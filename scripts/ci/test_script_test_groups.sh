#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
export PYTHONDONTWRITEBYTECODE=1
python3 - "$root" <<'PY'
import importlib.util,pathlib,sys,tempfile,time,unittest
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
unittest.main(argv=['groups'],verbosity=1)
PY
echo 'PASS: both CI groups awaited; either failure and bounded disposal remain nonpassing'
