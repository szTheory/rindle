#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"
phase=.planning/phases/139-exact-head-readiness-closure
test -f "$phase/139-CONTEXT.md" || { echo 'FAIL: wrong checkout or missing Phase 139'; exit 1; }
python3 - "$root" <<'PY'
import hashlib, json, pathlib, re, subprocess, sys
root = pathlib.Path(sys.argv[1])
phases = root / '.planning/phases'
def fail(reason):
    raise SystemExit('FAIL: ' + reason)
def front(path):
    text = path.read_text()
    match = re.match(r'\A---\n(.*?)\n---\n', text, re.S)
    if not match: fail(f'{path.name}: no frontmatter')
    return match.group(1)
for n, slug, count in [(133,'evidence-charter-and-live-truth',178),(134,'dependency-security-and-inbox-disposition',6),(135,'repository-and-code-craft-consolidation',14),(136,'measured-quality-and-ci-ratchets',15),(137,'built-package-twin-foundation',6),(138,'lifecycle-failure-and-recovery-matrix',6)]:
    d = phases / f'{n}-{slug}'
    report = d / f'{n}-VERIFICATION.md'
    if not report.is_file() or not re.search(r'(?m)^status:\s*passed\s*$', front(report)):
        fail(f'Phase {n} lacks passed verification')
    summaries = sorted(d.glob(f'{n}-*-SUMMARY.md'))
    if (len(summaries) < count if n == 133 else len(summaries) != count):
        fail(f'Phase {n} summary count {len(summaries)} does not cover {count}')
    tracked = subprocess.run(['git','ls-files','--error-unmatch',str(report.relative_to(root)),*[str(p.relative_to(root)) for p in summaries]],cwd=root,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    if tracked.returncode: fail(f'Phase {n} verification or summary is uncommitted')
    committed = subprocess.run(['git','diff','--quiet','HEAD','--',str(report.relative_to(root)),*[str(p.relative_to(root)) for p in summaries]],cwd=root)
    if committed.returncode: fail(f'Phase {n} verification or summary differs from HEAD')

# The old covered fingerprint is historical, including RUNNING.md before Phase 139.
# Do not compare today's intentionally changed docs to that old claim or require
# an agent-local CLI/private temp receipt. Current behavior is requalified by all
# eighteen local gates and the six-case matrix in exact_head_readiness.py.
report = phases / '138-lifecycle-failure-and-recovery-matrix/138-VERIFICATION.md'
if 'v3:sha256:53f6a249e6e423c86c05791070b96c3ad6d751908d958d6e753c2e3ab4d9abc7' not in report.read_text():
    fail('historical Phase 138 fingerprint changed')
for relative, expected in {
    '136-measured-quality-and-ci-ratchets/136-SPEED-DEFERRAL.json': 'c15572c572a8ca2e7dbdb564b6a50516f1822b6117c2d2430bad1c0f973b9af3',
    '136-measured-quality-and-ci-ratchets/136-QUALIFICATION-CLOSEOUT.json': 'aba8565ebfb97fd366efd94c691a977b3c29c78e232e2dda7cb338d69997abce'
}.items():
    if hashlib.sha256((phases/relative).read_bytes()).hexdigest() != expected:
        fail('original timing debt bytes changed')

defer = json.loads((phases/'136-measured-quality-and-ci-ratchets/136-SPEED-DEFERRAL.json').read_text())
if (defer.get('acceptance_status'),defer.get('acceptance_credit'),defer.get('follow_up')) != ('deferred_unfinished',False,'.planning/seeds/SEED-261021-918-required-ci-critical-path-and-proof-runtime.md'):
    fail('documented CI timing deferral changed')
if not (root/defer['follow_up']).is_file(): fail('CI timing follow-up missing')
context = (phases/'139-exact-head-readiness-closure/139-CONTEXT.md').read_text()
if 'deferred_unfinished' not in context or 'zero acceptance' not in context:
    fail('Phase 139 D-16 amendment missing')
print('PASS: committed historical Phase 133–138 delivery chain; fresh current qualification required; speed deferred with no credit')
PY
echo 'PASS: Phase 139 implementation prerequisites only; exact-current-main READY remains pending'
