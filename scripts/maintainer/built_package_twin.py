#!/usr/bin/env python3
"""One finite, synthetic external-package consumer trace. Python standard library only."""
import concurrent.futures
import argparse
import hashlib
import gzip
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import secrets
import shutil
import signal
import shlex
import subprocess
import sys
import tarfile
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
from twin_cleanup import dispose_matrix, dispose, validate_descriptor
import twin_receipt as contracts
from twin_receipt import SCENARIO, KIND, PNG, AV_BASE64, CASES, validate_tus_clients, Refused, require, verify_receipt, barrier_ok, decode, safe_diagnostic, MAX_BYTES

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
    require(path.stat().st_size <= MAX_BYTES, "json_size")
    with path.open() as source:
        return decode(source.read(MAX_BYTES + 1))


def tree_hash(root):
    entries = []
    for path in sorted(Path(root).rglob("*")):
        require(not path.is_symlink(), "symlink_input")
        if path.is_file():
            entries.append((path.relative_to(root).as_posix(), digest(path.read_bytes())))
    return digest(json.dumps(entries, separators=(",", ":")).encode())


def extract_tar(data, destination, compressed=False):
    """Reject all links, devices, aliases, traversal and oversized members before writing."""
    require(len(data) <= 16 * LIMIT, "archive_size")
    if compressed:
        with gzip.GzipFile(fileobj=io.BytesIO(data)) as stream:
            data = stream.read(16 * LIMIT + 1)
        require(len(data) <= 16 * LIMIT, "archive_expanded_size")
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:") as archive:
        members = archive.getmembers()
        require(len(members) <= 10_000, "archive_member_count")
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


HOST_FILES = {"mix.exs", "mix.lock", "config/config.exs", "config/runtime.exs",
              "lib/twin/application.ex", "lib/twin/repo.ex", "lib/twin/web.ex",
              "lib/twin/storage.ex", "lib/twin/tracer.ex",
              "priv/repo/migrations/20261021000000_install_twin.exs"}


def validate_host_inputs(host):
    validate_package_files(host)
    actual = {p.relative_to(host).as_posix() for p in Path(host).rglob("*") if p.is_file()}
    require(actual == HOST_FILES, "host_input_set")


def validate_host_dependency(source):
    require(len(re.findall(r"\{:rindle\s*,", source)) == 1 and
            re.search(r'\{:rindle,\s*path:\s*"\.\./package"\}', source), "host_dependency")


def validate_mounts(mounts):
    require(mounts == [{"type": "volume", "source": "retained", "target": "/retained"}], "unexpected_mount")


def validate_build_args(args, run_id):
    require(args == {"TWIN_BUILD_RUN": run_id}, "fresh_compile_identity")


def validate_runtime(health, inputs):
    require({k: health[k] for k in inputs["toolchain"]} == inputs["toolchain"], "runtime_version")
    require(health["lock_sha256"] == inputs["lock_sha256"], "runtime_lock")
    require(health["origin"] == "/twin/_build/prod/lib/rindle/ebin/Elixir.Rindle.beam", "runtime_origin")


def archive_identity(archive):
    require(Path(archive).is_file() and not Path(archive).is_symlink() and Path(archive).stat().st_size <= 16 * LIMIT, "archive_file_size")
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
    require(Path(archive).is_file() and Path(archive).stat().st_size <= 16 * LIMIT, "archive_file_size")
    require(digest(Path(archive).read_bytes()) == inputs["package_tar_sha256"], "archive_identity")
    actual = archive_identity(archive)
    require(all(inputs[k] == v for k, v in actual.items()), "archive_identity")


def validate_host_surface(source):
    forbidden = r"Rindle\.(?:Workers|FSM|Config)\b|perform_job|Oban\.(?:drain_queue|retry_job|Testing)|testing\s*:|SQL\.Sandbox|:beam_lib|:code\.get_object_code|Repo\.(?:update|delete|insert)!?\(|scheduled_at\s*=|(?:UPDATE|INSERT INTO|DELETE FROM)\s+(?!twin_fault_counters\b)[a-z_]+"
    require(re.search(forbidden, source) is None, "unsupported_host_call")
    require(re.search(r'File\.(?:read|read!)\([^\n]*(?:/lib/|\.beam|/checkout/)', source) is None, "host_source_inspection")



def validate_absence(before, absence):
    require(all(absence.get(k) == before.get(k) for k in ("source_key", "job_id", "asset_id")), "absence_identity")
    require(absence.get("head") == "not_found" and absence.get("asset_retained") is True,
            "absence_not_authoritative")
    require(barrier_ok({"paused": absence.get("paused"), "running": absence.get("running")}, absence), "raced_barrier")


class Runner:
    def __init__(self, evidence, descriptor=None):
        self.evidence = Path(evidence).resolve()
        self.context = self.evidence / "workspace"
        self.descriptor = descriptor
        existing = list((self.evidence / "private").glob("command-*.txt"))
        self.sequence = max((int(p.stem.split("-")[1]) for p in existing), default=0)
        self.stage = "initialization"
        self.machine = False
        self.case = None
        self.inputs = None
        self.full_audit = False
        self.audit = None

    def command(self, argv, timeout=120, cwd=None, expected_exit=0):
        self.sequence += 1
        logs = self.evidence / "private"
        logs.mkdir(mode=0o700, exist_ok=True)
        target = logs / ("command-%03d-%s.txt" % (self.sequence, uuid.uuid4().hex[:12]))
        # Exclusive bounded private capture; raw output never reaches parent console.
        with open(target, "xb", opener=lambda p, f: os.open(p, f, 0o600)) as output:
            proc = subprocess.Popen(argv, cwd=cwd or ROOT, env={**{k: v for k, v in os.environ.items() if not k.startswith("TWIN_") and k not in {"MIX_PATH", "MIX_EXS", "MIX_BUILD_PATH", "ERL_LIBS"}}, **TOOLCHAIN},
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
        require(proc.returncode == expected_exit, "stage_command_failed")
        return target.read_text(errors="replace")

    def compose(self, *args, timeout=120, expected_exit=0):
        return self.command(["docker", "compose", "--env-file", str(self.evidence / ".env"),
                             "-p", self.descriptor["project"], "-f", str(self.context / "compose.yml"),
                             *args], timeout=timeout, cwd=self.context, expected_exit=expected_exit)

    def progress(self, stage):
        self.stage = stage
        if not self.machine:
            print("RUNNING " + safe_diagnostic({"stage": stage})["stage"], flush=True)

    def rpc(self, operation, body):
        # The control header is expanded inside the disposable container, never in argv/log prose.
        text = self.compose("exec", "-T", "host", "sh", "-c",
                            'exec curl --fail --silent --max-time 145 -H "x-twin-control: $TWIN_SECRET" -X POST --data "$1" "http://localhost:4100/$2"',
                            "twin-control", json.dumps(body), operation, timeout=150)
        value = json.loads(text)
        if value.get("outcome") == "incomplete":
            code = value.get("reason", "scenario_failed")
            allowed = {name + suffix for name in ("scenario", "stimulus", "upload_initiate", "upload_sign", "upload_put", "upload_verify", "variant_ready", "asset_read", "attach", "detach", "job_retry", "pause", "barrier", "tus", "av", "provider", "promotion", "cleanup", "audit") for suffix in ("_match", "_failed")}
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

    def stage_inputs(self, shared_archive=None):
        self.progress("package")
        run_id = uuid.uuid4().hex
        self.context.mkdir()
        (self.context / "host").mkdir()
        host = ROOT / "test/twin/host"
        validate_host_inputs(host)
        for file in sorted(host.rglob("*")):
            require(not file.is_symlink(), "host_symlink")
            if file.is_file():
                require(file.relative_to(host).parts[0] not in ("deps", "_build", ".git"), "host_build_material")
                dest = self.context / "host" / file.relative_to(host)
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(file, dest)
        archive = self.evidence / "package.tar"
        if shared_archive is None:
            self.command(["mix", "hex.build", "--output", str(archive)], timeout=180)
        else:
            shutil.copyfile(shared_archive, archive)
        outer = self.context / "hex"
        outer.mkdir()
        extract_tar(archive.read_bytes(), outer)
        require((outer / "contents.tar.gz").is_file(), "hex_contents_missing")
        package = self.context / "package"
        package.mkdir()
        extract_tar((outer / "contents.tar.gz").read_bytes(), package, compressed=True)
        validate_package_files(package)
        validate_host_dependency((self.context / "host/mix.exs").read_text())
        for source_file in (self.context / "host").rglob("*"):
            if source_file.suffix in {".ex", ".exs"}:
                validate_host_surface(source_file.read_text())
        archive_fields = archive_identity(archive)
        shutil.rmtree(outer)
        shutil.copyfile(ROOT / "docker/Dockerfile.twin", self.context / "Dockerfile")
        shutil.copyfile(ROOT / "docker/compose.twin.yml", self.context / "compose.yml")
        source = self.command(["git", "rev-parse", "HEAD"]).strip()
        source_tree = self.command(["git", "diff", "HEAD", "--", "lib", "priv", "mix.exs"]).strip()
        require(not source_tree, "dirty_package_source")
        self.inputs = {"kind": KIND, "independent_pilot_credit": False, "schema_version": 2 if self.case else 1, "scenario": self.case or SCENARIO, "run_id": run_id,
                       "source_sha": source, **archive_fields,
                       "package_tree_sha256": tree_hash(package), "host_sha256": tree_hash(self.context / "host"),
                       "lock_sha256": digest((self.context / "host/mix.lock").read_bytes()),
                       "config_sha256": tree_hash(self.context / "host/config"),
                       "contract_sha256": digest(b"".join((ROOT / "scripts/maintainer" / name).read_bytes() for name in ("built_package_twin.py", "twin_receipt.py", "twin_cleanup.py") if (ROOT / "scripts/maintainer" / name).exists())),
                       "fixture_sha256": digest(__import__("base64").b64decode(AV_BASE64)) if self.case in {"av-repair", "provider-events"} else digest(__import__("base64").b64decode(re.search(r'Base.decode64!\(\s*"([A-Za-z0-9+/=]+)"', (self.context / "host/lib/twin/tracer.ex").read_text()).group(1))),
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
        validate_descriptor(self)
        require({p.name for p in self.context.iterdir()} == {"host", "package", "Dockerfile", "compose.yml"}, "stage_inputs")
        validate_archive(self.evidence / "package.tar", self.inputs)
        validate_package_files(self.context / "package")
        validate_host_inputs(self.context / "host")
        require(tree_hash(self.context / "package") == self.inputs["package_tree_sha256"], "staged_package_changed")
        require(tree_hash(self.context / "host") == self.inputs["host_sha256"], "staged_host_changed")
        require(digest((self.context / "Dockerfile").read_bytes() + (self.context / "compose.yml").read_bytes()) == self.inputs["build_sha256"], "staged_build_changed")
        config = json.loads(self.compose("config", "--format", "json"))
        require(set(config["services"]) == {"host", "postgres", "minio"}, "compose_services")
        service = config["services"]["host"]
        require(service["image"] == self.descriptor["image"], "compose_image_identity")
        require(service["environment"]["TWIN_RUN_ID"] == self.inputs["run_id"] and service["environment"]["TWIN_DATABASE"] == self.descriptor["database"] and service["environment"]["TWIN_BUCKET"] == self.descriptor["bucket"], "compose_resource_identity")
        mounts = [{k: m[k] for k in ("type", "source", "target")} for m in service["volumes"]]
        validate_mounts(mounts)
        require(service["build"]["context"] == str(self.context) and service["build"]["dockerfile"] == "Dockerfile", "compose_context")
        require(not service["build"].get("additional_contexts"), "compose_extra_context")
        validate_build_args(service["build"].get("args"), self.inputs["run_id"])
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

    def tus_clients(self):
        # Two completed exec processes: signed Location and raw headers remain private
        # on the same retained host node. Only fixed typed observations leave it.
        common = r'''set -eu
umask 077
hdr() { awk -v key="$2" 'tolower($1)==key":" {gsub("\r", "", $2); print $2}' "$1"; }
request() { target="$1"; shift; curl --silent --show-error --max-time 20 -o /dev/null -D "$target" -w '%{http_code}' -H 'Tus-Resumable: 1.0.0' "$@"; }
'''
        first = common + r'''
printf '%s' "$1" | base64 -d > /retained/tus.png
size=$(wc -c < /retained/tus.png)
create=$(request /retained/tus.create -X POST -H "Upload-Length: $size" -H 'Upload-Metadata: filetype aW1hZ2UvcG5n' http://localhost:4100/uploads/tus)
location=$(hdr /retained/tus.create location)
case "$location" in /uploads/tus/*) ;; *) exit 1 ;; esac
printf '%s' "$location" > /retained/tus.location
head -c 32 /retained/tus.png > /retained/tus.first
patch=$(request /retained/tus.patch -X PATCH -H 'Content-Type: application/offset+octet-stream' -H 'Upload-Offset: 0' --data-binary @/retained/tus.first "http://localhost:4100$location")
offset=$(hdr /retained/tus.patch upload-offset)
printf '{"pid":%s,"create_status":%s,"patch_status":%s,"offset":%s}' "$$" "$create" "$patch" "$offset"
'''
        second = common + r'''
location=$(cat /retained/tus.location)
head_status=$(request /retained/tus.head -I "http://localhost:4100$location")
offset=$(hdr /retained/tus.head upload-offset)
cache=$(hdr /retained/tus.head cache-control)
wrong=$(request /retained/tus.wrong -X PATCH -H 'Content-Type: application/offset+octet-stream' -H 'Upload-Offset: 0' --data-binary @/retained/tus.first "http://localhost:4100$location")
after_status=$(request /retained/tus.after -I "http://localhost:4100$location")
after=$(hdr /retained/tus.after upload-offset)
tail -c +$((offset + 1)) /retained/tus.png > /retained/tus.rest
patch=$(request /retained/tus.final -X PATCH -H 'Content-Type: application/offset+octet-stream' -H "Upload-Offset: $offset" --data-binary @/retained/tus.rest "http://localhost:4100$location")
final=$(hdr /retained/tus.final upload-offset)
printf '{"pid":%s,"head_status":%s,"head_offset":%s,"head_cache":"%s","wrong_status":%s,"after_wrong_status":%s,"after_wrong_offset":%s,"patch_status":%s,"final_offset":%s}' "$$" "$head_status" "$offset" "$cache" "$wrong" "$after_status" "$after" "$patch" "$final"
'''
        a = json.loads(self.compose("exec", "-T", "host", "sh", "-c", first, "tus-client-one", PNG))
        # compose exec has exited: the first client is dead before the next starts.
        b = json.loads(self.compose("exec", "-T", "host", "sh", "-c", second, "tus-client-two"))
        validate_tus_clients(a, b, len(__import__("base64").b64decode(PNG)))
        return {"first": a, "second": b, "first_exited": True, "second_exited": True}

    def object_keys(self):
        raw = self.minio('mc ls --json --recursive local/' + self.descriptor["bucket"])
        records = [json.loads(line) for line in raw.splitlines()]
        require(all(r.get("status") == "success" and r.get("type") == "file" for r in records), "object_inventory")
        found = [r["key"] for r in records]
        require(len(set(found)) == len(found), "object_inventory")
        return sorted(found)

    def purge_absence(self):
        self.progress("retry-barrier")
        before = self.rpc("begin", {})
        before["sequence"] = 1
        require(barrier_ok({"paused": before["paused"], "running": before["running"]}, before), "raced_barrier")
        key = before["source_key"]
        require(re.fullmatch(r"elixir-twin-profile/" + re.escape(before["asset_id"]) + r"/[0-9a-f-]{36}\.png", key) is not None, "source_identity")
        # Independent authority removes only this exact already-observed source.
        removed = json.loads(self.minio('mc rm --json ' + shlex.quote('local/' + self.descriptor["bucket"] + '/' + key)))
        require(removed.get("status") == "success", "independent_delete_failed")
        absence = self.rpc("purge-absent", {"source_key": key, "asset_id": before["asset_id"], "job_id": before["job_id"]})
        validate_absence(before, absence)
        absence["sequence"] = 2
        after = self.rpc("purge-resume", {"asset_id": before["asset_id"], "job_id": before["job_id"]})
        after["sequence"] = 3
        self.progress("domain-cleanup")
        inventory = self.rpc("inventory", {})
        inventory["sequence"] = 4
        objects = self.object_keys()
        multipart = self.minio('mc ls --json --incomplete --recursive local/' + self.descriptor["bucket"])
        require(not multipart.strip(), "multipart_residue")
        versioning = json.loads(self.minio('mc version info --json local/' + self.descriptor["bucket"]))
        inventory.update(objects=len(objects), multipart=0, versioning_disabled=(versioning.get("status") == "success" and versioning.get("versioning") == {"status": "", "MFADelete": ""}), processes=0, complete=True)
        require(not objects and all(v == int(k == "rindle_migration_versions") for k,v in inventory["domain"].items()), "purge_residue")
        return {"before": before, "absence": absence, "after": after, "inventory": inventory}

    def av_failure(self):
        self.compose("exec", "-T", "host", "sh", "-c",
                     'umask 077; printf "%s" "$1" | base64 -d > /retained/av-input.mp4', "av-fixture", AV_BASE64)
        self.compose("exec", "-T", "host", "ffmpeg", "-v", "error", "-xerror", "-i", "/retained/av-input.mp4", "-map", "0:v:0", "-map", "0:a:0", "-f", "null", "-")
        started = time.monotonic()
        before = self.rpc("av-begin", {})
        trail = []
        while time.monotonic() - started < 600:
            status = self.rpc("av-status", {"job_id": before["job_id"], "asset_id": before["asset_id"]})
            observation = {k: status[k] for k in ("job_id", "attempt", "state", "error_attempts", "fault_downloads")}
            if not trail or trail[-1] != observation:
                trail.append(observation)
            if status["state"] == "discarded":
                require(status["attempt"] == status["fault_downloads"] == 5 and sorted(status["error_attempts"]) == [1,2,3,4,5]
                        and status["variant_state"] == "failed" and status["diagnostic"] == "failed_work"
                        and status["processor_reason"] == "unsupported_codec", "av_failure_unproven")
                elapsed = int((time.monotonic() - started) * 1000)
                require(elapsed < 600_000, "av_deadline")
                return {"before": before, "failed": status, "attempts": trail, "elapsed_ms": elapsed,
                        "deadline_ms": 600_000, "remaining_ms": 600_000 - elapsed, "input_decoded": True}
            require(status["state"] not in {"completed", "cancelled"} and status["attempt"] <= 5, "av_failure_unproven")
            time.sleep(1)
        raise Refused("av_deadline")

    def provider_events(self):
        self.compose("exec", "-T", "host", "sh", "-c",
                     'umask 077; printf "%s" "$1" | base64 -d > /retained/av-input.mp4', "provider-fixture", AV_BASE64)
        first = self.rpc("provider-begin", {})
        snapshots, effects, statuses = [first["snapshot"]], [first["effects"]], []
        ready = dict(label="ready", event_type="video.asset.ready", created_at="2026-05-06T00:00:02.000001Z", invalid=False)
        for _ in range(2):
            statuses.append(self.rpc("provider-deliver", ready)["status"])
        pending = self.rpc("provider-pending", {})
        for completed, event in enumerate([None, ready,
                dict(label="older-created", event_type="video.asset.created", created_at="2026-05-06T00:00:01.999999Z", invalid=False),
                dict(label="older-error", event_type="video.asset.errored", created_at="2026-05-06T00:00:01.999999Z", invalid=False)], 1):
            if event:
                statuses.append(self.rpc("provider-deliver", event)["status"])
            observation = self.rpc("provider-advance", dict(completed=completed, ready=True))
            snapshots.append(observation["snapshot"])
            effects.append(observation["effects"])
        statuses.append(self.rpc("provider-deliver", {**ready, "invalid": True})["status"])
        provider = self.rpc("provider-finish", {})
        provider.update(snapshots=snapshots, effects=effects, pending=pending, http_statuses=statuses)
        self.export_canaries()
        logs = self.compose("logs", "--no-color", "--tail", "200", "host")
        require("MUX_PROVIDER_CANARY_" not in logs and "BODY_CANARY" not in logs, "provider_export_canary")
        objects = self.object_keys()
        return dict(provider=provider, object_keys=objects)

    def promotion_restart(self, runtime, isolation):
        started = time.monotonic()
        before = self.rpc("promotion-begin", {})
        request = {k: before[k] for k in ("session_id", "asset_id", "job_id")}
        cut = self.rpc("promotion-cut", request)
        require(cut == before, "promotion_cut_changed")
        old_ids = self.compose("ps", "--quiet", "host").split()
        require(len(old_ids) == 1, "host_identity_unknown")
        old = old_ids[0]
        self.compose("kill", "--signal", "SIGKILL", "host")
        observed = json.loads(self.command(["docker", "inspect", old]))[0]["State"]
        require(observed["Status"] == "exited" and observed["Running"] is False
                and observed["ExitCode"] == 137, "promotion_old_alive")
        self.progress("restart")
        self.compose("up", "-d", "--force-recreate", "host")
        new_runtime = self.health()
        validate_runtime(new_runtime, self.inputs)
        require(new_runtime["boot_id"] != runtime["boot_id"], "restart_runtime_reused")
        require(self.runtime_isolation() == isolation, "restart_isolation")
        result = self.rpc("promotion-finish", request)
        objects = self.object_keys()
        new_ids = self.compose("ps", "--all", "--quiet", "host").split()
        require(len(new_ids) == 1, "host_identity_unknown")
        new = new_ids[0]
        elapsed = int((time.monotonic() - started) * 1000)
        require(elapsed < 180_000, "promotion_deadline")
        restart = dict(before=before, cut=cut, **result, old_runtime=runtime, new_runtime=new_runtime,
                       old_container=old, new_container=new, signal="SIGKILL", exit_code=137,
                       old_exited=True, elapsed_ms=elapsed, deadline_ms=180_000)
        return dict(restart=restart, object_keys=objects)

    def maintenance(self, task, *args, expected_exit=0):
        return self.compose("exec", "-T", "-e", "TWIN_START_ROLE=maintenance", "host",
                            "mix", task, *args, timeout=200, expected_exit=expected_exit)

    def interrupted_cleanup(self, runtime):
        before = self.rpc("cleanup-begin", {})
        deadline = time.monotonic() + 30
        while self.rpc("cleanup-expired", {}) != {"expired": True}:
            require(time.monotonic() < deadline, "cleanup_expiry_timeout")
            time.sleep(0.1)
        self.maintenance("rindle.abort_incomplete_uploads")
        abort = self.rpc("cleanup-after-abort", {})
        require(self.rpc("cleanup-arm", {}) == {"armed": True}, "cleanup_arm_failed")
        executor = concurrent.futures.ThreadPoolExecutor(max_workers=1)
        future = executor.submit(self.maintenance, "rindle.cleanup_orphans", "--no-dry-run",
                                 "--storage", "Elixir.Twin.StorageFault", expected_exit=137)
        try:
            deadline = time.monotonic() + 90
            while True:
                barrier = self.rpc("cleanup-barrier", {})
                if barrier.get("ready") is True:
                    break
                require(barrier == {"ready": False} and not future.done()
                        and time.monotonic() < deadline, "cleanup_barrier_failed")
                time.sleep(0.1)
            pid, main_pid = barrier["maintenance_pid"], barrier["main_pid"]
            require(type(pid) is int and type(main_pid) is int and pid > 1 and main_pid >= 1
                    and pid != main_pid, "cleanup_pid_invalid")
            self.compose("exec", "-T", "host", "sh", "-c",
                'set -eu; test "$1" -gt 1; test "$1" != "$2"; test "$(cat /proc/"$1"/comm)" = beam.smp; kill -0 "$2"; kill -KILL "$1"',
                "owned-maintenance-cut", str(pid), str(main_pid))
            future.result(timeout=30)
            observed = self.health()
            require(observed == runtime, "cleanup_main_changed")
            self.compose("exec", "-T", "host", "sh", "-c", 'kill -0 "$1"', "main-alive", str(main_pid))
            interrupted = self.rpc("cleanup-interrupted", {})
            require(interrupted["maintenance_pid"] == pid and interrupted["main_pid"] == main_pid,
                    "cleanup_cut_identity")
            interrupted.update(maintenance_exited=True, maintenance_exit=137, main_alive=True)
        finally:
            executor.shutdown(wait=False, cancel_futures=True)
        reruns = []
        for _ in range(2):
            self.maintenance("rindle.cleanup_orphans", "--no-dry-run", "--storage", "Elixir.Twin.StorageFault")
            reruns.append(self.rpc("cleanup-converged", {}))
        converged = self.rpc("cleanup-finish", {})
        return dict(cleanup=dict(before=before, abort=abort, interrupted=interrupted,
                                 reruns=reruns, converged=converged))

    def run_case(self, verify, cleanup):
        receipt = {"schema_version": 2, "kind": KIND, "independent_pilot_credit": False,
                   "outcome": "incomplete", "reason": "not_completed", "stage": "initialization", "dependency": "none"}
        try:
            if self.inputs is None:
                self.stage_inputs()
            receipt["inputs"] = self.inputs
            self.validate_stage()
            self.progress("build")
            self.compose("build", "host", timeout=900)
            self.progress("services")
            self.compose("up", "-d", "--wait", "postgres", "minio", timeout=120)
            self.minio('mc mb local/' + self.descriptor["bucket"])
            self.compose("up", "-d", "host")
            runtime = self.health()
            validate_runtime(runtime, self.inputs)
            self.export_canaries()
            isolation = self.runtime_isolation()
            if self.case == "tus-resume":
                self.rpc("tus-start", {})
                clients = self.tus_clients()
                result = self.rpc("tus-finish", {})
                keys = self.object_keys()
                require(keys == sorted([result["source_key"], *result["variant_keys"]]), "undeclared_objects")
                expected_hash = digest(__import__("base64").b64decode(PNG))
                require(result["checksum_sha256"] == expected_hash, "source_checksum")
                payload = dict(clients=clients, result=result, object_keys=keys)
            elif self.case == "purge-absence":
                payload = self.purge_absence()
            elif self.case == "provider-events":
                payload = self.provider_events()
            elif self.case == "promotion-restart":
                payload = self.promotion_restart(runtime, isolation)
                runtime = payload["restart"]["new_runtime"]
            elif self.case == "interrupted-cleanup":
                payload = self.interrupted_cleanup(runtime)
            elif self.case == "av-repair":
                receipt["failure"] = self.av_failure()
                before = receipt["failure"]["before"]
                repair = self.rpc("av-repair", {"job_id": before["job_id"], "asset_id": before["asset_id"]})
                probe = json.loads(self.compose("exec", "-T", "host", "ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", "/retained/av-output.mp4"))
                video = [v for v in probe["streams"] if v.get("codec_type") == "video"]
                audio = [v for v in probe["streams"] if v.get("codec_type") == "audio"]
                require(len(video) == len(audio) == 1, "av_output_streams")
                self.compose("exec", "-T", "host", "ffmpeg", "-v", "error", "-xerror", "-i", "/retained/av-output.mp4", "-map", "0:v:0", "-map", "0:a:0", "-f", "null", "-")
                versions = {binary: self.compose("exec", "-T", "host", binary, "-version").splitlines()[0].split()[2] for binary in ("ffmpeg", "ffprobe")}
                output = dict(video_codec=video[0]["codec_name"], audio_codec=audio[0]["codec_name"],
                              width=video[0]["width"], height=video[0]["height"],
                              duration_ms=int(float(probe["format"]["duration"]) * 1000), fully_decoded=True)
                keys = self.object_keys()
                require(keys == sorted([repair["source_key"], repair["variant_key"]]), "undeclared_objects")
                payload = dict(repair=repair, output=output, versions=versions, object_keys=keys)
            else:
                raise Refused("case_not_implemented")
            prepared = None
            if self.full_audit:
                prepared = self.rpc("audit-prepare", {"case_id": self.case, "asset_ids": self.case_assets(payload)})
            self.stop_host()
            if self.full_audit:
                self.audit = self.collect_audit(payload, prepared)
            self.validate_stage()
            receipt.update(case_id=self.case, **payload,
                           runtime=runtime, isolation=isolation, host_exited=True,
                           outcome="complete", reason="complete", stage="complete")
            verify_receipt(self.inputs, receipt)
            if self.full_audit:
                contracts.verify_matrix_audit(self.inputs, receipt, self.audit)
                write_json(self.evidence / "audit.json", self.audit)
        except (Refused, OSError, ValueError, KeyError, TypeError) as exc:
            self.audit = None
            receipt.update(stage=self.stage, outcome="incomplete", reason=str(exc) if isinstance(exc, Refused) else "runner_failed")
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

    def case_assets(self, payload):
        if self.case == "tus-resume":
            return [payload["result"]["asset_id"]]
        if self.case == "purge-absence":
            return [payload["before"]["asset_id"]]
        if self.case == "av-repair":
            return [payload["repair"]["asset_id"]]
        if self.case == "provider-events":
            return [payload["provider"]["asset_id"]]
        if self.case == "promotion-restart":
            return [payload["restart"]["before"]["asset_id"]]
        before = payload["cleanup"]["before"]
        return sorted([before["multipart_asset_id"], before["orphan_asset_id"]])

    def collect_audit(self, payload, prepared):
        self.progress("domain-cleanup")
        require(prepared["writers_paused"] is True and prepared["temp_files"] == [], "audit_writers")
        # Independent reads after host exit: the producer cannot race these lists.
        ids = self.compose("ps", "--all", "--quiet", "host").split()
        require(len(ids) == 1, "audit_host_identity")
        state = json.loads(self.command(["docker", "inspect", ids[0]]))[0]["State"]
        require(state["Status"] == "exited" and state["Running"] is False, "audit_host_alive")
        sql = """SELECT json_build_object(
          'relations', (SELECT json_agg(json_build_array(schemaname,tablename) ORDER BY schemaname,tablename) FROM pg_tables WHERE schemaname IN ('public','rindle')),
          'jobs', (SELECT coalesce(json_agg(json_build_object('id',id,'queue',queue,'state',state,'attempt',attempt,'args',args,'errors',errors) ORDER BY id),'[]') FROM public.oban_jobs),
          'fixtures', (SELECT coalesce(json_agg(json_build_object('run_id',run_id,'operation',operation,'source_key',source_key,'claims',claims) ORDER BY operation),'[]') FROM public.twin_fault_counters),
          'schema_migrations', (SELECT coalesce(json_agg(version ORDER BY version),'[]') FROM public.schema_migrations),
          'peers', (SELECT coalesce(json_agg(name ORDER BY name),'[]') FROM public.oban_peers))"""
        raw = json.loads(self.compose("exec", "-T", "postgres", "psql", "-U", "postgres", "-d", self.descriptor["database"], "-Atc", sql))
        relations = {}
        for schema, table in raw["relations"]:
            relations.setdefault(schema, []).append(table)
        require(relations == {"public": ["oban_jobs", "oban_peers", "schema_migrations", "twin_fault_counters"],
                              "rindle": sorted(contracts.DOMAIN)}, "audit_relations")
        domain = {}
        for table in sorted(contracts.DOMAIN):
            # Identifiers come only from the source-owned finite table set.
            field = "version" if table == "rindle_migration_versions" else "id"
            query = "SELECT coalesce(json_agg(" + field + " ORDER BY " + field + "),'[]') FROM rindle." + table
            domain[table] = json.loads(self.compose("exec", "-T", "postgres", "psql", "-U", "postgres", "-d", self.descriptor["database"], "-Atc", query))
        asset_ids = self.case_assets(payload)
        jobs = []
        for job in raw["jobs"]:
            args = job["args"]
            asset_id = args.get("asset_id")
            if asset_id is None and self.case == "provider-events":
                provider_id = args.get("event", {}).get("provider_asset_id")
                require(type(provider_id) is str and digest(provider_id.encode()) == payload["provider"]["provider_sha256"], "audit_provider_job")
                asset_id = payload["provider"]["asset_id"]
            require(asset_id in asset_ids, "audit_foreign_job")
            errors = job["errors"]
            require(type(errors) is list and all(type(e) is dict and type(e.get("attempt")) is int for e in errors), "audit_job_errors")
            jobs.append({**{k: job[k] for k in ("id", "queue", "state", "attempt")}, "asset_id": asset_id,
                         "event_sha256": digest(args["event_id"].encode()) if "event_id" in args else None,
                         "error_attempts": [e["attempt"] for e in errors]})
        fixtures = [{"run_id": row["run_id"], "operation": row["operation"],
                     "source_sha256": digest(row["source_key"].encode()), "claims": row["claims"]} for row in raw["fixtures"]]
        objects = self.object_keys()
        incomplete = self.minio('mc ls --json --incomplete --recursive local/' + self.descriptor["bucket"])
        require(not incomplete.strip(), "audit_multipart_residue")
        require(not objects, "audit_object_residue")
        versioning = json.loads(self.minio('mc version info --json local/' + self.descriptor["bucket"]))
        require(versioning.get("status") == "success" and versioning.get("versioning") == {"status": "", "MFADelete": ""}, "audit_versioning")
        copied = self.evidence / "private" / "stopped-temp"
        copied.mkdir(mode=0o700)
        self.command(["docker", "cp", ids[0] + ":/retained/tmp/.", str(copied)], timeout=30)
        require(not any(p.is_symlink() or not p.is_dir() for p in copied.rglob("*")), "audit_temp_residue")
        return dict(asset_ids=asset_ids, purge_job_ids=prepared["purge_job_ids"], domain=domain, relations=relations,
                    jobs=jobs, fixtures=fixtures, schema_migrations=raw["schema_migrations"], peers=raw["peers"],
                    objects=[], multipart=[], parts=[], temp_files=[], processes=[], host_container=ids[0],
                    host_exited=True, writers_stopped=True, listing_complete=True, versioning_disabled=True,
                    frozen_before_disposal=True)

    def run(self, verify, cleanup):
        started = time.monotonic()
        receipt = dict(schema_version=3, kind=KIND, independent_pilot_credit=False, outcome="incomplete",
                       reason="not_completed", stage="initialization", dependency="none", cases=[])
        children = []
        try:
            self.progress("package")
            archive = self.evidence / "package.tar"
            self.command(["mix", "hex.build", "--output", str(archive)], timeout=180)
            archive_identity(archive)
            root_run = uuid.uuid4().hex
            case_root = self.evidence / "cases"
            case_root.mkdir(mode=0o700)
            for case_id in CASES:
                child_path = case_root / case_id
                child_path.mkdir(mode=0o700)
                child = Runner(child_path)
                child.case, child.machine, child.full_audit = case_id, self.machine, True
                child.stage_inputs(shared_archive=archive)
                children.append(child)
            self.inputs = {**children[0].inputs, "schema_version": 3, "run_id": root_run,
                           "scenario": contracts.MATRIX_SCENARIO, "fixture_sha256": contracts.FIXTURE_MATRIX_SHA256,
                           "case_inputs": {child.case: child.inputs for child in children}}
            contracts.validate_inputs(self.inputs)
            write_json(self.evidence / "inputs.json", self.inputs)
            self.descriptor = dict(schema_version=2, kind=KIND, independent_pilot_credit=False,
                                   run_id=root_run, evidence=str(self.evidence),
                                   inputs_sha256=digest((self.evidence / "inputs.json").read_bytes()),
                                   cases=[dict(case_id=c.case, run_id=c.inputs["run_id"],
                                               descriptor_sha256=digest((c.evidence / "resources.json").read_bytes())) for c in children])
            write_json(self.evidence / "resources.json", self.descriptor)
            receipt["inputs"] = self.inputs
            for child in children:
                if not self.machine:
                    print("CASE " + child.case, flush=True)
                result = child.run_case(True, False)
                receipt["cases"].append(dict(case_id=child.case, receipt=result, audit=child.audit))
            receipt.update(outcome="complete", reason="complete", stage="complete",
                           elapsed_ms=int((time.monotonic() - started) * 1000), all_hosts_exited=True,
                           domain_verdict_frozen=True)
            verify_receipt(self.inputs, receipt)
        except (Refused, OSError, ValueError, KeyError, TypeError) as exc:
            receipt.update(outcome="incomplete", reason=str(exc) if isinstance(exc, Refused) else "runner_failed", stage=self.stage)
            for child in children:
                try:
                    if child.descriptor and child.context.exists():
                        child.stop_host()
                except (Refused, OSError):
                    pass
        finally:
            write_json(self.evidence / "receipt.json", receipt)
        # Freeze both successful and failed domain evidence BEFORE disposal.
        if cleanup and self.descriptor:
            self.progress("disposal")
            dispose_matrix(self, Runner)
        require(receipt["outcome"] == "complete", receipt["reason"])
        if verify:
            verify_receipt(read_json(self.evidence / "inputs.json"), read_json(self.evidence / "receipt.json"))
        return receipt

    def run_legacy(self, verify, cleanup):
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


def emit(operation, outcome, stage, reason, dependency, evidence, machine, case_id=None, legacy=False):
    result = {"kind": KIND, "independent_pilot_credit": False, "operation": operation,
              "outcome": outcome, "stage": stage, "reason": reason, "dependency": dependency}
    if evidence:
        result.update(evidence=str(evidence), inputs=str(evidence / "inputs.json"), receipt=str(evidence / "receipt.json"),
                      descriptor=str(evidence / "resources.json"),
                      reproduce="python3 scripts/maintainer/built_package_twin.py run" + (" --case " + case_id if case_id else " --legacy" if legacy else "") + " --verify --cleanup",
                      cleanup="python3 scripts/maintainer/built_package_twin.py cleanup --descriptor " + shlex.quote(str(evidence / "resources.json")))
    if machine:
        print(json.dumps(result, sort_keys=True))
    else:
        stream = sys.stdout if outcome == "passed" else sys.stderr
        print("Maintainer-operated synthetic evidence; independent_pilot_credit: false", file=stream)
        print(outcome.upper() + " " + operation + ": " + reason, file=stream)
        if evidence:
            for name in ("inputs", "receipt", "descriptor", "reproduce", "cleanup"):
                print(name.capitalize() + ": " + result[name], file=stream)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest="operation", required=True)
    subs.add_parser("check", help="check local Docker/Compose and supported build toolchain")
    run = subs.add_parser("run", help="build once and run the finite synthetic lifecycle")
    modes = run.add_mutually_exclusive_group()
    modes.add_argument("--case", choices=CASES, help="focused diagnostic case; never a full matrix verdict")
    modes.add_argument("--legacy", action="store_true", help="run the distinct phase-137 foundation diagnostic")
    run.add_argument("--verify", action="store_true")
    run.add_argument("--cleanup", action="store_true")
    run.add_argument("--evidence", "--evidence-dir", dest="evidence", type=Path, help="new or empty private evidence directory")
    check = subs.add_parser("verify", help="verify retained evidence against independent runner inputs")
    check.add_argument("--inputs", type=Path, required=True)
    check.add_argument("--receipt", type=Path, required=True)
    modes = check.add_mutually_exclusive_group()
    modes.add_argument("--case", choices=CASES, help="explicitly verify one focused diagnostic")
    modes.add_argument("--legacy", action="store_true", help="explicitly verify phase-137 evidence")
    clean = subs.add_parser("cleanup", help="dispose exact run-owned resources after writers stop")
    clean.add_argument("--descriptor", type=Path, required=True)
    for command in subs.choices.values():
        command.add_argument("--json", action="store_true", help="emit one labeled JSON result")
    args = parser.parse_args()
    evidence = None
    runner = None
    try:
        if args.operation == "verify":
            inputs = read_json(args.inputs)
            receipt = read_json(args.receipt)
            if args.case:
                require(inputs.get("schema_version") == receipt.get("schema_version") == 2
                        and inputs.get("scenario") == receipt.get("case_id") == args.case, "diagnostic_case_required")
            elif args.legacy:
                require(inputs.get("schema_version") == receipt.get("schema_version") == 1, "legacy_receipt_required")
            else:
                require(inputs.get("schema_version") == receipt.get("schema_version") == 3, "full_matrix_required")
            validate_archive(args.inputs.resolve().parent / "package.tar", inputs)
            verify_receipt(inputs, receipt)
        elif args.operation == "cleanup":
            descriptor = read_json(args.descriptor)
            evidence = args.descriptor.resolve().parent
            runner = Runner(args.descriptor.resolve().parent, descriptor)
            if descriptor.get("schema_version") == 2:
                dispose_matrix(runner, Runner)
            else:
                dispose(runner)
        else:
            evidence = args.evidence if args.operation == "run" else None
            if evidence:
                require(not evidence.is_symlink(), "evidence_symlink")
                if evidence.exists():
                    require(evidence.is_dir() and not any(evidence.iterdir()), "evidence_not_empty")
                else:
                    evidence.mkdir(mode=0o700, parents=True)
                evidence = evidence.resolve()
                evidence.chmod(0o700)
            else:
                evidence = Path(tempfile.mkdtemp(prefix="rindle-twin-"))
                evidence.chmod(0o700)
            runner = Runner(evidence)
            runner.machine = args.json
            runner.command(["docker", "version", "--format", "{{.Server.Version}}"], timeout=15)
            runner.command(["docker", "compose", "version"], timeout=15)
            version = runner.command(["elixir", "-e", 'IO.puts(System.version()); IO.puts(File.read!(Path.join([:code.root_dir(), "releases", System.otp_release(), "OTP_VERSION"])) |> String.trim())'], timeout=30)
            require(version.splitlines() == ["1.17.3", "27.3.4.15"], "build_toolchain")
            if args.operation == "run":
                runner.case = args.case
                if args.case:
                    runner.run_case(args.verify, args.cleanup)
                elif args.legacy:
                    runner.run_legacy(args.verify, args.cleanup)
                else:
                    runner.run(args.verify, args.cleanup)
        emit(args.operation, "passed", "complete", "complete", "none", evidence, args.json, getattr(args, "case", None), getattr(args, "legacy", False))
        return 0
    except (Refused, OSError, ValueError, KeyError, TypeError) as exc:
        reason = str(exc) if isinstance(exc, Refused) else "invalid_or_unavailable_input"
        outcome = "failed" if args.operation == "verify" else "blocked" if args.operation == "check" or reason == "cleanup_active_runtime" else "incomplete"
        stage = runner.stage if runner else "initialization"
        emit(args.operation, outcome, stage, reason, "docker" if args.operation == "check" else "none", evidence, args.json, getattr(args, "case", None), getattr(args, "legacy", False))
        return 1


if __name__ == "__main__":
    sys.exit(main())
