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
    children=[];streams=[];results=[];completed={};reason=None;deadline=time.monotonic()+budget;failed=False
    handlers={sig:signal.getsignal(sig) for sig in (signal.SIGINT,signal.SIGTERM)}
    def interrupt(_sig,_frame):raise InterruptedError('CI harness groups interrupted')
    try:
        for sig in handlers:signal.signal(sig,interrupt)
        for position,(name,argv) in enumerate(groups):
            stream=open(output/f'group-{position}.log','xb',buffering=0,opener=lambda p,f:os.open(p,f,0o600));streams.append(stream)
            children.append((name,popen_owned(argv,cwd=ROOT,stdout=stream,stderr=-2),time.monotonic()))
        while True:
            for _,child,_ in children:
                if child.poll() is not None:completed.setdefault(child.pid,time.monotonic())
            if len(completed)==len(children):break
            if time.monotonic()>=deadline or any(stream.tell()>32_000_000 for stream in streams):
                raise TimeoutError('CI harness group budget exhausted')
            time.sleep(.05)
        failed=any(child.returncode!=0 for _,child,_ in children)
    except (InterruptedError,TimeoutError,OSError) as exc:
        failed=True;reason=str(exc)
    finally:
        for name,child,started in children:
            ended=completed.get(child.pid,time.monotonic());terminated=child.poll() is None
            if terminated:stop_owned(child,5)
            results.append({'name':name,'exit_code':child.returncode,
                            'state':'terminated' if terminated else 'completed',
                            'elapsed_seconds':round(ended-started,3)})
        for sig,handler in handlers.items():signal.signal(sig,handler)
        for stream in streams:stream.close()
    if reason is not None:results.append({'reason':reason})
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
    # These harnesses own independent fixture repositories. Balance the existing
    # three groups without changing their shared deadline or dropping commands.
    incident='bash scripts/ci/test_nightly_incident.sh'
    baseline='python3 scripts/ci/test_land_release_train_baseline.py'
    inbox=('bash scripts/ci/test_validate_inbox_ledger.sh',
           'bash scripts/ci/test_dep_landing_evidence.sh')
    lines=script.splitlines()
    independent=(incident,*inbox)
    # Collection stays with legacy: incident+collection+ledger+landing exhausted
    # the shared deadline while both other groups had already completed.
    for command in (*independent,baseline,'bash scripts/ci/test_collect_inbox.sh'):
        if lines.count(command)!=1:raise ValueError('exactly one independent harness command required: '+command)
    legacy='\n'.join(line for line in lines if line not in independent)
    isolated='\n'.join(line for line in lines if line in independent)
    # Live CI measured readiness at 237s, legacy at 218s and incident at 220s.
    # Keep the independent 11s baseline in legacy, rather than serializing it
    # behind readiness. Preserve all commands, three workers and the 240s bound.
    readiness='bash scripts/ci/test_readiness_fixtures.sh'
    return [('Existing CI contract harnesses',['bash','-euo','pipefail','-c',legacy]),
            ('Incident and inbox contracts',['bash','-euo','pipefail','-c',isolated]),
            ('Readiness contracts',['bash','-euo','pipefail','-c',readiness])]


def main():
    script=sys.stdin.read(16_385)
    if not script.strip() or len(script)>16_384:raise SystemExit('missing or oversized trusted CI harness script')
    parent=Path(os.environ.get('RUNNER_TEMP',tempfile.gettempdir()))
    output=parent/('rindle-script-groups-'+os.urandom(8).hex())
    return run(workflow_groups(script),output)

if __name__=='__main__':raise SystemExit(main())
