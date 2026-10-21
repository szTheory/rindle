defmodule Rindle.TwinPackageBoundaryTest do
  use ExUnit.Case, async: true
  @root Path.expand("../..", __DIR__)
  test "archive and dependency contaminants cannot enter the isolated host" do
    code = """
    import sys, io, tarfile, tempfile
    from pathlib import Path
    sys.path.insert(0, 'scripts/maintainer')
    from built_package_twin import extract_tar, validate_package_files, validate_host_dependency, Refused
    def refused(f):
        try: f()
        except Refused: return
        raise AssertionError('contamination accepted')
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
