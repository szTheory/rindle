#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$root"
PYTHONDONTWRITEBYTECODE=1 python3 - "$root" <<'PY'
import gzip, importlib.util, io, json, os, pathlib, shutil, subprocess, sys, tarfile, tempfile, unittest
from unittest.mock import patch
root = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location('readiness', root/'scripts/maintainer/exact_head_readiness.py')
r = importlib.util.module_from_spec(spec); spec.loader.exec_module(r)

env = {**os.environ, **r.TOOLCHAIN_ENV, 'RINDLE_EXACT_HEAD_LIBRARY_ONLY':'1'}
expr = 'Code.require_file("scripts/maintainer/validate_exact_head_readiness.exs"); v=Rindle.ExactHeadReadiness; IO.puts(Jason.encode!(%{policy: v.policy(), toolchain: v.toolchain(), inputs: v.input_paths(), commands: Map.new(v.required_proofs() -- v.mutable_proofs(), &{&1,v.command_prefix(&1)})}))'
metadata = json.loads(subprocess.check_output(['mix','run','--no-start','-e',expr],cwd=root,env=env).decode().splitlines()[-1])

class Fixture(r.Qualification):
    evidence_mode = 'fixture'
    fail = None
    def remote_main(self):
        return 'b'*40 if self.fail == 'main' else self.subject
    def checkout(self):
        self.workspace = pathlib.Path(tempfile.mkdtemp(prefix='rindle-readiness-source-'+self.run_id+'-')).resolve()/'source'
        self.checked(['git','clone','--quiet',str(self.root),str(self.workspace)],cwd=self.root)
        self.checked(['git','checkout','--quiet','--detach',self.subject])
        self.initial_clean = True
        if self.fail == 'dirty':
            (self.workspace/'unowned').write_text('residue')
            raise r.NotReady('dirty_checkout')
    def prepare(self):
        self.policy = metadata
        self.validator_sha=r.digest((root/r.POLICY_FILE).read_bytes())
        self.inputs={}
        for relative in self.policy['inputs']:
            dest=self.portable/'inputs'/relative
            r.write_new(dest,(root/relative).read_bytes())
            self.inputs[relative]=r.reference(self.portable,dest)
        self.runtime_evidence={}
        for name,data in [('elixir',b'1.17.3\n27.3.4.15\n'),('node',b'v20.18.1\n')]:
            path=self.portable/'runtime'/name;r.write_new(path,data);self.runtime_evidence[name]=r.reference(self.portable,path)
        self.package_identity={}; self.package_files={}
        for kind in ('package_tar_sha256','package_metadata_sha256','package_tree_sha256'):
            path=self.portable/'package'/kind
            r.write_new(path,('fixture '+kind).encode())
            self.package_files[kind]=r.reference(self.portable,path)
            self.package_identity[kind]=self.package_files[kind]['sha256']
    def start_services(self):
        pass
    def upstream(self):
        pass
    def gates(self):
        return super().gates()
    def gate(self, id, argv):
        if self.fail == 'crash':
            raise OSError('fixture crash')
        record,_=self.checked(['python3','-c','print("supported fixture gate")'])
        record['fixture_transport']=record['argv']
        record['argv']=argv
        self.receipts.append({'id':id,'command':record})

class QualificationTest(unittest.TestCase):
    def setUp(self):
        self.temp = pathlib.Path(tempfile.mkdtemp(prefix='rindle139-qualification-')).resolve()
        self.source = self.temp/'repo'; self.source.mkdir()
        self.git('init','--quiet')
        self.git('config','user.name','Fixture'); self.git('config','user.email','fixture@invalid.example')
        (self.source/'tracked').write_text('immutable input')
        self.git('add','tracked'); self.git('commit','--quiet','-m','fixture source')
        self.sha = self.git('rev-parse','HEAD').decode().strip()
    def tearDown(self):
        shutil.rmtree(self.temp)
    def git(self,*argv):
        return subprocess.check_output(['git',*argv],cwd=self.source,stderr=subprocess.DEVNULL)
    def controller(self, failure=None):
        q=Fixture(self.source,self.temp/'out','szTheory/rindle',self.sha)
        q.fail=failure
        return q
    def test_one_real_command_in_fresh_subject_has_bytes_and_nonpassing_attempt(self):
        q=self.controller(); self.assertEqual(q.run(),0)
        value=r.read_json(q.output/'attempt.json')
        self.assertEqual(value['verdict'],'not_ready')
        self.assertEqual(set(value['proofs']),set(metadata['commands']))
        manifest=r.read_json(q.portable/'manifest.json')
        ref=manifest['proofs'][0]
        self.assertEqual(ref['sha256'],r.digest((q.portable/ref['path']).read_bytes()))
        receipt=r.read_json(q.portable/ref['path'])
        self.assertEqual(receipt['command']['exit_code'],0)
        self.assertEqual(receipt['evidence_mode'],'fixture')
        self.assertIn(b'supported fixture gate',(q.portable/receipt['command']['output']['path']).read_bytes())
        self.assertFalse(q.workspace.exists())
        self.assertEqual(self.git('status','--porcelain'),b'')
    def test_changed_main_never_clones_or_runs(self):
        q=self.controller('main'); self.assertEqual(q.run(),1)
        self.assertEqual(r.read_json(q.output/'attempt.json')['reason'],'main_changed')
        self.assertIsNone(q.workspace)
    def test_crash_persists_nonpassing_attempt_and_observed_cleanup(self):
        q=self.controller('crash'); self.assertEqual(q.run(),1)
        value=r.read_json(q.output/'attempt.json')
        self.assertEqual(value['verdict'],'not_ready')
        self.assertEqual(value['cleanup']['state'],'observed')
        self.assertFalse(q.workspace.exists())
    def test_dirty_checkout_never_qualifies(self):
        q=self.controller('dirty'); self.assertEqual(q.run(),1)
        self.assertEqual(r.read_json(q.output/'attempt.json')['verdict'],'not_ready')
        # The runner refuses to delete unexplained source residue.
        self.assertEqual(r.read_json(q.output/'attempt.json')['cleanup']['state'],'failed')
        shutil.rmtree(q.workspace.parent)
    def test_output_inside_source_and_reused_attempt_are_rejected(self):
        q=Fixture(self.source,self.source/'bad','szTheory/rindle',self.sha)
        with self.assertRaises(r.NotReady): q.run()
        q=self.controller(); q.run()
        with self.assertRaises(r.NotReady): self.controller().run()
    def test_full_registry_cannot_be_satisfied_by_one_green_command(self):
        q=self.controller(); q.run()
        value=r.read_json(q.output/'attempt.json')
        self.assertEqual(value.get('local_qualification'),'complete')
        self.assertEqual(set(value['proofs']), set(q.policy['commands']))
        self.assertEqual(len(value['proofs']),18)

    def test_registered_omission_fails_before_any_green_expansion(self):
        q=self.controller(); q.reserve(); q.prepare()
        q.policy={**q.policy,'commands':{k:v for k,v in metadata['commands'].items() if k!='doctor'}}
        with self.assertRaisesRegex(r.NotReady,'gate_registry_drift'): q.gates()
    def test_actual_owner_rejects_an_unsupported_resolved_runtime(self):
        q=self.controller(); q.reserve(); q.workspace=root
        with patch.object(q,'checked',side_effect=[({},b'1.18.0\n28.0\n'),({},b'v20.18.1')]):
            with self.assertRaisesRegex(r.NotReady,'unsupported_toolchain'):
                r.Qualification.prepare(q)
    def test_actual_api_adapter_checks_ref_identity(self):
        q=self.controller(); q.reserve()
        with patch.object(q,'checked',return_value=({},json.dumps({'ref':'refs/heads/main','object':{'sha':self.sha}}).encode())) as command:
            self.assertEqual(r.Qualification.remote_main(q),self.sha)
            self.assertEqual(command.call_args.args[0][2:4],['--method','GET'])
        with patch.object(q,'checked',return_value=({},b'{"ref":"refs/heads/other","object":{}}')):
            with self.assertRaisesRegex(r.NotReady,'remote_ref_identity'): r.Qualification.remote_main(q)
    def archive(self, extra=None):
        def tar(items):
            output=io.BytesIO()
            with tarfile.open(fileobj=output,mode='w') as stream:
                for name,data in items.items():
                    info=tarfile.TarInfo(name);info.size=len(data);stream.addfile(info,io.BytesIO(data))
            return output.getvalue()
        files={'mix.exs':b'fixture project',**(extra or {})}
        payload=gzip.compress(tar(files),mtime=0)
        path=self.temp/'package.tar'
        path.write_bytes(tar({'VERSION':b'3','CHECKSUM':b'fixture','metadata.config':b'fixture Hex metadata','contents.tar.gz':payload}))
        return path
    def test_actual_upstream_archive_adapter_keeps_three_distinct_digest_kinds(self):
        q=self.controller(); q.reserve(); q.workspace=root
        archive=self.archive()
        r.Qualification.stage_package(q,archive)
        self.assertEqual(q.package_identity['package_tar_sha256'],r.digest(archive.read_bytes()))
        self.assertEqual(q.package_identity['package_metadata_sha256'],r.digest(b'fixture Hex metadata'))
        self.assertEqual(len(set(q.package_identity.values())),3)
        self.assertEqual((q.package_root/'hex_metadata.config').read_bytes(),b'fixture Hex metadata')
        for key,ref in q.package_files.items():
            self.assertEqual(r.digest((q.portable/ref['path']).read_bytes()),q.package_identity[key])
    def test_prebuilt_beam_is_refused_by_actual_upstream_archive_owner(self):
        q=self.controller(); q.reserve(); q.workspace=root
        archive=self.archive({'ebin/prebuilt.beam':b'forbidden'})
        with self.assertRaisesRegex(Exception,'package_build_material'):
            r.Qualification.stage_package(q,archive)
    def test_foreign_volume_user_blocks_disposal_before_any_mutation(self):
        q=self.controller(); q.reserve()
        owner=r.OwnedServices(q)
        r.write_new(owner.file,{'services':{}})
        owner.compose_sha=r.digest(owner.file.read_bytes())
        with patch.object(owner,'inventory',return_value=['owned']), patch.object(q,'checked',return_value=({},b'foreign')), patch.object(owner,'compose') as mutate:
            with self.assertRaisesRegex(r.NotReady,'foreign_volume_user'): owner.cleanup()
            mutate.assert_not_called()
    def test_changed_service_descriptor_blocks_disposal(self):
        q=self.controller(); q.reserve(); owner=r.OwnedServices(q)
        r.write_new(owner.file,{'services':{}}); owner.compose_sha='0'*64
        with patch.object(owner,'compose') as mutate:
            with self.assertRaisesRegex(r.NotReady,'service_descriptor_changed'): owner.cleanup()
            mutate.assert_not_called()
    def test_secret_values_are_redacted_from_portable_command_output(self):
        q=self.controller(); q.reserve(); q.env['FIXTURE_TOKEN']='fixture-secret-token'
        record,raw=q.command(['python3','-c','import os; print(os.environ["FIXTURE_TOKEN"])'])
        self.assertIn(b'fixture-secret-token',raw)
        public=(q.portable/record['output']['path']).read_bytes()
        self.assertNotIn(b'fixture-secret-token',public)
        self.assertIn(b'[REDACTED]',public)

    def test_green_transport_does_not_hide_wrong_bootstrap_subject(self):
        q=self.controller();q.reserve();q.workspace=self.source
        def fake(argv,**kwargs):
            r.write_new(q.bootstrap,{'outcome':'complete','full':True,'subject_sha':'b'*40})
            return {},b''
        with patch.object(q,'checked',side_effect=fake):
            with self.assertRaisesRegex(r.NotReady,'bootstrap_incomplete'):
                r.Qualification.gate(q,'contributor-bootstrap',metadata['commands']['contributor-bootstrap'])
    def test_green_transport_does_not_hide_a_hygiene_warning(self):
        q=self.controller();q.reserve();q.workspace=self.source
        with patch.object(q,'checked',return_value=({},b'Summary: 20 PASS, 1 WARN, 0 BLOCK')):
            with self.assertRaisesRegex(r.NotReady,'hygiene_warning'):
                r.Qualification.gate(q,'hygiene',metadata['commands']['hygiene'])
    def test_green_transport_does_not_hide_wrong_matrix_package(self):
        q=self.controller();q.reserve();q.workspace=self.source
        q.package_identity={'package_tar_sha256':'a'*64}
        def fake(argv,**kwargs):
            if not (q.matrix/'inputs.json').exists():
                r.write_new(q.matrix/'inputs.json',{'source_sha':self.sha,'package_tar_sha256':'b'*64})
            return {},b''
        with patch.object(q,'checked',side_effect=fake):
            with self.assertRaisesRegex(r.NotReady,'matrix_package_identity'):
                r.Qualification.gate(q,'twin-recovery',metadata['commands']['twin-recovery'])
    def test_cleanup_failure_cannot_become_complete_local_qualification(self):
        q=self.controller()
        original=q.cleanup
        def failed_cleanup():
            original()
            return {'state':'failed','errors':['retained residue'],'inventories':[]}
        q.cleanup=failed_cleanup
        self.assertEqual(q.run(),1)
        self.assertNotEqual(r.read_json(q.output/'attempt.json').get('local_qualification'),'complete')
    def test_changed_package_bytes_cannot_become_complete_local_qualification(self):
        q=self.controller()
        original=q.finalize
        def corrupt_before_finalize():
            (q.portable/q.package_files['package_tar_sha256']['path']).write_bytes(b'corrupt')
            return original()
        q.finalize=corrupt_before_finalize
        self.assertEqual(q.run(),1)
        self.assertNotEqual(r.read_json(q.output/'attempt.json').get('local_qualification'),'complete')

    def test_restored_plt_rebuild_cannot_be_reported_as_clean_restoration(self):
        q=self.controller();q.reserve();q.workspace=self.source
        plt=q.workspace/'priv/plts/dialyzer.plt';plt.parent.mkdir(parents=True);plt.write_bytes(b'fixture plt')
        q.fresh_plt=q.plt_inventory()
        with patch.object(q,'checked',return_value=({},b'nightly-dialyzer mode=restored attempt=1 fingerprint=old-plt recovery=rebuild-once')):
            with self.assertRaisesRegex(r.NotReady,'stale_restored_plt'):
                r.Qualification.gate(q,'dialyzer-restored',metadata['commands']['dialyzer-restored'])

    def test_cleanup_retry_preserves_original_attempt_and_retained_outputs(self):
        q=self.controller('crash');q.run()
        original=(q.output/'attempt.json').read_bytes()
        old_logs={p.name:p.read_bytes() for p in q.private.glob('command-*.txt')}
        self.assertEqual(r.cleanup_existing(root,q.output),0)
        self.assertEqual((q.output/'attempt.json').read_bytes(),original)
        self.assertTrue(list(q.output.glob('cleanup-*.json')))
        for name,data in old_logs.items(): self.assertEqual((q.private/name).read_bytes(),data)
    def test_cleanup_has_an_independent_budget_after_collection_timeout(self):
        q=self.controller()
        def expired_gate(*args):
            q.deadline=__import__('time').monotonic()-1
            raise r.NotReady('command_timeout')
        q.gate=expired_gate
        original=q.cleanup
        def cleanup_after_expiry():
            self.assertGreater(q.deadline-__import__('time').monotonic(),200)
            return original()
        q.cleanup=cleanup_after_expiry
        self.assertEqual(q.run(),1)

    def test_real_subprocess_deadline_is_terminal(self):
        q=self.controller(); q.reserve()
        q.deadline=__import__('time').monotonic()+0.1
        with self.assertRaisesRegex(r.NotReady,'command_timeout'):
            q.command(['python3','-c','import time; time.sleep(60)'])
        self.assertTrue(list(q.private.glob('command-*.txt')))

unittest.main(argv=['qualification'],verbosity=1)
PY
printf 'PASS: exact-head qualification full-gate fixture assertions; exact archive/metadata/payload identities, owned cleanup and nonpassing failure paths\n'
