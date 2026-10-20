"""Explicitly authorized v133 repeat; separate immutable campaign namespace."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tools/auto_tuning/benchmark_qualification'),str(ROOT/'tools/auto_tuning')]
from common import DEST,source_hashes,read_json,atomic_json,file_hash,engine_identity,git_identity,utc_now
import campaign
import benchmark_preflight

BASE=ROOT/'builds/eval_virtual_cursor/benchmark_v133_r2'
DOC=ROOT/'docs/validation/auto_tuning/benchmark_v133_r2'

def prepare():
    assert not (DOC/'run_plan.json').exists() and not BASE.exists()
    identity=git_identity();assert not identity['repository_dirty']
    original=ROOT/'docs/validation/auto_tuning/benchmark_v133'
    plan=read_json(original/'run_plan.json')
    plan.update(id=BASE.name,frozen_before_qualification_utc=utc_now(),
                user_authorization='se tiver tudo bem, vamos repetir a qualificação v1.3.3',
                admission_correction='benchmark_v133_headless_init;19 admission assertions passed; prior failed attempt preserved',
                prior_campaign='benchmark_v133_r1_NO_GO_UNCHANGED',
                previous_outcomes_are_not_new_passes=True)
    DOC.mkdir(parents=True,exist_ok=True)
    atomic_json(DOC/'run_plan.json',plan)
    for name in ['implementation_spec.md','measurement_contract.md']:
        shutil.copy2(original/name,DOC/name)
    paths=subprocess.check_output(['git','ls-files','docs/validation'],cwd=DEST,text=True).splitlines()
    hashes=source_hashes();assert hashes==source_hashes(DEST)
    protected={p:file_hash(DEST/p) for p in paths if (DEST/p).is_file()}
    previous=read_json(original/'baseline_manifest.json')
    raw={p.relative_to(ROOT).as_posix():file_hash(p) for name in ['requal_20261020_r1','projection_v132b_r1','projection_v132b_r2','benchmark_v133_r1','benchmark_v133_headless_init_r1','benchmark_v133_headless_init_r2'] for p in (ROOT/'builds/eval_virtual_cursor'/name).rglob('*') if p.is_file()}
    atomic_json(DOC/'baseline_manifest.json',{'utc':utc_now(),'baseline_commit':identity['repository_commit'],
                'original_physics_baseline':previous['baseline_commit'],'source_hashes':hashes,
                'historical_tracked_evidence':protected,'historical_raw_evidence':raw,
                'protected_external':previous['protected_external'],'engine':engine_identity(),
                'optimizer':'OFF','private_holdout_outcomes_accessed':False})
    print('Prospective repeat prepared;96 cap;34 regressions separate; no outcomes yet.')

def freeze():
    target=BASE/'source_identity.json';assert not target.exists()
    identity=git_identity();assert not identity['repository_dirty']
    hashes=source_hashes();assert hashes==source_hashes(DEST)
    assert hashes==read_json(DOC/'baseline_manifest.json')['source_hashes']
    atomic_json(target,{**identity,'source_hashes':hashes,'engine_identity':engine_identity(),
                'run_plan_sha256':file_hash(DOC/'run_plan.json'),
                'helper_hashes':{p.relative_to(ROOT).as_posix():file_hash(p) for p in (ROOT/'tools').glob('benchmark*.py')},
                'optimizer':'OFF','user_authorized_repeat':True})
    print('Repeat frozen',identity['repository_commit'])

def main(stage):
    campaign.BASE=BASE;campaign.DOC=DOC;benchmark_preflight.BASE=BASE
    if stage=='prepare':prepare()
    elif stage=='freeze':freeze()
    elif stage=='preflight':raise SystemExit(benchmark_preflight.main(BASE.name))
    else:raise SystemExit(campaign.run_stage(stage))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('stage',choices=['prepare','freeze','preflight','reference','domains'])
    main(p.parse_args().stage)
