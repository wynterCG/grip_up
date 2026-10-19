"""Collect actual completed suite footers, current executable hash and rendered QA."""
from pathlib import Path
import hashlib
import json
import re
from datetime import datetime, timezone

root = Path(__file__).resolve().parents[1]
builds = root/'builds'
validation = root/'docs'/'validation'/'v03'
aggregate = json.loads((validation/'results.json').read_text())
suites = {}
for item in aggregate['suites']:
    name,rate = item['suite'],str(item['hz'])+'hz'
    log = validation/f'{name}_{rate}.txt'
    output = log.read_text(encoding='utf-8')
    footer = re.search(r'RESULTS: (\d+) checks, (\d+) failures',output)
    assert item['passed'] and footer and int(footer[1])==item['checks'] and int(footer[2])==0 and 'SCRIPT ERROR:' not in output and 'FAIL ' not in output,log
    suites.setdefault(name,{})[rate] = int(footer[1])
legacy = Path(r'E:\Godot Games\janga_proto\runtime\physics_grabber.gd')
legacy_hash = hashlib.sha256(legacy.read_bytes()).hexdigest()
assert legacy_hash=='8ab923ac1d903e8dcc8ed2a2e4f9f8c5cec326a3217cb4a9d8f00036557e7dad'
assert aggregate['all_passed'] and aggregate['total_checks']==sum(sum(rates.values()) for rates in suites.values())
smoke = (builds/'smoke_export.log').read_text(encoding='utf-8')
assert '3 frames at 60 FPS' in smoke and 'SCRIPT ERROR:' not in smoke
report = {
    'revision':'v0.3: hold-to-grip, mouse arm drag and supported 3D swing',
    'recorded_utc':datetime.now(timezone.utc).isoformat(),
    'engine':'4.7.2.stable.ed1daf0bf','backend':'Jolt Physics','default_hz':120,
    'suites':suites,'total_checks':sum(sum(rates.values()) for rates in suites.values()),'failures':0,
    'legacy':{'unchanged_grabber_sha256':legacy_hash,'previous_smoke_checks':72},
    'baseline_ref':'v0.1-baseline',
    'previous_milestone_ref':'v0.2-M2',
    'default_input_profile':1,
    'default_profile_reason':'User requested the new arm controls active at startup; feel comparison remains pending',
    'experimental_space_launch':False,
    'arm_drag_mapping':'mouse up contracts / mouse down extends (user override)',
    'default_flags':dict.fromkeys(['predictive_grip','physical_feet','posture_solver','directional_grip_quality','reactive_challenge'],False),
    'exe_name':'GripUp-v0.3.exe',
    'exe_sha256':hashlib.sha256((builds/'GripUp-v0.3.exe').read_bytes()).hexdigest(),
    'mcp_project':'E:/Godot Games/grip_up/',
    'rendered_controls':{str(hz):json.loads((validation/f'rendered_{hz}hz.json').read_text()) for hz in [120,60]},
    'export_smoke_frames':3,'human_playtest':'v0.3 M4: 10-15 minute coordination, fatigue and enjoyment comparison pending',
    'future_milestones':['v0.2 M3 support-aware posture','v0.2 M4 directional grips','v0.2 M5 reactive challenge','v0.2 M6 mantle']
}
assert all(item['passed'] for run in report['rendered_controls'].values() for item in run['checks'])
(builds/'verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
(validation/'verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(f"Verified {report['total_checks']} checks, zero failures. Legacy source unchanged.")
