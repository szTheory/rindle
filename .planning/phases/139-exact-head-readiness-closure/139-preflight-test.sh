#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
preflight="$root/.planning/phases/139-exact-head-readiness-closure/139-preflight.sh"
export PYTHONDONTWRITEBYTECODE=1
python3 - "$root" "$preflight" <<'PY'
import os,pathlib,shutil,subprocess,sys,tempfile
root=pathlib.Path(sys.argv[1]);preflight=sys.argv[2]
with tempfile.TemporaryDirectory(prefix='rindle139-portable-preflight-') as temporary:
    out=pathlib.Path(temporary);checkout=out/'checkout';phases=checkout/'.planning/phases'
    for directory in (root/'.planning/phases').iterdir():
        if not directory.name[:3] in ('133','134','135','136','137','138'):continue
        dest=phases/directory.name;dest.mkdir(parents=True)
        for path in directory.iterdir():
            if path.name.endswith(('-SUMMARY.md','-VERIFICATION.md')) or path.name in ('136-SPEED-DEFERRAL.json','136-QUALIFICATION-CLOSEOUT.json'):
                shutil.copyfile(path,dest/path.name)
    context='.planning/phases/139-exact-head-readiness-closure/139-CONTEXT.md'
    seed='.planning/seeds/SEED-261021-918-required-ci-critical-path-and-proof-runtime.md'
    for relative in (context,seed):
        path=checkout/relative;path.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(root/relative,path)
    bin=out/'bin';bin.mkdir();git=bin/'git';real=shutil.which('git')
    git.write_text('#!/bin/sh\ncase "$1" in\nrev-parse) echo "$RINDLE_PREFLIGHT_ROOT";;\nls-files) exit "${RINDLE_PREFLIGHT_UNTRACKED:-0}";;\ndiff) exit "${RINDLE_PREFLIGHT_DIRTY:-0}";;\n*) exec "$RINDLE_PREFLIGHT_REAL_GIT" "$@";;\nesac\n');git.chmod(0o700)
    env={**os.environ,'PATH':str(bin)+os.pathsep+os.environ['PATH'],'RINDLE_PREFLIGHT_ROOT':str(checkout),'RINDLE_PREFLIGHT_REAL_GIT':real,'RINDLE_138_EVIDENCE_DIR':str(out/'absent-private-matrix')}
    def run(reason=None,**changes):
        result=subprocess.run(['bash',preflight],cwd=root,env={**env,**changes},capture_output=True,text=True,timeout=30)
        assert (result.returncode==0)==(reason is None),(reason,result.stdout,result.stderr)
        if reason:assert reason in result.stdout+result.stderr,(reason,result.stdout,result.stderr)
    run() # no private matrix, no GSD CLI dependency
    run('uncommitted',RINDLE_PREFLIGHT_UNTRACKED='1')
    run('differs from HEAD',RINDLE_PREFLIGHT_DIRTY='1')
    report=phases/'138-lifecycle-failure-and-recovery-matrix/138-VERIFICATION.md';raw=report.read_bytes();report.unlink();run('lacks passed verification');report.write_bytes(raw)
    report.write_bytes(raw.replace(b'53f6a249e6e423c86c05791070b96c3ad6d751908d958d6e753c2e3ab4d9abc7',b'0'*64));run('historical Phase 138 fingerprint changed');report.write_bytes(raw)
    debt=phases/'136-measured-quality-and-ci-ratchets/136-SPEED-DEFERRAL.json';raw=debt.read_bytes();debt.write_bytes(raw+b' ');run('original timing debt bytes changed');debt.write_bytes(raw)
    closeout=phases/'136-measured-quality-and-ci-ratchets/136-QUALIFICATION-CLOSEOUT.json';raw=closeout.read_bytes();closeout.write_bytes(raw+b' ');run('original timing debt bytes changed');closeout.write_bytes(raw)
bash=subprocess.run(['bash',preflight],cwd=root,check=True)
print('PASS: portable historical-delivery preflight; absent/uncommitted reports, changed fingerprint and timing debt reject; current qualification still required')
PY
