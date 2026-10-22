"""Finite typed contract for maintainer-operated synthetic twin evidence.

Expected identities come from separately retained runner inputs. Consistency is not
an authentication mechanism for a wholly fabricated trusted inputs/receipt pair.
"""
import json
import base64
import hashlib
import re
import uuid

SCENARIO = "image-delete-once-between-attempts"
PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVQI12P4//8/AAX+Av7cRHQGAAAAAElFTkSuQmCC"
CASES = ("tus-resume",)

TUS_SHA256 = hashlib.sha256(base64.b64decode(PNG)).hexdigest()
# Exact image recipe declared by Twin.Profile, measured in the packaged host.
THUMB_KEY = "thumb-3a9ab2f60b2d26217471f22cc329252acba546c6341111a3ef89a8d9978d30a7.jpeg"
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
    integer(value["schema_version"], 1, 2)
    require((value["schema_version"] == 1 and value["scenario"] == SCENARIO) or
            (value["schema_version"] == 2 and value["scenario"] == "tus-resume"), "scenario_identity")
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
    require(type(inputs) is dict and type(receipt) is dict, "record_keys")
    if inputs.get("schema_version") == 2 or receipt.get("schema_version") == 2:
        return verify_case_receipt(inputs, receipt)
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
    keys(inventory, {"domain", "jobs", "temp_files", "fault_claims", "writers_paused", "objects", "multipart", "versioning_disabled", "processes", "complete", "sequence", "relations", "fixture_rows", "schema_migration_rows", "peer_rows", "listing_complete"})
    require(all(inventory[k] is True for k in ("complete", "writers_paused", "versioning_disabled")), "unknown_inventory")
    for k in ("objects", "multipart", "temp_files", "processes"):
        integer(inventory[k], 0, 0)
    integer(inventory["fault_claims"], 1, 1)
    require(inventory["listing_complete"] is True, "incomplete_listing")
    require(inventory["relations"] == {"public": ["oban_jobs", "oban_peers", "schema_migrations", "twin_fault_counters"], "rindle": sorted(DOMAIN)}, "relation_inventory")
    integer(inventory["fixture_rows"], 2, 2)
    integer(inventory["schema_migration_rows"], 1, 1)
    integer(inventory["peer_rows"], 0, 1)
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



def validate_tus_clients(first, second, size):
    keys(first, {"pid", "create_status", "patch_status", "offset"})
    keys(second, {"pid", "head_status", "head_offset", "head_cache", "wrong_status",
                  "after_wrong_status", "after_wrong_offset", "patch_status", "final_offset"})
    for record in (first, second):
        for key, value in record.items():
            if key != "head_cache":
                integer(value, 0)
        integer(record["pid"], 1)
    require(first["pid"] != second["pid"], "client_identity")
    require(first["create_status"] == 201 and first["patch_status"] == 204
            and 0 < first["offset"] < size, "nonfinal_patch")
    require(second["head_status"] == 204 and second["head_cache"] == "no-store"
            and second["head_offset"] == first["offset"], "head_authority")
    require(second["wrong_status"] == 409 and second["after_wrong_status"] == 204
            and second["after_wrong_offset"] == first["offset"], "wrong_offset_advanced")
    require(second["patch_status"] == 204 and second["final_offset"] == size, "resume_incomplete")


def verify_case_receipt(inputs, receipt):
    validate_inputs(inputs)
    require(inputs["schema_version"] == 2, "case_inputs")
    keys(receipt, {"schema_version", "kind", "independent_pilot_credit", "inputs", "case_id",
                   "outcome", "reason", "stage", "dependency", "clients", "result", "object_keys",
                   "runtime", "isolation", "host_exited"})
    labeled(receipt)
    integer(receipt["schema_version"], 2, 2)
    require(receipt["inputs"] == inputs, "input_identity")
    require(receipt["case_id"] == inputs["scenario"] == "tus-resume", "case_identity")
    require(receipt["outcome"] == receipt["reason"] == receipt["stage"] == "complete"
            and receipt["dependency"] == "none", "incomplete_receipt")
    require(receipt["host_exited"] is True, "runtime_not_stopped")
    health(receipt["runtime"], inputs)
    keys(receipt["isolation"], {"image_id", "mounts_verified"})
    text(receipt["isolation"]["image_id"], r"sha256:[0-9a-f]{64}")
    require(receipt["isolation"]["mounts_verified"] is True, "runtime_mounts")
    clients = receipt["clients"]
    keys(clients, {"first", "second", "first_exited", "second_exited"})
    require(clients["first_exited"] is True and clients["second_exited"] is True, "client_not_exited")
    size = len(base64.b64decode(PNG))
    validate_tus_clients(clients["first"], clients["second"], size)
    result = receipt["result"]
    keys(result, {"outcome", "session_id", "asset_id", "session_state", "asset_state", "source_key",
                  "variant_keys", "checksum_sha256", "sessions", "assets", "upload_stimuli", "offset", "boot_id"})
    for key in ("session_id", "asset_id", "boot_id"):
        identity(result[key])
    require(result["session_id"] != result["asset_id"] and result["boot_id"] == receipt["runtime"]["boot_id"], "domain_identity")
    for key in ("sessions", "assets", "upload_stimuli"):
        integer(result[key], 1, 1)
    integer(result["offset"], size, size)
    require(result["outcome"] == result["asset_state"] == "ready"
            and result["session_state"] == "completed", "terminal_state")
    require(result["checksum_sha256"] == inputs["fixture_sha256"] == TUS_SHA256, "source_checksum")
    prefix = re.escape(result["asset_id"])
    text(result["source_key"], r"elixir-twin-profile/" + prefix + r"/[0-9a-f-]{36}")
    identity(result["source_key"].split("/")[-1])
    expected_variants = ["Elixir.Twin.Profile/" + result["asset_id"] + "/" + THUMB_KEY]
    require(result["variant_keys"] == expected_variants, "undeclared_variants")
    expected_objects = sorted([result["source_key"], *expected_variants])
    require(receipt["object_keys"] == expected_objects, "undeclared_objects")
    return True


def safe_diagnostic(observation):
    """Export fixed codes only; arbitrary access-log/telemetry/body fields are discarded."""
    stage = observation.get("stage")
    return {"kind": KIND, "independent_pilot_credit": False,
            "stage": stage if stage in STAGES else "initialization",
            "reason": "complete" if observation.get("reason") == "complete" else "operation_failed",
            "dependency": observation.get("dependency") if observation.get("dependency") in {"none", "docker", "database", "storage"} else "none"}
