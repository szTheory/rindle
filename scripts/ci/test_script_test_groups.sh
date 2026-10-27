#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
export PYTHONDONTWRITEBYTECODE=1
python3 - "$root" <<'PY'
import importlib.util,json,pathlib,sys,tempfile,time,unittest
root=pathlib.Path(sys.argv[1]);spec=importlib.util.spec_from_file_location('ci_groups',root/'scripts/ci/run_script_test_groups.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
class Groups(unittest.TestCase):
    def run_groups(self,first,second,budget=5):
        with tempfile.TemporaryDirectory(prefix='rindle-script-groups-test-') as tmp:
            path=pathlib.Path(tmp);groups=[]
            for n,(delay,code) in enumerate((first,second)):
                marker=path/str(n)
                program='import pathlib,time;time.sleep('+repr(delay)+');pathlib.Path('+repr(str(marker))+').write_text("finished");raise SystemExit('+repr(code)+')'
                groups.append((str(n),[sys.executable,'-c',program]))
            result=g.run(groups,path/'logs',budget)
            return result,[(path/str(n)).exists() for n in (0,1)]
    def test_both_successful_groups_finish(self):self.assertEqual(self.run_groups((.1,0),(.1,0)),(0,[True,True]))
    def test_early_failure_still_awaits_other_group(self):self.assertEqual(self.run_groups((.01,7),(.2,0)),(1,[True,True]))
    def test_second_group_failure_cannot_be_masked(self):self.assertEqual(self.run_groups((.1,0),(.01,3)),(1,[True,True]))
    def test_timeout_is_nonpassing_and_disposes_both_groups(self):self.assertEqual(self.run_groups((5,0),(5,0),.1),(1,[False,False]))
    def test_timeout_retains_completed_and_terminated_group_diagnostics(self):
        with tempfile.TemporaryDirectory(prefix='rindle-script-groups-test-') as tmp:
            path=pathlib.Path(tmp)
            groups=[('finished',[sys.executable,'-c','pass']),('slow',[sys.executable,'-c','import time;time.sleep(5)'])]
            self.assertEqual(g.run(groups,path/'logs',1),1)
            rows=json.loads((path/'logs/results.json').read_text())['groups']
            self.assertEqual((rows[0]['name'],rows[0]['state'],rows[0]['exit_code']),('finished','completed',0))
            self.assertEqual((rows[1]['name'],rows[1]['state']),('slow','terminated'))
            self.assertNotEqual(rows[1]['exit_code'],0)
            self.assertLess(rows[0]['elapsed_seconds'],rows[1]['elapsed_seconds'])
            self.assertEqual(rows[2]['reason'],'CI harness group budget exhausted')
    def test_three_groups_awaited_with_failure_preserved(self):
        with tempfile.TemporaryDirectory(prefix='rindle-script-groups-test-') as tmp:
            path=pathlib.Path(tmp);marker=path/'last'
            groups=[('first',[sys.executable,'-c','raise SystemExit(7)']),('second',[sys.executable,'-c','pass']),('last',[sys.executable,'-c','import pathlib,time;time.sleep(.2);pathlib.Path('+repr(str(marker))+').touch()'])]
            self.assertEqual(g.run(groups,path/'logs'),1);self.assertTrue(marker.exists())
    def test_workflow_split_preserves_every_command_once(self):
        independent=['bash scripts/ci/test_nightly_incident.sh','python3 scripts/ci/test_land_release_train_baseline.py',
                     'bash scripts/ci/test_collect_inbox.sh',
                     'bash scripts/ci/test_validate_inbox_ledger.sh','bash scripts/ci/test_dep_landing_evidence.sh']
        commands=['bash a.sh',*independent,'bash b.sh']
        groups=g.workflow_groups('\n'.join(commands))
        self.assertEqual(len(groups),3)
        self.assertEqual(groups[0][1][-1],'bash a.sh\npython3 scripts/ci/test_land_release_train_baseline.py\nbash scripts/ci/test_collect_inbox.sh\nbash b.sh')
        self.assertEqual(groups[1][1],['bash','-euo','pipefail','-c','\n'.join(line for line in independent if 'test_collect_inbox.sh' not in line and 'test_land_release_train_baseline.py' not in line and 'test_dep_landing_evidence.sh' not in line)])
        self.assertEqual(groups[2][1],['bash','-euo','pipefail','-c','bash scripts/ci/test_readiness_fixtures.sh\nbash scripts/ci/test_dep_landing_evidence.sh'])
        for command in independent:
            for broken in ([line for line in commands if line!=command],commands+[command]):
                with self.assertRaises(ValueError):g.workflow_groups('\n'.join(broken))
    def test_actual_workflow_retains_every_declared_harness_once(self):
        yaml=(root/'.github/workflows/ci.yml').read_text()
        body=yaml.split("python3 scripts/ci/run_script_test_groups.py <<'HARNESSES'\n",1)[1].split('\n          HARNESSES',1)[0]
        declared=[line.strip() for line in body.splitlines()]
        groups=g.workflow_groups('\n'.join(declared))
        self.assertEqual(groups[2][1][:4],['bash','-euo','pipefail','-c'])
        self.assertEqual(groups[2][1][-1].splitlines()[0],'bash scripts/ci/test_readiness_fixtures.sh')
        observed=groups[0][1][-1].splitlines()+groups[1][1][-1].splitlines()+groups[2][1][-1].splitlines()[1:]
        self.assertCountEqual(observed,declared)
        self.assertEqual(len(observed),len(set(observed)))
unittest.main(argv=['groups'],verbosity=1)
PY
echo 'PASS: all CI groups awaited; every command retained, failure and bounded disposal remain nonpassing'
