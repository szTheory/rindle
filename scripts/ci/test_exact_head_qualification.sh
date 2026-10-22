#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$root"
PYTHONDONTWRITEBYTECODE=1 python3 - "$root" <<'PY'
import importlib.util, json, os, pathlib, shutil, subprocess, sys, tempfile, unittest
root = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location('readiness', root/'scripts/maintainer/exact_head_readiness.py')
r = importlib.util.module_from_spec(spec); spec.loader.exec_module(r)

class Fixture(r.Qualification):
    evidence_mode = 'fixture'
    fail = None
    def remote_main(self):
        return 'b'*40 if self.fail == 'main' else self.subject
    def checkout(self):
        self.workspace = pathlib.Path(tempfile.mkdtemp(prefix='rindle-readiness-source-')).resolve()/'source'
        self.checked(['git','clone','--quiet',str(self.root),str(self.workspace)],cwd=self.root)
        self.checked(['git','checkout','--quiet','--detach',self.subject])
        self.initial_clean = True
        if self.fail == 'dirty':
            (self.workspace/'unowned').write_text('residue')
            raise r.NotReady('dirty_checkout')
    def prepare(self):
        self.policy = {'commands': {'format': ['python3','-c','print("supported fixture gate")']}}
    def gate(self, id, argv):
        if self.fail == 'crash':
            raise OSError('fixture crash')
        return super().gate(id, argv)

class QualificationTest(unittest.TestCase):
    def setUp(self):
        self.temp = pathlib.Path(tempfile.mkdtemp(prefix='rindle139-qualification-')).resolve()
        self.source = self.temp/'repo'; self.source.mkdir()
        self.git('init','--quiet')
        self.git('config','user.name','Fixture'); self.git('config','user.email','fixture@invalid.example')
        (self.source/'tracked').write_text('immutable input')
        self.git('add','tracked'); self.git('commit','--quiet','-m','fixture source')
        self.sha = self.git('rev-parse','HEAD').decode().strip()
    def tearDown(self):
        shutil.rmtree(self.temp)
    def git(self,*argv):
        return subprocess.check_output(['git',*argv],cwd=self.source,stderr=subprocess.DEVNULL)
    def controller(self, failure=None):
        q=Fixture(self.source,self.temp/'out','szTheory/rindle',self.sha)
        q.fail=failure
        return q
    def test_one_real_command_in_fresh_subject_has_bytes_and_nonpassing_attempt(self):
        q=self.controller(); self.assertEqual(q.run(),1)
        value=r.read_json(q.output/'attempt.json')
        self.assertEqual(value['verdict'],'not_ready')
        self.assertEqual(value['proofs'],['format'])
        manifest=r.read_json(q.portable/'manifest.json')
        ref=manifest['proofs'][0]
        self.assertEqual(ref['sha256'],r.digest((q.portable/ref['path']).read_bytes()))
        receipt=r.read_json(q.portable/ref['path'])
        self.assertEqual(receipt['command']['exit_code'],0)
        self.assertEqual(receipt['evidence_mode'],'fixture')
        self.assertIn(b'supported fixture gate',(q.portable/receipt['command']['output']['path']).read_bytes())
        self.assertFalse(q.workspace.exists())
        self.assertEqual(self.git('status','--porcelain'),b'')
    def test_changed_main_never_clones_or_runs(self):
        q=self.controller('main'); self.assertEqual(q.run(),1)
        self.assertEqual(r.read_json(q.output/'attempt.json')['reason'],'main_changed')
        self.assertIsNone(q.workspace)
    def test_crash_persists_nonpassing_attempt_and_observed_cleanup(self):
        q=self.controller('crash'); self.assertEqual(q.run(),1)
        value=r.read_json(q.output/'attempt.json')
        self.assertEqual(value['verdict'],'not_ready')
        self.assertEqual(value['cleanup']['state'],'observed')
        self.assertFalse(q.workspace.exists())
    def test_dirty_checkout_never_qualifies(self):
        q=self.controller('dirty'); self.assertEqual(q.run(),1)
        self.assertEqual(r.read_json(q.output/'attempt.json')['verdict'],'not_ready')
        # The runner refuses to delete unexplained source residue.
        self.assertEqual(r.read_json(q.output/'attempt.json')['cleanup']['state'],'failed')
        shutil.rmtree(q.workspace.parent)
    def test_output_inside_source_and_reused_attempt_are_rejected(self):
        q=Fixture(self.source,self.source/'bad','szTheory/rindle',self.sha)
        with self.assertRaises(r.NotReady): q.run()
        q=self.controller(); q.run()
        with self.assertRaises(r.NotReady): self.controller().run()
    def test_real_subprocess_deadline_is_terminal(self):
        q=self.controller(); q.reserve()
        q.deadline=__import__('time').monotonic()+0.1
        with self.assertRaisesRegex(r.NotReady,'command_timeout'):
            q.command(['python3','-c','import time; time.sleep(60)'])
        self.assertTrue(list(q.private.glob('command-*.txt')))

unittest.main(argv=['qualification'],verbosity=1)
PY
printf 'PASS: exact-head qualification tracer; real command bytes, wrong SHA, dirty clone, crash and timeout rejection\n'
