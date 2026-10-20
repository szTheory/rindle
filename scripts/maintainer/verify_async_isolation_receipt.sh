#!/usr/bin/env bash
# Validate receipts without running the experiment or changing any evidence.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
if [ "$#" -ne 2 ] || [ "$1" != --report ]; then
  echo 'usage: verify_async_isolation_receipt.sh --report <receipt.jsonl>' >&2
  exit 64
fi
python3 - "$2" "$repo_root" <<'PY'
import json, pathlib, re, subprocess, sys

def reject(reason):
    print(json.dumps({'status': 'blocked', 'reason': reason,
                      'uncertainty': 'Receipt cannot establish the experiment outcome.',
                      'next_trigger': 'Collect a new source-bound receipt after resolving validation failure.'}))
    sys.exit(1)

try:
    path = pathlib.Path(sys.argv[1])
    if not path.is_file() or path.stat().st_size > 1048576:
        reject('missing_or_oversized_receipt')
    # Duplicate keys, non-finite numbers and empty records cannot establish evidence.
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError('duplicate key')
            result[key] = value
        return result
    records = [json.loads(line, object_pairs_hook=pairs,
                          parse_constant=lambda _: (_ for _ in ()).throw(ValueError('nonfinite')))
               for line in path.read_text().splitlines()]
    runner = pathlib.Path(sys.argv[2]) / 'scripts/maintainer/async_isolation_evidence.sh'
    declaration = [json.loads(line) for line in subprocess.check_output(
        ['bash', str(runner), '--validate'], text=True).splitlines()]
    seeds, argv, fields = declaration[0]['seeds'], declaration[1]['argv'], declaration[2]['fields']
    header = {'kind': 'async_isolation_evidence', 'schema': fields}
    if not records or records[0] != header:
        reject('invalid_header')
    rows = records[1:]
    if not rows or len(rows) > len(seeds):
        reject('invalid_seed_prefix_length')
    sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=sys.argv[2], text=True).strip()
    supported = 'elixir-1.17.3/otp-27.3.4.15'
    for index, row in enumerate(rows):
        if not isinstance(row, dict) or set(row) != set(fields):
            reject('invalid_row_schema')
        expected_argv = ' '.join(str(seeds[index]) if item == 'SEED' else item for item in argv)
        if type(row['iteration']) is not int or row['iteration'] != index + 1 or \
           type(row['seed']) is not int or row['seed'] != seeds[index] or \
           row['sha'] != sha or row['toolchain'] != supported or row['argv'] != expected_argv:
            reject('seed_subject_toolchain_or_argv_mismatch')
        status = row['exit_status']
        if type(status) is not int or not 0 <= status <= 255:
            reject('invalid_exit_status')
        location = row['failure_location']
        if status == 0 and location is not None:
            reject('passing_row_has_failure_location')
        if status != 0:
            if index != len(rows) - 1:
                reject('post_red_record')
            if not isinstance(location, str) or not re.fullmatch(r'[A-Za-z0-9_.:-]{1,160}', location):
                reject('invalid_failure_location')
    last = rows[-1]
    if last['exit_status'] != 0:
        print(json.dumps({'status': 'open', 'sha': sha, 'toolchain': supported,
                          'iterations': len(rows), 'failed_seed': last['seed'],
                          'exit_status': last['exit_status'], 'failure_location': last['failure_location'],
                          'uncertainty': 'A first-red run is reproducible evidence, not proof that async isolation is safe.',
                          'next_trigger': 'Investigate the recorded seed and failure location, then collect a new immutable receipt after a source fix.'}))
    elif len(rows) != len(seeds):
        reject('incomplete_all_zero_prefix')
    else:
        print(json.dumps({'status': 'complete', 'sha': sha, 'toolchain': supported,
                          'iterations': len(rows),
                          'uncertainty': 'The fixed seed matrix is finite and does not prove every schedule safe.',
                          'next_trigger': 'Reopen on a new reproducible isolation failure or source change.'}))
except (OSError, ValueError, KeyError, IndexError, TypeError, subprocess.CalledProcessError):
    reject('malformed_or_unreadable_receipt')
PY
