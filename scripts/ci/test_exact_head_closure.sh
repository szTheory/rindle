#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$root"
export PYTHONDONTWRITEBYTECODE=1
export ASDF_ERLANG_VERSION="${ASDF_ERLANG_VERSION:-27.3.4.15}"
export ASDF_ELIXIR_VERSION="${ASDF_ELIXIR_VERSION:-1.17.3-otp-27}"
python3 - "$root" <<'PY'
import copy,json,os,pathlib,shutil,subprocess,sys,tempfile,unittest
from unittest.mock import patch
root=pathlib.Path(sys.argv[1]);sys.path.insert(0,str(root/'scripts/maintainer'))
import readiness_closure as c
repo='szTheory/rindle';sha='a'*40

class ClosureTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.shared=pathlib.Path(tempfile.mkdtemp(prefix='rindle139-closure-shared-')).resolve()
        shell=(root/'scripts/ci/test_exact_head_readiness.sh').read_text()
        fixture='defmodule ReadinessFixture do'+shell.split('defmodule ReadinessFixture do',1)[1].split('\ndefmodule ReadinessPolicyTest do',1)[0]
        script=cls.shared/'generate.exs'
        script.write_text('Code.require_file("scripts/maintainer/validate_exact_head_readiness.exs")\n'+fixture+'''
{base,m} = ReadinessFixture.fixture()
File.write!(Path.join(base,"baseline-manifest.json"), Jason.encode!(m))
local = m |> Map.put("state","incomplete") |> Map.put("local_state","complete") |> Map.update!("proofs", &Enum.reject(&1, fn ref -> ref["id"] in Rindle.ExactHeadReadiness.mutable_proofs() end))
File.write!(Path.join(base,"local-manifest.json"), Jason.encode!(local))
envelope = ReadinessFixture.refresh(base,m)
for {position,proofs,interval} <- [{"close",m["proofs"],ReadinessFixture.interval()},{"refresh",envelope["proofs"],ReadinessFixture.interval(2)}],
    {kind,ids} <- [{"runs",~w(ci-main nightly-scheduled protection)},{"remote",~w(remote-inventory)},{"adoption",~w(adoption-parity)}] do
  sources = proofs |> Enum.filter(&(&1["id"] in ids)) |> Map.new(fn ref ->
    receipt=base |> Path.join(ref["path"]) |> File.read!() |> Jason.decode!()
    {ref["id"],Map.take(receipt,~w(source references))}
  end)
  value=%{"repository"=>m["repository"],"subject_sha"=>m["subject_sha"],"evidence_mode"=>"fixture","sources"=>sources,"observation_interval"=>interval}
  File.write!(Path.join(base,kind<>"-"<>position<>".json"),Jason.encode!(value))
end
IO.puts(Jason.encode!(%{base: base}))
''')
        env={**os.environ,**c.TOOLCHAIN_ENV,'RINDLE_EXACT_HEAD_LIBRARY_ONLY':'1','RINDLE_READINESS_TEST_ROOT':str(cls.shared)}
        result=subprocess.run(['mix','run','--no-start','--no-compile','--no-deps-check',str(script)],cwd=root,env=env,capture_output=True,timeout=45)
        if result.returncode:
            shutil.rmtree(cls.shared)
            raise AssertionError(result.stdout+result.stderr)
        cls.base=pathlib.Path(json.loads(result.stdout.decode().splitlines()[-1])['base'])
    @classmethod
    def tearDownClass(cls):shutil.rmtree(cls.shared)
    def setUp(self):
        self.tmp=pathlib.Path(tempfile.mkdtemp(prefix='rindle139-closure-')).resolve()
        self.fixture=self.tmp/'fixture';self.fixture.mkdir();shutil.copytree(self.base,self.fixture/'data')
        self.config={'repository':repo,'subject_sha':sha,'local_manifest':'data/local-manifest.json',
            'observation_interval':{'started_at':'2026-10-22T10:00:00Z','completed_at':'2026-10-22T10:01:00Z'}}
        for kind in ('runs','remote','adoption'):
            for position in ('before','after'):self.config[kind+'_'+position]='data/'+kind+'-close.json'
        self.save()
    def tearDown(self):shutil.rmtree(self.tmp)
    def save(self): (self.fixture/'closure.json').write_bytes(c.canonical(self.config))
    def close(self,refresh=False):
        self.save();out=self.tmp/'out'
        original=self.fixture/'data/baseline-manifest.json' if refresh else None
        owner=c.Closure(repo,out,original,self.fixture);code=owner.run()
        value=c.read_json(out/'verdict.json');self.assertFalse(value['requirements_credit']);self.assertEqual(value['evidence_mode'],'fixture')
        return code,value,owner
    def refreshing(self):
        self.config['observation_interval']={'started_at':'2026-10-22T10:02:00Z','completed_at':'2026-10-22T10:03:00Z'}
        for kind in ('runs','remote','adoption'):
            for position in ('before','after'):self.config[kind+'_'+position]='data/'+kind+'-refresh.json'
    def reject(self,reason,refresh=False):
        code,value,owner=self.close(refresh);self.assertEqual(code,1);self.assertEqual(value['reason'],reason)
        self.assertEqual(c.read_json(owner.output/'attempt.json')['verdict'],'not_ready')
        self.assertFalse((owner.portable/'refresh-envelope.json').exists());return owner
    def mutate_source(self,kind,id,fn):
        source=c.read_json(self.fixture/self.config[kind+'_after']);packet=source['sources'][id];normalized=packet['source']['normalized'];fn(normalized)
        observations=[]
        for side in ('before','after'):
            path=self.fixture/'data'/('changed/'+id+'-'+side+'.json');c.write_new(path,normalized)
            observations.append(c.reference(self.fixture/'data',path))
        old=packet['source']['observations'];packet['references']=[r for r in packet['references'] if r not in old]+observations
        packet['source'].update(normalized=normalized,observations=observations,before_sha256=observations[0]['sha256'],after_sha256=observations[1]['sha256'])
        path=self.fixture/'data'/('changed-'+kind+'.json');c.write_new(path,source);self.config[kind+'_after']='data/'+path.name
    def test_current_authoritative_state_keeps_independent_pilots_open(self):
        owner=c.Closure(repo,self.tmp/'adoption-reader')
        facts=owner.adoption_facts()
        self.assertEqual(facts['adoption']['pilot_01'],'open');self.assertFalse(facts['adoption']['one_point_zero_authority'])
    def test_candidate_joins_all_proofs_through_actual_validator(self):
        code,value,owner=self.close();self.assertEqual(code,0);self.assertEqual(value['verdict'],'candidate_ready')
        manifest=c.read_json(owner.portable/'manifest.json');self.assertEqual(len(manifest['proofs']),23)
        self.assertEqual(c.read_json(owner.output/'candidate-validation.json')['verdict'],'ready')
        self.assertEqual(c.read_json(owner.output/'initial-attempt.json')['verdict'],'not_ready')
    def test_main_changed_after_collections(self):
        self.config['main_sequence']=[sha,'b'*40];self.reject('main_changed')
    def test_main_changed_after_validator_cannot_publish_candidate(self):
        self.config['main_sequence']=[sha,sha,'b'*40];owner=self.reject('main_changed')
        self.assertFalse((owner.portable/'manifest.json').exists())
    def test_one_valid_newer_ci_source_defeats_stale_candidate(self):
        self.mutate_source('runs','ci-main',lambda n:n.update(run_id=11,latest_run_id=11));self.reject('mutable_source_changed')
    def test_missing_mutable_source(self):
        path=self.fixture/'data/runs-close.json';value=c.read_json(path);del value['sources']['protection'];path.write_bytes(c.canonical(value))
        self.reject('source_registry_incomplete')
    def test_wrong_source_subject(self):
        path=self.fixture/'data/remote-close.json';value=c.read_json(path);value['subject_sha']='b'*40;path.write_bytes(c.canonical(value));self.reject('source_subject_or_mode')
    def test_corrupt_local_log_bytes_fail_before_candidate(self):
        path=self.fixture/'data/logs/format.txt';path.write_bytes(b'corrupted');self.reject('object_digest_changed')
    def test_local_incomplete_cleanup(self):
        path=self.fixture/'data/local-manifest.json';value=c.read_json(path);value['cleanup']['state']='failed';path.write_bytes(c.canonical(value));self.reject('cleanup_failed')
    def test_mixed_fixture_and_execution_evidence_is_rejected(self):
        path=self.fixture/'data/local-manifest.json';value=c.read_json(path);value['evidence_mode']='execution';path.write_bytes(c.canonical(value));self.reject('local_subject_or_mode')
    def test_refresh_keeps_original_manifest_and_rebases_actual_bound_bytes(self):
        self.refreshing();original=self.fixture/'data/baseline-manifest.json';before=original.read_bytes()
        code,value,owner=self.close(True);self.assertEqual(code,0)
        self.assertEqual(original.read_bytes(),before);self.assertEqual((owner.portable/'manifest.json').read_bytes(),before)
        envelope=c.read_json(owner.portable/'refresh-envelope.json');self.assertEqual(envelope['manifest_sha256'],c.digest(before));self.assertEqual(len(envelope['proofs']),5)
        n=c.read_json(owner.portable/next(r for r in envelope['proofs'] if r['id']=='nightly-scheduled')['path'])['source']['normalized']
        self.assertTrue(n['incident_artifact']['path'].startswith('refresh/'));self.assertTrue((owner.portable/n['incident_artifact']['path']).is_file())
    def test_refresh_rejects_advanced_main(self):
        self.refreshing();self.config['main_sequence']=['b'*40];self.reject('main_changed',True)
    def test_refresh_rejects_changed_source_during_invocation(self):
        self.refreshing();self.mutate_source('runs','ci-main',lambda n:n.update(run_id=11,latest_run_id=11));self.reject('mutable_source_changed',True)
    def test_actual_cli_candidate_fixture(self):
        out=self.tmp/'cli';result=subprocess.run(['bash',str(root/'scripts/maintainer/exact_head_readiness.sh'),'close','--repo',repo,
            '--output',str(out),'--fixture',str(self.fixture)],capture_output=True,timeout=45)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertEqual(c.read_json(out/'verdict.json')['verdict'],'candidate_ready')

result=unittest.TextTestRunner(verbosity=1).run(unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__]))
if not result.wasSuccessful():raise SystemExit(1)
print(f'PASS exact-head closure: {result.testsRun} candidate/immutable-refresh fixtures; no READY credit')
PY
