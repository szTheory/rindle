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

end
