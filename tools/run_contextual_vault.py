"""Preserve numbered v1.0 experiments, including failed test receipts."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import gzip
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('milestone')
parser.add_argument('suites', nargs='+')
parser.add_argument('--report-root', default='docs/validation/v10')
args = parser.parse_args()
assert re.fullmatch(r'[a-z0-9_]+', args.milestone)
assert all(re.fullmatch(r'[a-z0-9_]+', name) for name in args.suites)
base = root / args.report_root / args.milestone
assert base.resolve().is_relative_to((root/'docs/validation').resolve())
base.mkdir(parents=True, exist_ok=True)
number = 1
while (base / f'attempt_{number:03}').exists():
    number += 1
out = base / f'attempt_{number:03}'
out.mkdir()
report = {'recorded_utc': datetime.now(timezone.utc).isoformat(),
          'provenance': 'Automated Godot evidence, not human acceptance', 'runs': []}
for suite in args.suites:
    for hz in (120, 60):
        command = [sys.executable, str(root / 'tools/project.py'), 'test', 'test_' + suite]
        if hz == 60:
            command += ['--', '--60hz']
        started = time.time()
        run = subprocess.run(command, capture_output=True, timeout=210)
        text = (run.stdout + run.stderr).decode('utf-8', errors='replace').replace('\r', '').rstrip() + '\n'
        (out / f'{suite}_{hz}hz.txt').write_text(text, encoding='utf-8')
        footer = re.search(r'RESULTS: (\d+) checks, (\d+) failures', text)
        passed = run.returncode == 0 and footer and int(footer[2]) == 0 and 'SCRIPT ERROR:' not in text and 'FAIL ' not in text
        report['runs'].append({'suite': suite, 'hz': hz, 'passed': bool(passed),
                               'checks': int(footer[1]) if footer else 0,
                               'failures': int(footer[2]) if footer else None,
                               'exit_code': run.returncode})
        receipt = 'hybrid_resilience' if suite == 'vault_resilience' else suite
        p = root / f'builds/{receipt}_{hz}hz.json'
        if p.exists() and p.stat().st_mtime >= started:
            destination = out / f'{suite}_{hz}hz.json'
            if p.stat().st_size > 1_000_000:
                destination.with_suffix('.json.gz').write_bytes(gzip.compress(p.read_bytes(), mtime=0))
            else:
                shutil.copy2(p, destination)
        print(suite, hz, 'PASS' if passed else 'FAIL', flush=True)
report['all_passed'] = all(row['passed'] for row in report['runs'])
report['source_sha256'] = {str(p.relative_to(root)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in (root / 'features/grip_up').rglob('*')
                         if p.is_file() and p.suffix in ('.gd', '.tres')}
(out / 'results.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print('Archived', out)
sys.exit(0 if report['all_passed'] else 1)
