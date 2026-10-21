"""Source-bound evidence; all subprocess owners come from the frozen tree."""
import argparse
import base64
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

TOOLCHAIN = "elixir-1.17.3/otp-27.3.4.15"
ELIXIR_PROBE = ('otp = :code.root_dir() |> Path.join("releases/" <> System.otp_release() <> '
                '"/OTP_VERSION") |> File.read!() |> String.trim(); '
                'IO.puts("elixir-#{System.version()}/otp-#{otp}")')
PREPARE = [["mix", "local.hex", "--force"], ["mix", "local.rebar", "--force"],
           ["mix", "deps.get", "--check-locked"], ["mix", "compile", "--warnings-as-errors"]]
FOCUSED = ["mix", "test", "test/install_smoke/quality_signal_policy_test.exs", "--seed", "0"]
CANONICAL_COVERAGE = ["mix", "coveralls.multiple", "--type", "local", "--type", "json"]
LIMIT = 4 * 1024 * 1024


class Rejected(Exception):
    """A bounded, public diagnostic code, never raw child output."""


def require(condition, reason):
    if not condition:
        raise Rejected(reason)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def decode_json(data):
    def unique(items):
        value = {}
        for key, item in items:
            require(key not in value, "duplicate_json_key")
            value[key] = item
        return value
    value = json.loads(data, object_pairs_hook=unique,
                       parse_constant=lambda _: (_ for _ in ()).throw(Rejected("nonfinite_json")))
    require(isinstance(value, dict), "json_object_required")
    return value


def read_json(path):
    path = Path(path)
    require(path.is_file() and path.stat().st_size <= 32 * 1024 * 1024, "missing_or_oversized_json")
    return decode_json(path.read_bytes())


def git(root, *argv):
    process = subprocess.run(["git", *argv], cwd=root, capture_output=True, timeout=60)
    require(process.returncode == 0, "source_git_failure")
    return process.stdout.decode().strip()


def source_subject(root, subject_file):
    subject = read_json(subject_file)
    require(set(subject) == {"subject_sha", "source_tree"}, "invalid_subject_schema")
    require(all(isinstance(subject[key], str) and re.fullmatch(r"[0-9a-f]{40}", subject[key])
                for key in subject), "invalid_subject_identity")
    sha = subject["subject_sha"]
    require(git(root, "rev-parse", sha + "^{tree}") == subject["source_tree"], "subject_tree_mismatch")
    git(root, "merge-base", "--is-ancestor", sha, "HEAD")
    # Inspect every intervening commit, so a source mutation followed by a revert
    # cannot masquerade as an evidence-only history through a zero net diff.
    for commit in git(root, "rev-list", sha + "..HEAD").splitlines():
        names = git(root, "diff-tree", "-m", "--no-commit-id", "--name-only", "-r", commit)
        require(all(name.startswith(".planning/") for name in names.splitlines()), "source_history_drift")
    dirty = git(root, "diff", "--name-only", "HEAD").splitlines()
    untracked = git(root, "ls-files", "--others", "--exclude-standard").splitlines()
    require(all(name.startswith(".planning/") for name in dirty + untracked), "dirty_or_untracked_source")
    return subject


def execute(argv, cwd, env=None, budget=300):
    begin = time.monotonic()
    with tempfile.TemporaryFile() as output:
        child = subprocess.Popen(argv, cwd=cwd, env=env, stdout=output,
                                 stderr=subprocess.STDOUT, start_new_session=True)
        reason = None
        while child.poll() is None:
            if time.monotonic() - begin >= budget:
                reason = "command_timeout"
            elif os.fstat(output.fileno()).st_size > LIMIT:
                reason = "command_output_limit"
            if reason:
                os.killpg(child.pid, signal.SIGTERM)
                try:
                    child.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGKILL)
                    child.wait()
                raise Rejected(reason)
            time.sleep(0.025)
        output.seek(0)
        data = output.read(LIMIT + 1)
    require(len(data) <= LIMIT, "command_output_limit")
    return child.returncode, data, round(time.monotonic() - begin, 3)


def sanitized(data):
    # Owner argv are fixed and contain no credentials. Redact inherited secret
    # values before publishing diagnostics, while retaining the raw output hash.
    for name, value in os.environ.items():
        if len(value) > 4 and re.search(r"TOKEN|SECRET|PASSWORD|API_KEY", name):
            data = data.replace(value.encode(), b"[REDACTED]")
    return data


class Artifacts:
    def __init__(self, receipt, create=False):
        self.root = Path(str(Path(receipt).resolve()) + ".artifacts")
        self.count = 0
        if create:
            self.root.mkdir(mode=0o700)
        else:
            require(not self.root.is_symlink(), "symlink_artifact_directory")

    def run(self, argv, cwd, env=None, budget=300):
        status, raw, elapsed = execute(argv, cwd, env, budget)
        data = sanitized(raw)
        path = self.root / f"{self.count:03d}.txt"
        self.count += 1
        with path.open("xb") as output:
            output.write(data)
        return {"argv": argv, "exit_status": status, "artifact": path.name,
                "output_sha256": digest(data), "raw_output_sha256": digest(raw),
                "output_bytes": len(data), "duration_seconds": elapsed}

    def log(self, record):
        require(isinstance(record, dict) and re.fullmatch(r"[0-9]{3}\.(?:log|txt)", record.get("artifact", "")),
                "invalid_command_artifact")
        require(type(record.get("exit_status")) is int and -128 <= record["exit_status"] <= 255,
                "invalid_command_exit")
        path = self.root / record["artifact"]
        # Historical receipts keep their original bytes and digests after the
        # retained output moves to hygiene-safe .txt names. Never fall back
        # around an existing original, including a dangling symlink.
        if path.suffix == ".log" and not path.exists() and not path.is_symlink():
            path = path.with_suffix(".txt")
        require(path.is_file() and not path.is_symlink() and path.stat().st_size <= LIMIT,
                "missing_command_output")
        data = path.read_bytes()
        require(type(record.get("output_bytes")) is int and record["output_bytes"] >= 0,
                "invalid_output_size")
        require(type(record.get("duration_seconds")) in (int, float) and record["duration_seconds"] >= 0,
                "invalid_command_duration")
        require(digest(data) == record.get("output_sha256") and len(data) == record.get("output_bytes"),
                "command_output_digest_mismatch")
        return data.decode(errors="replace")

    def payload(self, name, path):
        target = self.root / name
        with target.open("xb") as output:
            output.write(Path(path).read_bytes())
        return {"artifact": name, "sha256": digest(target.read_bytes())}

    def read_payload(self, reference, name):
        require(reference.get("artifact") == name, "invalid_payload_name")
        path = self.root / name
        require(path.is_file() and not path.is_symlink(), "missing_payload")
        data = path.read_bytes()
        require(digest(data) == reference.get("sha256"), "payload_digest_mismatch")
        return path


@contextlib.contextmanager
def pinned_checkout(root, subject):
    with tempfile.TemporaryDirectory(prefix="rindle-frozen-evidence-") as scratch:
        scratch = Path(scratch)
        checkout = scratch / "source"
        status, _, _ = execute(["git", "clone", "--quiet", "--local", "--no-hardlinks", "--no-checkout",
                                str(root), str(checkout)], root, budget=60)
        require(status == 0, "pinned_clone_failed")
        require(execute(["git", "checkout", "--quiet", "--detach", subject["subject_sha"]], checkout,
                        budget=60)[0] == 0, "pinned_checkout_failed")
        require(git(checkout, "rev-parse", "HEAD") == subject["subject_sha"], "pinned_head_mismatch")
        env = dict(os.environ)
        for name in ("MIX_BUILD_PATH", "MIX_DEPS_PATH", "MIX_ARCHIVES", "MIX_BIN", "HEX_OFFLINE",
                     "PLT_DIR", "DIALYZER_LOG", "GH_TOKEN", "GITHUB_TOKEN"):
            env.pop(name, None)
        env.update(MIX_ENV="test", MIX_HOME=str(scratch / "mix"), HEX_HOME=str(scratch / "hex"))
        yield checkout, scratch, env


def runtime(artifacts, root, result):
    elixir = artifacts.run(["elixir", "--eval", ELIXIR_PROBE], root, budget=30)
    node = artifacts.run(["node", "--version"], root, budget=30)
    result["runtime"] = {"elixir": elixir, "node": node}
    result["toolchain"] = artifacts.log(elixir).strip()
    result["node_version"] = artifacts.log(node).strip()
    require(elixir["exit_status"] == 0 and result["toolchain"] == TOOLCHAIN, "unsupported_toolchain")
    require(node["exit_status"] == 0 and re.fullmatch(r"v20\.[0-9]+\.[0-9]+", result["node_version"]),
            "unsupported_node")


def prepare(artifacts, checkout, env, result):
    result["preparation"] = []
    for argv in PREPARE:
        record = artifacts.run(argv, checkout, env)
        result["preparation"].append(record)
        if record["exit_status"] != 0:
            result.update(outcome="open", reason="preparation_first_red")
            return False
    return True


def plt_inventory(path):
    require(path.is_dir() and not path.is_symlink(), "missing_plt_output")
    files = []
    for item in sorted(path.rglob("*")):
        require(not item.is_symlink(), "symlink_plt_output")
        if item.is_file():
            files.append({"path": str(item.relative_to(path)), "bytes": item.stat().st_size,
                          "sha256": digest(item.read_bytes())})
    require(files and all(item["bytes"] > 0 for item in files), "empty_plt_output")
    return {"files": files, "sha256": digest(canonical(files))}


def collect_dialyzer(artifacts, checkout, scratch, env, result):
    result["analyses"] = []
    if not prepare(artifacts, checkout, env, result):
        return
    plt = checkout / "priv/plts"
    for mode, budget in (("fresh", 5400), ("restored", 1800)):
        record = artifacts.run(["bash", "scripts/ci/run_nightly_dialyzer.sh", mode], checkout, env, budget)
        record["mode"] = mode
        result["analyses"].append(record)
        if record["exit_status"] != 0:
            result.update(outcome="open", reason=mode + "_analysis_first_red")
            return
        record["output_plt"] = plt_inventory(plt)
        if mode == "fresh":
            backup = scratch / "saved-plt"
            shutil.copytree(plt, backup)
            shutil.rmtree(plt)
            shutil.copytree(backup, plt)
            result["restored_input_plt"] = plt_inventory(plt)
    result["outcome"] = "complete"


def relative_evidence(root, path):
    path = Path(path).resolve()
    require(path.is_relative_to(root / ".planning"), "evidence_path_outside_planning")
    return str(path.relative_to(root))


def collect_async(root, artifacts, checkout, env, result, args):
    target = Path(args.jsonl or root / ".planning/evidence/async-isolation/136-async-isolation.jsonl").resolve()
    reference = relative_evidence(root, target)
    require(not target.exists() and not target.is_symlink(), "async_target_not_new")
    target.parent.mkdir(parents=True, exist_ok=True)
    if not prepare(artifacts, checkout, env, result):
        return
    env = {**env, "RINDLE_ASYNC_EVIDENCE_DIR": str(target.parent)}
    result["runner"] = artifacts.run(["bash", "scripts/maintainer/async_isolation_evidence.sh",
                                       "--report", str(target)], checkout, env, budget=14400)
    result["jsonl"] = artifacts.payload("async.jsonl", target)
    result["evidence_file"] = {"path": reference, "sha256": digest(target.read_bytes())}
    status, data, _ = execute(["bash", "scripts/maintainer/verify_async_isolation_receipt.sh",
                               "--report", str(target)], checkout, env, budget=60)
    require(status == 0, "async_owner_verification_failed")
    verdict = json.loads(data)
    result["async_verdict"] = verdict
    result["outcome"] = "complete" if verdict["status"] == "complete" else "open"
    if result["outcome"] == "open":
        result["reason"] = "async_first_red"


def collect_bootstrap(artifacts, checkout, env, result):
    target = artifacts.root / "bootstrap.json"
    result["runner"] = artifacts.run(["bash", "scripts/maintainer/verify_contributor_bootstrap.sh",
        "--run", "--full", "--subject-sha", result["subject_sha"], "--receipt", str(target)],
        checkout, env, budget=1260)
    # The owner already created this immutable payload in the fresh artifact directory.
    require(target.is_file(), "bootstrap_owner_receipt_missing")
    result["bootstrap"] = {"artifact": target.name, "sha256": digest(target.read_bytes())}
    inner = read_json(target)
    result["outcome"] = "complete" if inner.get("outcome") == "complete" else "open"
    if result["outcome"] == "open":
        result["reason"] = "bootstrap_first_red"


def verify_runtime(artifacts, receipt):
    records = receipt.get("runtime", {})
    elixir, node = records.get("elixir", {}), records.get("node", {})
    require(elixir.get("argv") == ["elixir", "--eval", ELIXIR_PROBE] and
            node.get("argv") == ["node", "--version"], "runtime_probe_identity")
    require(artifacts.log(elixir).strip() == receipt.get("toolchain") == TOOLCHAIN and
            elixir["exit_status"] == 0, "unsupported_toolchain")
    require(artifacts.log(node).strip() == receipt.get("node_version") and node["exit_status"] == 0 and
            re.fullmatch(r"v20\.[0-9]+\.[0-9]+", receipt["node_version"]), "unsupported_node")


def verify_preparation(artifacts, receipt):
    records = receipt.get("preparation", [])
    require(0 < len(records) <= len(PREPARE), "missing_preparation")
    for index, record in enumerate(records):
        artifacts.log(record)
        require(record["argv"] == PREPARE[index], "preparation_argv_mismatch")
        if record["exit_status"] != 0:
            require(index == len(records) - 1, "post_red_preparation")
            return "open"
    require(len(records) == len(PREPARE), "partial_green_preparation")
    return "complete"


def verify_plt(inventory):
    require(isinstance(inventory, dict) and inventory.get("files"), "missing_plt_inventory")
    require(inventory.get("sha256") == digest(canonical(inventory["files"])), "plt_inventory_digest")
    require(all(type(item.get("bytes")) is int and item["bytes"] > 0 and
                re.fullmatch(r"[0-9a-f]{64}", item.get("sha256", "")) for item in inventory["files"]),
            "invalid_plt_inventory")


def verify_dialyzer(artifacts, receipt):
    prepared = verify_preparation(artifacts, receipt)
    analyses = receipt.get("analyses", [])
    if prepared == "open":
        require(not analyses, "analysis_after_failed_preparation")
        return "open"
    require(0 < len(analyses) <= 2, "missing_analysis_mode")
    for index, record in enumerate(analyses):
        mode = ("fresh", "restored")[index]
        text = artifacts.log(record)
        require(record.get("mode") == mode and
                record.get("argv") == ["bash", "scripts/ci/run_nightly_dialyzer.sh", mode],
                "analysis_mode_mismatch")
        require("nightly-dialyzer mode=" + mode in text, "missing_owner_diagnostic")
        if record["exit_status"] != 0:
            require(index == len(analyses) - 1, "analysis_after_first_red")
            return "open"
        verify_plt(record.get("output_plt"))
    require(len(analyses) == 2, "missing_restored_analysis")
    require(receipt.get("restored_input_plt") == analyses[0]["output_plt"], "foreign_restored_plt")
    return "complete"


def verify_async(root, subject, artifacts, receipt):
    prepared = verify_preparation(artifacts, receipt)
    if prepared == "open":
        require("runner" not in receipt, "async_after_preparation_red")
        return "open"
    runner = receipt.get("runner", {})
    artifacts.log(runner)
    require(runner.get("argv", [])[:3] == ["bash", "scripts/maintainer/async_isolation_evidence.sh", "--report"] and
            len(runner["argv"]) == 4, "async_runner_identity")
    path = artifacts.read_payload(receipt.get("jsonl", {}), "async.jsonl")
    external = receipt.get("evidence_file", {})
    original = (root / external.get("path", "")).resolve()
    relative_evidence(root, original)
    require(original.is_file() and digest(original.read_bytes()) == external.get("sha256") ==
            digest(path.read_bytes()), "async_original_changed")
    with pinned_checkout(root, subject) as (checkout, _, env):
        status, output, _ = execute(["bash", "scripts/maintainer/verify_async_isolation_receipt.sh",
                                     "--report", str(path)], checkout, env, budget=60)
    require(status == 0, "async_owner_verification_failed")
    verdict = json.loads(output)
    require(verdict == receipt.get("async_verdict"), "async_verdict_changed")
    require((verdict["status"] == "complete" and runner["exit_status"] == 0) or
            (verdict["status"] == "open" and runner["exit_status"] != 0), "async_exit_mismatch")
    return "complete" if verdict["status"] == "complete" else "open"


def verify_bootstrap(artifacts, receipt):
    runner = receipt.get("runner", {})
    artifacts.log(runner)
    require(runner.get("argv", [])[:7] == ["bash", "scripts/maintainer/verify_contributor_bootstrap.sh",
            "--run", "--full", "--subject-sha", receipt["subject_sha"], "--receipt"] and
            len(runner["argv"]) == 8, "bootstrap_runner_identity")
    path = artifacts.read_payload(receipt.get("bootstrap", {}), "bootstrap.json")
    inner = read_json(path)
    require(type(inner.get("schema_version")) is int and inner["schema_version"] == 1,
            "bootstrap_receipt_schema")
    require(inner.get("subject_sha") == receipt["subject_sha"] and
            inner.get("source_tree") == receipt["source_tree"] and
            inner.get("toolchain") == TOOLCHAIN and
            re.fullmatch(r"v20\.[0-9]+\.[0-9]+", inner.get("node_version", "")), "bootstrap_subject_or_runtime")
    require(inner.get("clean_checkout") is True and inner.get("full") is True, "bootstrap_not_clean_full")
    commands = inner.get("commands", [])
    expected = PREPARE + [FOCUSED, ["mix", "ci"]]
    require(0 < len(commands) <= len(expected), "bootstrap_missing_commands")
    for index, record in enumerate(commands):
        require(record.get("argv") == expected[index] and type(record.get("exit_status")) is int,
                "bootstrap_command_identity")
        if record["exit_status"] != 0:
            require(index == len(commands) - 1 and runner["exit_status"] != 0 and
                    inner.get("outcome") != "complete", "bootstrap_post_red_or_forged_green")
            return "open"
    require(len(commands) == len(expected) and runner["exit_status"] == 0 and
            inner.get("outcome") == "complete", "bootstrap_partial_green")
    return "complete"


def verify_receipt(root, subject, path, kind):
    receipt = read_json(path)
    require(type(receipt.get("schema_version")) is int and receipt["schema_version"] == 1 and
            receipt.get("kind") == kind,
            "receipt_kind_or_schema")
    require(all(receipt.get(key) == value for key, value in subject.items()), "foreign_receipt_subject")
    artifacts = Artifacts(path)
    verify_runtime(artifacts, receipt)
    if kind == "dialyzer":
        outcome = verify_dialyzer(artifacts, receipt)
    elif kind == "async":
        outcome = verify_async(root, subject, artifacts, receipt)
    elif kind == "bootstrap":
        outcome = verify_bootstrap(artifacts, receipt)
    else:
        raise Rejected("unsupported_measurement_kind")
    require(receipt.get("outcome") == outcome, "forged_measurement_outcome")
    return receipt


def collect(root, subject, args):
    require(args.receipt, "receipt_required")
    path = Path(args.receipt).resolve()
    # O_EXCL also rejects dangling symlinks and preserves every prior attempt.
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    result = {"schema_version": 1, "kind": args.operation, **subject, "outcome": "blocked"}
    try:
        artifacts = Artifacts(path, create=True)
        runtime(artifacts, root, result)
        with pinned_checkout(root, subject) as (checkout, scratch, env):
            if args.operation == "dialyzer":
                collect_dialyzer(artifacts, checkout, scratch, env, result)
            elif args.operation == "async":
                collect_async(root, artifacts, checkout, env, result, args)
            else:
                collect_bootstrap(artifacts, checkout, env, result)
    except (Rejected, OSError, ValueError, subprocess.SubprocessError) as error:
        result["reason"] = str(error) if isinstance(error, Rejected) else "measurement_prerequisite_failed"
    finally:
        if result["outcome"] != "complete":
            result["next_trigger"] = "Resolve the recorded first-red/prerequisite and use a new evidence path; never overwrite this attempt."
        with os.fdopen(descriptor, "w") as output:
            json.dump(result, output, sort_keys=True)
            output.write("\n")
    return result


QUALITY_CHECKS = [
    ("credo_policy", ["mix", "test", "test/install_smoke/credo_policy_test.exs", "--seed", "0"]),
    ("credo_inventory", ["mix", "credo_quality"]),
    ("ci_structure", ["mix", "test", "test/install_smoke/quality_signal_policy_test.exs",
                      "test/install_smoke/ci_cache_hygiene_test.exs",
                      "test/install_smoke/ci_lane_split_test.exs", "--seed", "0"])]


def evidence_contract(root):
    path = root / "scripts/maintainer/phase136_evidence_contract.json"
    contract = read_json(path)
    require(type(contract.get("schema_version")) is int and contract["schema_version"] == 1 and
            contract.get("supported_toolchain") == TOOLCHAIN and
            contract.get("node_major") == 20 and
            contract.get("subject_fields") == ["subject_sha", "source_tree"], "evidence_contract_identity")
    require(contract["coverage"].get("canonical_argv") == CANONICAL_COVERAGE,
            "coverage_canonical_contract")
    require(contract["coverage"]["floor"] == {"numerator": 821343, "denominator": 1000000,
                                               "percent": "82.1343"}, "coverage_floor_contract")
    return contract, digest(path.read_bytes())


def coverage_at_floor(covered, relevant, contract):
    require(type(covered) is int and type(relevant) is int and 0 <= covered <= relevant and relevant > 0,
            "coverage_invalid_counts")
    floor = contract["coverage"]["floor"]
    require(type(floor["numerator"]) is int and type(floor["denominator"]) is int,
            "coverage_floor_types")
    return covered * floor["denominator"] >= relevant * floor["numerator"]


def coverage_counts(raw):
    artifact = decode_json(raw)
    files = artifact.get("source_files")
    require(isinstance(files, list) and files, "coverage_missing_sources")
    actual_covered, actual_relevant, names = 0, 0, set()
    for source in files:
        require(isinstance(source, dict), "coverage_invalid_source")
        name = source.get("name")
        require(isinstance(name, str) and name not in names, "coverage_duplicate_or_missing_file")
        names.add(name)
        require(isinstance(source.get("coverage"), list), "coverage_missing_line_counts")
        for count in source["coverage"]:
            if count is not None:
                require(type(count) is int and count >= 0, "coverage_invalid_line_count")
                actual_relevant += 1
                actual_covered += int(count > 0)
    return actual_covered, actual_relevant


def coverage_outcome(subject, path, contract):
    receipt = read_json(path)
    interface = contract["coverage"]
    require(set(interface["required_fields"]).issubset(receipt), "coverage_missing_fields")
    require(all(receipt.get(key) == value for key, value in subject.items()), "coverage_foreign_subject")
    require(receipt["canonical_argv"] == interface["canonical_argv"], "coverage_noncanonical_argv")
    require(type(receipt["local_exit"]) is int, "coverage_exit_type")
    require(receipt.get("toolchain") == TOOLCHAIN and
            re.fullmatch(r"v20\.[0-9]+\.[0-9]+", receipt.get("node_version", "")),
            "coverage_unsupported_runtime")
    covered, relevant = receipt["covered"], receipt["relevant"]
    require(type(covered) is int and type(relevant) is int and 0 <= covered <= relevant and relevant > 0,
            "coverage_invalid_counts")
    raw = base64.b64decode(receipt["artifact_base64"], validate=True)
    require(digest(raw) == receipt["artifact_sha256"], "coverage_artifact_digest")
    actual_covered, actual_relevant = coverage_counts(raw)
    require((actual_covered, actual_relevant) == (covered, relevant), "coverage_artifact_count_mismatch")
    local = base64.b64decode(receipt["local_output_base64"], validate=True)
    require(len(local) <= LIMIT and digest(local) == receipt["local_output_sha256"], "coverage_local_output_digest")
    require(re.search(rb"\b[1-9][0-9]* tests?, 0 failures\b", local), "coverage_missing_suite_proof")
    complete = receipt["local_exit"] == 0 and coverage_at_floor(covered, relevant, contract)
    outcome = "complete" if complete else "open"
    require(receipt["outcome"] == outcome, "coverage_forged_outcome")
    return outcome


def collect_quality(root, subject, artifacts):
    result = {"schema_version": 1, "kind": "quality", **subject, "outcome": "blocked", "checks": []}
    try:
        runtime(artifacts, root, result)
        with pinned_checkout(root, subject) as (checkout, _, env):
            if not prepare(artifacts, checkout, env, result):
                return result
            for name, argv in QUALITY_CHECKS:
                record = artifacts.run(argv, checkout, env, budget=600)
                record["check"] = name
                result["checks"].append(record)
                if record["exit_status"] != 0:
                    result.update(outcome="open", reason=name + "_first_red")
                    return result
        result["outcome"] = "complete"
    except (Rejected, OSError, ValueError, subprocess.SubprocessError) as error:
        result["reason"] = str(error) if isinstance(error, Rejected) else "quality_prerequisite_failed"
    return result


def quality_states(subject, artifacts, quality):
    require(all(quality.get(key) == value for key, value in subject.items()), "quality_foreign_subject")
    verify_runtime(artifacts, quality)
    if verify_preparation(artifacts, quality) == "open":
        require(not quality.get("checks"), "quality_after_preparation_red")
        return {"maint": "open", "ci": "blocked"}
    checks = quality.get("checks", [])
    require(0 < len(checks) <= len(QUALITY_CHECKS), "quality_missing_checks")
    passed = set()
    red = False
    for index, record in enumerate(checks):
        name, argv = QUALITY_CHECKS[index]
        require(record.get("check") == name and record.get("argv") == argv, "quality_owner_identity")
        text = artifacts.log(record)
        if record["exit_status"] != 0:
            require(index == len(checks) - 1, "quality_after_first_red")
            red = True
            break
        if name == "credo_inventory":
            require("[credo-quality] blocking warnings, public contract, and complexity inventory passed" in text,
                    "quality_missing_credo_proof")
        else:
            require(re.search(r"\b[1-9][0-9]* tests?, 0 failures\b", text) and
                    not re.search(r"\b[1-9][0-9]* invalid\b", text), "quality_missing_test_proof")
        passed.add(name)
    require(red or len(checks) == len(QUALITY_CHECKS), "quality_partial_green")
    require(quality.get("outcome") == ("open" if red else "complete"), "quality_forged_outcome")
    return {"maint": "complete" if {"credo_policy", "credo_inventory"}.issubset(passed) else "open",
            "ci": "complete" if "ci_structure" in passed else "open"}


def timing_state(root, subject, path):
    text = Path(path).read_text()
    require(text.count("CI_TIMING_CURRENT_SOURCE_BEGIN") == 1 and
            text.count("CI_TIMING_CURRENT_SOURCE_END") == 1, "timing_missing_or_duplicate_source")
    section = text.split("CI_TIMING_CURRENT_SOURCE_BEGIN\n", 1)[1].split("\nCI_TIMING_CURRENT_SOURCE_END", 1)[0]
    timing = decode_json(section)
    require(timing.get("sha") == subject["subject_sha"] and timing.get("repo") == "szTheory/rindle" and
            type(timing.get("pr")) is int and timing["pr"] > 0, "timing_foreign_identity")
    runs = timing.get("runs", [])
    require(len(runs) == 10 and len({run["id"] for run in runs}) == 10, "timing_not_exact_ten")
    require(all(type(run.get("id")) is int and run["id"] > 0 and
                type(run.get("duration_seconds")) is int and 0 <= run["duration_seconds"] <= 1800
                for run in runs), "timing_invalid_run")
    values = sorted(run["duration_seconds"] for run in runs)
    median, p95 = (values[4] + values[5]) / 2, values[9]
    require(timing.get("median_seconds") == median and timing.get("p95_seconds") == p95,
            "timing_statistics_mismatch")
    argv = ["bash", "scripts/ci/collect_pr_timing_receipt.sh", "verify", "--repo", "szTheory/rindle",
            "--pr", str(timing["pr"]), "--workflow", "ci.yml", "--summary-job", "CI Summary",
            "--samples", "10", "--median-max", "480", "--p95-max", "600", "--subject-sha",
            subject["subject_sha"], "--receipt", str(Path(path).resolve())]
    status, output, _ = execute(argv, root, budget=1800)
    if status != 0:
        require(b"misses inclusive CI-14 timing thresholds" in output, "timing_api_authentication_failed")
    return "complete" if median <= 480 and p95 <= 600 else "open"


def assessment(callback):
    try:
        return {"status": callback()}
    except (Rejected, OSError, ValueError, KeyError, TypeError, IndexError, subprocess.SubprocessError) as error:
        return {"status": "blocked", "reason": str(error) if isinstance(error, Rejected) else "missing_or_invalid_authority"}


def derive_qualification(root, subject, paths, quality, artifacts, contract, contract_sha):
    quality_assessment = assessment(lambda: quality_states(subject, artifacts, quality))
    if isinstance(quality_assessment["status"], dict):
        qstates = quality_assessment["status"]
    else:
        qstates = {"maint": "blocked", "ci": "blocked"}
    authorities = {"coverage": assessment(lambda: coverage_outcome(subject, paths["coverage"], contract))}
    for kind in ("dialyzer", "async", "bootstrap"):
        authorities[kind] = assessment(lambda kind=kind: verify_receipt(root, subject, paths[kind], kind)["outcome"])
    authorities["timing"] = assessment(lambda: timing_state(root, subject, paths["timing"]))
    requirements = {
        "MAINT-04": {"status": qstates["maint"], "authority": "quality.credo"},
        "TYPE-03": {**authorities["dialyzer"], "authority": "dialyzer"},
        "COV-06": {**authorities["coverage"], "authority": "coverage"},
        "TEST-08": {**authorities["async"], "authority": "async"},
        "CI-15": {"status": qstates["ci"], "authority": "quality.ci_structure"},
        "CI-16": {"status": authorities["timing"]["status"] if qstates["ci"] == "complete" else qstates["ci"],
                  "authority": "timing+quality.ci_structure"},
        "DX-05": {**authorities["bootstrap"], "authority": "bootstrap"}}
    references = {}
    for kind, path in paths.items():
        references[kind] = {"path": relative_evidence(root, path),
                            "sha256": digest(Path(path).read_bytes()) if Path(path).is_file() else None}
    statuses = [value["status"] for value in requirements.values()]
    outcome = "blocked" if "blocked" in statuses else "open" if "open" in statuses else "complete"
    result = {"schema_version": 1, **subject, "contract_sha256": contract_sha, "outcome": outcome,
              "requirements": requirements, "evidence": references, "authorities": authorities,
              "quality": quality}
    if outcome != "complete":
        result["next_trigger"] = "Resolve each recorded open/blocked authority; preserve prior receipts and use new authorized evidence paths."
    return result


def qualification_main(root, argv):
    parser = argparse.ArgumentParser(prog="verify_phase136_qualification.sh")
    parser.add_argument("operation", choices=("generate", "verify"))
    parser.add_argument("--subject-file", required=True)
    parser.add_argument("--manifest", required=True)
    for name in ("coverage", "dialyzer", "async-receipt", "bootstrap", "timing"):
        parser.add_argument("--" + name)
    args = parser.parse_args(argv)
    descriptor = None
    result = {"outcome": "blocked"}
    try:
        subject = source_subject(root, args.subject_file)
        contract, contract_sha = evidence_contract(root)
        path = Path(args.manifest).resolve()
        if args.operation == "generate":
            descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            artifacts = Artifacts(path, create=True)
            phase = root / ".planning/phases/136-measured-quality-and-ci-ratchets"
            defaults = {"coverage": "136-COVERAGE-EVIDENCE.json", "dialyzer": "136-DIALYZER-EVIDENCE.json",
                        "async": "136-ASYNC-RESULT.json", "bootstrap": "136-BOOTSTRAP-EVIDENCE.json",
                        "timing": "136-PR-TIMING.md"}
            paths = {kind: Path(getattr(args, "async_receipt" if kind == "async" else kind) or phase / name).resolve()
                     for kind, name in defaults.items()}
            quality = collect_quality(root, subject, artifacts)
        else:
            stored = read_json(path)
            require(type(stored.get("schema_version")) is int and stored["schema_version"] == 1,
                    "qualification_schema")
            require(all(stored.get(key) == value for key, value in subject.items()), "qualification_foreign_subject")
            require(set(stored.get("evidence", {})) == {"coverage", "dialyzer", "async", "bootstrap", "timing"},
                    "qualification_missing_authority")
            paths = {kind: root / reference["path"] for kind, reference in stored["evidence"].items()}
            artifacts, quality = Artifacts(path), stored["quality"]
        result = derive_qualification(root, subject, paths, quality, artifacts, contract, contract_sha)
        if args.operation == "verify":
            require(canonical(result) == canonical(stored), "qualification_claim_or_evidence_drift")
        print(json.dumps(result, sort_keys=True))
        return 0 if args.operation == "verify" or result["outcome"] == "complete" else 1
    except (Rejected, OSError, ValueError, KeyError, TypeError, IndexError, subprocess.SubprocessError) as error:
        result = {"outcome": "blocked", "reason": str(error) if isinstance(error, Rejected)
                  else "qualification_prerequisite_failed"}
        print(json.dumps(result))
        return 1
    finally:
        if descriptor is not None:
            with os.fdopen(descriptor, "w") as output:
                json.dump(result, output, sort_keys=True)
                output.write("\n")


def coverage_main(root, argv):
    parser = argparse.ArgumentParser(prog="verify_coverage_floor.exs")
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--subject-file", required=True)
    parser.add_argument("--receipt", required=True)
    parser.add_argument("--artifact")
    parser.add_argument("--local-output")
    parser.add_argument("--local-exit", type=int)
    parser.add_argument("--run-started-at", type=float)
    args = parser.parse_args(argv)
    result = {"outcome": "blocked"}
    descriptor = None
    try:
        require(args.write != args.verify_only, "choose_one_coverage_mode")
        subject = source_subject(root, args.subject_file)
        contract, _ = evidence_contract(root)
        result.update(subject)
        if args.verify_only:
            result["outcome"] = coverage_outcome(subject, args.receipt, contract)
        else:
            descriptor = os.open(args.receipt, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            require(args.artifact and args.local_output and args.local_exit is not None and
                    args.run_started_at is not None and 0 < args.run_started_at <= time.time(),
                    "coverage_run_inputs_required")
            for name in (args.artifact, args.local_output):
                path = Path(name)
                require(path.is_file() and not path.is_symlink() and
                        path.stat().st_mtime >= args.run_started_at, "coverage_missing_or_stale_artifact")
            raw = Path(args.artifact).read_bytes()
            local = Path(args.local_output).read_bytes()
            require(len(raw) <= 32 * 1024 * 1024 and len(local) <= LIMIT, "coverage_output_limit")
            code, version, _ = execute(["elixir", "--eval", ELIXIR_PROBE], root, budget=30)
            result["toolchain"] = version.decode().strip()
            require(code == 0 and result["toolchain"] == TOOLCHAIN, "coverage_unsupported_toolchain")
            code, version, _ = execute(["node", "--version"], root, budget=30)
            result["node_version"] = version.decode().strip()
            require(code == 0 and re.fullmatch(r"v20\.[0-9]+\.[0-9]+", result["node_version"]),
                    "coverage_unsupported_node")
            covered, relevant = coverage_counts(raw)
            complete = args.local_exit == 0 and coverage_at_floor(covered, relevant, contract)
            result.update(covered=covered, relevant=relevant, canonical_argv=CANONICAL_COVERAGE,
                          local_exit=args.local_exit, artifact_sha256=digest(raw),
                          artifact_base64=base64.b64encode(raw).decode(),
                          local_output_base64=base64.b64encode(local).decode(),
                          local_output_sha256=digest(local), run_started_at=args.run_started_at,
                          outcome="complete" if complete else "open")
            require(re.search(rb"\b[1-9][0-9]* tests?, 0 failures\b", local),
                    "coverage_missing_suite_proof")
    except (Rejected, OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        result.update(outcome="blocked", reason=str(error) if isinstance(error, Rejected)
                      else "invalid_coverage_or_prerequisite")
    finally:
        if descriptor is not None:
            with os.fdopen(descriptor, "w") as output:
                json.dump(result, output, sort_keys=True)
                output.write("\n")
    print(json.dumps({key: value for key, value in result.items()
                      if key not in ("artifact_base64", "local_output_base64")}, sort_keys=True))
    return 0 if result["outcome"] == "complete" else 1


def main():
    family, root = sys.argv[1], Path(sys.argv[2]).resolve()
    if family == "qualify":
        return qualification_main(root, sys.argv[3:])
    if family == "coverage":
        return coverage_main(root, sys.argv[3:])
    parser = argparse.ArgumentParser(prog="phase136_measure.sh")
    parser.add_argument("operation")
    parser.add_argument("--subject-file", required=True)
    parser.add_argument("--receipt")
    parser.add_argument("--jsonl", "--jsonl-path", dest="jsonl")
    args = parser.parse_args(sys.argv[3:])
    try:
        require(family == "measure", "unsupported_entrypoint")
        subject = source_subject(root, args.subject_file)
        if args.operation == "verify-subject":
            result = {"outcome": "complete", **subject}
        elif args.operation.startswith("verify-"):
            require(args.receipt, "receipt_required")
            result = verify_receipt(root, subject, args.receipt, args.operation[7:])
        else:
            require(args.operation in ("dialyzer", "async", "bootstrap"), "unknown_collection_mode")
            result = collect(root, subject, args)
        print(json.dumps(result, sort_keys=True))
        return 0 if result["outcome"] == "complete" or args.operation.startswith("verify-") else 1
    except (Rejected, OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(json.dumps({"outcome": "blocked", "reason": str(error) if isinstance(error, Rejected)
                          else "invalid_evidence_or_prerequisite"}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
