#!/usr/bin/env python3
"""One finite, synthetic external-package consumer trace. Python standard library only."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import secrets
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
from twin_cleanup import dispose, validate_descriptor
from twin_receipt import SCENARIO, KIND, Refused, require, verify_receipt, barrier_ok, decode, safe_diagnostic

TOOLCHAIN = {"ASDF_ERLANG_VERSION": "27.3.4.15", "ASDF_ELIXIR_VERSION": "1.17.3-otp-27", "ASDF_NODEJS_VERSION": "20.18.1"}
LIMIT = 4 * 1024 * 1024


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, value):
    with open(path, "x", encoding="utf-8", opener=lambda p, f: os.open(p, f, 0o600)) as out:
        json.dump(value, out, sort_keys=True, indent=2, allow_nan=False)
        out.write("\n")


def read_json(path):
    path = Path(path)
    require(path.is_file() and not path.is_symlink(), "invalid_json_file")
    return decode(path.read_text())


def tree_hash(root):
    entries = []
    for path in sorted(Path(root).rglob("*")):
        require(not path.is_symlink(), "symlink_input")
        if path.is_file():
            entries.append((path.relative_to(root).as_posix(), digest(path.read_bytes())))
    return digest(json.dumps(entries, separators=(",", ":")).encode())


def extract_tar(data, destination, compressed=False):
    """Reject all links, devices, aliases, traversal and oversized members before writing."""
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz" if compressed else "r:") as archive:
        members = archive.getmembers()
        seen = set()
        total = 0
        for member in members:
            name = PurePosixPath(member.name)
            require(not name.is_absolute() and ".." not in name.parts and "\\" not in member.name,
                    "archive_path")
            require(str(name) not in seen and str(name) not in ["", "."], "archive_duplicate")
            seen.add(str(name))
            require(member.isfile() or member.isdir(), "archive_material")
            total += member.size
            require(0 <= member.size <= 32 * LIMIT and total <= 64 * LIMIT, "archive_size")
        for member in members:
            target = destination / member.name
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with target.open("xb") as out:
                    out.write(archive.extractfile(member).read())


def validate_package_files(root):
    for path in Path(root).rglob("*"):
        parts = path.relative_to(root).parts
        require(not path.is_symlink() and not any(p in {"_build", "deps", ".git", "ebin"} for p in parts)
                and path.suffix != ".beam", "package_build_material")
    require((Path(root) / "mix.exs").is_file(), "package_project_missing")


def validate_host_dependency(source):
    require(len(re.findall(r"\{:rindle\s*,", source)) == 1 and
            re.search(r'\{:rindle,\s*path:\s*"\.\./package"\}', source), "host_dependency")


def validate_mounts(mounts):
    require(mounts == [{"type": "volume", "source": "retained", "target": "/retained"}], "unexpected_mount")


def validate_runtime(health, inputs):
    require({k: health[k] for k in inputs["toolchain"]} == inputs["toolchain"], "runtime_version")
    require(health["lock_sha256"] == inputs["lock_sha256"], "runtime_lock")
    require(health["origin"] == "/twin/_build/prod/lib/rindle/ebin/Elixir.Rindle.beam", "runtime_origin")


def archive_identity(archive):
    with tempfile.TemporaryDirectory(prefix="rindle-twin-archive-") as d:
        outer = Path(d) / "hex"; outer.mkdir()
        extract_tar(Path(archive).read_bytes(), outer)
        require({p.name for p in outer.iterdir()} == {"VERSION", "CHECKSUM", "metadata.config", "contents.tar.gz"}, "hex_members")
        require((outer / "VERSION").read_bytes() == b"3", "hex_version")
        package = Path(d) / "package"; package.mkdir()
        extract_tar((outer / "contents.tar.gz").read_bytes(), package, compressed=True)
        validate_package_files(package)
        return {"package_tar_sha256": digest(Path(archive).read_bytes()),
                "package_metadata_sha256": digest((outer / "metadata.config").read_bytes()),
                "package_tree_sha256": tree_hash(package)}


def validate_archive(archive, inputs):
    actual = archive_identity(archive)
    require(all(inputs[k] == v for k, v in actual.items()), "archive_identity")


class Runner:
    def __init__(self, evidence, descriptor=None):
        self.evidence = Path(evidence).resolve()
        self.context = self.evidence / "workspace"
        self.descriptor = descriptor
        existing = list((self.evidence / "private").glob("command-*.txt"))
        self.sequence = max((int(p.stem.split("-")[1]) for p in existing), default=0)
        self.stage = "initialization"

    def command(self, argv, timeout=120, cwd=None):
        self.sequence += 1
        logs = self.evidence / "private"
        logs.mkdir(mode=0o700, exist_ok=True)
        target = logs / ("command-%03d-%s.txt" % (self.sequence, uuid.uuid4().hex[:12]))
        # Exclusive bounded private capture; raw output never reaches parent console.
        with open(target, "xb", opener=lambda p, f: os.open(p, f, 0o600)) as output:
            proc = subprocess.Popen(argv, cwd=cwd or ROOT, env={**os.environ, **TOOLCHAIN},
                                    stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
            deadline = time.monotonic() + timeout
            try:
                while proc.poll() is None:
                    require(time.monotonic() < deadline, "stage_timeout")
                    require(target.stat().st_size <= LIMIT, "stage_output_limit")
                    time.sleep(0.1)
            except BaseException:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait()
                raise
        require(target.stat().st_size <= LIMIT, "stage_output_limit")
        require(proc.returncode == 0, "stage_command_failed")
        return target.read_text(errors="replace")

    def compose(self, *args, timeout=120):
        return self.command(["docker", "compose", "--env-file", str(self.evidence / ".env"),
                             "-p", self.descriptor["project"], "-f", str(self.context / "compose.yml"),
                             *args], timeout=timeout, cwd=self.context)

    def progress(self, stage):
        self.stage = stage
        print("RUNNING " + safe_diagnostic({"stage": stage})["stage"], flush=True)

    def rpc(self, operation, body):
        # The control header is expanded inside the disposable container, never in argv/log prose.
        text = self.compose("exec", "-T", "host", "sh", "-c",
                            'exec curl --fail --silent --max-time 145 -H "x-twin-control: $TWIN_SECRET" -X POST --data "$1" "http://localhost:4100/$2"',
                            "twin-control", json.dumps(body), operation, timeout=150)
        value = json.loads(text)
        if value.get("outcome") == "incomplete":
            code = value.get("reason", "scenario_failed")
            allowed = {name + suffix for name in ("scenario", "stimulus", "upload_initiate", "upload_sign", "upload_put", "upload_verify", "variant_ready", "asset_read", "attach", "detach", "job_retry", "pause", "barrier") for suffix in ("_match", "_failed")}
            require(code in allowed, "host_reason_invalid")
            raise Refused("host_" + code)
        return value

    def health(self):
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline:
            try:
                return json.loads(self.compose("exec", "-T", "host", "curl", "--fail", "--silent",
                                                "--max-time", "3", "http://localhost:4100/health", timeout=5))
            except (Refused, json.JSONDecodeError):
                time.sleep(1)
        raise Refused("host_readiness_timeout")

    def minio(self, command):
        return self.compose("exec", "-T", "minio", "sh", "-c",
                            'export MC_HOST_local="http://twinlocal:$MINIO_ROOT_PASSWORD@localhost:9000"; ' + command)

    def stage_inputs(self):
        self.progress("package")
        run_id = uuid.uuid4().hex
        self.context.mkdir()
        (self.context / "host").mkdir()
        host = ROOT / "test/twin/host"
        for file in sorted(host.rglob("*")):
            require(not file.is_symlink(), "host_symlink")
            if file.is_file():
                require(file.relative_to(host).parts[0] not in ("deps", "_build", ".git"), "host_build_material")
                dest = self.context / "host" / file.relative_to(host)
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(file, dest)
        archive = self.evidence / "package.tar"
        self.command(["mix", "hex.build", "--output", str(archive)], timeout=180)
        outer = self.context / "hex"
        outer.mkdir()
        extract_tar(archive.read_bytes(), outer)
        require((outer / "contents.tar.gz").is_file(), "hex_contents_missing")
        package = self.context / "package"
        package.mkdir()
        extract_tar((outer / "contents.tar.gz").read_bytes(), package, compressed=True)
        validate_package_files(package)
        validate_host_dependency((self.context / "host/mix.exs").read_text())
        archive_fields = archive_identity(archive)
        shutil.rmtree(outer)
        shutil.copyfile(ROOT / "docker/Dockerfile.twin", self.context / "Dockerfile")
        shutil.copyfile(ROOT / "docker/compose.twin.yml", self.context / "compose.yml")
        source = self.command(["git", "rev-parse", "HEAD"]).strip()
        source_tree = self.command(["git", "diff", "HEAD", "--", "lib", "priv", "mix.exs"]).strip()
        require(not source_tree, "dirty_package_source")
        self.inputs = {"kind": KIND, "independent_pilot_credit": False, "schema_version": 1, "scenario": SCENARIO, "run_id": run_id,
                       "source_sha": source, **archive_fields,
                       "package_tree_sha256": tree_hash(package), "host_sha256": tree_hash(self.context / "host"),
                       "lock_sha256": digest((self.context / "host/mix.lock").read_bytes()),
                       "config_sha256": tree_hash(self.context / "host/config"),
                       "contract_sha256": digest(b"".join((ROOT / "scripts/maintainer" / name).read_bytes() for name in ("built_package_twin.py", "twin_receipt.py", "twin_cleanup.py") if (ROOT / "scripts/maintainer" / name).exists())),
                       "fixture_sha256": digest(__import__("base64").b64decode(re.search(r'Base.decode64!\(\s*"([A-Za-z0-9+/=]+)"', (self.context / "host/lib/twin/tracer.ex").read_text()).group(1))),
                       "build_sha256": digest((self.context / "Dockerfile").read_bytes() + (self.context / "compose.yml").read_bytes()),
                       "toolchain": {"elixir": "1.17.3", "otp": "27.3.4.15", "oban": "2.21.1", "phoenix": "1.8.12"}}
        write_json(self.evidence / "inputs.json", self.inputs)
        self.descriptor = {"kind": KIND, "independent_pilot_credit": False, "schema_version": 1, "run_id": run_id, "project": "rindle-twin-" + run_id,
                           "database": "twin_" + run_id, "bucket": "twin-" + run_id,
                           "workspace": str(self.context), "evidence": str(self.evidence)}
        secret = secrets.token_hex(24)
        env = {"TWIN_PROJECT": self.descriptor["project"], "TWIN_RUN_ID": run_id,
               "TWIN_DATABASE": self.descriptor["database"], "TWIN_BUCKET": self.descriptor["bucket"], "TWIN_SECRET": secret}
        with open(self.evidence / ".env", "x", opener=lambda p, f: os.open(p, f, 0o600)) as out:
            out.write("".join(k + "=" + v + "\n" for k, v in env.items()))

        self.descriptor.update({"host_names": [self.descriptor["project"] + "-host-1"],
            "volumes": [self.descriptor["project"] + suffix for suffix in ("_database", "_objects", "_retained")],
            "network": self.descriptor["project"] + "_default", "image": self.descriptor["project"] + ":local",
            "compose_sha256": digest((self.context / "compose.yml").read_bytes()),
            "env_sha256": digest((self.evidence / ".env").read_bytes()),
            "inputs_sha256": digest((self.evidence / "inputs.json").read_bytes())})
        write_json(self.evidence / "resources.json", self.descriptor)
        validate_descriptor(self)

    def validate_stage(self):
        require({p.name for p in self.context.iterdir()} == {"host", "package", "Dockerfile", "compose.yml"}, "stage_inputs")
        validate_archive(self.evidence / "package.tar", self.inputs)
        validate_package_files(self.context / "package")
        require(tree_hash(self.context / "package") == self.inputs["package_tree_sha256"], "staged_package_changed")
        require(tree_hash(self.context / "host") == self.inputs["host_sha256"], "staged_host_changed")
        require(digest((self.context / "Dockerfile").read_bytes() + (self.context / "compose.yml").read_bytes()) == self.inputs["build_sha256"], "staged_build_changed")
        config = json.loads(self.compose("config", "--format", "json"))
        require(set(config["services"]) == {"host", "postgres", "minio"}, "compose_services")
        service = config["services"]["host"]
        mounts = [{k: m[k] for k in ("type", "source", "target")} for m in service["volumes"]]
        validate_mounts(mounts)
        require(service["build"]["context"] == str(self.context) and service["build"]["dockerfile"] == "Dockerfile", "compose_context")
        require(not service["build"].get("additional_contexts"), "compose_extra_context")
        for value in config["services"].values():
            require(not value.get("ports") and not value.get("privileged") and not value.get("pid") and not value.get("network_mode"), "compose_isolation")
            require(all(m["type"] == "volume" for m in value.get("volumes", [])), "compose_bind_mount")
        require(set(service["environment"]) == {"TWIN_RUN_ID", "TWIN_DATABASE", "TWIN_BUCKET", "TWIN_SECRET", "ERL_FLAGS"}, "compose_environment")

    def runtime_isolation(self):
        ids = self.compose("ps", "--quiet", "host").split()
        require(len(ids) == 1, "runtime_identity")
        observed = json.loads(self.command(["docker", "inspect", ids[0]]))[0]
        require(observed["Config"]["Labels"]["com.docker.compose.project"] == self.descriptor["project"], "runtime_project")
        mounts = observed["Mounts"]
        require(len(mounts) == 1 and mounts[0]["Type"] == "volume" and
                mounts[0]["Name"] == self.descriptor["project"] + "_retained" and mounts[0]["Destination"] == "/retained", "runtime_mounts")
        env_keys = {v.split("=", 1)[0] for v in observed["Config"]["Env"]}
        require(not env_keys.intersection({"MIX_PATH", "MIX_HOME", "MIX_ARCHIVES", "MIX_BUILD_PATH", "ERL_LIBS"}), "runtime_mix_paths")
        return {"image_id": observed["Image"], "mounts_verified": True}

    def export_canaries(self):
        secret = next(line.split("=", 1)[1] for line in (self.evidence / ".env").read_text().splitlines() if line.startswith("TWIN_SECRET="))
        values = [secret, "https://canary.invalid/object?X-Amz-Signature=SIGNED_CANARY", "BODY_CANARY", "JOB_ERROR_CANARY"]
        body = json.dumps({"signed_url": values[1], "credential": values[0], "body": values[2], "error": values[3]})
        response = self.compose("exec", "-T", "host", "sh", "-c",
            'exec curl --fail --silent --max-time 10 -H "x-twin-control: $TWIN_SECRET" -X POST --data "$1" http://localhost:4100/canary', "twin-canary", body)
        logs = self.compose("logs", "--no-color", "--tail", "200", "host")
        require(all(value not in response + logs for value in values), "export_canary")

    def capabilities(self):
        majors = {}
        for binary in ("ffmpeg", "ffprobe"):
            text = self.compose("exec", "-T", "host", binary, "-version")
            match = re.match(binary + r" version (\d+)\.", text)
            require(match is not None and int(match[1]) >= 6, "media_version_floor")
            majors[binary + "_major"] = int(match[1])
        # The actual public upload/ready-variant trace proves storage and image I/O.
        schema = self.compose("exec", "-T", "postgres", "psql", "-U", "postgres", "-d", self.descriptor["database"],
                              "-Atc", "SELECT to_regclass('public.oban_jobs') IS NOT NULL AND to_regclass('rindle.media_assets') IS NOT NULL")
        require(schema.strip() == "t", "database_schema")
        return {**majors, "database_schema": True, "image_exercised": True, "storage_exercised": True, "av_exercised": False, "doctor_status": "not_used_known_migration_ledger_issue"}

    def stop_host(self):
        self.compose("stop", "--timeout", "15", "host", timeout=30)
        ids = self.compose("ps", "--all", "--quiet", "host").split()
        require(len(ids) == 1, "host_identity_unknown")
        state = json.loads(self.command(["docker", "inspect", ids[0]]))[0]["State"]
        require(state["Status"] == "exited" and not state["Running"] and not state["Paused"], "host_not_stopped")
        return ids[0]

    def run(self, verify, cleanup):
        receipt = {"schema_version": 1, "kind": "maintainer-operated-synthetic", "independent_pilot_credit": False,
                   "outcome": "incomplete", "reason": "not_completed", "stage": "initialization", "dependency": "none"}
        try:
            self.stage_inputs()
            receipt["inputs"] = self.inputs
            self.validate_stage()
            self.progress("build")
            self.compose("build", "host", timeout=900)
            self.progress("services")
            self.compose("up", "-d", "--wait", "postgres", "minio", timeout=120)
            self.minio('mc mb local/' + self.descriptor["bucket"])
            self.compose("up", "-d", "host")
            first_health = self.health()
            validate_runtime(first_health, self.inputs)
            self.export_canaries()
            isolation = self.runtime_isolation()
            capabilities = self.capabilities()
            self.progress("retry-barrier")
            before = self.rpc("begin", {})
            before["sequence"] = 1
            old_container = self.stop_host()
            self.progress("restart")
            self.compose("up", "-d", "--force-recreate", "host")
            second_health = self.health()
            validate_runtime(second_health, self.inputs)
            require(self.runtime_isolation() == isolation, "restart_isolation")
            after = self.rpc("resume", {"job_id": before["job_id"], "asset_id": before["asset_id"]})
            self.progress("domain-cleanup")
            after["sequence"] = 2
            inventory = self.rpc("inventory", {})
            inventory["sequence"] = 3
            new_container = self.stop_host()
            objects = self.minio('mc ls --json --recursive local/' + self.descriptor["bucket"])
            multipart = self.minio('mc ls --json --incomplete --recursive local/' + self.descriptor["bucket"])
            versioning = self.minio('mc version info --json local/' + self.descriptor["bucket"])
            self.validate_stage()
            candidate = {**receipt, "isolation": isolation, "capabilities": capabilities, "before": before, "after": after, "old_runtime": first_health, "new_runtime": second_health,
                            "old_container": old_container, "new_container": new_container,
                            "old_exited": True, "new_exited": True,
                            "inventory": {**inventory, "objects": len(objects.splitlines()), "multipart": len(multipart.splitlines()),
                                          "versioning_disabled": (json.loads(versioning).get("status") == "success" and json.loads(versioning).get("versioning") == {"status": "", "MFADelete": ""}),
                                          "processes": 0, "complete": True}, "outcome": "complete", "reason": "complete", "stage": "complete", "dependency": "none"}
            verify_receipt(self.inputs, candidate)
            receipt = candidate
        except (Refused, OSError, ValueError, KeyError, TypeError) as exc:
            receipt["stage"] = self.stage
            receipt["outcome"] = "incomplete"
            receipt["reason"] = str(exc) if isinstance(exc, Refused) else "runner_failed"
            # Stop this run's writers before the explicitly requested cleanup.
            if self.descriptor:
                try:
                    self.stop_host()
                except (Refused, OSError):
                    pass
        finally:
            write_json(self.evidence / "receipt.json", receipt)
        if cleanup and self.descriptor:
            self.progress("disposal")
            dispose(self)
        require(receipt["outcome"] == "complete", receipt["reason"])
        if verify:
            verify_receipt(read_json(self.evidence / "inputs.json"), read_json(self.evidence / "receipt.json"))
        return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest="operation", required=True)
    subs.add_parser("check", help="check local Docker/Compose and supported build toolchain")
    run = subs.add_parser("run", help="build once and run the finite synthetic lifecycle")
    run.add_argument("--verify", action="store_true")
    run.add_argument("--cleanup", action="store_true")
    run.add_argument("--evidence", type=Path)
    check = subs.add_parser("verify", help="verify retained evidence against independent runner inputs")
    check.add_argument("--inputs", type=Path, required=True)
    check.add_argument("--receipt", type=Path, required=True)
    clean = subs.add_parser("cleanup", help="dispose exact run-owned resources after writers stop")
    clean.add_argument("--descriptor", type=Path, required=True)
    args = parser.parse_args()
    evidence = None
    try:
        if args.operation == "verify":
            inputs = read_json(args.inputs)
            validate_archive(args.inputs.resolve().parent / "package.tar", inputs)
            verify_receipt(inputs, read_json(args.receipt))
        elif args.operation == "cleanup":
            descriptor = read_json(args.descriptor)
            runner = Runner(args.descriptor.resolve().parent, descriptor)
            dispose(runner)
        else:
            evidence = args.evidence if args.operation == "run" else None
            if evidence:
                evidence.mkdir(mode=0o700, parents=True, exist_ok=False)
            else:
                evidence = Path(tempfile.mkdtemp(prefix="rindle-twin-"))
                evidence.chmod(0o700)
            runner = Runner(evidence)
            runner.command(["docker", "version", "--format", "{{.Server.Version}}"], timeout=15)
            runner.command(["docker", "compose", "version"], timeout=15)
            if args.operation == "run":
                runner.run(args.verify, args.cleanup)
        print("PASSED " + args.operation)
        if evidence:
            print("Evidence: " + str(evidence))
        return 0
    except (Refused, OSError, ValueError, KeyError, TypeError) as exc:
        reason = str(exc) if isinstance(exc, Refused) else "invalid_or_unavailable_input"
        print("INCOMPLETE " + args.operation + ": " + reason, file=sys.stderr)
        if evidence:
            print("Evidence: " + str(evidence), file=sys.stderr)
            print("Cleanup: python3 scripts/maintainer/built_package_twin.py cleanup --descriptor " + str(evidence / "resources.json"), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
