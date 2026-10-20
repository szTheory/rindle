#!/usr/bin/env bash
# Clean supported contributor bootstrap; no checkout artifacts or credentials copied.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
python3 - "$repo_root" "$@" <<'PY'
import argparse, hashlib, json, os, pathlib, re, shlex, signal, subprocess, sys, tempfile, time

parser = argparse.ArgumentParser()
action = parser.add_mutually_exclusive_group(required=True)
action.add_argument('--run', action='store_true')
action.add_argument('--validate', action='store_true')
parser.add_argument('--source-root', default=sys.argv[1])
parser.add_argument('--subject-sha')
parser.add_argument('--receipt')
parser.add_argument('--full', action='store_true')
parser.add_argument('--timeout-seconds', type=int, default=1200)
args = parser.parse_args(sys.argv[2:])
if not 1 <= args.timeout_seconds <= 1200:
    parser.error('--timeout-seconds must be between 1 and 1200')
source = pathlib.Path(args.source_root).resolve()
supported = {'elixir': '1.17.3', 'otp': '27.3.4.15', 'node_major': 20}
expected_commands = [
    ['mix', 'local.hex', '--force'], ['mix', 'local.rebar', '--force'],
    ['mix', 'deps.get', '--check-locked'], ['mix', 'compile', '--warnings-as-errors'],
    ['mix', 'test', 'test/install_smoke/quality_signal_policy_test.exs', '--seed', '0']]
result = {'schema_version': 1, 'outcome': 'blocked', 'subject_sha': args.subject_sha,
          'commands': [], 'clean_checkout': False, 'full': args.full}
started = time.monotonic()
deadline = started + args.timeout_seconds
output_limit = 4 * 1024 * 1024

class Blocked(Exception):
    pass

def command(argv, cwd, env=None, budget=300):
    remaining = min(budget, deadline - time.monotonic())
    if remaining <= 0:
        raise Blocked('bootstrap_deadline')
    begin = time.monotonic()
    with tempfile.TemporaryFile() as output:
        child = subprocess.Popen(argv, cwd=cwd, env=env, stdout=output,
                                 stderr=subprocess.STDOUT, start_new_session=True)
        reason = None
        while child.poll() is None:
            if time.monotonic() - begin >= remaining:
                reason = 'command_timeout'
            elif os.fstat(output.fileno()).st_size > output_limit:
                reason = 'command_output_limit'
            if reason:
                os.killpg(child.pid, signal.SIGTERM)
                try:
                    child.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGKILL)
                    child.wait()
                raise Blocked(reason)
            time.sleep(0.02)
        output.seek(0)
        data = output.read(output_limit + 1)
    if len(data) > output_limit:
        raise Blocked('command_output_limit')
    record = {'argv': argv, 'exit_status': child.returncode,
              'output_sha256': hashlib.sha256(data).hexdigest(), 'output_bytes': len(data),
              'duration_seconds': round(time.monotonic() - begin, 3)}
    return record, data.decode('utf-8', errors='replace')

def git(*argv):
    record, text = command(['git', *argv], source, budget=60)
    if record['exit_status'] != 0:
        raise Blocked('source_git_failure')
    return text.strip()

def documented_commands(root):
    text = (root / 'CONTRIBUTING.md').read_text()
    def section(name):
        pattern = r'<!-- ' + name + r' -->\s*(.*?)\s*<!-- /' + name + r' -->'
        matches = re.findall(pattern, text, flags=re.S)
        if len(matches) != 1:
            raise Blocked('missing_or_duplicate_documented_contract')
        return matches[0]
    runtime = json.loads(section('rindle-bootstrap-runtime'))
    if runtime != supported:
        raise Blocked('stale_documented_runtime')
    block = section('rindle-bootstrap-commands')
    if not block.startswith('```sh\n') or not block.endswith('\n```'):
        raise Blocked('invalid_documented_commands')
    commands = [shlex.split(line) for line in block[6:-4].splitlines() if line.strip()]
    if commands != expected_commands:
        raise Blocked('undocumented_or_unsafe_bootstrap_command')
    return commands

receipt_fd = None
if args.run:
    if not args.receipt:
        parser.error('--run requires --receipt')
    try:
        receipt_fd = os.open(args.receipt, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except OSError:
        print(json.dumps({'outcome': 'blocked', 'reason': 'receipt_target_not_new'}))
        sys.exit(64)
try:
    commands = documented_commands(source)
    if args.validate:
        print(json.dumps({'runtime': supported, 'commands': commands,
                          'timeout_seconds': args.timeout_seconds, 'command_timeout_seconds': 300}))
        sys.exit(0)
    head = git('rev-parse', 'HEAD')
    if not args.subject_sha or not re.fullmatch(r'[0-9a-f]{40}', args.subject_sha) or args.subject_sha != head:
        raise Blocked('subject_does_not_match_HEAD')
    if git('status', '--porcelain', '--untracked-files=all'):
        raise Blocked('source_checkout_not_clean')
    result['source_tree'] = git('rev-parse', head + '^{tree}')
    runtime_record, runtime = command(['elixir', '--eval',
        'otp = :code.root_dir() |> Path.join("releases/" <> System.otp_release() <> "/OTP_VERSION") |> File.read!() |> String.trim(); IO.puts("elixir-#{System.version()}/otp-#{otp}")'], source, budget=30)
    node_record, node = command(['node', '--version'], source, budget=30)
    if runtime_record['exit_status'] != 0 or runtime.strip() != 'elixir-1.17.3/otp-27.3.4.15':
        raise Blocked('unsupported_elixir_otp')
    if node_record['exit_status'] != 0 or not re.fullmatch(r'v20\.[0-9]+\.[0-9]+\s*', node):
        raise Blocked('unsupported_node')
    result['toolchain'] = runtime.strip()
    result['node_version'] = node.strip()
    with tempfile.TemporaryDirectory(prefix='rindle-contributor-bootstrap-') as scratch:
        scratch = pathlib.Path(scratch)
        checkout = scratch / 'source'
        record, _ = command(['git', 'clone', '--quiet', '--local', '--no-hardlinks', '--no-checkout',
                             str(source), str(checkout)], source, budget=60)
        if record['exit_status'] != 0:
            raise Blocked('clean_clone_failed')
        record, _ = command(['git', 'checkout', '--quiet', '--detach', head], checkout, budget=60)
        status, clean = command(['git', 'status', '--porcelain', '--untracked-files=all'], checkout, budget=30)
        if record['exit_status'] != 0 or status['exit_status'] != 0 or clean.strip():
            raise Blocked('clean_checkout_failed')
        result['clean_checkout'] = True
        if documented_commands(checkout) != commands:
            raise Blocked('cloned_command_map_changed')
        env = dict(os.environ)
        for key in ('MIX_BUILD_PATH', 'MIX_DEPS_PATH', 'MIX_ARCHIVES', 'HEX_OFFLINE'):
            env.pop(key, None)
        env.update(MIX_ENV='test', MIX_HOME=str(scratch / 'mix'), HEX_HOME=str(scratch / 'hex'))
        for argv in commands + ([['mix', 'ci']] if args.full else []):
            record, output = command(argv, checkout, env)
            result['commands'].append(record)
            if record['exit_status'] != 0:
                result['outcome'] = 'open'
                raise Blocked('documented_command_failed')
            if argv[1] in ('test', 'ci') and (not re.search(r'\b[1-9][0-9]* tests?, 0 failures\b', output) or re.search(r'\b[1-9][0-9]* invalid\b', output)):
                raise Blocked('focused_or_full_test_did_not_execute')
            if argv[1] == 'test' and re.search(r'\b[1-9][0-9]* (skipped|excluded)\b', output):
                raise Blocked('focused_test_did_not_execute')
        result['outcome'] = 'complete'
except (Blocked, OSError, ValueError, KeyError) as error:
    result['reason'] = str(error) if isinstance(error, Blocked) else 'bootstrap_contract_unreadable'
    result['next_trigger'] = 'Resolve the recorded prerequisite or command failure and collect a new immutable receipt.'
finally:
    if receipt_fd is not None:
        result['duration_seconds'] = round(time.monotonic() - started, 3)
        with os.fdopen(receipt_fd, 'w') as receipt:
            json.dump(result, receipt, sort_keys=True)
            receipt.write('\n')
print(json.dumps(result, sort_keys=True))
sys.exit(0 if result['outcome'] == 'complete' else 1)
PY
