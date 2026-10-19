"""Verify final v0.6 receipts without replacing historical v0.4/v0.5 evidence."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib
import json
import re
import shutil

root=Path(__file__).resolve().parents[1]
dest=Path(r'E:\Godot Games\grip_up')
final=root/'docs/validation/v06_final'
aggregate=json.loads((root/'docs/validation/v06/results.json').read_text())
assert aggregate['all_passed']
for item in aggregate['suites']:
    log=(root/f"docs/validation/v06/{item['suite']}_{item['hz']}hz.txt").read_text(encoding='utf-8')
    footer=re.search(r'RESULTS: (\d+) checks, (\d+) failures',log)
    assert item['passed'] and footer and int(footer[1])==item['checks'] and int(footer[2])==0
    assert 'FAIL ' not in log and 'SCRIPT ERROR:' not in log
assert sum(x['checks'] for x in aggregate['suites'])==aggregate['total_checks']
native={str(hz):json.loads((final/f'rendered_{hz}hz.json').read_text()) for hz in [120,60]}
assert all(r['complete'] and not r['focus_events'] and all(c['passed'] for c in r['checks']) and r['route']['transfers']==10 and r['route']['recoveries']==0 for r in native.values())
ui=json.loads((root/'builds/v06_ui_final.json').read_text())
assert ui['distant_flag_off'] and ui['other_new_flags_off'] and ui['hud_matches_viewport'] and ui['posture_variant']==0
errors,_=json.JSONDecoder().raw_decode((root/'builds/v06_editor_errors.json').read_text(encoding='utf-8'))
assert errors['count']==0
smoke=(root/'builds/smoke_export.log').read_text(encoding='utf-8')
assert '3 frames at 60 FPS' in smoke and 'SCRIPT ERROR:' not in smoke
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
legacy=sha(Path(r'E:\Godot Games\janga_proto\runtime\physics_grabber.gd'))
assert legacy=='8ab923ac1d903e8dcc8ed2a2e4f9f8c5cec326a3217cb4a9d8f00036557e7dad'
exe=root/'builds/GripUp-v0.6.exe'
source={}
for path in sorted((root/'features/grip_up').rglob('*')):
    if path.suffix not in ['.gd','.tscn','.glb']:continue
    relative=path.relative_to(root)
    assert sha(path)==sha(dest/relative),relative
    source[str(relative).replace('\\','/')]=sha(path)
assert sha(exe)==sha(dest/'builds'/exe.name)
report={
 'revision':'v0.6 out-of-reach held target selection',
 'recorded_utc':datetime.now(timezone.utc).isoformat(),
 'engine':'Godot4.7.2 / Jolt','default_hz':120,
 'automated_checks':aggregate['total_checks'],'suite_runs':len(aggregate['suites']),'automated_failures':0,
 'native_scripted_checks':sum(len(r['checks']) for r in native.values()),'native_scripted_failures':0,
 'native_route_transfers':{hz:r['route']['transfers'] for hz,r in native.items()},
 'native_early_route_selections':{hz:r['early_selections'] for hz,r in native.items()},
 'native_provenance':'Godot MCP Pro scripted input; not a human pilot',
 'initial_native_failures_preserved':'docs/validation/v06_native_initial',
 'final_editor_errors_or_warnings':errors['count'],'earlier_mcp_transport_errors':'Two malformed JSON requests from shell quoting, archived separately; corrected structured request and fresh session pass',
 'export_smoke_frames':3,'exe_name':exe.name,'exe_sha256':sha(exe),'e_copy_matches':True,
 'legacy_grabber_unchanged_sha256':legacy,
 'defaults':{'input_profile':2,'independent_aim_profile':3,'posture_policy':'B','posture_variant':0,'allow_out_of_reach_grip_targets':False,'predictive_grip':False,'physical_feet':False,'experimental_launch':False,'transfer_assist':False,'reach_advisory':False,'catch_buffer':False},
 'budgets':{'mass_kg':12,'shared_hands_n':360,'assist_nm':20,'resultant_nm':150,'anatomical_reach_m':.65708,'rest_target_range_m':[.18,.62],'pending_relative_gesture_m_s':4},
 'human_gate_complete':False,
 'recoverable_refs':{'pre_v06':'dac5f6d','m0':'fb56d1f','m1':'6e17fe6','m2':'3246da6','m3':'3e05022'},
 'decision':'KEEP as opt-in; preserve OFF baseline; comparative human acceptance pending',
 'system_report':'docs/reports/SISTEMA_IMPLEMENTADO_V06_PT.md',
 'source_sha256':source
}
for target in [root/'builds/verification.json',final/'verification.json']:
    target.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
for name,target in [('v06_ui_final.json','ui_final.json'),('v06_controls_final.png','controls_final.png'),('export00000002.png','export_smoke.png')]:
    shutil.copy2(root/'builds'/name,final/target)
(final/'editor_errors.json').write_text(json.dumps(errors,indent=2)+'\n',encoding='utf-8')
(final/'export_smoke.txt').write_text(smoke.replace('\r','').rstrip()+'\n',encoding='utf-8')
print('Verified',report['automated_checks'],'automated +',report['native_scripted_checks'],'native checks; source/build copies match; human comparison pending')
