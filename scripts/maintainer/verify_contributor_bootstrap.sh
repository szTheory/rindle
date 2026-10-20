#!/usr/bin/env bash
set -euo pipefail
python3 - "$@" <<'PY'
import argparse, json, pathlib
parser = argparse.ArgumentParser()
parser.add_argument('--run', action='store_true')
parser.add_argument('--validate', action='store_true')
parser.add_argument('--source-root')
parser.add_argument('--subject-sha')
parser.add_argument('--receipt')
args = parser.parse_args()
result = {'outcome': 'blocked', 'reason': 'bootstrap_not_implemented'}
if args.receipt:
    pathlib.Path(args.receipt).write_text(json.dumps(result))
print(json.dumps(result))
PY
