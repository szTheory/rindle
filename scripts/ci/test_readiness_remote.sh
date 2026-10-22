#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$root"
export PYTHONDONTWRITEBYTECODE=1
python3 - "$root" <<'PY'
import base64,copy,json,os,pathlib,shutil,subprocess,sys,tempfile,unittest
root=pathlib.Path(sys.argv[1]);sys.path.insert(0,str(root/'scripts/maintainer'))
import collect_readiness_remote as c
repo='szTheory/rindle';sha='a'*40;prefix='repos/'+repo+'/'
ledger=json.loads((root/c.LEDGER).read_bytes())

class Remote(unittest.TestCase):
    def setUp(self):
        self.tmp=pathlib.Path(tempfile.mkdtemp(prefix='rindle139-remote-')).resolve();self.fixture=self.tmp/'fixture';self.fixture.mkdir()
        self.responses={};self.put('repos/'+repo,{'id':123,'full_name':repo,'default_branch':'main','permissions':{'admin':True}})
        self.put(prefix+'git/ref/heads/main',{'ref':'refs/heads/main','object':{'type':'commit','sha':sha}})
        self.subject_file(c.LEDGER,(root/c.LEDGER).read_bytes())
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
    def tearDown(self):shutil.rmtree(self.tmp)
    def put(self,path,body,status=200,headers=None):self.responses[path]=[{'status':status,'body':copy.deepcopy(body),'headers':headers or {}}]
    def subject_file(self,path,raw):self.put(prefix+'contents/'+path+'?ref='+sha,{'path':path,'type':'file','encoding':'base64','size':len(raw),'content':base64.b64encode(raw).decode()})
    def body(self,path):return self.responses[path][0]['body']
    def collect(self):
        (self.fixture/'responses.json').write_bytes(c.canonical(self.responses))
        collector=c.RemoteCollector(repo,sha,self.tmp/'out',self.fixture,'issues');code=collector.run()
        value=c.read_json(collector.output/'verdict.json');self.assertFalse(value['requirements_credit'])
        portable=b''.join(f.read_bytes() for f in collector.portable.rglob('*') if f.is_file())
        self.assertNotIn(b'ADVISORY-CANARY-PRIVATE-BODY',portable)
        return code,value,collector
    def reject(self,reason):
        code,value,collector=self.collect();self.assertEqual(code,1);self.assertEqual(value['reason'],reason)
        self.assertFalse((collector.portable/'sources.json').exists())
    def test_complete_real_disposition_ledger_and_two_reads(self):
        code,value,collector=self.collect();self.assertEqual(code,0)
        result=c.read_json(collector.portable/'sources.json');self.assertEqual(result['scope'],'issues-tracer')
        self.assertEqual(result['sources']['remote-inventory']['source']['normalized']['ledger_sha256'],c.digest((root/c.LEDGER).read_bytes()))
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
