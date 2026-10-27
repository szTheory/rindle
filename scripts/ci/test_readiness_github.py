#!/usr/bin/env python3
"""Exercise the public GET transport and its retained evidence without network."""
import base64
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'maintainer'))
from readiness_github import GitHub
from exact_head_readiness import NotReady


class GitHubEvidenceTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='rindle-github-get-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.fixture = self.root / 'fixture'
        self.fixture.mkdir()
        self.evidence = self.root / 'evidence'
        self.path = 'repos/example/repo/actions/runs/42/jobs?per_page=100'

    def client(self, responses, **options):
        (self.fixture / 'responses.json').write_text(json.dumps({self.path: responses}))
        return GitHub('example/repo', self.evidence, self.fixture, **options)

    def retained(self):
        return [json.loads(p.read_text()) for p in sorted(self.evidence.glob('*-request.json'))]

    def file_body(self, raw=b'expected'):
        return {'type':'file','path':'code.py','encoding':'base64','size':len(raw),
                'sha':hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest(),
                'content':base64.b64encode(raw).decode()}

    def file_client(self, responses, **options):
        self.path='repos/example/repo/contents/code.py?ref='+'a'*40
        return self.client(responses,**options)

    def test_incomplete_file_reacquires_same_ref_and_retains_both_responses(self):
        good=self.file_body();bad={**good,'size':good['size']+1}
        client=self.file_client([{'status':200,'body':bad},{'status':200,'body':good}])
        with patch('readiness_github.time.sleep') as sleep:
            self.assertEqual(client.contents('code.py','a'*40),b'expected')
        sleep.assert_called_once_with(1)
        self.assertEqual([r['path'] for r in self.retained()],[self.path,self.path])
        self.assertEqual(json.loads((self.evidence/'0001-response').read_text()),bad)
        self.assertEqual(json.loads((self.evidence/'0002-response').read_text()),good)

    def test_equal_size_wrong_blob_cannot_pass_and_can_recover(self):
        good=self.file_body();bad={**good,'content':base64.b64encode(b'changed!').decode()}
        self.assertEqual(len(base64.b64decode(bad['content'])),good['size'])
        client=self.file_client([{'status':200,'body':bad},{'status':200,'body':good}])
        with patch('readiness_github.time.sleep'):
            self.assertEqual(client.contents('code.py','a'*40),b'expected')
        self.assertEqual(len(self.retained()),2)

    def test_persistent_file_inconsistency_stops_after_three_complete_reads(self):
        good=self.file_body()
        for index,(bad,reason) in enumerate((
                ({**good,'size':good['size']+1},'subject_file_incomplete'),
                ({**good,'sha':'0'*40},'subject_file_digest_mismatch'))):
            with self.subTest(reason=reason):
                self.evidence=self.root/f'inconsistent-{index}'
                client=self.file_client([{'status':200,'body':bad}]*3+[{'status':200,'body':good}])
                with patch('readiness_github.time.sleep') as sleep:
                    with self.assertRaisesRegex(NotReady,reason):client.contents('code.py','a'*40)
                self.assertEqual(sleep.call_count,2)
                self.assertEqual([r['path'] for r in self.retained()],[self.path]*3)

    def test_file_recovery_keeps_global_call_and_deadline_budgets(self):
        bad={**self.file_body(),'size':9}
        client=self.file_client([{'status':200,'body':bad}],max_calls=1)
        with patch('readiness_github.time.sleep') as sleep:
            with self.assertRaisesRegex(NotReady,'remote_budget_exhausted'):client.contents('code.py','a'*40)
            sleep.assert_not_called()
        self.assertEqual(len(self.retained()),1)
        self.evidence=self.root/'short-deadline'
        with patch('readiness_github.time.monotonic',return_value=0):
            client=self.file_client([{'status':200,'body':bad}],budget=.5)
            with patch('readiness_github.time.sleep') as sleep:
                with self.assertRaisesRegex(NotReady,'remote_budget_exhausted'):client.contents('code.py','a'*40)
                sleep.assert_not_called()
        self.assertEqual(len(self.retained()),1)

    def test_file_recovery_respects_cooldown_and_exhausted_quota(self):
        bad={**self.file_body(),'size':9}
        for index,headers in enumerate(({'Retry-After':'120'},{'X-RateLimit-Remaining':'0'})):
            self.evidence=self.root/f'file-cooldown-{index}'
            client=self.file_client([{'status':200,'body':bad,'headers':headers}])
            with patch('readiness_github.time.sleep') as sleep:
                with self.assertRaisesRegex(NotReady,'subject_file_incomplete'):client.contents('code.py','a'*40)
                sleep.assert_not_called()
            self.assertEqual(len(self.retained()),1)

    def test_foreign_or_malformed_file_identity_never_retries(self):
        good=self.file_body();missing=dict(good);missing.pop('sha')
        cases=[{**good,'path':'other.py'},{**good,'type':'dir'},
               {**good,'encoding':'utf8'},{**good,'size':True},missing,{**good,'content':'!'}]
        for index,body in enumerate(cases):
            self.evidence=self.root/f'bad-file-{index}'
            client=self.file_client([{'status':200,'body':body}])
            with patch('readiness_github.time.sleep') as sleep:
                with self.assertRaisesRegex(NotReady,'subject_file_unavailable'):client.contents('code.py','a'*40)
                sleep.assert_not_called()
            self.assertEqual(len(self.retained()),1)

    def test_file_recovery_does_not_retry_missing_authorization(self):
        client=self.file_client([{'status':403,'body':{}}])
        with patch('readiness_github.time.sleep') as sleep:
            with self.assertRaisesRegex(NotReady,'remote_forbidden'):client.contents('code.py','a'*40)
            sleep.assert_not_called()
        self.assertEqual(len(self.retained()),1)

    def test_recovers_from_bad_gateway_and_retains_both_responses(self):
        client = self.client([
            {'status': 502, 'body': {'message': 'Bad Gateway'}},
            {'status': 200, 'body': {'jobs': [42]}, 'headers': {'x-source': 'authenticated'}},
        ])
        with patch('readiness_github.time.sleep'):
            value, headers = client.get(self.path)
        self.assertEqual(value, {'jobs': [42]})
        self.assertEqual(headers['x-source'], 'authenticated')
        self.assertEqual([r['status'] for r in self.retained()], [502, 200])
        self.assertEqual(json.loads((self.evidence / '0001-response').read_text()),
                         {'message': 'Bad Gateway'})

    def test_unavailable_and_gateway_timeout_share_the_bounded_recovery(self):
        client = self.client([
            {'status': 503, 'body': {}},
            {'status': 504, 'body': {}},
            {'status': 200, 'body': {'complete': True}},
        ])
        with patch('readiness_github.time.sleep'):
            value, _ = client.get(self.path)
        self.assertEqual(value, {'complete': True})
        self.assertEqual([r['status'] for r in self.retained()], [503, 504, 200])

    def test_deadline_prevents_backoff_and_another_request(self):
        with patch('readiness_github.time.monotonic', return_value=0):
            client = self.client([
                {'status': 502, 'body': {}}, {'status': 200, 'body': {}},
            ], budget=0.5)
            with patch('readiness_github.time.sleep') as sleep:
                with self.assertRaisesRegex(NotReady, 'remote_budget_exhausted'):
                    client.get(self.path)
                sleep.assert_not_called()
        self.assertEqual([r['status'] for r in self.retained()], [502])

    def test_server_cooldown_and_exhausted_quota_do_not_retry(self):
        for index, headers in enumerate(({'Retry-After': '120'}, {'X-RateLimit-Remaining': '0'})):
            with self.subTest(headers=headers):
                self.evidence = self.root / ('restricted-' + str(index))
                client = self.client([
                    {'status': 503, 'body': {}, 'headers': headers},
                    {'status': 200, 'body': {}},
                ])
                with patch('readiness_github.time.sleep') as sleep:
                    with self.assertRaisesRegex(NotReady, 'remote_unavailable'):
                        client.get(self.path)
                    sleep.assert_not_called()
                self.assertEqual([r['status'] for r in self.retained()], [503])

    def test_three_transient_responses_fail_with_all_bytes_retained(self):
        client = self.client([{'status': 502, 'body': {'unavailable': True}}])
        with patch('readiness_github.time.sleep'):
            with self.assertRaisesRegex(NotReady, 'remote_unavailable'):
                client.get(self.path)
        self.assertEqual([r['status'] for r in self.retained()], [502, 502, 502])
        self.assertEqual(len(list(self.evidence.glob('*-response'))), 3)

    def test_retry_cannot_exceed_the_physical_call_limit(self):
        client = self.client([
            {'status': 502, 'body': {}}, {'status': 200, 'body': {}},
        ], max_calls=1)
        with patch('readiness_github.time.sleep') as sleep:
            with self.assertRaisesRegex(NotReady, 'remote_budget_exhausted'):
                client.get(self.path)
            sleep.assert_not_called()
        self.assertEqual([r['status'] for r in self.retained()], [502])

    def test_successful_retry_still_consumes_the_shared_call_budget(self):
        client = self.client([
            {'status': 502, 'body': {}}, {'status': 200, 'body': {'ok': True}},
        ], max_calls=2)
        with patch('readiness_github.time.sleep'):
            self.assertEqual(client.get(self.path)[0], {'ok': True})
        with self.assertRaisesRegex(NotReady, 'remote_budget_exhausted'):
            client.get(self.path)
        self.assertEqual([r['status'] for r in self.retained()], [502, 200])

    def test_auth_visibility_rate_limits_and_other_statuses_never_retry(self):
        for status, headers, reason in (
            (401, {}, 'remote_unauthorized'), (403, {}, 'remote_forbidden'),
            (403, {'x-ratelimit-remaining': '0'}, 'remote_rate_limited'),
            (429, {}, 'remote_rate_limited'), (404, {}, 'remote_unavailable'),
            (304, {}, 'remote_unavailable'), (501, {}, 'remote_unavailable'),
        ):
            with self.subTest(status=status, headers=headers):
                self.evidence = self.root / ('status-' + str(len(list(self.root.iterdir()))))
                client = self.client([
                    {'status': status, 'headers': headers, 'body': {}},
                    {'status': 200, 'body': {}},
                ])
                with patch('readiness_github.time.sleep') as sleep:
                    with self.assertRaisesRegex(NotReady, reason):
                        client.get(self.path)
                    sleep.assert_not_called()
                self.assertEqual([r['status'] for r in self.retained()], [status])

    def test_malformed_success_does_not_retry_into_valid_evidence(self):
        client = self.client([
            {'status': 200, 'base64': base64.b64encode(b'{"key":1,"key":2}').decode()},
            {'status': 200, 'body': {'key': 1}},
        ])
        with patch('readiness_github.time.sleep') as sleep:
            with self.assertRaisesRegex(NotReady, 'duplicate_json_key'):
                client.get(self.path)
            sleep.assert_not_called()
        self.assertEqual([r['status'] for r in self.retained()], [200])

    def test_binary_recovery_preserves_exact_bytes(self):
        raw = b'\x00\x01\xff'
        client = self.client([
            {'status': 502, 'body': {}},
            {'status': 200, 'base64': base64.b64encode(raw).decode()},
        ])
        with patch('readiness_github.time.sleep'):
            self.assertEqual(client.get(self.path, binary=True, limit=1024)[0], raw)
        self.assertEqual((self.evidence / '0002-response').read_bytes(), raw)

    def test_response_limit_failure_never_retries(self):
        client = self.client([
            {'status': 502, 'base64': base64.b64encode(b'123').decode()},
            {'status': 200, 'body': {}},
        ])
        with patch('readiness_github.time.sleep') as sleep:
            with self.assertRaisesRegex(NotReady, 'remote_response_limit'):
                client.get(self.path, binary=True, limit=2)
            sleep.assert_not_called()
        self.assertEqual(self.retained(), [])

    def test_real_cli_transport_replays_only_get_and_retains_each_attempt(self):
        binary = self.root / 'bin'
        binary.mkdir()
        gh = binary / 'gh'
        gh.write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
if sys.argv[1:3] == ['auth','status']: raise SystemExit(0)
log=Path(os.environ['RINDLE_GET_TEST_ROOT'])/'requests.jsonl'
count=len(log.read_text().splitlines()) if log.exists() else 0
with log.open('a') as stream: stream.write(json.dumps(sys.argv[1:])+'\\n')
status=502 if count==0 else 200
sys.stdout.buffer.write(('HTTP/2 '+str(status)+'\\r\\nContent-Type: application/json\\r\\n\\r\\n').encode())
sys.stdout.buffer.write(b'{"ok":true}' if status==200 else b'{"message":"Bad Gateway"}')
raise SystemExit(0 if status==200 else 1)
''')
        gh.chmod(0o700)
        with patch.dict(os.environ, {'PATH': str(binary) + os.pathsep + os.environ['PATH'],
                                    'RINDLE_GET_TEST_ROOT': str(self.root)}):
            client = GitHub('example/repo', self.evidence)
            self.assertEqual(client.get(self.path)[0], {'ok': True})
        requests = [json.loads(line) for line in (self.root / 'requests.jsonl').read_text().splitlines()]
        self.assertEqual(len(requests), 2)
        for args in requests:
            self.assertEqual(args[args.index('--method') + 1], 'GET')
            self.assertEqual(args[-1], self.path)
        self.assertEqual([r['status'] for r in self.retained()], [502, 200])


if __name__ == '__main__':
    unittest.main()
