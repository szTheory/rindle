import json
from pathlib import Path
import tempfile
import unittest

from check_gsd_handoff import inspect


class HandoffTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.planning = self.root / '.planning'
        (self.planning / 'async-jobs').mkdir(parents=True)
        (self.planning / 'phases/136-example').mkdir(parents=True)
        (self.planning / 'STATE.md').write_text('---\ncurrent_phase: 136\ncurrent_plan: 07\n---\n')

    def job(self, status='running', name='job'):
        job = {'phase': '136', 'plan_id': '136-07', 'status': status,
               'resume_command': '$gsd-execute-phase 136'}
        (self.planning / f'async-jobs/{name}.json').write_text(json.dumps(job))

    def missing(self, phase):
        self.assertEqual(phase, '136')
        return {'status': 'missing', 'next_command': '$gsd-execute-phase 136'}

    def test_running_job_is_polled_without_dispatch_or_verification(self):
        self.job()
        result = inspect(self.root, lambda _: self.fail('Running job must retain ownership'))
        self.assertEqual(result['next_command'], '$gsd-progress')
        self.assertEqual(result['after_job_command'], '$gsd-execute-phase 136')

    def test_completed_job_resumes_verification_instead_of_next_phase(self):
        self.job('completed-unverified')
        result = inspect(self.root, self.missing)
        self.assertEqual(result['next_command'], '$gsd-execute-phase 136')
        self.assertEqual(result['status'], 'completed-unverified')

    def test_stale_handoff_cannot_rewind_to_phase133(self):
        (self.planning / 'HANDOFF.json').write_text('{"phase":"133"}')
        with self.assertRaisesRegex(ValueError, 'disagrees with STATE'):
            inspect(self.root, self.missing)

    def test_duplicate_plan_owners_are_rejected(self):
        self.job(name='first')
        self.job(name='second')
        with self.assertRaisesRegex(ValueError, 'same plan'):
            inspect(self.root, self.missing)

    def test_missing_verification_keeps_execute_phase_route(self):
        self.assertEqual(inspect(self.root, self.missing)['next_command'], '$gsd-execute-phase 136')

    def test_failed_job_is_reconciled_without_resubmitting(self):
        self.job('failed')
        result = inspect(self.root, self.missing)
        self.assertEqual(result['status'], 'failed')
        self.assertEqual(result['next_command'], '$gsd-execute-phase 136')

    def test_summary_releases_job_to_gsd_verification_owner(self):
        self.job('completed-unverified')
        (self.planning / 'phases/136-example/136-07-SUMMARY.md').write_text('Summary')
        result = inspect(self.root, lambda _: {'status': 'passed'})
        self.assertEqual(result['status'], 'passed')
        self.assertEqual(result['next_command'], '$gsd-progress')

    def test_foreign_manifest_command_is_rejected(self):
        self.job()
        f = self.planning / 'async-jobs/job.json'
        job = json.loads(f.read_text())
        job['resume_command'] = '$gsd-execute-phase 133'
        f.write_text(json.dumps(job))
        with self.assertRaisesRegex(ValueError, 'command disagrees'):
            inspect(self.root, self.missing)

    def test_stale_plan_header_cannot_hide_running_job(self):
        self.job()
        (self.planning / 'STATE.md').write_text('---\ncurrent_phase: 136\ncurrent_plan: 15\n---\n')
        with self.assertRaisesRegex(ValueError, 'current_plan disagrees'):
            inspect(self.root, self.missing)

    def test_unstarted_phase_without_context_hands_off_directly_to_discussion(self):
        result = inspect(self.root, lambda _: {'status': 'not_started', 'next_command': '$gsd-progress'})
        self.assertEqual(result['next_command'], '$gsd-discuss-phase 136')

    def test_roadmap_only_phase_hands_off_directly_to_discussion(self):
        (self.planning / 'phases/136-example').rmdir()
        result = inspect(self.root, lambda _: {'status': 'not_started'})
        self.assertEqual(result['next_command'], '$gsd-discuss-phase 136')

    def test_unplanned_phase_with_context_hands_off_directly_to_planning(self):
        (self.planning / 'phases/136-example/136-CONTEXT.md').write_text('Decisions')
        result = inspect(self.root, lambda _: {'status': 'not_started'})
        self.assertEqual(result['next_command'], '$gsd-plan-phase 136')


if __name__ == '__main__':
    unittest.main()
