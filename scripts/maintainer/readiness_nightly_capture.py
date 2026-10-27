"""Explicit, bounded Nightly dispatch owner. Read-only collectors never dispatch."""
import argparse
from pathlib import Path
import subprocess
import re

from exact_head_readiness import NotReady, canonical, now, require, write_new
from readiness_github import GitHub, json_bytes
from readiness_retention import reserve
from readiness_subject import main_sha, observe


def dispatch(api, output, sequence):
    # POST is never retried. A missing/ambiguous response is an owned unknown run,
    # not permission to duplicate an expensive execution. This API returns its ID.
    result=subprocess.run(['gh','api','--hostname','github.com','--method','POST',
        '-H','X-GitHub-Api-Version: 2026-03-10',api.path('actions/workflows/nightly.yml/dispatches'),
        '--input','-'],input=canonical({'ref':'main'}),capture_output=True,timeout=35,check=False)
    write_new(output/'restricted'/f'dispatch-{sequence}.log',result.stdout+result.stderr)
    require(result.returncode==0,'nightly_dispatch_unknown')
    value=json_bytes(result.stdout)
    require(isinstance(value,dict),'nightly_dispatch_unknown')
    id=value.get('workflow_run_id')
    require(type(id) is int and id>0 and value.get('run_url')=='https://api.github.com/'+api.path('actions/runs/'+str(id)) and
        value.get('html_url')=='https://github.com/'+api.repo+'/actions/runs/'+str(id),'nightly_dispatch_unknown')
    return id


def capture(repo, output, fixture=None):
    output=reserve(output)
    verdict={'schema':'rindle-nightly-capture-v1','repository':repo,'policy':'rindle-snapshot-v3',
        'requirements_credit':False,'verdict':'not_ready','started_at':now(),'attempts':[]}
    try:
        api=GitHub(repo,output/'restricted/api',fixture,budget=180)
        workflow,_=api.get(api.path('actions/workflows/nightly.yml'))
        require(workflow.get('state')=='active' and workflow.get('name')=='Nightly' and
            workflow.get('path')=='.github/workflows/nightly.yml','nightly_workflow_identity')
        for sequence in range(1,4):
            subject=main_sha(api);binding=observe(api,subject)
            write_new(output/f'subject-{sequence}.json',binding)
            # Fixtures can supply a dispatch seam only through an explicit test patch.
            require(fixture is None,'fixture_dispatch_forbidden')
            id=dispatch(api,output,sequence)
            verdict['attempts'].append({'selected_subject_sha':subject,'run_id':id})
            write_new(output/f'owned-run-{sequence}.json',verdict['attempts'][-1])
            run,_=api.get(api.path('actions/runs/'+str(id)))
            require(run.get('id')==id and run.get('repository',{}).get('full_name')==repo and
                run.get('workflow_id')==workflow.get('id') and run.get('name')=='Nightly' and
                run.get('path')==workflow['path'] and run.get('event')=='workflow_dispatch' and
                run.get('head_branch')=='main' and run.get('run_attempt')==1 and
                re.fullmatch(r'[0-9a-f]{40}',run.get('head_sha','')),'nightly_capture_identity')
            write_new(output/f'run-{sequence}.json',run)
            if run['head_sha']!=subject:continue
            # Pinned workflow uses implicit same-source checkout. observe authenticates
            # these controller bytes and full push-main provenance at the actual head.
            observe(api,subject)
            verdict.update(verdict='captured',reason='nightly_source_captured',subject_sha=subject,
                run_id=id,run_attempt=1,url=run['html_url'])
            break
        else:raise NotReady('nightly_capture_raced')
    except (NotReady,OSError,ValueError,subprocess.TimeoutExpired) as exc:
        verdict['reason']=str(exc) if isinstance(exc,NotReady) else 'nightly_dispatch_unknown'
    verdict['completed_at']=now();write_new(output/'capture.json',verdict)
    print(verdict['verdict']+': '+verdict['reason'])
    return 0 if verdict['verdict']=='captured' else 1


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',required=True);parser.add_argument('--output',required=True)
    args=parser.parse_args(argv)
    return capture(args.repo,Path(args.output))
