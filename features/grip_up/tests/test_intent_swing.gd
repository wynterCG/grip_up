extends "res://features/grip_up/tests/test_drag_swing_physics.gd"
var report: Dictionary = {"runs":[]}

func swing_trial(kind: String, dual: bool = false) -> Dictionary:
	await setup(dual,Vector3.ZERO,false,4)
	controller.intent_climb_enabled = true
	controller.transfer_diagnostics_enabled = true
	var work := 0.0
	var energy_peak := 0.0
	var speed_peak := 0.0
	var late_energy := 0.0
	var middle_energy := 0.0
	var retained := true
	var positive := 0
	var negative := 0
	var duration := 12.0 if kind=="constant" else 5.0
	var heading: Vector3 = controller.telemetry().control_right
	var previous_phase := 0.0
	var filtered_acceleration := 0.0
	for index in int(duration*hz):
		var command := 0.0
		var lever: Vector3 = controller.get_shoulder_world(0)-body.global_position
		var axis := Vector3.RIGHT.cross(lever.normalized()).normalized()
		var phase: float = body.angular_velocity.dot(axis)
		filtered_acceleration = lerpf(filtered_acceleration,(phase-previous_phase)*hz,1.0-exp(-1.0/hz/.10))
		previous_phase = phase
		if kind=="pump":command = signf(phase) if absf(phase)>.03 else 1.0
		elif kind=="brake":
			# Deliberate anticipatory timing accounts for the two existing finite
			# input/effort ramps; a last-instant sign flip can pump accidentally.
			var anticipated_phase: float = phase+filtered_acceleration*.20
			command = -signf(anticipated_phase) if absf(anticipated_phase)>.12 else 0.0
		elif kind=="constant":command = 1.0
		controller.set_traversal_input(Vector2(command,0),Vector3.RIGHT.rotated(Vector3.UP,float(index)/hz))
		await tick()
		var motion: Dictionary = controller.transfer_diagnostics().motion
		work += float(motion.swing_power)/hz
		positive += int(motion.swing_power>.01)
		negative += int(motion.swing_power<-.01)
		var energy: float = motion.relative_translation_energy+motion.relative_rotation_energy
		energy_peak = maxf(energy_peak,energy)
		speed_peak = maxf(speed_peak,body.linear_velocity.length())
		if index>=8*hz and index<10*hz:middle_energy = maxf(middle_energy,energy)
		if index>=10*hz:late_energy = maxf(late_energy,energy)
		retained = retained and controller.get_hand_state(0)=="ATTACHED"
	var result := {"kind":kind,"dual":dual,"work":work,"energy_peak":energy_peak,"speed_peak":speed_peak,"late_energy":late_energy,"middle_energy":middle_energy,"positive_samples":positive,"negative_samples":negative,"retained":retained}
	check(retained and budgets,"profile4 %s dual%s retains actual support and unchanged360/20/150 caps" % [kind,dual])
	check(controller.telemetry().control_right==heading,"profile4 %s camera orbit never rotates cached physical heading" % kind)
	if kind=="constant":check(speed_peak<5.0 and late_energy<=middle_energy*1.5+.5,"twelve-second held intent has bounded speed and late energy instead of endless powered flight")
	if kind=="pump":check(work>.05 and positive>hz/2,"phase-aligned supported intention performs positive incremental swing work")
	if kind=="brake":check(work<-.01 and negative>hz/4,"opposite-phase supported intention removes swing work")
	for id in 2:controller.release_grip(id)
	await ticks(2)
	check(controller.telemetry().total_force==0 and controller.telemetry().assist_torque==Vector3.ZERO,"profile4 %s loses all propulsion on actual support release" % kind)
	print("INTENT_SWING_MEASURE ",JSON.stringify(result))
	report.runs.append(result)
	await clear()
	return result

func closed_pair() -> void:
	await setup(true,Vector3.ZERO,true,4,true)
	controller.intent_climb_enabled = true
	var material: RigidBody3D = supports[0]
	var initial_p: Vector3 = body.linear_velocity*body.mass+material.linear_velocity*material.mass
	var initial_l: Vector3 = body.global_position.cross(body.linear_velocity*body.mass)+material.global_position.cross(material.linear_velocity*material.mass)+body.angular_velocity*3+material.angular_velocity*20
	controller.set_traversal_input(Vector2(.7,.7),Vector3.RIGHT)
	var peak := 0.0
	var peak_force := 0.0
	var residual := 0.0
	var capture := func(_delta: float):
		var wrench := Vector3.ZERO
		for id in 2:
			var hand: Dictionary = controller.hands[id]
			if hand.state=="ATTACHED":wrench += (controller.get_shoulder_world(id)-Vector3(hand.anchor_world)).cross(Vector3(hand.force))
		controller.set_meta("pair_wrench_residual",maxf(float(controller.get_meta("pair_wrench_residual",0.0)),wrench.length()))
	controller.sample_ready.connect(capture)
	for index in int(.6*hz):
		await tick()
		peak = maxf(peak,Vector3(controller.telemetry().assist_torque).length())
		peak_force = maxf(peak_force,controller.telemetry().total_force)
	controller.sample_ready.disconnect(capture)
	residual = controller.get_meta("pair_wrench_residual",0.0)
	var final_p: Vector3 = body.linear_velocity*body.mass+material.linear_velocity*material.mass
	var final_l: Vector3 = body.global_position.cross(body.linear_velocity*body.mass)+material.global_position.cross(material.linear_velocity*material.mass)+body.angular_velocity*3+material.angular_velocity*20
	check(peak>.1 and peak_force>1.0,"new intent actually exercises traction and supported moment on one shared dynamic material")
	check(final_p.distance_to(initial_p)<.001 and final_l.distance_to(initial_l)<.01 and residual<.0001,"profile4 shared dynamic material receives complete opposite force and bounded moment without duplicating dual reactions")
	print("INTENT_PAIR_MEASURE ",JSON.stringify({"dp":final_p.distance_to(initial_p),"dL":final_l.distance_to(initial_l),"wrench_residual":residual,"peak_assist":peak,"peak_force":peak_force}))
	await clear()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var neutral: Dictionary = await swing_trial("neutral")
	var pump: Dictionary = await swing_trial("pump")
	var brake: Dictionary = await swing_trial("brake")
	check(pump.energy_peak>brake.energy_peak and pump.work>neutral.work,"same geometry distinguishes deliberate pump, coast and brake rather than labels alone")
	await swing_trial("constant")
	await swing_trial("constant",true)
	await closed_pair()
	FileAccess.open("res://builds/intent_swing_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("INTENT SWING RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
