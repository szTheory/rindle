"""Exact run-owned disposal, independent of domain acceptance and repeatable."""
import hashlib
import json
from pathlib import Path
import re
import shutil
from twin_receipt import KIND, decode, keys, require, validate_inputs


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def validate_descriptor(runner):
    d, root = runner.descriptor, runner.evidence
    keys(d, {"schema_version", "kind", "independent_pilot_credit", "run_id", "project", "database", "bucket", "workspace", "evidence", "host_names", "volumes", "network", "image", "compose_sha256", "env_sha256", "inputs_sha256"})
    require(d["schema_version"] == 1 and type(d["schema_version"]) is int and d["kind"] == KIND and d["independent_pilot_credit"] is False, "descriptor_schema")
    require(type(d["run_id"]) is str and re.fullmatch(r"[0-9a-f]{32}", d["run_id"]), "descriptor_run")
    project = "rindle-twin-" + d["run_id"]
    require(d["project"] == project and d["database"] == "twin_" + d["run_id"] and d["bucket"] == "twin-" + d["run_id"], "descriptor_namespace")
    require(d["host_names"] == [project + "-host-1"] and d["volumes"] == [project + "_database", project + "_objects", project + "_retained"] and d["network"] == project + "_default" and d["image"] == project + ":local", "descriptor_resources")
    require(d["evidence"] == str(root) and d["workspace"] == str(root / "workspace") and not (root / "workspace").is_symlink(), "descriptor_path")
    require((root / "workspace").resolve() == root / "workspace", "descriptor_path_escape")
    for name, field in [("inputs.json", "inputs_sha256"), (".env", "env_sha256")]:
        p = root / name
        require(p.is_file() and not p.is_symlink() and sha(p) == d[field], "descriptor_binding")
    inputs = decode((root / "inputs.json").read_text()); validate_inputs(inputs)
    require(inputs["run_id"] == d["run_id"], "descriptor_foreign_run")
    env = dict(line.split("=", 1) for line in (root / ".env").read_text().splitlines())
    require(set(env) == {"TWIN_PROJECT", "TWIN_RUN_ID", "TWIN_DATABASE", "TWIN_BUCKET", "TWIN_SECRET"} and env["TWIN_PROJECT"] == project and env["TWIN_RUN_ID"] == d["run_id"] and env["TWIN_DATABASE"] == d["database"] and env["TWIN_BUCKET"] == d["bucket"] and re.fullmatch(r"[0-9a-f]{48}", env["TWIN_SECRET"]), "descriptor_environment")
    if runner.context.exists():
        require(not any(p.is_symlink() for p in runner.context.rglob("*")), "descriptor_symlink")
        require(sha(runner.context / "compose.yml") == d["compose_sha256"], "descriptor_compose")
        require(hashlib.sha256((runner.context / "Dockerfile").read_bytes() + (runner.context / "compose.yml").read_bytes()).hexdigest() == inputs["build_sha256"], "descriptor_build")
    return d


def containers(runner):
    project = runner.descriptor["project"]
    ids = runner.command(["docker", "ps", "--all", "--no-trunc", "--filter", "label=com.docker.compose.project=" + project, "--quiet"]).split()
    require(len(ids) <= 3 and len(set(ids)) == len(ids), "container_inventory")
    if not ids:
        return []
    values = json.loads(runner.command(["docker", "inspect", *ids]))
    require(type(values) is list and len(values) == len(ids), "container_inventory")
    for c in values:
        labels = c["Config"]["Labels"]
        service = labels.get("com.docker.compose.service")
        require(labels.get("com.docker.compose.project") == project and service in {"host", "postgres", "minio"} and c["Name"] == "/" + project + "-" + service + "-1", "container_ownership")
        if service == "host":
            require(c["State"]["Status"] == "exited" and c["State"]["Running"] is False and c["State"]["Paused"] is False, "cleanup_active_runtime")
    return values


def named(runner, kind):
    return runner.command(["docker", kind, "ls", "--filter", "label=com.docker.compose.project=" + runner.descriptor["project"], "--format", "{{.Name}}"]).split()


def dispose(runner):
    d = validate_descriptor(runner)
    observed = containers(runner)  # No mutation precedes complete liveness observation.
    volumes, networks = named(runner, "volume"), named(runner, "network")
    require(set(volumes) <= set(d["volumes"]) and set(networks) <= {d["network"]}, "foreign_resource")
    owned_ids = {c["Id"] for c in observed}
    for volume in volumes:
        users = runner.command(["docker", "ps", "--all", "--no-trunc", "--filter", "volume=" + volume, "--quiet"]).split()
        require(set(users) <= owned_ids, "foreign_volume_user")
    for network in networks:
        value = json.loads(runner.command(["docker", "network", "inspect", network]))
        require(len(value) == 1 and set(value[0]["Containers"]) <= owned_ids, "foreign_network_user")
    for c in observed:
        containers(runner)
        if c["Config"]["Labels"]["com.docker.compose.service"] != "host" and c["State"]["Running"]:
            runner.command(["docker", "stop", "--time", "15", c["Id"]], timeout=30)
        containers(runner)
        runner.command(["docker", "rm", c["Id"]])  # No --force: a restarted host refuses removal.
    for volume in volumes:
        containers(runner)
        runner.command(["docker", "volume", "rm", volume])
    for network in networks:
        containers(runner)
        runner.command(["docker", "network", "rm", network])
    images = runner.command(["docker", "image", "ls", "--filter", "reference=" + d["image"], "--quiet"]).split()
    require(len(images) <= 1, "image_inventory")
    if images:
        containers(runner)
        runner.command(["docker", "image", "rm", d["image"]])
    containers(runner)
    validate_descriptor(runner)
    if runner.context.exists():
        shutil.rmtree(runner.context)
    require(not containers(runner) and not named(runner, "volume") and not named(runner, "network"), "disposal_residue")
    return True
