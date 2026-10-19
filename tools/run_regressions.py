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
evidence_label = label
requested_label = 'v09' if label == 'v10_baseline' else label
label = requested_label
if label == 'v07_baseline':label = 'v06'
if label in ['v07','v071','v072','v073','v074','v08','v09']:label = 'v06'
selected = sys.argv[2:]
if label in ['m1','m2','v03','contextual','v04','v05','v06']:
    names += ['m0_instrumentation','capture_input','capture_matrix']
if label in ['m2','v03','contextual','v04','v05','v06']:
    names += ['foot_support','foot_integration','feet_routes','feet_swing']
if label in ['v03','contextual','v04','v05','v06']:
    names += ['drag_input','drag_swing_physics']
if label in ['contextual','v04','v05','v06']:
    names += ['contextual_input','contextual_physics']
if label in ['v04','v05','v06']:
    names += ['independent_input','independent_physics','independent_routes']
if label in ['v05','v06']:
    names += ['transfer_diagnostics','transfer_routes','transfer_routes_p1','transfer_routes_p2',
              'posture_study','swing_diagnostics','transfer_swing','reach_assessment','transfer_capture']
if label == 'v06':
    names += ['distant_baseline','pending_grip','pending_motion','pending_contact','distant_input','distant_routes','distant_swing']
if requested_label in ['v07','v071','v072','v073','v074','v08','v09']:
    names += ['intent_locomotion','intent_swing','intent_integration','intent_arenas']
if requested_label in ['v071','v072','v073','v074','v08','v09']:
    names += ['intent_reversal','intent_progress','intent_handoffs','intent_frame_sign']
if requested_label in ['v072','v073','v074','v08','v09']:
    names += ['reachable_grip','reach_visual']
if requested_label in ['v073','v074','v08','v09']:
    names += ['route_progress','climbing_route']
if requested_label in ['v074','v08','v09']:
    names += ['intent_mantle','mantle_integration']
if requested_label in ['v08','v09']:
    # Safety and isolated capabilities only. The deliberately failing functional
    # gate remains separately archived under v08/m4; this cannot accept top-out.
    names += ['palm_compression','palm_wrist','mantle_leg_clearance','mantle_support_handoff']
if requested_label == 'v09':
    names += ['hybrid_motor','hybrid_animation','hybrid_mantle','hybrid_sequence','hybrid_resilience']
assert all(name in names for name in selected)
dest = root/'docs'/'validation'/evidence_label
dest.mkdir(parents=True,exist_ok=True)

def run(item):
    name, slow = item
    aliases = {'feet_routes':'playthrough','feet_swing':'swing_playthrough',
               'transfer_routes_p1':'transfer_routes','transfer_routes_p2':'transfer_routes',
               'distant_routes':'transfer_routes','distant_swing':'transfer_swing'}
    command = ['python',str(root/'tools'/'project.py'),'test','test_'+aliases.get(name,name)]
    flags = ['--feet'] if name in ['feet_routes','feet_swing'] else []
    if name in ['distant_routes','distant_swing']:flags += ['--distant']
    if name.startswith('transfer_routes_p'):flags += ['--'+name.rsplit('_',1)[1]]
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
if requested_label == 'v08':
    report['scope'] = 'Regression and isolated capability checks; not functional mantle acceptance'
    report['functional_mantle_gate_met'] = False
if requested_label == 'v09':
    report['functional_static_mantle_gate_met'] = all(row['passed'] for row in suites if row['suite']=='hybrid_mantle') and len([row for row in suites if row['suite']=='hybrid_mantle'])==2
    report['human_gate_complete'] = False
(dest/'results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'checks':report['total_checks'],'all_passed':report['all_passed']}))
raise SystemExit(0 if report['all_passed'] else 1)
