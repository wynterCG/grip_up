from pathlib import Path
import hashlib,json,shutil

root=Path(__file__).resolve().parents[1]
out=root/'docs/baselines/pre_v07'
out.mkdir(exist_ok=True)
files=[root/'project.godot',root/'export_presets.cfg']+sorted((root/'features/grip_up').rglob('*.gd'))
hashes={str(p.relative_to(root)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
report={'git_ref':'298b881cf190d1d6731910a3824703f56193d30e','profile':2,'v06_comparison_profile':3,'posture_policy':'B','posture_variant':'P0','distant_targets':False,'feet':False,'predictive':False,'short_buffer':False,'default_hz':120,'mass_kg':12,'hand_force_n':360,'assist_nm':20,'torso_moment_nm':150,'anatomical_reach_m':.65708,'target_range_m':[.18,.62],'gesture_m_s':4,'exe_sha256':hashlib.sha256((root/'builds/GripUp-v0.6.exe').read_bytes()).hexdigest(),'source_sha256':hashes,'human_baseline':'Designer says climbing is not interesting; macro control may make it functional. No new human ratings or arena recordings supplied.'}
(out/'configuration.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
for name in ['project.godot','export_presets.cfg']:shutil.copy2(root/name,out/name)
print('Protected v0.6 baseline',len(hashes),'source/config hashes')
