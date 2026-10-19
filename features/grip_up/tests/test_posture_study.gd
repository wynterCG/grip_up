extends "res://features/grip_up/tests/test_drag_swing_physics.gd"
## P0/P1 same-geometry study. Initial fixture motion is the only velocity write.
var report: Dictionary = {"runs":[]}

func settings(variant: int) -> void:
	controller.transfer_diagnostics_enabled = true
	controller.transfer_assist_enabled = variant==1
	controller.set_posture_variant(variant)
	controller.set_posture_policy(0)

func candidate() -> Dictionary:
	var point: Vector3 = controller.hands[0].anchor.world_point()+Vector3(.3838,.12,0)
	var target := StaticBody3D.new()
	target.collision_layer = 2
	target.collision_mask = 0
	target.position = point-Vector3.BACK*.025
	var shape := SphereShape3D.new()
	shape.radius = .025
	var collision := CollisionShape3D.new()
	collision.shape = shape
	target.add_child(collision)
	world.add_child(target)
	return {"support":target,"point":point,"normal":Vector3.BACK}

func trial(variant: int, mode: String, dual := false) -> Dictionary:
	var moving := mode in ["moving","transitions"]
	var rotation := Vector3(0,0,.35) if mode=="roll" else Vector3.ZERO
	await setup(dual,rotation,moving,3,dual and moving)
	settings(variant)
	var target := candidate()
	await ticks(2)
	if moving:
		# Initial stored kinetic energy, not an actuation added by the controller.
		supports[0].angular_velocity = Vector3(0,.7,0)
		supports[0].linear_velocity = Vector3(.08,0,0)
	var initial_momentum := momentum() if moving else {}
	var duration := 3.0 if moving else 6.0
	var result := {"variant":variant,"mode":mode,"dual":dual,"retained":true,"twist_rms":0.0,"support_twist_rms":0.0,
		"tilt_rms":0.0,"jitter_rms":0.0,"torque_slew_peak":0.0,"force_peak":0.0,"assist_peak":0.0,
		"pendulum_peak":0.0,"pendulum_peaks":[],"pendulum_periods":[],"free_window_total":0.0,"free_window_longest":0.0,
		"first_window":-1.0,"minimum_reach_distance":INF,"hand_time_lower_bound_min":INF,"travel_speed_peak":0.0,
		"arm_work":0.0,"moment_work":0.0,"saturation_time":0.0}
	result["frame_rate_peak"] = 0.0
	var spin_filtered := body.angular_velocity
	var previous_reference := Vector3.RIGHT
	var prior_torque: Vector3 = controller.telemetry().assist_torque
	var prior_angle := 0.0
	var prior_slope := 0.0
	var last_peak_time := -1.0
	var window := 0.0
	var count := 0
	var support_count := 0
	for frame in int(duration*hz):
		var time := float(frame)/hz
		if mode=="pump":
			controller.set_swing_intent(Vector3.RIGHT if fmod(time,1.2)<.6 else Vector3.LEFT,Vector3.RIGHT)
		elif mode=="brake":
			var lever: Vector3 = controller.get_shoulder_world(0)-body.global_position
			var drive_axis := Vector3.RIGHT.cross(lever.normalized()).normalized()
			var phase_speed := body.angular_velocity.dot(drive_axis)
			controller.set_swing_intent((Vector3.LEFT if phase_speed>0 else Vector3.RIGHT) if absf(phase_speed)>.05 else Vector3.ZERO,Vector3.RIGHT)
		if mode=="transitions" and frame==hz:
			controller.release_grip(1,"study_release")
		await tick()
		var data: Dictionary = controller.telemetry()
		var reference: Vector3 = data.transfer_posture.twist.get("reference_right",Vector3.RIGHT)
		result.frame_rate_peak = maxf(result.frame_rate_peak,previous_reference.angle_to(reference)*hz)
		previous_reference = reference
		var motion: Dictionary = controller.transfer_diagnostics().motion
		var theta: float = motion.pendulum_angle
		result.pendulum_peak = maxf(result.pendulum_peak,theta)
		var slope := theta-prior_angle
		if slope*prior_slope<0 and prior_slope>0 and time-last_peak_time>.25:
			result.pendulum_peaks.append(prior_angle)
			if last_peak_time>=0:
				result.pendulum_periods.append(time-last_peak_time)
			last_peak_time = time
		prior_angle = theta
		prior_slope = slope
		var response := 1.0-exp(-1.0/hz/.08)
		spin_filtered = spin_filtered.lerp(body.angular_velocity,response)
		result.jitter_rms += body.angular_velocity.distance_squared_to(spin_filtered)
		result.twist_rms += motion.trunk_twist*motion.trunk_twist
		result.tilt_rms += motion.trunk_tilt*motion.trunk_tilt
		if moving and time>.5:
			var axis: Vector3 = motion.trunk_axis
			var actual_right := body.global_basis.x.slide(axis)
			var support_right := supports[0].global_basis.x.slide(axis)
			if actual_right.length_squared()>.000001 and support_right.length_squared()>.000001:
				var relative_error := actual_right.normalized().signed_angle_to(support_right.normalized(),axis)
				result.support_twist_rms += relative_error*relative_error
				support_count += 1
		result.torque_slew_peak = maxf(result.torque_slew_peak,Vector3(data.assist_torque).distance_to(prior_torque)*hz)
		prior_torque = data.assist_torque
		result.force_peak = maxf(result.force_peak,data.total_force)
		result.assist_peak = maxf(result.assist_peak,Vector3(data.assist_torque).length())
		result.saturation_time += 1.0/hz if data.budget_scale<.999 else 0.0
		result.travel_speed_peak = maxf(result.travel_speed_peak,body.linear_velocity.length())
		result.arm_work = motion.estimated_arm_work
		result.moment_work = motion.estimated_grip_moment_work
		var distance: float = controller.get_shoulder_world(1).distance_to(target.point)
		result.minimum_reach_distance = minf(result.minimum_reach_distance,distance)
		if distance<controller.get_max_reach()-.005 and controller._accessible(controller.get_shoulder_world(1),target.point,target.normal,target.support):
			if result.first_window<0:
				result.first_window = time
			window += 1.0/hz
			result.free_window_total += 1.0/hz
			result.free_window_longest = maxf(result.free_window_longest,window)
			result.hand_time_lower_bound_min = minf(result.hand_time_lower_bound_min,controller.get_hand_world(1).distance_to(target.point)/4.0)
		else:
			window = 0.0
		result.retained = result.retained and controller.get_hand_state(0)=="ATTACHED"
		count += 1
	for key in ["twist_rms","tilt_rms","jitter_rms"]:
		result[key] = sqrt(float(result[key])/maxi(1,count))
	result.support_twist_rms = sqrt(float(result.support_twist_rms)/maxi(1,support_count))
	result["jitter_filter_tau"] = .08
	result["jitter_scope"] = "high_pass_proxy_including_motion_harmonics_not_proof_of_solver_chatter"
	if not is_finite(result.hand_time_lower_bound_min):
		result.hand_time_lower_bound_min = -1.0
	if result.pendulum_peaks.size()>=3:
		result["third_to_first_peak"] = result.pendulum_peaks[2]/maxf(.0001,result.pendulum_peaks[0])
	if moving:
		var final_momentum := momentum()
		result["twist_controller"] = controller.telemetry().transfer_posture.twist
		result["support_rotation"] = str(supports[0].global_rotation)
		result["linear_momentum_delta"] = Vector3(final_momentum.linear).distance_to(initial_momentum.linear)
		result["angular_momentum_delta"] = Vector3(final_momentum.angular).distance_to(initial_momentum.angular)
		check(result.linear_momentum_delta<.001 and result.angular_momentum_delta<.01,"closed moving support keeps paired linear/angular momentum P%d %s" % [variant,mode])
	check(result.retained and result.force_peak<=360.001 and result.assist_peak<=20.001,"P%d %s preserves attachment and unchanged effort caps" % [variant,mode])
	check(result.frame_rate_peak<=2.5+.002,"P%d %s material heading transport obeys2.5rad/s target rate" % [variant,mode])
	print("POSTURE STUDY ",JSON.stringify(result))
	report.runs.append(result)
	await clear()
	return result

func transitions_and_guard() -> void:
	await setup(true,Vector3.ZERO,true,3,true)
	settings(0)
	var pose := body.global_transform
	var velocity := body.linear_velocity
	var spin := body.angular_velocity
	controller.transfer_assist_enabled = true
	controller.set_posture_variant(1)
	check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"variant and enable setters preserve exact instantaneous physical state")
	var previous := 0.0
	var continuous := true
	for frame in hz/3:
		await tick()
		var blend: float = controller.telemetry().transfer_posture.twist.get("blend",0.0)
		continuous = continuous and blend-previous<=1.0/hz/.20+.00001
		previous = blend
	check(continuous and previous==1.0,"P1 activation ramps over existing bounded experimental interval")
	controller.transfer_assist_enabled = false
	await ticks(hz/3)
	check(controller.telemetry().transfer_posture.status=="P0" and controller._twist_refinement.blend==0.0,"deactivation returns to exact baseline after explicit blend-out")
	controller.transfer_assist_enabled = true
	controller.set_posture_variant(2)
	await ticks(3)
	check(not controller.telemetry().transfer_posture.available and controller.telemetry().transfer_posture.status=="P2_NOT_IMPLEMENTED","unapproved P2 is visible and cannot silently enable another assistance")
	controller.set_control_profile(0)
	controller.set_posture_variant(1)
	await ticks(3)
	check(controller._twist_refinement.blend==0 and not controller.telemetry().has("transfer_posture"),"legacy profiles ignore experimental posture assistance")
	controller.set_control_profile(3)
	for hand in 2:
		controller.release_grip(hand)
	controller.set_swing_intent(Vector3.RIGHT,Vector3.RIGHT)
	await ticks(3)
	check(controller.telemetry().assist_torque==Vector3.ZERO and controller._twist_refinement.blend==0,"unsupported body receives no refinement or swing torque")
	await clear()

func finite_handoff() -> void:
	await setup(false,Vector3.ZERO,true,3,true)
	settings(1)
	await ticks(hz/3)
	var survivor: float = controller.hands[0].rest_length
	var frame_before: Vector3 = controller._twist_refinement.reference_right
	var pose := body.global_transform
	var velocity := body.linear_velocity
	var spin := body.angular_velocity
	controller.set_contextual_effort(Vector2.ONE,Vector3.FORWARD)
	controller.set_climb_intent(1,1,1,Vector3.FORWARD)
	controller.set_swing_intent(Vector3.ZERO,Vector3.FORWARD)
	check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin and controller._twist_refinement.reference_right==frame_before,"camera/pointer-only setter traffic does not reset material posture frame or inject physical state")
	var point: Vector3 = supports[0].to_global(Vector3(.1919,-.025,0))
	var accepted: bool = controller.request_grip(1,supports[0],point,supports[0].global_basis*Vector3.DOWN)
	for frame in hz:
		await tick()
		if controller.get_hand_state(1)=="ATTACHED":
			break
	check(accepted and controller.get_hand_state(1)=="ATTACHED" and controller.hands[0].rest_length==survivor,"P1 finite1→2 handoff preserves surviving actuator target")
	await ticks(hz/4)
	pose = body.global_transform
	velocity = body.linear_velocity
	spin = body.angular_velocity
	controller.release_grip(1,"study_release")
	check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin and controller.hands[0].rest_length==survivor,"P1 two→one release preserves exact instantaneous momentum and survivor target")
	await ticks(hz/4)
	check(controller.get_hand_state(0)=="ATTACHED" and controller._twist_refinement.blend==1.0,"material reference survives1→2→1 without losing valid support")
	await clear()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	report.physics_hz = hz
	report.baseline_commit = "db6ea96"
	var neutral: Array[Dictionary] = []
	var moving: Array[Dictionary] = []
	for variant in [0,1]:
		neutral.append(await trial(variant,"neutral"))
		await trial(variant,"roll")
		await trial(variant,"pump")
		await trial(variant,"brake")
		moving.append(await trial(variant,"moving"))
		await trial(variant,"transitions",true)
	check(absf(neutral[0].pendulum_peak-neutral[1].pendulum_peak)<.01 and absf(neutral[0].free_window_total-neutral[1].free_window_total)<.1,"fixed-support P1 retains P0 pendulum and free-shoulder window without changing planner")
	check(moving[1].support_twist_rms<moving[0].support_twist_rms*.8,"P1 measurably reduces actual support-relative axial twist on rotating support")
	await transitions_and_guard()
	await finite_handoff()
	check(budgets,"all P0/P1 study trials retain360N20Nm150Nm")
	FileAccess.open("res://builds/posture_study_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("POSTURE STUDY RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
