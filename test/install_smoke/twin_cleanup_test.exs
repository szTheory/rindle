defmodule Rindle.TwinCleanupTest do
  use ExUnit.Case, async: true
  @root Path.expand("../..", __DIR__)
  test "unknown, truncated, residual or dry-run inventory never becomes acceptance" do
    code = """
    import sys,copy
    sys.path[:0]=['scripts/maintainer','test/install_smoke/support']
    from twin_fixture import fixture
    from twin_receipt import verify_receipt,Refused
    inputs,receipt=fixture();assert verify_receipt(inputs,receipt)
    for field,value in [('complete',False),('listing_complete',False),('objects',1),('multipart',None),('temp_files',1),('processes',1),('peer_rows',2),('relations',{}),('dry_run',True)]:
        r=copy.deepcopy(receipt);r['inventory'][field]=value
        try:verify_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError(field)
    for state in ['executing','retryable','scheduled','discarded']:
        r=copy.deepcopy(receipt);r['inventory']['jobs'][2]['state']=state
        try:verify_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError(state)
    r=copy.deepcopy(receipt);r['outcome']='failed'
    # Deleting infrastructure cannot change the frozen domain failure.
    try:verify_receipt(inputs,r)
    except Refused:pass
    else:raise AssertionError('forced disposal repaired failure')
    """

    assert {_, 0} = System.cmd("python3", ["-B", "-c", code], cd: @root, stderr_to_stdout: true)
  end

  test "janitor refuses active paused unknown restarted and foreign descriptors; repeat cleanup preserves decoys" do
    code = """
    import sys,json,tempfile,hashlib
    from pathlib import Path
    sys.path[:0]=['scripts/maintainer','test/install_smoke/support']
    from twin_fixture import fixture
    from twin_cleanup import dispose
    from twin_receipt import KIND,Refused
    h=lambda b:hashlib.sha256(b).hexdigest()
    class Fake:
        def __init__(self,root,state='exited',restart_at=0):
            root=root.resolve();self.evidence=root;self.context=root/'workspace';self.context.mkdir()
            (self.context/'compose.yml').write_bytes(b'compose');(self.context/'Dockerfile').write_bytes(b'build')
            inputs,_=fixture();inputs['build_sha256']=h(b'buildcompose')
            (root/'inputs.json').write_text(json.dumps(inputs));(root/'.env').write_text('TWIN_PROJECT=rindle-twin-'+inputs['run_id']+'\\nTWIN_RUN_ID='+inputs['run_id']+'\\nTWIN_DATABASE=twin_'+inputs['run_id']+'\\nTWIN_BUCKET=twin-'+inputs['run_id']+'\\nTWIN_SECRET='+'a'*48+'\\n')
            project='rindle-twin-'+inputs['run_id'];self.project=project
            self.descriptor=dict(schema_version=1,kind=KIND,independent_pilot_credit=False,run_id=inputs['run_id'],project=project,database='twin_'+inputs['run_id'],bucket='twin-'+inputs['run_id'],workspace=str(self.context),evidence=str(root),host_names=[project+'-host-1'],volumes=[project+s for s in ['_database','_objects','_retained']],network=project+'_default',image=project+':local',compose_sha256=h(b'compose'),env_sha256=h((root/'.env').read_bytes()),inputs_sha256=h((root/'inputs.json').read_bytes()))
            self.volumes=set(self.descriptor['volumes']);self.networks={self.descriptor['network']};self.host=True;self.state=state;self.mutations=[];self.checks=0;self.restart_at=restart_at
        def command(self,a,timeout=120):
            if a[1]=='ps':
                if any(x.startswith('volume=') for x in a):return ''
                self.checks+=1
                if self.state=='unknown':raise Refused('unavailable')
                if self.restart_at and self.checks>=self.restart_at:self.host=True;self.state='running'
                return 'b'*64 if self.host else ''
            if a[1]=='inspect':return json.dumps([dict(Id='b'*64,Name='/'+self.project+'-host-1',Config=dict(Labels={'com.docker.compose.project':self.project,'com.docker.compose.service':'host'}),State=dict(Status=self.state,Running=self.state=='running',Paused=self.state=='paused'))])
            if a[1:3]==['volume','ls']:return '\\n'.join(self.volumes)
            if a[1:3]==['network','ls']:return '\\n'.join(self.networks)
            if a[1:3]==['network','inspect']:return '[{"Containers":{}}]'
            if a[1:3]==['image','ls']:return ''
            self.mutations.append(a)
            if a[1]=='rm':self.host=False
            elif a[1:3]==['volume','rm']:self.volumes.remove(a[-1])
            elif a[1:3]==['network','rm']:self.networks.remove(a[-1])
            else:raise AssertionError(a)
            return ''
    for state in ['running','paused','unknown']:
        with tempfile.TemporaryDirectory() as tmp:
            f=Fake(Path(tmp),state)
            try:dispose(f)
            except Refused:pass
            else:raise AssertionError(state)
            assert not f.mutations and len(f.volumes)==3 and f.context.exists()
    with tempfile.TemporaryDirectory() as tmp:
        f=Fake(Path(tmp),restart_at=4)
        try:dispose(f)
        except Refused:pass
        else:raise AssertionError('restart race')
        assert len(f.volumes)==3 and f.context.exists()
    for field,value in [('workspace','/tmp/foreign'),('bucket','decoy'),('run_id','b'*32)]:
        with tempfile.TemporaryDirectory() as tmp:
            f=Fake(Path(tmp));f.descriptor[field]=value
            try:dispose(f)
            except Refused:pass
            else:raise AssertionError(field)
            assert not f.mutations
    with tempfile.TemporaryDirectory() as tmp:
        root=Path(tmp)/'owned';root.mkdir();decoy=Path(tmp)/'decoy';decoy.write_text('preserve')
        f=Fake(root);(root/'receipt.json').write_text('{"outcome":"failed"}')
        before=(root/'receipt.json').read_bytes()
        assert dispose(f) and dispose(f)
        assert not f.volumes and not f.networks and not f.context.exists()
        assert decoy.read_text()=='preserve' and (root/'receipt.json').read_bytes()==before
    """

    assert {_, 0} = System.cmd("python3", ["-B", "-c", code], cd: @root, stderr_to_stdout: true)
  end
end
