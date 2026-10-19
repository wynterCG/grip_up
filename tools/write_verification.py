"""Collect actual completed suite footers, current executable hash and rendered QA."""
from pathlib import Path
import hashlib
import json
import re
from datetime import datetime, timezone

root = Path(__file__).resolve().parents[1]
builds = root/'builds'
suites = {}
for name in ['physics','platform_probe','wall_clearance','biped_profile','playthrough','swing_playthrough','integration','biped_visual','idle_hang','ground_locomotion','climb_direction','leg_motion','pendulum','free_climb','launch','full_reach','biped_asset']:
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
report = {
    'revision':'charged physical launch / full anatomical reach / free surface climbing',
    'recorded_utc':datetime.now(timezone.utc).isoformat(),
    'engine':'4.7.2.stable.ed1daf0bf','backend':'Jolt Physics','default_hz':120,
    'suites':suites,'total_checks':sum(sum(rates.values()) for rates in suites.values()),'failures':0,
    'legacy':{'unchanged_grabber_sha256':legacy_hash,'previous_smoke_checks':72},
    'exe_sha256':hashlib.sha256((builds/'GripUp-v0.1.exe').read_bytes()).hexdigest(),
    'mcp_project':'E:/Godot Games/grip_up/',
    'rendered_ground_walk':json.loads((builds/'ground_walk_capture.json').read_text()),
    'rendered_leg_suspension':json.loads((builds/'biped_visual_capture.json').read_text()),
    'rendered_free_climb':json.loads((builds/'free_climb_capture.json').read_text()),
    'rendered_launch':json.loads((builds/'launch_capture.json').read_text()),
    'export_smoke_frames':3,'human_playtest':'user trying prototype; unfamiliar-player evaluation pending'
}
(builds/'verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(f"Verified {report['total_checks']} checks, zero failures. Legacy source unchanged.")
