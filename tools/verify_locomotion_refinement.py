"""Validate the v1.1 candidate's receipts, saved sources and protected baseline."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import gzip
import json
import re
import shutil

root = Path(__file__).resolve().parents[1]
saved = Path(r'E:\Godot Games\grip_up')
out = root / 'docs/validation/v11'
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text(encoding='utf-8'))
old = read(out / 'lp0/attempt_001/results.json')['source_sha256']
sources = {p.relative_to(root).as_posix(): digest(p)
           for p in sorted((root / 'features/grip_up').rglob('*')) if p.is_file()}
for name in ('project.godot', 'export_presets.cfg'):
    sources[name] = digest(root / name)
assert all((saved / name).exists() and digest(saved / name) == value for name, value in sources.items())
protected_names = ['arm_actuator.gd', 'supported_swing.gd', 'ground_locomotion.gd',
                   'locomotion_support_frame.gd', 'hybrid_mantle_controller.gd']
for name in protected_names:
    path = 'features/grip_up/scripts/' + name
    assert sources[path] == old[path], 'Protected physical mechanism changed: ' + name
original_exe_sha = '79c592e0dcaffdfe185cd9c4115a74a7f0e98f21c8f3705e4869807b11aa8293'
for directory in (root, saved):
    assert digest(directory / 'builds/GripUp-v1.0-pre-v1.1.exe') == original_exe_sha
janga = Path(r'E:\Godot Games\janga_proto\runtime\physics_grabber.gd')
assert digest(janga) == '8ab923ac1d903e8dcc8ed2a2e4f9f8c5cec326a3217cb4a9d8f00036557e7dad'
baseline = read(root / 'docs/validation/v11_baseline/results.json')
overlay = read(out / 'final/attempt_001/results.json')
warning_fix = read(out / 'warning_cleanup/attempt_001/results.json')
observer_fix = read(out / 'assisted_observer_fix/attempt_001/results.json')
native_dir = sorted((out / 'native').glob('attempt_*'))[-1]
native = read(native_dir / 'results.json')
for report in (baseline, overlay, warning_fix, observer_fix, native):
    assert report['all_passed']
assert all(row.get('assisted_hand_forces_zero') for row in native['runs'])
for path, value in native['source_sha256'].items():
    assert sources[path] == value, 'Native receipt not current: ' + path
for path, value in observer_fix['source_sha256'].items():
    assert sources[path] == value, 'Final observer receipt not current: ' + path
exe = root / 'builds/GripUp-v1.1-experimental.exe'
assert digest(saved / 'builds' / exe.name) == digest(exe)
evidence = out / 'export'
evidence.mkdir(exist_ok=True)
for name in ('export_export.log', 'smoke_export.log'):
    text = (root / 'builds' / name).read_text(encoding='utf-8')
    assert 'SCRIPT ERROR:' not in text and 'ERROR:' not in text
    raw = (root / 'builds' / name).read_bytes()
    (evidence / (name + '.raw.gz')).write_bytes(gzip.compress(raw, mtime=0))
    plain = re.sub(r'\x1b\[[0-9;]*[A-Za-z]', '', text.replace('\r', ''))
    (evidence / (name + '.txt')).write_text('\n'.join(line.rstrip() for line in plain.splitlines()).rstrip() + '\n', encoding='utf-8')
assert '3 frames at 60 FPS' in (root / 'builds/smoke_export.log').read_text(encoding='utf-8')
manifest = {
    'recorded_utc': datetime.now(timezone.utc).isoformat(),
    'branch': 'feature/v1.1-locomotion-refinement',
    'baseline_commit': '6646cdeda0a0104b723c483905a9a4fc36e00674',
    'rollback_tag': 'baseline/pre-v1.1-locomotion',
    'C_E_source_parity': True, 'source_sha256': sources,
    'baseline_changed_files': [name for name, value in old.items() if sources.get(name) != value],
    'added_feature_files': [name for name in sources if name not in old],
    'protected_physical_mechanisms_unchanged': protected_names,
    'janga_unchanged': True, 'baseline_build_preserved': True,
    'headless_checks': baseline['total_checks'] + sum(row['checks'] for row in overlay['runs']),
    'headless_runs': len(baseline['suites']) + len(overlay['runs']),
    'regressions_passed': True, 'known_A1_gameplay_regression_retained_separately': True,
    'post_matrix_changes': ['Local A1 variable rename only', 'Read-only observer clears stale assisted hand forces'],
    'post_matrix_rechecks': ['warning_cleanup/attempt_001', 'assisted_observer_fix/attempt_001'],
    'native': native_dir.relative_to(out).as_posix(),
    'native_checks': sum(row['checks'] for row in native['runs']),
    'native_runs': native['runs'],
    'export': {'name': exe.name, 'sha256': digest(exe), 'startup_smoke_frames': 3,
               'full_course_in_exported_executable': False},
    'source_defaults': {'profile': 2, 'movement_allocation': 0, 'intent_aware_feet': False,
                        'swing_feedback': False, 'locomotion_diagnostics': False},
    'human_gate': 'PENDING', 'human_ratings': None, 'default_promotion': False,
    'M7_started': False, 'full_v11_spec_complete': False,
}
(out / 'verification.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: manifest[key] for key in ('headless_checks', 'headless_runs', 'native_checks', 'C_E_source_parity', 'janga_unchanged', 'export')}))
