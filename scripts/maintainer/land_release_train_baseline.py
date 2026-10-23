#!/usr/bin/env python3
"""Land the post-public-verification ledger through ordinary protected PR CI."""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


LEDGER = ".planning/RELEASE-TRAIN.md"
SHA = re.compile(r"[0-9a-f]{40}")
VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?")
COMMAND_TIMEOUT = 60
WAIT_SECONDS = 45 * 60
POLL_SECONDS = 15


class LandingError(Exception):
    """A failed prerequisite or an unconfirmed landing."""


def require(condition, message):
    if not condition:
        raise LandingError(message)


def command(*args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=COMMAND_TIMEOUT)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise LandingError("command unavailable or timed out: " + " ".join(args[:2])) from error
    # Do not print arbitrary process output: it can contain credential diagnostics.
    require(result.returncode == 0, "command failed: " + " ".join(args[:2]))
    return result.stdout.rstrip("\n")


def gh_json(*args):
    try:
        return json.loads(command("gh", *args))
    except json.JSONDecodeError as error:
        raise LandingError("GitHub returned invalid JSON") from error


def pull(repo, number, branch, head):
    data = gh_json("pr", "view", str(number), "--repo", repo, "--json",
                   "number,baseRefName,headRefName,headRefOid,isCrossRepository,state,mergedAt,mergeCommit,files")
    require(isinstance(data, dict), "invalid pull request response")
    require(data.get("number") == number and data.get("baseRefName") == "main"
            and data.get("headRefName") == branch and data.get("headRefOid") == head
            and data.get("isCrossRepository") is False,
            "pull request ref or head changed; inspect the baseline PR")
    files = data.get("files")
    require(isinstance(files, list) and len(files) == 1 and files[0].get("path") == LEDGER,
            "pull request must change only the baseline ledger")
    require(data.get("state") in ("OPEN", "MERGED"), "baseline PR closed without merging")
    return data


def checks_green(repo, head, contexts):
    pages = gh_json("api", "--paginate", "--slurp",
                    "repos/{}/commits/{}/check-runs?per_page=100".format(repo, head))
    require(isinstance(pages, list) and bool(pages), "invalid check-run pages")
    runs = []
    for page in pages:
        require(isinstance(page, dict) and isinstance(page.get("check_runs"), list),
                "invalid check-run page")
        runs.extend(page["check_runs"])
    pending = False
    for context in contexts:
        matching = [run for run in runs if run.get("name") == context
                    and run.get("head_sha") == head
                    and run.get("app", {}).get("slug") == "github-actions"]
        if not matching:
            pending = True
            continue
        latest = max(matching, key=lambda run: run["id"])
        if latest.get("status") != "completed":
            pending = True
        else:
            require(latest.get("conclusion") == "success", "required CI failed: " + context)
    return not pending


def summary(message):
    print(message)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as output:
            output.write(message + "\n")


def land(repo, version, base, release_sha, wait_seconds=WAIT_SECONDS, poll_seconds=POLL_SECONDS):
    require(re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo), "invalid repository")
    require(VERSION.fullmatch(version), "invalid release version")
    require(SHA.fullmatch(base) and SHA.fullmatch(release_sha), "immutable source SHAs required")
    require(command("git", "rev-parse", "HEAD") == base, "checkout changed after baseline source was frozen")
    require(command("git", "branch", "--show-current") == "main", "baseline source must be main")
    command("git", "merge-base", "--is-ancestor", release_sha, base)
    require(not command("git", "diff", "--cached", "--name-only"), "unexpected staged changes")
    status = command("git", "status", "--porcelain=v1", "--untracked-files=all")
    require(not status or status == " M " + LEDGER, "unexpected changed or untracked files")
    require(Path(LEDGER).is_file() and not Path(LEDGER).is_symlink(), "baseline ledger must be a regular file")
    if not status:
        summary("Baseline unchanged; no landing requested.")
        return
    require(Path(LEDGER).read_text(encoding="utf-8").count(
        "- Latest released version: `" + version + "` (Hex.pm,") == 1,
        "baseline version does not match the frozen release version")
    policy = gh_json("api", "repos/" + repo)
    require(policy.get("allow_auto_merge") is True, "normal auto-merge unavailable; no bypass permitted")
    main = gh_json("api", "repos/" + repo + "/commits/main")
    require(main.get("sha") == base, "main advanced since baseline checkout; rerun from current main")
    config = json.loads(Path("config/ci_required_checks.json").read_text(encoding="utf-8"))
    contexts = config.get("contexts")
    require(isinstance(contexts, list) and contexts and all(isinstance(c, str) and c for c in contexts),
            "configured required CI contexts missing")

    branch = "chore/release-train-baseline-" + version
    command("git", "config", "user.name", "github-actions[bot]")
    command("git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com")
    command("git", "checkout", "-b", branch)
    command("git", "add", "--", LEDGER)
    title = "chore(release): record " + version + " baseline in RELEASE-TRAIN.md"
    command("git", "commit", "-m", title)
    head = command("git", "rev-parse", "HEAD")
    require(SHA.fullmatch(head), "invalid committed baseline head")
    command("git", "push", "--set-upstream", "origin", "HEAD:refs/heads/" + branch)
    url = command("gh", "pr", "create", "--repo", repo, "--base", "main", "--head", branch,
                  "--title", title, "--body", "Automated baseline update after public verification for " + version + ".")
    match = re.fullmatch(r"https://github\.com/" + re.escape(repo) + r"/pull/([1-9][0-9]*)", url)
    require(match, "unexpected created pull request URL")
    number = int(match.group(1))
    initial = pull(repo, number, branch, head)
    require(initial["state"] == "OPEN", "new baseline PR is not open")
    command("gh", "pr", "merge", str(number), "--repo", repo, "--auto", "--squash",
            "--match-head-commit", head)
    summary("Baseline auto-merge requested: {} at {}. Landing remains pending.".format(url, head))
    deadline = time.monotonic() + wait_seconds
    while True:
        current = pull(repo, number, branch, head)
        green = checks_green(repo, head, contexts)
        # Re-read identity after CI observation; neither queued auto-merge nor CI
        # success alone can satisfy completion. GitHub enforces protected merge.
        current = pull(repo, number, branch, head)
        if current["state"] == "MERGED" and green:
            merge_sha = (current.get("mergeCommit") or {}).get("oid", "")
            require(SHA.fullmatch(merge_sha) and current.get("mergedAt"), "merged identity missing")
            summary("Baseline merged: {} head {} merge {} after required CI success.".format(url, head, merge_sha))
            return
        require(time.monotonic() < deadline,
                "baseline landing timed out; auto-merge may remain pending at " + url)
        time.sleep(poll_seconds)


def main():
    try:
        land(os.environ.get("GH_REPO", ""), os.environ.get("VERSION", ""),
             os.environ.get("BASELINE_BASE_SHA", ""), os.environ.get("RELEASE_SHA", ""))
    except (LandingError, OSError, ValueError, KeyError, TypeError) as error:
        summary("Baseline landing NOT confirmed: " + str(error))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
