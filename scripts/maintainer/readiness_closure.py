#!/usr/bin/env python3
"""Finite candidate closure and immutable same-subject refresh. No release authority."""
import argparse
import copy
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import signal
import subprocess
import sys
import time

from exact_head_readiness import ROOT, POLICY_FILE, TOOLCHAIN_ENV, QUALIFICATION_SECONDS, NotReady, canonical, digest, now, read_json, reference, require, write_new, atomic, redact
from readiness_github import GitHub, RUN_COLLECTION_SECONDS, REMOTE_COLLECTION_SECONDS, COLLECTION_SHUTDOWN_SECONDS, json_bytes
from readiness_process import popen_owned, stop_owned

MAX_OBJECT = 256_000_000
MAX_GRAPH = 512_000_000


def refs(value):
    if isinstance(value,dict):
        if 'path' in value and 'sha256' in value:return [value]
        return [ref for item in value.values() for ref in refs(item)]
    if isinstance(value,list):return [ref for item in value for ref in refs(item)]
    return []


def object_bytes(root,ref):
    relative=ref.get('path');sha=ref.get('sha256')
    require(isinstance(relative,str) and relative and '\\' not in relative and '\0' not in relative and
            not relative.startswith('/') and all(p not in ('','.','..') for p in relative.split('/')) and
            isinstance(sha,str) and re.fullmatch(r'[0-9a-f]{64}',sha),'unsafe_object_reference')
    root=Path(root).resolve();path=root
    for part in relative.split('/'):
        path=path/part;require(not path.is_symlink(),'unsafe_object_reference')
    require(path.is_file() and path.stat().st_size<=MAX_OBJECT,'object_unavailable')
    data=path.read_bytes();require(digest(data)==sha,'object_digest_changed');return data


def semantic(packet):
    value=copy.deepcopy(packet['source']['normalized'])
    value.pop('authority_main_sha',None)
    if 'health_run' in value:
        # Each receipt validates this clock against its own observation interval.
        # Advancing the observation clock alone is not operational state drift.
        value.pop('observed_at',None)
    if 'sources' in value:
        for source in value['sources'].values():source.pop('observation_interval',None)
    return {'normalized':value,'query':packet['source'].get('query'),'policy':packet['source'].get('policy')}


class Closure:
    def __init__(self,repo,output,manifest=None,fixture=None,deadline=16200,subject=None,snapshot=False):
        self.repo=repo;self.output=Path(output).resolve();self.original=Path(manifest).resolve() if manifest else None
        self.candidate=subject;self.snapshot=snapshot
        self.fixture=fixture;self.mode='fixture' if fixture is not None else 'execution'
        self.deadline=time.monotonic()+deadline;self.sequence=0;self.subject=None;self.local_output=None
        self.run_id=secrets.token_hex(16);self.started=now();self.proposed=None;self.objects={};self.index=None
        self.env={**os.environ,**TOOLCHAIN_ENV,'ERL_FLAGS':'+S 4:4','PYTHONDONTWRITEBYTECODE':'1'}
        self.main_index=0;self.stage='reserve';self.reserved=False

    def reserve(self):
        require(re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+',self.repo),'repository_identity')
        require(not self.output.exists() and not self.output.is_relative_to(ROOT),'output_must_be_new_external_directory')
        self.output.mkdir(mode=0o700,parents=True);self.reserved=True
        self.private=self.output/'restricted';self.portable=self.output/'portable'
        self.private.mkdir(mode=0o700);self.portable.mkdir(mode=0o700)
        initial={'schema_version':1,'verdict':'not_ready','reason':'collecting','repository':self.repo,
            'subject_sha':None,'evidence_mode':self.mode,'requirements_credit':False,'run_id':self.run_id,
            'started_at':self.started,'operation':'refresh' if self.original else 'close'}
        write_new(self.output/'initial-attempt.json',initial);atomic(self.output/'attempt.json',initial)
        if self.fixture is not None:
            self.fixture=Path(self.fixture).resolve();self.index=read_json(self.fixture/'closure.json')
            require(isinstance(self.index,dict) and self.index.get('repository')==self.repo,'invalid_closure_fixture')
            self.started=self.index['observation_interval']['started_at']
        else:self.api=GitHub(self.repo,self.private/'api',budget=max(1,self.deadline-time.monotonic()))

    def fixture_path(self,name):
        relative=self.index.get(name)
        require(isinstance(relative,str) and not Path(relative).is_absolute(),'invalid_closure_fixture')
        path=self.fixture/relative
        require(not path.is_symlink() and path.resolve().is_relative_to(self.fixture) and path.exists(),'invalid_closure_fixture')
        return path

    def timestamp(self):
        return self.index['observation_interval']['completed_at'] if self.index else now()

    def command(self,argv,budget,cwd=ROOT,env=None,cleanup=False):
        self.sequence+=1;log=self.private/f'command-{self.sequence:04d}.log'
        end=time.monotonic()+budget if cleanup else min(self.deadline,time.monotonic()+budget)
        require(end>time.monotonic(),'closure_deadline')
        with open(log,'xb',opener=lambda p,f:os.open(p,f,0o600)) as out:
            try:
                child=popen_owned(argv,cwd=cwd,env=env or self.env,stdout=out,stderr=subprocess.STDOUT)
                while child.poll() is None:
                    if time.monotonic()>=end or out.tell()>32*1024*1024:
                        stop_owned(child,270 if 'qualify' in argv else 5)
                        raise NotReady('closure_command_timeout')
                    time.sleep(.03)
                require(out.tell()<=32*1024*1024,'closure_output_limit')
                return child.returncode,log.read_bytes()
            except BaseException as exc:
                if 'child' in locals():stop_owned(child,270 if 'qualify' in argv else 5)
                if isinstance(exc,OSError):raise NotReady('closure_command_unavailable') from exc
                raise

    def metadata(self):
        selection='"rindle-snapshot-v3"' if self.snapshot else 'v.policy()'
        expr='Code.require_file("scripts/maintainer/validate_exact_head_readiness.exs"); v=Rindle.ExactHeadReadiness; p='+selection+'; IO.puts(Jason.encode!(%{policy: p, proofs: v.required_proofs(p), mutable: v.mutable_proofs(p), inputs: v.input_paths()}))'
        code,raw=self.command(['mix','run','--no-start','--no-compile','--no-deps-check','-e',expr],45,
            env={**self.env,'RINDLE_EXACT_HEAD_LIBRARY_ONLY':'1'})
        require(code==0,'validator_unavailable')
        self.policy=json_bytes(raw.decode().splitlines()[-1])
        self.tool_sha=digest((ROOT/POLICY_FILE).read_bytes())

    def remote_main(self):
        if self.index:
            values=self.index.get('main_sequence',[self.index['subject_sha']])
            require(isinstance(values,list) and values,'invalid_closure_fixture')
            value=values[min(self.main_index,len(values)-1)];self.main_index+=1
        else:
            value,_=self.api.get(self.api.path('git/ref/heads/main'))
            require(value.get('ref')=='refs/heads/main' and value.get('object',{}).get('type')=='commit','main_unavailable')
            value=value['object']['sha']
        require(isinstance(value,str) and re.fullmatch(r'[0-9a-f]{40}',value),'main_unavailable')
        return value

    def check_main(self):
        if not self.snapshot:
            current=self.remote_main();require(current==self.subject,'main_changed');return current
        from readiness_subject import observe
        if self.index:
            current=self.remote_main()
            value=read_json(self.fixture_path('snapshot_'+current))
            require(value.get('current_main_sha')==current and value.get('subject_sha')==self.subject,'snapshot_subject_mismatch')
        else:value=observe(self.api,self.subject)
        ref=self.store_object('subject/'+secrets.token_hex(8)+'.json',canonical(value))
        self.subject_observations=getattr(self,'subject_observations',[])+[ref]
        return value['current_main_sha']

    def verify_root(self):
        if self.index:return
        code,raw=self.command(['git','rev-parse','HEAD'],10)
        require(code==0 and raw.decode().strip()==self.subject,'closing_subject_not_checked_out')
        code,raw=self.command(['git','status','--porcelain','--untracked-files=all'],10)
        require(code==0 and not raw.strip(),'dirty_closing_checkout')

    def store_object(self,target,data):
        sha=digest(data)
        if target in self.objects:require(self.objects[target]==sha,'object_path_collision')
        else:
            require(len(data)<=MAX_OBJECT and len(self.objects)<2000 and
                sum((self.portable/p).stat().st_size for p in self.objects)+len(data)<=MAX_GRAPH,'graph_limit')
            dest=self.portable/target
            if dest.exists():require(dest.is_file() and not dest.is_symlink() and dest.read_bytes()==data,'object_path_collision')
            else:write_new(dest,data)
            self.objects[target]=sha
        return {'path':target,'sha256':sha}

    def copy_object(self,root,ref,prefix=''):
        return self.store_object(prefix+ref['path'],object_bytes(root,ref))

    def copy_manifest_graph(self,root,manifest):
        for ref in refs(manifest):
            self.copy_object(root,ref)
            if ref.get('id') in self.policy['proofs']:
                receipt=json_bytes(object_bytes(root,ref))
                for child in refs(receipt):self.copy_object(root,child)

    def local(self):
        if self.index:
            path=self.fixture_path('local_manifest');manifest=read_json(path);root=path.parent
        else:
            self.local_output=self.private/'local-qualification'
            code,raw=self.command(['bash',str(ROOT/'scripts/maintainer/exact_head_readiness.sh'),'qualify','--repo',self.repo,
                '--subject',self.subject,'--output',str(self.local_output)]+(['--snapshot'] if self.snapshot else []),QUALIFICATION_SECONDS+300)
            if code:
                print('LOCAL_QUALIFICATION_FAILURE ' + json.dumps(redact(raw,self.env)[-16384:].decode(errors='replace')),flush=True)
                attempt=read_json(self.local_output/'attempt.json') if (self.local_output/'attempt.json').is_file() else {}
                raise NotReady(attempt.get('reason','local_qualification_failed'))
            root=self.local_output/'portable';manifest=read_json(root/'manifest.json')
        require(manifest.get('repository')==self.repo and manifest.get('subject_sha')==self.subject and manifest.get('evidence_mode')==self.mode,'local_subject_or_mode')
        require(manifest.get('state')=='incomplete' and manifest.get('local_state')=='complete','local_qualification_incomplete')
        require(manifest.get('cleanup',{}).get('state')=='observed' and manifest['cleanup'].get('errors')==[],'cleanup_failed')
        require(sorted(r.get('id') for r in manifest['proofs'])==sorted(set(self.policy['proofs'])-set(self.policy['mutable'])),'local_registry_incomplete')
        for ref in manifest['proofs']:require(json_bytes(object_bytes(root,ref)).get('evidence_mode')==self.mode,'mixed_evidence_mode')
        self.copy_manifest_graph(root,manifest)
        return manifest

    def verify_packet(self,packet,root,id):
        source=packet.get('source',{});normalized=source.get('normalized',{})
        require(source.get('complete') is True and source.get('authenticated') is True and source.get('policy')==self.policy['policy'] and
            type(source.get('pages')) is int and source['pages']>0 and isinstance(source.get('query'),str) and source['query'],'source_unavailable')
        require(normalized.get('repository')==self.repo and normalized.get('subject_sha')==self.subject,'source_subject')
        observations=source.get('observations');require(isinstance(observations,list) and len(observations)==2,'source_observations')
        require(observations[0]['path']!=observations[1]['path'],'source_observations')
        require(source.get('before_sha256')==observations[0]['sha256'] and source.get('after_sha256')==observations[1]['sha256'],'source_observations')
        for ref in packet.get('references',[]):object_bytes(root,ref)
        for ref in observations:require(ref in packet['references'] and json_bytes(object_bytes(root,ref))==normalized,'source_observations')
        require(source['before_sha256']==source['after_sha256'],'source_changed')

    def producer_sources(self,kind,position):
        if self.index:path=self.fixture_path(kind+'_'+position)
        else:
            output=self.private/(kind+'-'+position)
            script='collect_readiness_runs.sh' if kind=='runs' else 'collect_readiness_remote.sh'
            seconds=RUN_COLLECTION_SECONDS if kind=='runs' else REMOTE_COLLECTION_SECONDS
            code,_=self.command(['bash',str(ROOT/'scripts/maintainer'/script),'--repo',self.repo,'--subject',self.subject,'--output',str(output)]+(['--snapshot'] if self.snapshot else []),seconds+COLLECTION_SHUTDOWN_SECONDS)
            if code:
                value=read_json(output/'verdict.json') if (output/'verdict.json').is_file() else {}
                self.failed_proof=value.get('failed_proof')
                changed=value.get('changed_sources')
                sources={'issues','pulls','checks','statuses','absent','advisories','dependabot','hex','protection'}
                if value.get('reason')=='remote_state_changed' and isinstance(changed,list) and 0<len(changed)<=len(sources) and all(isinstance(name,str) and name in sources for name in changed):
                    detail={'reason':'remote_state_changed','kind':kind,'position':position,'changed_sources':changed}
                    from readiness_github import PULL_DIAGNOSTIC_FIELDS
                    pulls=value.get('pull_changes')
                    if isinstance(pulls,list) and len(pulls)<=1000 and all(isinstance(row,dict) and
                        set(row)=={'number','fields'} and type(row['number']) is int and row['number']>0 and
                        isinstance(row['fields'],list) and 0<len(row['fields'])<=len(PULL_DIAGNOSTIC_FIELDS) and
                        all(isinstance(field,str) and field in PULL_DIAGNOSTIC_FIELDS for field in row['fields']) for row in pulls):
                        detail['pull_changes']=pulls
                    print('REMOTE_COLLECTION_FAILURE '+json.dumps(detail,sort_keys=True),flush=True)
                raise NotReady(value.get('reason','remote_collection_failed'))
            path=output/'portable/sources.json'
        value=read_json(path)
        require(value.get('repository')==self.repo and value.get('subject_sha')==self.subject and value.get('evidence_mode')==self.mode,'source_subject_or_mode')
        if value.get('verdict')=='not_ready':raise NotReady(self.public_reason(value.get('reason')))
        expected=({'ci-main','nightly-qualification','scheduled-incident-health','protection'} if self.snapshot else {'ci-main','nightly-scheduled','protection'}) if kind=='runs' else {'remote-inventory'}
        require(set(value.get('sources',{}))==expected,'source_registry_incomplete')
        if kind=='runs' and self.mode=='execution':
            timing=value.get('numeric_speed',{})
            require(timing.get('state')=='deferred_unfinished' and timing.get('acceptance_credit') is False,'timing_deferral_drift')
            history=refs(timing);require(len(history)==2,'timing_history_unavailable')
            value['sources']['ci-main']['references']+=history
        for id,packet in value['sources'].items():self.verify_packet(packet,path.parent,id)
        return {id:(packet,path.parent) for id,packet in value['sources'].items()}

    def adoption(self,position):
        if self.index:
            path=self.fixture_path('adoption_'+position);value=read_json(path)
            require(value.get('evidence_mode')==self.mode and set(value.get('sources',{}))=={'adoption-parity'},'source_subject_or_mode')
            packet=value['sources']['adoption-parity'];self.verify_packet(packet,path.parent,'adoption-parity')
            return {'adoption-parity':(packet,path.parent)}
        started=now();before=self.adoption_facts();after=self.adoption_facts();require(before==after,'adoption_changed')
        root=self.private/('adoption-'+position);root.mkdir(mode=0o700)
        normalized={'repository':self.repo,'subject_sha':self.subject,**before};observations=[]
        extra=[]
        if self.snapshot:
            normalized.update(authority_main_sha=self.authority_sha,authoritative_files={})
            for relative,raw in self.authority_bytes.items():
                path=root/'authority'/relative;write_new(path,raw);ref=reference(root,path)
                normalized['authoritative_files'][relative]=ref;extra.append(ref)
        for side in ('before','after'):
            path=root/('observations/adoption-'+position+'-'+side+'.json');write_new(path,normalized);observations.append(reference(root,path))
        packet={'references':observations+extra,'source':{'complete':True,'authenticated':True,'query':('authenticated current-main authoritative inputs; two reads' if self.snapshot else 'local authoritative requirements/project/release state; two reads'),
            'pages':1,'policy':self.policy['policy'],'normalized':normalized,'observation_interval':{'started_at':started,'completed_at':now()},
            'observations':observations,'before_sha256':observations[0]['sha256'],'after_sha256':observations[1]['sha256']}}
        return {'adoption-parity':(packet,root)}

    def adoption_facts(self):
        from readiness_adoption import check,check_bytes,INPUTS
        if not self.snapshot:return check(ROOT)
        from readiness_subject import current_authority
        self.authority_sha,self.authority_bytes=current_authority(self.api,INPUTS)
        return check_bytes(self.authority_bytes)

    def collect(self,position):
        value={**self.producer_sources('runs',position),**self.producer_sources('remote',position),**self.adoption(position)}
        require(set(value)==set(self.policy['mutable']),'source_registry_incomplete')
        return value

    def import_packet(self,packet,root,prefix):
        source=copy.deepcopy(packet['source']);normalized=source['normalized'];data_refs=[]
        def rebase(value):
            if isinstance(value,dict):
                if 'path' in value and 'sha256' in value:
                    ref=self.copy_object(root,value,prefix);data_refs.append(ref);return ref
                return {key:rebase(item) for key,item in value.items()}
            if isinstance(value,list):return [rebase(item) for item in value]
            return value
        normalized=rebase(normalized)
        observations=[]
        for old in source['observations']:
            observations.append(self.store_object(prefix+old['path'],canonical(normalized)+b'\n'))
        for old in packet['references']:
            if old not in source['observations']:
                ref=self.copy_object(root,old,prefix)
                if ref not in data_refs:data_refs.append(ref)
        source.update(normalized=normalized,observations=observations,before_sha256=observations[0]['sha256'],after_sha256=observations[1]['sha256'])
        return {'source':source,'references':observations+data_refs}

    def receipts(self,manifest,packets,prefix=''):
        result=[]
        keys=('repository','subject_sha','policy','validator_sha256','toolchain','input_identity','package_identity','evidence_mode')
        for id in self.policy['mutable']:
            packet,root=packets[id];packet=self.import_packet(packet,root,prefix)
            receipt={**{key:manifest[key] for key in keys},'schema_version':1,'id':id,'state':'complete','outcome':'passed',
                'applicability':'required','observation_interval':packet['source']['observation_interval'],**packet}
            path=self.portable/(prefix+'receipts/'+id+'.json');write_new(path,receipt);result.append({**reference(self.portable,path),'id':id})
        return result

    def validate(self,manifest,envelope=None):
        path=self.output/('refresh-validation.json' if envelope else 'candidate-validation.json')
        argv=['mix','run','--no-start','--no-compile','--no-deps-check',str(ROOT/POLICY_FILE),'--manifest',str(manifest),
            '--root',str(self.portable),'--verdict',str(path)]
        if envelope:argv+=['--refresh-envelope',str(envelope)]
        env=dict(self.env);env.pop('RINDLE_EXACT_HEAD_LIBRARY_ONLY',None)
        code,_=self.command(argv,90,env=env)
        require(path.is_file(),'validator_unavailable');value=read_json(path)
        require(code==0 and value.get('verdict')=='ready','validator_'+value.get('reasons',[{'id':'not_ready'}])[0]['id'] if code else 'validator_not_ready')
        require(value.get('subject_sha')==self.subject and value.get('requirements_credit') is False,'validator_identity')
        return reference(self.output,path)

    def retry_cleanup(self):
        if self.mode=='fixture' or self.local_output is None:return {'state':'not_needed'}
        path=self.local_output/'attempt.json'
        if not path.is_file():return {'state':'unavailable','reason':'qualification_attempt_missing'}
        try:
            original_bytes=path.read_bytes();original=read_json(path)
            if original.get('cleanup',{}).get('state')=='observed':return {'state':'observed'}
            code,_=self.command(['bash',str(ROOT/'scripts/maintainer/exact_head_readiness.sh'),'cleanup','--output',str(self.local_output)],270,cleanup=True)
            return {'state':'observed' if code==0 else 'failed','original_attempt_unchanged':path.read_bytes()==original_bytes}
        except Exception as exc:
            write_new(self.private/'cleanup-failure.json',{'exception_type':type(exc).__name__,'diagnostic':str(exc)})
            return {'state':'failed'}

    @staticmethod
    def public_reason(reason):
        return reason if isinstance(reason,str) and re.fullmatch(r'[a-z][a-z0-9_]{0,80}',reason) and reason not in ('ready','candidate_ready','current_ready') else 'upstream_not_ready'

    def run(self):
        handlers={sig:signal.getsignal(sig) for sig in (signal.SIGINT,signal.SIGTERM)}
        def interrupt(_sig,_frame):raise NotReady('closure_interrupted')
        result={'schema_version':1,'verdict':'not_ready','repository':self.repo,'subject_sha':None,'evidence_mode':self.mode,
            'requirements_credit':False,'acceptance_scope':'candidate_only','run_id':self.run_id}
        try:
            self.reserve()
            result['initial_attempt']=reference(self.output,self.output/'initial-attempt.json')
            for sig in handlers:signal.signal(sig,interrupt)
            if self.original:
                existing=read_json(self.original)
                inferred=existing.get('policy')=='rindle-snapshot-v3'
                require(not self.snapshot or inferred,'snapshot_policy_mismatch')
                require(self.candidate is None or self.candidate==existing.get('subject_sha'),'snapshot_subject_mismatch')
                self.snapshot=inferred
                self.candidate=existing.get('subject_sha')
            if self.snapshot:
                require(isinstance(self.candidate,str) and re.fullmatch(r'[0-9a-f]{40}',self.candidate),'snapshot_subject_required')
                self.subject=self.candidate
            self.stage='metadata';self.metadata()
            self.stage='main';main=self.check_main() if self.snapshot else self.remote_main()
            self.observed_main_before=main
            if self.original:
                manifest=read_json(self.original);original_bytes=self.original.read_bytes();self.subject=manifest.get('subject_sha')
                require(manifest.get('repository')==self.repo and manifest.get('evidence_mode')==self.mode,'manifest_subject_or_mode')
                if not self.snapshot:require(main==self.subject,'main_changed')
                self.verify_root();self.copy_manifest_graph(self.original.parent,manifest)
                write_new(self.portable/'manifest.json',original_bytes)
                self.validate(self.portable/'manifest.json')
            else:
                if not self.snapshot:self.subject=main
                self.verify_root()
            result['subject_sha']=self.subject
            self.stage='initial_remote';before=self.collect('before')
            if not self.original:self.stage='local';manifest=self.local()
            require(manifest.get('validator_sha256')==self.tool_sha and manifest.get('policy')==self.policy['policy'],'tool_identity')
            if not self.original:
                # The initial collection is a fail-fast preflight. Immutable native
                # proof may take hours; acceptance compares two fresh collections
                # after it, with every original policy and byte check unchanged.
                self.stage='joining_remote';before=self.collect('join-before')
            self.stage='final_remote';after=self.collect('after')
            changed=[id for id in self.policy['mutable'] if semantic(before[id][0])!=semantic(after[id][0])]
            if changed:
                detail={'reason':'mutable_source_changed','changed_proofs':sorted(changed)}
                if 'remote-inventory' in changed:
                    left=semantic(before['remote-inventory'][0])['normalized'].get('sources',{})
                    right=semantic(after['remote-inventory'][0])['normalized'].get('sources',{})
                    names=('issues','pulls','checks','statuses','absent','advisories','dependabot','hex','protection')
                    detail['changed_remote_sources']=[name for name in names if left.get(name)!=right.get(name)]
                # Fixed policy names only: private values never enter public logs.
                print('MUTABLE_COLLECTION_FAILURE '+json.dumps(detail,sort_keys=True),flush=True)
                result.update({key:value for key,value in detail.items() if key!='reason'})
                raise NotReady('mutable_source_changed')
            self.stage='final_main';self.observed_main_after=self.check_main();self.verify_root()
            interval={'started_at':self.started,'completed_at':self.timestamp()}
            if self.original:
                prefix='refresh/'+self.run_id+'/'
                envelope={key:manifest[key] for key in ('repository','subject_sha','policy','validator_sha256')}
                envelope.update(schema_version=1,manifest_sha256=digest(original_bytes),remote_main_before=self.observed_main_before,remote_main_after=self.observed_main_after,
                    observation_interval=interval,proofs=self.receipts(manifest,after,prefix),adoption=after['adoption-parity'][0]['source']['normalized']['adoption'],verdict='ready')
                if self.snapshot:envelope['snapshot_subjects']=[self.subject_observations[0],self.subject_observations[-1]]
                self.proposed=self.portable/'refresh-envelope.proposed.json';write_new(self.proposed,envelope)
                validation=self.validate(self.portable/'manifest.json',self.proposed)
                final=self.portable/'refresh-envelope.json'
            else:
                manifest.update(state='complete',observation_interval=interval,remote_main_before=self.observed_main_before,remote_main_after=self.observed_main_after,
                    adoption=after['adoption-parity'][0]['source']['normalized']['adoption'])
                if self.snapshot:manifest['snapshot_subjects']=[self.subject_observations[0],self.subject_observations[-1]]
                manifest['proofs']+=self.receipts(manifest,after)
                self.proposed=self.portable/'manifest.proposed.json';write_new(self.proposed,manifest)
                validation=self.validate(self.proposed);final=self.portable/'manifest.json'
            result['current_main_at_completion']=self.check_main();self.verify_root()
            if self.original:
                require(self.original.read_bytes()==original_bytes and (self.portable/'manifest.json').read_bytes()==original_bytes,'manifest_bytes_changed')
                self.copy_manifest_graph(self.original.parent,manifest)
            os.replace(self.proposed,final);self.proposed=None
            result.update(verdict='candidate_ready',reason='validated_refresh' if self.original else 'validated_candidate',validation=validation,
                manifest=reference(self.output,self.portable/'manifest.json'),observation_interval=interval,
                policy=self.policy['policy'],validator_sha256=self.tool_sha)
            if self.original:result['refresh_envelope']=reference(self.output,final)
            code=0
        except Exception as exc:
            if not self.reserved:raise
            reason=self.public_reason(str(exc)) if isinstance(exc,NotReady) else 'closure_unavailable'
            write_new(self.private/'failure.json',{'exception_type':type(exc).__name__,'diagnostic':str(exc),'stage':self.stage})
            result.update(reason=reason,failure_reason=reason,stage=self.stage,subject_sha=self.subject,
                failed_proof=getattr(self,'failed_proof',None),cleanup=self.retry_cleanup())
            if self.proposed and self.proposed.is_file():self.proposed.unlink()
            if result['cleanup'].get('state')=='failed':result['reason']='cleanup_failed'
            result['repair_command']=['bash','scripts/maintainer/exact_head_readiness.sh','refresh' if self.original else 'close','--repo',self.repo,'--output','NEW_EXTERNAL_DIRECTORY']
            if self.original:result['repair_command']+=['--manifest',str(self.original)]
            if self.snapshot:result['repair_command']+=['--snapshot','--subject',self.subject]
            if reason=='scheduled_run_missing':result['next_observation']=('newest real global schedule under matching controls; preserve candidate proof' if self.snapshot else 'next scheduled Nightly on this same main subject; dispatch grants no acceptance')
            code=1
        finally:
            for sig,handler in handlers.items():signal.signal(sig,handler)
        write_new(self.output/'verdict.json',result);atomic(self.output/'attempt.json',result)
        print(result['verdict']+': '+result['reason']);return code


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation',choices=['close','refresh']);parser.add_argument('--repo',required=True)
    parser.add_argument('--output',required=True);parser.add_argument('--manifest');parser.add_argument('--fixture')
    parser.add_argument('--snapshot',action='store_true');parser.add_argument('--subject')
    args=parser.parse_args(argv)
    try:
        require((args.operation=='refresh')==(args.manifest is not None),'refresh_requires_manifest')
        require(args.snapshot or args.subject is None,'snapshot_flag_required')
        return Closure(args.repo,args.output,args.manifest,args.fixture,subject=args.subject,snapshot=args.snapshot).run()
    except (NotReady,OSError,ValueError) as exc:
        print('not_ready: '+(str(exc) if isinstance(exc,NotReady) else 'closure_unavailable'));return 1

if __name__=='__main__':raise SystemExit(main())
