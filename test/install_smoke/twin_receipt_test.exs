defmodule Rindle.TwinReceiptTest do
  use ExUnit.Case, async: true
  @root Path.expand("../..", __DIR__)
  defp python(code) do
    System.cmd(
      "python3",
      [
        "-B",
        "-c",
        "import sys\nsys.path.insert(0,'test/install_smoke/support')\nsys.path.insert(0,'scripts/maintainer')\n" <>
          code
      ],
      cd: @root,
      stderr_to_stdout: true
    )
  end

  test "strict identities, types, empty inventories and forged verdicts fail" do
    code = """
    from twin_fixture import fixture
    from twin_receipt import verify_receipt, Refused, MAX_ID
    import copy
    inputs, receipt = fixture(); assert verify_receipt(inputs, receipt)
    mutations = [(['inputs','run_id'],'b'*32), (['inputs','lock_sha256'],'b'*64),
      (['inputs','fixture_sha256'],'b'*64), (['inputs','contract_sha256'],'b'*64),
      (['inputs','package_tar_sha256'],'b'*64), (['inputs','host_sha256'],'b'*64),
      (['independent_pilot_credit'],True), (['kind'],None), (['outcome'],'failed'),
      (['before','attempt'],2), (['before','attempt'],True), (['after','attempt'],2.0),
      (['before','stimuli','detach'],2), (['before','error_count'],0), (['after','job_id'],4),
      (['old_exited'],False), (['new_runtime','boot_id'],receipt['old_runtime']['boot_id']),
      (['inventory','objects'],1), (['inventory','complete'],False), (['inventory','domain'],{}),
      (['inventory','jobs'],[]), (['inventory','sequence'],2), (['before','sequence'],2),
      (['after','job_id'],MAX_ID+1), (['inputs','package_tar_sha256'],'a'*65),
      (['capabilities','av_exercised'],True)]
    for path,value in mutations:
        r=copy.deepcopy(receipt);target=r
        for key in path[:-1]: target=target[key]
        target[path[-1]]=value
        try:verify_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError(path)
    for key in receipt:
        r=copy.deepcopy(receipt);del r[key]
        try:verify_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError('missing '+key)
    r=copy.deepcopy(receipt);r['foreign']='secret'
    try:verify_receipt(inputs,r)
    except Refused:pass
    else:raise AssertionError('unknown key')
    r=copy.deepcopy(receipt)
    for location in [r['before'],r['after']]: location['job_id']=MAX_ID
    r['inventory']['jobs'][2]['id']=MAX_ID
    assert verify_receipt(inputs,r)
    """

    assert {_, 0} = python(code)
  end

  test "decoder rejects duplicates nonfinite values and one byte above its exact bound" do
    code = """
    from twin_receipt import decode, Refused, MAX_BYTES
    for raw in ['{"x":1,"x":2}', '{"x":{"a":1,"a":2}}','{"x":NaN}','{"x":Infinity}']:
        try:decode(raw)
        except Refused:pass
        else:raise AssertionError(raw)
    assert decode('{}'+' '*(MAX_BYTES-2))=={}
    try:decode('{}'+' '*(MAX_BYTES-1))
    except Refused:pass
    else:raise AssertionError('oversized')
    """

    assert {_, 0} = python(code)
  end

  @tag :tmp_dir
  test "signed URL body credential access-log and telemetry canaries stay private", %{
    tmp_dir: dir
  } do
    code = """
    from twin_receipt import safe_diagnostic, verify_receipt, Refused
    from twin_fixture import fixture
    from built_package_twin import Runner
    import contextlib,io,json,tempfile
    canaries=['https://storage.invalid/x?X-Amz-Signature=SIGNED_CANARY','SECRET_CANARY','BODY_CANARY','JOB_ERROR_CANARY']
    for channel in ['receipt','console','stderr','access_log','telemetry']:
        raw=dict(stage='services',reason='complete',dependency='none',channel=channel,body=canaries,access_log=canaries,telemetry=canaries)
        exported=json.dumps(safe_diagnostic(raw))
        assert all(c not in exported for c in canaries)
    capture=io.StringIO()
    with tempfile.TemporaryDirectory() as d, contextlib.redirect_stdout(capture), contextlib.redirect_stderr(capture):
        runner=Runner(d)
        import os
        os.environ['TWIN_PROJECT']='FOREIGN_PROJECT_CANARY'
        assert runner.command([sys.executable,'-c',"import os;print(os.environ.get('TWIN_PROJECT'))"]).strip()=='None'
        runner.command([sys.executable,'-c','print('+repr('|'.join(canaries))+')'])
        runner.progress('services')
    assert all(c not in capture.getvalue() for c in canaries)
    inputs,r=fixture();r['raw_job_error']=canaries
    try:verify_receipt(inputs,r)
    except Refused as e: assert all(c not in str(e) for c in canaries)
    else:raise AssertionError('secret-bearing record accepted')
    """

    assert {_, 0} = python(code)
    assert File.dir?(dir)
  end

  test "typed tus evidence requires a new client, exact original and derivative and bound inputs" do
    code = """
    import copy
    from twin_fixture import fixture
    from twin_receipt import verify_receipt, verify_case_receipt, Refused, TUS_SHA256, THUMB_KEY
    inputs, old = fixture()
    inputs.update(schema_version=2, scenario='tus-resume', fixture_sha256=TUS_SHA256)
    asset = old['before']['asset_id']
    source = 'elixir-twin-profile/'+asset+'/00000000-0000-4000-8000-000000000004'
    variant = 'Elixir.Twin.Profile/'+asset+'/'+THUMB_KEY
    first = dict(pid=100, create_status=201, patch_status=204, offset=32)
    second = dict(pid=200, head_status=204, head_offset=32, head_cache='no-store', wrong_status=409,
                  after_wrong_status=204, after_wrong_offset=32, patch_status=204, final_offset=69)
    result = dict(outcome='ready', session_id='00000000-0000-4000-8000-000000000005',
                  asset_id=asset, session_state='completed', asset_state='ready', source_key=source,
                  variant_keys=[variant], checksum_sha256=TUS_SHA256, sessions=1, assets=1,
                  upload_stimuli=1, offset=69, boot_id=old['old_runtime']['boot_id'])
    receipt = dict(schema_version=2, kind=old['kind'], independent_pilot_credit=False, inputs=copy.deepcopy(inputs),
                   case_id='tus-resume', outcome='complete', reason='complete', stage='complete', dependency='none',
                   clients=dict(first=first, second=second, first_exited=True, second_exited=True),
                   result=result, object_keys=sorted([source,variant]), runtime=old['old_runtime'],
                   isolation=old['isolation'],host_exited=True)
    assert verify_receipt(inputs,receipt)
    mutations=[(['inputs','run_id'],'b'*32),(['inputs','package_tar_sha256'],'b'*64),
      (['case_id'],'unknown'),(['schema_version'],1),(['clients','first_exited'],False),
      (['clients','second','pid'],100),(['clients','second','head_offset'],31),
      (['clients','second','head_status'],200),(['clients','second','wrong_status'],204),
      (['clients','second','after_wrong_offset'],33),(['clients','first','offset'],True),
      (['result','sessions'],2),(['result','assets'],2),(['result','upload_stimuli'],2),
      (['result','checksum_sha256'],'b'*64),(['result','asset_state'],'available'),
      (['result','offset'],68),(['result','source_key'],source+'extra'),
      (['result','variant_keys'],[]),(['object_keys'],[source]),(['object_keys'],[source,variant,'extra']),
      (['host_exited'],False),(['runtime','origin'],'checkout'),(['outcome'],'incomplete')]
    for path,value in mutations:
        r=copy.deepcopy(receipt); target=r
        for key in path[:-1]: target=target[key]
        target[path[-1]]=value
        try:verify_case_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError(path)
    for key in receipt:
        r=copy.deepcopy(receipt);del r[key]
        try:verify_case_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError('missing '+key)
    for field in ['raw_body','signature','job_error','pubsub','signed_url']:
        r=copy.deepcopy(receipt);r[field]='SECRET_CANARY'
        try:verify_receipt(inputs,r)
        except Refused as e: assert 'SECRET_CANARY' not in str(e)
        else:raise AssertionError(field)
    legacy_inputs, legacy = fixture()
    assert verify_receipt(legacy_inputs,legacy)
    try:verify_case_receipt(legacy_inputs,legacy)
    except Refused:pass
    else:raise AssertionError('legacy counted as matrix case')
    """

    assert {_, 0} = python(code)
  end

  test "purge case rejects denial, substituted job identity, repeated stimulus and residue" do
    code = """
    import copy
    from twin_fixture import fixture
    from twin_receipt import verify_receipt, Refused
    inputs,legacy=fixture(); inputs.update(schema_version=2,scenario='purge-absence')
    before,after,inventory = [copy.deepcopy(legacy[k]) for k in ['before','after','inventory']]
    after.update(boot_id=before['boot_id'], sequence=3); inventory['sequence']=4
    absence=dict(source_key=before['source_key'], asset_id=before['asset_id'], job_id=before['job_id'],
                 head='not_found', asset_retained=True, paused=True, running=0, state='retryable',
                 attempt=1,error_count=1,sequence=2)
    receipt=dict(schema_version=2,kind=legacy['kind'],independent_pilot_credit=False,inputs=copy.deepcopy(inputs),
                 case_id='purge-absence',outcome='complete',reason='complete',stage='complete',dependency='none',
                 before=before,absence=absence,after=after,inventory=inventory,runtime=legacy['old_runtime'],
                 isolation=legacy['isolation'],host_exited=True)
    assert verify_receipt(inputs,receipt)
    mutations=[(['before','error_count'],0),(['after','job_id'],9),(['after','attempt'],1),
      (['absence','head'],'denied'),(['absence','head'],'unknown'),(['absence','source_key'],'foreign'),
      (['absence','asset_id'],'00000000-0000-4000-8000-000000000009'),(['absence','job_id'],9),
      (['absence','paused'],False),(['absence','running'],1),(['absence','attempt'],2),
      (['absence','error_count'],0),(['absence','sequence'],1),(['before','stimuli','detach'],2),
      (['inventory','objects'],1),(['inventory','domain','media_assets'],1),(['inventory','listing_complete'],False),
      (['inventory','writers_paused'],False),(['inventory','jobs',2,'id'],9),(['inventory','temp_files'],1),
      (['inventory','multipart'],1),(['after','asset_absent'],False)]
    for path,value in mutations:
        r=copy.deepcopy(receipt);target=r
        for key in path[:-1]:target=target[key]
        target[path[-1]]=value
        try:verify_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError(path)
    for key in ['absence','before','after','inventory']:
        r=copy.deepcopy(receipt);del r[key]
        try:verify_receipt(inputs,r)
        except Refused:pass
        else:raise AssertionError(key)
    """

    assert {_, 0} = python(code)
  end
end
