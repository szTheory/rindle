#!/usr/bin/env python3
"""Producer-bound archive preparation and authenticated durable byte retrieval."""
import argparse
import gzip
import io
import os
from pathlib import Path
import re
import tarfile
import tempfile
import zipfile

from exact_head_readiness import ROOT, NotReady, canonical, digest, now, read_json, reference, require, write_new
from readiness_closure import Closure, object_bytes, refs
from readiness_github import GitHub, json_bytes

WORKFLOW = '.github/workflows/readiness-retention.yml'
WORKFLOW_NAME = 'Readiness Retention'
SIDECAR_SCHEMA = 'rindle-readiness-producer-digest-v1'
ARCHIVE_FILE = 'readiness-evidence.tar.gz'
SIDECAR_FILE = 'readiness-digest.json'


def reserve(path):
    path=Path(path).resolve();require(not path.exists() and not path.is_relative_to(ROOT),'output_must_be_new_external_directory')
    path.mkdir(mode=0o700,parents=True);(path/'restricted').mkdir(mode=0o700);return path


def graph_objects(root,manifest):
    result={}
    for ref in refs(manifest):
        result[ref['path']]=object_bytes(root,ref)
        if ref.get('id'):
            require(ref['id'] in {r['id'] for r in manifest['proofs']},'proof_reference')
            receipt=json_bytes(result[ref['path']]);require(receipt.get('evidence_mode')==manifest.get('evidence_mode'),'mixed_evidence_mode')
            for child in refs(receipt):result[child['path']]=object_bytes(root,child)
    require(len(result)<=2000 and sum(map(len,result.values()))<=512_000_000,'graph_limit')
    return result


def scan_public(objects,environment):
    secrets=[v.encode() for k,v in environment.items() if len(v)>7 and re.search(r'TOKEN|SECRET|PASSWORD|API_KEY',k)]
    for data in objects.values():
        require(not any(s in data for s in secrets),'portable_secret_detected')
        require(not re.search(rb'(?i)authorization:\s*(?:bearer|token)\s+[^\s\]]{8,}',data),'portable_secret_detected')
        require(not any(marker in data for marker in (b'ADVISORY-CANARY-'+b'PRIVATE-BODY',b'TOKEN-CANARY-'+b'DO-NOT-PUBLISH',b'PRIVATE-CLOSURE-'+b'CANARY')),'portable_private_canary')


def durable_path(path,fixture):
    path=Path(path).resolve()
    require(not path.exists() and not path.is_relative_to(ROOT),'durable_destination_invalid')
    if fixture is None:
        require(os.environ.get('GITHUB_ACTIONS')!='true' and not os.environ.get('RUNNER_TEMP'),'durable_host_required')
        temporary=[Path(tempfile.gettempdir()).resolve(),Path('/tmp').resolve(),Path('/private/tmp'),Path('/run'),Path('/dev/shm'),Path('/private/var/folders'),Path('/var/tmp'),Path('/private/var/tmp')]
        require(not any(path.is_relative_to(p) for p in temporary),'ephemeral_destination')
    return path


def prepare(manifest_path,output,environment=None):
    output=reserve(output);environment=dict(os.environ if environment is None else environment)
    failure={'schema_version':1,'verdict':'not_ready','operation':'prepare','requirements_credit':False}
    try:
        manifest_path=Path(manifest_path).resolve();manifest=read_json(manifest_path)
        repo,subject=manifest['repository'],manifest['subject_sha']
        snapshot=manifest.get('policy')=='rindle-snapshot-v2'
        producer_head=environment.get('GITHUB_SHA','')
        run=environment.get('GITHUB_RUN_ID','');attempt=environment.get('GITHUB_RUN_ATTEMPT','')
        require(environment.get('GITHUB_ACTIONS')=='true' and environment.get('GITHUB_REPOSITORY')==repo and
            (producer_head==subject if not snapshot else
             re.fullmatch(r'[0-9a-f]{40}',producer_head) and environment.get('EXPECTED_SUBJECT')==subject and environment.get('ACCEPTANCE_MODE')=='snapshot') and environment.get('GITHUB_REF')=='refs/heads/main' and
            environment.get('GITHUB_EVENT_NAME')=='workflow_dispatch' and environment.get('GITHUB_WORKFLOW')==WORKFLOW_NAME and
            environment.get('GITHUB_WORKFLOW_REF')==repo+'/'+WORKFLOW+'@refs/heads/main' and
            re.fullmatch(r'[1-9][0-9]{0,19}',run) and re.fullmatch(r'[1-9][0-9]{0,9}',attempt),'producer_context_unavailable')
        require(manifest.get('evidence_mode') in ('fixture','execution') and manifest.get('state')=='complete','manifest_not_candidate')
        verifier=Closure(repo,output);verifier.private=output/'restricted';verifier.portable=manifest_path.parent;verifier.subject=subject
        verifier.validate(manifest_path)
        objects=graph_objects(manifest_path.parent,manifest);objects['manifest.json']=manifest_path.read_bytes()
        scan_public(objects,environment)
        archive=output/ARCHIVE_FILE
        with open(archive,'xb',opener=lambda p,f:os.open(p,f,0o600)) as raw:
            with gzip.GzipFile(fileobj=raw,mode='wb',filename='',mtime=0) as compressed:
                with tarfile.open(fileobj=compressed,mode='w|',format=tarfile.USTAR_FORMAT) as tar:
                    for name,data in sorted(objects.items()):
                        require(not name.startswith(('restricted/','../','/')),'unsafe_archive_member')
                        info=tarfile.TarInfo(name);info.size=len(data);info.mode=0o600;info.mtime=0
                        tar.addfile(info,io.BytesIO(data))
            raw.flush();os.fsync(raw.fileno())
        require(archive.stat().st_size<=250_000_000,'artifact_size_limit')
        import secrets
        nonce=secrets.token_hex(8)
        archive_name=f'rindle-readiness-archive-{run}-{attempt}-{nonce}'
        sidecar_name=f'rindle-readiness-digest-{run}-{attempt}-{nonce}'
        sidecar={'schema':'rindle-readiness-producer-digest-v2' if snapshot else SIDECAR_SCHEMA,'repository':repo,'subject_sha':subject,'workflow':WORKFLOW,'workflow_name':WORKFLOW_NAME,
            'run_id':int(run),'run_attempt':int(attempt),'event':'workflow_dispatch','branch':'main','evidence_mode':manifest['evidence_mode'],
            'archive_artifact_name':archive_name,'sidecar_artifact_name':sidecar_name,'archive_file':ARCHIVE_FILE,
            'manifest_sha256':digest(objects['manifest.json']),'archive_sha256':digest(archive.read_bytes()),'created_at':now(),
            'requirements_credit':False}
        if snapshot:sidecar['producer_head_sha']=producer_head
        write_new(output/SIDECAR_FILE,sidecar)
        value={'schema_version':1,'verdict':'prepared','repository':repo,'subject_sha':subject,'evidence_mode':manifest['evidence_mode'],
            'requirements_credit':False,'archive':reference(output,archive),'sidecar':reference(output,output/SIDECAR_FILE),
            'archive_artifact_name':archive_name,'sidecar_artifact_name':sidecar_name}
        write_new(output/'prepared.json',value)
        github_output=environment.get('GITHUB_OUTPUT')
        if github_output:
            with open(github_output,'a') as stream:
                stream.write('archive_path='+str(archive)+'\nsidecar_path='+str(output/SIDECAR_FILE)+'\narchive_name='+archive_name+'\nsidecar_name='+sidecar_name+'\n')
        return value
    except Exception as exc:
        write_new(output/'verdict.json',{**failure,'reason':Closure.public_reason(str(exc)) if isinstance(exc,NotReady) else 'retention_prepare_failed'})
        raise


def zip_member(raw,name,max_size):
    try:
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            items=archive.infolist()
            require(len(items)==1 and items[0].filename==name and not items[0].is_dir() and
                items[0].file_size<=max_size and (items[0].external_attr>>16)&0o170000!=0o120000,'unsafe_artifact_archive')
            with archive.open(items[0]) as stream:data=stream.read(max_size+1)
            require(len(data)==items[0].file_size and len(data)<=max_size,'artifact_size_limit');return data
    except (zipfile.BadZipFile,RuntimeError,OSError) as exc:raise NotReady('unsafe_artifact_archive') from exc


def unpack(raw,destination):
    result={};used=0
    try:
        with gzip.GzipFile(fileobj=io.BytesIO(raw),mode='rb') as archive:
            while True:
                header=archive.read(512)
                require(len(header)==512,'incomplete_bundle_header')
                if header==b'\0'*512:
                    tail=archive.read(10241)
                    require(len(tail)<=10240 and tail and not tail.strip(b'\0'),'unsafe_bundle_tail')
                    break
                # Reject extension records before a general tar reader can expand them.
                require(header[156:157] in (b'0',b'\0'),'unsafe_bundle_member')
                member=tarfile.TarInfo.frombuf(header,'utf-8','strict');parts=member.name.split('/')
                require(member.isfile() and member.name and not member.name.startswith('/') and '\\' not in member.name and
                    all(p not in ('','.','..') for p in parts) and member.name not in result and
                    not member.name.startswith('restricted/') and 0<=member.size<=256_000_000,'unsafe_bundle_member')
                require(len(result)<2001 and used+member.size<=512_000_000,'bundle_size_limit')
                data=archive.read(member.size);require(len(data)==member.size,'incomplete_bundle_member')
                padding=(-member.size)%512
                require(archive.read(padding)==b'\0'*padding,'unsafe_bundle_padding')
                result[member.name]=data;used+=member.size
        require('manifest.json' in result,'manifest_unavailable')
        manifest=json_bytes(result['manifest.json']);expected=set(graph_objects_from_bytes(result,manifest))|{'manifest.json'}
        require(set(result)==expected,'bundle_inventory_mismatch')
        for name,data in result.items():write_new(destination/name,data)
        return manifest,result
    except (tarfile.TarError,EOFError,OSError,UnicodeError) as exc:raise NotReady('unsafe_bundle_member') from exc


def graph_objects_from_bytes(objects,manifest):
    result=set()
    def check(ref):
        path=ref.get('path');require(isinstance(path,str) and path in objects and digest(objects[path])==ref.get('sha256'),'bundle_object_digest')
        result.add(path);return objects[path]
    for ref in refs(manifest):
        data=check(ref)
        if ref.get('id'):
            receipt=json_bytes(data);require(receipt.get('evidence_mode')==manifest.get('evidence_mode'),'mixed_evidence_mode')
            for child in refs(receipt):check(child)
    return result


def run_identity(value,repo,run,attempt):
    require(value.get('id')==run and value.get('run_attempt')==attempt and value.get('repository',{}).get('full_name')==repo and
        value.get('path')==WORKFLOW and value.get('name')==WORKFLOW_NAME and value.get('event')=='workflow_dispatch' and
        value.get('head_branch')=='main' and re.fullmatch(r'[0-9a-f]{40}',value.get('head_sha','')),'producer_identity')
    require(value.get('status')=='completed' and value.get('conclusion')=='success','producer_not_completed_successfully')
    return {k:value[k] for k in ('id','run_attempt','head_sha','status','conclusion','path')}


def retrieve(repo,run,attempt,destination,fixture=None):
    destination=durable_path(destination,fixture)
    destination.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
    staging=Path(tempfile.mkdtemp(prefix='.'+destination.name+'-',dir=destination.parent));os.chmod(staging,0o700)
    (staging/'restricted').mkdir(mode=0o700)
    try:
        api=GitHub(repo,staging/'restricted/api',fixture,budget=300)
        metadata,_=api.get('repos/'+repo);require(metadata.get('full_name')==repo and type(metadata.get('id')) is int,'repository_identity');api.repo_id=metadata['id']
        before,_=api.get(api.path('actions/runs/'+str(run)));identity=run_identity(before,repo,run,attempt)
        detail,_=api.get(api.path(f'actions/runs/{run}/attempts/{attempt}'));require(run_identity(detail,repo,run,attempt)==identity,'producer_attempt_changed')
        artifacts=api.pages(f'actions/runs/{run}/artifacts?per_page=100','artifacts')
        prefix=f'rindle-readiness-digest-{run}-{attempt}-'
        sidecars=[a for a in artifacts if a.get('name','').startswith(prefix)]
        require(len(sidecars)==1,'producer_sidecar_missing_or_ambiguous');sidecar_artifact=sidecars[0]
        def download(artifact,limit):
            w=artifact.get('workflow_run',{})
            require(artifact.get('expired') is False and type(artifact.get('id')) is int and artifact['id']>0 and w.get('id')==run and
                w.get('head_sha')==identity['head_sha'] and w.get('repository_id')==api.repo_id and
                w.get('head_repository_id')==api.repo_id,'artifact_identity')
            expected=artifact.get('digest');require(isinstance(expected,str) and re.fullmatch(r'sha256:[0-9a-f]{64}',expected),'artifact_digest_unavailable')
            raw,_=api.get(api.path('actions/artifacts/'+str(artifact['id'])+'/zip'),binary=True,limit=limit)
            require('sha256:'+digest(raw)==expected,'artifact_transport_digest');return raw
        sidecar_raw=download(sidecar_artifact,2_000_000);sidecar_bytes=zip_member(sidecar_raw,SIDECAR_FILE,1_000_000);sidecar=json_bytes(sidecar_bytes)
        mode='fixture' if fixture is not None else 'execution'
        snapshot=sidecar.get('schema')=='rindle-readiness-producer-digest-v2'
        require(sidecar.get('schema') in (SIDECAR_SCHEMA,'rindle-readiness-producer-digest-v2') and sidecar.get('repository')==repo and
            (sidecar.get('producer_head_sha')==identity['head_sha'] and re.fullmatch(r'[0-9a-f]{40}',sidecar.get('subject_sha','')) if snapshot else sidecar.get('subject_sha')==identity['head_sha']) and
            sidecar.get('run_id')==run and sidecar.get('run_attempt')==attempt and sidecar.get('workflow')==WORKFLOW and sidecar.get('workflow_name')==WORKFLOW_NAME and
            sidecar.get('event')=='workflow_dispatch' and sidecar.get('branch')=='main' and sidecar.get('evidence_mode')==mode and
            sidecar.get('sidecar_artifact_name')==sidecar_artifact['name'] and sidecar.get('archive_file')==ARCHIVE_FILE,'producer_sidecar_identity')
        nonce=sidecar_artifact['name'][len(prefix):]
        require(re.fullmatch(r'[0-9a-f]{16}',nonce) and sidecar.get('archive_artifact_name')==f'rindle-readiness-archive-{run}-{attempt}-{nonce}', 'producer_sidecar_identity')
        archives=[a for a in artifacts if a.get('name')==sidecar['archive_artifact_name']]
        require(len(archives)==1,'producer_archive_missing_or_ambiguous')
        archive_raw=download(archives[0],256_000_000);archive=zip_member(archive_raw,ARCHIVE_FILE,256_000_000)
        require(digest(archive)==sidecar.get('archive_sha256'),'producer_archive_digest')
        bundle=staging/'bundle';bundle.mkdir(mode=0o700);manifest,objects=unpack(archive,bundle)
        require(digest(objects['manifest.json'])==sidecar.get('manifest_sha256'),'producer_manifest_digest')
        require(manifest.get('repository')==repo and manifest.get('subject_sha')==sidecar['subject_sha'] and manifest.get('evidence_mode')==mode and manifest.get('state')=='complete','bundle_manifest_identity')
        require(snapshot==(manifest.get('policy')=='rindle-snapshot-v2'),'bundle_policy_identity')
        if snapshot:
            from readiness_subject import observe,CONTROL_PATHS
            observe(api,sidecar['subject_sha'])
            for path in CONTROL_PATHS:
                require(api.contents(path,identity['head_sha'])==(ROOT/path).read_bytes(),'producer_policy_mismatch')
        scan_public(objects,os.environ)
        after,_=api.get(api.path('actions/runs/'+str(run)));require(run_identity(after,repo,run,attempt)==identity,'producer_attempt_changed')
        write_new(staging/ARCHIVE_FILE,archive);write_new(staging/SIDECAR_FILE,sidecar_bytes)
        locator={'schema':'rindle-readiness-durable-locator-v1','repository':repo,'subject_sha':sidecar['subject_sha'],'run_id':run,'run_attempt':attempt,
            'workflow':WORKFLOW,'workflow_name':WORKFLOW_NAME,'archive_artifact_id':archives[0]['id'],'sidecar_artifact_id':sidecar_artifact['id'],
            'archive_artifact_digest':archives[0]['digest'],'sidecar_artifact_digest':sidecar_artifact['digest'],
            'producer_sidecar_sha256':digest(sidecar_bytes),'archive_sha256':sidecar['archive_sha256'],'manifest_sha256':sidecar['manifest_sha256'],
            'manifest_path':'bundle/manifest.json','archive_path':ARCHIVE_FILE,'sidecar_path':SIDECAR_FILE,
            'evidence_mode':mode,'bytes_verified':True,'requirements_credit':False,'storage_scope':'fixture_only' if fixture is not None else 'durable_maintainer_host',
            'retrieved_at':now()}
        if snapshot:locator['producer_head_sha']=identity['head_sha']
        write_new(staging/'locator.json',locator)
        for path in staging.rglob('*'):
            if path.is_file():
                with open(path,'rb') as stream:os.fsync(stream.fileno())
        require(digest((staging/ARCHIVE_FILE).read_bytes())==sidecar['archive_sha256'] and
            digest((bundle/'manifest.json').read_bytes())==sidecar['manifest_sha256'],'durable_readback_failed')
        for directory in sorted((p for p in staging.rglob('*') if p.is_dir()),key=lambda p:len(p.parts),reverse=True):
            fd=os.open(directory,os.O_RDONLY)
            try:os.fsync(fd)
            finally:os.close(fd)
        fd=os.open(staging,os.O_RDONLY)
        try:os.fsync(fd)
        finally:os.close(fd)
        require(not destination.exists(),'durable_destination_exists');os.rename(staging,destination)
        fd=os.open(destination.parent,os.O_RDONLY)
        try:os.fsync(fd)
        except OSError:
            os.rename(destination,staging)
            raise
        finally:os.close(fd)
        return locator
    except BaseException:
        # Preserve restricted diagnostics without presenting a partial destination as durable.
        raise


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);subs=parser.add_subparsers(dest='operation',required=True)
    p=subs.add_parser('prepare');p.add_argument('--manifest',required=True);p.add_argument('--output',required=True)
    p=subs.add_parser('retrieve');p.add_argument('--repo',required=True);p.add_argument('--run-id',type=int,required=True);p.add_argument('--attempt',type=int,required=True)
    p.add_argument('--destination',required=True);p.add_argument('--fixture')
    args=parser.parse_args(argv)
    try:
        value=prepare(args.manifest,args.output) if args.operation=='prepare' else retrieve(args.repo,args.run_id,args.attempt,args.destination,args.fixture)
        print('prepared' if args.operation=='prepare' else 'durable_bytes_verified');return 0
    except (NotReady,OSError,ValueError,KeyError,TypeError,IndexError) as exc:
        print('not_ready: '+(Closure.public_reason(str(exc)) if isinstance(exc,NotReady) else 'retention_unavailable'));return 1

if __name__=='__main__':raise SystemExit(main())
