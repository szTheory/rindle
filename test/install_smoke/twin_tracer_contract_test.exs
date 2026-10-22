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

  test "promotion cut requires an available untouched job and a quiescent queue" do
    queue = %{paused: true, running: []}
    job = %{state: "available", attempt: 0}
    assert Twin.Tracer.promotion_barrier?(queue, job)
    refute Twin.Tracer.promotion_barrier?(queue, %{job | state: "executing"})
    refute Twin.Tracer.promotion_barrier?(queue, %{job | state: "retryable", attempt: 1})
    refute Twin.Tracer.promotion_barrier?(queue, %{job | attempt: 1})
    refute Twin.Tracer.promotion_barrier?(%{queue | running: [42]}, job)
    refute Twin.Tracer.promotion_barrier?(%{queue | paused: false}, job)
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

  test "tus client boundary rejects same process and offset advancement" do
    code = """
    import sys, copy
    sys.path.insert(0, 'scripts/maintainer')
    from built_package_twin import validate_tus_clients, Refused
    first = dict(pid=101, create_status=201, patch_status=204, offset=32)
    second = dict(pid=202, head_status=204, head_offset=32, head_cache='no-store', wrong_status=409,
                  after_wrong_status=204, after_wrong_offset=32, patch_status=204, final_offset=69)
    validate_tus_clients(first, second, 69)
    for change in [dict(pid=101), dict(head_offset=0), dict(wrong_status=204),
                   dict(after_wrong_offset=33), dict(final_offset=68), dict(head_cache='max-age=5')]:
        try: validate_tus_clients(first, dict(second, **change), 69)
        except Refused: pass
        else: raise AssertionError(change)
    """

    assert {_, 0} = System.cmd("python3", ["-B", "-c", code], cd: @root, stderr_to_stdout: true)
  end
end
