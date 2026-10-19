"""Archive each v0.8 milestone attempt, including failures, without overwriting it."""
from pathlib import Path
import argparse
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('milestone')
parser.add_argument('suites', nargs='+')
parser.add_argument('--saved', action='store_true')
args = parser.parse_args()
assert re.fullmatch(r'[a-z0-9_]+', args.milestone)
assert all(re.fullmatch(r'[a-z0-9_]+', name) for name in args.suites)
base = root/'docs/validation/v08'/args.milestone
base.mkdir(parents=True, exist_ok=True)
number = 1
while (base/f'attempt_{number:03}').exists():
    number += 1
out = base/f'attempt_{number:03}'
out.mkdir()
saved = Path(r'E:\Godot Games\grip_up')
source = saved if args.saved else root
report = {'recorded_utc':datetime.now(timezone.utc).isoformat(),
          'source':str(source),'provenance':'Automated physical evidence; not human acceptance',
          'baseline_commit':subprocess.check_output(['git','-C',str(saved),'rev-parse','HEAD'],text=True).strip(),
          'runs':[]}
for suite in args.suites:
    for hz in [120,60]:
        command = [sys.executable,str(root/'tools/project.py'),
                   'test-saved' if args.saved else 'test','test_'+suite]
        if hz==60:
            command += ['--','--60hz']
        result = subprocess.run(command,capture_output=True,timeout=210)
        output = (result.stdout+result.stderr).decode('utf-8',errors='replace').replace('\r','')
        (out/f'{suite}_{hz}hz.txt').write_text(output,encoding='utf-8')
        footer = re.search(r'RESULTS: (\d+) checks, (\d+) failures',output)
        passed = result.returncode==0 and footer is not None and int(footer[2])==0 and 'SCRIPT ERROR:' not in output and 'FAIL ' not in output
        row = {'suite':suite,'hz':hz,'passed':bool(passed),'checks':int(footer[1]) if footer else 0,
               'failures':int(footer[2]) if footer else None,'exit_code':result.returncode}
        report['runs'].append(row)
        artifact = source/f'builds/{suite}_{hz}hz.json'
        if artifact.exists():
            shutil.copy2(artifact,out/artifact.name)
        print(suite,hz,'PASS' if passed else 'FAIL',flush=True)
        (out/'results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
report['all_passed'] = all(row['passed'] for row in report['runs'])
report['total_checks'] = sum(row['checks'] for row in report['runs'])
(out/'results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('Archived:',out)
sys.exit(0 if report['all_passed'] else 1)
