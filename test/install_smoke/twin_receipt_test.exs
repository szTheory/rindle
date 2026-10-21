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
end
