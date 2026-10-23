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
    def __init__(self,repo,subject,output,fixture=None,only=None):
        require(re.fullmatch(r'[0-9a-f]{40}',subject),'invalid_subject')
        self.repo,self.subject,self.output=repo,subject,Path(output).resolve()
        require(not self.output.exists() and not self.output.is_relative_to(ROOT),'output_must_be_new_external_directory')
        self.output.mkdir(mode=0o700,parents=True)
        self.portable=self.output/'portable';self.portable.mkdir(mode=0o700)
        self.fixture=fixture
        self.api=None
        self.mode='fixture' if fixture is not None else 'execution'
        self.only=only
        self.inputs={};self.artifacts={}

    def main(self):
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

    def latest(self,workflow,event):
        query=urlencode({'head_sha':self.subject,'event':event,'branch':'main','per_page':100})
        values=self.api.pages('actions/workflows/'+workflow+'/runs?'+query,'workflow_runs',cap=999)
        # Validate every returned item; a server/query mismatch is never silently filtered away.
        for run in values:
            require(run.get('head_sha')==self.subject and run.get('event')==event and run.get('head_branch')=='main' and
                run.get('repository',{}).get('full_name')==self.repo and run.get('name')==('CI' if event=='push' else 'Nightly') and
                run.get('path')=='.github/workflows/'+workflow and isinstance(run.get('id'),int) and
                isinstance(run.get('run_attempt'),int) and run['id']>0 and run['run_attempt']>0 and
                isinstance(run.get('created_at'),str),'workflow_identity')
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

    def incident(self,run):
        artifacts=self.api.pages('actions/runs/'+str(run['id'])+'/artifacts?per_page=100','artifacts')
        name=f"nightly-incident-verdict-{run['id']}-{run['run_attempt']}"
        matches=[a for a in artifacts if a.get('name')==name]
        require(len(matches)==1,'incident_artifact_missing')
        artifact=matches[0]
        require(artifact.get('expired') is False and isinstance(artifact.get('id'),int) and artifact['id']>0 and
                artifact.get('workflow_run',{}).get('id')==run['id'] and artifact['workflow_run'].get('head_sha')==self.subject,
                'incident_artifact_identity')
        raw,_=self.api.get(self.api.path('actions/artifacts/'+str(artifact['id'])+'/zip'),binary=True)
        expected=artifact.get('digest')
        require(expected is None or expected=='sha256:'+digest(raw),'incident_artifact_digest')
        try:
            with zipfile.ZipFile(io.BytesIO(raw)) as archive:
                items=archive.infolist()
                require(len(items)==1 and items[0].filename=='nightly-incident-verdict.json' and
                        items[0].file_size<=1024*1024 and not items[0].is_dir() and
                        (items[0].external_attr>>16)&0o170000 != 0o120000,'incident_artifact_unsafe')
                data=archive.read(items[0])
        except (zipfile.BadZipFile,RuntimeError,OSError) as exc:
            raise NotReady('incident_artifact_unsafe') from exc
        path=self.portable/'artifacts'/(digest(raw)+'.zip')
        if not path.exists():write_new(path,raw)
        require(path.read_bytes()==raw,'artifact_changed')
        ref=reference(self.portable,path)
        if ref not in self.artifacts.setdefault('nightly-scheduled',[]):self.artifacts['nightly-scheduled'].append(ref)
        return {'incident':json_bytes(data),'incident_artifact':ref,'incident_artifact_id':artifact['id'],'incident_artifact_sha256':digest(raw)}

    def run_observation(self,workflow,event):
        run=self.latest(workflow,event);self.detail(run,event)
        jobs=self.api.pages(f"actions/runs/{run['id']}/attempts/{run['run_attempt']}/jobs?per_page=100",'jobs')
        normalized=[]
        for job in jobs:
            require(job.get('run_id')==run['id'] and job.get('run_attempt')==run['run_attempt'] and
                    job.get('head_sha')==self.subject,'job_identity')
            normalized.append({k:job.get(v) for k,v in [('id','id'),('name','name'),('state','status'),('conclusion','conclusion')]})
        topology=policy({'operation':'topology','yaml':self.inputs['.github/workflows/'+workflow],
            'context':{'repository':self.repo,'event':event,'branch':'main'}})
        result={'repository':self.repo,'subject_sha':self.subject,'workflow':workflow,'name':run['name'],
            'event':event,'branch':'main','run_id':run['id'],'attempt':run['run_attempt'],'state':run['status'],
            'conclusion':run['conclusion'],'expected_jobs':[j['name'] for j in topology['jobs']],
            'jobs':sorted(normalized,key=lambda j:(j['name'],j['id'])),
            'topology_sha256':topology['workflow_sha256'],'topology_resolved':True,
            'latest_run_id':run['id'],'rechecked_attempt':run['run_attempt']}
        if event=='schedule': result.update(self.incident(run))
        self.detail(run,event)
        latest=self.latest(workflow,event)
        require(latest['id']==run['id'],'newer_run_observed')
        require(all(latest.get(k)==run.get(k) for k in ('run_attempt','status','conclusion','workflow_id')), 'attempt_changed')
        policy({'operation':'validate','id':'ci-main' if event=='push' else 'nightly-scheduled',
                'normalized':result,'inputs':self.inputs})
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
        result={'ci-main':self.run_observation('ci.yml','push')}
        if self.only!='ci':
            result['nightly-scheduled']=self.run_observation('nightly.yml','schedule')
            result['protection']=self.protection()
        return result

    def run(self):
        started=now(); verdict={'schema_version':1,'verdict':'not_ready','repository':self.repo,
            'subject_sha':self.subject,'evidence_mode':self.mode,'requirements_credit':False}
        try:
            self.api=GitHub(self.repo,self.output/'restricted',self.fixture)
            self.initialize()
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
                    'pages':len(self.api.calls),'policy':POLICY,'normalized':value,'observation_interval':interval,
                    'before_sha256':refs[0]['sha256'],'after_sha256':refs[1]['sha256'],'observations':refs}
                sources[id]={'source':source,'references':refs+self.artifacts.get(id,[])}
            write_new(self.portable/'sources.json',{'repository':self.repo,'subject_sha':self.subject,'evidence_mode':self.mode,
                'requirements_credit':False,'numeric_speed':self.timing,'observation_interval':interval,'sources':sources})
            verdict.update(verdict='collected',reason='remote_sources_collected',sources=list(sources))
            code=0
        except NotReady as exc:
            verdict['reason']=str(exc);code=1
        except (OSError,ValueError,KeyError,TypeError,IndexError) as exc:
            verdict['reason']='malformed_remote_evidence';code=1
        verdict['observation_interval']={'started_at':started,'completed_at':now()}
        if verdict.get('reason')=='scheduled_run_missing':
            verdict['next_observation']='next eligible cron 27 7 * * * on the same main subject; dispatch grants no acceptance'
        write_new(self.output/'verdict.json',verdict)
        print(verdict['verdict']+': '+verdict['reason'])
        return code


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',required=True);parser.add_argument('--subject',required=True)
    parser.add_argument('--output',required=True);parser.add_argument('--fixture');parser.add_argument('--only',choices=['ci'])
    args=parser.parse_args()
    try:return Collector(args.repo,args.subject,args.output,args.fixture,args.only).run()
    except NotReady as exc: print('not_ready: '+str(exc));return 1


if __name__=='__main__':raise SystemExit(main())
