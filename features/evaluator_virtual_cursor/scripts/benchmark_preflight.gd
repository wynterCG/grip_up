extends SceneTree
const Probe=preload("res://features/evaluator_virtual_cursor/scripts/projection_probe.gd")
const Camera=preload("res://features/grip_up/scripts/climbing_camera.gd")
class Clock extends Node:
	signal sample(delta:float)
	func _physics_process(delta:float)->void:sample.emit(delta)
class Surface extends Node:
	var camera:Camera3D
func _initialize()->void:run.call_deferred()
func run()->void:
	var args:Array=OS.get_cmdline_user_args();var output:="";var hz:=120
	for i in args.size()-1:
		if args[i]=="--output":output=args[i+1]
		if args[i]=="--hz":hz=int(args[i+1])
	if output.is_empty() or hz not in [60,120]:quit(2);return
	var result:Dictionary={"scope":"PREFLIGHT_ONLY_NO_GAMEPLAY_BODIES_NO_TASK_OUTCOME","gameplay_bodies_created":0,"requested_hz":hz,"engine":Engine.get_version_info(),"binary_sha256":FileAccess.get_sha256(OS.get_executable_path()),"actual_size":[root.size.x,root.size.y],"window_position":[root.position.x,root.position.y],"screen":root.current_screen,"window_mode":root.mode,"status":"ENVIRONMENT_NOT_COMPARABLE","reason":"BACKING_SIZE"}
	if root.size==Vector2i(1024,576) and root.get_visible_rect().size==Vector2(1920,1080):
		Engine.physics_ticks_per_second=hz
		var clock:=Clock.new();root.add_child(clock)
		var samples:Array=[];var streak:=0;var started:int=Time.get_ticks_msec()
		while samples.size()<120 and Time.get_ticks_msec()-started<5000:
			var delta:float=await clock.sample
			samples.append(delta);streak=streak+1 if absf(delta-1.0/hz)<.0000001 else 0
			if streak>=2:break
		result["clock_samples"]=samples
		if streak>=2:
			var app:=Surface.new();root.add_child(app);app.camera=Camera.new();app.add_child(app.camera)
			result["environment"]=Probe.environment(app)
			result["provider_state"]="DISABLED_NO_GAMEPLAY_WORLD"
			result["v0_runtime_proof"]="REQUIRED_IN_EACH_BQ2_REFERENCE_RUN_NOT_CLAIMED_BY_PREFLIGHT"
			result.status="PREFLIGHT_PASS";result.reason=""
		else:result.reason="CLOCK_NOT_SETTLED"
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"",true,true));file.close()
	quit(0 if result.status=="PREFLIGHT_PASS" else 1)
