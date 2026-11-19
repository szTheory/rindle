#!/usr/bin/env python3
"""Merged-main controller and byte-bound historical/current claim inspection."""
import argparse
import datetime as dt
import os
from pathlib import Path
import re
import secrets
import subprocess
import time

from exact_head_readiness import ROOT, NotReady, atomic, canonical, digest, now, read_json, reference, require, write_new
from readiness_adoption import check as adoption_check
from readiness_closure import Closure, object_bytes
from readiness_github import GitHub
from readiness_retention import WORKFLOW, WORKFLOW_NAME, durable_path, graph_objects, retrieve, reserve, workflow_identity
from readiness_subject import LEGACY_POLICY as LEGACY_SNAPSHOT_POLICY, POLICY as SNAPSHOT_POLICY
from collect_readiness_runs import LEGACY_POLICY as LEGACY_READINESS_POLICY, POLICY as READINESS_POLICY

SNAPSHOT_TERMINALS = {'rindle-snapshot-terminal-v3': LEGACY_SNAPSHOT_POLICY,
                      'rindle-snapshot-terminal-v4': SNAPSHOT_POLICY}
EXACT_HEAD_TERMINALS = {'rindle-exact-head-terminal-v1': LEGACY_READINESS_POLICY,
                        'rindle-exact-head-terminal-v2': READINESS_POLICY}

PHASE='.planning/phases/139-exact-head-readiness-closure'
RELOCATED_PHASE_FILES={f'{PHASE}/139-preflight.sh':'.planning/evidence/runtime/139-preflight.sh'}


def phase_inventory_path(root, relative):
    relocated=RELOCATED_PHASE_FILES.get(relative)
    if relocated is not None and not (root/relative).is_file():return relocated
    return relative


def git(root,*args):
    result=subprocess.run(['git',*args],cwd=root,capture_output=True,timeout=20)
    require(result.returncode==0,'subject_git_unavailable');return result.stdout


def main_sha(api):
    value,_=api.get(api.path('git/ref/heads/main'))
    require(value.get('ref')=='refs/heads/main' and value.get('object',{}).get('type')=='commit' and
        re.fullmatch(r'[0-9a-f]{40}',value.get('object',{}).get('sha','')),'main_unavailable')
    return value['object']['sha']


def declared_files(root=ROOT):
    paths=set(git(root,'ls-files','-z','--',PHASE).decode().split('\0'))-{''}
    paths.update({'RUNNING.md','.github/workflows/ci.yml',WORKFLOW,'scripts/maintainer/exact_head_readiness.sh',
        phase_inventory_path(root,f'{PHASE}/139-preflight.sh')})
    for n in range(8):
        relative=f'{PHASE}/139-{n:02d}-PLAN.md';paths.add(relative);path=root/relative
        require(path.is_file() and not path.is_symlink(),'phase_inventory_missing')
        text=path.read_text();match=re.search(r'(?ms)^files_modified:\s*\n((?:  - [^\n]+\n)+)',text)
        if match:
            for line in match[1].splitlines():
                declared=line[4:].strip()
                paths.add(phase_inventory_path(root,declared))
    require(all(p and not p.startswith('/') and all(c not in ('','.','..') for c in p.split('/')) for p in paths),'phase_inventory_invalid')
    return sorted(paths)


def verify_subject(api,repo,root=ROOT,subject=None,snapshot=False,snapshot_policy=None):
    binding=None
    if snapshot:
        from readiness_subject import LEGACY_POLICY, POLICY as CURRENT_SNAPSHOT_POLICY, observe
        snapshot_policy=snapshot_policy or CURRENT_SNAPSHOT_POLICY
        require(snapshot_policy in (LEGACY_POLICY,CURRENT_SNAPSHOT_POLICY),'snapshot_policy_unsupported')
        binding=observe(api,subject,root,policy=snapshot_policy)
    else:subject=main_sha(api)
    require(git(root,'rev-parse','HEAD').decode().strip()==subject,'closing_subject_not_checked_out')
    require(not git(root,'status','--porcelain','--untracked-files=all').strip(),'dirty_closing_checkout')
    inventory={}
    for relative in declared_files(root):
        data=git(root,'show',subject+':'+relative);path=root/relative
        require(path.is_file() and not path.is_symlink() and path.read_bytes()==data,'phase_inventory_missing')
        inventory[relative]=digest(data)
    if not snapshot:require(main_sha(api)==subject,'main_changed')
    record={'schema':'rindle-readiness-merged-subject-v1','repository':repo,'subject_sha':subject,
        'tracked_inventory':inventory,'observed_at':now(),'requirements_credit':False}
    if snapshot:
        checkout_schema='rindle-readiness-snapshot-checkout-v3' if binding['schema'].endswith('-v3') else 'rindle-readiness-snapshot-checkout-v4'
        record.update(schema=checkout_schema,snapshot_binding=binding)
    return record


HISTORICAL_TIMESTAMP = r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z'


def historical_completion_line(line,subject=None,interval=None):
    timestamps=re.findall(HISTORICAL_TIMESTAMP,line)
    qualified=('historical' in line.lower() and
        re.search(r'(?<![0-9a-f])[0-9a-f]{40}(?![0-9a-f])',line) is not None and
        len(timestamps)>=2 and re.search(r'terminal[-_ ]verdict|locator',line,re.I) is not None)
    if subject is not None:
        qualified=qualified and subject in line and interval is not None and all(v in line for v in interval.values())
    return qualified


def historical_phase_summary(text,subject=None,interval=None):
    """Require Plan 07's own historical receipt identity, not the run refreshing it."""
    qualified=all((
        re.search(r'(?im)^status:\s*complete\s*$',text),
        re.search(r'(?im)^evidence_scope:\s*historical\s*$',text),
        re.search(r'(?im)^accepted_subject_sha:\s*["\']?[0-9a-f]{40}["\']?\s*$',text),
        re.search(rf'(?im)^\s*started_at:\s*["\']?{HISTORICAL_TIMESTAMP}["\']?\s*$',text),
        re.search(rf'(?im)^\s*completed_at:\s*["\']?{HISTORICAL_TIMESTAMP}["\']?\s*$',text),
        re.search(r'(?im)^terminal_verdict:\s*.*(?:terminal-verdict|locator)',text)))
    if subject is not None:
        qualified=qualified and subject in text and interval is not None and all(v in text for v in interval.values())
    return qualified


def metadata_paths(root):
    return [root/'.planning/REQUIREMENTS.md',root/'.planning/ROADMAP.md',root/'.planning/STATE.md',
            *sorted((root/PHASE).glob('*SUMMARY.md'))]


def metadata_preflight(root):
    """Reject unqualified claims while preserving already accepted historical records.

    The acceptance interval is produced by this invocation, so existing historical
    completion records cannot be required to name it before the terminal verdict is
    written. Before terminalization, existing records must carry their own historical
    SHA, interval and locator. Claim-status remains strict through metadata_parity.
    """
    paths=metadata_paths(root)
    summary_path=root/PHASE/'139-07-SUMMARY.md'
    summary_text=summary_path.read_text() if summary_path.is_file() else ''
    phase_summary_qualified=historical_phase_summary(summary_text)
    for path in paths:
        if not path.is_file():continue
        text=path.read_text()
        # Scope to completion/readiness assertions, not negative policy prose.
        for line in text.splitlines():
            current_ready=bool(re.search(r'(?i)(?:current[- ]head|current[- ]main) readiness\s*(?:is|:)\s*(?:ready|complete|passed)',line))
            ready_complete=bool(re.search(r'(?i)(?:\[[xX]\].*READY-0[1-5]|READY-0[1-5].*\|\s*Complete\b)',line))
            if current_ready:raise NotReady('unqualified_readiness_metadata')
            if ready_complete:
                require(historical_completion_line(line),'unqualified_readiness_metadata')
            if path.name=='139-07-SUMMARY.md' and re.search(r'(?im)^status:\s*complete\s*$',text):
                require(phase_summary_qualified,'unqualified_readiness_metadata')
            phase_roadmap_complete=path.name=='ROADMAP.md' and re.search(r'(?i)\bPhase\s*139\b',line) and re.search(r'\[[xX]\]|\|\s*Complete\b|:\s*Complete\b',line,re.I)
            phase_state_complete=path.name=='STATE.md' and re.search(r'(?i)\bPhase\s*139\b.*\bComplete\b',line)
            if phase_roadmap_complete or phase_state_complete:
                require(phase_summary_qualified,'unqualified_readiness_metadata')


def metadata_parity(root,subject,interval):
    """Bind published readiness claims to the exact historical terminal record."""
    metadata_preflight(root)
    for path in metadata_paths(root):
        if not path.is_file():continue
        text=path.read_text()
        for line in text.splitlines():
            ready_complete=bool(re.search(r'(?i)(?:\[[xX]\].*READY-0[1-5]|READY-0[1-5].*\|\s*Complete\b)',line))
            if ready_complete:
                require(historical_completion_line(line,subject,interval),'unqualified_readiness_metadata')
        phase_complete=path.name in ('ROADMAP.md','STATE.md') and any(
            (path.name=='ROADMAP.md' and re.search(r'(?i)\bPhase\s*139\b',line) and re.search(r'\[[xX]\]|\|\s*Complete\b|:\s*Complete\b',line,re.I)) or
            (path.name=='STATE.md' and re.search(r'(?i)\bPhase\s*139\b.*\bComplete\b',line))
            for line in text.splitlines())
        if (path.name=='139-07-SUMMARY.md' and re.search(r'(?im)^status:\s*complete\s*$',text)) or phase_complete:
            require(historical_phase_summary(text if path.name=='139-07-SUMMARY.md' else
                (root/PHASE/'139-07-SUMMARY.md').read_text() if (root/PHASE/'139-07-SUMMARY.md').is_file() else '',
                subject,interval),'unqualified_readiness_metadata')


class Acceptance:
    def __init__(self,repo,output,fixture=None,wait=19800,subject=None,snapshot=False,snapshot_policy=None,readiness_policy=None):
        from readiness_subject import LEGACY_POLICY, POLICY as CURRENT_SNAPSHOT_POLICY
        self.candidate=subject;self.snapshot=snapshot
        self.snapshot_policy=(snapshot_policy or CURRENT_SNAPSHOT_POLICY) if snapshot else None
        require(not snapshot or self.snapshot_policy in (LEGACY_POLICY,CURRENT_SNAPSHOT_POLICY),'snapshot_policy_unsupported')
        self.readiness_policy=(readiness_policy or READINESS_POLICY) if not snapshot else None
        require(snapshot or self.readiness_policy in (LEGACY_READINESS_POLICY,READINESS_POLICY),'readiness_policy_unsupported')
        self.repo=repo;self.output=Path(output).resolve();self.fixture=fixture
        self.mode='fixture' if fixture is not None else 'execution';self.wait=wait
        self.started=now();self.subject=None;self.reserved=False
    def setup(self,durable=True):
        if durable:durable_path(self.output,self.fixture)
        reserve(self.output);self.reserved=True;self.api=GitHub(self.repo,self.output/'restricted/api',self.fixture,budget=self.wait+900,max_calls=3000)
    def subject_record(self):
        return verify_subject(self.api,self.repo,subject=self.candidate,snapshot=True,snapshot_policy=self.snapshot_policy) if self.snapshot else verify_subject(self.api,self.repo)
    def dispatch(self,nonce):
        require(self.fixture is None,'fixture_dispatch_forbidden')
        payload=canonical({'ref':'main','inputs':{'expected_subject':self.subject,'request_id':nonce,
            'acceptance_mode':'snapshot' if self.snapshot else 'current-main'}})
        result=subprocess.run(['gh','api','--hostname','github.com','--method','POST',
            self.api.path('actions/workflows/readiness-retention.yml/dispatches'),'--input','-'],input=payload,capture_output=True,timeout=35)
        write_new(self.output/'restricted/dispatch.log',result.stdout+result.stderr)
        require(result.returncode==0,'producer_dispatch_failed')
    def producer(self,nonce):
        workflow=workflow_identity(self.api)
        deadline=time.monotonic()+self.wait
        while time.monotonic()<deadline:
            if not self.snapshot:require(main_sha(self.api)==self.subject,'main_changed')
            runs=self.api.pages('actions/workflows/readiness-retention.yml/runs?event=workflow_dispatch&branch=main'+
                ('' if self.snapshot else '&head_sha='+self.subject)+'&per_page=100','workflow_runs',cap=1000)
            found=[r for r in runs if r.get('display_title')=='Readiness '+nonce]
            require(len(found)<=1,'producer_request_ambiguous')
            if found:
                run=found[0]
                require((self.snapshot or run.get('head_sha')==self.subject) and re.fullmatch(r'[0-9a-f]{40}',run.get('head_sha','')) and run.get('path')==WORKFLOW and type(run.get('workflow_id')) is int and run.get('workflow_id')==workflow and run.get('repository',{}).get('full_name')==self.repo and
                    run.get('head_branch')=='main' and run.get('event')=='workflow_dispatch' and
                    type(run.get('id')) is int and type(run.get('run_attempt')) is int and run['run_attempt']==1,'producer_request_identity')
                if run.get('status')=='completed':
                    require(run.get('conclusion')=='success','producer_failed');return run['id'],run['run_attempt']
            if self.fixture is not None:raise NotReady('producer_pending')
            time.sleep(min(30,max(0,deadline-time.monotonic())))
        raise NotReady('producer_wait_timeout')
    def refresh(self,manifest,output):
        owner=Closure(self.repo,output,manifest,self.fixture,subject=self.subject,snapshot=self.snapshot,
            snapshot_policy=self.snapshot_policy,readiness_policy=self.readiness_policy)
        require(owner.run()==0,'mutable_refresh_not_ready')
        value=read_json(output/'verdict.json');require(value.get('verdict')=='candidate_ready','mutable_refresh_not_ready')
        return value
    def adoption(self,manifest):
        if not self.snapshot:return adoption_check(ROOT,manifest['adoption'])
        from readiness_adoption import INPUTS,check_bytes
        from readiness_subject import current_authority
        _,raw=current_authority(self.api,INPUTS)
        return check_bytes(raw,manifest['adoption'])
    def run(self):
        try:
            self.setup();atomic(self.output/'attempt.json',{'verdict':'not_ready','reason':'collecting','requirements_credit':False})
            record=self.subject_record();self.subject=record['subject_sha'];write_new(self.output/'subject.json',record)
            nonce=secrets.token_hex(16);write_new(self.output/'producer-request.json',{'request_id':nonce,'subject_sha':self.subject,'requested_at':now()})
            self.dispatch(nonce);run,attempt=self.producer(nonce)
            locator=retrieve(self.repo,run,attempt,self.output/'durable',self.fixture)
            require(locator['subject_sha']==self.subject and locator['evidence_mode']==self.mode and locator['bytes_verified'] is True and
                locator['storage_scope']==('fixture_only' if self.fixture is not None else 'durable_maintainer_host'),'durable_subject_or_mode')
            manifest_path=self.output/'durable/bundle/manifest.json';manifest=read_json(manifest_path)
            expected_policy=self.snapshot_policy if self.snapshot else self.readiness_policy
            require(manifest.get('policy')==expected_policy,'acceptance_policy_mismatch')
            self.adoption(manifest)
            self.refresh(manifest_path,self.output/'refresh')
            require((self.output/'refresh/portable/manifest.json').read_bytes()==manifest_path.read_bytes(),'original_manifest_changed')
            self.adoption(manifest);require(self.subject_record()['subject_sha']==self.subject,'main_changed')
            # Independently re-read stored bytes, not the refresh scalar verdict.
            verify=verifier(self.repo,self.output/'terminal-validation',self.output/'refresh/portable',self.subject);verify.validate(verify.portable/'manifest.json',verify.portable/'refresh-envelope.json')
            interval={'started_at':self.started,'completed_at':now()};metadata_preflight(ROOT)
            references={name:reference(self.output,self.output/path) for name,path in {
                'subject':'subject.json','locator':'durable/locator.json','manifest':'durable/bundle/manifest.json',
                'sidecar':'durable/readiness-digest.json','archive':'durable/readiness-evidence.tar.gz',
                'refresh_manifest':'refresh/portable/manifest.json','refresh_envelope':'refresh/portable/refresh-envelope.json',
                'validator':'terminal-validation/refresh-validation.json'}.items()}
            terminal_schema=('rindle-snapshot-terminal-v3' if self.snapshot_policy==LEGACY_SNAPSHOT_POLICY else 'rindle-snapshot-terminal-v4') if self.snapshot else ('rindle-exact-head-terminal-v1' if self.readiness_policy==LEGACY_READINESS_POLICY else 'rindle-exact-head-terminal-v2')
            verdict={'schema':terminal_schema,'verdict':'fixture_ready' if self.fixture is not None else 'ready',
                'repository':self.repo,'subject_sha':self.subject,'evidence_mode':self.mode,'requirements_credit':self.fixture is None,
                'acceptance_scope':'historical','current_main_sha':main_sha(self.api),'current_readiness':False,'observation_interval':interval,'references':references,'run_id':run,'run_attempt':attempt}
            write_new(self.output/'terminal-verdict.json',verdict);atomic(self.output/'attempt.json',verdict);return 0
        except (NotReady,OSError,ValueError,KeyError,TypeError,IndexError,subprocess.SubprocessError) as exc:
            if self.reserved:
                write_new(self.output/'restricted/failure.json',{'exception_type':type(exc).__name__,'diagnostic':str(exc)})
                terminal_schema=('rindle-snapshot-terminal-v3' if self.snapshot_policy==LEGACY_SNAPSHOT_POLICY else 'rindle-snapshot-terminal-v4') if self.snapshot else ('rindle-exact-head-terminal-v1' if self.readiness_policy==LEGACY_READINESS_POLICY else 'rindle-exact-head-terminal-v2')
                value={'schema':terminal_schema,'verdict':'not_ready','reason':Closure.public_reason(str(exc)) if isinstance(exc,NotReady) else 'acceptance_unavailable',
                    'repository':self.repo,'subject_sha':self.subject,'evidence_mode':self.mode,'requirements_credit':False,'started_at':self.started,'completed_at':now()}
                if not (self.output/'terminal-verdict.json').exists():write_new(self.output/'terminal-verdict.json',value)
                atomic(self.output/'attempt.json',value)
            print('not_ready: '+(Closure.public_reason(str(exc)) if isinstance(exc,NotReady) else 'acceptance_unavailable'));return 1


def verifier(repo,output,portable,subject):
    output=reserve(output)
    owner=Closure(repo,output);owner.private=output/'restricted';owner.portable=Path(portable);owner.subject=subject
    return owner


def stored_bytes(repo,path,fixture):
    path=Path(path).resolve();value=read_json(path);root=path.parent;mode='fixture' if fixture is not None else 'execution'
    require(value.get('schema') in (*EXACT_HEAD_TERMINALS,*SNAPSHOT_TERMINALS) and value.get('repository')==repo and
        value.get('evidence_mode')==mode and value.get('verdict')==('fixture_ready' if fixture is not None else 'ready') and
        value.get('requirements_credit') is (fixture is None),'terminal_verdict_not_ready')
    if value['schema'] in SNAPSHOT_TERMINALS:
        require(value.get('acceptance_scope')=='historical' and value.get('current_readiness') is False,'terminal_policy_mismatch')
    interval=value['observation_interval']
    start,end=[dt.datetime.fromisoformat(interval[k].replace('Z','+00:00')) for k in ('started_at','completed_at')]
    require(start.tzinfo is not None and end.tzinfo is not None and start<=end<=dt.datetime.now(dt.timezone.utc),'terminal_interval')
    refs=value['references'];require(set(refs)=={'subject','locator','manifest','sidecar','archive','refresh_manifest','refresh_envelope','validator'},'terminal_reference_registry')
    data={name:object_bytes(root,ref) for name,ref in refs.items()};locator=read_json(root/refs['locator']['path']);sidecar=read_json(root/refs['sidecar']['path'])
    require(locator.get('bytes_verified') is True and locator.get('repository')==repo and locator.get('subject_sha')==value['subject_sha'] and
        locator.get('evidence_mode')==mode and locator.get('storage_scope')==('fixture_only' if fixture is not None else 'durable_maintainer_host') and
        locator.get('run_id')==value['run_id']==sidecar.get('run_id') and locator.get('run_attempt')==value['run_attempt']==sidecar.get('run_attempt') and
        sidecar.get('repository')==repo and sidecar.get('subject_sha')==value['subject_sha'] and sidecar.get('evidence_mode')==mode and
        digest(data['archive'])==sidecar.get('archive_sha256')==locator.get('archive_sha256') and
        digest(data['manifest'])==sidecar.get('manifest_sha256')==locator.get('manifest_sha256') and
        digest(data['sidecar'])==locator.get('producer_sidecar_sha256') and data['manifest']==data['refresh_manifest'],'terminal_bytes_mismatch')
    if value['schema'] in SNAPSHOT_TERMINALS:
        record=read_json(root/refs['subject']['path'])
        expected_checkout='rindle-readiness-snapshot-checkout-v3' if value['schema'].endswith('-v3') else 'rindle-readiness-snapshot-checkout-v4'
        require(record.get('schema')==expected_checkout and
            record.get('repository')==repo and record.get('subject_sha')==value['subject_sha'] and
            record.get('snapshot_binding',{}).get('subject_sha')==value['subject_sha'],'terminal_subject_identity')
        require(sidecar.get('schema')=='rindle-readiness-producer-digest-v2' and
            sidecar.get('producer_head_sha')==locator.get('producer_head_sha') and
            re.fullmatch(r'[0-9a-f]{40}',sidecar.get('producer_head_sha','')),'terminal_producer_identity')
    manifest=read_json(root/refs['manifest']['path'])
    expected_manifest_policy=(SNAPSHOT_TERMINALS.get(value['schema']) if value['schema'] in SNAPSHOT_TERMINALS else
        EXACT_HEAD_TERMINALS.get(value['schema']))
    require(manifest.get('policy')==expected_manifest_policy,'terminal_policy_mismatch')
    graph_objects((root/refs['manifest']['path']).parent,manifest)
    require(manifest['subject_sha']==value['subject_sha'] and manifest['evidence_mode']==mode,'terminal_bytes_mismatch')
    return value,manifest


def claim_status(repo,verdict,output,fixture=None):
    value,manifest=stored_bytes(repo,verdict,fixture);metadata_parity(ROOT,value['subject_sha'],value['observation_interval'])
    output=reserve(output);api=GitHub(repo,output/'restricted/api',fixture,budget=1000)
    source_root=Path(verdict).resolve().parent;references=value['references']
    owner=verifier(repo,output/'stored-validation',(source_root/references['refresh_manifest']['path']).parent,value['subject_sha'])
    owner.validate(source_root/references['refresh_manifest']['path'],source_root/references['refresh_envelope']['path'])
    current=main_sha(api)
    if current!=value['subject_sha'] or value['schema'] in SNAPSHOT_TERMINALS:
        if value['schema'] not in SNAPSHOT_TERMINALS:require(main_sha(api)==current,'main_changed')
        status='historical_ready';interval=value['observation_interval']
    else:
        require(verify_subject(api,repo)['subject_sha']==current,'main_changed');adoption_check(ROOT,manifest['adoption'])
        owner=Acceptance(repo,output,fixture);owner.refresh(Path(verdict).resolve().parent/value['references']['manifest']['path'],output/'refresh')
        require(main_sha(api)==current,'main_changed');adoption_check(ROOT,manifest['adoption'])
        status='fixture_current_ready' if fixture is not None else 'current_ready'
        interval=read_json(output/'refresh/verdict.json')['observation_interval']
    result={'status':status,'repository':repo,'subject_sha':value['subject_sha'],'current_main_sha':current,
        'observation_interval':interval,'evidence_mode':'fixture' if fixture is not None else 'execution',
        'requirements_credit':False,'current_readiness':status=='current_ready','source_verdict_sha256':digest(Path(verdict).read_bytes())}
    write_new(output/'claim-status.json',result);return result


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('operation',choices=('verify-subject','admit-snapshot','accept','claim-status'))
    parser.add_argument('--repo',required=True);parser.add_argument('--output');parser.add_argument('--verdict');parser.add_argument('--fixture')
    parser.add_argument('--snapshot',action='store_true');parser.add_argument('--snapshot-policy',choices=('rindle-snapshot-v3','rindle-snapshot-v4'));parser.add_argument('--readiness-policy',choices=('rindle-exact-head-v1','rindle-exact-head-v2'));parser.add_argument('--subject')
    args=parser.parse_args(argv)
    if args.snapshot and not args.subject:parser.error('--snapshot requires --subject FULL_SHA')
    if args.subject and not args.snapshot:parser.error('--subject requires --snapshot')
    if args.snapshot and args.readiness_policy:parser.error('--readiness-policy cannot be combined with --snapshot')
    if args.snapshot_policy and not args.snapshot:parser.error('--snapshot-policy requires --snapshot')
    if args.output is None:
        if args.operation=='claim-status' and args.verdict:
            args.output=str(Path(args.verdict).resolve().parent/('claim-status-'+secrets.token_hex(8)))
        else:parser.error('--output is required for this operation')
    if args.operation=='accept':return Acceptance(args.repo,args.output,args.fixture,subject=args.subject,snapshot=args.snapshot,snapshot_policy=args.snapshot_policy,readiness_policy=args.readiness_policy).run()
    try:
        if args.operation=='admit-snapshot':
            from readiness_subject import observe
            require(args.snapshot and args.subject is not None,'snapshot_subject_required')
            output=reserve(args.output);api=GitHub(args.repo,output/'restricted/api',args.fixture)
            write_new(output/'subject.json',observe(api,args.subject,policy=args.snapshot_policy));print('snapshot_admitted')
        elif args.operation=='claim-status':
            require(args.verdict is not None,'verdict_required');result=claim_status(args.repo,args.verdict,args.output,args.fixture);print(result['status'])
        else:
            output=reserve(args.output);api=GitHub(args.repo,output/'restricted/api',args.fixture)
            value=verify_subject(api,args.repo,subject=args.subject,snapshot=args.snapshot,snapshot_policy=args.snapshot_policy);value['evidence_mode']='fixture' if args.fixture is not None else 'execution';write_new(output/'subject.json',value);print('merged_subject_verified')
        return 0
    except (NotReady,OSError,ValueError,KeyError,TypeError,IndexError,subprocess.SubprocessError) as exc:
        print('not_ready: '+(Closure.public_reason(str(exc)) if isinstance(exc,NotReady) else 'acceptance_unavailable'));return 1

if __name__=='__main__':raise SystemExit(main())
