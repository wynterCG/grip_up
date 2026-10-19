extends "res://features/grip_up/tests/test_capture_matrix.gd"
## v0.6 M1: remembered distant targets are not physical supports.
var report: Dictionary = {}

func distant(enabled: bool) -> void:
	await setup({"label":"static_distant","offset_y":1.30},false)
	controller.set_control_profile(3)
	controller.tuning.allow_out_of_reach_grip_targets = enabled

func static_pending() -> void:
	await distant(true)
	var pose := body.global_transform
	var velocity := body.linear_velocity
	var spin := body.angular_velocity
	var other: Dictionary = controller.hands[1].duplicate(true)
	var point: Vector3 = anchor.world_point()
	check(controller.request_held_grip(0,support,point,anchor.world_normal()),"M1 accepts a real distant material point without anatomical selection rejection")
	check(controller.get_hand_state(0)=="REACHING" and controller.pending_diagnostics(0).substate=="PENDING_OUT_OF_REACH","pending is an explicit REACHING substate, not an attached grip")
	check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"selection preserves torso pose and both velocities")
	var first: Dictionary = controller.pending_diagnostics(0)
	var max_extension := 0.0
	var finite := true
	var max_gesture := 0.0
	var max_step := 0.0
	var max_decomposition_error := 0.0
	var zero_effort := true
	var previous: Vector3 = controller.get_hand_world(0)
	for frame in int(2.0*hz):
		await tick()
		var data: Dictionary = controller.pending_diagnostics(0)
		var endpoint: Vector3 = controller.get_hand_world(0)
		max_extension = maxf(max_extension,endpoint.distance_to(controller.get_shoulder_world(0)))
		max_gesture = maxf(max_gesture,data.gesture_speed)
		max_step = maxf(max_step,endpoint.distance_to(previous))
		max_decomposition_error = maxf(max_decomposition_error,Vector3(data.world_velocity).distance_to(Vector3(data.transport_velocity)+Vector3(data.gesture_velocity)))
		# Vector3 is float32: subtracting world positions near y=3 introduces
		# ~1.1e-5 m/s roundoff at120Hz. This .1mm/s tolerance is numerical only.
		finite = finite and data.gesture_speed<=4.0001 and data.workspace_valid and endpoint.distance_to(previous)<=4.0/hz+.00001
		finite = finite and Vector3(data.world_velocity).is_equal_approx(Vector3(data.transport_velocity)+Vector3(data.gesture_velocity))
		zero_effort = zero_effort and controller.get_arm_force(0)==Vector3.ZERO and controller._attached_ids().is_empty() and controller.telemetry().total_force==0.0 and Vector3(controller.telemetry().torque)==Vector3.ZERO
		previous = endpoint
	check(controller.get_hand_state(0)=="REACHING" and controller.pending_diagnostics(0).pending_time>1.9,"held pending survives beyond both legacy .65s candidate and .15s prediction timeouts")
	print("PENDING_MOTION ",JSON.stringify({"max_gesture":max_gesture,"max_step":max_step,"decomposition_error":max_decomposition_error,"max_extension":max_extension}))
	check(finite and max_extension<=controller.get_max_reach()+.00005,"full pending path stays inside anatomy and advances no faster than4m/s relative to shoulder")
	check(max_extension>controller.get_max_reach()-.001 and controller.get_hand_world(0).distance_to(point)>.5,"hand points at full attainable extension and never snaps to distant material point")
	check(zero_effort and body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"static distant selection has exactly zero attraction, torque, load allocation or body motion")
	check(controller.hands[1].anchor==other.anchor and controller.hands[1].target_world==other.target_world and controller.hands[1].rest_length==other.rest_length and controller.get_hand_state(1)=="FREE","selecting one hand preserves the other free hand's anchor, target and actuator length")
	var copy: Dictionary = controller.pending_diagnostics(0)
	copy.local_point = Vector3.INF
	check(controller.pending_diagnostics(0).local_point==first.local_point and controller.pending_diagnostics(0).attempt_id==first.attempt_id,"diagnostics are immutable copies of one stable material target and attempt")
	controller.set_hand_held(0,false,"input_released")
	check(controller.get_hand_state(0)=="RELEASED" and controller.hands[0].anchor==null and not controller.pending_diagnostics(0).active,"button-up immediately clears pending support without waiting for physics")
	check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"cancellation preserves body pose and momentum")
	controller.set_hand_held(0,true)
	await ticks(int(1.0*hz))
	check(controller.get_hand_state(0)=="FREE" and controller.metrics.attaches==0 and controller.pending_diagnostics(0).reason=="input_released","cancelled target cannot resurrect or attach later")
	report.static = {"duration":2.0,"max_extension":max_extension,"reach":controller.get_max_reach(),"force":controller.get_arm_force(0),"attempt":first.attempt_id}
	await clear()

func legacy_off() -> void:
	await distant(false)
	check(not controller.request_held_grip(0,support,anchor.world_point(),anchor.world_normal()) and controller.last_rejection=="out_of_reach","flagOFF held API delegates unchanged legacy out-of-reach rejection")
	check(not controller.pending_diagnostics(0).active and controller.get_hand_state(0)=="FREE","flagOFF allocates no persistent target or hand state")
	await clear()
	var samples: Array[Dictionary] = []
	for held_api in [false,true]:
		await setup({"label":"legacy_valid"},false)
		controller.set_control_profile(3)
		var ok: bool = controller.request_held_grip(0,support,anchor.world_point(),anchor.world_normal()) if held_api else controller.request_grip(0,support,anchor.world_point(),anchor.world_normal())
		check(ok,"flagOFF valid request starts legacy finite reaching through API %s" % held_api)
		await ticks(int(.7*hz))
		samples.append({"pose":body.global_transform,"velocity":body.linear_velocity,"spin":body.angular_velocity,"hand":controller.hands[0].hand_world,"state":controller.get_hand_state(0),"force":controller.get_arm_force(0),"rest":controller.hands[0].rest_length,"metrics":controller.metrics.duplicate(true)})
		await clear()
	check(samples[0]==samples[1] and samples[0].state=="ATTACHED","flagOFF wrapper is exactly equivalent to direct legacy catch, force and physical trajectory")

func loaded_trial(with_pending: bool) -> Dictionary:
	await setup({"label":"supporting_left"},false)
	controller.set_control_profile(3)
	controller.set_posture_policy(0)
	controller.request_grip(0,support,anchor.world_point(),anchor.world_normal())
	await ticks(int(.5*hz))
	check(controller.get_hand_state(0)=="ATTACHED","supporting left hand is acquired through real legacy finite contact")
	var left_anchor = controller.hands[0].anchor
	var rest: float = controller.hands[0].rest_length
	# Gravity is enabled as a fixture load after acquisition. No torso pose or
	# velocity is assigned during the loaded trial.
	body.gravity_scale = 1.0
	var remote := StaticBody3D.new()
	remote.position = controller.get_shoulder_world(1)+Vector3(0,2.0,-.4)-Vector3.BACK*.05
	remote.collision_layer = 2
	remote.collision_mask = 0
	remote.set_meta("grippable",true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.4,.4,.1)
	shape.shape = box
	remote.add_child(shape)
	world.add_child(remote)
	controller.tuning.allow_out_of_reach_grip_targets = with_pending
	if with_pending:check(controller.request_held_grip(1,remote,remote.global_position+Vector3.BACK*.05,Vector3.BACK),"loaded left hand permits an independent distant right selection")
	var cap := true
	var pending_zero := true
	var peak_load := 0.0
	for frame in int(.6*hz):
		await tick()
		peak_load = maxf(peak_load,controller.get_arm_force(0).length())
		pending_zero = pending_zero and controller.get_arm_force(1)==Vector3.ZERO and controller.hands[1].allocation==0.0
		cap = cap and controller.telemetry().total_force<=360.0001 and Vector3(controller.telemetry().torque).length()<=150.0001
	check(controller.get_hand_state(0)=="ATTACHED" and controller.hands[0].anchor==left_anchor and controller.hands[0].rest_length==rest and peak_load>10.0,"left hand retains actual anchor, target length and real supporting load")
	check(pending_zero and cap,"pending right hand has zero load and does not duplicate shared strength")
	var result := {"pose":body.global_transform,"velocity":body.linear_velocity,"spin":body.angular_velocity,"force":controller.get_arm_force(0),"rest":controller.hands[0].rest_length,"peak_load":peak_load}
	if with_pending:
		controller.set_hand_held(1,false,"input_focus_lost")
		check(controller.get_hand_state(0)=="ATTACHED" and controller.hands[0].anchor==left_anchor,"right cancellation never releases or retargets the supporting left hand")
	await clear()
	return result

func lifecycle() -> void:
	for cancellation in ["flag_disabled","target_lost","ungrabbable","reset","profile"]:
		await distant(true)
		controller.request_held_grip(0,support,anchor.world_point(),anchor.world_normal())
		match cancellation:
			"flag_disabled":controller.tuning.allow_out_of_reach_grip_targets = false
			"target_lost":support.queue_free()
			"ungrabbable":support.set_meta("grippable",false)
			"reset":controller.reset_state()
			"profile":controller.set_control_profile(2)
		await ticks(3)
		check(not controller.pending_diagnostics(0).active and controller.get_hand_state(0) in ["FREE","RELEASED"] and controller.get_arm_force(0)==Vector3.ZERO,"no orphan target or ghost effort after "+cancellation)
		await clear()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	await legacy_off()
	await static_pending()
	var baseline: Dictionary = await loaded_trial(false)
	var selected: Dictionary = await loaded_trial(true)
	check(baseline==selected,"loaded one-hand body/force trajectory is exactly unchanged by an unattached remote second target")
	report.loaded_equivalence = {"baseline":baseline,"selected":selected}
	await lifecycle()
	check(no_early_force and budgets,"all observed steps preserve zero precontact arm force and360N/150Nm shared budgets")
	var file := FileAccess.open("res://builds/pending_grip_m1_%dhz.json" % hz,FileAccess.WRITE)
	file.store_string(JSON.stringify({"hz":hz,"milestone":"M1; no new-branch attachment implemented","checks":checks,"failures":failures,"report":report},"\t"))
	print("PENDING GRIP RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
