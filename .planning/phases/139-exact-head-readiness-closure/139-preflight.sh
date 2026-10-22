#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"
phase=.planning/phases/139-exact-head-readiness-closure
evidence_dir="${RINDLE_138_EVIDENCE_DIR:-/private/tmp/rindle-138-matrix-verified}"
test -f "$phase/139-CONTEXT.md" || { echo 'FAIL: wrong checkout or missing Phase 139'; exit 1; }
python3 - "$root" <<'PY'
import json, pathlib, re, shutil, subprocess, sys
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

report = phases / '138-lifecycle-failure-and-recovery-matrix/138-VERIFICATION.md'
fm = front(report)
digest = re.search(r'(?m)^covered_digest:\s*"?([^"\n]+)', fm)
files = re.search(r'(?ms)^covered_files:\s*\n((?:  - [^\n]+\n)+)',fm)
if not digest or not files: fail('Phase 138 covered fingerprint missing')
covered = [line.removeprefix('  - ').strip().strip('"') for line in files.group(1).splitlines()]
if not all(p.startswith('.planning/phases/138-') or (root/p).is_file() for p in covered):
    fail('Phase 138 covered path missing')
covered_committed = subprocess.run(['git','diff','--quiet','HEAD','--',*covered],cwd=root)
if covered_committed.returncode: fail('Phase 138 covered source differs from HEAD')
launchers = []
if shutil.which('gsd_run'): launchers.append(['gsd_run'])
launchers.extend(['node',str(p)] for base in (root,*root.parents)
                 if (p := base/'.codex/gsd-core/bin/gsd-tools.cjs').is_file())
algorithm = digest.group(1).split(':',1)[0]
actual = None
for launcher in launchers:
    identity = subprocess.run([*launcher,'runtime-identity','--raw'],cwd=root,text=True,capture_output=True)
    try: package = json.loads(identity.stdout)
    except ValueError: continue
    if identity.returncode or package.get('packageName') != '@opengsd/gsd-core': continue
    cmd = [*launcher,'query','verification.fingerprint',str(report.parent.relative_to(root)),*covered]
    fingerprint = subprocess.run(cmd,cwd=root,text=True,capture_output=True)
    if fingerprint.returncode: continue
    try: candidate = json.loads(fingerprint.stdout)['covered_digest']
    except (ValueError,KeyError): continue
    if candidate.startswith(algorithm+':'):
        actual = candidate
        break
if actual is None: fail(f'identity-proven GSD fingerprint tool for {algorithm} unavailable')
if actual != digest.group(1): fail('Phase 138 covered digest is stale')

defer = json.loads((phases/'136-measured-quality-and-ci-ratchets/136-SPEED-DEFERRAL.json').read_text())
if (defer.get('acceptance_status'),defer.get('acceptance_credit'),defer.get('follow_up')) != ('deferred_unfinished',False,'.planning/seeds/SEED-261021-918-required-ci-critical-path-and-proof-runtime.md'):
    fail('documented CI timing deferral changed')
if not (root/defer['follow_up']).is_file(): fail('CI timing follow-up missing')
context = (phases/'139-exact-head-readiness-closure/139-CONTEXT.md').read_text()
if 'deferred_unfinished' not in context or 'zero acceptance' not in context:
    fail('Phase 139 D-16 amendment missing')
print('PASS: committed Phase 133–138 chain, current Phase 138 digest, numeric speed deferred with no credit')
PY

test -f "$evidence_dir/inputs.json" || { echo 'FAIL: retained Phase 138 inputs absent'; exit 1; }
test -f "$evidence_dir/receipt.json" || { echo 'FAIL: retained Phase 138 receipt absent'; exit 1; }
python3 scripts/maintainer/built_package_twin.py verify \
  --inputs "$evidence_dir/inputs.json" \
  --receipt "$evidence_dir/receipt.json"
echo 'PASS: Phase 139 implementation prerequisites only; exact-current-main READY remains pending'
