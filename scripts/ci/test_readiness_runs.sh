#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$root"
export PYTHONDONTWRITEBYTECODE=1
export ASDF_ERLANG_VERSION="${ASDF_ERLANG_VERSION:-27.3.4.15}"
export ASDF_ELIXIR_VERSION="${ASDF_ELIXIR_VERSION:-1.17.3-otp-27}"
python3 - "$root" <<'PY'
import atexit, base64, copy, functools, io, json, os, pathlib, shutil, subprocess, sys, tempfile, unittest, zipfile
from unittest.mock import patch
root=pathlib.Path(sys.argv[1]);sys.path.insert(0,str(root/'scripts/maintainer'))
import collect_readiness_runs as c
from readiness_github import GitHub
sys.path.insert(0,str(root/'scripts/ci'))
from readiness_validator_fixture import ValidatorFixture
worker=ValidatorFixture();atexit.register(worker.close)
original=c.policy
@functools.lru_cache(maxsize=256)
def cached(raw):return worker.policy(json.loads(raw))
def policy(request):return copy.deepcopy(cached(c.canonical(request)))
policy_patch=patch.object(c,'policy',policy);policy_patch.start();atexit.register(policy_patch.stop)
repo='szTheory/rindle';sha='a'*40;prefix='repos/'+repo+'/'
topologies={event:policy({'operation':'topology','yaml':(root/'.github/workflows'/file).read_text(),
    'context':{'repository':repo,'event':event,'branch':'main'}}) for event,file in [('push','ci.yml'),('schedule','nightly.yml')]}

class Runs(unittest.TestCase):
    def test_worker_matches_fresh_cli_for_policy_dispatch(self):
        code,_,owner=self.collect();self.assertEqual(code,0)
        sources=c.read_json(owner.portable/'sources.json')['sources']
        requests=[{'operation':'topology','yaml':(root/'.github/workflows/ci.yml').read_text(),'context':{'repository':repo,'event':'push','branch':'main'}},
                  {'operation':'topology','yaml':'name: CI\nname: Duplicate\n','context':{'repository':repo,'event':'push','branch':'main'}},
                  {'operation':'nightly-controls'},
                  {'operation':'validate','id':'protection','normalized':sources['protection']['source']['normalized'],'inputs':owner.inputs},
                  {'operation':'validate','id':'protection','normalized':{},'inputs':owner.inputs},
                  {'operation':'hex','payloads':[],'locks':{}}]
        def outcome(function,request):
            try:return ('ok',function(request))
            except c.NotReady as exc:return ('error',str(exc))
        for request in requests:
            with self.subTest(operation=request['operation'],request=request.get('normalized')):
                self.assertEqual(outcome(worker.policy,request),outcome(original,request))
    def test_unknown_worker_operation_fails_and_is_reaped(self):
        other=ValidatorFixture()
        try:
            with self.assertRaises(AssertionError):other.policy({'operation':'unknown'})
        finally:other.close();other.close()
        self.assertIsNotNone(other.child.poll())
    def setUp(self):
        self.tmp=pathlib.Path(tempfile.mkdtemp(prefix='rindle139-runs-')).resolve()
        self.fixture=self.tmp/'fixture';self.fixture.mkdir();self.responses={}
        self.put('repos/'+repo,{'id':123,'full_name':repo,'default_branch':'main','owner':{'type':'User'},'permissions':{'admin':True}})
        self.put(prefix+'git/ref/heads/main',{'ref':'refs/heads/main','object':{'type':'commit','sha':sha}})
        for relative in ['.github/workflows/ci.yml','.github/workflows/nightly.yml','.github/workflows/release.yml','config/ci_required_checks.json','.planning/phases/136-measured-quality-and-ci-ratchets/136-SPEED-DEFERRAL.json','.planning/phases/136-measured-quality-and-ci-ratchets/136-QUALIFICATION-CLOSEOUT.json']:
            raw=(root/relative).read_bytes()
            self.put(prefix+'contents/'+relative+'?ref='+sha,{'type':'file','path':relative,'encoding':'base64','size':len(raw),'content':base64.b64encode(raw).decode()})
        self.runs={};self.paths={};self.jobs={}
        for event,file,id in [('push','ci.yml',10),('schedule','nightly.yml',20)]:
            run={'id':id,'run_attempt':2,'head_sha':sha,'event':event,'head_branch':'main','repository':{'full_name':repo},
                 'name':topologies[event]['name'],'path':'.github/workflows/'+file,'created_at':'2026-10-22T07:27:00Z',
                 'status':'completed','conclusion':'success','workflow_id':100+id}
            self.runs[event]=run
            path=prefix+'actions/workflows/'+file+'/runs?head_sha='+sha+'&event='+event+'&branch=main&per_page=100'
            self.paths[event]=path;self.put(path,{'total_count':1,'workflow_runs':[run]})
            self.put(prefix+f'actions/runs/{id}',run)
            jobs=[{'id':id*100+n,'run_id':id,'run_attempt':2,'head_sha':sha,'name':j['name'],'status':'completed',
                   'conclusion':'success' if j['applicable'] else 'skipped'} for n,j in enumerate(topologies[event]['jobs'])]
            self.jobs[event]=prefix+f'actions/runs/{id}/attempts/2/jobs?per_page=100'
            self.put(self.jobs[event],{'total_count':len(jobs),'jobs':jobs})
        self.incident={'schema':'rindle-nightly-incident-verdict-v1','repository':repo,'sha':sha,'workflow_name':'Nightly',
            'workflow_ref':repo+'/.github/workflows/nightly.yml@refs/heads/main','event':'schedule','ref':'refs/heads/main',
            'run_id':20,'run_attempt':2,'url':'https://github.com/'+repo+'/actions/runs/20',
            'verdict':{'verdict':'green','errors':[],'jobs':[
                {'name':id,'result':'success','applicable':id in ('compat-matrix','dialyzer'),
                 'execution':'passed' if id in ('compat-matrix','dialyzer') else 'not-run',
                 'reason':'' if id in ('compat-matrix','dialyzer') else 'required-secrets-unavailable',
                 'applicability_rule':'always' if id in ('compat-matrix','dialyzer') else 'upstream-repository-and-required-secrets',
                 'status':'passed' if id in ('compat-matrix','dialyzer') else 'not-run','errors':[]}
                for id in ['compat-matrix','dialyzer','gcs-soak','package-consumer-gcs-live']]}}
        self.artifact()
        self.put(prefix+'branches/main/protection',{'required_status_checks':{'strict':True,'contexts':['CI Summary'],
            'checks':[{'context':'CI Summary','app_id':15368}]},'enforce_admins':{'enabled':False}})
        self.put(prefix+'rules/branches/main?per_page=100',[])
        self.put(prefix+'rulesets?includes_parents=true&per_page=100',[])
    def tearDown(self):shutil.rmtree(self.tmp)
    def put(self,path,body,status=200,headers=None):
        self.responses[path]=[{'status':status,'body':copy.deepcopy(body),'headers':headers or {}}]
    def body(self,path):return self.responses[path][0]['body']
    def artifact(self,leaf='nightly-incident-verdict.json'):
        stream=io.BytesIO()
        with zipfile.ZipFile(stream,'w') as archive:archive.writestr(zipfile.ZipInfo(leaf,date_time=(2026,1,1,0,0,0)),c.canonical(self.incident))
        raw=stream.getvalue()
        self.put(prefix+'actions/runs/20/artifacts?per_page=100',{'total_count':1,'artifacts':[{'id':300,'name':'nightly-incident-verdict-20-2',
            'expired':False,'workflow_run':{'id':20,'head_sha':sha},'digest':'sha256:'+c.digest(raw)}]})
        self.responses[prefix+'actions/artifacts/300/zip']=[{'status':200,'base64':base64.b64encode(raw).decode()}]
    def collect(self,only=None):
        (self.fixture/'responses.json').write_bytes(c.canonical(self.responses))
        collector=c.Collector(repo,sha,self.tmp/'out',self.fixture,only)
        code=collector.run();value=c.read_json(self.tmp/'out/verdict.json')
        self.assertFalse(value['requirements_credit']);self.assertEqual(value['evidence_mode'],'fixture')
        return code,value,collector
    def rejected(self,reason,only=None):
        code,value,_=self.collect(only);self.assertEqual(code,1);self.assertEqual(value['reason'],reason)
        self.assertFalse((self.tmp/'out/portable/sources.json').exists())
    def test_complete_ci_and_scheduled_topology_protection(self):
        code,value,collector=self.collect();self.assertEqual(code,0)
        self.assertEqual(len(topologies['push']['jobs']),23);self.assertEqual(len(topologies['schedule']['jobs']),11)
        sources=c.read_json(collector.portable/'sources.json')['sources']
        self.assertEqual(set(sources),{'ci-main','nightly-scheduled','protection'})
        numeric=c.read_json(collector.portable/'sources.json')['numeric_speed'];self.assertEqual(numeric['state'],'deferred_unfinished')
        self.assertFalse(numeric['acceptance_credit'])
        ref=numeric['original_qualification'];self.assertEqual((collector.portable/ref['path']).read_bytes(),
            (root/'.planning/phases/136-measured-quality-and-ci-ratchets/136-QUALIFICATION-CLOSEOUT.json').read_bytes())
        self.assertFalse(sources['nightly-scheduled']['source']['normalized']['incident']['verdict']['jobs'][-1]['applicable'])
        self.assertEqual(os.stat(collector.output/'restricted/0001-response').st_mode&0o777,0o600)
    def test_ci_tracer_is_explicitly_partial_and_has_no_readiness_credit(self):
        code,value,_=self.collect('ci');self.assertEqual(code,0);self.assertEqual(value['sources'],['ci-main'])
    def test_missing_matrix_leg_even_all_returned_jobs_success(self):
        body=self.body(self.jobs['push']);body['jobs']=[j for j in body['jobs'] if j['name']!='Quality (1.17, 27, true)'];body['total_count']-=1
        self.rejected('job_inventory','ci')
    def test_missing_main_only_job(self):
        body=self.body(self.jobs['push']);body['jobs']=[j for j in body['jobs'] if j['name']!='Cohort Demo Smoke'];body['total_count']-=1
        self.rejected('job_inventory','ci')
    def test_required_skip_is_not_green(self):
        self.body(self.jobs['push'])['jobs'][0]['conclusion']='skipped';self.rejected('job_outcome','ci')
    def test_newest_failed_run_wins_over_older_green(self):
        new={**self.runs['push'],'id':11,'created_at':'2026-10-22T07:28:00Z','conclusion':'failure'}
        self.put(self.paths['push'],{'total_count':2,'workflow_runs':[self.runs['push'],new]});self.put(prefix+'actions/runs/11',new)
        self.rejected('latest_attempt_not_green','ci')
    def test_newest_pending_run_wins_over_green(self):
        self.body(self.paths['push'])['workflow_runs'][0]['status']='in_progress'
        self.body(prefix+'actions/runs/10')['status']='in_progress';self.rejected('latest_attempt_not_green','ci')
    def test_partial_rerun_does_not_splice_prior_attempt(self):
        self.body(self.jobs['push'])['jobs'][0]['run_attempt']=1;self.rejected('job_identity','ci')
    def test_attempt_changes_after_job_collection(self):
        path=prefix+'actions/runs/10';self.responses[path].append(copy.deepcopy(self.responses[path][0]))
        self.responses[path][1]['body']['run_attempt']=3;self.rejected('attempt_changed','ci')
    def test_new_run_during_recheck(self):
        path=self.paths['push'];self.responses[path].append(copy.deepcopy(self.responses[path][0]))
        new={**self.runs['push'],'id':11,'created_at':'2026-10-22T07:28:00Z'}
        self.responses[path][1]['body']={'total_count':2,'workflow_runs':[self.runs['push'],new]}
        self.rejected('newer_run_observed','ci')
    def test_duplicate_job(self):
        body=self.body(self.jobs['push']);body['jobs'][1]=body['jobs'][0];self.rejected('job_inventory','ci')
    def test_wrong_job_sha(self):
        self.body(self.jobs['push'])['jobs'][0]['head_sha']='b'*40;self.rejected('job_identity','ci')
    def test_all_job_pages_bound_to_same_query(self):
        path=self.jobs['push'];body=self.body(path);second=path+'&page=2'
        tail=body['jobs'][12:];body['jobs']=body['jobs'][:12]
        self.responses[path][0]['headers']={'link':'<https://api.github.com/'+second+'>; rel="next"'}
        self.put(second,{'total_count':23,'jobs':tail});code,_,_=self.collect('ci');self.assertEqual(code,0)
    def test_missing_next_page_is_not_complete(self):
        body=self.body(self.jobs['push']);body['jobs']=body['jobs'][:12];self.rejected('incomplete_pages','ci')
    def test_foreign_next_link(self):
        self.responses[self.jobs['push']][0]['headers']={'link':'<https://evil.example/jobs?page=2>; rel="next"'}
        self.rejected('foreign_next_page','ci')
    def test_next_link_cannot_remove_subject_query(self):
        path=self.paths['push'];self.responses[path][0]['headers']={'link':'<https://api.github.com/'+prefix+'actions/workflows/ci.yml/runs?per_page=100&page=2>; rel="next"'}
        self.rejected('pagination_query_drift','ci')
    def test_count_search_cap_rejected(self):
        self.body(self.paths['push'])['total_count']=1000;self.rejected('inventory_count_limit','ci')
    def test_cancelled_scheduled_workflow_cannot_use_its_green_incident_artifact(self):
        self.body(self.paths['schedule'])['workflow_runs'][0]['conclusion']='cancelled'
        self.body(prefix+'actions/runs/20')['conclusion']='cancelled';self.rejected('latest_attempt_not_green')
    def test_wrong_run_event_never_substitutes(self):
        self.body(self.paths['schedule'])['workflow_runs'][0]['event']='workflow_dispatch';self.rejected('workflow_identity')
    def test_no_scheduled_run_keeps_next_observation(self):
        self.put(self.paths['schedule'],{'total_count':0,'workflow_runs':[]})
        code,value,_=self.collect();self.assertEqual(code,1);self.assertEqual(value['reason'],'scheduled_run_missing')
        self.assertIn('27 7 * * *',value['next_observation'])
    def test_missing_scheduled_incident_job(self):
        body=self.body(self.jobs['schedule']);body['jobs']=[j for j in body['jobs'] if j['name']!='Nightly Incident Lifecycle'];body['total_count']-=1
        self.rejected('job_inventory')
    def test_missing_scheduled_matrix_leg(self):
        body=self.body(self.jobs['schedule']);body['jobs'].pop(0);body['total_count']-=1;self.rejected('job_inventory')
    def test_forged_optional_claim_for_deterministic_job(self):
        j=self.incident['verdict']['jobs'][0];j.update(applicable=False,execution='not-run',reason='required-secrets-unavailable',status='not-run')
        self.artifact();self.rejected('incident_policy')
    def test_unknown_optional_reason(self):
        self.incident['verdict']['jobs'][-1]['reason']='maintainer-said-ok';self.artifact();self.rejected('incident_policy')
    def test_wrong_incident_attempt(self):
        self.incident['run_attempt']=1;self.artifact();self.rejected('incident_identity')
    def test_artifact_traversal(self):self.artifact('../nightly-incident-verdict.json');self.rejected('incident_artifact_unsafe')
    def test_expired_artifact(self):
        self.body(prefix+'actions/runs/20/artifacts?per_page=100')['artifacts'][0]['expired']=True;self.rejected('incident_artifact_identity')
    def test_artifact_digest_mismatch(self):
        self.body(prefix+'actions/runs/20/artifacts?per_page=100')['artifacts'][0]['digest']='sha256:'+'f'*64;self.rejected('incident_artifact_digest')
    def test_wrong_protection_app(self):
        self.body(prefix+'branches/main/protection')['required_status_checks']['checks'][0]['app_id']=1;self.rejected('protection_drift')
    def test_strict_false(self):
        self.body(prefix+'branches/main/protection')['required_status_checks']['strict']=False;self.rejected('protection_drift')
    def test_legacy_context_without_app_is_unavailable(self):
        self.body(prefix+'branches/main/protection')['required_status_checks']['checks']=[];self.rejected('protection_binding_unavailable')
    def test_protection_unavailable_is_not_empty(self):
        self.put(prefix+'branches/main/protection',{},403);self.rejected('remote_forbidden')
    def test_rate_limit_explicit(self):
        self.put(self.paths['push'],{},403,{'x-ratelimit-remaining':'0'});self.rejected('remote_rate_limited','ci')
    def test_304_without_cached_representation_is_unavailable(self):
        self.put(self.paths['push'],{},304);self.rejected('remote_unavailable','ci')
    def test_policy_changes_between_two_complete_reads(self):
        path=prefix+'branches/main/protection';self.responses[path].append(copy.deepcopy(self.responses[path][0]))
        self.responses[path][1]['body']['enforce_admins']['enabled']=True;self.rejected('protection_drift')
    def test_active_parent_ruleset_requires_detail_and_rejects_extra_policy(self):
        self.put(prefix+'rules/branches/main?per_page=100',[{'type':'required_signatures','ruleset_id':7}])
        self.put(prefix+'rulesets?includes_parents=true&per_page=100',[{'id':7,'source_type':'Organization','enforcement':'active'}])
        self.put(prefix+'rulesets/7?includes_parents=true',{'id':7,'enforcement':'active','bypass_actors':[],'rules':[{'type':'required_signatures'}]})
        self.rejected('protection_drift')
    def subject_file(self,relative,text):
        raw=text.encode();path=prefix+'contents/'+relative+'?ref='+sha
        self.put(path,{'type':'file','path':relative,'encoding':'base64','size':len(raw),'content':base64.b64encode(raw).decode()})
    def test_release_exact_sha_coupling_drift(self):
        relative='.github/workflows/release.yml';self.subject_file(relative,(root/relative).read_text().replace('head_sha: sha,','head_sha: context.sha,'))
        self.rejected('workflow_policy_drift','ci')
    def test_fork_trigger_drift(self):
        relative='.github/workflows/ci.yml';self.subject_file(relative,(root/relative).read_text().replace('  pull_request:', '  pull_request_target:'))
        self.rejected('workflow_policy_drift','ci')
    def test_script_seam_can_add_cheap_fixture_without_widening_jobs(self):
        relative='.github/workflows/ci.yml';text=(root/relative).read_text().replace('      - name: CI Summary gate logic', '      - name: Additional fixture\n        run: echo safe-fixture\n      - name: CI Summary gate logic')
        self.subject_file(relative,text);code,_,_=self.collect('ci');self.assertEqual(code,0)
    def test_listing_attempt_changes_after_detail_recheck(self):
        path=self.paths['push'];self.responses[path].append(copy.deepcopy(self.responses[path][0]))
        self.responses[path][1]['body']['workflow_runs'][0]['run_attempt']=3;self.rejected('attempt_changed','ci')
    def test_incident_workflow_ref_cannot_be_foreign(self):
        self.incident['workflow_ref']='foreign/repo/.github/workflows/nightly.yml@refs/heads/main';self.artifact();self.rejected('incident_identity')
    def test_compatible_active_ruleset_preserves_only_intended_check(self):
        rule={'type':'required_status_checks','ruleset_id':7,'parameters':{'strict_required_status_checks_policy':True,
             'required_status_checks':[{'context':'CI Summary','integration_id':15368}]}}
        self.put(prefix+'rules/branches/main?per_page=100',[rule])
        self.put(prefix+'rulesets?includes_parents=true&per_page=100',[{'id':7,'source_type':'Repository','enforcement':'active'}])
        self.put(prefix+'rulesets/7?includes_parents=true',{'id':7,'enforcement':'active','bypass_actors':[],
            'rules':[{'type':rule['type'],'parameters':rule['parameters']}]})
        code,_,_=self.collect();self.assertEqual(code,0)
    def test_unavailable_fixture_writes_nonpassing_terminal_verdict(self):
        self.fixture=self.tmp/'missing'
        collector=c.Collector(repo,sha,self.tmp/'out',self.fixture)
        self.assertEqual(collector.run(),1);self.assertEqual(c.read_json(self.tmp/'out/verdict.json')['verdict'],'not_ready')
    def test_historical_blocked_receipt_cannot_be_rewritten(self):
        relative='.planning/phases/136-measured-quality-and-ci-ratchets/136-QUALIFICATION-CLOSEOUT.json'
        value=json.loads((root/relative).read_bytes());value['subject_sha']='b'*40
        self.subject_file(relative,json.dumps(value));self.rejected('historical_timing_receipt_changed','ci')
    def test_workflow_alias_next_link_can_use_authenticated_workflow_id(self):
        path=self.paths['push'];second=prefix+'actions/workflows/110/runs?head_sha='+sha+'&event=push&branch=main&per_page=100&page=2'
        old={**self.runs['push'],'id':9,'created_at':'2026-10-21T07:27:00Z'}
        self.body(path)['total_count']=2
        self.responses[path][0]['headers']={'link':'<https://api.github.com/'+second+'>; rel="next"'}
        self.put(second,{'total_count':2,'workflow_runs':[old]})
        code,_,_=self.collect('ci');self.assertEqual(code,0)
    def test_null_fixture_map_never_falls_through_to_authenticated_network(self):
        (self.fixture/'responses.json').write_text('null')
        with patch('readiness_github.subprocess.run',side_effect=AssertionError('fixture reached network')):
            with self.assertRaisesRegex(c.NotReady,'fixture_response_map_invalid'):
                GitHub(repo,self.tmp/'invalid-private',self.fixture)
    def test_explicit_empty_fixture_path_never_enables_live_mode(self):
        collector=c.Collector(repo,sha,self.tmp/'empty-fixture','',only='ci')
        with patch('readiness_github.subprocess.run',side_effect=AssertionError('fixture reached network')):
            self.assertEqual(collector.run(),1)
        self.assertEqual(c.read_json(collector.output/'verdict.json')['evidence_mode'],'fixture')
    def test_main_moves(self):
        path=prefix+'git/ref/heads/main';self.responses[path].append(copy.deepcopy(self.responses[path][0]))
        self.responses[path][1]['body']['object']['sha']='b'*40;self.rejected('main_changed','ci')
    def test_cli_uses_same_fixture_and_writes_terminal_verdict(self):
        (self.fixture/'responses.json').write_bytes(c.canonical(self.responses))
        out=self.tmp/'cli';result=subprocess.run(['bash',str(root/'scripts/maintainer/collect_readiness_runs.sh'),
            '--repo',repo,'--subject',sha,'--output',str(out),'--fixture',str(self.fixture),'--only','ci'],capture_output=True)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertEqual(c.read_json(out/'verdict.json')['verdict'],'collected')


class SnapshotRuns(unittest.TestCase):
    def setUp(self):
        sys.path.insert(0,str(root/'scripts/ci'))
        from readiness_nightly_fixture import step_rows,jq_hash
        import readiness_subject
        self.base=Runs();self.base.setUp();b=self.base
        self.put,self.body=b.put,b.body
        self.put(prefix+'branches/main',{'name':'main','protected':True,'commit':{'sha':sha}})
        comparison='compare/'+sha+'...'+sha
        self.put(prefix+comparison,{'status':'identical','base_commit':{'sha':sha},'merge_base_commit':{'sha':sha},'url':'https://api.github.com/'+prefix+comparison})
        paths=set(readiness_subject.CONTROL_PATHS)|set(policy({'operation':'nightly-controls'}))
        for subject in [sha,'d'*40]:
            for path in paths:
                raw=(root/path).read_bytes()
                self.put(prefix+'contents/'+path+'?ref='+subject,{'type':'file','path':path,'encoding':'base64','size':len(raw),'content':base64.b64encode(raw).decode()})
        self.put(prefix+'actions/workflows/nightly.yml',{'id':120,'path':'.github/workflows/nightly.yml','state':'active'})
        clock=c.now();day=clock[:10];created=day+'T07:27:00Z';finished=day+'T07:37:00Z'
        # Freeze only the fixture observation clock, not any production clock.
        self.clock=day+'T10:00:00Z'
        run={**b.runs['schedule'],'run_attempt':1,'head_sha':'d'*40,'created_at':created,'updated_at':finished}
        self.put(prefix+'actions/workflows/nightly.yml/runs?event=schedule&branch=main&per_page=100',{'total_count':1,'workflow_runs':[run]})
        self.put(b.paths['schedule'],{'total_count':0,'workflow_runs':[]})
        manual={**run,'id':21,'head_sha':sha,'event':'workflow_dispatch'}
        self.manual_path=prefix+'actions/workflows/nightly.yml/runs?head_sha='+sha+'&event=workflow_dispatch&branch=main&per_page=100'
        self.put(self.manual_path,{'total_count':1,'workflow_runs':[manual]})
        yaml=(root/'.github/workflows/nightly.yml').read_text()
        for r in [run,manual]:
            self.put(prefix+f"actions/runs/{r['id']}",r)
            topology=policy({'operation':'topology','yaml':yaml,'context':{'repository':repo,'event':r['event'],'branch':'main'}})
            jobs=[{'id':r['id']*100+n,'run_id':r['id'],'run_attempt':1,'head_sha':r['head_sha'],
                'name':j['name'],'status':'completed','conclusion':'success' if j['applicable'] else 'skipped',
                'steps':step_rows(yaml,j['job_id']) if j['applicable'] else []} for n,j in enumerate(topology['jobs'])]
            self.put(prefix+f"actions/runs/{r['id']}/attempts/1/jobs?per_page=100",{'total_count':len(jobs),'jobs':jobs})
        incident={**b.incident,'sha':'d'*40,'run_attempt':1}
        checkpoint={'schema':'rindle-nightly-incident-checkpoint-v1','repository':repo,
            'workflow_ref':repo+'/.github/workflows/nightly.yml@refs/heads/main','last_run_id':20,'last_run_attempt':1,
            'event_digest':jq_hash(incident),'issue_digest':jq_hash([]),'issue_number':None,'issue_state':None,'previous_chain_digest':'0'*64}
        checkpoint['chain_digest']=jq_hash({k:v for k,v in checkpoint.items() if k not in ('schema','repository','workflow_ref')})
        artifacts=[]
        for id,key,leaf,value in [(300,'nightly-incident-verdict','nightly-incident-verdict.json',incident),(301,'nightly-incident-replay-checkpoint','nightly-incident-checkpoint.json',checkpoint)]:
            stream=io.BytesIO()
            with zipfile.ZipFile(stream,'w') as archive:archive.writestr(leaf,c.canonical(value))
            raw=stream.getvalue()
            artifacts.append({'id':id,'name':key+'-20-1','expired':False,'expires_at':'2030-01-01T00:00:00Z',
                'workflow_run':{'id':20,'head_sha':'d'*40},'digest':'sha256:'+c.digest(raw)})
            b.responses[prefix+f'actions/artifacts/{id}/zip']=[{'status':200,'base64':base64.b64encode(raw).decode()}]
        self.put(prefix+'actions/runs/20/artifacts?per_page=100',{'total_count':2,'artifacts':artifacts})
        self.put(prefix+'issues?state=all&labels=nightly-failure&per_page=100&sort=created&direction=asc',[])
        (b.fixture/'incident-inventory.json').write_bytes(c.canonical([]))
    def tearDown(self):self.base.tearDown()
    def collect(self):
        b=self.base;(b.fixture/'responses.json').write_bytes(c.canonical(b.responses))
        owner=c.Collector(repo,sha,b.tmp/'out',b.fixture,snapshot=True)
        with patch.object(c,'now',return_value=self.clock):code=owner.run()
        return code,c.read_json(owner.output/'verdict.json'),owner
    def test_dispatch_and_different_source_cron_collect_as_distinct_proofs(self):
        code,value,owner=self.collect();self.assertEqual(code,0,value)
        sources=c.read_json(owner.portable/'sources.json')['sources']
        self.assertEqual(set(sources),{'ci-main','nightly-qualification','scheduled-incident-health','protection'})
        self.assertEqual(sources['nightly-qualification']['source']['normalized']['subject_sha'],sha)
        health=sources['scheduled-incident-health']['source']['normalized']
        self.assertEqual(health['subject_sha'],sha);self.assertEqual(health['health_run']['subject_sha'],'d'*40)
    def test_newer_failed_dispatch_cannot_use_older_green(self):
        self.body(self.manual_path)['workflow_runs'][0]['conclusion']='failure'
        self.body(prefix+'actions/runs/21')['conclusion']='failure'
        code,value,_=self.collect();self.assertEqual(code,1);self.assertEqual(value['reason'],'latest_attempt_not_green')
    def test_newer_failed_global_cron_cannot_use_green_candidate(self):
        path=prefix+'actions/workflows/nightly.yml/runs?event=schedule&branch=main&per_page=100'
        self.body(path)['workflow_runs'][0]['conclusion']='failure';self.body(prefix+'actions/runs/20')['conclusion']='failure'
        code,value,_=self.collect();self.assertEqual(code,1);self.assertEqual(value['reason'],'latest_attempt_not_green')
    def test_missing_candidate_dispatch_is_actionable_without_waiting_for_cron(self):
        self.put(self.manual_path,{'total_count':0,'workflow_runs':[]})
        code,value,_=self.collect();self.assertEqual(code,1);self.assertEqual(value['reason'],'nightly_qualification_missing')

class Topology(unittest.TestCase):
    def derive(self,body,event='push'):
        return policy({'operation':'topology','yaml':body,'context':{'repository':repo,'event':event,'branch':'main'}})
    def test_ordered_include_boolean_names(self):
        self.assertIn('Quality (1.17, 27, true)',[j['name'] for j in topologies['push']['jobs']])
    def test_cartesian_exclude_include_merge(self):
        body='name: CI\njobs:\n  x:\n    name: Proof\n    strategy:\n      matrix:\n        os: [a, b]\n        version: [1, 2]\n        exclude:\n          - os: b\n            version: 2\n        include:\n          - os: a\n            extra: true\n          - os: c\n            version: 3\n'
        self.assertEqual([j['name'] for j in self.derive(body)['jobs']],['Proof (a, 1, true)','Proof (a, 2, true)','Proof (b, 1)','Proof (c, 3)'])
    def test_duplicate_yaml_rejected(self):
        with self.assertRaises(c.NotReady):self.derive('name: CI\nname: Other\njobs:\n  x: {}\n')
    def test_dynamic_matrix_rejected(self):
        with self.assertRaises(c.NotReady):self.derive('name: CI\njobs:\n  x:\n    strategy:\n      matrix: "${{ fromJSON(needs.build.outputs.matrix) }}"\n')
    def test_unknown_condition_rejected(self):
        with self.assertRaises(c.NotReady):self.derive('name: CI\njobs:\n  x:\n    if: needs.unknown.result == \'success\'\n')
    def test_explicit_matrix_name_and_condition(self):
        value=self.derive('name: CI\njobs:\n  x:\n    name: "Proof ${{ matrix.v }}"\n    if: github.event_name == \'push\'\n    strategy:\n      matrix:\n        v: [one, two]\n')
        self.assertEqual([j['name'] for j in value['jobs']],['Proof one','Proof two'])
    def test_false_job_condition_is_one_skipped_descriptor(self):
        value=self.derive('name: CI\njobs:\n  x:\n    if: github.event_name == \'pull_request\'\n    strategy:\n      matrix:\n        v: [one, two]\n')
        self.assertEqual(len(value['jobs']),1);self.assertFalse(value['jobs'][0]['applicable'])

try:
    result=unittest.TextTestRunner(verbosity=1).run(unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__]))
    if not result.wasSuccessful():raise SystemExit(1)
    print(f'PASS readiness runs: {result.testsRun} CI/scheduled/protection/topology fixtures; no READY credit')
finally:
    policy_patch.stop();worker.close()
PY
