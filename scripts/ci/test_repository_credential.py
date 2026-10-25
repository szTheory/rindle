#!/usr/bin/env python3
"""Offline admission checks; fake gh never reaches GitHub or uses real secrets."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / 'scripts/maintainer/repository_credential.py'


class CredentialTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        fake = self.root / 'gh'
        fake.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['CALLS'], 'a') as f: f.write(json.dumps(sys.argv[1:])+'\\n')
if os.environ.get('FAIL') == 'yes':
 print(os.environ['GH_TOKEN'], file=sys.stderr);sys.exit(1)
print(os.environ['RESPONSE'])
''')
        fake.chmod(0o700)
        self.calls = self.root / 'calls'
        self.env = {**os.environ, 'PATH': str(self.root)+os.pathsep+os.environ['PATH'],
                    'CALLS': str(self.calls), 'GH_TOKEN': 'opaque-test-secret',
                    'RESPONSE': json.dumps({'id': 99, 'full_name': 'owner/repo'})}
        for name in ('APP_CLIENT_ID','APP_PRIVATE_KEY','OTHER_APP_CLIENT_ID','LEGACY_TOKEN','JOB_TOKEN'):
            self.env.pop(name, None)

    def run_helper(self, *args, ok=True, **env):
        result = subprocess.run(['python3', str(HELPER), *args], env={**self.env, **env},
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0 if ok else 1, result.stdout+result.stderr)
        self.assertNotIn('opaque-test-secret', result.stdout+result.stderr)
        return result

    def select(self, profile='release', **env):
        output = self.root / 'outputs'
        result = self.run_helper('select', '--profile', profile, GITHUB_OUTPUT=str(output), **env)
        return output.read_text(), result

    def validate(self, source='app', ok=True, **env):
        return self.run_helper('validate', '--source', source, '--repo', 'owner/repo',
                               '--repository-id', '99', '--installation-id', '17', ok=ok, **env)

    def test_app_selected_ahead_of_all_fallbacks(self):
        output, _ = self.select(APP_CLIENT_ID='Iv123', APP_PRIVATE_KEY='private',
                                LEGACY_TOKEN='opaque-test-secret', JOB_TOKEN='job')
        self.assertIn('source=app', output)
        self.assertNotIn('opaque-test-secret', output)
        self.assertNotIn('token<<', output)

    def test_partial_app_configuration_never_falls_back(self):
        for env in ({'APP_CLIENT_ID':'Iv123'}, {'APP_PRIVATE_KEY':'private'}, {'APP_CLIENT_ID':'bad\nvalue','APP_PRIVATE_KEY':'private'}):
            with self.subTest(env=list(env)):
                self.run_helper('select','--profile','release',ok=False,LEGACY_TOKEN='opaque-test-secret',**env)

    def test_legacy_and_job_rollout(self):
        output, _ = self.select(LEGACY_TOKEN='opaque-test-secret', JOB_TOKEN='job')
        self.assertIn('source=legacy',output)
        output, _ = self.select(JOB_TOKEN='job')
        self.assertIn('source=job',output)

    def test_protection_never_uses_job_token(self):
        output, _ = self.select(profile='protection',JOB_TOKEN='job')
        self.assertIn('source=none',output)
        self.assertIn('enabled=false',output)

    def test_release_and_protection_cannot_share_app(self):
        self.run_helper('select','--profile','release',ok=False,
                        APP_CLIENT_ID='Iv123',APP_PRIVATE_KEY='key',OTHER_APP_CLIENT_ID='Iv123',LEGACY_TOKEN='opaque-test-secret')

    def test_release_missing_credentials_and_unknown_profile_fail(self):
        self.run_helper('select','--profile','release',ok=False)
        self.run_helper('select','--profile','arbitrary',ok=False,JOB_TOKEN='job')

    def test_app_admits_only_exact_scoped_repository(self):
        self.validate(RESPONSE=json.dumps([{'total_count':1,'repositories':[{'id':99,'full_name':'owner/repo'}]}]))
        calls=[json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertEqual(len(calls),1)
        self.assertIn('--paginate',calls[0]);self.assertIn('--slurp',calls[0])
        self.assertEqual(calls[0][-1],'installation/repositories?per_page=100')

    def test_wrong_foreign_partial_duplicate_and_overbroad_installation_fail(self):
        row={'id':99,'full_name':'owner/repo'}
        bad=[[],[{'total_count':0,'repositories':[]}],
             [{'total_count':1,'repositories':[{'id':98,'full_name':'owner/repo'}]}],
             [{'total_count':1,'repositories':[{'id':99,'full_name':'other/repo'}]}],
             [{'total_count':2,'repositories':[row]}],
             [{'total_count':2,'repositories':[row,{'id':98,'full_name':'owner/other'}]}],
             [{'total_count':1,'repositories':[row]},{'total_count':1,'repositories':[row]}]]
        for response in bad:
            with self.subTest(response=response):self.validate(ok=False,RESPONSE=json.dumps(response))

    def test_revoked_expired_forbidden_token_fails_without_fallback_or_leak(self):
        for source in ('app','legacy','job'):
            with self.subTest(source=source):self.validate(source,ok=False,FAIL='yes',LEGACY_TOKEN='another-token')

    def test_malformed_and_duplicate_response_keys_fail(self):
        for response in ('not json','{"id":99,"id":98}', 'null'):
            with self.subTest(response=response):self.validate(ok=False,RESPONSE=response)

    def test_app_requires_minted_installation_identity(self):
        self.run_helper('validate','--source','app','--repo','owner/repo',
                        '--repository-id','99','--installation-id','',ok=False)
        self.assertFalse(self.calls.exists())

    def test_legacy_authenticates_user_then_exact_repository(self):
        self.validate('legacy')
        calls=[json.loads(line)[-1] for line in self.calls.read_text().splitlines()]
        self.assertEqual(calls,['user','repos/owner/repo'])

    def test_job_token_checks_repository_without_user_endpoint(self):
        self.validate('job')
        self.assertEqual([json.loads(line)[-1] for line in self.calls.read_text().splitlines()],['repos/owner/repo'])

    def test_no_token_and_missing_identity_fail_before_network(self):
        self.validate(ok=False,GH_TOKEN='')
        self.run_helper('validate','--source','app','--repo','owner/repo',
                        '--repository-id','99','--installation-id','not-an-id',ok=False)
        self.assertFalse(self.calls.exists())


if __name__ == '__main__':
    unittest.main()
