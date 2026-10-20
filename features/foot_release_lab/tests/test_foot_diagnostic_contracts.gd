extends SceneTree
## Observer lifecycle and ownership contracts; no synthetic climbing anchors.
const Lab=preload("res://features/grip_up/scripts/grip_up_lab.gd")
var checks:=0
var failures:=0
var app:Node

func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+message)

func _initialize()->void:
	Engine.physics_ticks_per_second=60 if OS.get_cmdline_user_args().has("--60hz") else 120
	run.call_deferred()

func ticks(count:int)->void:
	for index in count:
		await physics_frame
		await process_frame

func run()->void:
	app=Lab.new();root.add_child(app);current_scene=app
	await ticks(3)
	check(not app.has_node("FootDiagnostics"),"normal startup has no diagnostic observer")
	check(app.input_profile==2 and not app.physical_feet_enabled and app.movement_allocation==0,"normal input and foot defaults preserved")
	check(app.replay_input_provider==null and app.input_frame.data().source_kind=="LIVE","normal startup remains live input")
	app._open_foot_diagnosis()
	await ticks(4)
	var observer:Node=app.get_node("FootDiagnostics")
	check(observer.recording and observer.rows>0,"explicit diagnostic starts recording")
	check(app.input_profile==4 and app.hold_mode and app.physical_feet_enabled,"diagnostic opens hold-to-grip First Ascent B1")
	check(app.movement_allocation==0 and not app.intent_aware_feet_enabled,"diagnostic forces controlled A0/B1 without B2")
	check(app.torso.mass==12 and is_equal_approx(app.controller.get_max_reach(),.65708),"body mass and reach preserved")
	var setup:Dictionary=observer.setup_receipt()
	check(setup.foot_values.total_N==180 and setup.foot_values.per_foot_N==120,"existing foot caps preserved")
	check(observer._latest.phase=="POST_CONTROL_BEFORE_NEXT_INTEGRATION","physics sample phase is explicit")
	check(observer._latest.native.has("status"),"native contact availability is explicitly typed")
	check(observer._latest.feet.all(func(f):return f.reaction_observation.begins_with("DERIVED_")),"reaction estimate is not mislabelled an independent sensor")
	check(observer._latest.render_clock.same_physics_tick_claimed==false if observer._latest.render_clock.has("same_physics_tick_claimed") else observer._latest.render_sample_status.begins_with("UNKNOWN"),"visual observations use separate clocks or UNKNOWN")
	check(observer._marker_root.find_children("*","PhysicsBody3D",true,false).is_empty(),"diagnostic markers have no physics bodies")
	var panel:Control=observer._panel
	app._set_physical_feet(false)
	await ticks(3)
	check(observer._latest.feet.all(func(f):return Vector3(f.actual_applied_force_N)==Vector3.ZERO),"feet OFF always reports zero effective foot force")
	var original:String=observer.output_dir
	var receipt:Dictionary=observer.stop_recording()
	check(receipt.ticks>0 and not observer.recording,"stop flushes a receipt and closes recording")
	check(FileAccess.file_exists(original.path_join("physics.jsonl")) and FileAccess.file_exists(original.path_join("receipt.json")),"trace and receipt exist")
	observer.start_recording()
	check(observer.output_dir!=original,"restarting allocates a unique take without overwriting raw evidence")
	await ticks(2)
	observer.free()
	await process_frame
	check(not is_instance_valid(panel) and not app.has_node("FootDiagnostics"),"observer and HUD cleanly detach")
	check(not app.physical_feet_enabled and app.replay_input_provider==null,"observer cleanup does not seize feet or input ownership")
	app.queue_free();await process_frame
	print("RESULTS: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
