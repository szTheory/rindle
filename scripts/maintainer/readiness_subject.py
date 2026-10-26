"""Authenticated snapshot identity. No dispatch, merge, release or readiness authority."""
import re
from urllib.parse import urlencode

from exact_head_readiness import ROOT, NotReady, digest, now, require

POLICY = 'rindle-snapshot-v2'
CONTROL_PATHS = (
    'scripts/maintainer/readiness_subject.py',
    'scripts/maintainer/validate_exact_head_readiness.exs',
    'scripts/maintainer/exact_head_readiness.py',
    'scripts/maintainer/readiness_acceptance.py',
    'scripts/maintainer/readiness_closure.py',
    'scripts/maintainer/readiness_retention.py',
    'scripts/maintainer/readiness_adoption.py',
    'scripts/maintainer/collect_readiness_runs.py',
    'scripts/maintainer/collect_readiness_remote.py',
    'scripts/maintainer/readiness_github.py',
    'scripts/maintainer/readiness_workflow.exs',
    'scripts/maintainer/readiness_process.py',
    'scripts/maintainer/readiness_hex_audit.exs',
    'scripts/maintainer/exact_head_readiness.sh',
    'scripts/maintainer/retain_readiness_bundle.sh',
    'scripts/maintainer/qualify_generated_consumer.exs',
    '.github/workflows/readiness-retention.yml',
)


def main_sha(api):
    value, _ = api.get(api.path('git/ref/heads/main'))
    sha = value.get('object', {}).get('sha')
    require(value.get('ref') == 'refs/heads/main' and value.get('object', {}).get('type') == 'commit'
            and isinstance(sha, str) and re.fullmatch(r'[0-9a-f]{40}', sha), 'main_unavailable')
    return sha


def observe(api, subject, root=ROOT):
    """Admit only an actual push-main tip reachable from currently protected main.

    An arbitrary PR commit can be an ancestor of main; ancestry alone is insufficient.
    Controller bytes must match the selected candidate, so old policy cannot opt in.
    """
    require(isinstance(subject, str) and re.fullmatch(r'[0-9a-f]{40}', subject), 'invalid_subject')
    current = main_sha(api)
    branch, _ = api.get(api.path('branches/main'))
    require(branch.get('name') == 'main' and branch.get('protected') is True and
            branch.get('commit', {}).get('sha') == current, 'snapshot_protection_unproved')
    comparison, _ = api.get(api.path('compare/' + subject + '...' + current))
    require(comparison.get('status') in ('ahead', 'identical') and
            comparison.get('base_commit', {}).get('sha') == subject and
            comparison.get('merge_base_commit', {}).get('sha') == subject and
            comparison.get('url') == 'https://api.github.com/' + api.path('compare/' + subject + '...' + current), 'snapshot_not_main_ancestor')
    query = urlencode({'head_sha': subject, 'event': 'push', 'branch': 'main', 'per_page': 100})
    runs = api.pages('actions/workflows/ci.yml/runs?' + query, 'workflow_runs', cap=999)
    require(runs and all(type(r.get('id')) is int and r['id'] > 0 and
            type(r.get('run_attempt')) is int and r['run_attempt'] > 0 and
            isinstance(r.get('created_at'), str) and r.get('head_sha') == subject and
            r.get('head_branch') == 'main' and r.get('event') == 'push' and
            r.get('path') == '.github/workflows/ci.yml' and r.get('name') == 'CI' and
            r.get('repository', {}).get('full_name') == api.repo for r in runs), 'snapshot_main_push_unproved')
    require(len({r['id'] for r in runs}) == len(runs), 'duplicate_run')
    latest = max(runs, key=lambda r: (r['created_at'], r['id']))
    detail, _ = api.get(api.path('actions/runs/' + str(latest['id'])))
    keys = ('id', 'run_attempt', 'head_sha', 'head_branch', 'event', 'path', 'name', 'status', 'conclusion')
    require(all(detail.get(k) == latest.get(k) for k in keys) and
            detail.get('repository', {}).get('full_name') == api.repo and
            detail.get('status') == 'completed' and detail.get('conclusion') == 'success', 'latest_attempt_not_green')
    controls = {}
    for path in CONTROL_PATHS:
        raw = api.contents(path, subject)
        require((root / path).is_file() and not (root / path).is_symlink() and
                raw == (root / path).read_bytes(), 'snapshot_policy_mismatch')
        controls[path] = digest(raw)
    return {'schema': 'rindle-readiness-snapshot-subject-v2', 'repository': api.repo,
            'subject_sha': subject, 'current_main_sha': current, 'observed_at': now(),
            'authenticated': True, 'protected_main': {'name': 'main', 'protected': True, 'sha': current},
            'comparison': {'status': comparison['status'], 'base': subject, 'merge_base': subject, 'head': current},
            'push_run': {k: detail[k] for k in keys}, 'control_identity': controls,
            'requirements_credit': False}


def current_authority(api, paths):
    """Refresh mutable policy bytes, tolerating unrelated main advancement only."""
    current = main_sha(api)
    values = {p: api.contents(p, current) for p in paths}
    after = main_sha(api)
    if after != current:
        require(values == {p: api.contents(p, after) for p in paths}, 'mutable_authority_changed')
    return after, values
