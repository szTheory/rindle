#!/usr/bin/env python3
"""Observe exact-subject CI, scheduled Nightly and effective main protection, read-only."""
import argparse
import base64
import io
import os
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile
import datetime as dt
from urllib.parse import urlencode

from exact_head_readiness import ROOT, TOOLCHAIN_ENV, NotReady, canonical, digest, now, read_json, reference, require, write_new
from readiness_github import GitHub, json_bytes

POLICY = 'rindle-exact-head-v1'
HISTORICAL_QUALIFICATION_SHA = 'aba8565ebfb97fd366efd94c691a977b3c29c78e232e2dda7cb338d69997abce'
TIMING_DEFERRAL_SHA = 'c15572c572a8ca2e7dbdb564b6a50516f1822b6117c2d2430bad1c0f973b9af3'


def policy(request):
    with tempfile.TemporaryDirectory(prefix='rindle-readiness-policy-') as tmp:
        path=Path(tmp)/'request.json'; write_new(path,request)
        try:
            result=subprocess.run(['mix','run','--no-start','--no-compile','--no-deps-check',
                str(ROOT/'scripts/maintainer/readiness_workflow.exs'),'--request',str(path)],
                cwd=ROOT,env={**os.environ,**TOOLCHAIN_ENV},stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,
                timeout=45,check=False)
            require(result.returncode==0 and len(result.stdout)<2*1024*1024,'policy_unavailable')
            value=json_bytes(result.stdout.decode().splitlines()[-1])
        except (OSError,subprocess.TimeoutExpired,IndexError,UnicodeError) as exc:
            raise NotReady('policy_unavailable') from exc
        require(value.get('ok') is True,value.get('reason','unknown_topology'))
        return value.get('value')


class Collector:
    def __init__(self,repo,subject,output,fixture=None,only=None,snapshot=False):
        require(re.fullmatch(r'[0-9a-f]{40}',subject),'invalid_subject')
        self.repo,self.subject,self.output=repo,subject,Path(output).resolve()
        self.snapshot=snapshot
        self.policy_name='rindle-snapshot-v3' if snapshot else POLICY
        require(not self.output.exists() and not self.output.is_relative_to(ROOT),'output_must_be_new_external_directory')
        self.output.mkdir(mode=0o700,parents=True)
        self.portable=self.output/'portable';self.portable.mkdir(mode=0o700)
        self.fixture=fixture
        self.api=None
        self.mode='fixture' if fixture is not None else 'execution'
        self.only=only
        self.inputs={};self.artifacts={}

    def main(self):
        if self.snapshot:
            from readiness_subject import observe
            self.snapshot_binding=observe(self.api,self.subject)
            return self.snapshot_binding['current_main_sha']
        value,_=self.api.get(self.api.path('git/ref/heads/main'))
        require(value.get('ref')=='refs/heads/main' and value.get('object',{}).get('type')=='commit' and
                value['object']['sha']==self.subject,'main_changed')

    def initialize(self):
        metadata,_=self.api.get('repos/'+self.repo)
        require(metadata.get('full_name')==self.repo and metadata.get('default_branch')=='main' and
                isinstance(metadata.get('id'),int) and metadata.get('owner',{}).get('type') in ('User','Organization'), 'repository_identity')
        self.api.repo_id=metadata['id'];self.metadata=metadata
        self.main()
        paths=['.github/workflows/ci.yml','.github/workflows/release.yml'] if self.only=='ci' else ['.github/workflows/ci.yml',
                '.github/workflows/nightly.yml','.github/workflows/release.yml','config/ci_required_checks.json']
        paths += ['.planning/phases/136-measured-quality-and-ci-ratchets/136-SPEED-DEFERRAL.json',
                  '.planning/phases/136-measured-quality-and-ci-ratchets/136-QUALIFICATION-CLOSEOUT.json']
        for path in paths:
            raw=self.api.contents(path,self.subject)
            self.inputs[path]=raw.decode()
            write_new(self.portable/'inputs'/path,raw)
        require(digest(self.inputs[paths[-1]].encode())==HISTORICAL_QUALIFICATION_SHA,'historical_timing_receipt_changed')
        require(digest(self.inputs[paths[-2]].encode())==TIMING_DEFERRAL_SHA,'timing_deferral_drift')
        deferral=json_bytes(self.inputs[paths[-2]]);historical=json_bytes(self.inputs[paths[-1]])
        require(deferral.get('acceptance_status')=='deferred_unfinished' and deferral.get('acceptance_credit') is False and
                historical.get('outcome')=='blocked','timing_deferral_drift')
        self.timing={'state':'deferred_unfinished','acceptance_credit':False,'requirement':'CI-16',
            'follow_up':deferral.get('follow_up'),'original_qualification_outcome':'blocked',
            'deferral':reference(self.portable,self.portable/'inputs'/paths[-2]),
            'original_qualification':reference(self.portable,self.portable/'inputs'/paths[-1])}

    def latest(self,workflow,event,subject='candidate',missing=True):
        subject=self.subject if subject=='candidate' else subject
        filters={'event':event,'branch':'main','per_page':100}
        if subject is not None:filters={'head_sha':subject,**filters}
        query=urlencode(filters)
        values=self.api.pages('actions/workflows/'+workflow+'/runs?'+query,'workflow_runs',cap=999)
        # Validate every returned item; a server/query mismatch is never silently filtered away.
        for run in values:
            require((subject is None or run.get('head_sha')==subject) and re.fullmatch(r'[0-9a-f]{40}',run.get('head_sha','')) and run.get('event')==event and run.get('head_branch')=='main' and
                run.get('repository',{}).get('full_name')==self.repo and run.get('name')==('CI' if event=='push' else 'Nightly') and
                run.get('path')=='.github/workflows/'+workflow and isinstance(run.get('id'),int) and
                isinstance(run.get('run_attempt'),int) and run['id']>0 and run['run_attempt']>0 and
                isinstance(run.get('created_at'),str),'workflow_identity')
        if not values and not missing:return None
        require(values,'scheduled_run_missing' if event=='schedule' else 'ci_run_missing')
        require(len({r['id'] for r in values})==len(values),'duplicate_run')
        return max(values,key=lambda r:(r['created_at'],r['id']))

    def detail(self,run,event):
        value,_=self.api.get(self.api.path('actions/runs/'+str(run['id'])))
        keys=('id','run_attempt','head_sha','event','head_branch','status','conclusion','path','workflow_id')
        require(all(value.get(k)==run.get(k) for k in keys),'attempt_changed')
        require(value.get('repository',{}).get('full_name')==self.repo and value.get('name')==run.get('name'),'workflow_identity')
        require(value.get('status')=='completed' and value.get('conclusion')=='success','latest_attempt_not_green')
        return value

    def incident(self,run,role='nightly-scheduled',key='incident'):
        artifacts=self.api.pages('actions/runs/'+str(run['id'])+'/artifacts?per_page=100','artifacts')
        prefix='nightly-incident-verdict' if key=='incident' else 'nightly-incident-replay-checkpoint'
        leaf='nightly-incident-verdict.json' if key=='incident' else 'nightly-incident-checkpoint.json'
        name=f"{prefix}-{run['id']}-{run['run_attempt']}"
        matches=[a for a in artifacts if a.get('name')==name]
        require(len(matches)==1,'incident_artifact_missing')
        artifact=matches[0]
        require(artifact.get('expired') is False and isinstance(artifact.get('id'),int) and artifact['id']>0 and
                artifact.get('workflow_run',{}).get('id')==run['id'] and artifact['workflow_run'].get('head_sha')==run['head_sha'],
                'incident_artifact_identity')
        if self.snapshot:
            require(isinstance(artifact.get('expires_at'),str) and
                dt.datetime.fromisoformat(artifact['expires_at'].replace('Z','+00:00')) >=
                dt.datetime.fromisoformat(self.observed_at.replace('Z','+00:00'))+dt.timedelta(hours=1),'incident_artifact_expiring')
        raw,_=self.api.get(self.api.path('actions/artifacts/'+str(artifact['id'])+'/zip'),binary=True)
        expected=artifact.get('digest')
        if self.snapshot:
            require(isinstance(expected,str) and re.fullmatch(r'sha256:[0-9a-f]{64}',expected),
                    'incident_artifact_digest_unavailable')
        require(expected is None or expected=='sha256:'+digest(raw),'incident_artifact_digest')
        try:
            with zipfile.ZipFile(io.BytesIO(raw)) as archive:
                items=archive.infolist()
                require(len(items)==1 and items[0].filename==leaf and
                        items[0].file_size<=1024*1024 and not items[0].is_dir() and
                        (items[0].external_attr>>16)&0o170000 != 0o120000,'incident_artifact_unsafe')
                data=archive.read(items[0])
        except (zipfile.BadZipFile,RuntimeError,OSError) as exc:
            raise NotReady('incident_artifact_unsafe') from exc
        path=self.portable/'artifacts'/(digest(raw)+'.zip')
        if not path.exists():write_new(path,raw)
        require(path.read_bytes()==raw,'artifact_changed')
        ref=reference(self.portable,path)
        if ref not in self.artifacts.setdefault(role,[]):self.artifacts[role].append(ref)
        return {key:json_bytes(data),key+'_artifact':ref,key+'_artifact_id':artifact['id'],key+'_artifact_sha256':digest(raw),**({key+'_artifact_expires_at':artifact['expires_at']} if self.snapshot else {})}

    def qualification_run(self):
        runs=[r for event in ('schedule','workflow_dispatch')
              if (r:=self.latest('nightly.yml',event,missing=False)) is not None]
        require(runs,'nightly_qualification_missing')
        return max(runs,key=lambda r:(r['created_at'],r['id']))

    def run_observation(self,workflow,event,run=None,role=None,global_schedule=False):
        run=run or self.latest(workflow,event);self.detail(run,event)
        role=role or ('ci-main' if event=='push' else 'nightly-scheduled')
        jobs=self.api.pages(f"actions/runs/{run['id']}/attempts/{run['run_attempt']}/jobs?per_page=100",'jobs')
        normalized=[]
        for job in jobs:
            require(job.get('run_id')==run['id'] and job.get('run_attempt')==run['run_attempt'] and
                    job.get('head_sha')==run['head_sha'],'job_identity')
            row={k:job.get(v) for k,v in [('id','id'),('name','name'),('state','status'),('conclusion','conclusion')]}
            if self.snapshot and workflow=='nightly.yml':
                row['steps']=[{k:s.get(k) for k in ('name','number','status','conclusion')} for s in job.get('steps',[])]
            normalized.append(row)
        topology=policy({'operation':'topology','yaml':self.inputs['.github/workflows/'+workflow],
            'context':{'repository':self.repo,'event':event,'branch':'main'}})
        result={'repository':self.repo,'subject_sha':run['head_sha'],'workflow':workflow,'name':run['name'],
            'event':event,'branch':'main','run_id':run['id'],'attempt':run['run_attempt'],'state':run['status'],
            'conclusion':run['conclusion'],'expected_jobs':[j['name'] for j in topology['jobs']],
            'jobs':sorted(normalized,key=lambda j:(j['name'],j['id'])),
            'topology_sha256':topology['workflow_sha256'],'topology_resolved':True,
            'latest_run_id':run['id'],'rechecked_attempt':run['run_attempt']}
        if self.snapshot and workflow=='nightly.yml':
            result.update(created_at=run['created_at'],completed_at=run['updated_at'])
        if event=='schedule': result.update(self.incident(run,role))
        self.detail(run,event)
        latest=(self.latest(workflow,event,subject=None) if global_schedule else
                self.qualification_run() if role=='nightly-qualification' else self.latest(workflow,event))
        require(latest['id']==run['id'],'newer_run_observed')
        require(all(latest.get(k)==run.get(k) for k in ('run_attempt','status','conclusion','workflow_id')), 'attempt_changed')
        policy({'operation':'validate','id':role if role!='scheduled-incident-health' else 'nightly-scheduled',
                'normalized':result,'inputs':self.inputs})
        return result

    def incidents(self):
        # Preserve the existing incident manager's exact gh JSON projection for its
        # checkpoint digest. REST pagination independently proves inventory/comment
        # completeness; a CLI truncation cannot manufacture an empty/partial history.
        rows=self.api.pages('issues?state=all&labels=nightly-failure&per_page=100&sort=created&direction=asc')
        require(len(rows)<100 and not any('pull_request' in r for r in rows),'incident_inventory_limit')
        if self.fixture is not None:
            values=read_json(Path(self.fixture)/'incident-inventory.json')
        else:
            result=subprocess.run(['gh','issue','list','--repo',self.repo,'--state','all','--label','nightly-failure',
                '--limit','100','--json','number,title,state,body,comments'],stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,timeout=35,check=False)
            require(result.returncode==0 and len(result.stdout)<2*1024*1024,'incident_inventory_unavailable')
            write_new(self.output/'restricted'/('incidents-'+str(len(self.api.calls))+'.json'),result.stdout)
            values=json_bytes(result.stdout)
        require(isinstance(values,list) and len(values)==len(rows) and
            len({v['number'] for v in values})==len(values),'incident_inventory_incomplete')
        for row in rows:
            matches=[v for v in values if v['number']==row.get('number')]
            require(len(matches)==1,'incident_inventory_incomplete');v=matches[0]
            require(v['title']==row.get('title') and v['body']==row.get('body') and
                v['state']==row.get('state','').upper(),'incident_inventory_changed')
            comments=self.api.pages(f"issues/{row['number']}/comments?per_page=100")
            require(row.get('comments')==len(comments) and
                [(s.get('node_id'),s.get('body')) for s in comments]==[(s.get('id'),s.get('body')) for s in v['comments']],
                'incident_comments_incomplete')
            for rest,comment in zip(comments,v['comments']):
                user=rest.get('user') or {};author=comment.get('author') or {}
                expected=user.get('login','').removesuffix('[bot]')
                require(author.get('login')==expected and
                    (expected!='github-actions' or user.get('type')=='Bot'),'incident_author_identity')
        return values

    def scheduled_health(self):
        workflow,_=self.api.get(self.api.path('actions/workflows/nightly.yml'))
        require(workflow.get('state')=='active' and workflow.get('path')=='.github/workflows/nightly.yml',
            'scheduled_workflow_inactive')
        run=self.latest('nightly.yml','schedule',subject=None)
        require(run.get('workflow_id')==workflow.get('id'),'workflow_identity')
        if run['status']!='completed':
            age=(dt.datetime.fromisoformat(self.observed_at.replace('Z','+00:00'))-
                 dt.datetime.fromisoformat(run['created_at'].replace('Z','+00:00'))).total_seconds()
            raise NotReady('scheduled_health_stalled' if age>=7200 else 'scheduled_health_pending')
        health=self.run_observation('nightly.yml','schedule',run,'scheduled-incident-health',True)
        paths=policy({'operation':'nightly-controls'})
        files={};identity={};witness={}
        for path in paths:
            raw=self.api.contents(path,run['head_sha'])
            target=self.portable/'health-controls'/path
            if not target.exists():write_new(target,raw)
            require(target.read_bytes()==raw,'scheduled_health_control_mismatch')
            ref=reference(self.portable,target);files[path]=ref;witness[path]=digest(raw)
            identity[path]=digest(self.inputs[path].encode())
            if ref not in self.artifacts.setdefault('scheduled-incident-health',[]):self.artifacts['scheduled-incident-health'].append(ref)
        result={'repository':self.repo,'subject_sha':self.subject,'health_run':health,
            'observed_at':self.observed_at,'control_identity':identity,'health_control_identity':witness,
            'health_control_files':files,'incidents':self.incidents(),**self.incident(run,'scheduled-incident-health','checkpoint')}
        policy({'operation':'validate','id':'scheduled-incident-health','normalized':result,'inputs':self.inputs})
        return result

    def protection(self):
        config=json_bytes(self.inputs['config/ci_required_checks.json'])
        require(config=={'schema_version':'rindle-required-checks-v1','workflow':{'file':'ci.yml','name':'CI','job_id':'ci-summary'},
                         'contexts':['CI Summary']},'protection_policy_drift')
        classic,_=self.api.get(self.api.path('branches/main/protection'))
        require(classic.get('required_pull_request_reviews') is None and classic.get('restrictions') is None and
                all(classic.get(k,{}).get('enabled',False) is False for k in ('required_linear_history','required_conversation_resolution','lock_branch')), 'protection_drift')
        required=classic.get('required_status_checks')
        require(isinstance(required,dict),'protection_unavailable')
        checks=required.get('checks');contexts=required.get('contexts')
        require(isinstance(checks,list) and isinstance(contexts,list) and
                sorted(contexts)==sorted(c.get('context') for c in checks),'protection_binding_unavailable')
        effective=self.api.pages('rules/branches/main?per_page=100')
        rulesets=self.api.pages('rulesets?includes_parents=true&per_page=100')
        active=[]
        # Effective branch rules identify the actually applicable active rulesets across parents.
        ids={r.get('ruleset_id') for r in effective}
        require(None not in ids and len({r.get('id') for r in rulesets})==len(rulesets),'ruleset_identity')
        for id in sorted(ids):
            matches=[r for r in rulesets if r.get('id')==id]
            require(len(matches)==1,'ruleset_visibility')
            detail,_=self.api.get(self.api.path('rulesets/'+str(id)+'?includes_parents=true'))
            require(detail.get('id')==id and detail.get('enforcement')=='active','ruleset_visibility')
            active.append(detail)
        # Effective rule parameters are validated by the same immutable policy as receipt replay.
        # Organization owners additionally need parent enumeration; an empty public list is not proof.
        if self.metadata['owner']['type']=='Organization':
            require(self.metadata.get('permissions',{}).get('admin') is True,'organization_visibility')
        allowances=classic.get('required_pull_request_reviews',{}).get('bypass_pull_request_allowances') if isinstance(classic.get('required_pull_request_reviews'),dict) else None
        bypass=[]
        if allowances:
            require(isinstance(allowances,dict),'protection_drift')
            bypass=[{'kind':k,'actor':v} for k,values in allowances.items() for v in values]
        result={'repository':self.repo,'subject_sha':self.subject,'classic_visible':True,'rulesets_visible':True,
            'organization_visible':True,'organization_visibility':'not-applicable-user-owner' if self.metadata['owner']['type']=='User' else 'authenticated-parent-enumeration',
            'enforced':True,'strict':required.get('strict'),'classic_admin_enforced':classic.get('enforce_admins',{}).get('enabled'),
            'bypass_actors':bypass,'effective_checks':sorted(checks,key=lambda c:c.get('context','')),
            'active_rulesets':active,'effective_rules':effective,'classic_policy':classic,'enumerated_rulesets':rulesets}
        policy({'operation':'validate','id':'protection','normalized':result,'inputs':self.inputs})
        return result

    def observations(self):
        self.current_proof='ci-main'
        result={'ci-main':self.run_observation('ci.yml','push')}
        if self.only!='ci':
            if self.snapshot:
                self.current_proof='nightly-qualification'
                run=self.qualification_run()
                result['nightly-qualification']=self.run_observation('nightly.yml',run['event'],run,'nightly-qualification')
                self.current_proof='scheduled-incident-health'
                result['scheduled-incident-health']=self.scheduled_health()
            else:
                self.current_proof='nightly-scheduled'
                result['nightly-scheduled']=self.run_observation('nightly.yml','schedule')
            self.current_proof='protection'
            result['protection']=self.protection()
        return result

    def run(self):
        started=now();self.observed_at=started; verdict={'schema_version':1,'verdict':'not_ready','repository':self.repo,
            'subject_sha':self.subject,'evidence_mode':self.mode,'requirements_credit':False}
        try:
            self.api=GitHub(self.repo,self.output/'restricted',self.fixture)
            self.initialize()
            if self.snapshot and self.only!='ci':
                for path in policy({'operation':'nightly-controls'}):
                    if path not in self.inputs:
                        raw=self.api.contents(path,self.subject);self.inputs[path]=raw.decode()
                        write_new(self.portable/'inputs'/path,raw)
            before=self.observations();after=self.observations();self.main()
            require(before==after,'source_changed')
            interval={'started_at':started,'completed_at':now()}
            sources={}
            for id,value in before.items():
                refs=[]
                for position in ('before','after'):
                    path=self.portable/'observations'/(id+'-'+position+'.json');write_new(path,value)
                    refs.append(reference(self.portable,path))
                source={'complete':True,'authenticated':True,'query':'GET exact-subject/'+id+'; all pages; current-attempt; two full reads',
                    'pages':len(self.api.calls),'policy':self.policy_name,'normalized':value,'observation_interval':interval,
                    'before_sha256':refs[0]['sha256'],'after_sha256':refs[1]['sha256'],'observations':refs}
                sources[id]={'source':source,'references':refs+self.artifacts.get(id,[])}
            write_new(self.portable/'sources.json',{'repository':self.repo,'subject_sha':self.subject,'evidence_mode':self.mode,
                'requirements_credit':False,'numeric_speed':self.timing,'observation_interval':interval,'sources':sources})
            verdict.update(verdict='collected',reason='remote_sources_collected',sources=list(sources))
            code=0
        except NotReady as exc:
            verdict['reason']=str(exc);verdict['failed_proof']=getattr(self,'current_proof',None);code=1
        except (OSError,ValueError,KeyError,TypeError,IndexError) as exc:
            verdict['reason']='malformed_remote_evidence';code=1
        verdict['observation_interval']={'started_at':started,'completed_at':now()}
        if verdict.get('reason')=='scheduled_run_missing':
            verdict['next_observation']=('newest real global cron 27 7 * * * under matching controls; preserve candidate qualification' if self.snapshot else 'next eligible cron 27 7 * * * on the same main subject; dispatch grants no acceptance')
        if verdict.get('reason')=='nightly_qualification_missing':
            verdict['next_operation']=['bash','scripts/maintainer/exact_head_readiness.sh','capture-nightly','--repo',self.repo,'--output','NEW_EXTERNAL_CAPTURE']
            verdict['may_require_new_subject']=True
        write_new(self.output/'verdict.json',verdict)
        print(verdict['verdict']+': '+verdict['reason'])
        return code


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',required=True);parser.add_argument('--subject',required=True)
    parser.add_argument('--output',required=True);parser.add_argument('--snapshot',action='store_true');parser.add_argument('--fixture');parser.add_argument('--only',choices=['ci'])
    args=parser.parse_args()
    try:return Collector(args.repo,args.subject,args.output,args.fixture,args.only,args.snapshot).run()
    except NotReady as exc: print('not_ready: '+str(exc));return 1


if __name__=='__main__':raise SystemExit(main())
