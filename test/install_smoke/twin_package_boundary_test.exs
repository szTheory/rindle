defmodule Rindle.TwinPackageBoundaryTest do
  use ExUnit.Case, async: true
  @root Path.expand("../..", __DIR__)
  test "archive and dependency contaminants cannot enter the isolated host" do
    code = """
    import sys, io, tarfile, tempfile
    from pathlib import Path
    sys.path.insert(0, 'scripts/maintainer')
    from built_package_twin import extract_tar, validate_package_files, validate_host_dependency, Refused, LIMIT
    import gzip
    def refused(f):
        try: f()
        except Refused: return
        raise AssertionError('contamination accepted')
    with tempfile.TemporaryDirectory() as d:
        refused(lambda:extract_tar(gzip.compress(b"x"*(16*LIMIT+1)),Path(d),compressed=True))
    for name,kind in [('../escape',tarfile.REGTYPE),('/absolute',tarfile.REGTYPE),('link',tarfile.SYMTYPE),('device',tarfile.CHRTYPE)]:
        b=io.BytesIO()
        with tarfile.open(fileobj=b,mode='w') as t:
            m=tarfile.TarInfo(name);m.type=kind;m.linkname='/tmp/foreign';t.addfile(m)
        with tempfile.TemporaryDirectory() as d: refused(lambda:extract_tar(b.getvalue(),Path(d)))
    with tempfile.TemporaryDirectory() as d:
        p=Path(d);(p/'mix.exs').write_text('project')
        validate_package_files(p)
        for path in ['lib/foreign.beam','_build/output','deps/rindle/lib.ex','.git/config']:
            f=p/path;f.parent.mkdir(parents=True,exist_ok=True);f.write_text('foreign')
            refused(lambda:validate_package_files(p));f.unlink()
    validate_host_dependency('{:rindle, path: "../package"}')
    for s in ['{:rindle, path: "/checkout"}','{:rindle, "0.4.10"}','{:rindle, git: "remote"}']:
        refused(lambda:validate_host_dependency(s))
    """

    assert {_, 0} = System.cmd("python3", ["-B", "-c", code], cd: @root, stderr_to_stdout: true)
  end

  test "effective mounts and effective capabilities fail closed" do
    code = """
    import sys,copy
    sys.path.insert(0, 'scripts/maintainer')
    from built_package_twin import validate_mounts, validate_runtime, Refused
    def refused(f):
        try:f()
        except Refused:return
        raise AssertionError('invalid capability accepted')
    good=[{'type':'volume','source':'retained','target':'/retained'}]
    validate_mounts(good)
    for target in ['/checkout','/home/user','/var/run/docker.sock']:
        refused(lambda:validate_mounts([{'type':'bind','source':target,'target':target}]))
    expected={'elixir':'1.17.3','otp':'27.3.4.15','oban':'2.21.1','phoenix':'1.8.12'}
    health=dict(expected,lock_sha256='a'*64,origin='/twin/_build/prod/lib/rindle/ebin/Elixir.Rindle.beam')
    validate_runtime(health,{'toolchain':expected,'lock_sha256':'a'*64})
    for key in expected:
        wrong=dict(health);wrong[key]='0.0.0';refused(lambda:validate_runtime(wrong,{'toolchain':expected,'lock_sha256':'a'*64}))
    for key,value in [('lock_sha256','b'*64),('origin','/checkout/_build/Elixir.Rindle.beam')]:
        wrong=dict(health);wrong[key]=value;refused(lambda:validate_runtime(wrong,{'toolchain':expected,'lock_sha256':'a'*64}))
    """

    assert {_, 0} = System.cmd("python3", ["-B", "-c", code], cd: @root, stderr_to_stdout: true)
  end

  test "archive byte, metadata and extracted-tree identities cannot substitute for one another" do
    code = """
    import sys,io,tarfile,gzip,tempfile
    from pathlib import Path
    sys.path.insert(0,'scripts/maintainer')
    from built_package_twin import archive_identity,validate_archive,Refused
    def tar(entries):
        out=io.BytesIO()
        with tarfile.open(fileobj=out,mode='w') as t:
            for name,data in entries:
                m=tarfile.TarInfo(name);m.size=len(data);t.addfile(m,io.BytesIO(data))
        return out.getvalue()
    inner=gzip.compress(tar([('mix.exs',b'project')]))
    raw=tar([('VERSION',b'3'),('CHECKSUM',b'checksum'),('metadata.config',b'metadata'),('contents.tar.gz',inner)])
    with tempfile.TemporaryDirectory() as d:
        p=Path(d)/'package.tar';p.write_bytes(raw);expected=archive_identity(p)
        assert len(set(expected.values()))==3
        validate_archive(p,expected)
        for field in expected:
            wrong=dict(expected);wrong[field]='0'*64
            try:validate_archive(p,wrong)
            except Refused:pass
            else:raise AssertionError('foreign digest accepted')
        p.write_bytes(raw+b'changed')
        try:validate_archive(p,expected)
        except Refused:pass
        else:raise AssertionError('changed tar bytes accepted')
    """

    assert {_, 0} = System.cmd("python3", ["-B", "-c", code], cd: @root, stderr_to_stdout: true)
  end
end
