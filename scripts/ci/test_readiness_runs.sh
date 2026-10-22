#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$root"
export PYTHONDONTWRITEBYTECODE=1
export ASDF_ERLANG_VERSION="${ASDF_ERLANG_VERSION:-27.3.4.15}"
export ASDF_ELIXIR_VERSION="${ASDF_ELIXIR_VERSION:-1.17.3-otp-27}"
python3 - "$root" <<'PY'
import base64, copy, functools, io, json, os, pathlib, shutil, subprocess, sys, tempfile, unittest, zipfile
from unittest.mock import patch
root=pathlib.Path(sys.argv[1]);sys.path.insert(0,str(root/'scripts/maintainer'))
import collect_readiness_runs as c
from readiness_github import GitHub
original=c.policy
@functools.lru_cache(maxsize=256)
def cached(raw):return original(json.loads(raw))
def policy(request):return copy.deepcopy(cached(c.canonical(request)))
c.policy=policy
repo='szTheory/rindle';sha='a'*40;prefix='repos/'+repo+'/'
topologies={event:policy({'operation':'topology','yaml':(root/'.github/workflows'/file).read_text(),
    'context':{'repository':repo,'event':event,'branch':'main'}}) for event,file in [('push','ci.yml'),('schedule','nightly.yml')]}

class Runs(unittest.TestCase):
    def setUp(self):
        self.tmp=pathlib.Path(tempfile.mkdtemp(prefix='rindle139-runs-')).resolve()
        self.fixture=self.tmp/'fixture';self.fixture.mkdir();self.responses={}
        self.put('repos/'+repo,{'id':123,'full_name':repo,'default_branch':'main','owner':{'type':'User'},'permissions':{'admin':True}})
        self.put(prefix+'git/ref/heads/main',{'ref':'refs/heads/main','object':{'type':'commit','sha':sha}})
        for relative in ['.github/workflows/ci.yml','.github/workflows/nightly.yml','.github/workflows/release.yml','config/ci_required_checks.json']:
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
    def test_main_moves(self):
        path=prefix+'git/ref/heads/main';self.responses[path].append(copy.deepcopy(self.responses[path][0]))
        self.responses[path][1]['body']['object']['sha']='b'*40;self.rejected('main_changed','ci')
    def test_cli_uses_same_fixture_and_writes_terminal_verdict(self):
        (self.fixture/'responses.json').write_bytes(c.canonical(self.responses))
        out=self.tmp/'cli';result=subprocess.run(['bash',str(root/'scripts/maintainer/collect_readiness_runs.sh'),
            '--repo',repo,'--subject',sha,'--output',str(out),'--fixture',str(self.fixture),'--only','ci'],capture_output=True)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertEqual(c.read_json(out/'verdict.json')['verdict'],'collected')

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

result=unittest.TextTestRunner(verbosity=1).run(unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__]))
if not result.wasSuccessful():raise SystemExit(1)
print(f'PASS readiness runs: {result.testsRun} CI/scheduled/protection/topology fixtures; no READY credit')
PY
