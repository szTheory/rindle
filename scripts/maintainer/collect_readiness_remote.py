#!/usr/bin/env python3
"""Read-only current disposition evidence. Private source bytes stay restricted."""
import argparse
import datetime as dt
import os
from pathlib import Path
import re
import subprocess
import time

from exact_head_readiness import ROOT, TOOLCHAIN_ENV, NotReady, canonical, digest, now, read_json, reference, require, write_new
from readiness_github import GitHub, json_bytes

LEDGER = '.planning/INBOX-LEDGER.json'
POLICY = 'rindle-exact-head-v1'


def stable_records(values, id_key):
    require(isinstance(values,list) and all(isinstance(v,dict) for v in values),'incomplete_inventory')
    ids=[v.get(id_key) for v in values]
    require(all(type(id) is int and id>0 for id in ids) and len(set(ids))==len(ids),'ambiguous_inventory_identity')
    # Stable IDs disambiguate equal timestamps; list order is not source identity.
    return sorted(values,key=lambda v:v[id_key])


class RemoteCollector:
    def __init__(self,repo,subject,output,fixture=None,only=None):
        require(re.fullmatch(r'[0-9a-f]{40}',subject),'invalid_subject')
        self.repo,self.subject,self.output=repo,subject,Path(output).resolve()
        require(not self.output.exists() and not self.output.is_relative_to(ROOT),'output_must_be_new_external_directory')
        self.output.mkdir(mode=0o700,parents=True)
        self.portable=self.output/'portable';self.private=self.output/'restricted'
        self.portable.mkdir(mode=0o700);self.private.mkdir(mode=0o700)
        self.fixture,self.only=fixture,only
        self.observation=0

    def main(self):
        value,_=self.api.get(self.api.path('git/ref/heads/main'))
        require(value.get('ref')=='refs/heads/main' and value.get('object',{}).get('type')=='commit' and
                value['object'].get('sha')==self.subject,'main_changed')

    def initialize(self):
        metadata,_=self.api.get('repos/'+self.repo)
        require(metadata.get('full_name')==self.repo and metadata.get('default_branch')=='main' and
                type(metadata.get('id')) is int,'repository_identity')
        self.metadata=metadata;self.api.repo_id=metadata['id'];self.main()
        raw=self.api.contents(LEDGER,self.subject)
        self.ledger=json_bytes(raw);self.ledger_sha=digest(raw)
        require(self.ledger.get('repo')==self.repo,'ledger_repository')
        self.ledger_path=self.private/'ledger.json';write_new(self.ledger_path,raw)
        self.validate_ledger()

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
            kind='pr' if 'pull_request' in value else 'issue';merged=False
            if kind=='pr':
                pull,_=self.api.get(self.api.path('pulls/'+str(number)))
                require(pull.get('number')==number and pull.get('base',{}).get('repo',{}).get('full_name')==self.repo and
                        type(pull.get('merged')) is bool and pull.get('state')==value['state'],'absent_pr_unavailable')
                merged=pull['merged']
            result.append({'kind':kind,'number':number,'state':value['state'],'state_reason':value.get('state_reason'),'merged':merged})
        return result

    def issue_reconciliation(self,issues,absent):
        records={i['number']:i for i in self.ledger['items'] if i['kind']=='issue'}
        require(all(i['number'] in records and 'terminal' not in records[i['number']] for i in issues),'issue_undispositioned')
        open_numbers={i['number'] for i in issues};closed={i['number']:i for i in absent if i['kind']=='issue'}
        for number,record in records.items():
            if number not in open_numbers:
                require('terminal' in record and number in closed and
                        all(closed[number].get(k)==v for k,v in record['terminal'].items()),'issue_terminal_mismatch')
            if record['disposition']=='defer' and 'terminal' not in record:
                raise NotReady('full_disposition_reconciliation_required')

    def observations(self):
        self.observation+=1
        require(digest(self.api.contents(LEDGER,self.subject))==self.ledger_sha,'ledger_changed')
        issues,pulls=self.issues()
        # The tracer is deliberately partial: it cannot certify PR/security/Hex completeness.
        absent=self.absent(issues,[{'number':n} for n in pulls])
        self.issue_reconciliation(issues,absent)
        return {'issues':issues,'absent':absent}

    def run(self):
        started=now();verdict={'schema_version':1,'verdict':'not_ready','repository':self.repo,'subject_sha':self.subject,
            'evidence_mode':'fixture' if self.fixture else 'execution','requirements_credit':False}
        try:
            self.api=GitHub(self.repo,self.private/'api',self.fixture,budget=600)
            self.initialize();before=self.observations();after=self.observations();self.main()
            require(before==after,'remote_state_changed')
            interval={'started_at':started,'completed_at':now()}
            # Portable records carry identity and coverage, never private bodies, titles, or tokens.
            sources={name:{'complete':True,'authorized':True,'reconciled':True,'changed':False,
                          'count':len(rows),'identity_sha256':digest(canonical(rows))} for name,rows in before.items()}
            normalized={'repository':self.repo,'subject_sha':self.subject,'ledger_sha256':self.ledger_sha,'sources':sources}
            refs=[]
            for position in ('before','after'):
                path=self.portable/'observations'/('remote-'+position+'.json');write_new(path,normalized);refs.append(reference(self.portable,path))
            source={'complete':True,'authenticated':True,'query':'GET all pages; distinct sources; two bounded reads; actual disposition validator',
                'pages':len(self.api.calls),'policy':POLICY,'normalized':normalized,'observation_interval':interval,
                'before_sha256':refs[0]['sha256'],'after_sha256':refs[1]['sha256'],'observations':refs}
            write_new(self.portable/'sources.json',{'repository':self.repo,'subject_sha':self.subject,'evidence_mode':verdict['evidence_mode'],
                'requirements_credit':False,'observation_interval':interval,'sources':{'remote-inventory':{'source':source,'references':refs}},
                'scope':'issues-tracer' if self.only=='issues' else 'full'})
            verdict.update(verdict='collected',reason='remote_dispositions_collected',sources=list(sources));code=0
        except NotReady as exc:verdict['reason']=str(exc);code=1
        except (OSError,ValueError,KeyError,TypeError,IndexError):verdict['reason']='malformed_remote_evidence';code=1
        verdict['observation_interval']={'started_at':started,'completed_at':now()}
        write_new(self.output/'verdict.json',verdict);print(verdict['verdict']+': '+verdict['reason']);return code


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',required=True);parser.add_argument('--subject',required=True);parser.add_argument('--output',required=True)
    parser.add_argument('--fixture');parser.add_argument('--only',choices=['issues'])
    args=parser.parse_args()
    try:
        require(args.only=='issues','full_remote_sources_not_implemented')
        return RemoteCollector(args.repo,args.subject,args.output,args.fixture,args.only).run()
    except NotReady as exc:print('not_ready: '+str(exc));return 1

if __name__=='__main__':raise SystemExit(main())
