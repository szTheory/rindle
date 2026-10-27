#!/usr/bin/env python3
"""Read-only current disposition evidence. Private source bytes stay restricted."""
import argparse
import signal
import base64
import secrets
import datetime as dt
import os
from pathlib import Path
import re
import subprocess
import time

from exact_head_readiness import ROOT, TOOLCHAIN_ENV, NotReady, canonical, digest, now, read_json, reference, require, write_new
from readiness_github import GitHub, json_bytes
from collect_readiness_runs import Collector as RunCollector, policy

LEDGER = '.planning/INBOX-LEDGER.json'
POLICY = 'rindle-exact-head-v1'


def stable_records(values, id_key):
    require(isinstance(values,list) and all(isinstance(v,dict) for v in values),'incomplete_inventory')
    ids=[v.get(id_key) for v in values]
    require(all(type(id) is int and id>0 for id in ids) and len(set(ids))==len(ids),'ambiguous_inventory_identity')
    # Stable IDs disambiguate equal timestamps; list order is not source identity.
    return sorted(values,key=lambda v:v[id_key])


class RemoteCollector:
    def __init__(self,repo,subject,output,fixture=None,only=None,snapshot=False):
        require(re.fullmatch(r'[0-9a-f]{40}',subject),'invalid_subject')
        self.repo,self.subject,self.output=repo,subject,Path(output).resolve()
        self.snapshot=snapshot
        self.policy_name='rindle-snapshot-v3' if snapshot else POLICY
        require(not self.output.exists() and not self.output.is_relative_to(ROOT),'output_must_be_new_external_directory')
        self.output.mkdir(mode=0o700,parents=True)
        self.portable=self.output/'portable';self.private=self.output/'restricted'
        self.portable.mkdir(mode=0o700);self.private.mkdir(mode=0o700)
        self.fixture,self.only=fixture,only
        self.observation=0
        self.command_count=0
        self.inputs={}
        self.current_source="repository"

    def main(self):
        if self.snapshot:
            from readiness_subject import observe
            self.snapshot_binding=observe(self.api,self.subject)
            return self.snapshot_binding['current_main_sha']
        value,_=self.api.get(self.api.path('git/ref/heads/main'))
        require(value.get('ref')=='refs/heads/main' and value.get('object',{}).get('type')=='commit' and
                value['object'].get('sha')==self.subject,'main_changed')

    def initialize(self):
        metadata,_=self.api.get('repos/'+self.repo)
        require(metadata.get('full_name')==self.repo and metadata.get('default_branch')=='main' and
                type(metadata.get('id')) is int,'repository_identity')
        self.metadata=metadata;self.api.repo_id=metadata['id'];self.main()
        self.current_source='ledger'
        raw=self.api.contents(LEDGER,self.snapshot_binding['current_main_sha'] if self.snapshot else self.subject)
        self.ledger=json_bytes(raw);self.ledger_sha=digest(raw)
        require(self.ledger.get('repo')==self.repo,'ledger_repository')
        self.ledger_path=self.private/'ledger.json';write_new(self.ledger_path,raw)
        self.validate_ledger()
        if self.only is None:
            require(metadata.get('permissions',{}).get('admin') is True,'advisory_visibility_unproved')
            for relative in ['mix.lock','examples/adoption_demo/mix.lock','.github/workflows/ci.yml',
                             '.github/workflows/release.yml','config/ci_required_checks.json']:
                raw=self.api.contents(relative,self.subject)
                self.inputs[relative]=raw.decode()
            self.hex_triggers=sorted({trigger['package'] for entry in self.ledger['items']+self.ledger['advisories']
                for trigger in [entry.get('trigger',entry.get('exception',{}).get('trigger',{}))] if trigger.get('type')=='hex_version_gte'})
            self.lock_inventory={}
            for scope,relative in [('root','mix.lock'),('examples/adoption_demo','examples/adoption_demo/mix.lock')]:
                directory=self.private/('lock-'+scope.replace('/','-'));directory.mkdir()
                lock=directory/'mix.lock';write_new(lock,self.inputs[relative].encode())
                output=directory/'inventory.json'
                code=self.command(['elixir',str(ROOT/'scripts/maintainer/readiness_hex_audit.exs'),'--inventory',str(lock),str(output)],directory,{**os.environ,**TOOLCHAIN_ENV},30)
                require(code==0,'lock_inventory_unavailable')
                self.lock_inventory[scope]=read_json(output)['packages']

    def validate_ledger(self,inventory=None):
        command=['bash',str(ROOT/'scripts/maintainer/validate_inbox_ledger.sh'),'--ledger',str(self.ledger_path)]
        if inventory is None:command+=['--offline']
        else:
            path=self.private/f'inventory-{self.observation}.json';write_new(path,inventory)
            command+=['--inventory',str(path),'--max-age-seconds','600']
        try:
            result=subprocess.run(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=25,
                env={k:v for k,v in os.environ.items() if k!='INBOX_NOW_EPOCH'},check=False)
        except (OSError,subprocess.TimeoutExpired) as exc:raise NotReady('ledger_validator_unavailable') from exc
        write_new(self.private/f'ledger-validation-{self.observation}-{inventory is not None}.log',result.stdout)
        require(result.returncode==0,'ledger_reconciliation_failed' if inventory else 'ledger_shape_invalid')

    def issues(self):
        values=stable_records(self.api.pages('issues?state=open&per_page=100'),'number')
        result=[];pull_numbers=[]
        for value in values:
            require(value.get('state')=='open' and value.get('repository_url')=='https://api.github.com/repos/'+self.repo,
                    'issue_identity')
            if 'pull_request' in value:
                require(isinstance(value['pull_request'],dict),'issue_pr_identity');pull_numbers.append(value['number']);continue
            require(isinstance(value.get('title'),str) and isinstance(value.get('labels'),list) and
                    isinstance(value.get('updated_at'),str),'issue_decision_inputs_unavailable')
            result.append({'number':value['number'],'title':value['title'],'body':value.get('body'),
                'labels':sorted(label['name'] if isinstance(label,dict) else label for label in value['labels']),
                'updated_at':value['updated_at'],'state':'open'})
        return result,pull_numbers

    def landing_evidence(self,number,merge_sha):
        result=[]
        for index,record in enumerate(r for r in self.ledger['landings'] if r['number']==number):
            evidence_sha=record.get('evidence_sha',merge_sha)
            run_data,_=self.api.get(self.api.path('actions/workflows/ci.yml/runs?head_sha='+evidence_sha+'&event=push&per_page=5'))
            runs=run_data.get('workflow_runs')
            require(isinstance(runs,list) and runs and type(runs[0].get('id')) is int,'landing_ci_unavailable')
            jobs=self.api.pages('actions/runs/'+str(runs[0]['id'])+'/jobs?per_page=100','jobs')
            directory=self.private/f'landing-{self.observation}-{number}-{index}';directory.mkdir(mode=0o700)
            write_new(directory/'runs.json',run_data);write_new(directory/'jobs.json',jobs)
            args=['bash',str(ROOT/'scripts/maintainer/dep_landing_evidence.sh'),'--repo',self.repo,
                '--sha',merge_sha,'--group',record['group'],'--packages',','.join(record['group_packages']),
                '--lock',record['lock'],'--run-file',str(directory/'runs.json'),'--jobs-file',str(directory/'jobs.json'),
                '--out',str(directory/'evidence.json')]
            if 'evidence_sha' in record:args+=['--evidence-sha',evidence_sha]
            if 'recovery' in record:
                require(isinstance(record['recovery'],dict) and record['recovery'].get('policy')=='demo-config-repair-v1','landing_recovery_policy')
                original_data,_=self.api.get(self.api.path('actions/workflows/ci.yml/runs?head_sha='+merge_sha+'&event=push&per_page=5'))
                originals=original_data.get('workflow_runs')
                require(isinstance(originals,list) and originals and type(originals[0].get('id')) is int,'landing_original_ci_unavailable')
                original_jobs=self.api.pages('actions/runs/'+str(originals[0]['id'])+'/jobs?per_page=100','jobs')
                write_new(directory/'original-runs.json',original_data);write_new(directory/'original-jobs.json',original_jobs)
                args+=['--demo-config-repair','--original-run-file',str(directory/'original-runs.json'),
                       '--original-jobs-file',str(directory/'original-jobs.json')]
            code=self.command(args,ROOT,dict(os.environ),30)
            require(code in (0,1,3) and (directory/'evidence.json').is_file(),'landing_evidence_unavailable')
            result.append(read_json(directory/'evidence.json'))
        return result

    def absent(self,issues,prs):
        open_keys={('issue',i['number']) for i in issues}|{('pr',p['number']) for p in prs}
        numbers={i['number'] for i in self.ledger['items'] if (i['kind'],i['number']) not in open_keys}
        for entry in self.ledger['items']+self.ledger['advisories']:
            trigger=entry.get('trigger',entry.get('exception',{}).get('trigger',{}))
            if trigger.get('type')=='gh_issue_closed':numbers.add(trigger['number'])
        result=[]
        for number in sorted(numbers):
            value,_=self.api.get(self.api.path('issues/'+str(number)))
            require(value.get('number')==number and value.get('state') in ('open','closed') and
                value.get('repository_url')=='https://api.github.com/repos/'+self.repo,'absent_item_unavailable')
            kind='pr' if 'pull_request' in value else 'issue';merged=False;extra={}
            if kind=='pr':
                pull,_=self.api.get(self.api.path('pulls/'+str(number)))
                require(pull.get('number')==number and pull.get('base',{}).get('repo',{}).get('full_name')==self.repo and
                        type(pull.get('merged')) is bool and pull.get('state')==value['state'],'absent_pr_unavailable')
                merged=pull['merged']
                if merged and self.only is None:
                    merge_sha=pull.get('merge_commit_sha')
                    require(isinstance(merge_sha,str) and re.fullmatch(r'[0-9a-f]{40}',merge_sha),'absent_pr_unavailable')
                    files=self.api.pages('pulls/'+str(number)+'/files?per_page=100')
                    require(len(files)<3000 and all(isinstance(f.get('filename'),str) for f in files),'pull_files_incomplete')
                    extra={'merge_sha':merge_sha,'changed_files':[f['filename'] for f in files],
                           'landing_evidence':self.landing_evidence(number,merge_sha)}
            result.append({'kind':kind,'number':number,'state':value['state'],'state_reason':value.get('state_reason'),'merged':merged,**extra})
        return result

    def command(self,argv,cwd,env,budget):
        self.command_count+=1
        path=self.private/f'command-{self.command_count:03d}.log'
        end=min(self.api.deadline,time.monotonic()+budget)
        with open(path,'xb',opener=lambda p,f:os.open(p,f,0o600)) as out:
            try:
                child=subprocess.Popen(argv,cwd=cwd,env=env,stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
                while child.poll() is None:
                    if time.monotonic()>=end or out.tell()>32*1024*1024:
                        os.killpg(child.pid,signal.SIGKILL);child.wait();raise NotReady('remote_command_budget')
                    time.sleep(.03)
                require(out.tell()<=32*1024*1024,'remote_command_budget')
                return child.returncode
            except BaseException as exc:
                if 'child' in locals() and child.poll() is None:
                    os.killpg(child.pid,signal.SIGKILL);child.wait()
                if isinstance(exc,OSError):raise NotReady('remote_command_unavailable') from exc
                raise

    def pulls(self,issue_prs):
        listed=stable_records(self.api.pages('pulls?state=open&per_page=100'),'number')
        require(sorted(p['number'] for p in listed)==sorted(issue_prs),'issue_pull_inventory_mismatch')
        dispositions={r['number']:r for r in self.ledger['items'] if r['kind']=='pr'}
        require(all(p['number'] in dispositions and 'terminal' not in dispositions[p['number']] for p in listed),'pull_undispositioned')
        prs=[];checks=[];statuses=[]
        for listed_pr in listed:
            n=listed_pr['number'];p,_=self.api.get(self.api.path('pulls/'+str(n)))
            head=p.get('head',{}).get('sha')
            require(p.get('number')==n and p.get('state')=='open' and re.fullmatch(r'[0-9a-f]{40}',head or '') and
                    p.get('base',{}).get('repo',{}).get('full_name')==self.repo and p['base'].get('ref')=='main' and
                    p.get('mergeable') in (True,False) and isinstance(p.get('mergeable_state'),str),'pull_decision_inputs_unavailable')
            values=stable_records(self.api.pages('commits/'+head+'/check-runs?filter=all&per_page=100','check_runs'),'id')
            head_runs=self.api.pages('actions/runs?head_sha='+head+'&per_page=100','workflow_runs',cap=999) if any(v.get('app',{}).get('id')==15368 for v in values) else []
            suites={};run_jobs={}
            for value in values:
                require(value.get('head_sha')==head and type(value.get('check_suite',{}).get('id')) is int and
                        type(value.get('app',{}).get('id')) is int and isinstance(value.get('name'),str),'check_identity')
                if value['app']['id']==15368:
                    suite_id=value['check_suite']['id']
                    if suite_id not in suites:suites[suite_id]=self.api.get(self.api.path('check-suites/'+str(suite_id)))[0]
                    suite=suites[suite_id]
                    require(suite.get('id')==value['check_suite']['id'] and suite.get('head_sha')==head and suite.get('app',{}).get('id')==15368,'check_attempt_identity')
                    runs=head_runs
                    require(all(r.get('head_sha')==head and r.get('repository',{}).get('full_name')==self.repo for r in runs),'check_attempt_identity')
                    matches=[r for r in runs if r.get('check_suite_id')==suite['id']]
                    require(len(matches)==1 and type(matches[0].get('run_attempt')) is int,'check_attempt_unavailable')
                    run=matches[0]
                    if run['id'] not in run_jobs:run_jobs[run['id']]=self.api.pages('actions/runs/'+str(run['id'])+'/jobs?filter=all&per_page=100','jobs')
                    jobs=run_jobs[run['id']]
                    matches=[j for j in jobs if j.get('check_run_url')=='https://api.github.com/repos/'+self.repo+'/check-runs/'+str(value['id'])]
                    require(len(matches)==1,'check_attempt_unavailable');job=matches[0]
                    require(job.get('run_id')==run['id'] and job.get('head_sha')==head and type(job.get('run_attempt')) is int and
                        1<=job['run_attempt']<=run['run_attempt'] and job.get('status')==value.get('status') and
                        job.get('conclusion')==value.get('conclusion'),'check_attempt_identity')
                    value.update(readiness_run_id=run['id'],readiness_attempt=job['run_attempt'],latest_run_attempt=run['run_attempt'],
                                 readiness_run_created_at=run.get('created_at'),readiness_workflow=run.get('path'),readiness_workflow_name=run.get('name'),readiness_run_state=run.get('status'))
                checks.append({'pr':n,'head_sha':head,'check':value})
            legacy=stable_records(self.api.pages('commits/'+head+'/statuses?per_page=100'),'id')
            require(all(v.get('state') in ('error','failure','pending','success') and isinstance(v.get('context'),str) and
                        v['context'] and isinstance(v.get('created_at'),str) for v in legacy),'legacy_status_identity')
            statuses.extend({'pr':n,'head_sha':head,'status':v} for v in legacy)
            candidates=[v for v in values if v['name']=='CI Summary' and v['app']['id']==15368]
            require(all(v.get('readiness_workflow')=='.github/workflows/ci.yml' and v.get('readiness_workflow_name')=='CI' for v in candidates),'ci_summary_workflow_identity')
            latest=max(candidates,key=lambda v:(v.get('readiness_run_created_at') or '',v['readiness_run_id'],v['readiness_attempt'],v.get('started_at') or '',v['id'])) if candidates else None
            if latest and (latest['readiness_attempt']!=latest['latest_run_attempt'] or latest['readiness_run_state']!='completed'):
                latest={**latest,'status':'in_progress','conclusion':None}
            files=self.api.pages('pulls/'+str(n)+'/files?per_page=100')
            require(len(files)<3000,'pull_file_cap')
            delta=[]
            for file in files:
                require(isinstance(file.get('filename'),str),'pull_files_incomplete')
                if file['filename'] in ('mix.lock','examples/adoption_demo/mix.lock'):
                    require(isinstance(file.get('patch'),str),'lock_delta_unavailable')
                    found={}
                    for sign,package,version in re.findall(r'^([-+])  "([a-z0-9_]+)": \{:hex, :[a-z0-9_]+, "([^"\n]+)"',file['patch'],re.M):
                        found.setdefault(package,{'package':package,'lock':file['filename'],'from':None,'to':None})['from' if sign=='-' else 'to']=version
                    delta.extend(found.values())
            prs.append({'number':n,'head_sha':head,'base':p['base']['ref'],'mergeable':p['mergeable'],
                'mergeable_state':p['mergeable_state'],'behind':p['mergeable_state']=='behind',
                'decision_identity_sha256':digest(canonical(p)), 'lock_delta':sorted(delta,key=lambda d:(d['lock'],d['package'])),
                'ci_summary':{'conclusion':latest.get('conclusion') if latest and latest.get('status')=='completed' else None,
                    'check_run_id':latest['id'] if latest else None}})
        return prs,checks,statuses

    def security(self):
        advisories=[]
        for state in ('triage','draft','published','closed'):
            self.current_source='advisories-'+state
            start=len(self.api.calls)
            rows=self.api.pages('security-advisories?state='+state+'&per_page=100')
            self.visibility(self.api.calls[start:],'advisory')
            for row in rows:
                require(isinstance(row,dict) and row.get('state')==state and re.fullmatch(r'GHSA-[a-z0-9-]+',row.get('ghsa_id','')) and
                    row.get('url')=='https://api.github.com/repos/'+self.repo+'/security-advisories/'+row['ghsa_id'],'advisory_identity')
                advisories.append(row)
        require(len({a['ghsa_id'] for a in advisories})==len(advisories),'advisory_changed')
        self.current_source='dependabot'
        start=len(self.api.calls)
        alerts=stable_records(self.api.pages('dependabot/alerts?state=open%2Cdismissed%2Cfixed%2Cauto_dismissed&per_page=100'),'number')
        self.visibility(self.api.calls[start:],'dependabot')
        for alert in alerts:
            require(alert.get('state') in ('open','dismissed','fixed','auto_dismissed') and
                    alert.get('url')=='https://api.github.com/repos/'+self.repo+'/dependabot/alerts/'+str(alert['number']), 'dependabot_identity')
        return sorted(advisories,key=lambda a:a['ghsa_id']),alerts

    def visibility(self,calls,source):
        for call in calls:
            h=call['headers'];scope_key='repository_advisories' if source=='advisory' else 'dependabot_alerts'
            if 'x-oauth-scopes' in h:
                scopes={s.strip() for s in h['x-oauth-scopes'].split(',')}
                allowed={'repo','repository_advisories:read','repository_advisories:write'} if source=='advisory' else {'repo','security_events','public_repo'}
                require(bool(scopes&allowed),source+'_visibility_unproved')
            else:
                # A successful authenticated private-state GET with the required fine-grained permission header.
                accepted=h.get('x-accepted-github-permissions','')
                require(re.search(r'(?:^|[;, ])'+scope_key+r'=(?:read|write)(?:$|[;, ])',accepted),source+'_visibility_unproved')

    def hex_audits(self):
        if self.fixture is not None:
            versions=read_json(Path(self.fixture)/'hex.json')
            require(isinstance(versions,list) and len(versions)>=self.observation,'hex_source_unavailable')
            rows=versions[self.observation-1]
        else:
            rows=[]
            for scope,relative in [('root','mix.lock'),('examples/adoption_demo','examples/adoption_demo/mix.lock')]:
                directory=self.private/f'hex-{self.observation}-{scope.replace("/","-")}'
                directory.mkdir(mode=0o700)
                project='defmodule ReadinessAudit.MixProject do\n use Mix.Project\n def project, do: [app: :readiness_audit, version: "0.0.0", deps: []]\n def application, do: [extra_applications: [:logger,:ssl,:inets,:crypto,:public_key]]\nend\n'
                write_new(directory/'mix.exs',project.encode());write_new(directory/'mix.lock',self.inputs[relative].encode())
                env={k:v for k,v in os.environ.items() if not k.startswith('HEX_') and k not in ('MIX_EXS','MIX_HOME','MIX_ARCHIVES','MIX_DEPS_PATH','MIX_BUILD_PATH','ERL_FLAGS','ERL_AFLAGS','ERL_ZFLAGS')}
                env.update(TOOLCHAIN_ENV);env.update(HEX_HOME=str(directory/'hex-home'),HEX_IGNORE_ADVISORIES='',HEX_IGNORE_RETIREMENTS='',MIX_ENV='prod')
                output=directory/'audit.json';extras=directory/'extra-packages.json';write_new(extras,getattr(self,'hex_triggers',[]))
                code=self.command(['mix','run','--no-start',str(ROOT/'scripts/maintainer/readiness_hex_audit.exs'),'--audit',str(output),str(extras)],directory,env,150)
                require(code in (0,1) and output.is_file(),'hex_source_unavailable')
                rows.append({**read_json(output),'scope':scope})
        require(isinstance(rows,list) and len(rows)==2 and {r.get('scope') for r in rows}=={'root','examples/adoption_demo'},'hex_source_unavailable')
        for row in rows:
            relative='mix.lock' if row['scope']=='root' else 'examples/adoption_demo/mix.lock'
            require(row.get('schema')=='rindle-readiness-hex-v1' and row.get('hex_version') in ('2.5.1','2.6.0') and row.get('online') is True and
                row.get('registry_signature_verification') is True and row.get('https_verified') is True and
                row.get('lock_sha256')==digest(self.inputs[relative].encode()),'hex_source_identity')
            latest=row.get('latest_versions',{})
            require(isinstance(latest,dict) and sorted(latest)==getattr(self,'hex_triggers',[]) and
                all(re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:\+[a-zA-Z0-9.-]+)?',v) for v in latest.values()),'hex_version_trigger_unavailable')
            row['latest_versions']=latest
            packages=row.get('packages');database=row.get('database')
            require(isinstance(packages,list) and isinstance(database,list) and database and len(database)<=200000,'hex_database_unavailable')
            expected=[(p['package'],p['version']) for p in self.lock_inventory[row['scope']]]
            require(sorted((p.get('package'),p.get('version')) for p in packages)==expected,'hex_lock_coverage')
            for p in packages:
                require(p.get('retired') is False and isinstance(p.get('advisories'),list),'hex_retired_or_unavailable')
                for a in p['advisories']:
                    require(re.fullmatch(r'(?:EEF-CVE-[0-9-]+|CVE-[0-9-]+|GHSA-[a-z0-9-]+)',a.get('id','')) and
                            a.get('severity') in ('SEVERITY_LOW','SEVERITY_MEDIUM','SEVERITY_HIGH','SEVERITY_CRITICAL','LOW','MEDIUM','HIGH','CRITICAL'),'hex_advisory_shape')
            keys=[]
            for d in database:
                key=d.get('key');require(isinstance(key,list) and key and all(isinstance(k,str) and re.fullmatch(r'[a-z0-9._+-]+',k) for k in key) and
                    re.fullmatch(r'[0-9a-f]{64}',d.get('value_sha256','')),'hex_database_unavailable');keys.append(tuple(key))
            require(len(keys)==len(set(keys)),'hex_database_unavailable')
            row['packages']=sorted(packages,key=lambda p:p['package']);row['database']=sorted(database,key=lambda d:d['key'])
        policy({'operation':'hex','payloads':rows,'locks':{scope:self.inputs['mix.lock' if scope=='root' else 'examples/adoption_demo/mix.lock'] for scope in ('root','examples/adoption_demo')}})
        return sorted(rows,key=lambda r:r['scope'])

    def live_inventory(self,issues,prs,absent,advisories,alerts,hexes,protection):
        findings=[]
        for audit in hexes:
            for package in audit['packages']:
                findings.extend({'id':a['id'],'scope':audit['scope'],'package':package['package'],'version':package['version'],
                    'source':'hex_audit','ignored':False} for a in package['advisories'])
        for a in advisories:
            if a['state']!='closed' and not a.get('withdrawn_at'):
                findings.append({'id':a['ghsa_id'],'scope':'github','package':self.repo.split('/')[1],'source':'repository-advisory','ignored':False})
        for a in alerts:
            if a['state'] in ('open','dismissed'):
                dependency=a['dependency'];advisory=a['security_advisory']
                findings.append({'id':advisory['ghsa_id'],'scope':'examples/adoption_demo' if dependency.get('manifest_path','').startswith('examples/adoption_demo/') else 'root',
                    'package':dependency['package']['name'],'source':'dependabot','ignored':a['state']=='dismissed'})
        inventory={'schema':'rindle-inbox-inventory-v1','repo':self.repo,'main_sha':self.subject,
            'collected_at':dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            'issues':issues,'prs':prs,'terminal':absent,'branch_protection':protection,
            'advisories':{'findings':findings,'sources':{'hex_audit_root':{'status':'findings' if any(f['scope']=='root' and f['source']=='hex_audit' for f in findings) else 'clean'},
                'hex_audit_demo':{'status':'findings' if any(f['scope']=='examples/adoption_demo' and f['source']=='hex_audit' for f in findings) else 'clean'},
                'dependabot_alerts':{'status':'enabled'}}},'hex_latest':hexes[0].get('latest_versions',{})}
        require(all(h.get('latest_versions',{})==hexes[0].get('latest_versions',{}) for h in hexes),'hex_version_trigger_changed')
        self.validate_ledger(inventory)

    def issue_reconciliation(self,issues,absent):
        records={i['number']:i for i in self.ledger['items'] if i['kind']=='issue'}
        require(all(i['number'] in records and 'terminal' not in records[i['number']] for i in issues),'issue_undispositioned')
        open_numbers={i['number'] for i in issues};closed={i['number']:i for i in absent if i['kind']=='issue'}
        for number,record in records.items():
            if number not in open_numbers:
                if record.get('terminal_policy')=='observe-retained-issue-v1':
                    require(record['disposition']=='retain' and 'terminal' not in record and number in closed and
                            closed[number].get('state')=='closed' and closed[number].get('merged') is False and
                            closed[number].get('state_reason')=='completed','issue_terminal_mismatch')
                else:
                    require('terminal' in record and number in closed and
                            all(closed[number].get(k)==v for k,v in record['terminal'].items()),'issue_terminal_mismatch')
            if record['disposition']=='defer' and 'terminal' not in record:
                raise NotReady('full_disposition_reconciliation_required')

    def observations(self):
        self.observation+=1
        self.current_source='ledger'
        if self.only is None:
            metadata,_=self.api.get('repos/'+self.repo)
            require(metadata.get('id')==self.metadata['id'] and metadata.get('permissions',{}).get('admin') is True,'advisory_visibility_changed')
        if self.snapshot:
            from readiness_subject import current_authority
            self.authority_sha,authority=current_authority(self.api,[LEDGER])
            require(digest(authority[LEDGER])==self.ledger_sha,'ledger_changed')
        else:
            require(digest(self.api.contents(LEDGER,self.subject))==self.ledger_sha,'ledger_changed')
        self.current_source="issues"
        issues,pulls=self.issues()
        if self.only=='issues':
            absent=self.absent(issues,[{'number':n} for n in pulls]);self.issue_reconciliation(issues,absent)
            return {'issues':issues,'absent':absent}
        self.current_source="pulls"
        prs,checks,statuses=self.pulls(pulls)
        self.current_source="absent"
        absent=self.absent(issues,prs)
        advisories,alerts=self.security()
        self.current_source="hex"
        hexes=self.hex_audits()
        self.current_source="protection"
        protection=RunCollector.protection(self)
        self.current_source="ledger"
        self.live_inventory(issues,prs,absent,advisories,alerts,hexes,protection)
        value={'issues':issues,'pulls':prs,'checks':checks,'statuses':statuses,'absent':absent,
            'advisories':advisories,'dependabot':alerts,'hex':hexes,'protection':[protection]}
        write_new(self.private/f'normalized-{self.observation}.json',value)
        return value

    def run(self):
        started=now();verdict={'schema_version':1,'verdict':'not_ready','repository':self.repo,'subject_sha':self.subject,
            'evidence_mode':'fixture' if self.fixture is not None else 'execution','requirements_credit':False}
        handlers={sig:signal.getsignal(sig) for sig in (signal.SIGINT,signal.SIGTERM)}
        def interrupt(_sig,_frame):raise NotReady('collection_interrupted')
        for sig in handlers:signal.signal(sig,interrupt)
        try:
            # Two complete inventories of retained history can exceed the generic
            # 400-GET default. Keep a finite owner cap, including retry attempts.
            self.api=GitHub(self.repo,self.private/'api',self.fixture,budget=600,max_calls=600)
            self.initialize();before=self.observations();after=self.observations();self.main()
            require(before==after,'remote_state_changed')
            interval={'started_at':started,'completed_at':now()}
            # Portable records carry identity and coverage, never private bodies, titles, or tokens.
            sources={name:{'complete':True,'authorized':True,'reconciled':True,'changed':False,
                          'count':len(rows),'identity_sha256':digest(canonical(rows))} for name,rows in before.items()}
            extra_refs=[]
            if self.only is None:
                path=self.portable/'hex-database.json';write_new(path,{'audits':before['hex']});ref=reference(self.portable,path)
                sources['hex'].update(database_sha256=ref['sha256'],database=ref)
                extra_refs.append(ref)
            policies={'issues':'issues state=open; PR objects excluded; every Link page',
                'pulls':'open PRs; exact head and complete file delta', 'checks':'filter=all; exact head; full current and historical job attempts',
                'statuses':'separate legacy statuses; every Link page', 'advisories':'triage,draft,published,closed; each authenticated private-state GET; all pages',
                'dependabot':'open,dismissed,fixed,auto_dismissed; authorized alerts GET; all pages',
                'hex':'fresh signed public Hex registry; empty ignores; all locked root/demo packages',
                'protection':'classic and effective active repository/parent rulesets', 'absent':'individual issue/PR terminal lookup for every absent tracked item and trigger'}
            for name in sources:
                sources[name].update(query_policy=policies[name],observation_interval=interval,observations=2,
                    visibility='authenticated-repository-admin-and-private-state-permission' if name=='advisories' else
                               'authenticated-alerts-endpoint-permission' if name=='dependabot' else
                               'public-signed-registry' if name=='hex' else 'authenticated-complete-GET')
            normalized={'repository':self.repo,'subject_sha':self.subject,'ledger_sha256':self.ledger_sha,'sources':sources,
                'snapshot_guarantee':'two-bounded-reads; no cross-endpoint atomicity'}
            if self.snapshot:
                ledger_file=self.portable/'authority/INBOX-LEDGER.json'
                write_new(ledger_file,self.ledger_path.read_bytes())
                normalized.update(authority_main_sha=self.authority_sha,ledger_file=reference(self.portable,ledger_file))
                extra_refs.append(reference(self.portable,ledger_file))
            refs=[]
            for position in ('before','after'):
                path=self.portable/'observations'/('remote-'+position+'.json');write_new(path,normalized);refs.append(reference(self.portable,path))
            source={'complete':True,'authenticated':True,'query':'GET all pages; distinct sources; two bounded reads; actual disposition validator',
                'pages':len(self.api.calls),'policy':self.policy_name,'normalized':normalized,'observation_interval':interval,
                'before_sha256':refs[0]['sha256'],'after_sha256':refs[1]['sha256'],'observations':refs}
            write_new(self.portable/'sources.json',{'repository':self.repo,'subject_sha':self.subject,'evidence_mode':verdict['evidence_mode'],
                'requirements_credit':False,'observation_interval':interval,'sources':{'remote-inventory':{'source':source,'references':refs+extra_refs}},
                'scope':'issues-tracer' if self.only=='issues' else 'full'})
            verdict.update(verdict='collected',reason='remote_dispositions_collected',sources=list(sources));code=0
        except NotReady as exc:
            verdict['reason']=str(exc);verdict['source']=self.current_source;code=1
            if str(exc) in ('pull_undispositioned','issue_undispositioned','ledger_reconciliation_failed'):
                verdict['next_action']='Phase 134 disposition owner: reconcile the current ledger against restricted collected evidence, then collect again'
            elif str(exc) in ('remote_forbidden','remote_unauthorized','remote_unavailable','advisory_visibility_unproved','dependabot_visibility_unproved'):
                verdict['next_action']='Obtain complete read-only source visibility with authorized credentials; unavailable is not empty'
        except (OSError,ValueError,KeyError,TypeError,IndexError):verdict['reason']='malformed_remote_evidence';code=1
        finally:
            for sig,handler in handlers.items():signal.signal(sig,handler)
        verdict['observation_interval']={'started_at':started,'completed_at':now()}
        write_new(self.output/'verdict.json',verdict);print(verdict['verdict']+': '+verdict['reason']);return code


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',required=True);parser.add_argument('--subject',required=True);parser.add_argument('--output',required=True)
    parser.add_argument('--snapshot',action='store_true');parser.add_argument('--fixture');parser.add_argument('--only',choices=['issues'])
    args=parser.parse_args()
    try:
        return RemoteCollector(args.repo,args.subject,args.output,args.fixture,args.only,args.snapshot).run()
    except NotReady as exc:print('not_ready: '+str(exc));return 1

if __name__=='__main__':raise SystemExit(main())
