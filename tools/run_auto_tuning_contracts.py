from pathlib import Path
import hashlib,json,re,subprocess,sys
from datetime import datetime,timezone
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
from project_config import ENGINE
base=root/'docs/validation/auto_tuning/contracts'
number=1
while (base/f'attempt_{number:03}').exists():number+=1
out=base/f'attempt_{number:03}';out.mkdir(parents=True)
jobs=[('python',[str(root/'tools/auto_tuning/.venv/Scripts/python.exe'),'-m','unittest','discover','-s','tools/auto_tuning/tests','-v'])]
for name in ('override_loader','response_metrics','trial_contract'):
    jobs.append((name,[str(ENGINE),'--headless','--path',str(root),'--script',f'res://features/auto_tuning_lab/tests/test_{name}.gd']))
jobs.append(('native_parse',[str(ENGINE),'--headless','--path',str(root),'--check-only','--script','res://features/auto_tuning_lab/scripts/native_review.gd']))
report={'recorded_utc':datetime.now(timezone.utc).isoformat(),'scope':'Python contracts, pure numerical metrics, resource isolation and native scene parsing; not human or full gameplay validation','runs':[]}
for name,command in jobs:
    result=subprocess.run(command,cwd=root,capture_output=True,timeout=90)
    text=(result.stdout+result.stderr).decode('utf-8',errors='replace').replace('\r','')
    (out/f'{name}.txt').write_text(text,encoding='utf-8')
    match=re.search(r'RESULTS: (\d+) checks, (\d+) failures',text)
    unit=re.search(r'Ran (\d+) tests?',text)
    passed=result.returncode==0 and 'SCRIPT ERROR:' not in text and 'FAIL ' not in text and 'ERROR:' not in text
    report['runs'].append({'name':name,'passed':passed,'exit_code':result.returncode,'checks':int(match[1]) if match else int(unit[1]) if unit else 0})
    print(name,'PASS' if passed else 'FAIL',flush=True)
report['source_sha256']={p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'features/auto_tuning_lab').rglob('*.gd')}
report['all_passed']=all(row['passed'] for row in report['runs'])
(out/'results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(out)
raise SystemExit(0 if report['all_passed'] else 1)
