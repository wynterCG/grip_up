"""Verify actual v0.5 evidence; preserve the archived v0.4 verification writer."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re
import shutil

root=Path(__file__).resolve().parents[1]
validation=root/'docs/validation/v05'
final=root/'docs/validation/v05_final'
aggregate=json.loads((validation/'results.json').read_text())
assert aggregate['all_passed']
for item in aggregate['suites']:
    text=(validation/f"{item['suite']}_{item['hz']}hz.txt").read_text(encoding='utf-8')
    footer=re.search(r'RESULTS: (\d+) checks, (\d+) failures',text)
    assert item['passed'] and footer and int(footer[1])==item['checks'] and int(footer[2])==0 and 'FAIL ' not in text and 'SCRIPT ERROR:' not in text
assert sum(item['checks'] for item in aggregate['suites'])==aggregate['total_checks']
native={str(hz):json.loads((final/f'rendered_{hz}hz.json').read_text()) for hz in [120,60]}
assert all(run['complete'] and all(item['passed'] for item in run['checks']) and run['route']['transfers']==10 and run['route']['recoveries']==0 for run in native.values())
ui=json.loads((root/'builds/v05_ui_final.json').read_text())
assert ui['new_flags_off'] and ui['posture_variant']==0 and ui['hud_matches_viewport']
errors,_=json.JSONDecoder().raw_decode((root/'builds/v05_editor_errors.json').read_text(encoding='utf-8'))
assert errors['count']==0
smoke=(root/'builds/smoke_export.log').read_text(encoding='utf-8')
assert '3 frames at 60 FPS' in smoke and 'SCRIPT ERROR:' not in smoke
legacy=hashlib.sha256(Path(r'E:\Godot Games\janga_proto\runtime\physics_grabber.gd').read_bytes()).hexdigest()
assert legacy=='8ab923ac1d903e8dcc8ed2a2e4f9f8c5cec326a3217cb4a9d8f00036557e7dad'
report={
 'revision':'v0.5 transfer posture and conservative reach study',
 'recorded_utc':datetime.now(timezone.utc).isoformat(),
 'engine':'Godot4.7.2 / Jolt','default_hz':120,
 'automated_checks':aggregate['total_checks'],'automated_failures':0,
 'suite_runs':len(aggregate['suites']),
 'native_scripted_checks':sum(len(run['checks']) for run in native.values()),'native_scripted_failures':0,
 'native_route_transfers':{hz:run['route']['transfers'] for hz,run in native.items()},
 'editor_errors_or_warnings':0,'export_smoke_frames':3,
 'exe_name':'GripUp-v0.5.exe','exe_sha256':hashlib.sha256((root/'builds/GripUp-v0.5.exe').read_bytes()).hexdigest(),
 'legacy_grabber_unchanged_sha256':legacy,
 'default_input_profile':2,'independent_aim_profile':3,'default_posture_policy':'B',
 'new_flags':{'transfer_assist_enabled':False,'posture_variant':0,'reach_prediction_enabled':False,'catch_buffer_enabled':False,'catch_buffer_duration':.12},
 'budgets':{'body_mass_kg':12,'shared_hand_force_n':360,'shared_assist_torque_nm':20,'resultant_torque_nm':150,'hand_speed_m_s':4,'anatomical_reach_m':.65708},
 'recoverable_refs':{'v04':'d53b43d','v05_m1':'db6ea96','isolated_p1':'21d896b'},
 'observed_interactive':json.loads((root/'docs/validation/v05_human_observed/summary.json').read_text()),
 'decision':'KEEP diagnostics and optional P1 moving-support correction; REJECT P2 as default; REVISE before promoting assistance or buffer, human comparison pending',
 'human_gate_complete':False,
 'remaining_human_work':'Three-session/two-completion pilot, P0/P1/P2 and buffer comparison, agency/comfort/fatigue/retry ratings'
}
for path in [root/'builds/verification.json',final/'verification.json']:
    path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
shutil.copy2(root/'builds/v05_ui_final.json',final/'ui_final.json')
shutil.copy2(root/'builds/v05_controls_final.png',final/'controls_final.png')
shutil.copy2(root/'builds/export00000002.png',final/'export_smoke.png')
(final/'export_smoke.txt').write_text(smoke.replace('\r','').rstrip()+'\n',encoding='utf-8')
(final/'editor_errors.json').write_text(json.dumps(errors,indent=2)+'\n',encoding='utf-8')
print(f"Verified {aggregate['total_checks']} automated + {report['native_scripted_checks']} native scripted checks, zero failures; human comparative gate pending.")
