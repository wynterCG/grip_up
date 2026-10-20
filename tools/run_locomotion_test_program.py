"""Versioned technical receipts; functional negative outcomes remain in studies."""
from pathlib import Path
from datetime import datetime, timezone
import gzip
import hashlib
import json
import re
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[1]
base = root / 'docs/validation/v12/automated'
base.mkdir(parents=True, exist_ok=True)
number = 1
while (base / f'attempt_{number:03}').exists():
    number += 1
out = base / f'attempt_{number:03}'
out.mkdir()
jobs = [('suite-test', 'measurement_metrics', []), ('suite-test', 'measurement_harness', []),
        ('suite-test', 'measurement_physics', []), ('suite-test', 'mastery_course', ['--segment=SAFETY'])]
report = {'recorded_utc': datetime.now(timezone.utc).isoformat(),
          'source': 'scripted', 'human_sessions': 0, 'runs': []}
identity = root / 'features/locomotion_test_suite/resources/build_identity.json'
report['identity'] = json.loads(identity.read_text())
fingerprint = lambda: {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                       for p in (root / 'features').rglob('*.gd')}
report['source_sha256'] = fingerprint()
for task, suite, flags in jobs:
    for hz in (120, 60):
        command = [sys.executable, str(root / 'tools/project.py'), task, 'test_' + suite]
        extra = flags + (['--60hz'] if hz == 60 else [])
        if extra:
            command += ['--'] + extra
        started = time.time()
        run = subprocess.run(command, capture_output=True, timeout=210)
        text = (run.stdout + run.stderr).decode('utf-8', errors='replace').replace('\r', '').rstrip() + '\n'
        (out / f'{suite}_{hz}hz.txt').write_text(text, encoding='utf-8')
        footer = re.search(r'RESULTS: (\d+) checks, (\d+) failures', text)
        passed = run.returncode == 0 and footer and int(footer[2]) == 0 and 'SCRIPT ERROR:' not in text and 'FAIL ' not in text
        report['runs'].append({'suite': suite, 'hz': hz, 'flags': extra, 'passed': bool(passed),
                               'checks': int(footer[1]) if footer else 0,
                               'failures': int(footer[2]) if footer else None, 'exit_code': run.returncode})
        path = root / f'builds/{suite}_{hz}hz.json'
        if path.exists() and path.stat().st_mtime >= started:
            raw = path.read_bytes()
            if len(raw) > 1_000_000:
                (out / (path.name + '.gz')).write_bytes(gzip.compress(raw, mtime=0))
            else:
                (out / path.name).write_bytes(raw)
        print(suite, hz, 'PASS' if passed else 'FAIL', flush=True)
report['sources_unchanged'] = report['source_sha256'] == fingerprint()
report['all_passed'] = all(row['passed'] for row in report['runs']) and report['sources_unchanged']
report['checks'] = sum(row['checks'] for row in report['runs'])
(out / 'results.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print('Archived', out, 'checks', report['checks'], flush=True)
raise SystemExit(0 if report['all_passed'] else 1)
