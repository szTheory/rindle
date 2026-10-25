#!/usr/bin/env python3
"""Explicit credential selection and GET-only admission, never a write-grant proof."""
import argparse
import json
import os
from pathlib import Path
import re
import secrets
import subprocess


class Rejected(Exception):
    pass


def require(condition):
    if not condition:
        raise Rejected()


def outputs(values):
    # Multiline framing treats token values as opaque and prevents output injection.
    with Path(os.environ['GITHUB_OUTPUT']).open('a') as stream:
        for name, value in values.items():
            marker = secrets.token_hex(32)
            require(marker not in value)
            stream.write(f'{name}<<{marker}\n{value}\n{marker}\n' if name == 'token' else f'{name}={value}\n')


def select(profile):
    require(profile in ('release', 'merge', 'protection'))
    client, key = os.environ.get('APP_CLIENT_ID', ''), os.environ.get('APP_PRIVATE_KEY', '')
    require(bool(client) == bool(key))
    if client:
        require(re.fullmatch(r'[A-Za-z0-9_]+', client) is not None)
        require(client != os.environ.get('OTHER_APP_CLIENT_ID'))
        source, token = 'app', ''
    elif os.environ.get('LEGACY_TOKEN'):
        source, token = 'legacy', os.environ['LEGACY_TOKEN']
    elif profile != 'protection' and os.environ.get('JOB_TOKEN'):
        source, token = 'job', os.environ['JOB_TOKEN']
    else:
        require(profile == 'protection')
        source, token = 'none', ''
    result = {'source': source, 'enabled': 'false' if source == 'none' else 'true'}
    if token:
        result['token'] = token
    outputs(result)


def unique(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result)
        result[key] = value
    return result


def get(path, paginate=False):
    args = ['gh', 'api', '--hostname', 'github.com', '--method', 'GET',
            '-H', 'Accept: application/vnd.github+json', '-H', 'X-GitHub-Api-Version: 2022-11-28']
    if paginate:
        args += ['--paginate', '--slurp']
    result = subprocess.run([*args, path], capture_output=True, timeout=30, check=False)
    # gh error bodies can contain secrets. Never include them in exceptions or logs.
    require(result.returncode == 0 and len(result.stdout) <= 2_000_000)
    return json.loads(result.stdout, object_pairs_hook=unique)


def validate(source, repo, repository_id, installation_id):
    require(source in ('app', 'legacy', 'job'))
    require(os.environ.get('GH_TOKEN') and re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repo))
    require(repository_id.isdecimal() and int(repository_id) > 0)
    expected = int(repository_id)
    if source == 'app':
        # The pinned mint action authenticated the configured App/key and reports
        # its installation. The token must then enumerate precisely this repo.
        require(installation_id.isdecimal() and int(installation_id) > 0)
        pages = get('installation/repositories?per_page=100', paginate=True)
        require(isinstance(pages, list) and len(pages) == 1)
        page = pages[0]
        require(isinstance(page, dict) and type(page.get('total_count')) is int and page['total_count'] == 1)
        rows = page.get('repositories')
        require(isinstance(rows, list) and len(rows) == 1)
        record = rows[0]
    else:
        if source == 'legacy':
            identity = get('user')
            require(isinstance(identity, dict) and type(identity.get('id')) is int and identity['id'] > 0)
        record = get('repos/' + repo)
    require(isinstance(record, dict) and type(record.get('id')) is int and
            record['id'] == expected and record.get('full_name') == repo)
    print(f'credential_admitted: {source}; read-only identity, write acceptance remains pending')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('select', 'validate'))
    parser.add_argument('--profile'); parser.add_argument('--source'); parser.add_argument('--repo')
    parser.add_argument('--repository-id', default=''); parser.add_argument('--installation-id', default='')
    args = parser.parse_args()
    try:
        if args.operation == 'select':
            select(args.profile)
        else:
            validate(args.source, args.repo, args.repository_id, args.installation_id)
        return 0
    except (Rejected, OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError):
        print('::error::Selected repository credential rejected; check configuration, expiry and exact repository access. No fallback attempted.')
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
