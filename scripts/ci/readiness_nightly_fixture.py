"""Synthetic v3 proof graph. No live/requirements credit."""
import copy
import io
import json
import re
import zipfile

import exact_head_readiness as q


def jq_hash(value):
    return q.digest((json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False)+'\n').encode())


def step_rows(yaml, job_id):
    rows=[];active=False
    for line in yaml.splitlines():
        match=re.match(r'^  ([a-z-]+):$',line)
        if match:active=match[1]==job_id
        if active and line.startswith('      - name: '):
            name=line.removeprefix('      - name: ')
            rows.append({'name':name,'number':len(rows)+1,'status':'completed','conclusion':'success'})
    if job_id=='dialyzer':
        next(r for r in rows if r['name']=='Require exact PLT restore')['conclusion']='skipped'
    if job_id in ('gcs-soak','package-consumer-gcs-live'):
        for row in rows:
            if row['name'] not in ('Checkout','Determine live GCS applicability','Publish Nightly evidence') and not row['name'].startswith('Skip live '):
                row['conclusion']='skipped'
    return rows


def split_receipt(receipt, manifest, root, put, prefix):
    """Split the legacy synthetic schedule into distinct subjects and claims."""
    original=receipt['source']['normalized']
    yaml=(q.ROOT/'.github/workflows/nightly.yml').read_text()
    qualification=copy.deepcopy(receipt);qualification['id']='nightly-qualification'
    n=qualification['source']['normalized'];n['event']='workflow_dispatch';n['attempt']=1;n['rechecked_attempt']=1
    n.update(created_at='2026-10-22T07:27:00Z',completed_at='2026-10-22T07:37:00Z')
    for key in list(n):
        if key.startswith('incident'):n.pop(key)
    for job in n['jobs']:
        name=job['name']
        if name.startswith('Compat Matrix'):job_id='compat-matrix'
        else:job_id={'Dialyzer':'dialyzer','Nightly Summary':'nightly-summary',
          'GCS Soak (real bucket)':'gcs-soak','Package Consumer GCS Live Proof':'package-consumer-gcs-live',
          'Persist Nightly Incident Verdict':'nightly-incident-verdict','Nightly Incident Lifecycle':'nightly-failure-issue'}[name]
        skipped=job_id in ('nightly-incident-verdict','nightly-failure-issue')
        job['conclusion']='skipped' if skipped else 'success'
        job['steps']=[] if skipped else step_rows(yaml,job_id)
    health=copy.deepcopy(receipt);health['id']='scheduled-incident-health'
    run=copy.deepcopy(original);run['subject_sha']='d'*40;run['incident']['sha']='d'*40
    run['attempt']=1;run['rechecked_attempt']=1;run['incident']['run_attempt']=1
    run.update(created_at='2026-10-22T07:27:00Z',completed_at='2026-10-22T07:37:00Z',incident_artifact_expires_at='2026-11-04T00:00:00Z')
    def archive(value,leaf,path):
        buf=io.BytesIO()
        with zipfile.ZipFile(buf,'w') as z:z.writestr(leaf,q.canonical(value))
        return put(root,prefix+path,buf.getvalue())
    run['incident_artifact']=archive(run['incident'],'nightly-incident-verdict.json','health-event.zip')
    run['incident_artifact_sha256']=run['incident_artifact']['sha256']
    checkpoint={'schema':'rindle-nightly-incident-checkpoint-v1','repository':receipt['repository'],
        'workflow_ref':receipt['repository']+'/.github/workflows/nightly.yml@refs/heads/main',
        'last_run_id':run['run_id'],'last_run_attempt':1,'event_digest':jq_hash(run['incident']),
        'issue_digest':jq_hash([]),'issue_number':None,'issue_state':None,'previous_chain_digest':'0'*64}
    checkpoint['chain_digest']=jq_hash({k:v for k,v in checkpoint.items() if k not in ('schema','repository','workflow_ref')})
    paths=['.github/workflows/nightly.yml','.github/actions/setup-elixir/action.yml',
        'scripts/ci/eval_nightly_summary.sh','scripts/ci/manage_nightly_incident.sh',
        'scripts/ci/run_nightly_dialyzer.sh','scripts/ci/install_apt_packages.sh',
        'scripts/ci/install_ffmpeg.sh','scripts/ci/ensure_phx_new.sh','scripts/install_smoke.sh',
        'scripts/ci/adoption_demo_gcs_live.sh','.github/actions/repository-credential/action.yml',
        'scripts/maintainer/repository_credential.py','.github/workflows/release-please-automerge.yml',
        '.github/workflows/branch-protection-apply.yml']
    controls={p:manifest['input_identity'][p] for p in paths}
    checkpoint_ref=archive(checkpoint,'nightly-incident-checkpoint.json','health-checkpoint.zip')
    health['source']['normalized']={'repository':receipt['repository'],'subject_sha':receipt['subject_sha'],
        'health_run':run,'observed_at':receipt['source']['observation_interval']['started_at'],
        'control_identity':controls,'health_control_identity':controls,
        'health_control_files':{p:manifest['input_files'][p] for p in paths},'checkpoint':checkpoint,
        'checkpoint_artifact':checkpoint_ref,'checkpoint_artifact_sha256':checkpoint_ref['sha256'],
        'checkpoint_artifact_expires_at':'2026-11-04T00:00:00Z','incidents':[]}
    qualification['references']=[]
    health['references']=[run['incident_artifact'],checkpoint_ref]+list(health['source']['normalized']['health_control_files'].values())
    return [qualification,health]
