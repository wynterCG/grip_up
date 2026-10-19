"""Archive the unchanged pre-v1.1 baseline; never labels scripts as human play."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
SAVED = Path(r'E:\Godot Games\grip_up')
BASELINE = '6646cdeda0a0104b723c483905a9a4fc36e00674'
SUITES = ['intent_locomotion', 'intent_progress', 'intent_reversal',
          'intent_handoffs', 'intent_frame_sign', 'intent_swing',
          'intent_integration', 'intent_arenas', 'foot_support',
          'reachable_grip', 'climbing_route', 'vault_v10',
          'vault_resilience', 'first_ascent']

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

previous = json.loads((ROOT/'docs/validation/v10/course_source_sha256.json').read_text())
assert all(digest(ROOT/name) == expected == digest(SAVED/name)
           for name, expected in previous.items()), 'Baseline feature sources changed'
manifest = {p.relative_to(ROOT).as_posix(): digest(p)
            for p in sorted((ROOT/'features/grip_up').rglob('*')) if p.is_file()}
for name in ['project.godot', 'export_presets.cfg']:
    assert digest(ROOT/name) == digest(SAVED/name)
    manifest[name] = digest(ROOT/name)

exe = ROOT/'builds/GripUp-v1.0-experimental.exe'
assert digest(exe) == '79c592e0dcaffdfe185cd9c4115a74a7f0e98f21c8f3705e4869807b11aa8293'
for directory in [ROOT/'builds', SAVED/'builds']:
    backup = directory/'GripUp-v1.0-pre-v1.1.exe'
    if backup.exists():
        assert digest(backup) == digest(exe)
    else:
        shutil.copy2(exe, backup)
assert digest(Path(r'E:\Godot Games\janga_proto\runtime\physics_grabber.gd')) == '8ab923ac1d903e8dcc8ed2a2e4f9f8c5cec326a3217cb4a9d8f00036557e7dad'

base = ROOT/'docs/validation/v11/lp0'
number = 1
while (base/f'attempt_{number:03}').exists():
    number += 1
out = base/f'attempt_{number:03}'
out.mkdir(parents=True)
report = {'recorded_utc': datetime.now(timezone.utc).isoformat(),
          'baseline_commit': BASELINE,
          'provenance': 'Automated unchanged baseline regression; not a human session',
          'human_gate': 'PENDING', 'source_sha256': manifest, 'runs': []}
for suite in SUITES:
    for hz in (120, 60):
        command = [sys.executable, str(ROOT/'tools/project.py'), 'test', 'test_'+suite]
        if hz == 60:
            command += ['--', '--60hz']
        started = time.time()
        run = subprocess.run(command, capture_output=True, timeout=210)
        output = (run.stdout+run.stderr).decode('utf-8', errors='replace').replace('\r', '').rstrip()+'\n'
        (out/f'{suite}_{hz}hz.txt').write_text(output, encoding='utf-8')
        footer = re.search(r'RESULTS: (\d+) checks, (\d+) failures', output)
        passed = bool(run.returncode == 0 and footer and int(footer[2]) == 0
                      and 'SCRIPT ERROR:' not in output and 'FAIL ' not in output)
        report['runs'].append({'suite': suite, 'hz': hz, 'passed': passed,
                               'checks': int(footer[1]) if footer else 0,
                               'failures': int(footer[2]) if footer else None,
                               'exit_code': run.returncode})
        receipt = 'hybrid_resilience' if suite == 'vault_resilience' else suite
        path = ROOT/f'builds/{receipt}_{hz}hz.json'
        if path.exists() and path.stat().st_mtime >= started:
            shutil.copy2(path, out/f'{suite}_{hz}hz.json')
        print(suite, hz, 'PASS' if passed else 'FAIL', flush=True)
report['all_passed'] = all(row['passed'] for row in report['runs'])
report['checks'] = sum(row['checks'] for row in report['runs'])
report['source_unchanged_after_tests'] = all(digest(ROOT/name) == expected
                                             for name, expected in manifest.items())
report['all_passed'] = report['all_passed'] and report['source_unchanged_after_tests']
(out/'results.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print('Archived', out, 'checks', report['checks'], flush=True)
sys.exit(0 if report['all_passed'] else 1)
