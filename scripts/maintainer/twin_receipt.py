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
CASES = ("tus-resume", "purge-absence", "av-repair")
# Fixed 0.2-second H.264/AAC fixture, generated once with FFmpeg bitexact flags.
AV_BASE64 = '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'
AV_RECIPE = "7adba05438de4278fad4a4e708b2bfe66b1f35cbf1e80469258fcc886d5725b8"
AV_SHA256 = hashlib.sha256(base64.b64decode(AV_BASE64)).hexdigest()

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
            (value["schema_version"] == 2 and value["scenario"] in CASES), "scenario_identity")
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
    verify_empty_inventory(receipt["inventory"], after["job_id"], 3)
    require((before["sequence"], after["sequence"], receipt["inventory"]["sequence"]) == (1, 2, 3), "observation_order")
    return True




def verify_empty_inventory(inventory, purge_id, sequence):
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
            require(job["id"] == purge_id, "purge_identity")
        seen.add(job["queue"]); ids.add(job["id"])
    integer(inventory["sequence"], sequence, sequence)
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
    fields = {"tus-resume": {"clients", "result", "object_keys"},
              "purge-absence": {"before", "absence", "after", "inventory"},
              "av-repair": {"failure", "repair", "output", "versions", "object_keys"}}
    require(receipt.get("case_id") in fields, "case_identity")
    keys(receipt, {"schema_version", "kind", "independent_pilot_credit", "inputs", "case_id",
                   "outcome", "reason", "stage", "dependency", "runtime", "isolation", "host_exited"}
                   | fields[receipt["case_id"]])
    labeled(receipt)
    integer(receipt["schema_version"], 2, 2)
    require(receipt["inputs"] == inputs, "input_identity")
    require(receipt["case_id"] == inputs["scenario"], "case_identity")
    require(receipt["outcome"] == receipt["reason"] == receipt["stage"] == "complete"
            and receipt["dependency"] == "none", "incomplete_receipt")
    require(receipt["host_exited"] is True, "runtime_not_stopped")
    health(receipt["runtime"], inputs)
    keys(receipt["isolation"], {"image_id", "mounts_verified"})
    text(receipt["isolation"]["image_id"], r"sha256:[0-9a-f]{64}")
    require(receipt["isolation"]["mounts_verified"] is True, "runtime_mounts")
    if receipt["case_id"] == "tus-resume":
        return verify_tus_case(inputs, receipt)
    if receipt["case_id"] == "purge-absence":
        return verify_purge_case(receipt)
    return verify_av_case(inputs, receipt)


def verify_tus_case(inputs, receipt):
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



def verify_purge_case(receipt):
    before, absence, after = (receipt[k] for k in ("before", "absence", "after"))
    keys(before, {"asset_id", "source_key", "job_id", "attempt", "state", "outcome", "error_count",
                  "asset_retained", "source_present", "ready_variant_count", "variant_deletes_before_failure",
                  "paused", "running", "stimuli", "boot_id", "sequence"})
    keys(absence, {"asset_id", "source_key", "job_id", "head", "asset_retained", "paused", "running",
                   "attempt", "state", "error_count", "sequence"})
    keys(after, {"outcome", "job_id", "attempt", "state", "asset_absent", "error_count", "boot_id", "fault_claims", "sequence"})
    identity(before["asset_id"])
    text(before["source_key"], r"elixir-twin-profile/" + re.escape(before["asset_id"]) + r"/[0-9a-f-]{36}\.png")
    identity(before["source_key"].split("/")[-1][:-4])
    for value in (before, absence, after):
        integer(value["job_id"], 1)
        integer(value["error_count"], 1, 1)
        integer(value["sequence"], 1, 4)
    for value in (before, absence):
        integer(value["attempt"], 1, 1)
        integer(value["running"], 0, 0)
        require(value["paused"] is True and value["asset_retained"] is True
                and value["state"] == "retryable", "raced_barrier")
    require(before["outcome"] == "paused" and before["source_present"] is True, "retained_source")
    integer(before["ready_variant_count"], 1, 1)
    integer(before["variant_deletes_before_failure"], 1, 1)
    keys(before["stimuli"], {"upload", "attach", "detach"})
    for count in before["stimuli"].values():
        integer(count, 1, 1)
    require(all(absence[k] == before[k] for k in ("asset_id", "source_key", "job_id"))
            and absence["head"] == "not_found", "absence_not_authoritative")
    integer(after["attempt"], 2, 2)
    integer(after["fault_claims"], 1, 1)
    require(after["job_id"] == before["job_id"] and after["state"] == after["outcome"] == "completed"
            and after["asset_absent"] is True, "job_continuity")
    require(before["boot_id"] == after["boot_id"] == receipt["runtime"]["boot_id"], "boot_identity")
    verify_empty_inventory(receipt["inventory"], after["job_id"], 4)
    require((before["sequence"], absence["sequence"], after["sequence"]) == (1, 2, 3), "observation_order")
    return True



def verify_av_case(inputs, receipt):
    failure, repair, output = (receipt[k] for k in ("failure", "repair", "output"))
    keys(failure, {"before", "failed", "attempts", "elapsed_ms", "deadline_ms", "remaining_ms", "input_decoded"})
    before, failed = failure["before"], failure["failed"]
    keys(before, {"asset_id", "session_id", "source_key", "job_id", "variant_id", "variant_name", "recipe_digest",
                  "max_attempts", "source_video", "source_audio", "source_duration_ms", "upload_stimuli", "boot_id"})
    for key in ("asset_id", "session_id", "variant_id", "boot_id"):
        identity(before[key])
    require(len({before[k] for k in ("asset_id", "session_id", "variant_id")}) == 3, "domain_identity")
    require(before["boot_id"] == receipt["runtime"]["boot_id"], "boot_identity")
    require(before["source_video"] is True and before["source_audio"] is True and failure["input_decoded"] is True, "invalid_av_source")
    require(before["variant_name"] == "web_720p" and before["recipe_digest"] == AV_RECIPE, "av_recipe")
    integer(before["source_duration_ms"], 100, 1000)
    integer(before["upload_stimuli"], 1, 1)
    integer(before["max_attempts"], 5, 5)
    integer(before["job_id"], 1)
    text(before["source_key"], r"elixir-twin-avprofile/" + re.escape(before["asset_id"]) + r"/[0-9a-f-]{36}\.mp4")
    identity(before["source_key"].split("/")[-1][:-4])
    keys(failed, {"job_id", "attempt", "state", "error_attempts", "variant_id", "variant_state", "diagnostic", "fault_downloads", "processor_reason"})
    require(failed["job_id"] == before["job_id"] and failed["variant_id"] == before["variant_id"], "av_job_identity")
    integer(failed["attempt"], 5, 5); integer(failed["fault_downloads"], 5, 5)
    require(failed["state"] == "discarded" and failed["variant_state"] == "failed"
            and failed["diagnostic"] == "failed_work" and failed["processor_reason"] == "unsupported_codec", "av_failure_unproven")
    require(type(failed["error_attempts"]) is list and len(failed["error_attempts"]) == 5, "av_attempts")
    for attempt in failed["error_attempts"]:
        integer(attempt, 1, 5)
    require(sorted(failed["error_attempts"]) == [1,2,3,4,5], "av_attempts")
    trail = failure["attempts"]
    require(type(trail) is list and 5 <= len(trail) <= 32, "av_attempt_observations")
    seen = set()
    for item in trail:
        keys(item, {"job_id", "attempt", "state", "error_attempts", "fault_downloads"})
        require(item["job_id"] == before["job_id"] and item["state"] in {"available", "executing", "retryable", "discarded"}, "av_attempt_observations")
        integer(item["attempt"], 0, 5); integer(item["fault_downloads"], 0, 5)
        require(type(item["error_attempts"]) is list and len(item["error_attempts"]) <= item["attempt"], "av_attempts")
        for attempt in item["error_attempts"]:
            integer(attempt, 1, 5)
        require(sorted(item["error_attempts"]) == list(range(1, len(item["error_attempts"]) + 1)), "av_attempts")
        if item["state"] in {"retryable", "discarded"}:
            seen.update(item["error_attempts"])
    require(seen == {1,2,3,4,5} and trail[-1]["state"] == "discarded", "av_attempt_observations")
    integer(failure["elapsed_ms"], 1, 599999); integer(failure["deadline_ms"], 600000, 600000)
    integer(failure["remaining_ms"], 1, 599999)
    require(failure["elapsed_ms"] + failure["remaining_ms"] == 600000, "av_deadline")
    keys(repair, {"asset_id", "variant_id", "source_key", "variant_key", "source_sha256", "output_sha256", "asset_state", "variant_state",
                  "discarded_job_id", "new_job_id", "new_job_state", "new_job_attempt", "selected", "enqueued", "skipped", "errors", "fault_restored", "error_cleared"})
    require(all(repair[k] == before[k] for k in ("asset_id", "variant_id", "source_key")), "av_repair_identity")
    require(repair["discarded_job_id"] == before["job_id"], "av_job_identity")
    integer(repair["new_job_id"], 1)
    require(repair["new_job_id"] != before["job_id"] and repair["new_job_state"] == "completed", "repair_not_new")
    for key in ("selected", "enqueued", "new_job_attempt"):
        integer(repair[key], 1, 1)
    for key in ("skipped", "errors"):
        integer(repair[key], 0, 0)
    require(repair["fault_restored"] is True and repair["error_cleared"] is True
            and repair["asset_state"] == repair["variant_state"] == "ready", "repair_terminal_state")
    require(repair["source_sha256"] == inputs["fixture_sha256"] == AV_SHA256, "source_checksum")
    text(repair["output_sha256"], r"[0-9a-f]{64}")
    require(repair["output_sha256"] != AV_SHA256, "derivative_checksum")
    expected_key = "Elixir.Twin.AVProfile/" + before["asset_id"] + "/web_720p-" + AV_RECIPE + ".mp4"
    require(repair["variant_key"] == expected_key and receipt["object_keys"] == sorted([before["source_key"], expected_key]), "undeclared_objects")
    keys(output, {"video_codec", "audio_codec", "width", "height", "duration_ms", "fully_decoded"})
    require(output["fully_decoded"] is True and output["video_codec"] == "h264" and output["audio_codec"] == "aac", "av_output_decode")
    integer(output["width"], 1280, 1280); integer(output["height"], 720, 720); integer(output["duration_ms"], 100, 1000)
    keys(receipt["versions"], {"ffmpeg", "ffprobe"})
    for version in receipt["versions"].values():
        text(version, r"[0-9][A-Za-z0-9.+~_-]{0,79}")
        require(int(version.split(".")[0]) >= 6, "media_version_floor")
    return True


def safe_diagnostic(observation):
    """Export fixed codes only; arbitrary access-log/telemetry/body fields are discarded."""
    stage = observation.get("stage")
    return {"kind": KIND, "independent_pilot_credit": False,
            "stage": stage if stage in STAGES else "initialization",
            "reason": "complete" if observation.get("reason") == "complete" else "operation_failed",
            "dependency": observation.get("dependency") if observation.get("dependency") in {"none", "docker", "database", "storage"} else "none"}
