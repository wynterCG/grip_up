"""Run and preserve the real v0.1 suite before feature development."""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import os
import re
import subprocess
from datetime import datetime, timezone

root = Path(__file__).resolve().parents[1]
dest = root/'docs'/'baselines'/'v0.1'
dest.mkdir(parents=True, exist_ok=True)
names = ['physics','platform_probe','wall_clearance','biped_profile','playthrough',
         'swing_playthrough','integration','biped_visual','idle_hang',
         'ground_locomotion','climb_direction','leg_motion','pendulum',
         'free_climb','launch','full_reach','biped_asset']

def run(item):
    name, slow = item
    command = ['python',str(root/'tools'/'project.py'),'test','test_'+name]
    if slow:
        command += ['--','--60hz']
    result = subprocess.run(command,capture_output=True,timeout=210)
    output = (result.stdout+result.stderr).decode('utf-8',errors='replace')
    label = name+('_60hz' if slow else '_120hz')
    (dest/(label+'.txt')).write_text(output,encoding='utf-8')
    footer = re.search(r'RESULTS: (\d+) checks, (\d+) failures',output)
    ok = result.returncode==0 and footer and int(footer[2])==0 and 'FAIL ' not in output and 'SCRIPT ERROR:' not in output
    print(label, 'PASS' if ok else 'FAIL', flush=True)
    return {'suite':name,'hz':60 if slow else 120,'checks':int(footer[1]) if footer else 0,
            'failures':int(footer[2]) if footer else None,'passed':bool(ok)}

jobs = [(name,slow) for name in names for slow in ([False] if name=='biped_asset' else [False,True])]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    suites = list(pool.map(run,jobs))
for name in ['project.godot','features/grip_up/resources/climbing_tuning.gd',
             'features/grip_up/resources/biped_tuning.gd']:
    (dest/(Path(name).name+'.txt')).write_bytes((root/name).read_bytes())
sessions = Path(os.environ['APPDATA'])/'Godot'/'app_userdata'/'GRIP UP'/'trials.jsonl'
representative = {}
if sessions.exists():
    for line in sessions.read_text(encoding='utf-8').splitlines():
        row = json.loads(line)
        if row.get('outcome')=='goal':
            representative[str(row.get('test'))] = row
(dest/'representative_sessions.jsonl').write_text(''.join(json.dumps(row)+'\n' for row in representative.values()),encoding='utf-8')
report = {'baseline_commit':'5c4aa72db58108ec482cd9d0e28086c28563f410',
          'recorded_utc':datetime.now(timezone.utc).isoformat(),'suites':suites,
          'total_checks':sum(row['checks'] for row in suites),
          'all_passed':all(row['passed'] for row in suites),
          'janga_sha256':hashlib.sha256(Path(r'E:\Godot Games\janga_proto\runtime\physics_grabber.gd').read_bytes()).hexdigest()}
(dest/'results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'checks':report['total_checks'],'all_passed':report['all_passed']}))
raise SystemExit(0 if report['all_passed'] else 1)
