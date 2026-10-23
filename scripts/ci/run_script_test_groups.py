#!/usr/bin/env python3
"""Run bounded independent CI harness groups; await all and preserve every failure."""
import json
import os
from pathlib import Path
import shutil
import signal
import sys
import tempfile
import time

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts/maintainer'))
from readiness_process import popen_owned, stop_owned


def run(groups,output,budget=240):
    if not 2<=len(groups)<=3:raise ValueError('two or three CI harness groups required')
    output=Path(output);output.mkdir(mode=0o700)
    children=[];streams=[];results=[];deadline=time.monotonic()+budget;failed=False
    handlers={sig:signal.getsignal(sig) for sig in (signal.SIGINT,signal.SIGTERM)}
    def interrupt(_sig,_frame):raise InterruptedError('CI harness groups interrupted')
    try:
        for sig in handlers:signal.signal(sig,interrupt)
        for position,(name,argv) in enumerate(groups):
            stream=open(output/f'group-{position}.log','xb',buffering=0,opener=lambda p,f:os.open(p,f,0o600));streams.append(stream)
            children.append((name,popen_owned(argv,cwd=ROOT,stdout=stream,stderr=-2)))
        while any(child.poll() is None for _,child in children):
            if time.monotonic()>=deadline or any(stream.tell()>32_000_000 for stream in streams):
                raise TimeoutError('CI harness group budget exhausted')
            time.sleep(.05)
        results=[{'name':name,'exit_code':child.returncode} for name,child in children]
        failed=any(row['exit_code']!=0 for row in results)
    except (InterruptedError,TimeoutError,OSError) as exc:
        failed=True;results.append({'reason':str(exc)})
    finally:
        for _,child in children:
            if child.poll() is None:stop_owned(child,5)
        for sig,handler in handlers.items():signal.signal(sig,handler)
        for stream in streams:stream.close()
    for position,(name,_argv) in enumerate(groups):
        print('::group::'+name,flush=True)
        path=output/f'group-{position}.log'
        if path.is_file():
            with open(path,'rb') as source:shutil.copyfileobj(source,sys.stdout.buffer)
        print('::endgroup::',flush=True)
    print(json.dumps({'groups':results,'exit_code':int(failed),'requirements_credit':False}),flush=True)
    (output/'results.json').write_text(json.dumps({'groups':results,'exit_code':int(failed),'requirements_credit':False})+'\n')
    return int(failed)


def workflow_groups(script):
    # The incident replay harness is independent of the other fixture repositories.
    # Keep its exact workflow command, but remove it from their serial critical path.
    incident='bash scripts/ci/test_nightly_incident.sh'
    lines=script.splitlines()
    if lines.count(incident)!=1:raise ValueError('exactly one Nightly incident harness command required')
    legacy='\n'.join(line for line in lines if line!=incident)
    return [('Existing CI contract harnesses',['bash','-euo','pipefail','-c',legacy]),
            ('Nightly incident contract harness',['bash','scripts/ci/test_nightly_incident.sh']),
            ('Exact-head readiness fixtures',['bash','scripts/ci/test_readiness_fixtures.sh'])]


def main():
    script=sys.stdin.read(16_385)
    if not script.strip() or len(script)>16_384:raise SystemExit('missing or oversized trusted CI harness script')
    parent=Path(os.environ.get('RUNNER_TEMP',tempfile.gettempdir()))
    output=parent/('rindle-script-groups-'+os.urandom(8).hex())
    return run(workflow_groups(script),output)

if __name__=='__main__':raise SystemExit(main())
