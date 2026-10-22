#!/usr/bin/env python3
"""One finite, synthetic external-package consumer trace. Python standard library only."""
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
from twin_cleanup import dispose, validate_descriptor
from twin_receipt import SCENARIO, KIND, Refused, require, verify_receipt, barrier_ok, decode, safe_diagnostic, MAX_BYTES

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


PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVQI12P4//8/AAX+Av7cRHQGAAAAAElFTkSuQmCC"
CASES = ("tus-resume",)


def validate_tus_clients(first, second, size):
    require(type(first.get("pid")) is int and type(second.get("pid")) is int
            and first["pid"] > 0 and second["pid"] > 0 and first["pid"] != second["pid"], "client_identity")
    require(first.get("create_status") == 201 and first.get("patch_status") == 204
            and type(first.get("offset")) is int and 0 < first["offset"] < size, "nonfinal_patch")
    require(second.get("head_status") == 204 and second.get("head_cache") == "no-store"
            and second.get("head_offset") == first["offset"], "head_authority")
    require(second.get("wrong_status") == 409 and second.get("after_wrong_status") == 204
            and second.get("after_wrong_offset") == first["offset"], "wrong_offset_advanced")
    require(second.get("patch_status") == 204 and second.get("final_offset") == size, "resume_incomplete")


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

    def command(self, argv, timeout=120, cwd=None):
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
        require(proc.returncode == 0, "stage_command_failed")
        return target.read_text(errors="replace")

    def compose(self, *args, timeout=120):
        return self.command(["docker", "compose", "--env-file", str(self.evidence / ".env"),
                             "-p", self.descriptor["project"], "-f", str(self.context / "compose.yml"),
                             *args], timeout=timeout, cwd=self.context)

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
            allowed = {name + suffix for name in ("scenario", "stimulus", "upload_initiate", "upload_sign", "upload_put", "upload_verify", "variant_ready", "asset_read", "attach", "detach", "job_retry", "pause", "barrier", "tus") for suffix in ("_match", "_failed")}
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
        validate_host_inputs(host)
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

    def run_case(self, verify, cleanup):
        receipt = {"schema_version": 2, "kind": KIND, "independent_pilot_credit": False,
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
            runtime = self.health()
            validate_runtime(runtime, self.inputs)
            self.export_canaries()
            isolation = self.runtime_isolation()
            self.rpc("tus-start", {})
            clients = self.tus_clients()
            result = self.rpc("tus-finish", {})
            keys = self.object_keys()
            require(keys == sorted([result["source_key"], *result["variant_keys"]]), "undeclared_objects")
            expected_hash = digest(__import__("base64").b64decode(PNG))
            require(result["checksum_sha256"] == expected_hash, "source_checksum")
            self.stop_host()
            self.validate_stage()
            receipt.update(case_id=self.case, clients=clients, result=result, object_keys=keys,
                           runtime=runtime, isolation=isolation, host_exited=True,
                           outcome="complete", reason="complete", stage="complete")
        except (Refused, OSError, ValueError, KeyError, TypeError) as exc:
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


def emit(operation, outcome, stage, reason, dependency, evidence, machine):
    result = {"kind": KIND, "independent_pilot_credit": False, "operation": operation,
              "outcome": outcome, "stage": stage, "reason": reason, "dependency": dependency}
    if evidence:
        result.update(evidence=str(evidence), inputs=str(evidence / "inputs.json"), receipt=str(evidence / "receipt.json"),
                      descriptor=str(evidence / "resources.json"),
                      reproduce="python3 scripts/maintainer/built_package_twin.py run --verify --cleanup",
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
    run.add_argument("--case", choices=CASES, help="focused diagnostic case; never a full matrix verdict")
    run.add_argument("--verify", action="store_true")
    run.add_argument("--cleanup", action="store_true")
    run.add_argument("--evidence", "--evidence-dir", dest="evidence", type=Path, help="new or empty private evidence directory")
    check = subs.add_parser("verify", help="verify retained evidence against independent runner inputs")
    check.add_argument("--inputs", type=Path, required=True)
    check.add_argument("--receipt", type=Path, required=True)
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
            validate_archive(args.inputs.resolve().parent / "package.tar", inputs)
            verify_receipt(inputs, read_json(args.receipt))
        elif args.operation == "cleanup":
            descriptor = read_json(args.descriptor)
            evidence = args.descriptor.resolve().parent
            runner = Runner(args.descriptor.resolve().parent, descriptor)
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
                else:
                    runner.run(args.verify, args.cleanup)
        emit(args.operation, "passed", "complete", "complete", "none", evidence, args.json)
        return 0
    except (Refused, OSError, ValueError, KeyError, TypeError) as exc:
        reason = str(exc) if isinstance(exc, Refused) else "invalid_or_unavailable_input"
        outcome = "failed" if args.operation == "verify" else "blocked" if args.operation == "check" or reason == "cleanup_active_runtime" else "incomplete"
        stage = runner.stage if runner else "initialization"
        emit(args.operation, outcome, stage, reason, "docker" if args.operation == "check" else "none", evidence, args.json)
        return 1


if __name__ == "__main__":
    sys.exit(main())
