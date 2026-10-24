#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$root"
export PYTHONDONTWRITEBYTECODE=1
python3 - "$root" <<'PY'
import base64,copy,json,os,pathlib,shutil,subprocess,sys,tempfile,unittest,hashlib,functools,time
from unittest.mock import patch
from types import SimpleNamespace
root=pathlib.Path(sys.argv[1]);sys.path.insert(0,str(root/'scripts/maintainer'))
import collect_readiness_remote as c
import collect_readiness_runs as runs
original_policy=runs.policy
@functools.lru_cache(maxsize=128)
def cached(raw):return original_policy(json.loads(raw))
def cached_policy(value):return copy.deepcopy(cached(c.canonical(value)))
c.policy=cached_policy;runs.policy=cached_policy
repo='szTheory/rindle';sha='a'*40;prefix='repos/'+repo+'/'
ledger=json.loads((root/c.LEDGER).read_bytes())
# Each adversarial scenario supplies its own open PRs; never import live PR heads
# into a synthetic API map that intentionally starts with no open pulls.
ledger['items']=[item for item in ledger['items'] if item['kind']!='pr' or 'terminal' in item]

# Reuse the pure lock-parser transformation across fixture cases. The script and
# complete lock bytes form the key; changed input cannot reuse a prior result.
# Every authenticated API observation and ledger validation still runs normally.
# The actual CLI subprocess test below remains unpatched.
original_command=c.RemoteCollector.command
lock_parses={}
def fixture_command(self,argv,cwd,env,budget):
    if len(argv)!=5 or argv[0]!='elixir' or argv[2]!='--inventory':
        return original_command(self,argv,cwd,env,budget)
    key=(pathlib.Path(argv[1]).read_bytes(),pathlib.Path(argv[3]).read_bytes())
    output=pathlib.Path(argv[4])
    if key in lock_parses:
        code,raw=lock_parses[key];c.write_new(output,raw);return code
    code=original_command(self,argv,cwd,env,budget)
    if output.is_file():lock_parses[key]=(code,output.read_bytes())
    return code
c.RemoteCollector.command=fixture_command

class Remote(unittest.TestCase):
    def setUp(self):
        self.tmp=pathlib.Path(tempfile.mkdtemp(prefix='rindle139-remote-')).resolve();self.fixture=self.tmp/'fixture';self.fixture.mkdir()
        self.responses={};self.put('repos/'+repo,{'id':123,'full_name':repo,'default_branch':'main','owner':{'type':'User'},'permissions':{'admin':True}})
        self.put(prefix+'git/ref/heads/main',{'ref':'refs/heads/main','object':{'type':'commit','sha':sha}})
        self.subject_file(c.LEDGER,c.canonical(ledger))
        issues=[]
        for record in ledger['items']:
            number=record['number'];terminal=record.get('terminal')
            value={'number':number,'id':1000+number,'repository_url':'https://api.github.com/repos/'+repo,
                'title':'fixture decision','body':'ADVISORY-CANARY-PRIVATE-BODY','labels':[],
                'state':terminal['state'] if terminal else 'open','state_reason':terminal.get('state_reason') if terminal else None,
                'updated_at':'2026-10-21T00:00:00Z'}
            if record['kind']=='pr':value['pull_request']={'url':'https://api.github.com/'+prefix+'pulls/'+str(number)}
            if terminal:
                self.put(prefix+'issues/'+str(number),value)
                if record['kind']=='pr':self.put(prefix+'pulls/'+str(number),{'number':number,'state':'closed','merged':terminal['merged'],
                    'base':{'repo':{'full_name':repo}}})
            else:issues.append(value)
        self.put(prefix+'issues?state=open&per_page=100',issues)
        self.issue_path=prefix+'issues?state=open&per_page=100'
        self.put(prefix+'pulls?state=open&per_page=100',[])
        self.put(prefix+'security-advisories?state=triage&per_page=100',[],headers={'x-oauth-scopes':'repo'})
        self.put(prefix+'security-advisories?state=draft&per_page=100',[],headers={'x-oauth-scopes':'repo'})
        self.put(prefix+'security-advisories?state=published&per_page=100',[],headers={'x-oauth-scopes':'repo'})
        self.put(prefix+'security-advisories?state=closed&per_page=100',[],headers={'x-oauth-scopes':'repo'})
        self.put(prefix+'dependabot/alerts?state=open%2Cdismissed%2Cfixed%2Cauto_dismissed&per_page=100',[],headers={'x-oauth-scopes':'repo'})
        self.put(prefix+'branches/main/protection',{'required_status_checks':{'strict':True,'contexts':['CI Summary'],
            'checks':[{'context':'CI Summary','app_id':15368}]},'enforce_admins':{'enabled':False}})
        self.put(prefix+'rules/branches/main?per_page=100',[]);self.put(prefix+'rulesets?includes_parents=true&per_page=100',[])
        for relative in ['mix.lock','examples/adoption_demo/mix.lock','.github/workflows/ci.yml','.github/workflows/release.yml','config/ci_required_checks.json']:
            self.subject_file(relative,(root/relative).read_bytes())
        self.hex_payload=[]
        for scope,relative in [('root','mix.lock'),('examples/adoption_demo','examples/adoption_demo/mix.lock')]:
            text=(root/relative).read_text()
            import re
            packages=[{'package':p,'version':v,'retired':False,'advisories':[]} for p,v in re.findall(r'^  "[a-z0-9_]+": \{:hex, :([a-z0-9_]+), "([^"\n]+)"',text,re.M)]
            for package in packages:
                package['advisories']=[{'id':a['id'],'severity':'SEVERITY_MEDIUM'} for a in ledger['advisories']
                    if a['scope']==scope and a['package']==package['package'] and a['status']=='exception']
            checksums={p:outer for p,outer in re.findall(r'^  "[a-z0-9_]+": \{:hex, :([a-z0-9_]+),.*"hexpm", "([0-9a-f]{64})"\},?$',text,re.M)}
            database=[{'key':['version'],'value_sha256':'f'*64}]
            for package in packages:
                binary=bytes.fromhex(checksums[package['package']])
                etf=b'\x83m'+len(binary).to_bytes(4,'big')+binary
                for key,value in [(['outer_checksum','hexpm',package['package'],package['version']],hashlib.sha256(etf).hexdigest()),
                                  (['advisories','hexpm',package['package'],package['version']],'e'*64),
                                  (['versions','hexpm',package['package']],'d'*64)]:
                    database.append({'key':key,'value_sha256':value})
            self.hex_payload.append({'schema':'rindle-readiness-hex-v1','scope':scope,'lock_sha256':c.digest(text.encode()),
                'hex_version':'2.5.1','online':True,'registry_signature_verification':True,'https_verified':True,
                'packages':sorted(packages,key=lambda p:p['package']),'database':database})
        (self.fixture/'hex.json').write_bytes(c.canonical([self.hex_payload,self.hex_payload]))
    def tearDown(self):shutil.rmtree(self.tmp)
    def put(self,path,body,status=200,headers=None):self.responses[path]=[{'status':status,'body':copy.deepcopy(body),'headers':headers or {}}]
    def subject_file(self,path,raw):self.put(prefix+'contents/'+path+'?ref='+sha,{'path':path,'type':'file','encoding':'base64','size':len(raw),'content':base64.b64encode(raw).decode()})
    def body(self,path):return self.responses[path][0]['body']
    def collect(self,full=False):
        (self.fixture/'responses.json').write_bytes(c.canonical(self.responses))
        collector=c.RemoteCollector(repo,sha,self.tmp/'out',self.fixture,None if full else 'issues');code=collector.run()
        value=c.read_json(collector.output/'verdict.json');self.assertFalse(value['requirements_credit'])
        portable=b''.join(f.read_bytes() for f in collector.portable.rglob('*') if f.is_file())
        self.assertNotIn(b'ADVISORY-CANARY-PRIVATE-BODY',portable)
        return code,value,collector
    def reject(self,reason):
        code,value,collector=self.collect();self.assertEqual(code,1);self.assertEqual(value['reason'],reason)
        self.assertFalse((collector.portable/'sources.json').exists())
    def test_complete_fixture_disposition_ledger_and_two_reads(self):
        code,value,collector=self.collect();self.assertEqual(code,0)
        result=c.read_json(collector.portable/'sources.json');self.assertEqual(result['scope'],'issues-tracer')
        self.assertEqual(result['sources']['remote-inventory']['source']['normalized']['ledger_sha256'],c.digest(c.canonical(ledger)))
        self.assertEqual(os.stat(collector.private).st_mode&0o777,0o700)
        self.assertEqual(os.stat(collector.private/'api/0001-response').st_mode&0o777,0o600)
    def test_issues_endpoint_pr_is_not_counted_as_issue(self):
        code,_,collector=self.collect();self.assertEqual(code,0)
        source=c.read_json(collector.portable/'sources.json')['sources']['remote-inventory']['source']['normalized']['sources']
        self.assertEqual(source['issues']['count'],sum(1 for r in ledger['items'] if r['kind']=='issue' and 'terminal' not in r))
    def test_new_undispositioned_issue(self):
        value=copy.deepcopy(next(i for i in self.body(self.issue_path) if 'pull_request' not in i));value['number']=999
        self.body(self.issue_path).append(value);self.reject('issue_undispositioned')
    def test_missing_retained_issue_does_not_become_empty_success(self):
        values=self.body(self.issue_path);retained=next(i for i in values if 'pull_request' not in i)
        self.put(prefix+'issues/'+str(retained['number']),{**retained,'state':'closed'})
        self.put(self.issue_path,[i for i in values if i is not retained]);self.reject('issue_terminal_mismatch')
    def test_changed_issue_body_invalidates_second_observation(self):
        path=self.issue_path;self.responses[path].append(copy.deepcopy(self.responses[path][0]))
        next(i for i in self.responses[path][1]['body'] if 'pull_request' not in i)['body']='changed decision inputs'
        self.reject('remote_state_changed')
    def test_stable_ids_handle_equal_timestamp_and_reordered_results(self):
        path=self.issue_path;self.responses[path].append(copy.deepcopy(self.responses[path][0]));self.responses[path][1]['body'].reverse()
        code,_,_=self.collect();self.assertEqual(code,0)
    def test_duplicate_identity(self):
        self.body(self.issue_path).append(self.body(self.issue_path)[0]);self.reject('ambiguous_inventory_identity')
    def test_null_is_unavailable(self):self.put(self.issue_path,None);self.reject('incomplete_pages')
    def test_private_404_is_unavailable(self):self.put(self.issue_path,{},404);self.reject('remote_unavailable')
    def test_unauthorized_is_unavailable(self):self.put(self.issue_path,{},401);self.reject('remote_unauthorized')
    def test_rate_limited_is_not_empty(self):self.put(self.issue_path,{},403,{'x-ratelimit-remaining':'0'});self.reject('remote_rate_limited')
    def test_second_page_and_complete_source(self):
        path=self.issue_path;body=self.body(path);second=path+'&page=2';self.put(second,body[1:]);self.put(path,body[:1],headers={'link':'<https://api.github.com/'+second+'>; rel="next"'})
        code,_,_=self.collect();self.assertEqual(code,0)
    def test_main_changes(self):
        path=prefix+'git/ref/heads/main';self.responses[path].append(copy.deepcopy(self.responses[path][0]));self.responses[path][1]['body']['object']['sha']='b'*40
        self.reject('main_changed')
    def test_ledger_changes_even_when_shape_still_valid(self):
        path=prefix+'contents/'+c.LEDGER+'?ref='+sha;self.responses[path].append(copy.deepcopy(self.responses[path][0]))
        raw=c.canonical({**ledger,'recorded_note':'changed decision'});self.responses[path][1]['body'].update(content=base64.b64encode(raw).decode(),size=len(raw))
        self.reject('ledger_changed')
    def test_absent_terminal_pr_is_reobserved(self):
        record=next(r for r in ledger['items'] if r['kind']=='pr' and 'terminal' in r)
        self.body(prefix+'pulls/'+str(record['number']))['merged']=not record['terminal']['merged']
        # The issue-only tracer cannot close PR reconciliation; full mode must reject this in Task 2.
        code,_,_=self.collect();self.assertEqual(code,0)
    def test_full_mode_cannot_claim_complete_from_issue_tracer(self):
        code,value,collector=self.collect(full=True);self.assertEqual(code,0)
        source=c.read_json(collector.portable/'sources.json')['sources']['remote-inventory']['source']['normalized']['sources']
        self.assertEqual(set(source),{'issues','pulls','checks','statuses','advisories','dependabot','hex','protection','absent'})
        self.assertIn('database_sha256',source['hex'])
    def test_full_mode_runs_actual_existing_ledger_validator(self):
        record=next(r for r in ledger['items'] if r['kind']=='pr' and 'terminal' in r)
        self.body(prefix+'pulls/'+str(record['number']))['merged']=not record['terminal']['merged']
        code,value,_=self.collect(full=True);self.assertEqual(code,1);self.assertEqual(value['reason'],'ledger_reconciliation_failed')
    def test_unpublished_advisory_404_cannot_be_empty(self):
        self.put(prefix+'security-advisories?state=draft&per_page=100',{},404)
        code,value,_=self.collect(full=True);self.assertEqual(code,1);self.assertEqual(value['reason'],'remote_unavailable')
    def test_missing_advisory_scope_cannot_be_empty(self):
        self.responses[prefix+'security-advisories?state=draft&per_page=100'][0]['headers']={'x-oauth-scopes':'public_repo'}
        code,value,_=self.collect(full=True);self.assertEqual(code,1);self.assertEqual(value['reason'],'advisory_visibility_unproved')
    def test_null_security_source_is_unavailable(self):
        self.put(prefix+'dependabot/alerts?state=open%2Cdismissed%2Cfixed%2Cauto_dismissed&per_page=100',None)
        code,value,_=self.collect(full=True);self.assertEqual(code,1);self.assertEqual(value['reason'],'incomplete_pages')
    def add_pr(self):
        n=999;head='c'*40
        new_ledger=copy.deepcopy(ledger);new_ledger['items'].append({'kind':'pr','number':n,'head_sha':head,'disposition':'retain','rationale':'Retain pending dependency review'})
        self.subject_file(c.LEDGER,c.canonical(new_ledger))
        self.body(self.issue_path).append({'id':1999,'number':n,'state':'open','repository_url':'https://api.github.com/repos/'+repo,'pull_request':{}})
        self.put(prefix+'pulls?state=open&per_page=100',[{'number':n}])
        self.put(prefix+'pulls/999',{'number':n,'state':'open','head':{'sha':head},'base':{'ref':'main','repo':{'full_name':repo}},
            'mergeable':True,'mergeable_state':'clean','title':'retained proposal','body':'ADVISORY-CANARY-PRIVATE-BODY'})
        checks=[{'id':id,'name':'CI Summary','head_sha':head,'app':{'id':15368},'check_suite':{'id':900},
            'status':'completed','conclusion':'success','started_at':'2026-10-22T01:00:00Z','output':{'summary':'ADVISORY-CANARY-PRIVATE-BODY'}} for id in (1001,1002)]
        self.check_path=prefix+'commits/'+head+'/check-runs?filter=all&per_page=100'
        self.put(self.check_path,{'total_count':2,'check_runs':checks})
        self.put(prefix+'check-suites/900',{'id':900,'head_sha':head,'app':{'id':15368}})
        self.run_path=prefix+'actions/runs?head_sha='+head+'&per_page=100'
        self.put(self.run_path,{'total_count':1,'workflow_runs':[{'id':700,'head_sha':head,'check_suite_id':900,'repository':{'full_name':repo},
            'run_attempt':2,'path':'.github/workflows/ci.yml','name':'CI','status':'completed','created_at':'2026-10-22T01:00:00Z'}]})
        self.job_path=prefix+'actions/runs/700/jobs?filter=all&per_page=100'
        self.put(self.job_path,{'total_count':2,'jobs':[{'id':9000+i,'head_sha':head,'run_id':700,'run_attempt':i+1,
            'check_run_url':'https://api.github.com/repos/'+repo+'/check-runs/'+str(id),'status':'completed','conclusion':'success'} for i,id in enumerate((1001,1002))]})
        self.status_path=prefix+'commits/'+head+'/statuses?per_page=100'
        self.put(self.status_path,[{'id':id,'context':'legacy','state':state,'created_at':'2026-10-22T01:00:00Z'} for id,state in [(2001,'failure'),(2002,'success')]])
        self.put(prefix+'pulls/999/files?per_page=100',[])
        return head
    def full_reject(self,reason):
        code,value,_=self.collect(full=True);self.assertEqual(code,1);self.assertEqual(value['reason'],reason)
    def test_pr_checks_bind_each_historical_attempt_and_statuses_separately(self):
        self.add_pr();code,_,collector=self.collect(full=True);self.assertEqual(code,0)
        observed=c.read_json(collector.private/'normalized-1.json')
        self.assertEqual([v['check']['readiness_attempt'] for v in observed['checks']],[1,2])
        self.assertEqual(len(observed['statuses']),2)
        calls=[v['path'] for v in collector.api.calls]
        self.assertEqual(calls.count(self.run_path),2);self.assertEqual(calls.count(self.job_path),2)
    def test_undispositioned_pr_fails_before_expensive_job_reads(self):
        self.add_pr();self.subject_file(c.LEDGER,c.canonical(ledger));self.full_reject('pull_undispositioned')
    def test_stale_pr_head_rejected_by_actual_ledger_owner(self):
        self.add_pr();raw=c.json_bytes(base64.b64decode(self.body(prefix+'contents/'+c.LEDGER+'?ref='+sha)['content']))
        raw['items'][-1]['head_sha']='d'*40;self.subject_file(c.LEDGER,c.canonical(raw));self.full_reject('ledger_reconciliation_failed')
    def test_newest_pending_attempt_never_reuses_old_summary_as_green(self):
        self.add_pr();self.body(self.run_path)['workflow_runs'][0].update(run_attempt=3,status='in_progress')
        code,_,collector=self.collect(full=True);self.assertEqual(code,0)
        self.assertIsNone(c.read_json(collector.private/'normalized-1.json')['pulls'][0]['ci_summary']['conclusion'])
    def test_wrong_workflow_cannot_supply_ci_summary(self):
        self.add_pr();self.body(self.run_path)['workflow_runs'][0]['path']='.github/workflows/foreign.yml';self.full_reject('ci_summary_workflow_identity')
    def test_job_cannot_splice_foreign_head(self):
        self.add_pr();self.body(self.job_path)['jobs'][0]['head_sha']='b'*40;self.full_reject('check_attempt_identity')
    def test_missing_historical_job_cannot_be_latest_attempt(self):
        self.add_pr();body=self.body(self.job_path);body['jobs'].pop(0);body['total_count']-=1;self.full_reject('check_attempt_unavailable')
    def test_check_history_must_have_all_pages(self):
        self.add_pr();self.body(self.check_path)['check_runs'].pop();self.full_reject('incomplete_pages')
    def test_null_legacy_statuses_is_unavailable(self):
        self.add_pr();self.put(self.status_path,None);self.full_reject('incomplete_pages')
    def test_changed_check_output_invalidates_current_disposition(self):
        self.add_pr();path=self.check_path;self.responses[path].append(copy.deepcopy(self.responses[path][0]))
        self.responses[path][1]['body']['check_runs'][0]['output']['summary']='changed check decision';self.full_reject('remote_state_changed')
    def test_legacy_status_change_with_equal_timestamp_invalidates(self):
        self.add_pr();path=self.status_path;self.responses[path].append(copy.deepcopy(self.responses[path][0]))
        self.responses[path][1]['body'][1]['state']='pending';self.full_reject('remote_state_changed')
    def test_private_advisory_cannot_leak_canaries_to_portable_bundle(self):
        row={'ghsa_id':'GHSA-abcd-1234-efgh','state':'closed','url':'https://api.github.com/repos/'+repo+'/security-advisories/GHSA-abcd-1234-efgh',
            'description':'ADVISORY-CANARY-PRIVATE-BODY','summary':'TOKEN-CANARY-DO-NOT-PUBLISH'}
        self.put(prefix+'security-advisories?state=closed&per_page=100',[row],headers={'x-oauth-scopes':'repo','authorization':'token TOKEN-CANARY-DO-NOT-PUBLISH'})
        with patch.dict(os.environ,{'GH_TOKEN':'TOKEN-CANARY-DO-NOT-PUBLISH'}):code,_,collector=self.collect(full=True)
        self.assertEqual(code,0)
        portable=b''.join(p.read_bytes() for p in collector.portable.rglob('*') if p.is_file())
        self.assertNotIn(b'TOKEN-CANARY-DO-NOT-PUBLISH',portable)
        self.assertIn(b'ADVISORY-CANARY-PRIVATE-BODY',(collector.private/'normalized-1.json').read_bytes())
    def test_new_unpublished_advisory_needs_actual_disposition(self):
        self.put(prefix+'security-advisories?state=draft&per_page=100',[{'ghsa_id':'GHSA-abcd-1234-efgh','state':'draft',
            'url':'https://api.github.com/repos/'+repo+'/security-advisories/GHSA-abcd-1234-efgh','description':'ADVISORY-CANARY-PRIVATE-BODY'}],headers={'x-oauth-scopes':'repo'})
        self.full_reject('ledger_reconciliation_failed')
    def test_advisory_collaborator_visibility_is_insufficient_for_all_private_advisories(self):
        self.body('repos/'+repo)['permissions']['admin']=False;self.full_reject('advisory_visibility_unproved')
    def test_fine_grained_private_gets_require_expected_permission_header(self):
        for path in self.responses:
            if 'security-advisories?' in path:self.responses[path][0]['headers']={'x-accepted-github-permissions':'repository_advisories=read'}
            if 'dependabot/alerts?' in path:self.responses[path][0]['headers']={'x-accepted-github-permissions':'dependabot_alerts=read'}
        code,_,_=self.collect(full=True);self.assertEqual(code,0)
    def test_dependabot_disabled_or_forbidden_is_not_empty(self):
        self.put(prefix+'dependabot/alerts?state=open%2Cdismissed%2Cfixed%2Cauto_dismissed&per_page=100',{'message':'disabled for this repository'},403)
        self.full_reject('remote_forbidden')
    def test_advisory_cursor_pages_follow_same_state_and_endpoint(self):
        path=prefix+'security-advisories?state=closed&per_page=100';second=path+'&after=opaque-cursor'
        self.responses[path][0]['headers']['link']='<https://api.github.com/'+second+'>; rel="next"'
        self.put(second,[],headers={'x-oauth-scopes':'repo'});code,_,_=self.collect(full=True);self.assertEqual(code,0)
    def test_advisory_cursor_cannot_drop_private_state_filter(self):
        path=prefix+'security-advisories?state=draft&per_page=100'
        self.responses[path][0]['headers']['link']='<https://api.github.com/'+prefix+'security-advisories?per_page=100&after=opaque>; rel="next"'
        self.full_reject('pagination_query_drift')
    def test_expired_exception_cannot_be_overridden_by_injected_clock(self):
        raw=copy.deepcopy(ledger);record=next(a for a in raw['advisories'] if a['status']=='exception')
        record['exception']['expires']='2020-01-01';record['exception']['trigger']['not_after']='2020-01-01'
        self.subject_file(c.LEDGER,c.canonical(raw))
        with patch.dict(os.environ,{'INBOX_NOW_EPOCH':'1'}):self.full_reject('ledger_reconciliation_failed')
    def set_hex(self,rows):
        (self.fixture/'hex.json').write_bytes(c.canonical(rows))
    def test_hex_cannot_omit_demo_audit(self):
        self.set_hex([[self.hex_payload[0]],[self.hex_payload[0]]]);self.full_reject('hex_source_unavailable')
    def test_hex_must_cover_every_locked_package(self):
        rows=copy.deepcopy(self.hex_payload);rows[0]['packages'].pop();self.set_hex([rows,rows]);self.full_reject('hex_lock_coverage')
    def test_hex_must_keep_locked_checksum_in_database(self):
        rows=copy.deepcopy(self.hex_payload);next(d for d in rows[0]['database'] if d['key'][0]=='outer_checksum')['value_sha256']='b'*64
        self.set_hex([rows,rows]);self.full_reject('hex_identity')
    def test_hex_cannot_use_unsafe_registry(self):
        rows=copy.deepcopy(self.hex_payload);rows[0]['registry_signature_verification']=False;self.set_hex([rows,rows]);self.full_reject('hex_source_identity')
    def test_hex_database_change_invalidates_second_observation(self):
        second=copy.deepcopy(self.hex_payload);second[0]['database'][0]['value_sha256']='b'*64;self.set_hex([self.hex_payload,second]);self.full_reject('remote_state_changed')
    def test_untrusted_lockfile_is_never_executed(self):
        marker=self.tmp/'lock-side-effect';self.subject_file('mix.lock',('File.write!("'+str(marker)+'", "bad"); %{}').encode())
        self.full_reject('lock_inventory_unavailable');self.assertFalse(marker.exists())
    def hex_trigger(self,target):
        raw=copy.deepcopy(ledger);record=next(i for i in raw['items'] if i['kind']=='issue' and 'terminal' not in i)
        record.update(disposition='defer',gate='new version',trigger={'type':'hex_version_gte','package':'cowlib','version':target})
        self.subject_file(c.LEDGER,c.canonical(raw))
        rows=copy.deepcopy(self.hex_payload)
        for row in rows:row['latest_versions']={'cowlib':'2.21.0'}
        self.set_hex([rows,rows])
    def test_pending_hex_version_trigger_uses_actual_collected_version(self):
        self.hex_trigger('9.0.0');code,_,_=self.collect(full=True);self.assertEqual(code,0)
    def test_fired_hex_version_trigger_forces_new_decision(self):
        self.hex_trigger('2.0.0');self.full_reject('ledger_reconciliation_failed')
    def test_changed_admin_visibility_on_second_read_invalidates_empty_security(self):
        path='repos/'+repo;self.responses[path].extend([copy.deepcopy(self.responses[path][0]),copy.deepcopy(self.responses[path][0])])
        self.responses[path][2]['body']['permissions']['admin']=False;self.full_reject('advisory_visibility_changed')
    def test_actual_cli_full_mode_requires_all_nine_sources(self):
        (self.fixture/'responses.json').write_bytes(c.canonical(self.responses));out=self.tmp/'cli-full'
        result=subprocess.run(['bash',str(root/'scripts/maintainer/collect_readiness_remote.sh'),'--repo',repo,'--subject',sha,
            '--output',str(out),'--fixture',str(self.fixture)],capture_output=True)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        sources=c.read_json(out/'portable/sources.json')['sources']['remote-inventory']['source']['normalized']['sources']
        self.assertEqual(len(sources),9)
    def test_null_fixture_is_rejected_without_network_and_retains_fixture_scope(self):
        (self.fixture/'responses.json').write_text('null')
        owner=c.RemoteCollector(repo,sha,self.tmp/'null-fixture',self.fixture,'issues')
        with patch('readiness_github.subprocess.run',side_effect=AssertionError('unexpected network')):self.assertEqual(owner.run(),1)
        value=c.read_json(owner.output/'verdict.json');self.assertEqual(value['evidence_mode'],'fixture');self.assertEqual(value['reason'],'fixture_response_map_invalid')
    def test_explicit_empty_fixture_path_remains_fixture_mode(self):
        owner=c.RemoteCollector(repo,sha,self.tmp/'empty-fixture','','issues')
        with patch('readiness_github.subprocess.run',side_effect=AssertionError('unexpected network')):self.assertEqual(owner.run(),1)
        self.assertEqual(c.read_json(owner.output/'verdict.json')['evidence_mode'],'fixture')
    def test_owned_audit_child_has_real_bounded_timeout(self):
        owner=c.RemoteCollector(repo,sha,self.tmp/'child',self.fixture);owner.api=SimpleNamespace(deadline=time.monotonic()+1)
        with self.assertRaisesRegex(c.NotReady,'remote_command_budget'):
            owner.command([sys.executable,'-c','import time; time.sleep(10)'],self.tmp,dict(os.environ),.1)
    def test_actual_cli_tracer_uses_same_fixture(self):
        (self.fixture/'responses.json').write_bytes(c.canonical(self.responses));out=self.tmp/'cli'
        result=subprocess.run(['bash',str(root/'scripts/maintainer/collect_readiness_remote.sh'),'--repo',repo,'--subject',sha,
            '--output',str(out),'--fixture',str(self.fixture),'--only','issues'],capture_output=True)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(c.read_json(out/'verdict.json')['evidence_mode'],'fixture')

result=unittest.TextTestRunner(verbosity=1).run(unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__]))
if not result.wasSuccessful():raise SystemExit(1)
print(f'PASS readiness remote: {result.testsRun} issue/disposition/privacy fixtures; no READY credit')
PY
