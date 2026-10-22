Code.require_file("../twin/host/lib/twin/repo.ex", __DIR__)
Code.require_file("../twin/host/lib/twin/storage.ex", __DIR__)
Code.require_file("../twin/host/lib/twin/tracer.ex", __DIR__)
Code.require_file("../twin/host/lib/twin/application.ex", __DIR__)

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
            self.mounts=[dict(Type='volume',Name=project+'_retained',Destination='/retained')];self.volumes=set(self.descriptor['volumes']);self.networks={self.descriptor['network']};self.host=True;self.state=state;self.mutations=[];self.checks=0;self.restart_at=restart_at
        def command(self,a,timeout=120):
            if a[1]=='ps':
                if any(x.startswith('volume=') for x in a):return ''
                self.checks+=1
                if self.state=='unknown':raise Refused('unavailable')
                if self.restart_at and self.checks>=self.restart_at:self.host=True;self.state='running'
                return 'b'*64 if self.host else ''
            if a[1]=='inspect':return json.dumps([dict(Id='b'*64,Name='/'+self.project+'-host-1',Mounts=self.mounts,Config=dict(Labels={'com.docker.compose.project':self.project,'com.docker.compose.service':'host'}),State=dict(Status=self.state,Running=self.state=='running',Paused=self.state=='paused'))])
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
    for mounts in [[],[dict(Type='bind',Name='foreign',Destination='/retained')],[dict(Type='volume',Name='foreign',Destination='/retained')],[dict(Type='volume',Name='foreign',Destination='/data')]]:
        with tempfile.TemporaryDirectory() as tmp:
            f=Fake(Path(tmp));f.mounts=mounts
            try:dispose(f)
            except Refused:pass
            else:raise AssertionError('foreign mount')
            assert not f.mutations and len(f.volumes)==3
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

  test "maintenance runtime starts only its Repo and refuses unknown roles" do
    assert Twin.Application.children("maintenance") == [Twin.Repo]
    assert_raise ArgumentError, fn -> Twin.Application.children("unrecognized") end
  end

  test "multipart inventory requires a real exact part and complete raw XML pagination" do
    xml = """
    <ListPartsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
      <Bucket>owned</Bucket><Key>owned/source.png</Key><UploadId>private-upload</UploadId>
      <PartNumberMarker>0</PartNumberMarker><NextPartNumberMarker>1</NextPartNumberMarker>
      <MaxParts>1000</MaxParts><IsTruncated>false</IsTruncated>
      <Part><PartNumber>1</PartNumber><ETag>"11111111111111111111111111111111"</ETag><Size>69</Size></Part>
    </ListPartsResult>
    """

    assert {:ok, [%{"number" => 1, "bytes" => 69, "etag_sha256" => hash}]} =
             Twin.Tracer.cleanup_parts(xml, "owned", "owned/source.png", "private-upload")

    assert hash ==
             :crypto.hash(:sha256, ~s("11111111111111111111111111111111"))
             |> Base.encode16(case: :lower)

    for {before, after_value} <- [
          {"<IsTruncated>false", "<IsTruncated>true"},
          {"<PartNumberMarker>0", "<PartNumberMarker>1"},
          {"<NextPartNumberMarker>1", "<NextPartNumberMarker>2"},
          {"<MaxParts>1000", "<MaxParts>1"},
          {"<Size>69", "<Size>0"},
          {"<PartNumber>1", "<PartNumber>2"},
          {"private-upload", "foreign-upload"},
          {"owned/source.png", "foreign/source.png"},
          {"<Bucket>owned", "<Bucket>foreign"},
          {"<Part>", "<WrongPart>"},
          {"</Part>", "</WrongPart>"}
        ] do
      assert {:error, :incomplete_inventory} =
               Twin.Tracer.cleanup_parts(
                 String.replace(xml, before, after_value),
                 "owned",
                 "owned/source.png",
                 "private-upload"
               )
    end

    assert {:error, :incomplete_inventory} =
             Twin.Tracer.cleanup_parts(
               "<Error><Code>AccessDenied</Code></Error>",
               "owned",
               "key",
               "id"
             )
  end

  test "empty upload and object inventories reject missing completion and continuation cursors" do
    uploads = """
    <ListMultipartUploadsResult><Bucket>owned</Bucket><KeyMarker></KeyMarker>
      <UploadIdMarker></UploadIdMarker><MaxUploads>1000</MaxUploads>
      <IsTruncated>false</IsTruncated></ListMultipartUploadsResult>
    """

    assert {:ok, []} = Twin.Tracer.cleanup_uploads(uploads, "owned")

    for xml <- [
          String.replace(uploads, "<IsTruncated>false</IsTruncated>", ""),
          String.replace(uploads, "<IsTruncated>false", "<IsTruncated>true"),
          String.replace(uploads, "<KeyMarker>", "<KeyMarker>foreign"),
          String.replace(uploads, "<UploadIdMarker>", "<UploadIdMarker>foreign"),
          String.replace(uploads, "<MaxUploads>1000", "<MaxUploads>0"),
          String.replace(
            uploads,
            "</ListMultipartUploadsResult>",
            "<NextKeyMarker>foreign</NextKeyMarker></ListMultipartUploadsResult>"
          ),
          "<Error><Code>AccessDenied</Code></Error>",
          ""
        ] do
      assert {:error, :incomplete_inventory} = Twin.Tracer.cleanup_uploads(xml, "owned")
    end

    objects = """
    <ListBucketResult><Name>owned</Name><MaxKeys>1000</MaxKeys><KeyCount>0</KeyCount>
      <IsTruncated>false</IsTruncated></ListBucketResult>
    """

    assert {:ok, []} = Twin.Tracer.cleanup_objects(objects, "owned")

    for xml <- [
          String.replace(objects, "<IsTruncated>false", "<IsTruncated>true"),
          String.replace(objects, "<KeyCount>0", "<KeyCount>1"),
          String.replace(objects, "<Name>owned", "<Name>foreign"),
          String.replace(
            objects,
            "</ListBucketResult>",
            "<NextContinuationToken>foreign</NextContinuationToken></ListBucketResult>"
          ),
          String.replace(
            objects,
            "</ListBucketResult>",
            "<Contents><Key>foreign</Key></Contents></ListBucketResult>"
          ),
          "<ListBucketResult/>",
          ""
        ] do
      assert {:error, :incomplete_inventory} = Twin.Tracer.cleanup_objects(xml, "owned")
    end
  end

  test "only exact NoSuchUpload makes an observed multipart upload absent" do
    missing = {:error, {:http_error, 404, %{body: "<Error><Code>NoSuchUpload</Code></Error>"}}}
    assert Twin.Tracer.cleanup_missing_upload?(missing)

    for result <- [
          {:error, {:http_error, 403, %{body: "<Error><Code>AccessDenied</Code></Error>"}}},
          {:error, {:http_error, 404, %{body: "<Error><Code>NoSuchKey</Code></Error>"}}},
          {:error, {:http_error, 404, %{body: ""}}},
          {:ok, %{body: %{parts: []}}},
          {:error, :timeout}
        ] do
      refute Twin.Tracer.cleanup_missing_upload?(result)
    end
  end

  test "audit scope refuses foreign, duplicate, unordered and unknown assets before cleanup" do
    first = "00000000-0000-4000-8000-000000000001"
    second = "00000000-0000-4000-8000-000000000002"

    for case_id <- ~w(tus-resume purge-absence av-repair provider-events promotion-restart) do
      assert Twin.Tracer.audit_scope?(case_id, [first], [first])
      assert Twin.Tracer.audit_scope?(case_id, [first], [])
      refute Twin.Tracer.audit_scope?(case_id, [first], [second])
      refute Twin.Tracer.audit_scope?(case_id, [first, first], [first])
      refute Twin.Tracer.audit_scope?(case_id, [], [])
      refute Twin.Tracer.audit_scope?(case_id, ["invalid"], [])
    end

    assert Twin.Tracer.audit_scope?("interrupted-cleanup", [first, second], [first, second])
    assert Twin.Tracer.audit_scope?("interrupted-cleanup", [first, second], [])
    refute Twin.Tracer.audit_scope?("interrupted-cleanup", [second, first], [])
    refute Twin.Tracer.audit_scope?("interrupted-cleanup", [first, first], [])
    refute Twin.Tracer.audit_scope?("interrupted-cleanup", [first], [])
    refute Twin.Tracer.audit_scope?("unknown", [first], [first])
    refute Twin.Tracer.audit_scope?(nil, [first], [])
    refute Twin.Tracer.audit_scope?("tus-resume", nil, [])
    refute Twin.Tracer.audit_scope?("tus-resume", [first], nil)
  end

  test "matrix disposal preflights every child and binds finite retained authorities before mutation" do
    code = """
    import sys,json,tempfile,copy,hashlib
    from pathlib import Path
    from types import SimpleNamespace
    from unittest.mock import patch
    sys.path[:0]=['scripts/maintainer','test/install_smoke/support']
    from twin_fixture import fixture
    from twin_receipt import CASES,KIND,MATRIX_SCENARIO,FIXTURE_MATRIX_SHA256,TUS_SHA256,AV_SHA256,Refused
    from twin_cleanup import dispose_matrix
    h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory() as tmp:
        root=Path(tmp).resolve();children={};entries=[];authorities={}
        base,_=fixture()
        for i,case_id in enumerate(CASES,1):
            child=root/'cases'/case_id;child.mkdir(parents=True)
            inputs=copy.deepcopy(base);inputs.update(schema_version=2,scenario=case_id,run_id=format(i,'032x'),fixture_sha256=AV_SHA256 if case_id in ['av-repair','provider-events'] else TUS_SHA256)
            authorities[case_id]=inputs
            (child/'inputs.json').write_text(json.dumps(inputs))
            descriptor={'run_id':inputs['run_id']}
            (child/'resources.json').write_text(json.dumps(descriptor))
            children[child]=SimpleNamespace(evidence=child,descriptor=descriptor,active=False)
            entries.append(dict(case_id=case_id,run_id=inputs['run_id'],descriptor_sha256=h(child/'resources.json')))
        inputs=copy.deepcopy(authorities[CASES[0]])
        inputs.update(schema_version=3,scenario=MATRIX_SCENARIO,run_id='d'*32,fixture_sha256=FIXTURE_MATRIX_SHA256,case_inputs=authorities)
        (root/'inputs.json').write_text(json.dumps(inputs))
        descriptor=dict(schema_version=2,kind=KIND,independent_pilot_credit=False,run_id=inputs['run_id'],evidence=str(root),inputs_sha256=h(root/'inputs.json'),cases=entries)
        runner=SimpleNamespace(evidence=root,descriptor=descriptor)
        mutated=[];observed=[]
        def make(path,described):
            assert children[path].descriptor==described
            return children[path]
        def preflight(child):
            observed.append(child.evidence)
            if child.active:raise Refused('cleanup_active_runtime')
        with patch('twin_cleanup.preflight_disposal',preflight),patch('twin_cleanup.dispose',lambda child:mutated.append(child.evidence)):
            last=children[root/'cases'/CASES[-1]];last.active=True
            try:dispose_matrix(runner,make)
            except Refused:pass
            else:raise AssertionError('last active writer accepted')
            assert len(observed)==6 and mutated==[]
            last.active=False
            for change in ['duplicate','foreign','hash','run','unknown']:
                broken=copy.deepcopy(descriptor)
                if change=='duplicate':broken['cases'][-1]=copy.deepcopy(broken['cases'][0])
                elif change=='foreign':broken['evidence']='/tmp/foreign'
                elif change=='hash':broken['cases'][-1]['descriptor_sha256']='f'*64
                elif change=='run':broken['cases'][-1]['run_id']='f'*32
                else:broken['force']=True
                runner.descriptor=broken
                try:dispose_matrix(runner,make)
                except Refused:pass
                else:raise AssertionError(change)
                assert mutated==[]
            runner.descriptor=descriptor
            assert dispose_matrix(runner,make) and len(mutated)==6
            assert dispose_matrix(runner,make) and len(mutated)==12
    """

    assert {_, 0} = System.cmd("python3", ["-B", "-c", code], cd: @root, stderr_to_stdout: true)
  end
end
