"""Fresh normal startup and release-export smoke, separate from V0 qualification."""
from pathlib import Path
import subprocess,json,sys,hashlib
ROOT=Path(__file__).resolve().parents[1];ENGINE=Path.home()/'WrapRush/tools/godot.exe'
OUT=ROOT/'builds/eval_virtual_cursor/benchmark_v133_r1/safety';OUT.mkdir(parents=True,exist_ok=True)
def run(label,command,timeout=60):
    with (OUT/f'{label}_stdout.txt').open('wb') as stdout,(OUT/f'{label}_stderr.txt').open('wb') as stderr:
        p=subprocess.Popen([str(x) for x in command],stdout=stdout,stderr=stderr,cwd=ROOT)
        try:code=p.wait(timeout=timeout)
        except subprocess.TimeoutExpired:p.kill();p.wait();code=124
    text='\n'.join((OUT/f'{label}_{s}.txt').read_text(errors='replace') for s in ['stdout','stderr'])
    result={'exit_code':code,'command':[str(x) for x in command],'script_errors':'SCRIPT ERROR:' in text or 'Parse Error:' in text}
    (OUT/f'{label}_receipt.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(label,code,'script_errors',result['script_errors'],flush=True)
    if code or result['script_errors']:raise RuntimeError(text[-3000:])
    return result
if sys.argv[1]=='startup':
    target=(OUT/'normal_runtime.json').as_posix()
    script=OUT/'normal_startup.gd'
    script.write_text('''extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	var app=load("res://features/grip_up/scenes/grip_up_lab.tscn").instantiate()
	root.add_child(app);current_scene=app
	for frame in 5:await physics_frame
	var bindings={}
	for action in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:bindings[action]=InputMap.action_get_events(action).map(func(event):return event.as_text())
	var value={"profile":app.input_profile,"allocation":app.movement_allocation,"physics_hz":Engine.physics_ticks_per_second,"hold":app.hold_mode,"physical_feet":app.physical_feet_enabled,"intent_aware_feet":app.intent_aware_feet_enabled,"observer":app.locomotion_diagnostics_enabled,"capture_recorder":app.capture_trace.enabled,"mass":app.torso.mass,"reach":app.controller.get_max_reach(),"values":[app.controller.tuning.traversal_speed_m_s,app.controller.tuning.traversal_input_ramp_s,app.controller.tuning.traversal_target_max_rate,app.controller.tuning.traversal_target_max_acceleration],"bindings":bindings}
	var safety={"provider_disabled":app.replay_input_provider==null,"arming":app.virtual_input_arming,"camera_virtual":app.camera.virtual_physics_follow,"source_kind":app.input_frame.data().source_kind}
	var file=FileAccess.open("TARGET",FileAccess.WRITE);file.store_string(JSON.stringify({"normal":value,"safety":safety}));file.close()
	quit(0 if safety.provider_disabled and not safety.arming and not safety.camera_virtual and safety.source_kind=="LIVE" else 1)
'''.replace('TARGET',target),encoding='utf-8')
    run('normal_startup',[ENGINE,'--headless','--path',ROOT,'--script',script])
    baseline=json.loads((ROOT/'docs/validation/evaluator_v132/baseline/normal_runtime.json').read_text())
    actual=json.loads((OUT/'normal_runtime.json').read_text());assert actual['normal']==baseline,(actual,baseline)
    print('Fresh default snapshot exactly equals previous baseline')
elif sys.argv[1]=='export':
    exe=OUT/'GripUp-v133-benchmark-safe.exe'
    run('export',[ENGINE,'--headless','--path',ROOT,'--export-release','Windows PC',exe],180)
    run('export_smoke',[exe,'--headless','--quit-after','180'],40)
    (OUT/'export_identity.json').write_text(json.dumps({'sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'bytes':exe.stat().st_size,'release':True,'startup_smoke_only':True}),encoding='utf-8')
elif sys.argv[1] in ['pack','inspect-pack']:
    exe=OUT/'GripUp-v133-benchmark-safe.exe';target=(OUT/'export_pack_check.json').as_posix();script=OUT/'export_pack_check.gd'
    script.write_text('''extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	var excluded={}
	for path in ["res://features/evaluator_virtual_cursor/scripts/projection_probe.gd","res://features/evaluator_virtual_cursor/scripts/replay_input_provider.gd","res://features/evaluator_virtual_cursor/scripts/virtual_cursor_driver.gd","res://features/evaluator_virtual_cursor/scripts/virtual_cursor_runner.gd","res://features/evaluator_qualification/scripts/qualification_driver.gd","res://features/auto_tuning_lab/scripts/optimization_trial_driver.gd"]:excluded[path]=not ResourceLoader.exists(path)
	for path in ["res://features/evaluator_virtual_cursor/scripts/benchmark_driver.gd","res://features/evaluator_virtual_cursor/scripts/benchmark_runner.gd","res://features/evaluator_virtual_cursor/scripts/benchmark_preflight.gd","res://features/evaluator_virtual_cursor/resources/benchmark_eval_v133.json"]:excluded[path]=not ResourceLoader.exists(path)
	var app=load("res://features/grip_up/scenes/grip_up_lab.tscn").instantiate();root.add_child(app);current_scene=app
	for frame in 5:await physics_frame
	var value={"release_template":not OS.is_debug_build(),"provider_disabled":app.replay_input_provider==null,"camera_virtual":app.camera.virtual_physics_follow,"profile":app.input_profile,"excluded":excluded}
	var file=FileAccess.open("TARGET",FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()
	quit(0 if excluded.values().all(func(x):return x) and value.provider_disabled and not value.camera_virtual and value.profile==2 else 1)
'''.replace('TARGET',target),encoding='utf-8')
    if sys.argv[1]=='pack':run('export_pack_check',[exe,'--headless','--script',script],40)
    else:
        isolated=OUT/'isolated_pack_qa';isolated.mkdir(exist_ok=True)
        run('export_pack_inspection_isolated',[ENGINE,'--headless','--path',isolated,'--main-pack',exe,'--script',script],40)
