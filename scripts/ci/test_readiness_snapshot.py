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
from readiness_nightly_fixture import split_receipt
import collect_readiness_runs as runs
import collect_readiness_remote as remote
import readiness_nightly_capture as capture

REPO='szTheory/rindle';SHA='a'*40;MAIN='b'*40;NEXT='c'*40


def put(root,path,value):
    dest=root/path;dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_bytes(value if isinstance(value,bytes) else q.canonical(value))
    return q.reference(root,dest)


def binding(main,identity,observed='2026-10-22T10:00:30Z'):
    return {'schema':'rindle-readiness-snapshot-subject-v3','repository':REPO,'subject_sha':SHA,
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
        expanded=split_receipt(receipt,manifest,root,put,prefix) if ref['id']=='nightly-scheduled' else [receipt]
        for receipt in expanded:
            receipt['policy']=subject.POLICY
            id=receipt['id']
            if id=='hygiene':
                receipt['command']['argv']+=['--snapshot-subject',SHA,'--repo',REPO,'--snapshot-evidence','/external/hygiene-admission']
                receipt['references'].append(put(root,prefix+'hygiene-subject.json',
                    binding(NEXT,manifest['input_identity'],receipt['observation_interval']['started_at'])))
            if 'source' in receipt:
                source=receipt['source'];source['policy']=subject.POLICY;n=source['normalized']
                if id=='remote-inventory':
                    ledger=put(root,prefix+'authority/ledger.json',(ROOT/'.planning/INBOX-LEDGER.json').read_bytes())
                    n.update(ledger_file=ledger,ledger_sha256=ledger['sha256'],authority_main_sha=NEXT)
                    receipt['references'].append(ledger)
                if id=='adoption-parity':
                    files={p:put(root,prefix+'authority/'+p,(ROOT/p).read_bytes()) for p in adoption.INPUTS}
                    n.update(authoritative_files=files,authoritative_inputs={p:r['sha256'] for p,r in files.items()},authority_main_sha=NEXT)
                    receipt['references']+=list(files.values())
                observations=[]
                for i,old in enumerate(source['observations']):
                    observations.append(put(root,prefix+'observations/'+id+'-'+str(i)+'.json',n))
                oldpaths={r['path'] for r in source['observations']}
                receipt['references']=[r for r in receipt['references'] if r['path'] not in oldpaths]+observations
                source.update(observations=observations,before_sha256=observations[0]['sha256'],after_sha256=observations[-1]['sha256'])
            proofs.append({**put(root,prefix+'receipts/'+id+'.json',receipt),'id':id})
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
        if p.endswith('actions/workflows/readiness-retention.yml'):return {'id':901,'name':retention.WORKFLOW_NAME,'path':retention.WORKFLOW,'state':'active'},{}
        if p.endswith('branches/main'):return {'name':'main','protected':True,'commit':{'sha':self.main}},{}
        if '/compare/' in p:return {'status':'ahead','base_commit':{'sha':SHA},'merge_base_commit':{'sha':SHA},'url':'https://api.github.com/'+p},{}
        if p.endswith('actions/runs/10'):return copy.deepcopy(self.run),{}
        raise AssertionError(p)
    def pages(self,path,*args,**kwargs):return [copy.deepcopy(self.run)]
    def contents(self,path,sha):return (ROOT/path).read_bytes()


class Identity(unittest.TestCase):
    def test_health_refresh_clock_alone_does_not_restart_source_work(self):
        a={'source':{'policy':subject.POLICY,'query':'health','normalized':{
            'health_run':{'run_id':20,'attempt':1},'observed_at':'2026-10-22T09:00:00Z'}}}
        b=copy.deepcopy(a);b['source']['normalized']['observed_at']='2026-10-22T10:00:00Z'
        self.assertEqual(c.semantic(a),c.semantic(b))
        b['source']['normalized']['health_run']['attempt']=2
        self.assertNotEqual(c.semantic(a),c.semantic(b))

    def capture_case(self,heads):
        tmp=Path(tempfile.mkdtemp(prefix='rindle-capture-test-')).resolve();self.addCleanup(shutil.rmtree,tmp)
        api=API();seen=[]
        def get(path):
            if path.endswith('actions/workflows/nightly.yml'):
                return {'id':120,'name':'Nightly','path':'.github/workflows/nightly.yml','state':'active'},{}
            if '/actions/runs/' in path:
                id=int(path.rsplit('/',1)[1]);head=heads[min(id-1,len(heads)-1)]
                return {'id':id,'repository':{'full_name':REPO},'workflow_id':120,'name':'Nightly',
                    'path':'.github/workflows/nightly.yml','event':'workflow_dispatch','head_branch':'main',
                    'head_sha':head,'run_attempt':1,'html_url':'https://github.com/'+REPO+'/actions/runs/'+str(id)},{}
            return {'ref':'refs/heads/main','object':{'type':'commit','sha':SHA}},{}
        api.get=get
        def dispatch(*args):seen.append(1);return len(seen)
        return tmp,api,seen,dispatch

    def test_capture_binds_returned_id_and_does_not_wait_for_main_freeze(self):
        tmp,api,seen,dispatch=self.capture_case([SHA])
        with patch.object(capture,'GitHub',return_value=api),patch.object(capture,'observe',return_value={'subject_sha':SHA}),patch.object(capture,'dispatch',side_effect=dispatch):
            self.assertEqual(capture.capture(REPO,tmp/'out'),0)
        self.assertEqual(len(seen),1);self.assertEqual(q.read_json(tmp/'out/capture.json')['subject_sha'],SHA)

    def test_capture_races_are_bounded_and_owned_runs_preserved(self):
        tmp,api,seen,dispatch=self.capture_case([MAIN]*3)
        with patch.object(capture,'GitHub',return_value=api),patch.object(capture,'observe',return_value={'subject_sha':SHA}),patch.object(capture,'dispatch',side_effect=dispatch):
            self.assertEqual(capture.capture(REPO,tmp/'out'),1)
        self.assertEqual(len(seen),3);self.assertEqual(len(q.read_json(tmp/'out/capture.json')['attempts']),3)

    def test_unknown_dispatch_never_retries_post(self):
        tmp,api,seen,dispatch=self.capture_case([SHA])
        with patch.object(capture,'GitHub',return_value=api),patch.object(capture,'observe',return_value={'subject_sha':SHA}),patch.object(capture,'dispatch',side_effect=q.NotReady('nightly_dispatch_unknown')) as post:
            self.assertEqual(capture.capture(REPO,tmp/'out'),1);self.assertEqual(post.call_count,1)

    def test_newest_global_schedule_does_not_filter_out_wrong_source_or_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            owner=runs.Collector(REPO,SHA,Path(tmp)/'out',snapshot=True);owner.api=API()
            old={**owner.api.run,'id':20,'workflow_id':120,'name':'Nightly','path':'.github/workflows/nightly.yml',
                'event':'schedule','head_sha':SHA}
            new={**old,'id':21,'head_sha':MAIN,'created_at':'2026-10-23T07:27:00Z','conclusion':'failure'}
            queries=[];owner.api.pages=lambda p,*args,**kwargs:(queries.append(p) or [old,new])
            self.assertEqual(owner.latest('nightly.yml','schedule',subject=None)['id'],21)
            self.assertNotIn('head_sha',queries[0])

    def test_newest_pending_and_never_started_schedule_gets_absolute_deadline(self):
        for created,reason in [('2026-10-22T07:27:00Z','scheduled_health_stalled'),('2026-10-22T09:27:00Z','scheduled_health_pending')]:
            with tempfile.TemporaryDirectory() as tmp:
                owner=runs.Collector(REPO,SHA,Path(tmp)/'out',snapshot=True);owner.api=API();owner.observed_at='2026-10-22T10:00:00Z'
                owner.api.get=lambda p:({'id':120,'path':'.github/workflows/nightly.yml','state':'active'}, {})
                run={'workflow_id':120,'status':'queued','created_at':created}
                with patch.object(owner,'latest',return_value=run):
                    with self.assertRaisesRegex(q.NotReady,reason):owner.scheduled_health()

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
             'event':'workflow_dispatch','path':a.WORKFLOW,'name':'Readiness nonce','workflow_id':901,'repository':{'full_name':REPO},'status':'completed','conclusion':'success'}
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

    def mutate_proof(self,id,fn):
        m=q.read_json(self.bundle/'manifest.json');ref=next(r for r in m['proofs'] if r['id']==id)
        receipt=q.read_json(self.bundle/ref['path']);fn(receipt['source']['normalized'])
        source=receipt['source'];observations=[]
        for old in source['observations']:
            observations.append(put(self.bundle,old['path'],source['normalized']))
        oldpaths={r['path'] for r in source['observations']}
        receipt['references']=[r for r in receipt['references'] if r['path'] not in oldpaths]+observations
        source.update(observations=observations,before_sha256=observations[0]['sha256'],after_sha256=observations[-1]['sha256'])
        m['proofs']=[{**put(self.bundle,ref['path'],receipt),'id':id} if r['id']==id else r for r in m['proofs']]
        put(self.bundle,'manifest.json',m)

    def test_dispatch_aggregate_cannot_hide_missing_enforcement(self):
        def change(n):
            job=next(j for j in n['jobs'] if j['name']=='Nightly Summary')
            job['steps']=[s for s in job['steps'] if s['name']!='Enforce strict Nightly verdict']
        self.mutate_proof('nightly-qualification',change)
        with self.assertRaisesRegex(q.NotReady,'nightly_required_step'):self.validate()

    def test_dispatch_required_step_skip_fails(self):
        def change(n):
            next(j for j in n['jobs'] if j['name']=='Dialyzer')['steps'][4]['conclusion']='skipped'
        self.mutate_proof('nightly-qualification',change)
        with self.assertRaisesRegex(q.NotReady,'nightly_required_step'):self.validate()

    def test_dispatch_partial_rerun_fails(self):
        self.mutate_proof('nightly-qualification',lambda n:n.update(attempt=2,rechecked_attempt=2))
        with self.assertRaisesRegex(q.NotReady,'nightly_attempt_unsupported'):self.validate()

    def test_dispatch_duplicate_steps_fail(self):
        def change(n):
            steps=next(j for j in n['jobs'] if j['name']=='Nightly Summary')['steps']
            steps.append(copy.deepcopy(steps[-1]))
        self.mutate_proof('nightly-qualification',change)
        with self.assertRaisesRegex(q.NotReady,'nightly_steps_duplicate'):self.validate()

    def test_missing_operational_health_cannot_close_v3(self):
        m=q.read_json(self.bundle/'manifest.json');m['proofs']=[r for r in m['proofs'] if r['id']!='scheduled-incident-health']
        put(self.bundle,'manifest.json',m)
        with self.assertRaisesRegex(q.NotReady,'proof_inventory'):self.validate()

    def test_snapshot_hygiene_cannot_use_unqualified_release_prep(self):
        m=q.read_json(self.bundle/'manifest.json');ref=next(r for r in m['proofs'] if r['id']=='hygiene')
        receipt=q.read_json(self.bundle/ref['path']);receipt['command']['argv']=receipt['command']['argv'][:3]
        m['proofs']=[{**put(self.bundle,ref['path'],receipt),'id':ref['id']} if r['id']==ref['id'] else r for r in m['proofs']]
        put(self.bundle,'manifest.json',m)
        with self.assertRaisesRegex(q.NotReady,'hygiene_subject'):self.validate()

    def test_snapshot_hygiene_rejects_missing_retained_admission(self):
        m=q.read_json(self.bundle/'manifest.json');ref=next(r for r in m['proofs'] if r['id']=='hygiene')
        receipt=q.read_json(self.bundle/ref['path'])
        receipt['references']=[r for r in receipt['references'] if not r['path'].endswith('/hygiene-subject.json')]
        m['proofs']=[{**put(self.bundle,ref['path'],receipt),'id':ref['id']} if r['id']==ref['id'] else r for r in m['proofs']]
        put(self.bundle,'manifest.json',m)
        with self.assertRaisesRegex(q.NotReady,'hygiene_subject'):self.validate()

    def test_snapshot_hygiene_rejects_foreign_retained_admission(self):
        m=q.read_json(self.bundle/'manifest.json');ref=next(r for r in m['proofs'] if r['id']=='hygiene')
        receipt=q.read_json(self.bundle/ref['path']);admission=next(r for r in receipt['references'] if r['path'].endswith('/hygiene-subject.json'))
        value=q.read_json(self.bundle/admission['path']);value['subject_sha']='f'*40
        receipt['references']=[put(self.bundle,admission['path'],value) if r['path']==admission['path'] else r for r in receipt['references']]
        m['proofs']=[{**put(self.bundle,ref['path'],receipt),'id':ref['id']} if r['id']==ref['id'] else r for r in m['proofs']]
        put(self.bundle,'manifest.json',m)
        with self.assertRaisesRegex(q.NotReady,'hygiene_subject'):self.validate()

    def test_foreign_health_repository_fails_even_with_matching_controls(self):
        self.mutate_proof('scheduled-incident-health',lambda n:n['health_run'].update(repository='fork/rindle'))
        with self.assertRaises(q.NotReady):self.validate()

    def test_optional_skip_cannot_claim_live_execution(self):
        def change(n):
            job=next(j for j in n['jobs'] if j['name']=='GCS Soak (real bucket)')
            next(s for s in job['steps'] if s['name']=='Run GCS integration tests')['conclusion']='success'
        self.mutate_proof('nightly-qualification',change)
        with self.assertRaisesRegex(q.NotReady,'nightly_required_step'):self.validate()

    def test_manual_execution_cannot_become_scheduled_health(self):
        self.mutate_proof('scheduled-incident-health',lambda n:n['health_run'].update(event='workflow_dispatch'))
        with self.assertRaisesRegex(q.NotReady,'workflow_identity'):self.validate()

    def test_stale_schedule_cannot_borrow_new_source_qualification(self):
        self.mutate_proof('scheduled-incident-health',lambda n:n['health_run'].update(created_at='2026-10-21T07:27:00Z'))
        with self.assertRaisesRegex(q.NotReady,'scheduled_health_stale'):self.validate()

    def test_downstream_queue_cannot_extend_execution_deadline(self):
        self.mutate_proof('scheduled-incident-health',lambda n:n['health_run'].update(completed_at='2026-10-22T09:28:00Z'))
        with self.assertRaisesRegex(q.NotReady,'scheduled_health_stalled'):self.validate()

    def test_crossing_cron_deadline_uses_source_completion_clock(self):
        self.mutate_proof('scheduled-incident-health',lambda n:n.update(observed_at='2026-10-22T08:26:00Z'))
        self.mutate_proof('scheduled-incident-health',lambda n:n['health_run'].update(
            created_at='2026-10-21T07:27:00Z',completed_at='2026-10-21T07:37:00Z'))
        m=q.read_json(self.bundle/'manifest.json')
        m['observation_interval']['started_at']='2026-10-22T08:26:00Z'
        ref=next(r for r in m['proofs'] if r['id']=='scheduled-incident-health')
        receipt=q.read_json(self.bundle/ref['path'])
        receipt['observation_interval']['started_at']='2026-10-22T08:26:00Z'
        receipt['source']['observation_interval']={'started_at':'2026-10-22T08:26:00Z','completed_at':'2026-10-22T08:28:00Z'}
        m['proofs']=[{**put(self.bundle,ref['path'],receipt),'id':ref['id']} if r['id']==ref['id'] else r for r in m['proofs']]
        put(self.bundle,'manifest.json',m)
        with self.assertRaisesRegex(q.NotReady,'scheduled_health_stale'):self.validate()

    def test_control_change_invalidates_existing_cron(self):
        self.mutate_proof('scheduled-incident-health',lambda n:n['health_control_identity'].update({'scripts/ci/manage_nightly_incident.sh':'0'*64}))
        with self.assertRaisesRegex(q.NotReady,'scheduled_health_control_mismatch'):self.validate()

    def test_checkpoint_json_cannot_disagree_with_retained_zip(self):
        self.mutate_proof('scheduled-incident-health',lambda n:n['checkpoint'].update(event_digest='0'*64))
        with self.assertRaisesRegex(q.NotReady,'incident_identity'):self.validate()

    def test_open_incident_cannot_use_old_closed_checkpoint(self):
        self.mutate_proof('scheduled-incident-health',lambda n:n.update(incidents=[{'number':1,'title':'Nightly CI failure','state':'OPEN'}]))
        with self.assertRaisesRegex(q.NotReady,'scheduled_incident_open'):self.validate()

    def test_checkpoint_projects_only_viewer_relative_author_boolean(self):
        from readiness_nightly_fixture import jq_hash
        m=q.read_json(self.bundle/'manifest.json')
        ref=next(r for r in m['proofs'] if r['id']=='scheduled-incident-health')
        n=q.read_json(self.bundle/ref['path'])['source']['normalized']
        issue={'number':1,'title':'Nightly CI failure','state':'CLOSED','body':'immutable incident',
            'comments':[{'author':{'login':'github-actions'},'viewerDidAuthor':False,'body':'authentic recovery'}]}
        producer=copy.deepcopy(issue);producer['comments'][0]['viewerDidAuthor']=True
        n['incidents']=[issue];checkpoint=n['checkpoint']
        checkpoint.update(issue_digest=jq_hash([producer]),issue_number=1,issue_state='CLOSED')
        keys=['previous_chain_digest','last_run_id','last_run_attempt','event_digest','issue_digest','issue_number','issue_state']
        checkpoint['chain_digest']=jq_hash({k:checkpoint[k] for k in keys})
        inputs={p:(ROOT/p).read_text() for p in n['control_identity']}
        inputs.update({p:(ROOT/p).read_text() for p in ['.github/workflows/ci.yml','.github/workflows/release.yml']})
        runs.policy({'operation':'validate','id':'scheduled-incident-health','normalized':n,'inputs':inputs})
        n['incidents'][0]['comments'][0]['body']='edited content'
        with self.assertRaisesRegex(q.NotReady,'scheduled_checkpoint_issues'):
            runs.policy({'operation':'validate','id':'scheduled-incident-health','normalized':n,'inputs':inputs})

    def test_old_policy_cannot_opt_into_v3(self):
        m=q.read_json(self.bundle/'manifest.json');m['policy']='rindle-snapshot-v2';put(self.bundle,'manifest.json',m)
        with self.assertRaisesRegex(q.NotReady,'validator_policy'):self.validate()
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
        local['proofs']=[r for r in local['proofs'] if r['id'] not in ('ci-main','nightly-qualification','scheduled-incident-health','protection','remote-inventory','adoption-parity')]
        put(fixture,'data/local-manifest.json',local)
        interval=e['observation_interval'] if refresh else m['observation_interval']
        for main,side in [(MAIN,'started_at'),(NEXT,'completed_at')]:
            put(fixture,'snapshot-'+main+'.json',binding(main,m['input_identity'],interval[side]))
        config={'repository':REPO,'subject_sha':SHA,'main_sequence':[MAIN,NEXT,NEXT],
                'local_manifest':'data/local-manifest.json','observation_interval':interval,
                'snapshot_'+MAIN:'snapshot-'+MAIN+'.json','snapshot_'+NEXT:'snapshot-'+NEXT+'.json'}
        for kind,ids in [('runs',{'ci-main','nightly-qualification','scheduled-incident-health','protection'}),('remote',{'remote-inventory'}),('adoption',{'adoption-parity'})]:
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
        response('actions/workflows/readiness-retention.yml',{'id':901,'name':retention.WORKFLOW_NAME,'path':retention.WORKFLOW,'state':'active'})
        run={'id':30,'run_attempt':1,'repository':{'full_name':REPO},'path':retention.WORKFLOW,'name':'Readiness '+('d'*32),'workflow_id':901,
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
        with patch.object(owner,'setup',side_effect=setup),patch.object(owner,'subject_record',return_value={'schema':'rindle-readiness-snapshot-checkout-v3','repository':REPO,'subject_sha':SHA,'snapshot_binding':{'subject_sha':SHA}}),patch.object(owner,'dispatch'),patch.object(owner,'producer',return_value=(30,1)):
            self.assertEqual(owner.run(),0)
        verdict=owner.output/'terminal-verdict.json';value=q.read_json(verdict)
        self.assertEqual(value['schema'],'rindle-snapshot-terminal-v3');self.assertFalse(value['requirements_credit']);self.assertFalse(value['current_readiness'])
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
