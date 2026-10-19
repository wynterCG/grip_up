extends SceneTree
## Calibration experiment: only fixture initialization sets body transforms.
## Every measured movement is produced by gravity and the production actuators.
const Profile = preload("res://features/grip_up/resources/biped_tuning.gd")
const Controller = preload("res://features/grip_up/scripts/climbing_controller.gd")
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
var world: Node3D
var body: RigidBody3D
var controller: Node
var hz := 120
var checks := 0
var failures := 0
var caps_ok := true

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):
		hz = 60
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ",label)

func step() -> void:
	await physics_frame
	var telemetry: Dictionary = controller.telemetry()
	if not telemetry.is_empty():
		caps_ok = caps_ok and telemetry.total_force<=360.001 and telemetry.torque.length()<=150.001

func ticks(count: int) -> void:
	for frame in count:
		await step()

func collider(shape: Shape3D, position: Vector3) -> void:
	var child := CollisionShape3D.new()
	child.shape = shape
	child.position = position
	body.add_child(child)

func setup(variant: String, dual: bool, arm_length: float = 0.5, fresh: bool = false, yaw: float = 0.0) -> Vector3:
	var profile := Profile.new()
	if variant == "baseline":
		profile.grip_blend_duration = 0.06
		profile.allocation_response_time = 0.10
		profile.twist_stiffness = 0.0
		profile.twist_damping = 0.0
		for property in profile.get_property_list():
			if property.name == "intent_response_time":
				profile.set("intent_response_time",0.0)
	if variant in ["assist_only","fluid"]:
		profile.attitude_damping = 0.25
	if variant == "fluid_radial":
		profile.attitude_damping = 0.25
		profile.arm_damping = 140.0
	body = RigidBody3D.new()
	body.position = Vector3(0,3,0)
	body.rotation.y = yaw
	body.mass = profile.body_mass
	body.gravity_scale = 0
	body.can_sleep = false
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3.ZERO
	body.linear_damp = 0.08
	body.angular_damp = 0.35
	if variant in ["drag_only","fluid","fluid_radial"]:
		body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		body.linear_damp = 0.02
		body.angular_damp = 0.03
	body.collision_layer = 4
	body.collision_mask = 1
	for segment in [Vector3(profile.torso_capsule_radius,profile.torso_capsule_height,profile.torso_capsule_center_y),Vector3(profile.leg_capsule_radius,profile.leg_capsule_height,profile.leg_capsule_center_y)]:
		var capsule := CapsuleShape3D.new()
		capsule.radius = segment.x
		capsule.height = segment.y
		collider(capsule,Vector3(0,segment.z,0))
	var head := SphereShape3D.new()
	head.radius = profile.head_radius
	collider(head,Vector3(0,profile.head_center_y,0))
	var foot := BoxShape3D.new()
	foot.size = profile.foot_base_size
	collider(foot,profile.foot_base_offset)
	world.add_child(body)
	controller = Controller.new()
	world.add_child(controller)
	controller.configure(body,profile)
	await ticks(3)
	var pivot := Vector3.ZERO
	for hand in (2 if dual else 1):
		var displacement := Vector3(0.20,sqrt(0.25-0.04),0) if dual else Vector3(-0.12,sqrt(0.25-0.0144),0)
		if fresh:
			displacement = Vector3(0,sqrt(arm_length*arm_length-0.08*0.08),-0.08)
		var point: Vector3 = controller.get_shoulder_world(hand)+displacement
		pivot += point/float(2 if dual else 1)
		var axis := displacement.normalized()
		var support := StaticBody3D.new()
		support.position = point+axis*0.025
		support.collision_layer = 2
		support.collision_mask = 0
		support.set_meta("grip_load_limit",10000.0)
		var sphere := SphereShape3D.new()
		sphere.radius = 0.025
		var collision := CollisionShape3D.new()
		collision.shape = sphere
		support.add_child(collision)
		world.add_child(support)
		var attached: bool = controller.request_grip(hand,support,point,-axis)
		for frame in int(0.7*hz):
			await step()
			if controller.get_hand_state(hand)=="ATTACHED":
				break
		attached = attached and controller.get_hand_state(hand)=="ATTACHED"
		check(attached,"real finite hand approach establishes pendulum anchor")
	if not fresh:
		await ticks(int(0.15*hz))
	body.gravity_scale = 1
	return pivot

func clear() -> void:
	controller.reset_state()
	for child in world.get_children():
		child.queue_free()
	controller = null
	body = null
	for frame in 3:
		await physics_frame

func passive(variant: String, dual: bool) -> Dictionary:
	var pivot: Vector3 = await setup(variant,dual)
	var peaks: Array[float] = []
	var times: Array[float] = []
	var last_angle: float = atan2(body.position.x-pivot.x,pivot.y-body.position.y)
	var previous_slope := 0.0
	var last_peak := -1.0
	var max_speed := 0.0
	var max_length := 0.0
	var retained := true
	for frame in int(8.0*hz):
		await step()
		var angle: float = atan2(body.position.x-pivot.x,pivot.y-body.position.y)
		var slope: float = angle-last_angle
		var time: float = float(frame)/hz
		if slope*previous_slope<0 and time-last_peak>0.45 and absf(last_angle)>0.005:
			peaks.append(absf(last_angle))
			times.append(time)
			last_peak = time
		previous_slope = slope
		last_angle = angle
		max_speed = maxf(max_speed,body.linear_velocity.length())
		for hand in (2 if dual else 1):
			retained = retained and controller.get_hand_state(hand)=="ATTACHED"
			max_length = maxf(max_length,controller.hands[hand].actual_length)
	var result := {"variant":variant,"dual":dual,"peaks_rad":peaks,"peak_times":times,"max_speed":max_speed,"max_length":max_length,"retained":retained}
	if peaks.size()>=3:
		result["third_to_first"] = peaks[2]/peaks[0]
	print("PENDULUM PASSIVE ",JSON.stringify(result))
	check(retained and max_length<=0.6601 and max_speed>0.1,"passive swing keeps anatomical reach and physical attachment")
	await clear()
	return result

func transfer(variant: String) -> Dictionary:
	await setup(variant,true)
	await ticks(int(1.0*hz))
	var pre_step_velocity: Vector3 = body.linear_velocity
	await step()
	var previous_a: Vector3 = (body.linear_velocity-pre_step_velocity)*hz
	var before_pose: Transform3D = body.global_transform
	var before_v: Vector3 = body.linear_velocity
	var before_w: Vector3 = body.angular_velocity
	var previous_force: Vector3 = controller.get_arm_force(0)+controller.get_arm_force(1)
	controller.release_grip(1)
	check(body.global_transform==before_pose and body.linear_velocity==before_v and body.angular_velocity==before_w,"dual-to-single event preserves pose and both velocities")
	controller.set_climb_intent(1,0,0)
	var previous_v: Vector3 = body.linear_velocity
	var peak_acceleration := 0.0
	var peak_jerk := 0.0
	var peak_force_delta := 0.0
	var retained := true
	for frame in int(0.8*hz):
		await step()
		var acceleration: Vector3 = (body.linear_velocity-previous_v)*hz
		if frame>0:
			peak_jerk = maxf(peak_jerk,(acceleration-previous_a).length()*hz)
		peak_acceleration = maxf(peak_acceleration,acceleration.length())
		var force: Vector3 = controller.get_arm_force(0)
		peak_force_delta = maxf(peak_force_delta,(force-previous_force).length())
		previous_force = force
		previous_v = body.linear_velocity
		previous_a = acceleration
		retained = retained and controller.get_hand_state(0)=="ATTACHED"
	print("PENDULUM TRANSFER ",JSON.stringify({"variant":variant,"peak_acceleration":peak_acceleration,"peak_jerk":peak_jerk,"peak_force_delta":peak_force_delta,"rest_length":controller.hands[0].rest_length,"retained":retained}))
	check(retained and peak_acceleration<50,"contraction and hand transfer remain finite and attached")
	await clear()
	return {"jerk":peak_jerk}

func directional_transitions(variant: String, dual: bool) -> Dictionary:
	await setup(variant,dual)
	await ticks(hz)
	var pre_step_velocity: Vector3 = body.linear_velocity
	await step()
	var previous_v: Vector3 = body.linear_velocity
	var previous_a: Vector3 = (body.linear_velocity-pre_step_velocity)*hz
	var previous_torque: Vector3 = controller.telemetry().assist_torque
	var peak_jerk := 0.0
	var peak_torque_delta := 0.0
	var command_window_jerk := 0.0
	var retained := true
	for command in [Vector3(1,0,1),Vector3.ZERO,Vector3(1,0,-1),Vector3.ZERO]:
		controller.set_climb_intent(command.x,command.y,command.z,Vector3.RIGHT)
		for frame in int(0.32*hz):
			await step()
			var acceleration: Vector3 = (body.linear_velocity-previous_v)*hz
			peak_jerk = maxf(peak_jerk,(acceleration-previous_a).length()*hz)
			if frame<int(0.12*hz):
				command_window_jerk = maxf(command_window_jerk,(acceleration-previous_a).length()*hz)
			var torque: Vector3 = controller.telemetry().assist_torque
			peak_torque_delta = maxf(peak_torque_delta,(torque-previous_torque).length())
			previous_v = body.linear_velocity
			previous_a = acceleration
			previous_torque = torque
			for hand in (2 if dual else 1):
				retained = retained and controller.get_hand_state(hand)=="ATTACHED"
	print("PENDULUM INPUT ",JSON.stringify({"variant":variant,"dual":dual,"peak_jerk":peak_jerk,"command_window_jerk":command_window_jerk,"peak_assist_delta":peak_torque_delta,"retained":retained}))
	check(retained,"A/D starts, stops and reversals preserve the material grips")
	await clear()
	return {"jerk":command_window_jerk,"assist_delta":peak_torque_delta}

func fresh_hang(variant: String, length: float) -> void:
	await setup(variant,false,length,true)
	var peak := 0.0
	var retained := true
	var peak_force_delta := 0.0
	var previous_force := Vector3.ZERO
	for frame in hz:
		await step()
		peak = maxf(peak,controller.hands[0].actual_length)
		var force: Vector3 = controller.get_arm_force(0)
		peak_force_delta = maxf(peak_force_delta,force.distance_to(previous_force))
		previous_force = force
		retained = retained and controller.get_hand_state(0)=="ATTACHED"
	print("PENDULUM FRESH ",JSON.stringify({"variant":variant,"initial_length":length,"peak_length":peak,"retained":retained,"peak_force_delta":peak_force_delta,"reason":controller.hands[0].reason}))
	check(retained and peak<=0.6601,"fresh near-maximum hanging catch preserves anatomical reach")
	await clear()

func yaw_recovery(variant: String, yaw: float) -> Dictionary:
	await setup(variant,false,0.5,false,yaw)
	var retained := true
	var max_assist := 0.0
	for frame in 4*hz:
		await step()
		retained = retained and controller.get_hand_state(0)=="ATTACHED"
		max_assist = maxf(max_assist,controller.telemetry().assist_torque.length())
	var right: Vector3 = body.global_basis.x.slide(Vector3.UP)
	var error: float = absf(right.normalized().signed_angle_to(Vector3.RIGHT,Vector3.UP))
	print("PENDULUM TWIST ",JSON.stringify({"variant":variant,"initial_yaw":yaw,"final_yaw_error":error,"retained":retained,"peak_assist":max_assist,"spin":body.angular_velocity.length()}))
	check(retained and max_assist<=20.001,"twist recovery preserves loaded grip and bounded assistance")
	if variant=="live":
		check(error<0.40,"camera-referenced loaded twist settles from rotated torso without locking swing")
	await clear()
	return {"error":error}

func reactive_heading() -> void:
	await physics_frame
	var app = Lab.new()
	app.input_profile = 0 # Explicitly exercise the preserved legacy control profile.
	root.add_child(app)
	current_scene = app
	app.load_test(2)
	for frame in int(0.75*hz):
		await physics_frame
	var beam: RigidBody3D = app.level.beam
	var point: Vector3 = beam.to_global(Vector3(0.3,0,0.13))
	check(app.controller.request_grip(1,beam,point,Vector3.BACK),"actual reactive beam front catch is accessible")
	Input.action_press("contract")
	for frame in int(2.5*hz):
		await physics_frame
	var telemetry: Dictionary = app.controller.telemetry()
	var right: Vector3 = app.torso.global_basis.x.slide(Vector3.UP)
	var reference: Vector3 = telemetry.control_right
	var error: float = absf(right.normalized().signed_angle_to(reference,Vector3.UP))
	print("PENDULUM REACTIVE ",JSON.stringify({"position":app.torso.position,"rotation":app.torso.rotation,"heading_error":error,"force":telemetry.total_force,"assist":telemetry.assist_torque,"arm_length":app.controller.hands[1].actual_length,"rest_length":app.controller.hands[1].rest_length}))
	check(error<0.40 and app.controller.get_hand_state(1)=="ATTACHED","actual short-arm reactive pose retains controllable heading")
	Input.action_release("contract")
	app.queue_free()
	for frame in 4:
		await physics_frame

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var measurements := {}
	for variant in ["baseline","live"]:
		var single: Dictionary = await passive(variant,false)
		var dual: Dictionary = await passive(variant,true)
		var hand_transfer: Dictionary = await transfer(variant)
		var single_input: Dictionary = await directional_transitions(variant,false)
		var dual_input: Dictionary = await directional_transitions(variant,true)
		measurements[variant] = {"single":single,"dual":dual,"transfer":hand_transfer,"single_input":single_input,"dual_input":dual_input}
		await fresh_hang(variant,sqrt(0.60*0.60+0.08*0.08))
		await fresh_hang(variant,0.62)
		for yaw in [PI/2,-PI/2,PI,-PI]:
			await yaw_recovery(variant,yaw)
	check(measurements.live.transfer.jerk<measurements.baseline.transfer.jerk*0.8,"live hand transfer reduces measured jerk by at least 20 percent")
	check(measurements.live.single_input.jerk<measurements.baseline.single_input.jerk*0.8 and measurements.live.dual_input.jerk<measurements.baseline.dual_input.jerk*0.8,"live A/D starts and stops reduce single/dual command jerk by at least 20 percent")
	check(measurements.live.single_input.assist_delta<measurements.baseline.single_input.assist_delta*0.8,"single-grip input torque ramps instead of stepping on key events")
	check(absf(measurements.live.single.third_to_first-measurements.baseline.single.third_to_first)<0.05 and absf(measurements.live.dual.third_to_first-measurements.baseline.dual.third_to_first)<0.05,"twist stabilization preserves passive pendular amplitude decay")
	await reactive_heading()
	check(caps_ok,"all measured swings and transfers preserve 360 N / 150 Nm limits")
	print("PENDULUM RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
