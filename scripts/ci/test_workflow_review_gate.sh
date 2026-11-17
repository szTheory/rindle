#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PYTHONDONTWRITEBYTECODE=1 python3 - "$repo_root" <<'PY'
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(sys.argv[1]).resolve()
CHECKER = REPO / "scripts/maintainer/check_workflow_review.py"
RECORD_REL = ".planning/phases/139-exact-head-readiness-closure/139-09-WORKFLOW-REVIEW.json"
PATHS = [
    ".github/workflows/ci.yml",
    ".github/workflows/nightly.yml",
    ".github/workflows/readiness-retention.yml",
    ".github/workflows/release.yml",
]


def git(root, *args, input_bytes=None):
    return subprocess.run(
        ["git", "-C", str(root), *args],
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    ).stdout


def hunk_rows(root, base_commit):
    raw = git(
        root,
        "-c",
        "color.ui=false",
        "diff",
        "--no-ext-diff",
        "--no-textconv",
        "--unified=0",
        base_commit,
        "--",
        *PATHS,
    )
    rows = []
    current_path = None
    hunk = None

    def finish():
        if hunk is not None:
            digest = hashlib.sha256(current_path.encode() + b"\0" + b"".join(hunk)).hexdigest()
            rows.append((current_path, digest))

    for line in raw.splitlines(keepends=True):
        if line.startswith(b"diff --git "):
            finish()
            current_path = line.split(b" b/", 1)[1].decode("utf-8").rstrip("\n")
            hunk = None
        elif line.startswith(b"@@ "):
            finish()
            hunk = [line]
        elif hunk is not None:
            hunk.append(line)
    finish()
    return rows


def make_fixture():
    temp = tempfile.TemporaryDirectory(prefix="rindle-workflow-review-")
    root = Path(temp.name)
    git(root, "init", "-b", "main")
    git(root, "config", "user.name", "Workflow Gate Test")
    git(root, "config", "user.email", "workflow-gate@example.invalid")
    base_contents = {
        PATHS[0]: b"name: CI\non:\n  pull_request:\njobs:\n  ci-script-tests:\n    steps:\n      - run: echo baseline\n",
        PATHS[1]: b"name: Nightly\non:\n  schedule:\n    - cron: '27 7 * * *'\njobs:\n  incident:\n    if: scheduled\n",
        PATHS[2]: b"name: Readiness Retention\njobs:\n  collect:\n    steps:\n      - run: echo baseline\n",
        PATHS[3]: b"name: Release\njobs:\n  gate:\n    head_sha: sha\n",
    }
    for relative, content in base_contents.items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    git(root, "add", "--", *PATHS)
    git(root, "commit", "-m", "fixture workflow baseline")
    base_commit = git(root, "rev-parse", "HEAD").decode().strip()

    replacements = {
        PATHS[0]: (b"echo baseline", b"echo reviewed"),
        PATHS[1]: (b"27 7", b"28 7"),
        PATHS[2]: (b"echo baseline", b"echo reviewed"),
        PATHS[3]: (b"head_sha: sha", b"head_sha: context.sha"),
    }
    for relative, (old, new) in replacements.items():
        path = root / relative
        path.write_bytes(path.read_bytes().replace(old, new))

    (root / "task.txt").write_text("later plan task commit\n", encoding="utf-8")
    git(root, "add", "--", "task.txt")
    git(root, "commit", "-m", "later unrelated plan task")

    workflow_rows = []
    for relative in PATHS:
        base = git(root, "cat-file", "blob", f"{base_commit}:{relative}")
        final = (root / relative).read_bytes()
        workflow_rows.append(
            {
                "path": relative,
                "base_sha256": hashlib.sha256(base).hexdigest(),
                "final_sha256": hashlib.sha256(final).hexdigest(),
            }
        )
    hunks = [
        {
            "path": relative,
            "hunk_sha256": digest,
            "disposition": "approved",
            "rationale": f"Reviewed control change for {relative}.",
        }
        for relative, digest in hunk_rows(root, base_commit)
    ]
    record = {
        "schema_version": 1,
        "base_commit": base_commit,
        "workflow_paths": workflow_rows,
        "reviewed_hunks": hunks,
        "findings": [],
        "local_contracts": [
            {"name": "fixture contract", "outcome": "pass", "evidence": "isolated fixture"}
        ],
    }
    record_path = root / RECORD_REL
    record_path.parent.mkdir(parents=True, exist_ok=True)
    record_path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    return temp, root, record_path


def run_checker(root, record_path):
    return subprocess.run(
        [
            sys.executable,
            str(CHECKER),
            "--repo-root",
            str(root),
            "--record",
            str(record_path.relative_to(root)),
        ],
        cwd=REPO,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=5,
        env={**__import__("os").environ, "PYTHONDONTWRITEBYTECODE": "1"},
    )


def read_record(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_record(path, record):
    path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")


def expect_pass(label):
    temp, root, record_path = make_fixture()
    try:
        result = run_checker(root, record_path)
        if result.returncode != 0:
            raise AssertionError(f"{label}: expected pass, got {result.returncode}: {result.stderr}{result.stdout}")
        if "4 workflow files" not in result.stdout or "reviewed hunks" not in result.stdout:
            raise AssertionError(f"{label}: missing success summary: {result.stdout}")
        print(f"PASS {label}")
    finally:
        temp.cleanup()


def expect_fail(label, code, mutate):
    temp, root, record_path = make_fixture()
    try:
        mutate(root, record_path)
        result = run_checker(root, record_path)
        output = result.stdout + result.stderr
        if result.returncode == 0 or code not in output:
            raise AssertionError(f"{label}: expected {code}, got {result.returncode}: {output}")
        print(f"PASS {label}")
    finally:
        temp.cleanup()


def mutate_record(change):
    def mutate(_root, path):
        record = read_record(path)
        change(record)
        write_record(path, record)

    return mutate


def set_non_ancestor(root, path):
    record = read_record(path)
    tree = git(root, "rev-parse", "HEAD^{tree}").decode().strip()
    record["base_commit"] = git(root, "commit-tree", tree, "-m", "unrelated baseline").decode().strip()
    write_record(path, record)


def replace_with_symlink(root, _record_path):
    workflow = root / PATHS[0]
    target = root / "outside.yml"
    target.write_bytes(workflow.read_bytes())
    workflow.unlink()
    os.symlink(target, workflow)


def replace_with_fifo(root, _record_path):
    workflow = root / PATHS[0]
    workflow.unlink()
    os.mkfifo(workflow)


expect_pass("complete reviewed record, including later task commit")

temp, root, record_path = make_fixture()
try:
    result = run_checker(root, root / "missing-review.json")
    output = result.stdout + result.stderr
    if result.returncode == 0 or "review_record_missing" not in output:
        raise AssertionError(f"missing record: expected review_record_missing, got {output}")
    print("PASS missing record rejected")
finally:
    temp.cleanup()

expect_fail(
    "malformed record rejected",
    "review_record_malformed",
    lambda _root, path: path.write_text("{bad json", encoding="utf-8"),
)
expect_fail(
    "final digest mismatch rejected",
    "final_digest_mismatch",
    mutate_record(lambda record: record["workflow_paths"][0].update(final_sha256="0" * 64)),
)
expect_fail(
    "baseline digest mismatch rejected",
    "base_digest_mismatch",
    mutate_record(lambda record: record["workflow_paths"][0].update(base_sha256="0" * 64)),
)
expect_fail(
    "non-ancestor baseline rejected",
    "base_commit_not_ancestor",
    set_non_ancestor,
)
expect_fail(
    "missing hunk rejected",
    "hunk_coverage_mismatch",
    mutate_record(lambda record: record["reviewed_hunks"].pop()),
)
expect_fail(
    "duplicate hunk rejected",
    "hunk_record_duplicate",
    mutate_record(lambda record: record["reviewed_hunks"].append(dict(record["reviewed_hunks"][0]))),
)
expect_fail(
    "unresolved finding rejected",
    "finding_unresolved",
    mutate_record(lambda record: record["findings"].append({"id": "F-1", "status": "unresolved", "resolution": ""})),
)
expect_fail(
    "missing hunk rationale rejected",
    "hunk_rationale_missing",
    mutate_record(lambda record: record["reviewed_hunks"][0].update(rationale=" ")),
)
expect_fail(
    "unapproved disposition rejected",
    "hunk_disposition_unapproved",
    mutate_record(lambda record: record["reviewed_hunks"][0].update(disposition="deferred")),
)
expect_fail(
    "failed contract outcome rejected",
    "contract_failed",
    mutate_record(lambda record: record["local_contracts"][0].update(outcome="fail")),
)
expect_fail(
    "symlink workflow rejected",
    "final_workflow_symlink",
    replace_with_symlink,
)
expect_fail(
    "non-regular workflow rejected without blocking",
    "final_workflow_not_regular",
    replace_with_fifo,
)

print("Workflow review gate adverse fixtures passed.")
PY
