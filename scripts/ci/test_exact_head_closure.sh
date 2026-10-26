#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$root"
export PYTHONDONTWRITEBYTECODE=1
export ASDF_ERLANG_VERSION="${ASDF_ERLANG_VERSION:-27.3.4.15}"
export ASDF_ELIXIR_VERSION="${ASDF_ELIXIR_VERSION:-1.17.3-otp-27}"
python3 - "$root" <<'PY'
import copy,json,os,pathlib,shutil,subprocess,sys,tempfile,unittest,time,signal
from unittest.mock import patch
root=pathlib.Path(sys.argv[1]);sys.path.insert(0,str(root/'scripts/maintainer'))
sys.path.insert(0,str(root/'scripts/ci'))
from readiness_validator_fixture import ValidatorFixture
import readiness_closure as c
repo='szTheory/rindle';sha='a'*40

class ValidatorWorkerTest(unittest.TestCase):
    def worker(self):
        worker=ValidatorFixture();self.addCleanup(worker.close);return worker
    def test_malformed_request_cannot_be_green(self):
        worker=self.worker()
        with self.assertRaises(AssertionError):worker.request({'not':'argv'})
        self.assertIsNotNone(worker.child.poll())
    def test_dead_worker_cannot_be_green(self):
        worker=self.worker();self.assertEqual(os.getpgid(worker.child.pid),os.getpgrp());worker.stop()
        with self.assertRaises((AssertionError,BrokenPipeError)):worker.request([])
    def test_deadline_stops_owned_worker_and_cannot_be_green(self):
        worker=self.worker()
        with self.assertRaisesRegex(AssertionError,'deadline'):worker.request([],timeout=0)
        self.assertIsNotNone(worker.child.poll())

class ClosureTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.shared=pathlib.Path(tempfile.mkdtemp(prefix='rindle139-closure-shared-')).resolve()
        fixture='Code.require_file("scripts/ci/readiness_fixture.exs")\n'
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
        if os.environ.get('RINDLE_READINESS_FRESH_VALIDATOR')!='1':
            cls.validator=ValidatorFixture();cls.addClassCleanup(cls.validator.close)
            original=c.Closure.command
            adapter=patch.object(c.Closure,'command',lambda owner,argv,seconds,**kwargs: cls.validator.command(original,owner,argv,seconds,**kwargs))
            adapter.start();cls.addClassCleanup(adapter.stop)
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
    def test_validator_worker_does_not_retain_previous_graph_state(self):
        worker=ValidatorFixture();self.addCleanup(worker.close)
        manifest=self.fixture/'data/baseline-manifest.json';before=manifest.read_bytes()
        outputs=[]
        for position,corrupt in enumerate([False,True,False]):
            if corrupt:
                value=json.loads(before);value['subject_sha']='b'*40;manifest.write_bytes(c.canonical(value))
            else:manifest.write_bytes(before)
            verdict=self.tmp/('worker-'+str(position)+'.json')
            code,_=worker.request(['--manifest',str(manifest),'--root',str(manifest.parent),'--verdict',str(verdict)])
            self.assertEqual(code,1 if corrupt else 0)
            outputs.append(verdict.read_bytes())
        self.assertEqual(outputs[0],outputs[2]);self.assertEqual(manifest.read_bytes(),before)
    def test_main_changed_after_collections(self):
        self.config['main_sequence']=[sha,'b'*40];self.reject('main_changed')
    def test_main_changed_after_validator_cannot_publish_candidate(self):
        self.config['main_sequence']=[sha,sha,'b'*40];owner=self.reject('main_changed')
        self.assertFalse((owner.portable/'manifest.json').exists())
    def test_changed_source_query_policy_cannot_reuse_equal_facts(self):
        value=c.read_json(self.fixture/'data/runs-close.json');value['sources']['ci-main']['source']['query']='different query policy'
        path=self.fixture/'data/changed-query.json';c.write_new(path,value);self.config['runs_after']='data/changed-query.json'
        self.reject('mutable_source_changed')
    def test_malformed_cleanup_attempt_is_a_nonpassing_terminal(self):
        self.save();owner=c.Closure(repo,self.tmp/'cleanup-crash',fixture=self.fixture)
        def broken_collect(_position):
            owner.mode='execution';owner.local_output=owner.private/'local-qualification';owner.local_output.mkdir()
            (owner.local_output/'attempt.json').write_text('not-json')
            raise c.NotReady('local_qualification_failed')
        with patch.object(owner,'collect',side_effect=broken_collect):self.assertEqual(owner.run(),1)
        self.assertEqual(c.read_json(owner.output/'verdict.json')['reason'],'cleanup_failed')
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
    def test_unexpected_crash_persists_nonpassing_terminal_and_private_diagnostics(self):
        with patch.object(c.Closure,'collect',side_effect=RuntimeError('PRIVATE-CLOSURE-CANARY')):
            code,value,owner=self.close()
        self.assertEqual(code,1);self.assertEqual(value['reason'],'closure_unavailable')
        self.assertNotIn(b'PRIVATE-CLOSURE-CANARY',(owner.output/'verdict.json').read_bytes())
        self.assertTrue((owner.private/'failure.json').is_file())
    def test_missing_scheduled_run_is_bounded_with_next_observation(self):
        value={'repository':repo,'subject_sha':sha,'evidence_mode':'fixture','verdict':'not_ready','reason':'scheduled_run_missing','sources':{}}
        path=self.fixture/'data/missing-scheduled.json';c.write_new(path,value);self.config['runs_before']='data/missing-scheduled.json'
        code,value,owner=self.close();self.assertEqual(code,1);self.assertEqual(value['reason'],'scheduled_run_missing')
        self.assertIn('scheduled Nightly',value['next_observation']);self.assertFalse((owner.portable/'manifest.json').exists())
    def test_owned_child_has_unblocked_termination_signal(self):
        child=c.popen_owned([sys.executable,'-c','import signal; print("blocked" if signal.SIGTERM in signal.pthread_sigmask(signal.SIG_BLOCK, []) else "unblocked",flush=True); signal.pause()'],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        try:
            self.assertEqual(child.stdout.readline().strip(),b'unblocked')
            c.stop_owned(child,.2);self.assertEqual(child.returncode,-signal.SIGTERM)
        finally:
            if child.poll() is None:os.killpg(child.pid,signal.SIGKILL);child.wait()
    def test_real_collection_deadline_persists_not_ready(self):
        self.save();owner=c.Closure(repo,self.tmp/'deadline',fixture=self.fixture,deadline=.01)
        self.assertEqual(owner.run(),1);value=c.read_json(owner.output/'verdict.json')
        self.assertIn(value['reason'],('closure_deadline','closure_command_timeout'));self.assertFalse(value['requirements_credit'])
    def test_invalid_fixture_after_reservation_has_terminal_reason(self):
        self.config['repository']='foreign/repo';self.save();out=self.tmp/'bad-fixture'
        self.assertEqual(c.main(['close','--repo',repo,'--output',str(out),'--fixture',str(self.fixture)]),1)
        self.assertEqual(c.read_json(out/'verdict.json')['reason'],'invalid_closure_fixture')
    def test_refresh_cannot_publish_after_original_manifest_changes(self):
        self.refreshing();original_validate=c.Closure.validate
        def change_original(owner,manifest,envelope=None):
            result=original_validate(owner,manifest,envelope)
            if envelope:owner.original.write_bytes(owner.original.read_bytes()+b' ')
            return result
        with patch.object(c.Closure,'validate',change_original):
            self.reject('manifest_bytes_changed',True)
    def test_refresh_rejects_omitted_mutable_receipt(self):
        self.refreshing();original_validate=c.Closure.validate
        def omit(owner,manifest,envelope=None):
            if envelope:
                value=c.read_json(envelope);value['proofs'].pop();c.atomic(envelope,value)
            return original_validate(owner,manifest,envelope)
        with patch.object(c.Closure,'validate',omit):self.reject('validator_refresh_inventory',True)
    def test_refresh_rejects_swapped_original_receipt(self):
        self.refreshing();original_validate=c.Closure.validate
        def swap(owner,manifest,envelope=None):
            if envelope:
                value=c.read_json(envelope);original=c.read_json(manifest)
                value['proofs'][0]=next(r for r in original['proofs'] if r['id']==value['proofs'][0]['id']);c.atomic(envelope,value)
            return original_validate(owner,manifest,envelope)
        with patch.object(c.Closure,'validate',swap):self.reject('validator_refresh_inventory',True)
    def test_forged_ready_envelope_cannot_override_failed_refreshed_receipt(self):
        self.refreshing();original_validate=c.Closure.validate
        def forge(owner,manifest,envelope=None):
            if envelope:
                value=c.read_json(envelope);ref=value['proofs'][0];path=owner.portable/ref['path'];receipt=c.read_json(path)
                receipt['outcome']='failed';c.atomic(path,receipt);value['proofs'][0]['sha256']=c.digest(path.read_bytes());value['verdict']='ready';c.atomic(envelope,value)
            return original_validate(owner,manifest,envelope)
        with patch.object(c.Closure,'validate',forge):self.reject('validator_proof_outcome',True)
    def test_cleanup_failure_cannot_be_hidden_by_original_collection_failure(self):
        with patch.object(c.Closure,'collect',side_effect=c.NotReady('scheduled_run_missing')),patch.object(c.Closure,'retry_cleanup',return_value={'state':'failed'}):
            self.reject('cleanup_failed')
    def test_cleanup_retry_has_separate_budget_and_preserves_actual_original_bytes(self):
        owner=c.Closure(repo,self.tmp/'cleanup-budget',deadline=-1)
        owner.output.mkdir();owner.private=owner.output/'restricted';owner.private.mkdir();owner.portable=owner.output/'portable';owner.portable.mkdir()
        owner.local_output=owner.private/'local-qualification';owner.local_output.mkdir()
        (owner.local_output/'restricted').mkdir();(owner.local_output/'portable').mkdir()
        attempt={'schema_version':1,'run_id':'f'*32,'repository':repo,'subject_sha':sha,'workspace':None,'verdict':'not_ready'}
        path=owner.local_output/'attempt.json';before=json.dumps(attempt,indent=2).encode();path.write_bytes(before)
        result=owner.retry_cleanup();self.assertEqual(result['state'],'observed');self.assertTrue(result['original_attempt_unchanged'])
        self.assertEqual(path.read_bytes(),before)
    def test_actual_cli_sigterm_stops_owned_children_and_records_not_ready(self):
        self.save();out=self.tmp/'interrupted'
        child=subprocess.Popen(['bash',str(root/'scripts/maintainer/exact_head_readiness.sh'),'close','--repo',repo,
            '--output',str(out),'--fixture',str(self.fixture)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
        end=time.monotonic()+10
        while time.monotonic()<end and not list((out/'restricted').glob('command-*.log')) and child.poll() is None:time.sleep(.01)
        self.assertIsNone(child.poll());child.terminate();stdout,stderr=child.communicate(timeout=10)
        self.assertEqual(child.returncode,1,stdout+stderr);self.assertEqual(c.read_json(out/'verdict.json')['reason'],'closure_interrupted')
    def test_actual_cli_candidate_fixture(self):
        out=self.tmp/'cli';result=subprocess.run(['bash',str(root/'scripts/maintainer/exact_head_readiness.sh'),'close','--repo',repo,
            '--output',str(out),'--fixture',str(self.fixture)],capture_output=True,timeout=45)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertEqual(c.read_json(out/'verdict.json')['verdict'],'candidate_ready')

result=unittest.TextTestRunner(verbosity=1).run(unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__]))
if not result.wasSuccessful():raise SystemExit(1)
print(f'PASS exact-head closure: {result.testsRun} candidate/immutable-refresh fixtures; no READY credit')
PY
