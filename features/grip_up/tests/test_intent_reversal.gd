extends "res://features/grip_up/tests/test_drag_swing_physics.gd"
## Matched v0.7 serial-ramp control and revised profile4. No fixture body writes
## occur after inherited initialization; every catch and effort is physical.
class SerialRampControl:
	extends "res://features/grip_up/scripts/intent_locomotion_coordinator.gd"
	func step(owner_controller: Node, delta: float, enabled: bool) -> void:
		super.step(owner_controller,delta,enabled)
		# Exact historical v0.7 swing request; everything else stays identical.
		var slipping: bool = owner_controller.hands.any(func(hand):return hand.state=="SLIPPING")
		swing = Vector3(data.movement_intent_world)*float(data.recommended_climb_share) if enabled and not data.actual_hand_ids.is_empty() and not slipping else Vector3.ZERO

var baseline_only := false
var report: Dictionary = {"runs":[]}

func prepare(serial: bool, dynamic: bool = false) -> void:
	await setup(false,Vector3.ZERO,dynamic,4)
	if serial:controller.intent_locomotion = SerialRampControl.new()
	controller.intent_climb_enabled = true
	controller.transfer_diagnostics_enabled = true

func sample(command: Vector2, camera := Vector3.RIGHT) -> Dictionary:
	controller.set_traversal_input(command,camera)
	await controller.sample_ready
	var data: Dictionary = controller.telemetry()
	budgets = budgets and data.total_force<=360.001 and Vector3(data.assist_torque).length()<=20.001 and Vector3(data.torque).length()<=150.001
	return data

func one_reversal(serial: bool, reverse: bool = true) -> Dictionary:
	await prepare(serial)
	var start_trace: Array = []
	for index in int(.60*hz):
		var data: Dictionary = await sample(Vector2(1,0))
		start_trace.append({"position":data.torso_position,"velocity":data.linear_velocity,"force":data.total_force,"torque":data.assist_torque,"rest":data.hands[0].rest_length})
	var before: Dictionary = controller.telemetry()
	var press: float = controller.simulation_time
	var first_counter := -1.0
	var wrong_impulse := 0.0
	var work := 0.0
	var phases := {"PUMPING":0,"BRAKING":0,"NEUTRAL":0}
	var snapshots: Array = []
	var retained := true
	var zero_command := not reverse
	for index in int(.50*hz):
		var data: Dictionary = await sample(Vector2(-1,0) if reverse else Vector2.ZERO)
		var motion: Dictionary = controller.transfer_diagnostics().motion
		var lever: Vector3 = controller.get_shoulder_world(0)-body.global_position
		var new_axis := Vector3.LEFT.cross(lever.normalized()).normalized()
		var along_counter: float = Vector3(data.swing_torque).dot(new_axis)
		if along_counter>.05 and first_counter<0:first_counter = controller.simulation_time-press
		if index<int(.25*hz):wrong_impulse += maxf(0.0,-along_counter)/hz
		work += float(motion.swing_power)/hz
		phases[motion.swing_phase] += 1
		retained = retained and controller.get_hand_state(0)=="ATTACHED"
		snapshots.append({"time":controller.simulation_time-press,"torque":data.swing_torque,"counter_axis_torque":along_counter,"power":motion.swing_power,"intent":data.intent_locomotion.movement_intent_local})
	var neutral_trace: Array = []
	for index in int(.8*hz):
		var data: Dictionary = await sample(Vector2.ZERO)
		neutral_trace.append({"swing":data.swing_torque,"velocity":data.linear_velocity,"rest":data.hands[0].rest_length})
	var result := {"serial_control":serial,"mode":"reverse" if reverse else "release_only","latency":first_counter,"wrong_direction_impulse_first250ms":wrong_impulse,
		"swing_work_first500ms":work,"retained":retained,"phases":phases,"before_spin":before.angular_velocity,"before_velocity":before.linear_velocity,
		"start_trace":start_trace,"neutral_trace":neutral_trace,"samples":snapshots,"zero_command":zero_command}
	check(retained and budgets,"%s %s uses actual retained grip and unchanged360/20/150 budgets" % ["serial" if serial else "candidate",result.mode])
	report.runs.append(result)
	print("REVERSAL_MEASURE ",JSON.stringify({"serial":serial,"mode":result.mode,"latency":first_counter,"wrong_impulse":wrong_impulse,"work":work,"retained":retained}))
	await clear()
	return result

func phase_brake(serial: bool) -> Dictionary:
	await prepare(serial)
	var work := 0.0
	var positive := 0
	var negative := 0
	var peak_energy := 0.0
	var retained := true
	for index in int(5.0*hz):
		var lever: Vector3 = controller.get_shoulder_world(0)-body.global_position
		var axis := Vector3.RIGHT.cross(lever.normalized()).normalized()
		var phase: float = body.angular_velocity.dot(axis)
		var command := -signf(phase) if absf(phase)>.03 else 0.0
		await sample(Vector2(command,0))
		var motion: Dictionary = controller.transfer_diagnostics().motion
		work += float(motion.swing_power)/hz
		positive += int(motion.swing_power>.01)
		negative += int(motion.swing_power<-.01)
		peak_energy = maxf(peak_energy,float(motion.relative_translation_energy)+float(motion.relative_rotation_energy))
		retained = retained and controller.get_hand_state(0)=="ATTACHED"
	var result := {"mode":"reactive_phase_brake","serial_control":serial,"work":work,"energy_peak":peak_energy,"positive_samples":positive,"negative_samples":negative,"retained":retained,"anticipation_seconds":0.0}
	check(retained and budgets,"reactive brake serial%s preserves real support and capacity" % serial)
	report.runs.append(result)
	print("REVERSAL_PHASE ",JSON.stringify(result))
	await clear()
	return result

func safety_and_reaction() -> void:
	await prepare(false)
	for index in int(.4*hz):await sample(Vector2(1,0))
	for index in int(.1*hz):await sample(Vector2(-1,0))
	var no_resurrection := true
	for index in int(.4*hz):
		var data: Dictionary = await sample(Vector2.ZERO)
		no_resurrection = no_resurrection and Vector3(data.intent_locomotion.swing_request_world)==Vector3.ZERO
	check(no_resurrection,"releasing a brief opposite gesture requests ZERO instead of resurrecting old-sign traversal tail")
	controller.release_grip(0)
	var before_velocity := body.linear_velocity
	for index in 4:
		var data: Dictionary = await sample(Vector2(-1,0))
		check(data.total_force==0 and data.assist_torque==Vector3.ZERO,"support loss removes reversed intent force and moment on every unsupported tick")
	check(absf(body.linear_velocity.x)<=absf(before_velocity.x)+.0001,"holding reverse after release cannot provide an airborne horizontal motor")
	await clear()
	await setup(true,Vector3.ZERO,true,4,true)
	controller.intent_climb_enabled = true
	var material: RigidBody3D = supports[0]
	var start_p: Vector3 = body.linear_velocity*body.mass+material.linear_velocity*material.mass
	var start_l: Vector3 = body.global_position.cross(body.linear_velocity*body.mass)+material.global_position.cross(material.linear_velocity*material.mass)+body.angular_velocity*3+material.angular_velocity*20
	var peak_torque := 0.0
	for sign_value in [1,-1]:
		for index in int(.4*hz):
			var data: Dictionary = await sample(Vector2(sign_value,0))
			peak_torque = maxf(peak_torque,Vector3(data.swing_torque).length())
	var final_p: Vector3 = body.linear_velocity*body.mass+material.linear_velocity*material.mass
	var final_l: Vector3 = body.global_position.cross(body.linear_velocity*body.mass)+material.global_position.cross(material.linear_velocity*material.mass)+body.angular_velocity*3+material.angular_velocity*20
	check(peak_torque>.1 and final_p.distance_to(start_p)<.001 and final_l.distance_to(start_l)<.01,"explicit reversal on shared dynamic material retains equal/opposite force and moment reactions")
	report["reaction"] = {"dp":final_p.distance_to(start_p),"dL":final_l.distance_to(start_l),"peak_swing_torque":peak_torque}
	await clear()

func run() -> void:
	baseline_only = OS.get_cmdline_user_args().has("--record-baseline")
	world = Node3D.new()
	root.add_child(world)
	var old: Dictionary = await one_reversal(true)
	var candidate: Dictionary = await one_reversal(false)
	var old_neutral: Dictionary = await one_reversal(true,false)
	var candidate_neutral: Dictionary = await one_reversal(false,false)
	check(old.start_trace==candidate.start_trace,"initial gesture trajectory/force is exactly preserved before first explicit reversal")
	check(old_neutral.start_trace==candidate_neutral.start_trace and old_neutral.neutral_trace==candidate_neutral.neutral_trace,"release-only gesture preserves complete historical neutral decay and body/arm trajectory exactly")
	var old_brake: Dictionary = await phase_brake(true)
	var new_brake: Dictionary = await phase_brake(false)
	if not baseline_only:
		check(candidate.latency>0 and candidate.latency<old.latency*.75,"explicit opposite command produces finite countereffort at least25percent sooner")
		check(candidate.wrong_direction_impulse_first250ms<old.wrong_direction_impulse_first250ms*.75,"reversal reduces wrong-way torque impulse without more maximum torque")
		check(new_brake.work<old_brake.work and new_brake.energy_peak<=old_brake.energy_peak+.05,"same no-anticipation brake policy reduces injected work without increasing peak energy")
		await safety_and_reaction()
	var filename := "res://builds/intent_reversal_baseline_%dhz.json" if baseline_only else "res://builds/intent_reversal_%dhz.json"
	FileAccess.open(filename % hz,FileAccess.WRITE).store_string(JSON.stringify({"hz":hz,"checks":checks,"failures":failures,"baseline_only":baseline_only,"report":report},"\t"))
	print("INTENT REVERSAL RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
