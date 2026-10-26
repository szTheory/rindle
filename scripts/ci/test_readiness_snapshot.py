"""Moving-main integration and negative cases using the actual immutable validator."""
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts/maintainer'))
sys.path.insert(0,str(ROOT/'scripts/ci'))
from readiness_validator_fixture import ValidatorFixture
import exact_head_readiness as q
import readiness_acceptance as a
import readiness_closure as c
import readiness_retention as retention
import readiness_subject as subject
import readiness_adoption as adoption
import collect_readiness_runs as runs
import collect_readiness_remote as remote

REPO='szTheory/rindle';SHA='a'*40;MAIN='b'*40;NEXT='c'*40


def put(root,path,value):
    dest=root/path;dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_bytes(value if isinstance(value,bytes) else q.canonical(value))
    return q.reference(root,dest)


def binding(main,identity,observed='2026-10-22T10:00:30Z'):
    return {'schema':'rindle-readiness-snapshot-subject-v2','repository':REPO,'subject_sha':SHA,
        'current_main_sha':main,'observed_at':observed,'authenticated':True,'requirements_credit':False,
        'protected_main':{'name':'main','protected':True,'sha':main},
        'comparison':{'status':'ahead','base':SHA,'merge_base':SHA,'head':main},
        'push_run':{'id':10,'run_attempt':2,'head_sha':SHA,'head_branch':'main','event':'push','path':'.github/workflows/ci.yml',
                    'name':'CI','status':'completed','conclusion':'success'},
        'control_identity':{p:identity[p] for p in subject.CONTROL_PATHS}}


def upgrade(root,record,manifest,prefix):
    record['policy']=subject.POLICY
    record['remote_main_before']=MAIN;record['remote_main_after']=NEXT
    record['snapshot_subjects']=[put(root,prefix+'subject-before.json',binding(MAIN,manifest['input_identity'],record['observation_interval']['started_at'])),
        put(root,prefix+'subject-after.json',binding(NEXT,manifest['input_identity'],record['observation_interval']['completed_at']))]
    proofs=[]
    for ref in record['proofs']:
        receipt=q.read_json(root/ref['path']);receipt['policy']=subject.POLICY
        if 'source' in receipt:
            source=receipt['source'];source['policy']=subject.POLICY;n=source['normalized']
            if ref['id']=='remote-inventory':
                ledger=put(root,prefix+'authority/ledger.json',(ROOT/'.planning/INBOX-LEDGER.json').read_bytes())
                n.update(ledger_file=ledger,ledger_sha256=ledger['sha256'],authority_main_sha=NEXT)
                receipt['references'].append(ledger)
            if ref['id']=='adoption-parity':
                files={p:put(root,prefix+'authority/'+p,(ROOT/p).read_bytes()) for p in adoption.INPUTS}
                n.update(authoritative_files=files,authoritative_inputs={p:r['sha256'] for p,r in files.items()},authority_main_sha=NEXT)
                receipt['references']+=list(files.values())
            observations=[]
            for i,old in enumerate(source['observations']):
                observations.append(put(root,prefix+'observations/'+ref['id']+'-'+str(i)+'.json',n))
            oldpaths={r['path'] for r in source['observations']}
            receipt['references']=[r for r in receipt['references'] if r['path'] not in oldpaths]+observations
            source.update(observations=observations,before_sha256=observations[0]['sha256'],after_sha256=observations[-1]['sha256'])
        proofs.append({**put(root,ref['path'],receipt),'id':ref['id']})
    record['proofs']=proofs
    return record


class API:
    repo=REPO
    def __init__(self,main=MAIN):
        self.main=main
        self.run={'id':10,'run_attempt':2,'head_sha':SHA,'event':'push','head_branch':'main',
                  'repository':{'full_name':REPO},'name':'CI','path':'.github/workflows/ci.yml',
                  'created_at':'2026-10-22T07:27:00Z','status':'completed','conclusion':'success'}
    def path(self,p):return 'repos/'+REPO+'/'+p
    def get(self,p):
        if p.endswith('git/ref/heads/main'):return {'ref':'refs/heads/main','object':{'type':'commit','sha':self.main}},{}
        if p.endswith('branches/main'):return {'name':'main','protected':True,'commit':{'sha':self.main}},{}
        if '/compare/' in p:return {'status':'ahead','base_commit':{'sha':SHA},'merge_base_commit':{'sha':SHA},'url':'https://api.github.com/'+p},{}
        if p.endswith('actions/runs/10'):return copy.deepcopy(self.run),{}
        raise AssertionError(p)
    def pages(self,path,*args,**kwargs):return [copy.deepcopy(self.run)]
    def contents(self,path,sha):return (ROOT/path).read_bytes()


class Identity(unittest.TestCase):
    def test_authenticated_past_main_tip_admitted(self):
        value=subject.observe(API(),SHA)
        self.assertEqual(value['current_main_sha'],MAIN);self.assertEqual(value['subject_sha'],SHA)
    def test_pr_ancestor_without_push_main_provenance_refused(self):
        api=API();api.run['event']='pull_request'
        with self.assertRaisesRegex(q.NotReady,'snapshot_main_push_unproved'):subject.observe(api,SHA)
    def test_latest_failed_attempt_cannot_use_previous_green(self):
        api=API();older=copy.deepcopy(api.run);api.run.update(id=11,created_at='2026-10-23T00:00:00Z',conclusion='failure')
        api.pages=lambda *args,**kwargs:[older,api.run]
        original=api.get;api.get=lambda p:(api.run,{}) if p.endswith('actions/runs/11') else original(p)
        with self.assertRaisesRegex(q.NotReady,'latest_attempt_not_green'):subject.observe(api,SHA)
    def test_wrong_repository_refused(self):
        api=API();api.run['repository']['full_name']='fork/rindle'
        with self.assertRaisesRegex(q.NotReady,'snapshot_main_push_unproved'):subject.observe(api,SHA)
    def test_missing_candidate_policy_refused(self):
        api=API();api.contents=lambda *args:b'old policy'
        with self.assertRaisesRegex(q.NotReady,'snapshot_policy_mismatch'):subject.observe(api,SHA)
    def test_nonancestor_and_unprotected_refused(self):
        for target in ['comparison','protection']:
            api=API();original=api.get
            def get(p):
                if target=='comparison' and '/compare/' in p:return {'status':'diverged'},{}
                if target=='protection' and p.endswith('branches/main'):return {'name':'main','protected':False},{}
                return original(p)
            api.get=get
            with self.assertRaises(q.NotReady):subject.observe(api,SHA)
    def test_mutable_authority_uses_current_main(self):
        api=API();seen=[];api.contents=lambda p,sha:(seen.append(sha) or b'current')
        current,raw=subject.current_authority(api,['ledger']);self.assertEqual(current,MAIN);self.assertEqual(seen,[MAIN])
    def test_mutable_authority_drift_fails_but_unrelated_merge_survives(self):
        for drift in [False,True]:
            api=API();counter=[]
            def get(p):
                counter.append(1);return {'ref':'refs/heads/main','object':{'type':'commit','sha':MAIN if len(counter)==1 else NEXT}},{}
            api.get=get;api.contents=lambda p,sha:b'changed' if drift and sha==NEXT else b'same'
            if drift:
                with self.assertRaisesRegex(q.NotReady,'mutable_authority_changed'):subject.current_authority(api,['ledger'])
            else:self.assertEqual(subject.current_authority(api,['ledger'])[0],NEXT)
    def test_collector_main_checks_admit_fixed_snapshot(self):
        with tempfile.TemporaryDirectory() as tmp:
            for cls in [runs.Collector,remote.RemoteCollector]:
                owner=cls(REPO,SHA,Path(tmp)/cls.__name__,snapshot=True);owner.api=API(NEXT)
                self.assertEqual(owner.main(),NEXT)
    def test_producer_lookup_uses_nonce_without_candidate_head_filter(self):
        owner=a.Acceptance(REPO,'/unused',fixture='fixture',subject=SHA,snapshot=True);owner.subject=SHA;api=API(NEXT)
        run={'display_title':'Readiness nonce','id':30,'run_attempt':1,'head_sha':NEXT,'head_branch':'main',
             'event':'workflow_dispatch','path':a.WORKFLOW,'name':a.WORKFLOW_NAME,'status':'completed','conclusion':'success'}
        queries=[];api.pages=lambda p,*args,**kwargs:(queries.append(p) or [run]);owner.api=api
        self.assertEqual(owner.producer('nonce'),(30,1));self.assertNotIn('head_sha=',queries[0])

    def test_snapshot_qualification_rechecks_candidate_without_restarting_for_main(self):
        with tempfile.TemporaryDirectory() as tmp:
            owner=q.Qualification(ROOT,Path(tmp).resolve()/'qualification',REPO,SHA,snapshot=True);owner.reserve()
            with patch('readiness_github.GitHub',side_effect=[API(MAIN),API(NEXT)]) as factory:
                self.assertEqual(owner.check_subject(),MAIN);self.assertEqual(owner.check_subject(),NEXT)
                self.assertNotEqual(factory.call_args_list[0].args[1],factory.call_args_list[1].args[1])
            self.assertEqual(owner.subject,SHA);self.assertEqual(len(owner.subject_observations),2)
    def test_snapshot_cleanup_failure_remains_nonpassing(self):
        with tempfile.TemporaryDirectory() as tmp:
            owner=q.Qualification(ROOT,Path(tmp).resolve()/'qualification',REPO,SHA,snapshot=True)
            with patch.object(owner,'check_subject',return_value=MAIN),patch.object(owner,'checkout'),patch.object(owner,'prepare'),patch.object(owner,'upstream'),patch.object(owner,'start_services'),patch.object(owner,'gates',return_value=[]),patch.object(owner,'cleanup',side_effect=OSError('cleanup failure')):
                self.assertEqual(owner.run(),1)
            self.assertEqual(q.read_json(owner.output/'attempt.json')['reason'],'cleanup_failed')
    def test_snapshot_remote_initialization_uses_current_ledger(self):
        with tempfile.TemporaryDirectory() as tmp:
            owner=remote.RemoteCollector(REPO,SHA,Path(tmp)/'remote',only='issues',snapshot=True)
            api=API();original_get=api.get;original_contents=api.contents;seen=[]
            api.get=lambda p:({'id':7,'full_name':REPO,'default_branch':'main'}, {}) if p=='repos/'+REPO else original_get(p)
            def contents(p,sha):
                if p==remote.LEDGER:seen.append(sha)
                return original_contents(p,sha)
            api.contents=contents;owner.api=api;owner.initialize()
            self.assertEqual(seen,[MAIN])


class Graph(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.shared=Path(tempfile.mkdtemp(prefix='rindle-snapshot-graph-')).resolve()
        script=cls.shared/'generate.exs';script.write_text('Code.require_file("scripts/ci/readiness_fixture.exs"); {base,m}=ReadinessFixture.fixture(); File.write!(Path.join(base,"manifest.json"),Jason.encode!(m)); e=ReadinessFixture.refresh(base,m); File.write!(Path.join(base,"refresh-envelope.json"),Jason.encode!(e)); IO.puts(Jason.encode!(%{base: base}))')
        env={**os.environ,'RINDLE_EXACT_HEAD_LIBRARY_ONLY':'1','RINDLE_READINESS_TEST_ROOT':str(cls.shared)}
        result=subprocess.run(['mix','run','--no-start','--no-compile','--no-deps-check',str(script)],cwd=ROOT,env=env,capture_output=True,timeout=45)
        if result.returncode:raise AssertionError(result.stdout+result.stderr)
        cls.base=Path(json.loads(result.stdout.decode().splitlines()[-1])['base'])
        m=q.read_json(cls.base/'manifest.json');upgrade(cls.base,m,m,'snapshot/');put(cls.base,'manifest.json',m)
        e=q.read_json(cls.base/'refresh-envelope.json');upgrade(cls.base,e,m,'refresh/snapshot/');e['manifest_sha256']=q.digest((cls.base/'manifest.json').read_bytes());put(cls.base,'refresh-envelope.json',e)
        if os.environ.get('RINDLE_READINESS_FRESH_VALIDATOR')!='1':
            cls.validator=ValidatorFixture();cls.addClassCleanup(cls.validator.close)
            original=c.Closure.command
            adapter=patch.object(c.Closure,'command',lambda owner,argv,seconds,**kwargs: cls.validator.command(original,owner,argv,seconds,**kwargs))
            adapter.start();cls.addClassCleanup(adapter.stop)
    @classmethod
    def tearDownClass(cls):shutil.rmtree(cls.shared)
    def setUp(self):
        self.tmp=Path(tempfile.mkdtemp(prefix='rindle-snapshot-case-')).resolve();self.bundle=self.tmp/'bundle';shutil.copytree(self.base,self.bundle)
    def tearDown(self):shutil.rmtree(self.tmp)
    def validate(self,refresh=False):
        owner=a.verifier(REPO,self.tmp/'validator',self.bundle,SHA)
        return owner.validate(self.bundle/'manifest.json',self.bundle/'refresh-envelope.json' if refresh else None)
    def mutate_binding(self,fn):
        m=q.read_json(self.bundle/'manifest.json');ref=m['snapshot_subjects'][0];value=q.read_json(self.bundle/ref['path']);fn(value)
        m['snapshot_subjects'][0]=put(self.bundle,ref['path'],value);put(self.bundle,'manifest.json',m)
    def test_moving_main_manifest_passes_actual_validator(self):self.validate()
    def test_moving_main_refresh_passes_and_preserves_original_manifest(self):
        before=(self.bundle/'manifest.json').read_bytes();self.validate(True);self.assertEqual(before,(self.bundle/'manifest.json').read_bytes())
    def test_pr_provenance_rejected_by_actual_validator(self):
        self.mutate_binding(lambda v:v['push_run'].update(event='pull_request'))
        with self.assertRaisesRegex(q.NotReady,'snapshot_provenance'):self.validate()
    def test_mixed_candidate_refused_by_actual_validator(self):
        self.mutate_binding(lambda v:v.update(subject_sha='d'*40))
        with self.assertRaisesRegex(q.NotReady,'snapshot_identity'):self.validate()
    def test_missing_control_binding_refused(self):
        self.mutate_binding(lambda v:v['control_identity'].pop(subject.CONTROL_PATHS[0]))
        with self.assertRaisesRegex(q.NotReady,'snapshot_policy'):self.validate()
    def test_stale_snapshot_observation_refused(self):
        self.mutate_binding(lambda v:v.update(observed_at='2026-10-21T00:00:00Z'))
        with self.assertRaisesRegex(q.NotReady,'stale_observation'):self.validate()
    def test_snapshot_archive_binds_candidate_and_distinct_producer(self):
        env={**os.environ,'GITHUB_ACTIONS':'true','GITHUB_REPOSITORY':REPO,'GITHUB_SHA':NEXT,'GITHUB_REF':'refs/heads/main',
             'GITHUB_EVENT_NAME':'workflow_dispatch','GITHUB_WORKFLOW':retention.WORKFLOW_NAME,
             'GITHUB_WORKFLOW_REF':REPO+'/'+retention.WORKFLOW+'@refs/heads/main','GITHUB_RUN_ID':'30','GITHUB_RUN_ATTEMPT':'1',
             'EXPECTED_SUBJECT':SHA,'ACCEPTANCE_MODE':'snapshot'}
        retention.prepare(self.bundle/'manifest.json',self.tmp/'prepared',env)
        sidecar=q.read_json(self.tmp/'prepared'/retention.SIDECAR_FILE)
        self.assertEqual(sidecar['schema'],'rindle-readiness-producer-digest-v2');self.assertEqual(sidecar['subject_sha'],SHA);self.assertEqual(sidecar['producer_head_sha'],NEXT)
    def test_missing_explicit_producer_candidate_refused(self):
        with self.assertRaisesRegex(q.NotReady,'producer_context_unavailable'):
            retention.prepare(self.bundle/'manifest.json',self.tmp/'prepared',{})

    def closure_fixture(self,refresh=False):
        fixture=self.tmp/'fixture';fixture.mkdir()
        shutil.copytree(self.bundle,fixture/'data')
        m=q.read_json(fixture/'data/manifest.json');e=q.read_json(fixture/'data/refresh-envelope.json')
        local=copy.deepcopy(m);local.update(state='incomplete',local_state='complete')
        local['proofs']=[r for r in local['proofs'] if r['id'] not in ('ci-main','nightly-scheduled','protection','remote-inventory','adoption-parity')]
        put(fixture,'data/local-manifest.json',local)
        interval=e['observation_interval'] if refresh else m['observation_interval']
        for main,side in [(MAIN,'started_at'),(NEXT,'completed_at')]:
            put(fixture,'snapshot-'+main+'.json',binding(main,m['input_identity'],interval[side]))
        config={'repository':REPO,'subject_sha':SHA,'main_sequence':[MAIN,NEXT,NEXT],
                'local_manifest':'data/local-manifest.json','observation_interval':interval,
                'snapshot_'+MAIN:'snapshot-'+MAIN+'.json','snapshot_'+NEXT:'snapshot-'+NEXT+'.json'}
        for kind,ids in [('runs',{'ci-main','nightly-scheduled','protection'}),('remote',{'remote-inventory'}),('adoption',{'adoption-parity'})]:
            sources={}
            for ref in (e if refresh else m)['proofs']:
                if ref['id'] in ids:
                    receipt=q.read_json(fixture/'data'/ref['path'])
                    sources[ref['id']]={k:receipt[k] for k in ('source','references')}
            value={'repository':REPO,'subject_sha':SHA,'evidence_mode':'fixture','sources':sources}
            put(fixture,'data/'+kind+'.json',value)
            for side in ['before','after']:config[kind+'_'+side]='data/'+kind+'.json'
        put(fixture,'closure.json',config)
        return fixture
    def test_actual_closure_finishes_after_main_advances(self):
        fixture=self.closure_fixture();owner=c.Closure(REPO,self.tmp/'close',fixture=fixture,subject=SHA,snapshot=True)
        self.assertEqual(owner.run(),0)
        manifest=q.read_json(owner.portable/'manifest.json')
        self.assertEqual(manifest['remote_main_before'],MAIN);self.assertEqual(manifest['remote_main_after'],NEXT)
        self.assertEqual(manifest['subject_sha'],SHA);self.assertFalse(q.read_json(owner.output/'verdict.json')['requirements_credit'])
    def test_actual_refresh_survives_main_advance_and_retains_original(self):
        fixture=self.closure_fixture(True);path=self.bundle/'manifest.json';before=path.read_bytes()
        owner=c.Closure(REPO,self.tmp/'refresh',manifest=path,fixture=fixture)
        self.assertEqual(owner.run(),0);self.assertEqual(path.read_bytes(),before)
        self.assertEqual((owner.portable/'manifest.json').read_bytes(),before)
    def producer_environment(self):
        return {**os.environ,'GITHUB_ACTIONS':'true','GITHUB_REPOSITORY':REPO,'GITHUB_SHA':NEXT,'GITHUB_REF':'refs/heads/main',
            'GITHUB_EVENT_NAME':'workflow_dispatch','GITHUB_WORKFLOW':retention.WORKFLOW_NAME,
            'GITHUB_WORKFLOW_REF':REPO+'/'+retention.WORKFLOW+'@refs/heads/main','GITHUB_RUN_ID':'30','GITHUB_RUN_ATTEMPT':'1',
            'EXPECTED_SUBJECT':SHA,'ACCEPTANCE_MODE':'snapshot'}
    def retention_fixture(self,fixture):
        import base64,io,zipfile
        prepared=self.tmp/'upload';retention.prepare(self.bundle/'manifest.json',prepared,self.producer_environment())
        sidecar=q.read_json(prepared/retention.SIDECAR_FILE)
        def zipped(name,data):
            buf=io.BytesIO()
            with zipfile.ZipFile(buf,'w',zipfile.ZIP_DEFLATED) as archive:archive.writestr(name,data)
            return buf.getvalue()
        responses={}
        def response(path,value=None,raw=None):
            responses['repos/'+REPO+('/'+path if path else '')]=[{'status':200,'headers':{},**({'base64':base64.b64encode(raw).decode()} if raw is not None else {'body':value})}]
        response('',{'id':7,'full_name':REPO})
        run={'id':30,'run_attempt':1,'repository':{'full_name':REPO},'path':retention.WORKFLOW,'name':retention.WORKFLOW_NAME,
            'event':'workflow_dispatch','head_branch':'main','head_sha':NEXT,'status':'completed','conclusion':'success'}
        response('actions/runs/30',run);response('actions/runs/30/attempts/1',run)
        artifacts=[]
        for id,name,file in [(9,sidecar['sidecar_artifact_name'],retention.SIDECAR_FILE),(10,sidecar['archive_artifact_name'],retention.ARCHIVE_FILE)]:
            raw=zipped(file,(prepared/file).read_bytes())
            artifacts.append({'id':id,'name':name,'expired':False,'digest':'sha256:'+q.digest(raw),
                              'workflow_run':{'id':30,'head_sha':NEXT,'repository_id':7,'head_repository_id':7}})
            response('actions/artifacts/'+str(id)+'/zip',raw=raw)
        response('actions/runs/30/artifacts?per_page=100',{'total_count':2,'artifacts':artifacts})
        response('git/ref/heads/main',{'ref':'refs/heads/main','object':{'type':'commit','sha':NEXT}})
        response('branches/main',{'name':'main','protected':True,'commit':{'sha':NEXT}})
        response('compare/'+SHA+'...'+NEXT,{'url':'https://api.github.com/repos/'+REPO+'/compare/'+SHA+'...'+NEXT,
            'status':'ahead','base_commit':{'sha':SHA},'merge_base_commit':{'sha':SHA}})
        push=API().run;response('actions/runs/10',push)
        response('actions/workflows/ci.yml/runs?head_sha='+SHA+'&event=push&branch=main&per_page=100',{'total_count':1,'workflow_runs':[push]})
        for candidate in [SHA,NEXT]:
            for path in subject.CONTROL_PATHS:
                raw=(ROOT/path).read_bytes()
                response('contents/'+path+'?ref='+candidate,{'type':'file','path':path,'encoding':'base64','size':len(raw),'content':base64.b64encode(raw).decode()})
        put(fixture,'responses.json',responses)
        return responses
    def test_actual_snapshot_retrieval_authenticates_distinct_producer_and_candidate(self):
        fixture=self.tmp/'transport';fixture.mkdir();self.retention_fixture(fixture)
        locator=retention.retrieve(REPO,30,1,self.tmp/'retained',fixture)
        self.assertEqual(locator['subject_sha'],SHA);self.assertEqual(locator['producer_head_sha'],NEXT)
        self.assertTrue(locator['bytes_verified'])
    def test_substituted_producer_head_cannot_retrieve(self):
        fixture=self.tmp/'transport';fixture.mkdir();responses=self.retention_fixture(fixture)
        responses['repos/'+REPO+'/actions/runs/30'][0]['body']['head_sha']=MAIN
        put(fixture,'responses.json',responses)
        with self.assertRaises(q.NotReady):retention.retrieve(REPO,30,1,self.tmp/'retained',fixture)
    def test_full_snapshot_acceptance_and_later_claim_are_historical_only(self):
        fixture=self.closure_fixture(True);self.retention_fixture(fixture)
        owner=a.Acceptance(REPO,self.tmp/'accept',fixture=fixture,subject=SHA,snapshot=True)
        def setup():
            a.reserve(owner.output);owner.reserved=True;owner.api=API(NEXT)
        with patch.object(owner,'setup',side_effect=setup),patch.object(owner,'subject_record',return_value={'schema':'rindle-readiness-snapshot-checkout-v2','repository':REPO,'subject_sha':SHA,'snapshot_binding':{'subject_sha':SHA}}),patch.object(owner,'dispatch'),patch.object(owner,'producer',return_value=(30,1)):
            self.assertEqual(owner.run(),0)
        verdict=owner.output/'terminal-verdict.json';value=q.read_json(verdict)
        self.assertEqual(value['schema'],'rindle-snapshot-terminal-v2');self.assertFalse(value['requirements_credit']);self.assertFalse(value['current_readiness'])
        result=a.claim_status(REPO,verdict,self.tmp/'claim',fixture)
        self.assertEqual(result['status'],'historical_ready');self.assertFalse(result['current_readiness'])

    def test_terminal_controller_rejects_mixed_policy_before_refresh(self):
        owner=a.Acceptance(REPO,self.tmp/'accept-mixed',fixture='fixture',subject=SHA,snapshot=True)
        def setup():
            a.reserve(owner.output);owner.reserved=True;owner.api=API(NEXT)
        def transport(repo,run,attempt,destination,fixture):
            (destination/'bundle').mkdir(parents=True)
            manifest=q.read_json(self.bundle/'manifest.json');manifest['policy']='rindle-exact-head-v1'
            put(destination,'bundle/manifest.json',manifest)
            return {'subject_sha':SHA,'evidence_mode':'fixture','bytes_verified':True,'storage_scope':'fixture_only'}
        with patch.object(owner,'setup',side_effect=setup),patch.object(owner,'subject_record',return_value={'subject_sha':SHA}),patch.object(owner,'dispatch'),patch.object(owner,'producer',return_value=(30,1)),patch.object(a,'retrieve',side_effect=transport),patch.object(owner,'refresh') as refresh:
            self.assertEqual(owner.run(),1);refresh.assert_not_called()
        self.assertEqual(q.read_json(owner.output/'terminal-verdict.json')['reason'],'acceptance_policy_mismatch')

if __name__=='__main__':unittest.main(verbosity=1)
