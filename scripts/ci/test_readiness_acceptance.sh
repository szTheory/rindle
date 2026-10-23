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
import readiness_acceptance as a
import readiness_retention as r
repo='szTheory/rindle';sha='a'*40
class Main:
    def __init__(self,values):self.values=list(values);self.n=0
    def path(self,p):return 'repos/'+repo+'/'+p
    def get(self,p):
        value=self.values[min(self.n,len(self.values)-1)];self.n+=1
        return {'ref':'refs/heads/main','object':{'type':'commit','sha':value}},{}
class Acceptance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.shared=pathlib.Path(tempfile.mkdtemp(prefix='rindle139-acceptance-shared-')).resolve()
        script=cls.shared/'generate.exs';script.write_text('Code.require_file("scripts/ci/readiness_fixture.exs"); {base,m}=ReadinessFixture.fixture(); File.write!(Path.join(base,"manifest.json"),Jason.encode!(m)); e=ReadinessFixture.refresh(base,m); File.write!(Path.join(base,"refresh-envelope.json"),Jason.encode!(e)); IO.puts(Jason.encode!(%{base: base}))')
        env={**os.environ,'RINDLE_EXACT_HEAD_LIBRARY_ONLY':'1','RINDLE_READINESS_TEST_ROOT':str(cls.shared)}
        result=subprocess.run(['mix','run','--no-start','--no-compile','--no-deps-check',str(script)],cwd=root,env=env,capture_output=True,timeout=45)
        if result.returncode:raise AssertionError(result.stdout+result.stderr)
        cls.base=pathlib.Path(json.loads(result.stdout.decode().splitlines()[-1])['base'])
    @classmethod
    def tearDownClass(cls):shutil.rmtree(cls.shared)
    def setUp(self):self.tmp=pathlib.Path(tempfile.mkdtemp(prefix='rindle139-acceptance-')).resolve()
    def tearDown(self):shutil.rmtree(self.tmp)
    def subject(self):return {'repository':repo,'subject_sha':sha,'tracked_inventory':{},'requirements_credit':False}
    def retained(self,_repo,_run,_attempt,destination,_fixture):
        destination.mkdir();shutil.copytree(self.base,destination/'bundle')
        manifest=(destination/'bundle/manifest.json').read_bytes();archive=b'fixture producer archive'
        sidecar={'repository':repo,'subject_sha':sha,'run_id':1,'run_attempt':1,'evidence_mode':'fixture','archive_sha256':a.digest(archive),'manifest_sha256':a.digest(manifest)}
        a.write_new(destination/'readiness-digest.json',sidecar);a.write_new(destination/'readiness-evidence.tar.gz',archive)
        locator={'bytes_verified':True,'repository':repo,'subject_sha':sha,'run_id':1,'run_attempt':1,'evidence_mode':'fixture','storage_scope':'fixture_only',**{k:sidecar[k] for k in ('archive_sha256','manifest_sha256')},'producer_sidecar_sha256':a.digest((destination/'readiness-digest.json').read_bytes())}
        a.write_new(destination/'locator.json',locator);return locator
    def refreshing(self,_owner,manifest,output):
        output.mkdir();shutil.copytree(self.base,output/'portable')
        value={'verdict':'candidate_ready','requirements_credit':False,'observation_interval':a.read_json(self.base/'refresh-envelope.json')['observation_interval']}
        a.write_new(output/'verdict.json',value);return value
    def run_accept(self,transport=None,refresh=None,subject=None):
        owner=a.Acceptance(repo,self.tmp/'accepted','fixture')
        def setup():
            a.reserve(owner.output);owner.reserved=True;owner.api=Main([sha])
        with patch.object(owner,'setup',side_effect=setup),patch.object(owner,'subject_record',side_effect=subject or self.subject),patch.object(owner,'dispatch'),patch.object(owner,'producer',return_value=(1,1)),patch.object(a,'retrieve',side_effect=transport or self.retained),patch.object(a.Acceptance,'refresh',refresh or (lambda owner,manifest,output:self.refreshing(owner,manifest,output))):
            code=owner.run()
        return code,a.read_json(owner.output/'terminal-verdict.json')
    def test_fixture_controller_uses_actual_refresh_validator_without_credit(self):
        code,value=self.run_accept();self.assertEqual(code,0);self.assertEqual(value['verdict'],'fixture_ready');self.assertFalse(value['requirements_credit']);self.assertEqual(value['subject_sha'],sha)
    def test_missing_uploaded_bundle(self):
        code,value=self.run_accept(transport=lambda *args:(_ for _ in ()).throw(a.NotReady('producer_sidecar_missing_or_ambiguous')))
        self.assertEqual(code,1);self.assertEqual(value['reason'],'producer_sidecar_missing_or_ambiguous');self.assertFalse(value['requirements_credit'])
    def test_wrong_durable_attempt_subject(self):
        def wrong(*args):return {**self.retained(*args),'subject_sha':'b'*40}
        code,value=self.run_accept(transport=wrong);self.assertEqual(code,1);self.assertEqual(value['reason'],'durable_subject_or_mode')
    def test_refresh_scalar_cannot_override_failed_receipt(self):
        def wrong(owner,manifest,output):
            self.refreshing(owner,manifest,output);envelope=a.read_json(output/'portable/refresh-envelope.json');envelope['proofs'].pop();(output/'portable/refresh-envelope.json').write_bytes(a.canonical(envelope))
        code,value=self.run_accept(refresh=wrong);self.assertEqual(code,1);self.assertTrue(value['reason'].startswith('validator_'))
    def test_missing_durable_bytes(self):
        def wrong(*args):
            value=self.retained(*args);(args[3]/'bundle/manifest.json').unlink();return value
        code,value=self.run_accept(transport=wrong);self.assertEqual(code,1);self.assertFalse(value['requirements_credit'])
    def test_main_advanced_before_terminal(self):
        calls=[]
        def subject():
            calls.append(1);return {**self.subject(),'subject_sha':sha if len(calls)==1 else 'b'*40}
        code,value=self.run_accept(subject=subject);self.assertEqual(code,1);self.assertEqual(value['reason'],'main_changed')
    def test_fixture_terminal_cannot_be_read_as_execution(self):
        self.run_accept()
        with self.assertRaisesRegex(a.NotReady,'terminal_verdict_not_ready'):a.stored_bytes(repo,self.tmp/'accepted/terminal-verdict.json',None)
    def test_advanced_main_is_historical_and_no_current_credit(self):
        self.run_accept();path=self.tmp/'accepted/terminal-verdict.json'
        with patch.object(a,'GitHub',return_value=Main(['b'*40])):
            value=a.claim_status(repo,path,self.tmp/'historical','fixture')
        self.assertEqual(value['status'],'historical_ready');self.assertFalse(value['current_readiness']);self.assertFalse(value['requirements_credit'])
    def test_current_main_requires_new_refresh(self):
        self.run_accept();path=self.tmp/'accepted/terminal-verdict.json';calls=[]
        def refresh(owner,manifest,output):calls.append(1);return self.refreshing(owner,manifest,output)
        with patch.object(a,'GitHub',return_value=Main([sha])),patch.object(a,'verify_subject',side_effect=lambda *args:self.subject()),patch.object(a.Acceptance,'refresh',refresh):
            value=a.claim_status(repo,path,self.tmp/'current','fixture')
        self.assertEqual(len(calls),1);self.assertEqual(value['status'],'fixture_current_ready');self.assertFalse(value['current_readiness'])
    def test_changed_archive_rejects_historical_claim(self):
        self.run_accept();(self.tmp/'accepted/durable/readiness-evidence.tar.gz').write_bytes(b'corrupt')
        with self.assertRaisesRegex(a.NotReady,'object_digest_changed'):a.claim_status(repo,self.tmp/'accepted/terminal-verdict.json',self.tmp/'claim','fixture')
    def test_changed_refresh_object_rejects_historical_claim(self):
        self.run_accept();path=self.tmp/'accepted/refresh/portable';envelope=a.read_json(path/'refresh-envelope.json');receipt=a.read_json(path/envelope['proofs'][0]['path']);ref=receipt['source']['observations'][0];(path/ref['path']).write_bytes(b'corrupt')
        with patch.object(a,'GitHub',return_value=Main(['b'*40])):
            with self.assertRaises(a.NotReady):a.claim_status(repo,self.tmp/'accepted/terminal-verdict.json',self.tmp/'claim','fixture')
    def test_existing_output_is_immutable(self):
        output=self.tmp/'old';output.mkdir();(output/'attempt.json').write_bytes(b'original')
        with patch.object(a,'durable_path'):
            self.assertEqual(a.Acceptance(repo,output,'fixture').run(),1)
        self.assertEqual((output/'attempt.json').read_bytes(),b'original')
    def test_unqualified_checked_requirement_rejected(self):
        path=self.tmp/'.planning';path.mkdir();(path/'REQUIREMENTS.md').write_text('- [x] **READY-01**: Complete\n')
        with self.assertRaisesRegex(a.NotReady,'unqualified_readiness_metadata'):a.metadata_parity(self.tmp,sha,{'started_at':'start','completed_at':'end'})
    def test_historical_checked_requirement_is_qualified(self):
        path=self.tmp/'.planning';path.mkdir();(path/'REQUIREMENTS.md').write_text('- [x] **READY-01**: historical '+sha+' start end terminal-verdict\n')
        a.metadata_parity(self.tmp,sha,{'started_at':'start','completed_at':'end'})
    def test_unqualified_complete_traceability_row_rejected(self):
        path=self.tmp/'.planning';path.mkdir();(path/'REQUIREMENTS.md').write_text('| READY-05 | Phase 139 | Complete |\n')
        with self.assertRaises(a.NotReady):a.metadata_parity(self.tmp,sha,{'started_at':'start','completed_at':'end'})
    def test_unqualified_summary_rejected(self):
        path=self.tmp/a.PHASE;path.mkdir(parents=True);(path/'139-07-SUMMARY.md').write_text('---\nstatus: complete\n---\nready\n')
        with self.assertRaises(a.NotReady):a.metadata_parity(self.tmp,sha,{'started_at':'start','completed_at':'end'})
    def checkout(self):
        checkout=self.tmp/'checkout';checkout.mkdir()
        for relative in a.declared_files():
            path=checkout/relative;path.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(root/relative,path)
        for args in (('init','--quiet'),('config','user.name','Fixture'),('config','user.email','fixture@invalid.example'),('add','.'),('commit','--quiet','-m','fixture')):a.git(checkout,*args)
        return checkout,a.git(checkout,'rev-parse','HEAD').decode().strip()
    def test_subject_requires_actual_clean_git_and_all_eight_plans(self):
        checkout,subject=self.checkout();value=a.verify_subject(Main([subject]),repo,checkout)
        self.assertEqual(value['subject_sha'],subject);self.assertIn(a.PHASE+'/139-CONTEXT.md',value['tracked_inventory']);self.assertIn(a.PHASE+'/139-06-SUMMARY.md',value['tracked_inventory']);self.assertTrue(all(f'{a.PHASE}/139-{n:02d}-PLAN.md' in value['tracked_inventory'] for n in range(8)))
    def test_unmerged_subject_refused(self):
        checkout,subject=self.checkout()
        with self.assertRaisesRegex(a.NotReady,'closing_subject_not_checked_out'):a.verify_subject(Main([sha]),repo,checkout)
    def test_dirty_subject_refused(self):
        checkout,subject=self.checkout();(checkout/'untracked').write_text('dirty')
        with self.assertRaisesRegex(a.NotReady,'dirty_closing_checkout'):a.verify_subject(Main([subject]),repo,checkout)
    def test_dispatch_fixture_cannot_mutate_github(self):
        with self.assertRaisesRegex(a.NotReady,'fixture_dispatch_forbidden'):a.Acceptance(repo,self.tmp/'out','').dispatch('nonce')
    def test_pending_and_wrong_attempt_producer(self):
        owner=a.Acceptance(repo,self.tmp/'out','fixture');owner.subject=sha
        class Runs(Main):
            def pages(self,*args,**kwargs):return []
        owner.api=Runs([sha])
        with self.assertRaisesRegex(a.NotReady,'producer_pending'):owner.producer('nonce')
        owner.api.pages=lambda *args,**kwargs:[{'display_title':'Readiness nonce','head_sha':sha,'path':a.WORKFLOW,'name':a.WORKFLOW_NAME,'head_branch':'main','event':'workflow_dispatch','id':3,'run_attempt':2}]
        with self.assertRaisesRegex(a.NotReady,'producer_request_identity'):owner.producer('nonce')

unittest.main(argv=['acceptance'],verbosity=1)
PY
echo 'PASS: merged-subject inventory, durable acceptance join, fresh current/historical claims and no fixture credit'
