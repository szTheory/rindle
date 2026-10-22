#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$root"
export PYTHONDONTWRITEBYTECODE=1
python3 - "$root" <<'PY'
import copy,json,pathlib,shutil,subprocess,sys,tempfile,unittest
root=pathlib.Path(sys.argv[1]);sys.path.insert(0,str(root/'scripts/maintainer'))
import readiness_adoption as a

class Adoption(unittest.TestCase):
    def setUp(self):
        self.tmp=pathlib.Path(tempfile.mkdtemp(prefix='rindle139-adoption-')).resolve()
        for relative in a.INPUTS:
            path=self.tmp/relative;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes((root/relative).read_bytes())
    def tearDown(self):shutil.rmtree(self.tmp)
    def mutate(self,path,fn):
        path=self.tmp/path;path.write_text(fn(path.read_text()))
    def rejects(self,reason='adoption_inflation',classification=None):
        with self.assertRaisesRegex(a.NotReady,reason):a.check(self.tmp,classification)
    def test_actual_repository_parity(self):
        value=a.check(root);self.assertEqual(value['adoption'],a.SYNTHETIC);self.assertEqual(len(value['authoritative_inputs']),5)
    def test_real_state_copy_remains_synthetic(self):self.assertEqual(a.check(self.tmp)['adoption']['pilot_02'],'open')
    def test_pilot_01_checked(self):self.mutate(a.INPUTS[0],lambda s:s.replace('- **PILOT-01**:','- [x] **PILOT-01**:'));self.rejects()
    def test_pilot_02_checked(self):self.mutate(a.INPUTS[0],lambda s:s.replace('- **PILOT-02**:','- [x] **PILOT-02**:'));self.rejects()
    def test_missing_pilot_requirement(self):self.mutate(a.INPUTS[0],lambda s:s.replace('PILOT-01','REMOVED-01'));self.rejects()
    def test_duplicate_pilot_requirement(self):self.mutate(a.INPUTS[0],lambda s:s+'\n- **PILOT-01**: Duplicate.\n');self.rejects()
    def test_independent_project_claim(self):self.mutate(a.INPUTS[1],lambda s:s+'\nIndependent Phoenix pilot: verified.\n');self.rejects()
    def test_claim_cannot_hide_behind_later_negation(self):self.mutate(a.INPUTS[1],lambda s:s+'\nIndependent adopter verified; not synthetic.\n');self.rejects()
    def test_reverse_independent_claim_is_rejected(self):
        self.mutate(a.INPUTS[1],lambda s:s+'\nWe verified an independent Phoenix pilot.\n');self.rejects()
    def test_current_one_point_zero_authorization_is_rejected(self):
        self.mutate(a.INPUTS[1],lambda s:s.replace('**Goal:**','We authorize release 1.0 from the synthetic twin.\n\n**Goal:**',1));self.rejects('one_point_zero_authority')
    def test_requirements_claim_inflation(self):self.mutate(a.INPUTS[0],lambda s:s+'\nPILOT-01 is complete.\n');self.rejects()
    def test_missing_synthetic_boundary(self):self.mutate(a.INPUTS[1],lambda s:s.replace('synthetic twin cannot satisfy it','synthetic twin satisfies it'));self.rejects('adoption_boundary_missing')
    def test_project_version_cannot_be_one_point_zero(self):
        self.mutate('mix.exs',lambda s:__import__('re').sub(r'@version "[^"]+"','@version "1.0.0"',s));self.rejects('one_point_zero_authority')
    def test_release_manifest_one_point_zero(self):
        (self.tmp/'.release-please-manifest.json').write_text('{".":"1.0.0"}');self.rejects('one_point_zero_authority')
    def test_release_intent_cannot_claim_one_point_zero(self):
        p=self.tmp/'release-please-config.json';v=json.loads(p.read_bytes());v['release-as']='1.0.0';p.write_text(json.dumps(v));self.rejects('one_point_zero_authority')
    def test_synthetic_receipt_cannot_award_independent_credit(self):self.rejects(classification={**a.SYNTHETIC,'independent_pilot_credit':True})
    def test_synthetic_receipt_cannot_award_one_point_zero(self):self.rejects(classification={**a.SYNTHETIC,'one_point_zero_authority':True})
    def test_unknown_receipt_claim_is_not_ignored(self):self.rejects(classification={**a.SYNTHETIC,'independent_verified':True})
    def test_actual_cli(self):
        result=subprocess.run([sys.executable,str(root/'scripts/maintainer/readiness_adoption.py'),'--root',str(self.tmp)],capture_output=True)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertFalse(json.loads(result.stdout)['requirements_credit'])

result=unittest.TextTestRunner(verbosity=1).run(unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__]))
if not result.wasSuccessful():raise SystemExit(1)
print(f'PASS readiness adoption: {result.testsRun} actual-state/synthetic-rejection fixtures; no READY credit')
PY
