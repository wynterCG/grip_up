"""Run the existing baseline suites without replacing the archived v0.1 evidence."""
from pathlib import Path
import concurrent.futures
import json
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
names = ['physics','platform_probe','wall_clearance','biped_profile','playthrough',
         'swing_playthrough','integration','biped_visual','idle_hang','ground_locomotion',
         'climb_direction','leg_motion','pendulum','free_climb','launch','full_reach','biped_asset']
label = sys.argv[1] if len(sys.argv)>1 else 'regressions'
selected = sys.argv[2:]
if label in ['m1','m2','v03','contextual']:
    names += ['m0_instrumentation','capture_input','capture_matrix']
if label in ['m2','v03','contextual']:
    names += ['foot_support','foot_integration','feet_routes','feet_swing']
if label in ['v03','contextual']:
    names += ['drag_input','drag_swing_physics']
if label == 'contextual':
    names += ['contextual_input','contextual_physics']
assert all(name in names for name in selected)
dest = root/'docs'/'validation'/label
dest.mkdir(parents=True,exist_ok=True)

def run(item):
    name, slow = item
    aliases = {'feet_routes':'playthrough','feet_swing':'swing_playthrough'}
    command = ['python',str(root/'tools'/'project.py'),'test','test_'+aliases.get(name,name)]
    flags = ['--feet'] if name in aliases else []
    if slow:
        flags += ['--60hz']
    if flags:
        command += ['--']+flags
    result = subprocess.run(command,capture_output=True,timeout=210)
    output = (result.stdout+result.stderr).decode('utf-8',errors='replace').replace('\r','').rstrip()+'\n'
    footer = re.search(r'RESULTS: (\d+) checks, (\d+) failures',output)
    ok = result.returncode==0 and footer and int(footer[2])==0 and 'FAIL ' not in output and 'SCRIPT ERROR:' not in output
    (dest/(name+('_60hz' if slow else '_120hz')+'.txt')).write_text(output,encoding='utf-8')
    print(name,60 if slow else 120,'PASS' if ok else 'FAIL',flush=True)
    return {'suite':name,'hz':60 if slow else 120,'passed':bool(ok),'checks':int(footer[1]) if footer else 0,'failures':int(footer[2]) if footer else None}

jobs = [(name,slow) for name in (selected or names) for slow in ([False] if name=='biped_asset' else [False,True])]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    suites = list(pool.map(run,jobs))
if selected and (dest/'results.json').exists():
    previous = json.loads((dest/'results.json').read_text(encoding='utf-8'))['suites']
    suites = [item for item in previous if item['suite'] not in selected]+suites
report = {'suites':suites,'total_checks':sum(item['checks'] for item in suites),'all_passed':all(item['passed'] for item in suites)}
(dest/'results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'checks':report['total_checks'],'all_passed':report['all_passed']}))
raise SystemExit(0 if report['all_passed'] else 1)
