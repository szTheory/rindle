#!/usr/bin/env python3
"""Fail closed unless the final workflow bytes and every changed hunk were reviewed."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import stat
import subprocess
import sys
from pathlib import Path
from typing import Any


WORKFLOW_PATHS = (
    ".github/workflows/ci.yml",
    ".github/workflows/nightly.yml",
    ".github/workflows/readiness-retention.yml",
    ".github/workflows/release.yml",
)
DEFAULT_RECORD = ".planning/phases/139-exact-head-readiness-closure/139-09-WORKFLOW-REVIEW.json"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^(?:[0-9a-f]{40}|[0-9a-f]{64})$")


class ReviewError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class DuplicateJsonKey(ValueError):
    pass


def fail(code: str, message: str) -> None:
    raise ReviewError(code, message)


def no_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJsonKey(f"duplicate JSON field {key!r}")
        result[key] = value
    return result


def git(root: Path, *args: str, code: str, message: str) -> bytes:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", "replace").strip()
        fail(code, f"{message}{': ' + detail if detail else ''}")
    return result.stdout


def object_with_fields(value: Any, fields: set[str], label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail("review_record_malformed", f"{label} must be a JSON object")
    if set(value) != fields:
        missing = sorted(fields - set(value))
        extra = sorted(set(value) - fields)
        fail(
            "review_record_fields_invalid",
            f"{label} fields differ from schema (missing={missing}, extra={extra})",
        )
    return value


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def workflow_bytes(root: Path, relative: str) -> bytes:
    current = root
    parts = Path(relative).parts
    for index, part in enumerate(parts):
        current = current / part
        try:
            mode = current.lstat().st_mode
        except FileNotFoundError:
            fail("final_workflow_missing", f"working-tree workflow is missing: {relative}")
        except OSError as error:
            fail("final_workflow_unreadable", f"cannot inspect working-tree workflow {relative}: {error}")
        if stat.S_ISLNK(mode):
            fail("final_workflow_symlink", f"working-tree workflow path contains a symlink: {relative}")
        if index < len(parts) - 1 and not stat.S_ISDIR(mode):
            fail("final_workflow_path_invalid", f"working-tree workflow parent is not a directory: {relative}")
        if index == len(parts) - 1 and not stat.S_ISREG(mode):
            fail("final_workflow_not_regular", f"working-tree workflow is not a regular file: {relative}")
    try:
        return current.read_bytes()
    except OSError as error:
        fail("final_workflow_unreadable", f"cannot read working-tree workflow {relative}: {error}")


def load_record(root: Path, record_arg: Path) -> dict[str, Any]:
    path = record_arg if record_arg.is_absolute() else root / record_arg
    try:
        resolved = path.resolve(strict=True)
        resolved.relative_to(root)
    except FileNotFoundError:
        fail("review_record_missing", f"review record does not exist: {path}")
    except ValueError:
        fail("review_record_outside_repo", "review record must be inside the repository")
    except OSError as error:
        fail("review_record_unreadable", f"cannot resolve review record: {error}")

    try:
        with resolved.open("r", encoding="utf-8") as stream:
            record = json.load(stream, object_pairs_hook=no_duplicate_keys)
    except (UnicodeDecodeError, json.JSONDecodeError, DuplicateJsonKey) as error:
        fail("review_record_malformed", f"review record is not valid unique-key JSON: {error}")
    except OSError as error:
        fail("review_record_unreadable", f"cannot read review record: {error}")
    return object_with_fields(
        record,
        {"schema_version", "base_commit", "workflow_paths", "reviewed_hunks", "findings", "local_contracts"},
        "review record",
    )


def validate_digest(value: Any, label: str) -> str:
    if not isinstance(value, str) or SHA256_RE.fullmatch(value) is None:
        fail("review_digest_invalid", f"{label} must be a lowercase SHA-256 hex digest")
    return value


def changed_hunks(root: Path, base_commit: str) -> list[tuple[str, str]]:
    raw = git(
        root,
        "-c",
        "color.ui=false",
        "diff",
        "--no-ext-diff",
        "--no-textconv",
        "--no-renames",
        "--unified=0",
        base_commit,
        "--",
        *WORKFLOW_PATHS,
        code="workflow_diff_unavailable",
        message="cannot compute base-to-working-tree workflow diff",
    )
    rows: list[tuple[str, str]] = []
    current_path: str | None = None
    hunk: list[bytes] | None = None

    def finish_hunk() -> None:
        if hunk is None or current_path is None:
            return
        digest = sha256(current_path.encode("utf-8") + b"\0" + b"".join(hunk))
        rows.append((current_path, digest))

    for line in raw.splitlines(keepends=True):
        if line.startswith(b"diff --git "):
            finish_hunk()
            try:
                current_path = line.split(b" b/", 1)[1].decode("utf-8").rstrip("\n")
            except (IndexError, UnicodeDecodeError):
                fail("workflow_diff_malformed", "could not parse a workflow path from git diff")
            hunk = None
        elif line.startswith(b"@@ "):
            finish_hunk()
            hunk = [line]
        elif hunk is not None:
            hunk.append(line)
    finish_hunk()

    if len(rows) != len(set(rows)):
        fail("workflow_diff_ambiguous", "base-to-working-tree diff contains duplicate hunk identities")
    return rows


def verify_record(root: Path, record: dict[str, Any]) -> tuple[int, int, int]:
    if type(record["schema_version"]) is not int or record["schema_version"] != 1:
        fail("review_schema_unsupported", "schema_version must be integer 1")

    base_commit = record["base_commit"]
    if not isinstance(base_commit, str) or COMMIT_RE.fullmatch(base_commit) is None:
        fail("base_commit_invalid", "base_commit must be a full lowercase Git object ID")
    resolved_base = git(
        root,
        "rev-parse",
        "--verify",
        f"{base_commit}^{{commit}}",
        code="base_commit_unavailable",
        message="base_commit does not resolve to a commit",
    ).decode("ascii", "replace").strip()
    if resolved_base != base_commit:
        fail("base_commit_invalid", "base_commit must use the full canonical Git object ID")

    ancestor = subprocess.run(
        ["git", "-C", str(root), "merge-base", "--is-ancestor", base_commit, "HEAD"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        check=False,
    )
    if ancestor.returncode != 0:
        fail("base_commit_not_ancestor", "review base must be an ancestor of current HEAD")

    path_rows = record["workflow_paths"]
    if not isinstance(path_rows, list) or len(path_rows) != len(WORKFLOW_PATHS):
        fail("workflow_paths_invalid", "record must contain exactly the four expected workflow paths")
    found_paths: set[str] = set()
    for row in path_rows:
        row = object_with_fields(row, {"path", "base_sha256", "final_sha256"}, "workflow path entry")
        path = row["path"]
        if not isinstance(path, str) or path not in WORKFLOW_PATHS or path in found_paths:
            fail("workflow_paths_invalid", "workflow paths must name each expected path exactly once")
        found_paths.add(path)
        expected_base_digest = validate_digest(row["base_sha256"], f"base_sha256 for {path}")
        expected_final_digest = validate_digest(row["final_sha256"], f"final_sha256 for {path}")

        base_bytes = git(
            root,
            "cat-file",
            "blob",
            f"{base_commit}:{path}",
            code="base_workflow_missing",
            message=f"review base does not contain {path}",
        )
        if sha256(base_bytes) != expected_base_digest:
            fail("base_digest_mismatch", f"recorded base bytes do not match {base_commit}:{path}")

        final_bytes = workflow_bytes(root, path)
        if sha256(final_bytes) != expected_final_digest:
            fail("final_digest_mismatch", f"recorded final bytes do not match working-tree file: {path}")

    if found_paths != set(WORKFLOW_PATHS):
        fail("workflow_paths_invalid", "record must name each expected workflow path exactly once")

    expected_hunks = set(changed_hunks(root, base_commit))
    hunk_rows = record["reviewed_hunks"]
    if not isinstance(hunk_rows, list):
        fail("review_record_malformed", "reviewed_hunks must be a JSON array")
    recorded_hunks: set[tuple[str, str]] = set()
    for row in hunk_rows:
        row = object_with_fields(row, {"path", "hunk_sha256", "disposition", "rationale"}, "reviewed hunk entry")
        path = row["path"]
        if not isinstance(path, str) or path not in WORKFLOW_PATHS:
            fail("hunk_path_invalid", "reviewed hunk names a path outside the four workflow files")
        digest = validate_digest(row["hunk_sha256"], f"hunk_sha256 for {path}")
        identity = (path, digest)
        if identity in recorded_hunks:
            fail("hunk_record_duplicate", f"duplicate review entry for hunk {digest} in {path}")
        recorded_hunks.add(identity)
        disposition = row["disposition"]
        if disposition != "approved":
            fail("hunk_disposition_unapproved", f"hunk {digest} in {path} is not approved")
        rationale = row["rationale"]
        if not isinstance(rationale, str) or not rationale.strip():
            fail("hunk_rationale_missing", f"hunk {digest} in {path} has no review rationale")

    if recorded_hunks != expected_hunks:
        missing = len(expected_hunks - recorded_hunks)
        extra = len(recorded_hunks - expected_hunks)
        fail("hunk_coverage_mismatch", f"reviewed hunk set differs from exact diff (missing={missing}, extra={extra})")

    findings = record["findings"]
    if not isinstance(findings, list):
        fail("review_record_malformed", "findings must be a JSON array")
    finding_ids: set[str] = set()
    for row in findings:
        row = object_with_fields(row, {"id", "status", "resolution"}, "finding entry")
        finding_id = row["id"]
        if not isinstance(finding_id, str) or not finding_id.strip() or finding_id in finding_ids:
            fail("finding_id_invalid", "finding IDs must be nonempty and unique")
        finding_ids.add(finding_id)
        if row["status"] != "resolved":
            fail("finding_unresolved", f"finding {finding_id} is not resolved")
        if not isinstance(row["resolution"], str) or not row["resolution"].strip():
            fail("finding_resolution_missing", f"finding {finding_id} has no resolution text")

    contracts = record["local_contracts"]
    if not isinstance(contracts, list) or not contracts:
        fail("local_contracts_missing", "at least one reviewed local contract outcome is required")
    contract_names: set[str] = set()
    for row in contracts:
        row = object_with_fields(row, {"name", "outcome", "evidence"}, "local contract entry")
        name = row["name"]
        if not isinstance(name, str) or not name.strip() or name in contract_names:
            fail("contract_name_invalid", "local contract names must be nonempty and unique")
        contract_names.add(name)
        if row["outcome"] != "pass":
            fail("contract_failed", f"local contract did not pass: {name}")
        if not isinstance(row["evidence"], str) or not row["evidence"].strip():
            fail("contract_evidence_missing", f"local contract has no evidence description: {name}")

    return len(path_rows), len(expected_hunks), len(findings)


def main() -> int:
    default_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=default_root, help="repository root (default: this script's repository)")
    parser.add_argument("--record", type=Path, default=Path(DEFAULT_RECORD), help="repo-relative review JSON path")
    args = parser.parse_args()

    try:
        root = args.repo_root.resolve(strict=True)
        if not root.is_dir():
            fail("repo_root_invalid", "--repo-root must name an existing directory")
        record = load_record(root, args.record)
        file_count, hunk_count, finding_count = verify_record(root, record)
    except ReviewError as error:
        print(f"ERROR: {error.code}: {error.message}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"ERROR: filesystem_error: {error}", file=sys.stderr)
        return 1

    contract_count = len(record["local_contracts"])
    print(
        "Workflow review gate passed: "
        f"{file_count} workflow files, {hunk_count} reviewed hunks, "
        f"{finding_count} resolved findings, {contract_count} local contracts."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
