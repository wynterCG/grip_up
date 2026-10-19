extends SceneTree
## Same playable biped and finite grip controller; fixture placement occurs only
## before the first physics step. Launching never edits body pose or velocity.
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var hz := 120
var checks := 0
var failures := 0
var bounded := true
var event_continuity := true

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

func tick() -> void:
	await physics_frame
	if is_instance_valid(app) and is_instance_valid(app.controller):
		var data: Dictionary = app.controller.telemetry()
		if not data.is_empty():
			bounded = bounded and data.total_force<=360.001 and data.torque.length()<=150.001

func ticks(count: int) -> void:
	for frame in count:
		await tick()

func request(pressed: bool) -> bool:
	var pose: Transform3D = app.torso.global_transform
	var linear: Vector3 = app.torso.linear_velocity
	var angular: Vector3 = app.torso.angular_velocity
	var result: bool = app.controller.request_launch_charge(pressed)
	event_continuity = event_continuity and pose==app.torso.global_transform and linear==app.torso.linear_velocity and angular==app.torso.angular_velocity
	return result

func setup(hands: int, dynamic: bool = false) -> Array[PhysicsBody3D]:
	await physics_frame
	app = Lab.new()
	app.input_profile = 0 # Explicitly exercise the preserved legacy control profile.
	root.add_child(app)
	current_scene = app
	# Elevated free-wall fixture: the production one-body capsule/sole, actual
	# colliders and world gravity remain active once the finite hands attach.
	app.torso.position = Vector3(0,3,0.45)
	app.torso.gravity_scale = 0
	app.controller.reset_state()
	var supports: Array[PhysicsBody3D] = []
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for hand in hands:
		var shoulder: Vector3 = app.controller.get_shoulder_world(hand)
		var displacement := Vector3(-0.17 if hand==0 else 0.17,0.43,0.0 if dynamic else -0.30)
		var point: Vector3 = shoulder+displacement
		var support: PhysicsBody3D = RigidBody3D.new() if dynamic else StaticBody3D.new()
		if dynamic:
			support.mass = 20.0
			# A weighted handle, rather than an almost inertia-free dense marble:
			# avoids Jolt's angular-speed ceiling obscuring reaction conservation.
			support.inertia = Vector3(2,2,2)
			support.gravity_scale = 0
			support.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
			support.center_of_mass = Vector3.ZERO
			support.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
			support.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
			support.linear_damp = 0
			support.angular_damp = 0
		support.position = point+displacement.normalized()*0.03
		support.set_meta("grip_load_limit",10000.0)
		var shape := SphereShape3D.new()
		shape.radius = 0.03
		var collision := CollisionShape3D.new()
		collision.shape = shape
		support.add_child(collision)
		app.world.add_child(support)
		supports.append(support)
		points.append(point)
		normals.append(-displacement.normalized())
	# Register every real collider with Jolt before asking the public LOS API.
	await ticks(3)
	for hand in hands:
		var acquired: bool = app.controller.request_grip(hand,supports[hand],points[hand],normals[hand])
		for frame in int(0.7*hz):
			await tick()
			if app.controller.get_hand_state(hand)=="ATTACHED":
				break
		if not acquired or app.controller.get_hand_state(hand)!="ATTACHED":
			print("LAUNCH FIXTURE REJECT ",app.controller.last_rejection," ",app.controller.hands[hand].reason)
		check(acquired and app.controller.get_hand_state(hand)=="ATTACHED","launch fixture reaches a real visible material surface")
	app.torso.gravity_scale = 0 if dynamic else 1
	Input.action_press("contract")
	await ticks(int(0.65*hz))
	Input.action_release("contract")
	await ticks(int(0.15*hz))
	return supports

func clear() -> void:
	Input.action_release("contract")
	app.queue_free()
	for frame in 4:
		await physics_frame
	app = null

func launch_trial(hands: int, active: bool) -> Dictionary:
	await setup(hands)
	var precharge_y: float = app.torso.position.y
	check(request(true),"attached biped can start a bounded launch preload")
	await ticks(int(0.45*hz))
	var before_y: float = app.torso.position.y
	var charged := true
	for hand in hands:
		charged = charged and app.controller.get_hand_state(hand)=="ATTACHED"
	check(charged,"preload preserves original material anchors")
	if active:
		check(request(false),"releasing launch input begins an actuator pull")
	else:
		for hand in hands:
			app.controller.release_grip(hand)
		app.controller.cancel_launch()
	var detached := not active
	var launch_velocity: Vector3 = app.torso.linear_velocity
	var takeoff_y := before_y
	var apex := before_y
	var peak_force := 0.0
	var max_length := 0.0
	for frame in int(1.8*hz):
		await tick()
		apex = maxf(apex,app.torso.position.y)
		peak_force = maxf(peak_force,app.controller.telemetry().total_force)
		var attached := false
		for hand in hands:
			if app.controller.get_hand_state(hand) in ["ATTACHED","SLIPPING"]:
				attached = true
				max_length = maxf(max_length,app.controller.hands[hand].actual_length)
		if not attached and not detached:
			detached = true
			launch_velocity = app.torso.linear_velocity
			takeoff_y = app.torso.position.y
	var result := {"hands":hands,"active":active,"detached":detached,"velocity":launch_velocity,"apex":apex,"precharge_y":precharge_y,"rise_before_charge":apex-precharge_y,"rise_from_preload":apex-before_y,"ballistic_rise":apex-takeoff_y,"peak_force":peak_force,"max_length":max_length}
	print("LAUNCH TRIAL ",result)
	check(detached and max_length<=0.6601,"launch detaches without exceeding anatomical arm reach")
	await clear()
	return result

func cancellation() -> void:
	await setup(1)
	check(request(true),"launch can be charged for cancellation checks")
	await ticks(2)
	check(not request(false),"a tap shorter than the minimum charge cannot launch")
	await ticks(1)
	check(app.controller.telemetry().launch_state=="IDLE","short-tap cancellation returns launch state to idle")
	check(request(true),"cancelled preload can be started again")
	if is_instance_valid(app.controller.hands[0].support):
		app.controller.hands[0].support.queue_free()
	await ticks(4)
	check(app.controller.get_hand_state(0) in ["FREE","RELEASED"] and app.controller.telemetry().launch_state in ["IDLE","COOLDOWN"],"destroying support cancels active preload safely")
	check(not request(true) and not request(false),"airborne input cannot start another actuator launch")
	var old_controller = app.controller
	app.load_test(0)
	await ticks(3)
	check(not is_instance_valid(old_controller) and app.controller.telemetry().launch_state=="IDLE","reset clears launch state and references")
	await clear()

func no_air_thrust() -> void:
	await setup(1)
	app.controller.release_grip(0)
	app.controller.cancel_launch()
	await ticks(2)
	var before: Vector3 = app.torso.linear_velocity
	check(not request(true) and not request(false),"ungripped input is rejected without an impulse")
	await ticks(int(0.2*hz))
	check(app.controller.telemetry().total_force==0.0 and app.torso.linear_velocity.y<before.y-1.0,"ungripped biped follows gravity without launch thrust")
	await clear()

func momentum(body: RigidBody3D) -> Vector3:
	return body.linear_velocity*body.mass

func angular_momentum(body: RigidBody3D) -> Vector3:
	return body.global_position.cross(momentum(body))+body.get_inverse_inertia_tensor().inverse()*body.angular_velocity

func dynamic_reaction() -> void:
	var supports := await setup(1,true)
	var support: RigidBody3D = supports[0]
	# The height trial above includes the authored world; conservation is a
	# separate closed-system experiment without scenery or ground locomotion.
	app.ground_motor.set_physics_process(false)
	app.set_physics_process(false)
	app.set_process(false)
	app.torso.collision_mask = 1
	support.collision_layer = 2
	support.collision_mask = 0
	app.level.queue_free()
	app.torso.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	app.torso.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	app.torso.linear_damp = 0
	app.torso.angular_damp = 0
	app.torso.contact_monitor = true
	app.torso.max_contacts_reported = 16
	support.contact_monitor = true
	support.max_contacts_reported = 16
	await ticks(4)
	var initial_p: Vector3 = momentum(app.torso)+momentum(support)
	var initial_l: Vector3 = angular_momentum(app.torso)+angular_momentum(support)
	check(request(true),"movable support permits a physical charged pull")
	await ticks(int(0.45*hz))
	check(request(false),"dynamic-support launch starts from the original anchor")
	await ticks(int(0.30*hz))
	var error_p: float = (momentum(app.torso)+momentum(support)-initial_p).length()
	var error_l: float = (angular_momentum(app.torso)+angular_momentum(support)-initial_l).length()
	print("LAUNCH DYNAMIC momentum_error=",error_p," angular_error=",error_l," support_velocity=",support.linear_velocity," bodypos=",app.torso.position," contacts=",app.torso.get_colliding_bodies()," supportcontacts=",support.get_colliding_bodies()," P0=",initial_p," P1=",momentum(app.torso)+momentum(support)," L0=",initial_l," L1=",angular_momentum(app.torso)+angular_momentum(support))
	check(error_p<0.03 and error_l<0.15,"launch transmits opposite force and torque to dynamic material support")
	await clear()

func preserve_new_catch() -> void:
	await setup(1)
	check(request(true),"launch for mid-pull catch can charge")
	await ticks(int(0.45*hz))
	check(request(false),"mid-pull catch begins during a real launch")
	var shoulder: Vector3 = app.controller.get_shoulder_world(1)
	# Remain within natural reach throughout the production .30 s pull. A lower
	# catch would legitimately break by extension before the release timer.
	var offset := Vector3(0.18,-0.15,0)
	var point := shoulder+offset
	var support := StaticBody3D.new()
	support.position = point+offset.normalized()*0.03
	support.set_meta("grip_load_limit",10000.0)
	var sphere := SphereShape3D.new()
	sphere.radius = 0.03
	var shape := CollisionShape3D.new()
	shape.shape = sphere
	support.add_child(shape)
	app.world.add_child(support)
	await ticks(2)
	check(app.controller.request_grip(1,support,point,-offset.normalized()),"free hand can request another actual surface while pulling")
	var reached := false
	var completed := false
	for frame in int(0.4*hz):
		await tick()
		reached = reached or app.controller.get_hand_state(1)=="ATTACHED"
		if app.controller.telemetry().launch_state=="COOLDOWN":
			completed = true
			break
	check(completed and reached and app.controller.get_hand_state(1)=="ATTACHED" and app.controller.hands[1].support==support,"automatic takeoff releases original anchors and preserves a newly caught grip")
	await clear()

func practical_wall_launch() -> void:
	await physics_frame
	app = Lab.new()
	app.input_profile = 0 # Explicitly exercise the preserved legacy control profile.
	root.add_child(app)
	current_scene = app
	await ticks(int(0.5*hz))
	var wall: PhysicsBody3D = app.level.get_node("Wall")
	Input.action_press("contract")
	for hand in 2:
		var point := Vector3(-0.16 if hand==0 else 0.12,2.01,0)
		var accepted: bool = app.controller.request_grip(hand,wall,point,Vector3.BACK)
		await ticks(int(0.65*hz))
		check(accepted and app.controller.get_hand_state(hand)=="ATTACHED","practical launch begins at an actual reachable wall surface")
		await ticks(int(0.85*hz))
	for index in 6:
		var hand: int = index%2
		var shoulder: Vector3 = app.controller.get_shoulder_world(hand)
		var point := Vector3(clampf(shoulder.x,-0.16,0.16),shoulder.y+0.32,0)
		app.controller.release_grip(hand)
		var accepted: bool = app.controller.request_grip(hand,wall,point,Vector3.BACK)
		await ticks(int(0.65*hz))
		check(accepted and app.controller.get_hand_state(hand)=="ATTACHED","practical launch gains its starting height through hand-over-hand physics")
		await ticks(hz)
	Input.action_release("contract")
	var start_y: float = app.torso.position.y
	var target := Vector3(-0.12,app.controller.get_shoulder_world(0).y+0.72,0)
	var initial_distance: float = app.controller.get_shoulder_world(0).distance_to(target)
	check(initial_distance>app.controller.get_max_reach()+0.05,"higher wall target begins beyond full anatomical reach")
	check(request(true),"midwall launch charges using the production profile")
	await ticks(int(0.48*hz))
	check(request(false),"midwall launch pulls without a torso impulse")
	var requested := false
	var catch_time := -1.0
	var continuous := true
	var retained := false
	var peak_y := start_y
	for frame in 2*hz:
		await tick()
		var time := float(frame+1)/hz
		if catch_time<0:
			peak_y = maxf(peak_y,app.torso.position.y)
		var distance: float = app.controller.get_shoulder_world(0).distance_to(target)
		if app.controller.get_hand_state(0)=="FREE" and distance<app.controller.get_max_reach()-0.005:
			requested = app.controller.request_grip(0,wall,target,Vector3.BACK) or requested
		if requested and catch_time<0 and app.controller.get_hand_state(0)=="ATTACHED":
			catch_time = time
			Input.action_press("contract")
		if catch_time>=0:
			continuous = continuous and app.controller.get_hand_state(0)=="ATTACHED"
			if time-catch_time>=1.0:
				retained = continuous
	check(peak_y-start_y>0.15,"actual wall launch raises the torso above its precharge pose")
	check(requested and catch_time>0 and retained,"previously unreachable wall target is caught and retained for one second")
	check(app.trial.falls==0 and app.trial.large_step_events==0,"practical wall dyno uses continuous physics without reset or teleport")
	print("LAUNCH PRACTICAL initial_distance=",initial_distance," precharge_gain=",peak_y-start_y," catch_time=",catch_time," retained_1s=",retained," final_position=",app.torso.position)
	await clear()

func run() -> void:
	var normal_single := await launch_trial(1,false)
	var launch_single := await launch_trial(1,true)
	var normal_dual := await launch_trial(2,false)
	var launch_dual := await launch_trial(2,true)
	check(launch_single.velocity.y>0.25 and launch_single.apex>normal_single.apex+0.10,"single-hand dyno gains real upward velocity and higher apex than normal release")
	check(launch_dual.velocity.y>0.25 and launch_dual.apex>normal_dual.apex+0.10,"two-hand dyno gains height using the same shared force budget")
	check(launch_single.rise_before_charge>0.10,"single-hand launch gains height above the pose before charging")
	check(launch_dual.rise_before_charge>0.10,"dual-hand launch gains height above the pose before charging")
	await cancellation()
	await no_air_thrust()
	await dynamic_reaction()
	await preserve_new_catch()
	await practical_wall_launch()
	check(bounded,"one/two-hand launch shares the existing 360 N / 150 Nm limits")
	check(event_continuity,"charge/release input never assigns body pose or velocities")
	print("LAUNCH RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
