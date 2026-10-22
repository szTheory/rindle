#!/usr/bin/env python3
"""Authoritative synthetic-only adoption parity; no independent pilot or release grant."""
import argparse
import copy
from pathlib import Path
import re

from exact_head_readiness import ROOT, NotReady, digest, read_json, require, write_new, canonical

INPUTS = ('.planning/REQUIREMENTS.md','.planning/PROJECT.md','mix.exs',
          '.release-please-manifest.json','release-please-config.json')
SYNTHETIC = {'class':'maintainer_operated_synthetic','independent_pilot_credit':False,
             'pilot_01':'open','pilot_02':'open','one_point_zero_authority':False}


def pre_major(version):
    return isinstance(version,str) and re.fullmatch(r'0\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.-]+)?',version)


def positive_independent_claim(text):
    for clause in re.split(r'(?<=[.!?;])\s+|\n',text):
        for match in re.finditer(r'(?i)\b(?:independent|non[- ]maintainer|real)[- ]+(?:Phoenix[- ]+)?(?:adopter|pilot|adoption)\b(?P<between>.{0,90}?)\b(?:complete[ds]?|verified|satisfied|achieved|closed|passed)\b',clause):
            prefix=clause[max(0,match.start()-50):match.start()]+match['between']
            if not re.search(r'(?i)\b(?:no|not|cannot|never|without|unless|requires|once|after)\b',prefix):return True
        if re.search(r'(?i)\bPILOT-0[12]\b.{0,50}\b(?:complete[ds]?|verified|satisfied|achieved|closed|passed)\b',clause) and not re.search(r'(?i)\b(?:not|cannot|never|unless|after)\b',clause):return True
    return False


def check(root=ROOT,classification=None):
    root=Path(root).resolve();classification=copy.deepcopy(SYNTHETIC if classification is None else classification)
    require(isinstance(classification,dict) and classification==SYNTHETIC,'adoption_inflation')
    snapshots={}
    for relative in INPUTS:
        path=root/relative
        require(path.is_file() and not path.is_symlink() and path.stat().st_size<=2_000_000,'adoption_authority_unavailable')
        snapshots[relative]=path.read_bytes()
    requirements=snapshots[INPUTS[0]].decode();project=snapshots[INPUTS[1]].decode()
    for id in ('PILOT-01','PILOT-02'):
        lines=[line for line in requirements.splitlines() if re.match(r'^- (?:\[[ xX]\] )?\*\*'+id+r'\*\*:',line)]
        require(len(lines)==1 and not re.search(r'\[[xX]\]',lines[0]),'adoption_inflation')
        require(not re.search(r'(?im)^.*\[[xX]\].*'+id,requirements),'adoption_inflation')
    require('does not satisfy the named independent Phoenix pilot gate' in project and
            'synthetic twin cannot satisfy it' in project,'adoption_boundary_missing')
    require(not positive_independent_claim(requirements) and not positive_independent_claim(project),'adoption_inflation')
    version=re.search(r'@version\s+"([^"]+)"',snapshots['mix.exs'].decode())
    release=read_json(root/'.release-please-manifest.json')
    require(version and pre_major(version[1]) and release.get('.')==version[1],'one_point_zero_authority')
    config=read_json(root/'release-please-config.json')
    def intents(value):
        if isinstance(value,dict):
            for key,item in value.items():
                if key=='release-as':yield item
                yield from intents(item)
        elif isinstance(value,list):
            for item in value:yield from intents(item)
    require(all(pre_major(v) for v in intents(config)),'one_point_zero_authority')
    require(all((root/p).read_bytes()==raw for p,raw in snapshots.items()),'adoption_authority_changed')
    return {'adoption':classification,'authoritative_inputs':{p:digest(raw) for p,raw in snapshots.items()},
            'adoption_policy':'rindle-synthetic-adoption-v1'}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',default=str(ROOT));parser.add_argument('--output')
    args=parser.parse_args()
    try:
        value={'verdict':'synthetic_parity','requirements_credit':False,**check(args.root)}
        if args.output:write_new(args.output,value)
        print(canonical(value).decode());return 0
    except (NotReady,OSError,ValueError,UnicodeError) as exc:
        print('not_ready: '+(str(exc) if isinstance(exc,NotReady) else 'adoption_authority_unavailable'));return 1

if __name__=='__main__':raise SystemExit(main())
