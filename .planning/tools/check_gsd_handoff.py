"""Read-only resume guard. GSD owns routing; external-job ownership takes priority."""
import json
from pathlib import Path
import re
import subprocess
import sys


def inspect(root, verification):
    planning = root / '.planning'
    state = (planning / 'STATE.md').read_text().split('---', 2)[1]
    match = re.search(r'^current_phase:\s*["\']?([0-9]+[A-Z]?(?:\.[0-9]+)*)["\']?\s*$', state, re.M)
    if not match:
        raise ValueError('STATE has no valid current_phase')
    phase = match[1]
    handoff = planning / 'HANDOFF.json'
    if handoff.exists() and str(json.loads(handoff.read_text()).get('phase')) != phase:
        raise ValueError('HANDOFF phase disagrees with STATE; archive/reconcile the stale handoff')
    jobs = []
    for path in sorted((planning / 'async-jobs').glob('*.json')):
        job = json.loads(path.read_text())
        if str(job.get('phase')) == phase:
            if not re.fullmatch(re.escape(phase) + r'-[0-9]+', job.get('plan_id', '')):
                raise ValueError('Manifest plan identity disagrees with its phase')
            jobs.append((path, job))
    ids = [job['plan_id'] for _, job in jobs]
    if len(ids) != len(set(ids)):
        raise ValueError('Multiple manifests own the same plan; reconcile before execution')
    # A summary closes the external-job half-state; keep old manifests as evidence.
    outstanding = [(path, job) for path, job in jobs
                   if not list((planning / 'phases').glob(f"*/{job['plan_id']}-SUMMARY.md"))]
    if outstanding:
        if len(outstanding) != 1:
            raise ValueError('Multiple outstanding jobs: report each owner before choosing a resume command')
        path, job = outstanding[0]
        plan = re.search(r'^current_plan:\s*["\']?([0-9]+)["\']?\s*$', state, re.M)
        if not plan or int(plan[1]) != int(job['plan_id'].rsplit('-', 1)[1]):
            raise ValueError('STATE current_plan disagrees with external-job ownership')
        status = job.get('status')
        valid = {'submitted', 'running', 'completed-unverified', 'failed', 'cancelled', 'timeout'}
        if status not in valid:
            raise ValueError('Invalid external-job status')
        if job.get('resume_command') != f'$gsd-execute-phase {phase}':
            raise ValueError('Manifest resume command disagrees with its phase')
        running = status in {'submitted', 'running'}
        return {'phase': phase, 'worktree': str(root), 'status': 'external_job_waiting' if running else status,
                'next_command': '$gsd-progress' if running else job['resume_command'],
                'after_job_command': job['resume_command'], 'job': str(path.relative_to(root)),
                'instruction': 'Inspect the existing job; do not resubmit.' if running else
                               'Reconcile existing artifacts and verify; never infer success from job exit alone.'}
    verdict = verification(phase)
    command = verdict.get('next_command')
    if not command:
        # Let the progress owner choose the next phase after verified completion.
        command = '$gsd-progress'
    return {'phase': phase, 'worktree': str(root), 'status': verdict['status'], 'next_command': command,
            'instruction': verdict.get('next_action', 'Use the GSD progress owner to choose the next action.')}


def main():
    root = Path(__file__).resolve().parents[2]

    def verification(phase):
        cli = Path.home() / '.codex/gsd-core/bin/gsd-tools.cjs'
        result = subprocess.run(['node', str(cli), 'query', 'find-phase', phase], cwd=root,
                                check=True, text=True, capture_output=True)
        found = json.loads(result.stdout)
        if not found.get('found'):
            result = subprocess.run(['node', str(cli), 'query', 'roadmap.get-phase', phase], cwd=root,
                                    check=True, text=True, capture_output=True)
            if not json.loads(result.stdout).get('found'):
                raise ValueError('Current phase does not exist in the roadmap')
            return {'status': 'not_started', 'next_command': '$gsd-progress',
                    'next_action': 'Phase exists in the roadmap; let GSD choose discussion or planning.'}
        result = subprocess.run(['node', str(cli), 'query', 'verification.status', found['directory']],
                                cwd=root, check=True, text=True, capture_output=True)
        return json.loads(result.stdout)

    try:
        print(json.dumps(inspect(root, verification), indent=2))
        return 0
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        print(json.dumps({'status': 'handoff_conflict', 'error': str(error)}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
