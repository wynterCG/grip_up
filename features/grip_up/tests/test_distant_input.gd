extends "res://features/grip_up/tests/test_distant_baseline.gd"
var observed:Array[Dictionary]=[]

func setup() -> void:
	await physics_frame
	app=Lab.new()
	root.add_child(app)
	current_scene=app
	app._open_transfer_lab(5)
	app._set_posture_policy(0)
	app.won=true
	await ticks(.45)
	click(0,true,app.level.transfer_points[0])
	await ticks(.5)

func clear() -> void:
	for id in 2:click(id,false,app.level.transfer_points[0])
	app.queue_free()
	await ticks(.05)

func support_trial(enabled:bool) -> Dictionary:
	await setup()
	var support=app.controller.hands[0].anchor
	var rest:float=app.controller.hands[0].rest_length
	app._set_distant_targeting(enabled)
	var point:Vector3=app.level.transfer_points[1]+Vector3(0,-.051,0)
	if enabled:
		app.pointer=app.camera.unproject_position(point)
		app._process(0)
		check(app.target_marker.material_override.albedo_color.is_equal_approx(Color("f0b85c")),"distant selectable hover is amber rather than a false invalid target")
		var pose:Transform3D=app.torso.global_transform
		var velocity:Vector3=app.torso.linear_velocity
		click(1,true,point)
		check(app.controller.get_hand_state(1)=="REACHING" and app.controller.pending_diagnostics(1).active,"actual out-of-reach RMB selects a persistent pending target")
		check(app.torso.global_transform==pose and app.torso.linear_velocity==velocity,"selection preserves exact body pose and velocity")
		var material_point:Vector3=app.controller.hands[1].anchor.local_point
		app.pointer=Vector2(90,50)
		app.camera.orbit(Vector2(70,10))
		root.size_changed.emit()
		check(app.controller.hands[1].anchor.local_point==material_point and app.controller.pending_diagnostics(1).active,"resize notification preserves held target rather than rebasing material coordinates")
		await ticks(.1)
		check(app.controller.hands[1].anchor.local_point==material_point,"pointer and camera cannot retarget latched material point")
	else:await ticks(.1)
	var valid:=true
	for frame in int(2*hz):
		await physics_frame
		valid=valid and app.controller.get_arm_force(1)==Vector3.ZERO and app.controller.hands[1].allocation==0.0
		if enabled:
			valid=valid and app.controller.get_shoulder_world(1).distance_to(app.controller.get_hand_world(1))<=app.controller.get_max_reach()+.0001
	var result:Dictionary={"enabled":enabled,"pose":app.torso.global_transform,"velocity":app.torso.linear_velocity,"spin":app.torso.angular_velocity}
	check(valid,"pending/free right hand never adds load or exceeds workspace")
	check(app.controller.get_hand_state(0)=="ATTACHED" and app.controller.hands[0].anchor==support and app.controller.hands[0].rest_length==rest,"existing supporting left anchor and target length preserved")
	if enabled:
		check(app.controller.get_hand_state(1)=="REACHING" and app.controller.pending_diagnostics(1).pending_time>2,"pending survives old650/150ms admission deadlines while held")
		app._process(0)
		check(app.pending_markers[1].visible and not app.pending_markers[0].visible,"small pending outline identifies selected hand without advertising a grip")
		var normal:Vector3=app.controller.pending_diagnostics(1).normal_world
		check(app.pending_markers[1].global_position.distance_to(app.controller.hands[1].anchor.world_point()+normal*.012)<.00001,"marker follows exact selected material point")
		click(1,false,point)
		check(not app.controller.pending_diagnostics(1).active and app.controller.get_hand_state(0)=="ATTACHED","right mouse-up cancels only right pending target immediately")
		await ticks(.4)
		check(app.controller.get_hand_state(1)=="FREE" and not app.pending_markers[1].visible,"cancelled point never attaches later and outline disappears")
	await clear()
	return result

func run() -> void:
	await setup()
	check(not app.allow_out_of_reach_grip_targets and not app.controller.tuning.allow_out_of_reach_grip_targets,"v0.6 remains opt-in and baseline flag OFF")
	await clear()
	var baseline:Dictionary=await support_trial(false)
	var pending:Dictionary=await support_trial(true)
	check(baseline.pose==pending.pose and baseline.velocity==pending.velocity and baseline.spin==pending.spin,"queued distant target has exactly zero effect on supported body trajectory")
	observed=[baseline,pending]
	for cancellation in ["ui","focus","reset","disable","profile"]:
		await setup()
		app._set_distant_targeting(true)
		click(1,true,app.level.transfer_points[1]+Vector3(0,-.051,0))
		match cancellation:
			"ui":app.settings.show()
			"focus":root.focus_exited.emit()
			"reset":app.load_test(5)
			"disable":app._set_distant_targeting(false)
			"profile":app._set_input_profile(1)
		await ticks(.05)
		check(not app.controller.pending_diagnostics(1).get("active",false) and app.controller.get_hand_state(1) in ["FREE","RELEASED"],"no stale pending target after "+cancellation)
		await clear()
	await setup()
	app._set_distant_targeting(true)
	click(1,true,app.level.transfer_points[1]+Vector3(0,-.051,0))
	click(0,false,app.level.transfer_points[0])
	check(app.controller.get_hand_state(0)=="RELEASED" and app.controller.pending_diagnostics(1).active,"releasing legacy-acquired left grip preserves pending right")
	await clear()
	await setup()
	app._set_distant_targeting(true)
	app._set_catch_buffer(true)
	app._set_predictive_grip(true)
	click(1,true,app.level.transfer_points[1]+Vector3(0,-.051,0))
	check(app.controller.pending_diagnostics(1).active and not app.controller.hands[1].get("predictive_wait",false),"explicit distant mode takes priority over legacy and short-buffer admission")
	await ticks(.25)
	check(app.controller.pending_diagnostics(1).active,"short buffer settings cannot expire persistent distant selection")
	app._set_distant_targeting(false)
	check(not app.controller.pending_diagnostics(1).active and app.controller.tuning.predictive_grip,"disabling distant mode cancels its intent while preserving explicit legacy comparison flag")
	await clear()
	app=Lab.new()
	app.input_profile=3
	root.add_child(app)
	current_scene=app
	app.load_test(3)
	app.won=true
	await ticks(.5)
	app._set_distant_targeting(true)
	click(1,true,Vector3(.2,3.5,0))
	check(app.controller.pending_diagnostics(1).get("active",false) and not app.ground_motor.has_climbing_intent(),"pending hand does not count as climbing support or disable ground motor")
	Input.action_press("bias_right")
	await ticks(.15)
	check(app.ground_motor.grounded and app.ground_motor.applied_force.length()>0 and app.controller.telemetry().total_force==0,"existing third-person ground walking continues with distant intention held")
	Input.action_release("bias_right")
	click(1,false,Vector3(.2,3.5,0))
	app.queue_free()
	await ticks(.05)
	FileAccess.open("res://builds/distant_input_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify({"hz":hz,"body_equivalence":observed,"checks":checks,"failures":failures},"\t"))
	print("DISTANT INPUT RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
