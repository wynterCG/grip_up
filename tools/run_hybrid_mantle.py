"""Numbered v0.9 attempts preserve successful and failed physical evidence."""
from pathlib import Path
import argparse, json, re, subprocess, sys, shutil, time, hashlib
from datetime import datetime, timezone
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('milestone')
parser.add_argument('suites',nargs='+')
args=parser.parse_args()
assert re.fullmatch(r'[a-z0-9_]+',args.milestone)
assert all(re.fullmatch(r'[a-z0-9_]+',name) for name in args.suites)
base=root/'docs/validation/v09'/args.milestone
base.mkdir(parents=True,exist_ok=True)
number=1
while (base/f'attempt_{number:03}').exists():number+=1
out=base/f'attempt_{number:03}';out.mkdir()
report={'recorded_utc':datetime.now(timezone.utc).isoformat(),'provenance':'Automated Godot evidence, not human acceptance','runs':[]}
for suite in args.suites:
    for hz in (120,60):
        command=[sys.executable,str(root/'tools/project.py'),'test','test_'+suite]
        if hz==60:command+=['--','--60hz']
        started=time.time()
        run=subprocess.run(command,capture_output=True,timeout=210)
        text=(run.stdout+run.stderr).decode('utf-8',errors='replace').replace('\r','').rstrip()+'\n'
        (out/f'{suite}_{hz}hz.txt').write_text(text,encoding='utf-8')
        footer=re.search(r'RESULTS: (\d+) checks, (\d+) failures',text)
        passed=run.returncode==0 and footer and int(footer[2])==0 and 'SCRIPT ERROR:' not in text
        row={'suite':suite,'hz':hz,'passed':bool(passed),'checks':int(footer[1]) if footer else 0,'failures':int(footer[2]) if footer else None,'exit_code':run.returncode}
        report['runs'].append(row)
        p=root/f'builds/{suite}_{hz}hz.json'
        if p.exists() and p.stat().st_mtime>=started:shutil.copy2(p,out/p.name)
        print(suite,hz,'PASS' if passed else 'FAIL',flush=True)
report['all_passed']=all(row['passed'] for row in report['runs'])
report['source_sha256']={str(p.relative_to(root)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'features/grip_up').rglob('*.gd')}
(out/'results.json').write_text(json.dumps(report,indent=2)+'\n')
print('Archived',out)
sys.exit(0 if report['all_passed'] else 1)
