"""Freeze the reviewed implementation once; no gameplay process."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/auto_tuning'))
from common import DEST, atomic_json, read_json, source_hashes, engine_identity, file_hash, git_identity

BASE = ROOT / 'builds/eval_virtual_cursor/benchmark_v133_r1'
DOC = ROOT / 'docs/validation/auto_tuning/benchmark_v133'

def main():
    target = BASE / 'source_identity.json'
    assert not target.exists(), 'Immutable source freeze already exists'
    identity = git_identity()
    assert not identity['repository_dirty'], 'Commit reviewed source before freeze'
    hashes = source_hashes()
    assert hashes == source_hashes(DEST)
    previous = read_json(DOC / 'baseline_manifest.json')['source_hashes']
    allowed = {'features/evaluator_qualification/scripts/qualification_driver.gd',
               'features/evaluator_virtual_cursor/scripts/virtual_cursor_driver.gd',
               'features/evaluator_virtual_cursor/scripts/projection_probe.gd',
               'tools/auto_tuning/virtual_cursor/test_projection.py'}
    delta = {p: {'before': previous.get(p), 'after': hashes.get(p)}
             for p in previous.keys() | hashes.keys() if previous.get(p) != hashes.get(p)}
    assert all(p in allowed or p.startswith('features/evaluator_virtual_cursor/scripts/benchmark_')
               or p.startswith('features/evaluator_virtual_cursor/resources/benchmark_')
               or p.startswith('tools/auto_tuning/benchmark_qualification/') for p in delta), delta
    helpers = {p.relative_to(ROOT).as_posix(): file_hash(p) for p in (ROOT / 'tools').glob('benchmark*.py')}
    atomic_json(target, {**identity, 'source_hashes': hashes, 'engine_identity': engine_identity(),
                        'reviewed_source_delta': delta, 'helper_hashes': helpers,
                        'plan_sha256': file_hash(DOC / 'run_plan.json'), 'optimizer': 'OFF'})
    print('Frozen', identity['repository_commit'], len(hashes), 'sources;', len(delta), 'reviewed deltas')

if __name__ == '__main__':
    main()
