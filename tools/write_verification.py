"""Collect actual completed suite footers, current executable hash and rendered QA."""
from pathlib import Path
import hashlib
import json
import re
from datetime import datetime, timezone

root = Path(__file__).resolve().parents[1]
builds = root/'builds'
suites = {}
for name in ['physics','platform_probe','wall_clearance','biped_profile','playthrough','swing_playthrough','integration','biped_visual','idle_hang','ground_locomotion','climb_direction','leg_motion','pendulum','free_climb','launch','full_reach','biped_asset','m0_instrumentation','capture_input','capture_matrix']:
    rates = ['120hz'] if name=='biped_asset' else ['120hz','60hz']
    suites[name] = {}
    for rate in rates:
        log = builds/f'test_test_{name}{"_60hz" if rate=="60hz" else ""}.log'
        output = log.read_text(encoding='utf-8')
        footer = re.search(r'RESULTS: (\d+) checks, (\d+) failures',output)
        assert footer and int(footer[2])==0 and 'SCRIPT ERROR:' not in output and 'FAIL ' not in output, log
        suites[name][rate] = int(footer[1])
legacy = Path(r'E:\Godot Games\janga_proto\runtime\physics_grabber.gd')
legacy_hash = hashlib.sha256(legacy.read_bytes()).hexdigest()
assert legacy_hash=='8ab923ac1d903e8dcc8ed2a2e4f9f8c5cec326a3217cb4a9d8f00036557e7dad'
validation = root/'docs'/'validation'/'m1'
aggregate = json.loads((validation/'results.json').read_text())
assert aggregate['all_passed'] and aggregate['total_checks']==sum(sum(rates.values()) for rates in suites.values())
smoke = (builds/'smoke_export.log').read_text(encoding='utf-8')
assert '3 frames at 60 FPS' in smoke and 'SCRIPT ERROR:' not in smoke
report = {
    'revision':'v0.2 M0/M1: protected baseline / opt-in predictive held capture',
    'recorded_utc':datetime.now(timezone.utc).isoformat(),
    'engine':'4.7.2.stable.ed1daf0bf','backend':'Jolt Physics','default_hz':120,
    'suites':suites,'total_checks':sum(sum(rates.values()) for rates in suites.values()),'failures':0,
    'legacy':{'unchanged_grabber_sha256':legacy_hash,'previous_smoke_checks':72},
    'baseline_ref':'v0.1-baseline',
    'default_flags':dict.fromkeys(['predictive_grip','physical_feet','posture_solver','directional_grip_quality','reactive_challenge'],False),
    'exe_name':'GripUp-v0.2-M1.exe',
    'exe_sha256':hashlib.sha256((builds/'GripUp-v0.2-M1.exe').read_bytes()).hexdigest(),
    'mcp_project':'E:/Godot Games/grip_up/',
    'rendered_capture':{str(hz):json.loads((validation/f'rendered_{hz}hz.json').read_text()) for hz in [120,60]},
    'export_smoke_frames':3,'human_playtest':'M1 unfamiliar-player A/B evaluation pending',
    'future_milestones':['M2 physical feet','M3 support-aware posture','M4 directional grips','M5 reactive challenge','M6 mantle']
}
(builds/'verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
(validation/'verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(f"Verified {report['total_checks']} checks, zero failures. Legacy source unchanged.")
