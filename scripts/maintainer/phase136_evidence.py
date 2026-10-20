"""Source-bound Phase 136 evidence; all subprocess owners come from the frozen tree."""
import argparse
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


def read_json(path):
    path = Path(path)
    require(path.is_file() and path.stat().st_size <= 32 * 1024 * 1024, "missing_or_oversized_json")
    def unique(items):
        value = {}
        for key, item in items:
            require(key not in value, "duplicate_json_key")
            value[key] = item
        return value
    return json.loads(path.read_text(), object_pairs_hook=unique,
                      parse_constant=lambda _: (_ for _ in ()).throw(Rejected("nonfinite_json")))


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
        self.root = Path(str(receipt) + ".artifacts")
        self.count = 0
        if create:
            self.root.mkdir(mode=0o700)

    def run(self, argv, cwd, env=None, budget=300):
        status, raw, elapsed = execute(argv, cwd, env, budget)
        data = sanitized(raw)
        path = self.root / f"{self.count:03d}.log"
        self.count += 1
        with path.open("xb") as output:
            output.write(data)
        return {"argv": argv, "exit_status": status, "artifact": path.name,
                "output_sha256": digest(data), "raw_output_sha256": digest(raw),
                "output_bytes": len(data), "duration_seconds": elapsed}

    def log(self, record):
        require(isinstance(record, dict) and re.fullmatch(r"[0-9]{3}\.log", record.get("artifact", "")),
                "invalid_command_artifact")
        require(type(record.get("exit_status")) is int and -128 <= record["exit_status"] <= 255,
                "invalid_command_exit")
        path = self.root / record["artifact"]
        require(path.is_file() and not path.is_symlink() and path.stat().st_size <= LIMIT,
                "missing_command_output")
        data = path.read_bytes()
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


def verify_receipt(root, subject, path, kind):
    receipt = read_json(path)
    require(receipt.get("schema_version") == 1 and receipt.get("kind") == kind,
            "receipt_kind_or_schema")
    require(all(receipt.get(key) == value for key, value in subject.items()), "foreign_receipt_subject")
    artifacts = Artifacts(path)
    verify_runtime(artifacts, receipt)
    require(kind == "dialyzer", "unsupported_measurement_kind")
    outcome = verify_dialyzer(artifacts, receipt)
    require(receipt.get("outcome") == outcome, "forged_measurement_outcome")
    return receipt


def collect(root, subject, args):
    require(args.receipt, "receipt_required")
    path = Path(args.receipt)
    # O_EXCL also rejects dangling symlinks and preserves every prior attempt.
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    result = {"schema_version": 1, "kind": args.operation, **subject, "outcome": "blocked"}
    try:
        artifacts = Artifacts(path, create=True)
        runtime(artifacts, root, result)
        with pinned_checkout(root, subject) as (checkout, scratch, env):
            require(args.operation == "dialyzer", "unsupported_measurement_kind")
            collect_dialyzer(artifacts, checkout, scratch, env, result)
    except (Rejected, OSError, ValueError, subprocess.SubprocessError) as error:
        result["reason"] = str(error) if isinstance(error, Rejected) else "measurement_prerequisite_failed"
    finally:
        if result["outcome"] != "complete":
            result["next_trigger"] = "Resolve the recorded first-red/prerequisite and use a new evidence path; never overwrite this attempt."
        with os.fdopen(descriptor, "w") as output:
            json.dump(result, output, sort_keys=True)
            output.write("\n")
    return result


def main():
    family, root = sys.argv[1], Path(sys.argv[2]).resolve()
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
