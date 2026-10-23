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

from readiness_process import popen_owned, stop_owned

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


def file_digest(path):
    value=hashlib.sha256()
    with open(path,'rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):
            value.update(block)
    return value.hexdigest()


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


class OwnedServices:
    """Only the two declared services in a newly reserved namespace may be disposed."""
    def __init__(self, owner):
        self.owner = owner
        self.project = 'rindle-readiness-' + owner.run_id
        self.file = owner.private / 'compose.json'
        self.password = secrets.token_hex(24)
        owner.env['PGPASSWORD'] = self.password
        self.expected = {self.project + '-postgres-1', self.project + '-minio-1'}
        self.started = False

    def compose(self, *args):
        return self.owner.checked(['docker', 'compose', '-p', self.project, '-f', str(self.file), *args], budget=180)

    def start(self):
        config = {'services': {
            'postgres': {'image': 'postgres:16-alpine', 'environment': {'POSTGRES_PASSWORD': self.password},
                         'ports': ['127.0.0.1::5432'], 'volumes': ['database:/var/lib/postgresql/data'],
                         'healthcheck': {'test': ['CMD-SHELL', 'pg_isready -U postgres'], 'interval': '2s', 'timeout': '3s', 'retries': 30}},
            'minio': {'image': 'cgr.dev/chainguard/minio@sha256:2136d593beacf4461187035eca949fe49abd589d5079735025c711ca58fee0c8',
                      'command': ['server', '/data'], 'environment': {'MINIO_ROOT_USER': 'twinlocal', 'MINIO_ROOT_PASSWORD': self.password},
                      'ports': ['127.0.0.1::9000'], 'volumes': ['objects:/data'],
                      'healthcheck': {'test': ['CMD-SHELL', 'MC_HOST_local=http://twinlocal:$$MINIO_ROOT_PASSWORD@localhost:9000 mc ready local >/dev/null'], 'interval': '2s', 'timeout': '3s', 'retries': 30}}},
            'volumes': {'database': {}, 'objects': {}}}
        write_new(self.file, config)
        self.compose_sha = digest(self.file.read_bytes())
        write_new(self.owner.private/'services.json', {'schema_version':1,'project':self.project,
                  'run_id':self.owner.run_id,'subject_sha':self.owner.subject,'repository':self.owner.repo,
                  'compose_sha256':self.compose_sha})
        self.compose('up', '-d', '--wait')
        _, pg = self.compose('port', 'postgres', '5432')
        _, minio = self.compose('port', 'minio', '9000')
        pg_port, object_port = pg.decode().strip().rsplit(':', 1)[1], minio.decode().strip().rsplit(':', 1)[1]
        require(pg_port.isdigit() and object_port.isdigit(), 'service_port_identity')
        bucket = self.project
        self.compose('exec', '-T', 'minio', 'sh', '-c',
                     'export MC_HOST_local="http://twinlocal:$MINIO_ROOT_PASSWORD@localhost:9000"; mc mb local/' + bucket)
        self.owner.env.update({'PGHOST': '127.0.0.1', 'PGPORT': pg_port, 'PGUSER': 'postgres',
                               'MIX_TEST_PARTITION': '_' + self.project.replace('-', '_'),
                               'RINDLE_MINIO_URL': 'http://127.0.0.1:' + object_port,
                               'RINDLE_MINIO_BUCKET': bucket, 'RINDLE_MINIO_ACCESS_KEY': 'twinlocal',
                               'RINDLE_MINIO_SECRET_KEY': self.password, 'RINDLE_MINIO_REGION': 'us-east-1'})
        self.started = True

    def inventory(self):
        _, output = self.owner.checked(['docker', 'ps', '--all', '--no-trunc', '--filter', 'label=com.docker.compose.project=' + self.project, '--format', '{{.ID}}'])
        ids = output.decode().split()
        require(len(ids) <= 2, 'foreign_service_resource')
        if ids:
            _, raw = self.owner.checked(['docker', 'inspect', *ids])
            values = json.loads(raw)
            require(len(values) == len(ids), 'incomplete_service_inventory')
            for value in values:
                labels = value['Config']['Labels']
                require(labels['com.docker.compose.project'] == self.project and
                        value['Name'].lstrip('/') in self.expected, 'foreign_service_resource')
                require(all(m['Type'] == 'volume' and m['Name'] in [self.project+'_database', self.project+'_objects'] for m in value['Mounts']), 'foreign_service_mount')
        return ids

    def snapshot(self):
        result={kind:[] for kind in ('database','jobs','objects','provider','multipart')}
        if not self.started or not self.inventory():
            return result
        _, raw=self.compose('exec','-T','postgres','psql','-U','postgres','-Atc',
                           "SELECT datname FROM pg_database WHERE NOT datistemplate AND datname <> 'postgres' ORDER BY datname")
        databases=raw.decode().splitlines()
        require(all(re.fullmatch(r'[A-Za-z0-9_]+',name) for name in databases),'database_inventory')
        result['database']=databases
        for database in databases:
            prefix=['exec','-T','postgres','psql','-U','postgres','-d',database,'-Atc']
            _, exists=self.compose(*prefix,"SELECT to_regclass('public.oban_jobs') IS NOT NULL")
            if exists.strip()==b't':
                _, jobs=self.compose(*prefix,'SELECT state,count(*) FROM public.oban_jobs GROUP BY state ORDER BY state')
                result['jobs'].append(database+':'+jobs.decode().strip())
            for schema in ('public','rindle'):
                _, exists=self.compose(*prefix,"SELECT to_regclass('"+schema+".media_provider_assets') IS NOT NULL")
                if exists.strip()==b't':
                    _, count=self.compose(*prefix,'SELECT count(*) FROM '+schema+'.media_provider_assets')
                    result['provider'].append(database+':'+schema+':'+count.decode().strip())
        for kind, flags in (('objects',''),('multipart','--incomplete ')):
            _, listing=self.compose('exec','-T','minio','sh','-c',
                'export MC_HOST_local="http://twinlocal:$MINIO_ROOT_PASSWORD@localhost:9000"; mc ls --recursive --json '+flags+'local/'+self.project)
            records=[json.loads(line) for line in listing.decode().splitlines()]
            require(all(isinstance(item,dict) and item.get('status')=='success' for item in records),'object_inventory')
            result[kind]=[digest(canonical(item)) for item in records]
        return result

    def cleanup(self):
        if not self.file.exists():
            return []
        require(not self.file.is_symlink() and digest(self.file.read_bytes()) == self.compose_sha, 'service_descriptor_changed')
        before = self.inventory()
        for suffix in ('_database', '_objects'):
            _, users = self.owner.checked(['docker','ps','--all','--no-trunc','--filter','volume='+self.project+suffix,'--format','{{.ID}}'])
            require(set(users.decode().split()) <= set(before), 'foreign_volume_user')
        _, names = self.owner.checked(['docker','network','ls','--filter','label=com.docker.compose.project='+self.project,'--format','{{.Name}}'])
        require(set(names.decode().split()) <= {self.project+'_default'}, 'foreign_network')
        for name in names.decode().split():
            _, network = self.owner.checked(['docker','network','inspect',name])
            records = json.loads(network)
            require(len(records) == 1 and set(records[0]['Containers']) <= set(before), 'foreign_network_user')
        # Exact namespace, no orphan/force/global prune options. Recheck absence afterwards.
        self.compose('down', '--volumes')
        require(not self.inventory(), 'service_cleanup_failed')
        for kind in ('volume', 'network'):
            _, raw = self.owner.checked(['docker', kind, 'ls', '--filter', 'label=com.docker.compose.project=' + self.project, '--format', '{{.Name}}'])
            require(not raw.strip(), 'service_cleanup_residue')
        return before


class Qualification:
    evidence_mode = 'execution'

    def __init__(self, root, output, repo, subject, deadline_seconds=7200):
        self.root, self.output = Path(root).resolve(), Path(output).absolute()
        self.repo, self.subject = repo, subject
        self.run_id = secrets.token_hex(16)
        self.deadline = time.monotonic() + deadline_seconds
        self.workspace = None
        self.started = now()
        self.sequence = 0
        self.env = {**os.environ, **TOOLCHAIN_ENV, 'ERL_FLAGS': '+S 4:4', 'MIX_ENV': 'test', 'PYTHONDONTWRITEBYTECODE': '1'}
        for key in ('MIX_PATH', 'MIX_EXS', 'MIX_BUILD_PATH', 'MIX_DEPS_PATH', 'ERL_LIBS',
                    'PLT_DIR','MIX_BIN','DIALYZER_LOG','MIX_ARCHIVES','ERL_AFLAGS','ERL_ZFLAGS',
                    'ELIXIR_ERL_OPTIONS','HEX_OFFLINE','GH_DEBUG','GH_FORCE_TTY',
                    'RINDLE_INSTALL_SMOKE_NETWORK_VERSION','RINDLE_INSTALL_SMOKE_PACKAGE_ROOT'):
            self.env.pop(key, None)
        for key in list(self.env):
            if key.startswith(('COMPOSE_','RINDLE_HYGIENE_','GOOGLE_','RINDLE_GCS_','RINDLE_MUX_','AWS_','MUX_','COVERALLS_')) or key == 'HEX_API_KEY':
                self.env.pop(key,None)
        self.env.update({'NO_COLOR':'1','MIX_ANSI_ENABLED':'false'})
        self.receipts = []
        self.cleanup_result = None
        self.services = None
        self.matrix = None
        self.consumer_context = None

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
        self.env.update({'MIX_HOME':str(self.private/'mix-home'), 'HEX_HOME':str(self.private/'hex-home'),
                         'npm_config_cache':str(self.private/'npm-cache'),
                         'PLAYWRIGHT_BROWSERS_PATH':str(self.private/'browsers')})
        self.attempt('collecting')

    def attempt(self, reason, **extra):
        atomic(self.output / 'attempt.json', {'schema_version': 1, 'verdict': 'not_ready',
               'reason': reason, 'subject_sha': self.subject, 'repository': self.repo,
               'requirements_credit':False,'started_at':self.started,'run_id':self.run_id,
               'workspace':str(self.workspace) if self.workspace else None,
               'repair_command':'bash scripts/maintainer/exact_head_readiness.sh cleanup --output '+str(self.output), **extra})

    def command(self, argv, cwd=None, budget=600, env=None):
        remaining = min(budget, self.deadline - time.monotonic())
        require(remaining > 0, 'qualification_deadline')
        self.sequence += 1
        raw_path = self.private / ('command-%04d.txt' % self.sequence)
        started, stamp = time.monotonic(), now()
        timed_out = False
        child = None
        try:
            with open(raw_path, 'xb', opener=lambda p, f: os.open(p, f, 0o600)) as raw:
                child = popen_owned(argv, cwd=cwd or self.workspace or self.root,
                                         env=env or self.env, stdout=raw, stderr=subprocess.STDOUT)
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
        except BaseException:
            stop_owned(child, 2)
            raise
        require(raw_path.stat().st_size <= OUTPUT_LIMIT, 'command_output_limit')
        data = raw_path.read_bytes()
        output = self.portable / 'logs' / raw_path.name
        write_new(output, redact(data, env or self.env))
        record = {'argv': argv, 'state': 'timeout' if timed_out else 'completed',
                  'exit_code': 124 if timed_out else child.returncode,
                  'duration_ms': int((time.monotonic() - started) * 1000),
                  'environment':{key:(env or self.env)[key] for key in ('MIX_ENV','ASDF_ERLANG_VERSION','ASDF_ELIXIR_VERSION','ASDF_NODEJS_VERSION') if key in (env or self.env)},
                  'observation_interval': {'started_at': stamp, 'completed_at': now()},
                  'output': reference(self.portable, output)}
        write_new(raw_path.with_suffix('.json'), record)
        require(not timed_out, 'command_timeout')
        return record, data

    def checked(self, argv, **kwargs):
        record, data = self.command(argv, **kwargs)
        require(record['exit_code'] == 0, 'command_failed')
        return record, data

    def remote_main(self):
        _, raw = self.checked(['gh', 'api', '--method', 'GET', '-H', 'Accept: application/vnd.github+json',
                              '-H', 'X-GitHub-Api-Version: 2022-11-28',
                              f'repos/{self.repo}/git/ref/heads/main'], budget=30, cwd=self.root)
        value = json.loads(raw)
        require(value.get('ref') == 'refs/heads/main', 'remote_ref_identity')
        sha = value.get('object', {}).get('sha')
        require(isinstance(sha, str) and re.fullmatch('[0-9a-f]{40}', sha), 'remote_ref_identity')
        return sha

    def checkout(self):
        self.checked(['bash', PREFLIGHT], cwd=self.root, budget=180)
        self.workspace = Path(tempfile.mkdtemp(prefix='rindle-readiness-source-'+self.run_id+'-')).resolve() / 'source'
        self.checked(['git','clone','--no-checkout','--depth','1','--branch','main',f'https://github.com/{self.repo}.git',str(self.workspace)],cwd=self.root)
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
        runtime_record, runtime = self.checked(['elixir', '-e', 'IO.puts(System.version()); IO.puts(File.read!(Path.join([:code.root_dir(), "releases", System.otp_release(), "OTP_VERSION"])) |> String.trim())'], budget=30)
        node_record, node = self.checked(['node', '--version'], budget=30)
        require(runtime.decode().splitlines() == ['1.17.3', '27.3.4.15'] and node.strip() == b'v20.18.1', 'unsupported_toolchain')
        self.runtime_evidence={'elixir':runtime_record['output'],'node':node_record['output']}
        for argv in (['mix', 'local.hex', '--force'], ['mix', 'local.rebar', '--force'], ['mix', 'deps.get', '--check-locked'], ['bash','scripts/ci/ensure_phx_new.sh'], ['mix','deps.compile']):
            self.checked(argv, budget=600)
        expr = ('Code.require_file("' + POLICY_FILE + '"); v=Rindle.ExactHeadReadiness; '
                'IO.puts(Jason.encode!(%{policy: v.policy(), toolchain: v.toolchain(), '
                'inputs: v.input_paths(), mutable: v.mutable_proofs(), '
                'commands: Map.new(v.required_proofs() -- v.mutable_proofs(), &{&1, v.command_prefix(&1)})}))')
        _, data = self.checked(['mix','run','--no-start','--no-compile','--no-deps-check','-e',expr], env={**self.env, 'RINDLE_EXACT_HEAD_LIBRARY_ONLY': '1'})
        self.policy = json.loads(data.decode().splitlines()[-1])
        self.checked(['npm','ci'],cwd=self.workspace/'examples/adoption_demo',budget=600)
        self.checked(['npx','playwright','install','chromium'],cwd=self.workspace/'examples/adoption_demo',budget=600)
        require(digest((self.workspace/'scripts/maintainer/exact_head_readiness.py').read_bytes()) == digest(Path(__file__).read_bytes()), 'collector_subject_mismatch')
        self.validator_sha = digest((self.workspace / POLICY_FILE).read_bytes())
        self.inputs = {}
        for relative in self.policy['inputs']:
            path = self.workspace / relative
            dest = self.portable / 'inputs' / relative
            write_new(dest, path.read_bytes())
            self.inputs[relative] = reference(self.portable, dest)

    def gates(self):
        order = ['format', 'compile', 'credo', 'dialyzer-fresh', 'dialyzer-restored',
                 'coverage', 'security', 'docs', 'contracts', 'package', 'generated-consumer',
                 'doctor', 'twin-recovery', 'inbox-ledger', 'contributor-bootstrap',
                 'async-isolation', 'release-truth', 'hygiene']
        require(set(order) == set(self.policy['commands']), 'gate_registry_drift')
        return [(name, self.policy['commands'][name]) for name in order]

    def start_services(self):
        _, self.cache_before = self.checked(['docker','system','df','--format','{{json .}}'],budget=30)
        self.services = OwnedServices(self)
        self.services.start()
        self.temporary = self.private / 'temporary'
        self.temporary.mkdir(mode=0o700)
        self.env['TMPDIR'] = str(self.temporary)

    def upstream(self):
        # Read the delivered policy, preserving the original blocked numeric-speed receipt.
        path = self.workspace / '.planning/phases/136-measured-quality-and-ci-ratchets/136-SPEED-DEFERRAL.json'
        value = read_json(path)
        require(value.get('acceptance_status') == 'deferred_unfinished' and value.get('acceptance_credit') is False,
                'timing_deferral_drift')
        self.timing_sha = digest(path.read_bytes())
        historical = self.workspace/'.planning/phases/136-measured-quality-and-ci-ratchets/136-QUALIFICATION-CLOSEOUT.json'
        prior = read_json(historical)
        require(prior.get('outcome') == 'blocked', 'historical_timing_receipt_changed')
        prerequisite_path=self.portable/'upstream/prerequisites.json'
        write_new(prerequisite_path, {
            'evidence_scope':'historical_prerequisite_only', 'numeric_speed_acceptance':'deferred_unfinished',
            'acceptance_credit':False, 'deferral_sha256':self.timing_sha,
            'original_qualification_sha256':digest(historical.read_bytes()),
            'original_subject_sha':prior.get('subject_sha'), 'original_outcome':prior.get('outcome')})
        self.prerequisites=reference(self.portable,prerequisite_path)

    def stage_package(self, archive):
        sys.path.insert(0, str(self.workspace / 'scripts/maintainer'))
        import built_package_twin as twin
        self.twin = twin
        self.package_identity = twin.archive_identity(archive)
        outer = self.private / 'hex'
        outer.mkdir()
        twin.extract_tar(archive.read_bytes(), outer)
        self.package_root = self.private / 'consumer-package'
        self.package_root.mkdir()
        twin.extract_tar((outer/'contents.tar.gz').read_bytes(), self.package_root, compressed=True)
        twin.validate_package_files(self.package_root)
        entries = [(p.relative_to(self.package_root).as_posix(), digest(p.read_bytes()))
                   for p in sorted(self.package_root.rglob('*')) if p.is_file()]
        objects = {'package_tar_sha256': archive.read_bytes(),
                   'package_metadata_sha256': (outer/'metadata.config').read_bytes(),
                   'package_tree_sha256': json.dumps(entries, separators=(',', ':')).encode()}
        self.package_files = {}
        for kind, data in objects.items():
            require(digest(data) == self.package_identity[kind], 'package_digest_kind')
            dest = self.portable/'package'/kind
            write_new(dest, data)
            self.package_files[kind] = reference(self.portable, dest)
        # Hex's generated-consumer helper uses this explicitly named metadata object.
        shutil.copyfile(outer/'metadata.config', self.package_root/'hex_metadata.config')
        self.env['RINDLE_INSTALL_SMOKE_PACKAGE_ROOT'] = str(self.package_root)

    def plt_inventory(self):
        paths=sorted((self.workspace/'priv/plts').glob('*.plt'))
        require(paths and all(p.is_file() and not p.is_symlink() for p in paths),'plt_inventory_missing')
        return [{'relative_path':p.relative_to(self.workspace).as_posix(),'file_sha256':file_digest(p),'bytes':p.stat().st_size} for p in paths]

    def gate(self, proof_id, argv):
        extras = []
        env = self.env
        cwd = self.workspace
        stamp = time.time()
        if proof_id in ('dialyzer-fresh','dialyzer-restored'):
            env={**self.env,'DIALYZER_LOG':str(self.private/(proof_id+'.txt'))}
        if proof_id == 'dialyzer-restored':
            restored_before=self.plt_inventory()
            require(restored_before == self.fresh_plt, 'restored_plt_input_changed')
        if proof_id == 'docs':
            env = {**self.env, 'MIX_ENV':'dev'}
        elif proof_id == 'coverage':
            self.checked(['git', 'rev-parse', 'HEAD'])
        elif proof_id == 'package':
            archive = self.private/'package.tar'
            argv = argv + ['--output', str(archive)]
        elif proof_id == 'generated-consumer':
            self.consumer_context = self.private/'consumer-context.json'
            self.consumer_receipt = self.portable/'upstream/consumer.json'
            self.consumer_receipt.parent.mkdir(mode=0o700, exist_ok=True)
            env = {**self.env, 'RINDLE_READINESS_CONSUMER_CONTEXT': str(self.consumer_context),
                   'RINDLE_READINESS_CONSUMER_RECEIPT': str(self.consumer_receipt)}
        elif proof_id == 'doctor':
            context = read_json(self.consumer_context)
            cwd = Path(context['generated_app_root'])
            require(cwd.is_relative_to(self.temporary) and cwd.is_dir(), 'consumer_host_identity')
            env = {**self.env, **context['execution_env']}
        elif proof_id == 'twin-recovery':
            self.matrix = self.private/'matrix'
            argv = argv + ['--evidence-dir', str(self.matrix), '--cleanup']
        elif proof_id == 'inbox-ledger':
            # The dedicated remote collector owns current inventory and visibility; this is the tracked policy shape gate.
            argv = argv + ['--ledger', '.planning/INBOX-LEDGER.json', '--offline']
        elif proof_id == 'contributor-bootstrap':
            self.bootstrap = self.private/'bootstrap.json'
            argv = argv + ['--receipt', str(self.bootstrap), '--subject-sha', self.subject]
        elif proof_id == 'async-isolation':
            self.async_report = self.private/'async.jsonl'
            argv = argv + ['--report', str(self.async_report)]
            env = {**self.env, 'RINDLE_ASYNC_EVIDENCE_DIR': str(self.private)}
        record, raw = self.checked(argv, cwd=cwd, budget=2400, env=env)
        if proof_id == 'dialyzer-fresh':
            require(raw.count(b'mode=fresh action=build-plt')==1 and raw.count(b'mode=fresh attempt=1 action=analyze')==1, 'fresh_plt_missing_execution')
            self.fresh_plt=self.plt_inventory()
            path=self.portable/'upstream/fresh-plt.json';write_new(path,{'subject_sha':self.subject,'files':self.fresh_plt});extras.append(reference(self.portable,path))
        elif proof_id == 'dialyzer-restored':
            require(b'fingerprint=old-plt' not in raw and b'recovery=rebuild' not in raw and raw.count(b'mode=restored attempt=1 action=analyze')==1, 'stale_restored_plt')
            after=self.plt_inventory()
            require(after == restored_before, 'restored_plt_changed')
            path=self.portable/'upstream/restored-plt.json';write_new(path,{'subject_sha':self.subject,'before':restored_before,'after':after});extras.append(reference(self.portable,path))
        elif proof_id == 'package':
            self.stage_package(archive)
        elif proof_id == 'doctor':
            require(b'Environment checks passed' in raw and b'doctor.migrations.pending' in raw, 'doctor_missing_proof')
        elif proof_id == 'generated-consumer':
            receipt = read_json(self.consumer_receipt)
            require(receipt['subject_sha'] == self.subject and receipt['package_sha256'] == self.package_identity['package_metadata_sha256'] and receipt['dependency_source']['type'] == 'path', 'consumer_package_identity')
            require(all(receipt['results'][name]['exit_code'] == 0 for name in ('compile', 'boot', 'smoke_lifecycle')), 'consumer_command_evidence')
            payload = [(p.relative_to(self.package_root).as_posix(), digest(p.read_bytes())) for p in sorted(self.package_root.rglob('*')) if p.is_file() and p.relative_to(self.package_root).as_posix() != 'hex_metadata.config']
            require(digest(json.dumps(payload,separators=(',',':')).encode()) == self.package_identity['package_tree_sha256'], 'consumer_payload_changed')
            boundary = self.portable/'upstream/consumer-identity.json'
            write_new(boundary, {**self.package_identity, 'legacy_package_sha256_digest_kind':'hex_metadata.config',
                       'legacy_metadata_sha256':receipt['package_sha256'],
                       'generated_consumer_tree_sha256':receipt['unpacked_tree_sha256'],
                       'generated_consumer_tree_algorithm':'sorted-path-NUL-content-sha256-newline-including-hex-metadata',
                       'source_sha':self.subject, 'receipt_sha256':digest(self.consumer_receipt.read_bytes())})
            extras.extend([reference(self.portable,self.consumer_receipt),reference(self.portable,boundary)])
        elif proof_id == 'twin-recovery':
            verify = ['python3', 'scripts/maintainer/built_package_twin.py', 'verify', '--inputs', str(self.matrix/'inputs.json'), '--receipt', str(self.matrix/'receipt.json')]
            self.checked(verify, budget=120)
            inputs = read_json(self.matrix/'inputs.json')
            require(inputs['source_sha'] == self.subject and all(inputs[k] == v for k, v in self.package_identity.items()), 'matrix_package_identity')
            for name in ('inputs.json', 'receipt.json'):
                dest = self.portable/'upstream/matrix'/name
                write_new(dest, (self.matrix/name).read_bytes())
                extras.append(reference(self.portable, dest))
            # Repeating exact descriptor disposal is the observed absence probe.
            self.checked(['python3','scripts/maintainer/built_package_twin.py','cleanup','--descriptor',str(self.matrix/'resources.json')], budget=180)
        elif proof_id == 'coverage':
            subject = self.private/'subject.json'
            _, tree = self.checked(['git', 'rev-parse', self.subject+'^{tree}'])
            write_new(subject, {'subject_sha': self.subject, 'source_tree': tree.decode().strip()})
            receipt = self.private/'coverage.json'
            self.checked(['mix','run','--no-start','scripts/maintainer/verify_coverage_floor.exs','--write',
                          '--subject-file',str(subject),'--receipt',str(receipt),'--artifact',str(self.workspace/'cover/excoveralls.json'),
                          '--local-output',str(self.portable/record['output']['path']),'--local-exit','0','--run-started-at',str(stamp)], budget=120)
            self.checked(['mix','run','--no-start','scripts/maintainer/verify_coverage_floor.exs','--verify-only',
                          '--subject-file',str(subject),'--receipt',str(receipt)], budget=120)
            value = read_json(receipt)
            require(value['outcome'] == 'complete' and value['subject_sha'] == self.subject, 'coverage_floor')
            dest = self.portable/'upstream/coverage.json'; write_new(dest, receipt.read_bytes()); extras.append(reference(self.portable,dest))
        elif proof_id == 'contributor-bootstrap':
            value = read_json(self.bootstrap)
            require(value['outcome'] == 'complete' and value['subject_sha'] == self.subject and value['full'] is True, 'bootstrap_incomplete')
            dest = self.portable/'upstream/bootstrap.json'; write_new(dest, self.bootstrap.read_bytes()); extras.append(reference(self.portable,dest))
        elif proof_id == 'async-isolation':
            self.checked(['bash','scripts/maintainer/verify_async_isolation_receipt.sh','--report',str(self.async_report)],budget=120)
            lines = [json.loads(line) for line in self.async_report.read_text().splitlines()]
            records = [item for item in lines if item.get('kind') == 'iteration']
            if not records:
                records = [item for item in lines if 'iteration' in item]
            require(len(records) == 25 and all(item.get('sha') == self.subject and item.get('exit_status') == 0 for item in records), 'async_incomplete')
            dest=self.portable/'upstream/async.jsonl'; write_new(dest,self.async_report.read_bytes()); extras.append(reference(self.portable,dest))
        elif proof_id == 'hygiene':
            require(re.search(rb'Summary: [0-9]+ PASS, 0 WARN, 0 BLOCK', raw) is not None, 'hygiene_warning')
        self.receipts.append({'id': proof_id, 'command': record, 'references': extras})

    def cleanup(self):
        before = []
        service_snapshot = self.services.snapshot() if self.services else {}
        services_before = self.services.cleanup() if self.services else []
        cache_after = None
        if self.services:
            _, cache_after = self.checked(['docker','system','df','--format','{{json .}}'],budget=30)
        if self.matrix and (self.matrix/'resources.json').exists():
            self.checked(['python3','scripts/maintainer/built_package_twin.py','cleanup','--descriptor',str(self.matrix/'resources.json')], budget=180)
        if getattr(self, 'temporary', None) and self.temporary.exists():
            before.extend(str(p) for p in self.temporary.iterdir())
            shutil.rmtree(self.temporary)
            require(not self.temporary.exists(), 'temporary_residue')
        source_ignored=[]
        if self.workspace and self.workspace.exists():
            _, ignored=self.checked(['git','ls-files','--others','--ignored','--exclude-standard','--directory'])
            source_ignored=ignored.decode().splitlines()
            _, tracked = self.checked(['git', 'diff', '--name-only', 'HEAD'])
            _, untracked = self.checked(['git', 'ls-files', '--others', '--exclude-standard'])
            require(not tracked.strip() and not untracked.strip(), 'source_residue')
            before.append(str(self.workspace))
            parent = self.workspace.parent
            require(parent.name.startswith('rindle-readiness-source-'+self.run_id+'-') and parent != self.root and parent.is_relative_to(Path(tempfile.gettempdir()).resolve()), 'cleanup_ownership')
            shutil.rmtree(parent)
            require(not parent.exists(), 'cleanup_failed')
        inventories = []
        for kind in ('tracked','untracked','ignored','generated','database','jobs','objects','provider','multipart','temporary'):
            entry={'kind':kind, 'before':before if kind=='temporary' else service_snapshot.get(kind,services_before) if kind in ('database','jobs','objects','provider','multipart') else source_ignored if kind=='ignored' else [], 'after':[], 'allowed':[]}
            if kind=='temporary':
                entry['after']=[str(self.output)]
                entry['allowed']=[{'path':str(self.output),'class':'evidence_output','reason':'This reserved attempt retains portable evidence, restricted diagnostics and tool caches.'}]
            if kind=='ignored' and cache_after is not None:
                marker='docker-build-cache:'+digest(cache_after)
                entry['before'].append('docker-build-cache:'+digest(self.cache_before))
                entry['after']=[marker]
                entry['allowed']=[{'path':marker,'class':'tool_cache','reason':'Observed Docker build cache; no run-owned live container, named volume or network remains.'}]
            inventories.append(entry)
        return {'state':'observed','errors':[],'inventories':inventories}

    def finalize(self):
        require(self.cleanup_result.get('state') == 'observed' and self.cleanup_result.get('errors') == [], 'cleanup_failed')
        refs = list(self.inputs.values()) + list(self.package_files.values()) + list(self.runtime_evidence.values())
        for item in self.receipts:
            refs.extend([item['command']['output'], *item.get('references', [])])
        for ref in refs:
            path = self.portable/ref['path']
            require(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(self.portable) and digest(path.read_bytes()) == ref['sha256'], 'evidence_bytes_changed')
        expected = set(self.policy['commands'])
        require(len(self.receipts) == len(expected) and {item['id'] for item in self.receipts} == expected,
                'incomplete_local_registry')
        completed = now()
        m = {'schema_version': 1, 'state': 'incomplete', 'local_state': 'complete',
             'policy': self.policy['policy'], 'validator_sha256': self.validator_sha,
             'repository': self.repo, 'subject_sha': self.subject, 'remote_main_before': self.subject,
             'remote_main_after': self.subject, 'toolchain': self.policy['toolchain'],
             'input_identity': {path: ref['sha256'] for path, ref in self.inputs.items()},
             'input_files': self.inputs, 'runtime_evidence': self.runtime_evidence, 'package_identity': self.package_identity,
             'package_files': self.package_files, 'evidence_mode': self.evidence_mode,
             'observation_interval': {'started_at': self.started, 'completed_at': completed},
             'cleanup': self.cleanup_result, 'adoption': {'class': 'maintainer_operated_synthetic',
             'independent_pilot_credit': False, 'pilot_01': 'open', 'pilot_02': 'open', 'one_point_zero_authority': False}}
        refs = []
        for item in self.receipts:
            command = item['command']
            r = {**{key: m[key] for key in ('repository','subject_sha','policy','validator_sha256','toolchain','input_identity','package_identity','evidence_mode')},
                 'schema_version': 1, 'id': item['id'], 'state': 'complete', 'outcome': 'passed',
                 'applicability': 'required', 'command': command, 'tool_identity': {'collector': digest(Path(__file__).read_bytes())},
                 'observation_interval': command['observation_interval'], 'cleanup': self.cleanup_result,
                 'references': [command['output'], *item.get('references', [])]}
            path = self.portable/'receipts'/(item['id']+'.json')
            write_new(path, r)
            refs.append({**reference(self.portable,path), 'id': item['id']})
        m['proofs'] = refs
        if hasattr(self,'prerequisites'):
            m['prerequisites']=self.prerequisites
        write_new(self.portable/'manifest.json', m)
        self.attempt('remote_evidence_pending', local_qualification='complete', proofs=[r['id'] for r in refs], cleanup=self.cleanup_result)
        print('local qualification complete; readiness remains not_ready until remote closure')
        return 0

    def run(self):
        self.reserve()
        handlers = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
        def interrupt(_sig, _frame):
            raise NotReady('qualification_interrupted')
        for sig in handlers:
            signal.signal(sig, interrupt)
        try:
            return self.run_reserved()
        finally:
            for sig, handler in handlers.items():
                signal.signal(sig, handler)

    def run_reserved(self):
        reason = None
        try:
            require(self.remote_main() == self.subject, 'main_changed')
            self.checkout()
            self.prepare()
            self.upstream()
            self.start_services()
            for proof_id, argv in self.gates():
                print('QUALIFY ' + proof_id, flush=True)
                self.current_proof = proof_id
                self.gate(proof_id, argv)
            require(self.remote_main() == self.subject, 'main_changed')
        except Exception as exc:
            reason = str(exc) if isinstance(exc, NotReady) else 'qualification_unavailable'
        finally:
            # Collection expiry never consumes the separate bounded disposal budget.
            self.deadline=time.monotonic()+240
            try:
                self.cleanup_result = self.cleanup()
            except Exception:
                reason = 'cleanup_failed'
                self.cleanup_result = {'state': 'failed', 'errors': ['cleanup_failed'], 'inventories': []}
        if reason:
            self.attempt(reason, cleanup=self.cleanup_result, proofs=[r['id'] for r in self.receipts], failed_proof=getattr(self,'current_proof',None))
            print('not_ready: ' + reason, file=sys.stderr)
            return 1
        try:
            self.deadline=time.monotonic()+45
            require(self.remote_main() == self.subject, 'main_changed')
            return self.finalize()
        except (NotReady, OSError, ValueError, KeyError, TypeError) as exc:
            reason = str(exc) if isinstance(exc, NotReady) else 'qualification_finalize_failed'
            self.attempt(reason, cleanup=self.cleanup_result)
            return 1


def cleanup_existing(root, output):
    output=Path(output).resolve()
    attempt=read_json(output/'attempt.json')
    require(attempt.get('schema_version')==1 and re.fullmatch(r'[0-9a-f]{32}',attempt.get('run_id','')),
            'cleanup_attempt_identity')
    q=Qualification(root,output,attempt['repository'],attempt['subject_sha'],deadline_seconds=240)
    q.run_id=attempt['run_id']
    q.private,q.portable=output/'restricted',output/'portable'
    require(q.private.is_dir() and not q.private.is_symlink() and q.portable.is_dir() and not q.portable.is_symlink(), 'cleanup_evidence_path')
    q.sequence=max((int(p.stem.split('-')[1]) for p in q.private.glob('command-*.txt')),default=0)
    q.workspace=Path(attempt['workspace']) if attempt.get('workspace') else None
    descriptor=q.private/'services.json'
    if descriptor.exists():
        d=read_json(descriptor)
        require(set(d)=={'schema_version','project','run_id','subject_sha','repository','compose_sha256'} and
                d['schema_version']==1 and d['project']=='rindle-readiness-'+q.run_id and
                all(d[key]==attempt[key] for key in ('run_id','subject_sha','repository')), 'cleanup_descriptor_identity')
        q.services=OwnedServices(q)
        q.services.compose_sha=d['compose_sha256']
        require(digest(q.services.file.read_bytes())==d['compose_sha256'], 'service_descriptor_changed')
        config=read_json(q.services.file)
        q.services.password=config['services']['postgres']['environment']['POSTGRES_PASSWORD']
        q.env['PGPASSWORD']=q.services.password
        q.cache_before=b'cleanup retry; original cache remains historical'
    matrix=q.private/'matrix'
    q.matrix=matrix if (matrix/'resources.json').exists() else None
    temporary=q.private/'temporary'
    q.temporary=temporary if temporary.exists() else None
    try:
        observed=q.cleanup()
    except Exception:
        write_new(output/('cleanup-'+secrets.token_hex(8)+'.json'),{'state':'failed','reason':'cleanup_failed','run_id':q.run_id})
        raise NotReady('cleanup_failed')
    write_new(output/('cleanup-'+secrets.token_hex(8)+'.json'),{**observed,'run_id':q.run_id,'requirements_credit':False})
    print('owned cleanup observed; original readiness attempt remains unchanged')
    return 0


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    if argv and argv[0] in ('verify-subject','accept','claim-status'):
        from readiness_acceptance import main as acceptance_main
        return acceptance_main(argv)
    if argv and argv[0] in ('close','refresh'):
        from readiness_closure import main as closure_main
        return closure_main(argv)
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest='operation', required=True)
    subs.add_parser('close', help='collect a bounded candidate verdict')
    subs.add_parser('refresh', help='refresh an immutable same-subject manifest')
    qualify = subs.add_parser('qualify')
    qualify.add_argument('--repo', required=True)
    qualify.add_argument('--subject', required=True)
    qualify.add_argument('--output', type=Path, required=True)
    cleanup = subs.add_parser('cleanup')
    cleanup.add_argument('--output',type=Path,required=True)
    args = parser.parse_args(argv)
    try:
        if args.operation=='cleanup':
            return cleanup_existing(ROOT,args.output)
        return Qualification(ROOT, args.output, args.repo, args.subject).run()
    except (NotReady, OSError, ValueError) as exc:
        print('not_ready: ' + (str(exc) if isinstance(exc, NotReady) else 'qualification_unavailable'), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
