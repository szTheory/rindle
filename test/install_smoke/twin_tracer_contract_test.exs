Code.require_file("../twin/host/lib/twin/repo.ex", __DIR__)
Code.require_file("../twin/host/lib/twin/storage.ex", __DIR__)
Code.require_file("../twin/host/lib/twin/tracer.ex", __DIR__)

defmodule Rindle.TwinTracerContractTest do
  use ExUnit.Case, async: true
  @root Path.expand("../..", __DIR__)
  test "pause barrier rejects races and noncanonical attempts" do
    code = """
    import sys
    sys.path.insert(0, 'scripts/maintainer')
    from built_package_twin import barrier_ok
    q = {'paused': True, 'running': 0}
    j = {'state': 'retryable', 'attempt': 1, 'error_count': 1}
    assert barrier_ok(q, j)
    for change in [{'state':'executing'}, {'attempt':2}, {'attempt':True}, {'error_count':0}]:
        assert not barrier_ok(q, dict(j, **change))
    assert not barrier_ok({'paused':True, 'running':1}, j)
    assert not barrier_ok({'paused':False, 'running':0}, j)
    """

    assert {_, 0} = System.cmd("python3", ["-B", "-c", code], cd: @root, stderr_to_stdout: true)
  end

  test "host pause predicate rejects a state changed after pause acknowledgement" do
    queue = %{paused: true, running: []}
    job = %{state: "retryable", attempt: 1, errors: [%{}]}
    assert Twin.Tracer.barrier?(queue, job)
    refute Twin.Tracer.barrier?(queue, %{job | state: "executing"})
    refute Twin.Tracer.barrier?(queue, %{job | attempt: 2})
    refute Twin.Tracer.barrier?(%{queue | running: [42]}, job)
  end

  test "duplicate stimulus cannot verify as one lifecycle" do
    code = """
    import sys
    sys.path.insert(0, 'scripts/maintainer')
    from built_package_twin import verify_receipt, Refused, SCENARIO
    sys.path.insert(0, 'test/install_smoke/support')
    from twin_fixture import fixture
    inputs,r=fixture()
    r['before']['stimuli']['detach']=2
    try:
        verify_receipt(inputs, r)
    except Refused as e:
        assert str(e) == 'integer_bounds'
    else:
        raise AssertionError('duplicate accepted')
    """

    assert {_, 0} = System.cmd("python3", ["-B", "-c", code], cd: @root, stderr_to_stdout: true)
  end

  test "verification requires separate inputs authority and no default container run" do
    assert {output, 2} =
             System.cmd("python3", ["-B", "scripts/maintainer/built_package_twin.py", "verify"],
               cd: @root,
               stderr_to_stdout: true
             )

    assert output =~ "--inputs"
  end
end
