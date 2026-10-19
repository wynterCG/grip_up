extends "res://features/grip_up/tests/test_capture_matrix.gd"
const Frame = preload("res://features/grip_up/scripts/locomotion_support_frame.gd")
var report: Dictionary = {"trials":[]}

func frames() -> void:
	var sampler = Frame.new()
	var material := StaticBody3D.new()
	world.add_child(material)
	var inputs := [Vector3.BACK,Vector3.DOWN,Vector3(0,-.7,.7).normalized(),Vector3.RIGHT]
	for normal in inputs:
		var contacts: Array[Dictionary] = [{"id":material.get_instance_id(),"normal":normal,"weight":1.0,"support":material}]
		var data: Dictionary = sampler.update(contacts,Vector3.RIGHT,1.0/hz)
		check(Vector3(data.up).is_finite() and Vector3(data.right).is_finite() and absf(Vector3(data.up).dot(data.normal))<.0001,"wall/ceiling/overhang/corner frame is finite and tangent: %s" % normal)
	var opposed: Array[Dictionary] = [{"id":1,"normal":Vector3.RIGHT,"weight":1.0,"support":material},{"id":2,"normal":Vector3.LEFT,"weight":1.0,"support":material}]
	check(sampler.update(opposed,Vector3.RIGHT,.1).quality.begins_with("DOMINANT"),"opposing support normals use actual dominant material instead of normalizing zero")
	sampler.reset()
	var wall: Array[Dictionary] = [{"id":1,"normal":Vector3.BACK,"weight":1.0,"support":material}]
	var previous: Vector3 = sampler.update(wall,Vector3.RIGHT,.1).right
	var unchanged := true
	for index in 36:
		var orbit := Basis(Vector3.UP,index*TAU/36.0)*Vector3.RIGHT
		unchanged = unchanged and Vector3(sampler.update(wall,orbit,1.0/hz).right).distance_to(previous)<.000001
	check(unchanged,"camera-only full orbit never changes existing supported movement frame")
	var mixed: Array[Dictionary] = [{"id":1,"normal":Vector3.BACK,"weight":.05,"support":material,"kind":"hand"},{"id":2,"normal":Vector3.UP,"weight":100.0,"support":material,"kind":"foot"}]
	var stable := true
	for index in hz:
		var data: Dictionary = sampler.update(mixed,Vector3.RIGHT,1.0/hz)
		stable = stable and Vector3(data.up).distance_to(Vector3.UP)<.00001 and Vector3(data.normal).distance_to(Vector3.BACK)<.00001 and data.support_ids.has(2)
	check(stable,"a loaded upward-bearing foot cannot rotate W into the wall; it remains recorded as an actual support")
	material.queue_free()
	await ticks(2)

func acquire(two: bool = false, moving: bool = false, heavy: bool = false) -> void:
	await setup({"label":"intent_trial","offset_y":.40,"moving":moving},false)
	controller.set_control_profile(4)
	controller.intent_climb_enabled = true
	if moving:
		support.mass = 15.0
		support.center_of_mass = Vector3(-.6,0,0)
		var frame := StaticBody3D.new()
		world.add_child(frame)
		var hinge := HingeJoint3D.new()
		hinge.position = support.global_position+Vector3(-.6,0,0)
		world.add_child(hinge)
		hinge.node_a = hinge.get_path_to(frame)
		hinge.node_b = hinge.get_path_to(support)
		hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT,true)
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER,-.6)
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER,.2)
	controller.request_grip(0,support,anchor.world_point(),Vector3.BACK)
	if two:
		var point: Vector3 = controller.get_shoulder_world(1)+Vector3(0,.40,-.35)
		controller.request_grip(1,support,point,Vector3.BACK)
	await ticks(int(.6*hz))
	check(controller.get_hand_state(0)=="ATTACHED" and (not two or controller.get_hand_state(1)=="ATTACHED"),"finite actual contact acquired for %s hands / moving %s" % [2 if two else 1,moving])
	body.mass = 50.0 if heavy else 12.0
	body.gravity_scale = 1.0
	await ticks(int(.35*hz))

func physical_trial(label: String, direction: Vector2, two: bool = false, moving: bool = false, enabled: bool = true) -> Dictionary:
	await acquire(two,moving)
	controller.intent_climb_enabled = enabled
	var start := body.global_position
	var support_start := support.global_position
	var rest_start: float = controller.hands[0].rest_length
	var peak_force := 0.0
	var peak_assist := 0.0
	var peak_rate := 0.0
	var peak_acceleration := 0.0
	var caps := true
	var unchanged_anchor = controller.hands[0].anchor
	controller.set_traversal_input(direction,Vector3.RIGHT)
	for index in int(1.2*hz):
		await tick()
		var data: Dictionary = controller.telemetry()
		peak_force = maxf(peak_force,data.total_force)
		peak_assist = maxf(peak_assist,Vector3(data.assist_torque).length())
		caps = caps and data.total_force<=360.001 and Vector3(data.assist_torque).length()<=20.001 and Vector3(data.torque).length()<=150.001
		for rate in data.intent_locomotion.target_rates.values():peak_rate = maxf(peak_rate,absf(rate))
		for acceleration in data.intent_locomotion.target_accelerations.values():peak_acceleration = maxf(peak_acceleration,absf(acceleration))
	var result := {"label":label,"dy":body.global_position.y-start.y,"dx":body.global_position.x-start.x,"support_dy":support.global_position.y-support_start.y,
		"support_rotation_z":support.global_rotation.z,
		"rest_delta":controller.hands[0].rest_length-rest_start,"peak_force":peak_force,"peak_assist":peak_assist,"rate":peak_rate,"acceleration":peak_acceleration,
		"state":controller.get_hand_state(0),"block_reason":controller.telemetry().intent_locomotion.movement_block_reason,"caps":caps}
	check(caps and peak_rate<=.2401 and peak_acceleration<=.9001,"%s preserves existing force/moment and new target rate/acceleration bounds" % label)
	check(controller.hands[0].anchor==unchanged_anchor or controller.get_hand_state(0) in ["FREE","RELEASED"],"%s never replaces a player-selected material contact; overload may release" % label)
	controller.set_traversal_input(Vector2.ZERO,Vector3.LEFT)
	await ticks(int(.8*hz))
	var settled: float = controller.hands[0].rest_length
	await ticks(int(1.0*hz))
	result.idle_drift = absf(controller.hands[0].rest_length-settled)
	check(result.idle_drift<.003,"%s stops target drift after finite neutral settling" % label)
	report.trials.append(result)
	print("INTENT_MEASURE ",JSON.stringify(result))
	await clear()
	return result

func blocked_and_handoff() -> void:
	await acquire(true,false)
	var pose := body.global_transform
	var velocity := body.linear_velocity
	var spin := body.angular_velocity
	controller.set_traversal_input(Vector2(0,1),Vector3.RIGHT)
	controller.set_ground_support({"grounded":true,"authority":.5,"normal":Vector3.UP,"point":body.global_position-Vector3.UP,"support_id":0,"applied_torque":Vector3(65,0,0)})
	check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"input/support ownership setters never write torso transforms or velocities")
	await ticks(2)
	check(controller.telemetry().intent_locomotion.support_mode=="FOOT_TRANSITION" and Vector3(controller.telemetry().combined_ground_climb_torque).length()<=150.001,"mixed real ground snapshot and attached grip report progressive handoff with same-tick combined torque budget")
	controller.set_ground_support({})
	var survivor = controller.hands[0].anchor
	var length: float = controller.hands[0].rest_length
	pose = body.global_transform
	velocity = body.linear_velocity
	spin = body.angular_velocity
	controller.release_grip(1)
	check(controller.hands[0].anchor==survivor and controller.hands[0].rest_length==length and body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"two-to-one release preserves survivor state and both velocities exactly at transition")
	controller.release_grip(0)
	await ticks(1)
	check(controller.telemetry().total_force==0 and controller.telemetry().assist_torque==Vector3.ZERO and controller.telemetry().intent_locomotion.support_mode=="FALLING_RECOVERY","real support loss immediately removes intent propulsion and reports recovery")
	await clear()
	await acquire(true,false)
	var ceiling := StaticBody3D.new()
	ceiling.position = body.global_position+Vector3(0,.96,0)
	ceiling.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4,.2,4)
	shape.shape = box
	ceiling.add_child(shape)
	world.add_child(ceiling)
	controller.set_traversal_input(Vector2(0,1),Vector3.RIGHT)
	var maximum_error := 0.0
	var peak_force := 0.0
	for index in int(4.0*hz):
		await tick()
		for hand in controller.hands:
			if hand.state=="ATTACHED":maximum_error = maxf(maximum_error,absf(hand.actual_length-hand.rest_length))
		peak_force = maxf(peak_force,controller.telemetry().total_force)
	check(maximum_error<.10 and peak_force<=360.001,"four-second blocked chest request cannot accumulate arbitrary actuator error or exceed shared capacity")
	var rest_before: float = controller.hands[0].rest_length
	controller.set_traversal_input(Vector2.ZERO,Vector3.LEFT)
	await ticks(int(.8*hz))
	check(absf(controller.hands[0].rest_length-rest_before)<.08,"release of a prolonged blocked command has bounded finite target recovery, not stored climb displacement")
	await clear()

func unsupported() -> void:
	var values: Array[Dictionary] = []
	for enabled in [false,true]:
		await setup({"label":"unsupported","gravity":1.0},false)
		controller.set_control_profile(4)
		controller.intent_climb_enabled = enabled
		controller.set_traversal_input(Vector2(1,1),Vector3.RIGHT)
		await ticks(int(.4*hz))
		values.append({"position":body.global_position,"velocity":body.linear_velocity,"force":controller.telemetry().total_force,"torque":controller.telemetry().assist_torque})
		check(controller.telemetry().total_force==0.0 and Vector3(controller.telemetry().assist_torque)==Vector3.ZERO,"no support / enabled %s produces exactly zero motor force or moment" % enabled)
		await clear()
	check(values[0]==values[1],"enabled unsupported WASD is exactly uncontrolled ballistic trajectory")
	await setup({"label":"far_pending","offset_y":1.2},false)
	controller.set_control_profile(4)
	controller.intent_climb_enabled = true
	controller.tuning.allow_out_of_reach_grip_targets = true
	controller.request_held_grip(0,support,anchor.world_point(),Vector3.BACK)
	controller.set_traversal_input(Vector2.UP,Vector3.RIGHT)
	await ticks(int(.6*hz))
	check(controller.get_hand_state(0)=="REACHING" and controller.telemetry().total_force==0 and controller.telemetry().intent_locomotion.support_mode=="AIRBORNE","distant pending hand never becomes motor authority or physical support")
	check(controller.telemetry().intent_locomotion.movement_block_reason=="TARGET_PENDING_ONLY","pending-only failure is reported separately from actual support")
	await clear()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	await frames()
	await unsupported()
	await blocked_and_handoff()
	var neutral: Dictionary = await physical_trial("one_neutral",Vector2.ZERO)
	var up: Dictionary = await physical_trial("one_up",Vector2(0,1))
	check(up.dy>neutral.dy+.03,"one actual hand W produces measurable upward progress relative to neutral on identical gravity geometry")
	var down: Dictionary = await physical_trial("one_down",Vector2(0,-1))
	check(down.rest_delta>neutral.rest_delta+.01,"S increases achievable arm target using gravity rather than a compression arm force")
	var dual: Dictionary = await physical_trial("two_up",Vector2(0,1),true)
	check(dual.peak_force<=360.001 and dual.dy>.03,"two real hands improve supported geometry without duplicating total strength")
	await physical_trial("one_right",Vector2(1,0))
	var dynamic: Dictionary = await physical_trial("moving_up",Vector2(0,1),false,true)
	check(absf(dynamic.support_rotation_z)>.03,"same support geometry on a real15kg hinge yields rotation to its actual mechanical stop")
	check(no_early_force and budgets,"all sampled physical steps preserve zero precontact effort and shared caps")
	var file := FileAccess.open("res://builds/intent_locomotion_%dhz.json" % hz,FileAccess.WRITE)
	file.store_string(JSON.stringify({"hz":hz,"checks":checks,"failures":failures,"report":report},"\t"))
	print("INTENT LOCOMOTION RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
