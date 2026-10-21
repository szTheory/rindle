"""Finite typed contract for maintainer-operated synthetic twin evidence.

Expected identities come from separately retained runner inputs. Consistency is not
an authentication mechanism for a wholly fabricated trusted inputs/receipt pair.
"""
import json
import re
import uuid

SCENARIO = "image-delete-once-between-attempts"
KIND = "maintainer-operated-synthetic"
MAX_BYTES = 65_536
MAX_ID = 2**63 - 1
DOMAIN = {"media_assets", "media_attachments", "media_processing_runs", "media_provider_assets", "media_upload_sessions", "media_variants", "rindle_migration_versions"}
HASHES = {"package_tar_sha256", "package_metadata_sha256", "package_tree_sha256", "host_sha256", "lock_sha256", "config_sha256", "contract_sha256", "fixture_sha256", "build_sha256"}
STAGES = {"initialization", "package", "build", "services", "retry-barrier", "restart", "domain-cleanup", "disposal", "complete"}


class Refused(Exception):
    pass


def require(ok, reason):
    if not ok:
        raise Refused(reason)


def decode(data):
    require(isinstance(data, str) and len(data.encode()) <= MAX_BYTES, "json_size")
    def unique(pairs):
        value = {}
        for k, v in pairs:
            require(k not in value, "duplicate_json_key")
            value[k] = v
        return value
    return json.loads(data, object_pairs_hook=unique, parse_constant=lambda _: require(False, "nonfinite_json"))


def keys(value, expected):
    require(type(value) is dict and set(value) == set(expected), "record_keys")


def integer(value, low=0, high=MAX_ID):
    require(type(value) is int and low <= value <= high, "integer_bounds")


def text(value, pattern):
    require(type(value) is str and len(value) <= 256 and re.fullmatch(pattern, value) is not None, "string_bounds")


def boolean(value):
    require(type(value) is bool, "boolean_type")


def identity(value):
    text(value, r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
    require(str(uuid.UUID(value)) == value, "uuid_identity")


def labeled(value):
    require(value["kind"] == KIND and value["independent_pilot_credit"] is False, "synthetic_identity")


def validate_inputs(value):
    keys(value, HASHES | {"schema_version", "kind", "independent_pilot_credit", "scenario", "run_id", "source_sha", "toolchain"})
    labeled(value)
    integer(value["schema_version"], 1, 1)
    require(value["scenario"] == SCENARIO, "scenario_identity")
    text(value["run_id"], r"[0-9a-f]{32}")
    text(value["source_sha"], r"[0-9a-f]{40}")
    for k in HASHES:
        text(value[k], r"[0-9a-f]{64}")
    require(value["toolchain"] == {"elixir": "1.17.3", "otp": "27.3.4.15", "oban": "2.21.1", "phoenix": "1.8.12"}, "supported_toolchain")


def barrier_ok(queue, job):
    return (queue == {"paused": True, "running": 0} and job.get("state") == "retryable"
            and type(job.get("attempt")) is int and job["attempt"] == 1
            and type(job.get("error_count")) is int and job["error_count"] > 0)


def health(value, inputs):
    keys(value, {"boot_id", "elixir", "otp", "oban", "phoenix", "origin", "lock_sha256"})
    identity(value["boot_id"])
    require({k: value[k] for k in inputs["toolchain"]} == inputs["toolchain"], "runtime_version")
    require(value["lock_sha256"] == inputs["lock_sha256"], "runtime_lock")
    require(value["origin"] == "/twin/_build/prod/lib/rindle/ebin/Elixir.Rindle.beam", "runtime_origin")


def verify_receipt(inputs, receipt):
    validate_inputs(inputs)
    keys(receipt, {"schema_version", "kind", "independent_pilot_credit", "inputs", "outcome", "reason", "stage", "dependency",
                   "before", "after", "old_runtime", "new_runtime", "old_container", "new_container", "old_exited", "new_exited", "inventory", "capabilities", "isolation"})
    labeled(receipt)
    integer(receipt["schema_version"], 1, 1)
    validate_inputs(receipt["inputs"])
    require(receipt["inputs"] == inputs, "input_identity")
    require(receipt["outcome"] == "complete" and receipt["reason"] == "complete" and receipt["stage"] == "complete" and receipt["dependency"] == "none", "incomplete_receipt")
    before, after = receipt["before"], receipt["after"]
    keys(before, {"asset_id", "source_key", "job_id", "attempt", "state", "outcome", "error_count", "asset_retained", "source_present", "ready_variant_count", "variant_deletes_before_failure", "paused", "running", "stimuli", "boot_id", "sequence"})
    keys(after, {"outcome", "job_id", "attempt", "state", "asset_absent", "error_count", "boot_id", "fault_claims", "sequence"})
    identity(before["asset_id"])
    identity(before["boot_id"])
    identity(after["boot_id"])
    text(before["source_key"], r"elixir-twin-profile/" + re.escape(before["asset_id"]) + r"/[0-9a-f-]{36}\.png")
    identity(before["source_key"].split("/")[-1][:-4])
    for value in (before, after):
        integer(value["job_id"], 1)
        integer(value["attempt"], 1, 2)
        integer(value["error_count"], 1, 1)
        integer(value["sequence"], 1, 3)
    for key in ("paused", "asset_retained", "source_present"):
        boolean(before[key]); require(before[key], "retained_source")
    integer(before["running"], 0, 0)
    integer(before["ready_variant_count"], 1, 1)
    integer(before["variant_deletes_before_failure"], 1, 1)
    require(before["outcome"] == "paused" and barrier_ok({"paused": before["paused"], "running": before["running"]}, before), "raced_barrier")
    keys(before["stimuli"], {"upload", "attach", "detach"})
    for count in before["stimuli"].values():
        integer(count, 1, 1)
    require(before["job_id"] == after["job_id"] and after["attempt"] == 2 and after["state"] == "completed" and after["outcome"] == "completed", "job_continuity")
    require(after["asset_absent"] is True, "asset_residue")
    integer(after["fault_claims"], 1, 1)
    health(receipt["old_runtime"], inputs); health(receipt["new_runtime"], inputs)
    require(receipt["old_runtime"]["boot_id"] == before["boot_id"] and receipt["new_runtime"]["boot_id"] == after["boot_id"] and before["boot_id"] != after["boot_id"], "boot_identity")
    for k in ("old_container", "new_container"):
        text(receipt[k], r"[0-9a-f]{64}")
    require(receipt["old_container"] != receipt["new_container"] and receipt["old_exited"] is True and receipt["new_exited"] is True, "runtime_replacement")
    keys(receipt["isolation"], {"image_id", "mounts_verified"})
    text(receipt["isolation"]["image_id"], r"sha256:[0-9a-f]{64}")
    require(receipt["isolation"]["mounts_verified"] is True, "runtime_mounts")
    caps = receipt["capabilities"]
    keys(caps, {"ffmpeg_major", "ffprobe_major", "database_schema", "image_exercised", "storage_exercised", "av_exercised", "doctor_status"})
    for k in ("ffmpeg_major", "ffprobe_major"):
        integer(caps[k], 6, 99)
    require(all(caps[k] is True for k in ("database_schema", "image_exercised", "storage_exercised")) and caps["av_exercised"] is False and caps["doctor_status"] == "not_used_known_migration_ledger_issue", "capability_claim")
    inventory = receipt["inventory"]
    keys(inventory, {"domain", "jobs", "temp_files", "fault_claims", "writers_paused", "objects", "multipart", "versioning_disabled", "processes", "complete", "sequence"})
    require(all(inventory[k] is True for k in ("complete", "writers_paused", "versioning_disabled")), "unknown_inventory")
    for k in ("objects", "multipart", "temp_files", "processes"):
        integer(inventory[k], 0, 0)
    integer(inventory["fault_claims"], 1, 1)
    keys(inventory["domain"], DOMAIN)
    for k, n in inventory["domain"].items():
        integer(n, 1 if k == "rindle_migration_versions" else 0, 1 if k == "rindle_migration_versions" else 0)
    jobs = inventory["jobs"]
    require(type(jobs) is list and len(jobs) == 3, "job_inventory")
    expected = {"rindle_promote": 1, "rindle_process": 1, "rindle_purge": 2}
    seen, ids = set(), set()
    for job in jobs:
        keys(job, {"id", "state", "attempt", "queue"})
        integer(job["id"], 1)
        require(job["queue"] in expected and job["queue"] not in seen and job["id"] not in ids, "job_inventory_identity")
        integer(job["attempt"], expected[job["queue"]], expected[job["queue"]])
        require(job["state"] == "completed", "job_residue")
        if job["queue"] == "rindle_purge":
            require(job["id"] == after["job_id"], "purge_identity")
        seen.add(job["queue"]); ids.add(job["id"])
    require((before["sequence"], after["sequence"], inventory["sequence"]) == (1, 2, 3), "observation_order")
    return True


def safe_diagnostic(observation):
    """Export fixed codes only; arbitrary access-log/telemetry/body fields are discarded."""
    stage = observation.get("stage")
    return {"kind": KIND, "independent_pilot_credit": False,
            "stage": stage if stage in STAGES else "initialization",
            "reason": "complete" if observation.get("reason") == "complete" else "operation_failed",
            "dependency": observation.get("dependency") if observation.get("dependency") in {"none", "docker", "database", "storage"} else "none"}
