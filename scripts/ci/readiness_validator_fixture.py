"""Suite-owned actual-validator worker; never imported by production collectors.

Only the immutable validator command is intercepted. CLI, cancellation, deadline,
archive and owned-process tests continue to use their original external commands.
"""
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/maintainer'))


class ValidatorFixture:
    def __init__(self):
        self.errors = tempfile.TemporaryFile()
        # Stay in the suite's process group so the outer CI group deadline also
        # disposes this worker, including between individual test requests.
        self.child = subprocess.Popen(
            ['mix', 'run', '--no-start', '--no-compile', '--no-deps-check',
             str(ROOT / 'scripts/ci/readiness_validator_fixture.exs')],
            cwd=ROOT, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=self.errors, env={**os.environ, 'RINDLE_EXACT_HEAD_LIBRARY_ONLY': '1'})
        self.pending = b''

    def stop(self):
        if self.child.poll() is None:
            self.child.terminate()
            try:
                self.child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.child.kill()
                self.child.wait()

    def close(self):
        try:
            self.child.stdin.close()
        except BrokenPipeError:
            pass  # A dead worker has already closed its reader; still reap/close ours.
        if self.child.poll() is None:
            try:
                self.child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.stop()
        self.child.stdout.close()
        self.errors.close()

    def request(self, argv, timeout=90):
        deadline = time.monotonic() + timeout
        try:
            self.child.stdin.write(json.dumps(argv).encode() + b'\n')
            self.child.stdin.flush()
            with selectors.DefaultSelector() as selector:
                selector.register(self.child.stdout, selectors.EVENT_READ)
                while True:
                    while b'\n' in self.pending:
                        line, self.pending = self.pending.split(b'\n', 1)
                        prefix = b'RINDLE_TEST_VALIDATOR_RESPONSE '
                        if line.startswith(prefix):
                            value = json.loads(line[len(prefix):])
                            if (not isinstance(value, dict) or set(value) != {'code'}
                                    or type(value['code']) is not int or value['code'] not in (0, 1)):
                                raise AssertionError('invalid fixture validator response')
                            return value['code'], ''
                    left = deadline - time.monotonic()
                    if left <= 0 or not selector.select(left):
                        raise AssertionError('fixture validator deadline exhausted')
                    chunk = os.read(self.child.stdout.fileno(), 65536)
                    if not chunk:
                        raise AssertionError('fixture validator exited without response')
                    self.pending += chunk
                    if len(self.pending) > 131072:
                        raise AssertionError('fixture validator output limit')
        except BaseException:
            self.stop()
            raise

    def command(self, original, owner, argv, seconds, **kwargs):
        prefix = ['mix', 'run', '--no-start', '--no-compile', '--no-deps-check',
                  str(ROOT / 'scripts/maintainer/validate_exact_head_readiness.exs')]
        if argv[:len(prefix)] != prefix:
            return original(owner, argv, seconds, **kwargs)
        args = argv[len(prefix):]
        if os.environ.get('RINDLE_READINESS_FIXTURE_PARITY') == '1':
            # Compare the real CLI against the worker for every original request.
            # Both read the same bytes; only the exclusive verdict output differs.
            path = Path(args[args.index('--verdict') + 1])
            other = path.with_name(path.name + '.fresh-process')
            fresh = list(argv)
            fresh[fresh.index('--verdict') + 1] = str(other)
            fresh_code, _ = original(owner, fresh, seconds, **kwargs)
            result = self.request(args, seconds)
            assert fresh_code == result[0], 'validator exit parity'
            assert other.read_bytes() == path.read_bytes(), 'validator verdict byte parity'
            other.unlink()
            return result
        return self.request(args, seconds)
