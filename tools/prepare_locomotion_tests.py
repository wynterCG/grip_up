"""Freeze exact runtime identity and verify the v1.2 no-locomotion-change contract."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parents[1]
saved = Path(r'E:\Godot Games\grip_up')
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
old = json.loads((root / 'docs/validation/v12/baseline/freeze.json').read_text())
allowed = {'features/grip_up/scripts/grip_up_lab.gd', 'features/grip_up/scripts/locomotion_observer.gd'}
changed = [name for name, value in old['source_sha256'].items() if digest(root / name) != value]
assert set(changed) <= allowed, 'Gameplay mechanism changed: ' + str(set(changed) - allowed)
assert digest(Path(r'E:\Godot Games\janga_proto\runtime\physics_grabber.gd')) == '8ab923ac1d903e8dcc8ed2a2e4f9f8c5cec326a3217cb4a9d8f00036557e7dad'
identity_path = root / 'features/locomotion_test_suite/resources/build_identity.json'
sources = {p.relative_to(root).as_posix(): digest(p) for p in (root / 'features').rglob('*')
           if p.is_file() and p != identity_path and p.suffix in ('.gd', '.tres', '.json', '.tscn', '.glb')}
for name in ('project.godot', 'export_presets.cfg'):
    sources[name] = digest(root / name)
git = lambda *args: subprocess.check_output(['git', *args], cwd=saved, text=True).strip()
mirror_diff = [name for name, value in sources.items() if not (saved / name).exists() or digest(saved / name) != value]
data = {
    'schema_version': 'locomotion_build_v12_1',
    'generated_utc': datetime.now(timezone.utc).isoformat(),
    'branch': git('branch', '--show-current'), 'commit': git('rev-parse', 'HEAD'),
    'dirty_tree': bool(git('status', '--porcelain')) or bool(mirror_diff),
    'dirty_reason': 'Git status and/or source mirror differs from saved working tree',
    'source_sha256': sources,
    'build_id': hashlib.sha256(json.dumps(sources, sort_keys=True).encode()).hexdigest(),
    'baseline_commit': old['source_commit'], 'changed_baseline_files': changed,
    'unchanged_physical_mechanisms': True, 'janga_unchanged': True,
    'engine_expected': '4.7.2 / ed1daf0bf001b61586d9930840f2f1394092c079',
    'runtime_engine_and_bindings': 'Recorded separately for each actual session',
}
identity_path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
out = root / 'docs/validation/v12/baseline'
(out / 'candidate_identity.json').write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
print('Prepared identity', data['build_id'][:16], 'dirty', data['dirty_tree'], 'baseline changes', changed)
