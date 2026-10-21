import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import time

root = Path('/Users/jon/projects/rindle/.claude/worktrees/phase136-execution')
phase = root / '.planning/phases/136-measured-quality-and-ci-ratchets'
subject = phase / '136-SUBJECT-SPEED.json'
pin = json.loads(subject.read_text())
progress = phase / '136-SPEED-LOCAL-COLLECTION.json'
job_path = root / '.planning/async-jobs/136-07-final-measurements.json'
state = {**pin, 'status': 'running', 'steps': [], 'pid': os.getpid(),
         'purpose': 'Progress only; acceptance comes from immutable owner receipts.'}
with progress.open('x') as output:
    json.dump(state, output, indent=2)

def save(status=None):
    if status:
        state['status'] = status
    state['updated_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    progress.write_text(json.dumps(state, indent=2) + '\n')
    job = json.loads(job_path.read_text())
    job['status'] = 'completed-unverified' if state['status'] == 'complete' else 'failed' if state['status'] == 'stopped_on_failure' else 'running'
    job['terminal_details'] = {'active_step': state.get('active_step'), 'last_step': state['steps'][-1] if state['steps'] else None} if job['status'] == 'failed' else None
    job_path.write_text(json.dumps(job, indent=2) + '\n')

def run(name, argv, timeout, allow_open=False, output_path=None):
    output_path = output_path or Path('/private/tmp/phase136-speed-' + name + '.txt')
    started = time.time()
    state['active_step'] = name
    save()
    print('START', name, flush=True)
    with output_path.open('x') as output:
        try:
            code = subprocess.run(argv, cwd=root, stdout=output,
                                  stderr=subprocess.STDOUT, timeout=timeout).returncode
        except subprocess.TimeoutExpired:
            code = 124
    record = {'name': name, 'argv': argv, 'exit_status': code,
              'run_started_at': started, 'duration_seconds': round(time.time()-started, 3),
              'output': str(output_path)}
    state['steps'].append(record)
    save()
    print('END', name, code, flush=True)
    if code != 0 and not (allow_open and code == 1):
        save('stopped_on_failure')
        sys.exit(code if code > 0 else 1)
    return record

measure = ['bash', 'scripts/maintainer/phase136_measure.sh']
run('projection', measure + ['verify-subject', '--subject-file', str(subject)], 60)
canonical_output = phase / '136-CANONICAL-SPEED.txt'
record = run('canonical', ['mix', 'coveralls.multiple', '--type', 'local', '--type', 'json'],
             1200, output_path=canonical_output)
with (phase / '136-CANONICAL-SPEED-RUN.json').open('x') as output:
    json.dump({**pin, **record}, output, indent=2)
coverage = phase / '136-COVERAGE-EVIDENCE-SPEED.json'
coverage_owner = ['mix', 'run', 'scripts/maintainer/verify_coverage_floor.exs', '--']
run('coverage-write', coverage_owner + ['--write', '--subject-file', str(subject),
    '--receipt', str(coverage), '--artifact', str(root/'cover/excoveralls.json'),
    '--local-output', str(canonical_output), '--local-exit', '0',
    '--run-started-at', str(record['run_started_at'])], 120)
run('coverage-verify', coverage_owner + ['--verify-only', '--subject-file', str(subject),
    '--receipt', str(coverage)], 120)

for kind in ['dialyzer', 'bootstrap']:
    receipt = phase / ('136-' + kind.upper() + '-EVIDENCE-SPEED.json')
    run(kind, measure + [kind, '--subject-file', str(subject), '--receipt', str(receipt)],
        9000 if kind == 'dialyzer' else 1500, allow_open=True)
    run('verify-'+kind, measure + ['verify-'+kind, '--subject-file', str(subject),
        '--receipt', str(receipt)], 180)

files = json.loads((phase/'136-CLOSEOUT-REGRESSION-FILES.json').read_text())
regression = run('regression', ['mix', 'test', *files, '--seed', '0'], 600,
                 output_path=phase/'136-REGRESSION-SPEED.txt')
with (phase/'136-REGRESSION-SPEED.json').open('x') as output:
    json.dump({**pin, **regression, 'files': files}, output, indent=2)

receipt = phase/'136-ASYNC-RESULT-SPEED.json'
run('async', measure + ['async', '--subject-file', str(subject), '--receipt', str(receipt),
    '--jsonl', str(root/'.planning/evidence/async-isolation/136-async-isolation-speed.jsonl')],
    19000, allow_open=True)
run('verify-async', measure + ['verify-async', '--subject-file', str(subject),
    '--receipt', str(receipt)], 180)

manifest = phase/'136-QUALIFICATION-CLOSEOUT.json'
qualification = ['bash', 'scripts/maintainer/verify_phase136_qualification.sh']
run('qualification-generate', qualification + ['generate', '--manifest', str(manifest),
    '--subject-file', str(subject), '--coverage', str(coverage),
    '--dialyzer', str(phase/'136-DIALYZER-EVIDENCE-SPEED.json'),
    '--bootstrap', str(phase/'136-BOOTSTRAP-EVIDENCE-SPEED.json'),
    '--async-receipt', str(receipt), '--timing', str(phase/'136-PR-TIMING.md')],
    2400, allow_open=True)
run('qualification-verify', qualification + ['verify', '--manifest', str(manifest),
    '--subject-file', str(subject)], 2100)
state['qualification_outcome'] = json.loads(manifest.read_text()).get('outcome')
state.pop('active_step', None)
save('complete')
print('LOCAL PIPELINE TERMINAL:', state['qualification_outcome'], flush=True)
