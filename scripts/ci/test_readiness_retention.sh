#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$root"
export PYTHONDONTWRITEBYTECODE=1
export ASDF_ERLANG_VERSION="${ASDF_ERLANG_VERSION:-27.3.4.15}"
export ASDF_ELIXIR_VERSION="${ASDF_ELIXIR_VERSION:-1.17.3-otp-27}"
python3 - "$root" <<'PY'
import base64,copy,io,json,os,pathlib,shutil,subprocess,sys,tarfile,tempfile,unittest,zipfile
from unittest.mock import patch
root=pathlib.Path(sys.argv[1]);sys.path.insert(0,str(root/'scripts/maintainer'))
import readiness_retention as r
repo='szTheory/rindle';sha='a'*40
class Retention(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.shared=pathlib.Path(tempfile.mkdtemp(prefix='rindle139-retention-shared-')).resolve()
        script=cls.shared/'generate.exs';script.write_text('Code.require_file("scripts/ci/readiness_fixture.exs"); {base,m}=ReadinessFixture.fixture(); File.write!(Path.join(base,"manifest.json"),Jason.encode!(m)); IO.puts(Jason.encode!(%{base: base}))')
        env={**os.environ,'RINDLE_EXACT_HEAD_LIBRARY_ONLY':'1','RINDLE_READINESS_TEST_ROOT':str(cls.shared)}
        result=subprocess.run(['mix','run','--no-start','--no-compile','--no-deps-check',str(script)],cwd=root,env=env,capture_output=True,timeout=45)
        if result.returncode:raise AssertionError(result.stdout+result.stderr)
        cls.base=pathlib.Path(json.loads(result.stdout.decode().splitlines()[-1])['base'])
        cls.env={**os.environ,'GITHUB_ACTIONS':'true','GITHUB_REPOSITORY':repo,'GITHUB_SHA':sha,'GITHUB_REF':'refs/heads/main','GITHUB_EVENT_NAME':'workflow_dispatch','GITHUB_WORKFLOW':r.WORKFLOW_NAME,'GITHUB_WORKFLOW_REF':repo+'/'+r.WORKFLOW+'@refs/heads/main','GITHUB_RUN_ID':'123','GITHUB_RUN_ATTEMPT':'2'}
        cls.prepared=cls.shared/'prepared';r.prepare(cls.base/'manifest.json',cls.prepared,cls.env)
    @classmethod
    def tearDownClass(cls):shutil.rmtree(cls.shared)
    def setUp(self):
        self.tmp=pathlib.Path(tempfile.mkdtemp(prefix='rindle139-retention-')).resolve();self.fixture=self.tmp/'fixture';self.fixture.mkdir()
        self.sidecar=r.read_json(self.prepared/r.SIDECAR_FILE);self.archive=(self.prepared/r.ARCHIVE_FILE).read_bytes()
        self.run={'id':123,'run_attempt':2,'repository':{'full_name':repo},'path':r.WORKFLOW,'name':'Readiness '+('d'*32),'workflow_id':901,'event':'workflow_dispatch','head_branch':'main','head_sha':sha,'status':'completed','conclusion':'success'}
        self.responses={};self.sync()
    def tearDown(self):shutil.rmtree(self.tmp)
    def zipped(self,name,data):
        buf=io.BytesIO()
        with zipfile.ZipFile(buf,'w',zipfile.ZIP_DEFLATED) as z:z.writestr(name,data)
        return buf.getvalue()
    def sync(self):
        sz=self.zipped(r.SIDECAR_FILE,r.canonical(self.sidecar));az=self.zipped(r.ARCHIVE_FILE,self.archive)
        def artifact(id,name,data):return {'id':id,'name':name,'expired':False,'digest':'sha256:'+r.digest(data),'workflow_run':{'id':123,'head_sha':sha,'repository_id':7,'head_repository_id':7}}
        self.artifacts=[artifact(9,self.sidecar['sidecar_artifact_name'],sz),artifact(10,self.sidecar['archive_artifact_name'],az)]
        def row(body):return [{'status':200,'body':body}]
        self.responses={'repos/'+repo:row({'id':7,'full_name':repo}), 'repos/'+repo+'/actions/workflows/readiness-retention.yml':row({'id':901,'name':r.WORKFLOW_NAME,'path':r.WORKFLOW,'state':'active'}), 'repos/'+repo+'/actions/runs/123':row(self.run), 'repos/'+repo+'/actions/runs/123/attempts/2':row(self.run), 'repos/'+repo+'/actions/runs/123/artifacts?per_page=100':row({'total_count':2,'artifacts':self.artifacts}), 'repos/'+repo+'/actions/artifacts/9/zip':[{'status':200,'base64':base64.b64encode(sz).decode()}], 'repos/'+repo+'/actions/artifacts/10/zip':[{'status':200,'base64':base64.b64encode(az).decode()}]}
    def retrieve(self):
        self.responses['repos/'+repo+'/actions/runs/123/artifacts?per_page=100'][0]['body']['total_count']=len(self.artifacts)
        (self.fixture/'responses.json').write_bytes(r.canonical(self.responses))
        return r.retrieve(repo,123,2,self.tmp/'durable',self.fixture)
    def reject(self,reason):
        with self.assertRaisesRegex(r.NotReady,reason):self.retrieve()
        self.assertFalse((self.tmp/'durable').exists())
    def test_producer_digests_then_durable_atomic_copy(self):
        value=self.retrieve();self.assertTrue(value['bytes_verified']);self.assertFalse(value['requirements_credit']);self.assertEqual(value['storage_scope'],'fixture_only')
        self.assertEqual(value['manifest_sha256'],self.sidecar['manifest_sha256']);self.assertEqual((self.tmp/'durable/bundle/manifest.json').read_bytes(),(self.base/'manifest.json').read_bytes())
        self.assertEqual((self.tmp/'durable').stat().st_mode&0o777,0o700)
        self.assertTrue(all(p.stat().st_mode&0o777==0o600 for p in (self.tmp/'durable').rglob('*') if p.is_file()))
    def test_missing_sidecar(self):self.artifacts.pop(0);self.reject('producer_sidecar_missing_or_ambiguous')
    def test_ambiguous_sidecar(self):self.artifacts.append(copy.deepcopy(self.artifacts[0]));self.reject('producer_sidecar_missing_or_ambiguous')
    def test_missing_archive(self):self.artifacts.pop();self.reject('producer_archive_missing_or_ambiguous')
    def test_pending_run(self):self.run['status']='in_progress';self.reject('producer_not_completed_successfully')
    def test_failed_run(self):self.run['conclusion']='failure';self.reject('producer_not_completed_successfully')
    def test_wrong_current_attempt(self):self.run['run_attempt']=3;self.reject('producer_identity')
    def test_wrong_repository(self):self.run['repository']['full_name']='foreign/repo';self.reject('producer_identity')
    def test_static_display_name_is_not_workflow_authority(self):
        self.run['name']=r.WORKFLOW_NAME;self.run['workflow_id']=902;self.reject('producer_identity')
    def test_dynamic_run_name_with_authenticated_workflow_id(self):
        self.assertTrue(self.retrieve()['bytes_verified'])
    def test_foreign_workflow_path(self):
        self.run['path']='.github/workflows/foreign.yml';self.reject('producer_identity')
    def test_foreign_workflow_metadata(self):
        self.responses['repos/'+repo+'/actions/workflows/readiness-retention.yml'][0]['body']['path']='.github/workflows/foreign.yml';self.reject('producer_workflow_identity')
    def test_workflow_id_changes_during_download(self):
        path='repos/'+repo+'/actions/workflows/readiness-retention.yml'
        self.responses[path].append({'status':200,'body':{'id':902,'name':r.WORKFLOW_NAME,'path':r.WORKFLOW,'state':'active'}})
        self.reject('producer_workflow_changed')
    def test_attempt_changes_during_download(self):
        other={**self.run,'run_attempt':3};self.responses['repos/'+repo+'/actions/runs/123'].append({'status':200,'body':other});self.reject('producer_identity')
    def test_wrong_sidecar_attempt(self):self.sidecar['run_attempt']=1;self.sync();self.reject('producer_sidecar_identity')
    def test_wrong_sidecar_subject(self):self.sidecar['subject_sha']='b'*40;self.sync();self.reject('producer_sidecar_identity')
    def test_wrong_sidecar_repository(self):self.sidecar['repository']='foreign/repo';self.sync();self.reject('producer_sidecar_identity')
    def test_wrong_evidence_mode(self):self.sidecar['evidence_mode']='execution';self.sync();self.reject('producer_sidecar_identity')
    def test_independent_archive_digest_mismatch(self):self.sidecar['archive_sha256']='0'*64;self.sync();self.reject('producer_archive_digest')
    def test_independent_manifest_digest_mismatch(self):self.sidecar['manifest_sha256']='0'*64;self.sync();self.reject('producer_manifest_digest')
    def test_expired_archive(self):self.artifacts[1]['expired']=True;self.reject('artifact_identity')
    def test_foreign_artifact(self):self.artifacts[1]['workflow_run']['head_repository_id']=8;self.reject('artifact_identity')
    def test_transport_digest_mismatch(self):self.artifacts[1]['digest']='sha256:'+'0'*64;self.reject('artifact_transport_digest')
    def test_transport_digest_absent(self):del self.artifacts[1]['digest'];self.reject('artifact_digest_unavailable')
    def test_inaccessible_artifact(self):self.responses['repos/'+repo+'/actions/artifacts/10/zip']=[{'status':403,'body':{}}];self.reject('remote_forbidden')
    def test_storage_failure_never_publishes(self):
        with patch.object(r.os,'fsync',side_effect=OSError('disk failed')):
            with self.assertRaises(OSError):self.retrieve()
        self.assertFalse((self.tmp/'durable').exists())
    def test_parent_sync_failure_rolls_back_publication(self):
        original=r.os.fsync
        def fail_parent(fd):
            if r.os.fstat(fd).st_ino==self.tmp.stat().st_ino:raise OSError('parent sync failed')
            return original(fd)
        with patch.object(r.os,'fsync',side_effect=fail_parent):
            with self.assertRaises(OSError):self.retrieve()
        self.assertFalse((self.tmp/'durable').exists())
    def test_real_host_rejects_temporary_storage(self):
        with patch.dict(os.environ,{'GITHUB_ACTIONS':'false','RUNNER_TEMP':''}):
            with self.assertRaisesRegex(r.NotReady,'ephemeral_destination'):r.durable_path(self.tmp/'live',None)
    def test_runner_cannot_be_durable_host(self):
        with patch.dict(os.environ,{'GITHUB_ACTIONS':'true'}):
            with self.assertRaisesRegex(r.NotReady,'durable_host_required'):r.durable_path('/var/maintainer/new-evidence',None)
    def test_fixture_option_empty_cannot_enable_network(self):
        with self.assertRaises((r.NotReady,OSError)):r.retrieve(repo,123,2,self.tmp/'empty','')
    def test_prepare_refuses_foreign_producer_context(self):
        with self.assertRaisesRegex(r.NotReady,'producer_context_unavailable'):r.prepare(self.base/'manifest.json',self.tmp/'bad',{**self.env,'GITHUB_SHA':'b'*40})
        self.assertEqual(r.read_json(self.tmp/'bad/verdict.json')['verdict'],'not_ready')
    def test_prepare_cli_and_controlled_outputs(self):
        output=self.tmp/'prepared';github_output=self.tmp/'github-output'
        result=subprocess.run(['bash','scripts/maintainer/retain_readiness_bundle.sh','prepare','--manifest',str(self.base/'manifest.json'),'--output',str(output)],cwd=root,env={**self.env,'GITHUB_OUTPUT':str(github_output)},capture_output=True,timeout=45)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertIn('archive_name=rindle-readiness-archive-123-2-',github_output.read_text())
    def test_retrieve_cli_fixture(self):
        (self.fixture/'responses.json').write_bytes(r.canonical(self.responses))
        result=subprocess.run(['bash','scripts/maintainer/retain_readiness_bundle.sh','retrieve','--repo',repo,'--run-id','123','--attempt','2','--destination',str(self.tmp/'cli'),'--fixture',str(self.fixture)],cwd=root,capture_output=True,timeout=15)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr);self.assertFalse(r.read_json(self.tmp/'cli/locator.json')['requirements_credit'])
    def test_private_canary_and_secret_rejected(self):
        for data in (b'ADVISORY-CANARY-PRIVATE-BODY',b'PRIVATE-CLOSURE-CANARY',b'authorization: Bearer abcdefghijk',b'supersecret123'):
            with self.assertRaises(r.NotReady):r.scan_public({'object':data},{'SECRET':'supersecret123'})
    def test_tar_traversal_symlink_pax_and_extra_members_rejected(self):
        for name,kind in (('../escape',tarfile.REGTYPE),('link',tarfile.SYMTYPE),('extended',tarfile.XHDTYPE),('extra',tarfile.REGTYPE)):
            raw=io.BytesIO()
            with tarfile.open(fileobj=raw,mode='w:gz',format=tarfile.USTAR_FORMAT) as tar:
                info=tarfile.TarInfo(name);info.type=kind;info.size=1 if kind==tarfile.REGTYPE else 0;tar.addfile(info,io.BytesIO(b'x'))
            with self.assertRaises(r.NotReady):r.unpack(raw.getvalue(),self.tmp/name.replace('/','_'))
    def test_zip_requires_single_exact_file(self):
        with self.assertRaisesRegex(r.NotReady,'unsafe_artifact_archive'):r.zip_member(self.zipped('../bad',b'x'),r.ARCHIVE_FILE,100)

unittest.main(argv=['retention'],verbosity=1)
PY
echo 'PASS: producer sidecar, completed attempt identity, durable byte verification, private canaries and adverse retention fixtures'
