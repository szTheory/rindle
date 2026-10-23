#!/usr/bin/env python3
"""Offline behavioral checks: real Git repositories, fake GitHub, no credentials."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
OWNER = ROOT / "scripts/maintainer/land_release_train_baseline.py"
LEDGER = ".planning/RELEASE-TRAIN.md"
REPO = "fixture/baseline"
VERSION = "0.9.1"

FAKE_GH = r'''#!/usr/bin/env python3
import json, os, pathlib, subprocess, sys
args=sys.argv[1:]
root=pathlib.Path(os.environ['FIXTURE_STATE'])
mode=os.environ.get('FIXTURE_MODE','success')
with (root/'calls.jsonl').open('a') as out: out.write(json.dumps(args)+'\n')
def count(name):
    p=root/name
    n=int(p.read_text())+1 if p.exists() else 1
    p.write_text(str(n))
    return n
def fail(): print('fixture rejected',file=sys.stderr); sys.exit(1)
def emit(data): print(json.dumps(data)); sys.exit(0)
head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
base=os.environ['FIXTURE_BASE']
if mode=='auth_failure': fail()
if args[:2]==['api','repos/fixture/baseline']:
    emit({'allow_auto_merge':mode!='auto_disabled'})
if args[:2]==['api','repos/fixture/baseline/commits/main']:
    emit({'sha':'a'*40 if mode=='main_advanced' else base})
if args[:2]==['pr','create']:
    if mode=='create_failure': fail()
    print('https://github.com/'+('other/repo' if mode=='foreign_url' else 'fixture/baseline')+'/pull/17')
    sys.exit(0)
if args[:2]==['pr','merge']:
    assert '--admin' not in args and '--auto' in args and '--squash' in args
    assert args[args.index('--match-head-commit')+1]==head
    if mode=='merge_failure': fail()
    sys.exit(0)
if args[:2]==['pr','view']:
    n=count('views')
    checks=int((root/'checks').read_text()) if (root/'checks').exists() else 0
    state='MERGED' if checks>=2 or (mode=='merged_without_ci' and n>1) else 'OPEN'
    if mode=='closed' and n>1: state='CLOSED'
    if mode=='queued': state='OPEN'
    data={'number':17,'baseRefName':'main','headRefName':'chore/release-train-baseline-0.9.1',
          'headRefOid':head,'isCrossRepository':False,'state':state,
          'files':[{'path':'.planning/RELEASE-TRAIN.md','additions':1,'deletions':1}],
          'mergedAt':'2026-10-23T19:00:00Z' if state=='MERGED' else None,
          'mergeCommit':{'oid':'b'*40} if state=='MERGED' else None}
    if mode=='wrong_head' or (mode=='head_drift' and n>1): data['headRefOid']='c'*40
    if mode=='wrong_branch': data['headRefName']='other'
    if mode=='wrong_base': data['baseRefName']='other'
    if mode=='wrong_number': data['number']=99
    if mode=='cross_repo': data['isCrossRepository']=True
    if mode=='wrong_files': data['files'].append({'path':'mix.exs'})
    if mode=='missing_merge': data['mergeCommit']=None
    emit(data)
if args[:3]==['api','--paginate','--slurp']:
    n=count('checks')
    run={'id':22,'name':'CI Summary','head_sha':head,'app':{'slug':'github-actions'},
         'status':'completed' if n>=2 else 'in_progress','conclusion':'success' if n>=2 else None}
    if mode in ('queued','merged_without_ci'): run['status']='queued'; run['conclusion']=None
    if mode=='failed_ci': run['status']='completed'; run['conclusion']='failure'
    if mode=='skipped_ci': run['status']='completed'; run['conclusion']='skipped'
    if mode=='wrong_ci_head': run['head_sha']='d'*40
    if mode=='foreign_ci': run['app']['slug']='other'
    if mode=='missing_ci': run['name']='Other check'
    if mode=='malformed_ci': emit({})
    old=dict(run,id=1,status='completed',conclusion='success')
    if mode=='additional_context': old['name']='Other required check'; old['status']='queued'; old['conclusion']=None
    emit([{'check_runs':[old]},{'check_runs':[run]}])
fail()
'''

LAUNCH = r'''
import importlib.util, itertools, os
spec=importlib.util.spec_from_file_location('landing',os.environ['OWNER'])
module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
clock=itertools.count(); module.time.monotonic=lambda:next(clock)
module.time.sleep=lambda seconds:None
try:
    module.land(os.environ['GH_REPO'],os.environ['VERSION'],os.environ['BASELINE_BASE_SHA'],
                os.environ['RELEASE_SHA'],wait_seconds=2,poll_seconds=0)
except module.LandingError as error:
    module.summary('Baseline landing NOT confirmed: '+str(error))
    raise SystemExit(1)
'''


class LandingTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="rindle-baseline-fixture-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.state = self.root / "state"
        self.state.mkdir()
        fake = self.bin / "gh"
        fake.write_text(FAKE_GH, encoding="utf-8")
        fake.chmod(0o755)
        subprocess.run(["git", "init", "--bare", "--quiet", str(self.root / "remote")], check=True)
        self.git("init", "--quiet", "--initial-branch=main")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        (self.repo / ".planning").mkdir()
        (self.repo / "config").mkdir()
        self.ledger = self.repo / LEDGER
        self.ledger.write_text("## Current Baseline\n\n- Latest released version: `0.9.0` (Hex.pm, 2026-10-22)\n")
        (self.repo / "config/ci_required_checks.json").write_text(json.dumps({"contexts": ["CI Summary"]}))
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "fixture source")
        self.base = self.git("rev-parse", "HEAD")
        self.git("remote", "add", "origin", str(self.root / "remote"))
        self.git("push", "--quiet", "origin", "main")
        self.ledger.write_text(self.ledger.read_text().replace("0.9.0", VERSION))
        self.env = {**os.environ, "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
                    "OWNER": str(OWNER), "FIXTURE_STATE": str(self.state), "FIXTURE_BASE": self.base,
                    "GH_REPO": REPO, "VERSION": VERSION, "BASELINE_BASE_SHA": self.base,
                    "RELEASE_SHA": self.base, "GITHUB_STEP_SUMMARY": str(self.root / "summary")}
        # Fixtures never inherit a real credential or Git commit hook/template.
        for key in ("GH_TOKEN", "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN"):
            self.env.pop(key, None)
        self.env["GIT_CONFIG_GLOBAL"] = os.devnull
        self.env["GIT_CONFIG_NOSYSTEM"] = "1"

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.repo, stderr=subprocess.DEVNULL, text=True).strip()

    def run_owner(self, mode="success", success=False, message=None):
        result = subprocess.run([sys.executable, "-c", LAUNCH], cwd=self.repo,
                                env={**self.env, "FIXTURE_MODE": mode}, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0 if success else 1, result.stdout + result.stderr)
        if message:
            self.assertIn(message, result.stdout)
        if not success:
            self.assertNotIn("Baseline merged:", result.stdout)
        return result

    def calls(self):
        path = self.state / "calls.jsonl"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_queued_then_green_then_actually_merged(self):
        result = self.run_owner(success=True, message="Baseline merged:")
        self.assertIn("Landing remains pending", result.stdout)
        head = self.git("rev-parse", "HEAD")
        self.assertNotIn("[skip ci]", self.git("log", "-1", "--format=%s"))
        self.assertEqual(self.git("diff", "--name-only", self.base, head), LEDGER)
        self.assertEqual(self.git("rev-parse", "refs/remotes/origin/chore/release-train-baseline-" + VERSION), head)
        merge = next(c for c in self.calls() if c[:2] == ["pr", "merge"])
        self.assertIn("--auto", merge)
        self.assertIn("--squash", merge)
        self.assertNotIn("--admin", merge)
        self.assertEqual(merge[merge.index("--match-head-commit") + 1], head)
        self.assertEqual((self.state / "checks").read_text(), "2")

    def test_unchanged_needs_no_pr_or_merge(self):
        self.git("restore", "--", LEDGER)
        self.run_owner(success=True, message="Baseline unchanged")
        self.assertEqual(self.calls(), [])

    def test_failures_never_report_a_landing(self):
        for mode in ("auth_failure", "auto_disabled", "main_advanced", "create_failure", "foreign_url",
                     "wrong_head", "wrong_branch", "wrong_base", "wrong_number", "cross_repo", "wrong_files",
                     "merge_failure", "head_drift", "closed", "missing_merge", "queued", "merged_without_ci",
                     "failed_ci", "skipped_ci", "wrong_ci_head", "foreign_ci", "missing_ci", "malformed_ci"):
            with self.subTest(mode=mode):
                # Each attempt starts from its own base and bare remote.
                self.git("checkout", "--force", "main")
                self.git("reset", "--hard", self.base)
                branch = "chore/release-train-baseline-" + VERSION
                subprocess.run(["git", "branch", "-D", branch], cwd=self.repo, capture_output=True)
                subprocess.run(["git", "push", "origin", "--delete", branch], cwd=self.repo, capture_output=True)
                for path in self.state.iterdir():
                    path.unlink()
                self.ledger.write_text(self.ledger.read_text().replace("0.9.0", VERSION))
                self.run_owner(mode)
                calls = self.calls()
                if mode in ("auth_failure", "auto_disabled", "main_advanced", "create_failure", "foreign_url",
                            "wrong_head", "wrong_branch", "wrong_base", "wrong_number", "cross_repo", "wrong_files"):
                    self.assertFalse(any(c[:2] == ["pr", "merge"] for c in calls))

    def test_unexpected_file_rejects_before_network(self):
        (self.repo / "extra").write_text("unexpected")
        self.run_owner(message="unexpected changed")
        self.assertEqual(self.calls(), [])

    def test_staged_ledger_rejects_before_network(self):
        self.git("add", LEDGER)
        self.run_owner(message="unexpected staged")
        self.assertEqual(self.calls(), [])

    def test_version_mismatch_rejects(self):
        self.env["VERSION"] = "0.9.2"
        self.run_owner(message="baseline version does not match")
        self.assertEqual(self.calls(), [])

    def test_invalid_version_rejects(self):
        self.env["VERSION"] = "--admin"
        self.run_owner(message="invalid release version")
        self.assertEqual(self.calls(), [])

    def test_frozen_head_mismatch_rejects(self):
        self.env["BASELINE_BASE_SHA"] = "e" * 40
        self.run_owner(message="checkout changed")
        self.assertEqual(self.calls(), [])

    def test_non_main_checkout_rejects(self):
        self.git("checkout", "-b", "other")
        self.run_owner(message="source must be main")
        self.assertEqual(self.calls(), [])

    def test_unrelated_release_sha_rejects(self):
        self.env["RELEASE_SHA"] = self.git("commit-tree", self.git("rev-parse", "HEAD^{tree}"), "-m", "unrelated source")
        self.run_owner(message="command failed: git merge-base")
        self.assertEqual(self.calls(), [])

    def test_push_rejection_never_creates_pr(self):
        self.git("remote", "set-url", "origin", str(self.root / "missing"))
        self.run_owner(message="command failed: git push")
        self.assertFalse(any(c[:2] == ["pr", "create"] for c in self.calls()))

    def test_all_configured_contexts_are_required(self):
        path = self.repo / "config/ci_required_checks.json"
        path.write_text(json.dumps({"contexts": ["CI Summary", "Other required check"]}))
        self.git("add", "config/ci_required_checks.json")
        self.git("commit", "--quiet", "-m", "fixture second context")
        self.base = self.git("rev-parse", "HEAD")
        self.env.update(BASELINE_BASE_SHA=self.base, FIXTURE_BASE=self.base)
        self.run_owner("additional_context", message="timed out")


if __name__ == "__main__":
    unittest.main(verbosity=2)
