"""Verify the opt-in v0.7 candidate; human acceptance remains a separate gate."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,re,shutil,subprocess,sys

root=Path(__file__).resolve().parents[1]
dest=Path(r'E:\Godot Games\grip_up')
version=sys.argv[1] if len(sys.argv)>1 else 'v07'
assert version in ['v07','v071','v072','v073','v074']
exe_name={'v07':'GripUp-v0.7.exe','v071':'GripUp-v0.7.1.exe','v072':'GripUp-v0.7.2.exe','v073':'GripUp-v0.7.3.exe','v074':'GripUp-v0.7.4.exe'}[version]
folder=root/f'docs/validation/{version}'
final=folder/'final'
aggregate=json.loads((folder/'results.json').read_text())
assert aggregate['all_passed']
for item in aggregate['suites']:
    log=(folder/f"{item['suite']}_{item['hz']}hz.txt").read_text(encoding='utf-8')
    footer=re.search(r'RESULTS: (\d+) checks, (\d+) failures',log)
    assert footer and int(footer[1])==item['checks'] and int(footer[2])==0 and item['passed']
    assert 'SCRIPT ERROR:' not in log and 'FAIL ' not in log
    if item['suite'].startswith('intent_'):assert 'ERROR:' not in log
native={str(hz):json.loads((final/f'rendered_{hz}hz.json').read_text()) for hz in [120,60]}
assert all(r['complete'] and not r['focus_events'] and all(c['passed'] for c in r['checks']) for r in native.values())
ui=json.loads((root/f'builds/{version}_ui_final.json').read_text())
assert ui['profile']==4 and ui['intent_climb_enabled'] and ui['physical_feet'] and ui['posture_variant']==0 and not ui['launch'] and ui['hud_matches_viewport']
errors,_=json.JSONDecoder().raw_decode((root/f'builds/{version}_editor_errors.json').read_text(encoding='utf-8'))
assert errors['count']==0
smoke=(root/'builds/smoke_export.log').read_text(encoding='utf-8')
assert '3 frames at 60 FPS' in smoke and 'SCRIPT ERROR:' not in smoke
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
legacy=sha(Path(r'E:\Godot Games\janga_proto\runtime\physics_grabber.gd'))
assert legacy=='8ab923ac1d903e8dcc8ed2a2e4f9f8c5cec326a3217cb4a9d8f00036557e7dad'
source={}
for p in sorted((root/'features/grip_up').rglob('*')):
    if p.suffix not in ['.gd','.tscn','.glb']:continue
    relative=p.relative_to(root)
    assert sha(p)==sha(dest/relative),relative
    source[str(relative).replace('\\','/')]=sha(p)
exe=root/'builds'/exe_name
assert sha(exe)==sha(dest/'builds'/exe.name)
lab=(root/'features/grip_up/scripts/grip_up_lab.gd').read_text(encoding='utf-8')
assert 'var input_profile := 2' in lab and 'var intent_climb_enabled := false' in lab
report={'revision':version+' intent-driven locomotion technical candidate','recorded_utc':datetime.now(timezone.utc).isoformat(),
 'source_commit':subprocess.check_output(['git','-C',str(dest),'rev-parse','HEAD'],text=True).strip(),
 'engine':'Godot4.7.2 / Jolt','default_hz':120,'comparison_hz':60,
 'automated_checks':aggregate['total_checks'],'suite_runs':len(aggregate['suites']),'automated_failures':0,
 'native_scripted_checks':sum(len(r['checks']) for r in native.values()),'native_scripted_failures':0,
 'native_provenance':'Godot MCP Pro scripted input; not human flow/comfort evaluation',
 'native_step':{hz:[{k:row[k] for k in ['feet','rise','higher_caught','hand_load_integral','foot_load_integral']} for row in run.get('steps',[])] for hz,run in native.items()},
 'editor_errors_or_warnings':errors['count'],'smoke_frames':3,
 'exe_name':exe.name,'exe_sha256':sha(exe),'e_copy_matches':True,'legacy_grabber_unchanged_sha256':legacy,
 'defaults':{'input_profile':2,'intent_climb_enabled':False,'physical_feet':False,'distant_targets':False,'posture_variant':0,'Space_experimental':False},
 'prepared_human_session':ui,
 'baseline_ref':'298b881','m0_ref':'6752c67',
 'human_gate_complete':False,'decision':'REVISE / isolated technical candidate for M5 human comparison; no default promotion',
 'conditional_milestones':{'M6_mantle':'not started; requires M5','M7_reactive_challenge':'not started; requires M5'},
 'known_limits':['Adverse hinge retention differs at60Hz','Descent can lose grip at anatomical extension','Swing braking requires timing with existing ramps','No closed combined hand+foot moving-beam test yet','Corner/ceiling usability unvalidated with people'],
 'source_sha256':source}
for p in [root/'builds/verification.json',final/'verification.json']:
    p.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
if version in ['v071','v072']:
    report['decision']='KEEP as control refinement candidate; new human comparison remains open; no default promotion'
    report['known_limits'].append('Continuous W can peak then oscillate or lose height; no monotonic climb guarantee')
    report['human_feedback_received']='Designer: muito melhor (v0.7.2 reachable contact)' if version=='v072' else 'Designer: sim está melhor (v0.7 baseline); new refinement not yet human validated'
    report['refinement_baseline_ref']='ec89ebd' if version=='v072' else 'cea4ae0'
    report['native_handoffs']={hz:run.get('second_handoff',{}) for hz,run in native.items()}
    if version=='v072':report['native_reachable_grips']={hz:run['trials'] for hz,run in native.items()}
    for target in [root/'builds/verification.json',final/'verification.json']:
        target.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
if version=='v073':
    report['decision']='KEEP as a short M5 route candidate; human route comparison remains open'
    report['human_feedback_received']='Designer: muito melhor on v0.7.2 reach; route not yet evaluated'
    report['refinement_baseline_ref']='a78ecb0'
    report['native_route']={hz:run['route'] for hz,run in native.items()}
    assert all(run['route']['completed'] for run in native.values())
    for target in [root/'builds/verification.json',final/'verification.json']:
        target.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
if version=='v074':
    report['decision']='M6 acceptance gate NOT MET; retain only as an isolated physical feasibility experiment, do not promote to approved route'
    report['human_feedback_received']='Designer: muito bom on v0.7.3 route; M6 not human evaluated'
    report['refinement_baseline_ref']='0d34607'
    report['native_mantle_capability']={hz:run['capability'] for hz,run in native.items()}
    report['mantle_acceptance_gate_met']=all(row['acceptance_gate_met'] for run in native.values() for row in run['capability'])
    assert not report['mantle_acceptance_gate_met'],'Update the decision if physical capability changes'
    report['known_limits'] += ['Traction-only arms and fixed compound calf/sole do not complete an ordinary ledge top-out','Destination occupancy is checked; no continuous collision-free mantle trajectory is certified']
    for target in [root/'builds/verification.json',final/'verification.json']:
        target.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
for source_name,target_name in [(f'{version}_ui_final.json','ui_final.json'),(f'{version}_controls_final.png','controls_final.png'),('export00000002.png','export_smoke.png')]:shutil.copy2(root/'builds'/source_name,final/target_name)
(final/'editor_errors.json').write_text(json.dumps(errors,indent=2)+'\n',encoding='utf-8')
(final/'export_smoke.txt').write_text(smoke.replace('\r','').rstrip()+'\n',encoding='utf-8')
files={str(p.relative_to(final)).replace('\\','/'):sha(p) for p in sorted(final.rglob('*')) if p.is_file() and p.name!='manifest.json'}
(final/'manifest.json').write_text(json.dumps({'provenance':'MCP scripted input and machine receipts; not human pilot','files':files},indent=2)+'\n',encoding='utf-8')
print('Verified',aggregate['total_checks'],'automated +',report['native_scripted_checks'],'scripted native checks; human gate remains open')
