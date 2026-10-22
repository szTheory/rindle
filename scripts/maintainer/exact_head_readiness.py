#!/usr/bin/env python3
"""Finite exact-main qualification; receipts are evidence, never release authority."""
import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
POLICY_FILE = 'scripts/maintainer/validate_exact_head_readiness.exs'
PREFLIGHT = '.planning/phases/139-exact-head-readiness-closure/139-preflight.sh'
TOOLCHAIN_ENV = {'ASDF_ERLANG_VERSION': '27.3.4.15', 'ASDF_ELIXIR_VERSION': '1.17.3-otp-27',
                 'ASDF_NODEJS_VERSION': '20.18.1'}
OUTPUT_LIMIT = 32 * 1024 * 1024


class NotReady(Exception):
    """Stable public failure identity. Never include private child output."""


def require(condition, reason):
    if not condition:
        raise NotReady(reason)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat().replace('+00:00', 'Z')


def read_json(path):
    path = Path(path)
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= OUTPUT_LIMIT,
            'unavailable_json')
    def unique(items):
        result = {}
        for key, value in items:
            require(key not in result, 'duplicate_json_key')
            result[key] = value
        return result
    return json.loads(path.read_bytes(), object_pairs_hook=unique,
                      parse_constant=lambda _: (_ for _ in ()).throw(NotReady('nonfinite_json')))


def write_new(path, data):
    path = Path(path)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    payload = data if isinstance(data, bytes) else canonical(data) + b'\n'
    with open(path, 'xb', opener=lambda p, f: os.open(p, f, 0o600)) as stream:
        stream.write(payload)
    return {'path': str(path), 'sha256': digest(payload)}


def atomic(path, value):
    path = Path(path)
    temporary = path.with_name('.' + path.name + '.' + secrets.token_hex(8))
    write_new(temporary, value)
    os.replace(temporary, path)


def reference(root, path):
    path = Path(path)
    require(not path.is_symlink() and path.is_file(), 'unsafe_object')
    relative = path.relative_to(root)
    return {'path': relative.as_posix(), 'sha256': digest(path.read_bytes())}


def redact(data, env):
    for key, value in env.items():
        if len(value) > 4 and re.search(r'TOKEN|SECRET|PASSWORD|API_KEY', key):
            data = data.replace(value.encode(), b'[REDACTED]')
    data = re.sub(rb'(?i)(authorization:\s*(?:bearer|token)\s+)\S+', rb'\1[REDACTED]', data)
    return data


class Qualification:
    evidence_mode = 'execution'

    def __init__(self, root, output, repo, subject, deadline_seconds=7200):
        self.root, self.output = Path(root).resolve(), Path(output).absolute()
        self.repo, self.subject = repo, subject
        self.deadline = time.monotonic() + deadline_seconds
        self.workspace = None
        self.started = now()
        self.sequence = 0
        self.env = {**os.environ, **TOOLCHAIN_ENV, 'ERL_FLAGS': '+S 4:4', 'MIX_ENV': 'test', 'PYTHONDONTWRITEBYTECODE': '1'}
        for key in ('MIX_PATH', 'MIX_EXS', 'MIX_BUILD_PATH', 'MIX_DEPS_PATH', 'ERL_LIBS',
                    'PLT_DIR', 'RINDLE_INSTALL_SMOKE_NETWORK_VERSION', 'RINDLE_INSTALL_SMOKE_PACKAGE_ROOT'):
            self.env.pop(key, None)
        self.receipts = []
        self.cleanup_result = None

    def reserve(self):
        require(re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', self.repo) is not None, 'repository_identity')
        require(re.fullmatch(r'[0-9a-f]{40}', self.subject) is not None, 'subject_identity')
        require(not self.output.is_relative_to(self.root), 'evidence_inside_source')
        require(not self.output.exists() and not self.output.is_symlink(), 'output_exists')
        require(self.output.parent.resolve() == self.output.parent, 'output_parent_symlink')
        self.output.mkdir(mode=0o700)
        self.portable = self.output / 'portable'
        self.private = self.output / 'restricted'
        self.portable.mkdir(mode=0o700)
        self.private.mkdir(mode=0o700)
        self.attempt('collecting')

    def attempt(self, reason, **extra):
        atomic(self.output / 'attempt.json', {'schema_version': 1, 'verdict': 'not_ready',
               'reason': reason, 'subject_sha': self.subject, 'repository': self.repo,
               'requirements_credit': False, 'started_at': self.started, **extra})

    def command(self, argv, cwd=None, budget=600, env=None):
        remaining = min(budget, self.deadline - time.monotonic())
        require(remaining > 0, 'qualification_deadline')
        self.sequence += 1
        raw_path = self.private / ('command-%04d.txt' % self.sequence)
        started, stamp = time.monotonic(), now()
        timed_out = False
        with open(raw_path, 'xb', opener=lambda p, f: os.open(p, f, 0o600)) as raw:
            child = subprocess.Popen(argv, cwd=cwd or self.workspace or self.root,
                                     env=env or self.env, stdout=raw, stderr=subprocess.STDOUT,
                                     start_new_session=True)
            while child.poll() is None:
                if time.monotonic() - started >= remaining or raw.tell() > OUTPUT_LIMIT:
                    timed_out = True
                    os.killpg(child.pid, signal.SIGTERM)
                    try:
                        child.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        os.killpg(child.pid, signal.SIGKILL)
                        child.wait()
                    break
                time.sleep(0.025)
        data = raw_path.read_bytes()
        require(len(data) <= OUTPUT_LIMIT, 'command_output_limit')
        output = self.portable / 'logs' / raw_path.name
        write_new(output, redact(data, env or self.env))
        record = {'argv': argv, 'state': 'timeout' if timed_out else 'completed',
                  'exit_code': 124 if timed_out else child.returncode,
                  'duration_ms': int((time.monotonic() - started) * 1000),
                  'observation_interval': {'started_at': stamp, 'completed_at': now()},
                  'output': reference(self.portable, output)}
        require(not timed_out, 'command_timeout')
        return record, data

    def checked(self, argv, **kwargs):
        record, data = self.command(argv, **kwargs)
        require(record['exit_code'] == 0, 'command_failed')
        return record, data

    def remote_main(self):
        _, raw = self.checked(['gh', 'api', '--method', 'GET', '-H', 'Accept: application/vnd.github+json',
                              '-H', 'X-GitHub-Api-Version: 2022-11-28',
                              f'repos/{self.repo}/git/ref/heads/main'], budget=30)
        value = json.loads(raw)
        require(value.get('ref') == 'refs/heads/main', 'remote_ref_identity')
        sha = value.get('object', {}).get('sha')
        require(isinstance(sha, str) and re.fullmatch('[0-9a-f]{40}', sha), 'remote_ref_identity')
        return sha

    def checkout(self):
        self.checked(['bash', PREFLIGHT], cwd=self.root, budget=180)
        self.workspace = Path(tempfile.mkdtemp(prefix='rindle-readiness-source-')) / 'source'
        self.checked(['git', 'clone', '--no-checkout', '--no-hardlinks', str(self.root), str(self.workspace)], cwd=self.root)
        # This mutation is confined to the new disposable clone; the user's checkout is untouched.
        self.checked(['git', 'checkout', '--detach', self.subject])
        self.checked(['git', 'branch', '-f', 'main', self.subject])
        self.checked(['git', 'checkout', 'main'])
        self.checked(['git', 'remote', 'set-url', 'origin', f'https://github.com/{self.repo}.git'])
        _, head = self.checked(['git', 'rev-parse', 'HEAD'])
        require(head.decode().strip() == self.subject, 'checkout_subject')
        for argv in (['git', 'status', '--porcelain', '--untracked-files=all'],
                     ['git', 'ls-files', '--others', '--ignored', '--exclude-standard']):
            _, state = self.checked(argv)
            require(not state.strip(), 'dirty_checkout')
        self.initial_clean = True

    def prepare(self):
        _, runtime = self.checked(['elixir', '-e', 'IO.puts(System.version()); IO.puts(File.read!(Path.join([:code.root_dir(), "releases", System.otp_release(), "OTP_VERSION"])) |> String.trim())'], budget=30)
        _, node = self.checked(['node', '--version'], budget=30)
        require(runtime.decode().splitlines() == ['1.17.3', '27.3.4.15'] and node.strip() == b'v20.18.1', 'unsupported_toolchain')
        for argv in (['mix', 'local.hex', '--force'], ['mix', 'local.rebar', '--force'], ['mix', 'deps.get', '--check-locked']):
            self.checked(argv, budget=600)
        expr = ('Code.require_file("' + POLICY_FILE + '"); v=Rindle.ExactHeadReadiness; '
                'IO.puts(Jason.encode!(%{policy: v.policy(), toolchain: v.toolchain(), '
                'inputs: v.input_paths(), mutable: v.mutable_proofs(), '
                'commands: Map.new(v.required_proofs() -- v.mutable_proofs(), &{&1, v.command_prefix(&1)})}))')
        _, data = self.checked(['mix', 'run', '--no-start', '-e', expr], env={**self.env, 'RINDLE_EXACT_HEAD_LIBRARY_ONLY': '1'})
        self.policy = json.loads(data.decode().splitlines()[-1])
        self.validator_sha = digest((self.workspace / POLICY_FILE).read_bytes())
        self.inputs = {}
        for relative in self.policy['inputs']:
            path = self.workspace / relative
            dest = self.portable / 'inputs' / relative
            write_new(dest, path.read_bytes())
            self.inputs[relative] = reference(self.portable, dest)

    def gates(self):
        return [('format', self.policy['commands']['format'])]

    def gate(self, proof_id, argv):
        record, _ = self.checked(argv, budget=1800)
        self.receipts.append({'id': proof_id, 'command': record})

    def cleanup(self):
        before = []
        if self.workspace and self.workspace.exists():
            _, tracked = self.command(['git', 'diff', '--name-only', 'HEAD'])
            _, untracked = self.command(['git', 'ls-files', '--others', '--exclude-standard'])
            require(not tracked.strip() and not untracked.strip(), 'source_residue')
            before.append(str(self.workspace))
            parent = self.workspace.parent
            require(parent.name.startswith('rindle-readiness-source-') and parent != self.root and parent.is_relative_to(Path(tempfile.gettempdir()).resolve()), 'cleanup_ownership')
            shutil.rmtree(parent)
            require(not parent.exists(), 'cleanup_failed')
        return {'state': 'observed', 'errors': [], 'inventories': [
            {'kind': kind, 'before': before if kind == 'temporary' else [], 'after': [], 'allowed': []}
            for kind in ('tracked', 'untracked', 'ignored', 'generated', 'database', 'jobs', 'objects', 'provider', 'multipart', 'temporary')]}

    def finalize(self):
        refs = []
        for item in self.receipts:
            path = self.portable / 'receipts' / (item['id'] + '.json')
            write_new(path, {**item, 'schema_version': 1, 'repository': self.repo,
                            'subject_sha': self.subject, 'evidence_mode': self.evidence_mode,
                            'state': 'complete', 'outcome': 'passed'})
            refs.append({**reference(self.portable, path), 'id': item['id']})
        write_new(self.portable / 'manifest.json', {'schema_version': 1, 'state': 'incomplete',
                  'subject_sha': self.subject, 'repository': self.repo, 'proofs': refs})
        self.attempt('local_qualification_incomplete', proofs=[r['id'] for r in self.receipts], cleanup=self.cleanup_result)
        return 1

    def run(self):
        self.reserve()
        reason = None
        try:
            require(self.remote_main() == self.subject, 'main_changed')
            self.checkout()
            self.prepare()
            for proof_id, argv in self.gates():
                print('QUALIFY ' + proof_id, flush=True)
                self.gate(proof_id, argv)
            require(self.remote_main() == self.subject, 'main_changed')
        except (NotReady, OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
            reason = str(exc) if isinstance(exc, NotReady) else 'qualification_unavailable'
        finally:
            try:
                self.cleanup_result = self.cleanup()
            except (NotReady, OSError, subprocess.SubprocessError):
                reason = 'cleanup_failed'
                self.cleanup_result = {'state': 'failed', 'errors': ['cleanup_failed'], 'inventories': []}
        if reason:
            self.attempt(reason, cleanup=self.cleanup_result, proofs=[r['id'] for r in self.receipts])
            print('not_ready: ' + reason, file=sys.stderr)
            return 1
        return self.finalize()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest='operation', required=True)
    qualify = subs.add_parser('qualify')
    qualify.add_argument('--repo', required=True)
    qualify.add_argument('--subject', required=True)
    qualify.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        return Qualification(ROOT, args.output, args.repo, args.subject).run()
    except (NotReady, OSError, ValueError) as exc:
        print('not_ready: ' + (str(exc) if isinstance(exc, NotReady) else 'qualification_unavailable'), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
