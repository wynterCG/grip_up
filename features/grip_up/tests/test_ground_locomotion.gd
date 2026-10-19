extends SceneTree
const Profile = preload("res://features/grip_up/resources/biped_tuning.gd")
const Controller = preload("res://features/grip_up/scripts/climbing_controller.gd")
const Motor = preload("res://features/grip_up/scripts/ground_locomotion.gd")
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
var world: Node3D
var body: RigidBody3D
var controller: Node
var motor: Node
var camera: Camera3D
var profile = Profile.new()
var checks := 0
var failures := 0
var hz := 120
var budgets_ok := true

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

func keys(w := 0.0, a := 0.0, s := 0.0, d := 0.0) -> void:
	for action in ["contract","bias_left","extend","bias_right"]:
		Input.action_release(action)
	for entry in [["contract",w],["bias_left",a],["extend",s],["bias_right",d]]:
		if float(entry[1])>0:
			Input.action_press(entry[0],entry[1])

func ticks(count: int) -> void:
	for frame in count:
		if is_instance_valid(motor):
			motor.move_intent = Input.get_vector("bias_left","bias_right","contract","extend")
			controller.set_climb_intent(Input.get_action_strength("contract"),Input.get_action_strength("extend"),Input.get_axis("bias_left","bias_right"))
		await physics_frame
		if is_instance_valid(motor):
			var max_acceleration: float = maxf(profile.walk_acceleration,profile.walk_braking)
			budgets_ok = budgets_ok and motor.applied_force.length()<=body.mass*max_acceleration+0.001 and motor.applied_torque.length()<=profile.walk_max_torque+0.001

func clear() -> void:
	keys()
	if is_instance_valid(controller):
		controller.reset_state()
	for child in world.get_children():
		child.queue_free()
	body = null
	controller = null
	motor = null
	await ticks(3)

func floor_at(at: Vector3 = Vector3(0,0.1,0.4), dynamic := false) -> PhysicsBody3D:
	var result: PhysicsBody3D = RigidBody3D.new() if dynamic else StaticBody3D.new()
	result.position = at
	result.collision_layer = 1
	result.collision_mask = 7
	var shape := BoxShape3D.new()
	shape.size = Vector3(16,0.3,16)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	result.add_child(collision)
	if dynamic:
		result.mass = 80
		result.gravity_scale = 0
		result.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		result.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		result.linear_damp = 0
		result.angular_damp = 0
	world.add_child(result)
	return result

func spawn(at: Vector3) -> RigidBody3D:
	var result := RigidBody3D.new()
	result.position = at
	result.mass = profile.body_mass
	result.continuous_cd = true
	result.can_sleep = false
	result.collision_layer = 4
	result.collision_mask = 3
	result.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	result.center_of_mass = profile.body_center_of_mass
	result.linear_damp = 0.08
	result.angular_damp = 0.35
	var mat := PhysicsMaterial.new()
	mat.friction = profile.body_friction
	result.physics_material_override = mat
	for dimensions in [Vector3(profile.torso_capsule_height,profile.torso_capsule_radius,profile.torso_capsule_center_y),Vector3(profile.leg_capsule_height,profile.leg_capsule_radius,profile.leg_capsule_center_y)]:
		var shape := CapsuleShape3D.new()
		shape.height = dimensions.x
		shape.radius = dimensions.y
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = dimensions.z
		result.add_child(collision)
	var head := SphereShape3D.new()
	head.radius = profile.head_radius
	var head_collision := CollisionShape3D.new()
	head_collision.shape = head
	head_collision.position.y = profile.head_center_y
	result.add_child(head_collision)
	var sole := BoxShape3D.new()
	sole.size = profile.foot_base_size
	var foot_collision := CollisionShape3D.new()
	foot_collision.shape = sole
	foot_collision.position = profile.foot_base_offset
	result.add_child(foot_collision)
	world.add_child(result)
	return result

func setup(at: Vector3 = Vector3(0,1.1667,0.4), yaw := 0.0) -> void:
	body = spawn(at)
	controller = Controller.new()
	world.add_child(controller)
	controller.configure(body,profile)
	camera = Camera3D.new()
	camera.rotation = Vector3(-0.2,yaw,0)
	world.add_child(camera)
	motor = Motor.new()
	world.add_child(motor)
	motor.configure(body,controller,camera)

func test_walk() -> void:
	floor_at()
	setup()
	await ticks(hz)
	check(motor.grounded and not motor.has_climbing_intent(),"standing free biped detects its actual supporting floor")
	var start: Vector3 = body.position
	keys(1)
	await ticks(int(1.5*hz))
	var displacement: Vector3 = body.position-start
	check(displacement.z < -2.0 and absf(displacement.x)<0.1,"W action drives camera-forward displacement through rigid-body forces")
	check(body.linear_velocity.slide(Vector3.UP).length()<=profile.walk_speed+0.15 and motor.walking,"ground target speed is finite and walking feedback activates")
	keys()
	var released: Vector3 = body.position
	await ticks(hz)
	check(body.linear_velocity.slide(Vector3.UP).length()<0.10 and body.position.distance_to(released)<0.7,"releasing WASD brakes naturally without assigning velocity")
	var idle_start: Vector3 = body.position
	await ticks(5*hz)
	check(body.position.distance_to(idle_start)<0.03 and body.global_basis.y.dot(Vector3.UP)>0.98,"five-second grounded idle stays upright and does not drift")
	await clear()

func test_camera_and_diagonal() -> void:
	floor_at()
	setup(Vector3(0,1.1667,0.4),PI/2)
	await ticks(int(0.5*hz))
	var start: Vector3 = body.position
	keys(1)
	await ticks(hz)
	check(body.position.x<start.x-1.3 and absf(body.position.z-start.z)<0.15,"rotating camera ninety degrees rotates W movement direction")
	await clear()
	floor_at()
	setup()
	await ticks(int(0.5*hz))
	start = body.position
	keys(1,0,0,1)
	await ticks(int(1.2*hz))
	var delta: Vector3 = body.position-start
	check(delta.x>0.8 and delta.z < -0.8 and absf(delta.x+delta.z)<0.25,"W+D uses normalized camera-relative diagonal")
	check(body.linear_velocity.slide(Vector3.UP).length()<profile.walk_speed+0.15,"diagonal input cannot multiply maximum walk speed")
	await clear()
	for reverse in [false,true]:
		floor_at()
		setup()
		await ticks(int(0.5*hz))
		start = body.position
		keys(0,0,1,0) if reverse else keys(0,1,0,0)
		await ticks(hz)
		var distance: float = body.position.z-start.z if reverse else start.x-body.position.x
		check(distance>1.0 and body.global_basis.y.dot(Vector3.UP)>0.9,"S backward input walks and turns without toppling" if reverse else "A lateral input walks and turns without toppling")
		await clear()

func test_air() -> void:
	setup(Vector3(0,5,0.4))
	var reference := spawn(Vector3(4,5,0.4))
	keys(1,0,0,1)
	var zero := true
	for frame in int(0.5*hz):
		await ticks(1)
		zero = zero and motor.applied_force==Vector3.ZERO and motor.applied_torque==Vector3.ZERO
	check(zero and not motor.grounded and body.linear_velocity.distance_to(reference.linear_velocity)<0.0001,"airborne WASD matches uncontrolled freefall with no drive or attitude torque")
	await clear()

func test_response() -> void:
	floor_at()
	setup()
	await ticks(int(0.5*hz))
	keys(0,0,1)
	await ticks(int(0.25*hz))
	check(body.linear_velocity.z>1.8,"ground movement accelerates to useful speed within 250 ms")
	await ticks(int(0.40*hz))
	var facing := (-body.global_basis.z).slide(Vector3.UP).normalized()
	var heading_error := absf(facing.signed_angle_to(Vector3.BACK,Vector3.UP))
	print("GROUND RESPONSE heading_error=",heading_error," speed=",body.linear_velocity.length())
	check(heading_error<0.35,"180-degree ground turn settles within 650 ms instead of sliding sideways")
	keys()
	var stop_start: Vector3 = body.position
	await ticks(int(0.30*hz))
	check(body.linear_velocity.slide(Vector3.UP).length()<0.12 and body.position.distance_to(stop_start)<0.35,"releasing movement brakes within 300 ms and 35 cm")
	await clear()
	floor_at()
	setup(Vector3(0,1.2167,0.4))
	body.gravity_scale = 0
	keys(1)
	await ticks(int(0.25*hz))
	check(not motor.grounded and motor.applied_force==Vector3.ZERO and body.linear_velocity.length()<0.0001,"five-centimetre foot gap is airborne, even when a ray sees the floor")
	await clear()

func test_climbing_priority() -> void:
	floor_at()
	setup()
	await ticks(int(0.5*hz))
	var point: Vector3 = controller.get_shoulder_world(0)+Vector3(0,0.35,-0.10)
	var hold := StaticBody3D.new()
	hold.position = point-Vector3(0,0,0.03)
	hold.collision_layer = 2
	hold.set_meta("grip_load_limit",20.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.15,0.10,0.06)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	hold.add_child(collision)
	world.add_child(hold)
	await ticks(2)
	check(controller.request_grip(0,hold,point,Vector3.BACK),"real grounded hand request starts finite reach")
	keys(1)
	var seen: Dictionary = {}
	var zero := true
	for frame in int(1.4*hz):
		await ticks(1)
		var state: String = controller.get_hand_state(0)
		if state in ["REACHING","ATTACHED","SLIPPING"]:
			seen[state] = true
			zero = zero and motor.applied_force==Vector3.ZERO and motor.applied_torque==Vector3.ZERO and not motor.walking
	check(seen.has("REACHING") and seen.has("ATTACHED") and seen.has("SLIPPING"),"priority fixture exercises real reach, attachment and deterministic slipping")
	check(zero,"REACHING ATTACHED and SLIPPING suppress every ground force and torque")
	await clear()

func momentum(item: RigidBody3D) -> Vector3:
	return item.linear_velocity*item.mass

func angular_momentum(item: RigidBody3D) -> Vector3:
	var center: Vector3 = item.global_transform*item.center_of_mass
	var spin: Vector3 = item.get_inverse_inertia_tensor().inverse()*item.angular_velocity
	return center.cross(momentum(item))+spin

func test_dynamic_support() -> void:
	var support: RigidBody3D = floor_at(Vector3(0,0.1,0.4),true)
	setup()
	body.gravity_scale = 0
	for item: RigidBody3D in [body,support]:
		item.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		item.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		item.linear_damp = 0
		item.angular_damp = 0
		item.physics_material_override = PhysicsMaterial.new()
		item.physics_material_override.friction = 0
	await ticks(3)
	keys(0,0,0,1)
	await ticks(int(0.20*hz))
	var total: Vector3 = momentum(body)+momentum(support)
	var angular: Vector3 = angular_momentum(body)+angular_momentum(support)
	print("GROUND DYNAMIC momentum=",total.length()," angular=",angular.length()," player_v=",body.linear_velocity," support_v=",support.linear_velocity)
	check(body.linear_velocity.x>0.2 and support.linear_velocity.x < -0.02,"walking applies a real opposite reaction to movable ground")
	check(total.length()<0.03 and angular.length()<0.15,"paired ground force and wrench conserve linear and angular momentum")
	await clear()
	support = floor_at(Vector3(0,0.1,0.4),true)
	setup()
	body.gravity_scale = 0
	for item: RigidBody3D in [body,support]:
		item.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		item.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		item.linear_damp = 0
		item.angular_damp = 0
		item.linear_velocity = Vector3(0.8,0,0)
	await ticks(int(0.2*hz))
	check(motor.applied_force.length()<0.05 and body.linear_velocity.distance_to(support.linear_velocity)<0.001,"idle braking uses moving support velocity instead of braking against world space")
	await clear()

func test_main_reset() -> void:
	var app = Lab.new()
	app.input_profile = 0 # Explicitly exercise the preserved legacy control profile.
	root.add_child(app)
	current_scene = app
	await ticks(hz)
	var old_motor = app.ground_motor
	var old_body = app.torso
	Input.action_press("contract")
	await ticks(int(0.2*hz))
	app.load_test(0)
	await ticks(hz)
	check(not is_instance_valid(old_motor) and not is_instance_valid(old_body),"actual app reset destroys old ground motor and rigid body")
	check(app.ground_motor.move_intent==Vector2.ZERO and not Input.is_action_pressed("contract") and app.torso.linear_velocity.length()<0.05,"reset clears walking input and leaves new grounded body idle")
	app.queue_free()
	await ticks(3)

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	# Use the same logical actions as main; Input.action_press exercises the real
	# Input singleton without changing a user's saved physical key bindings.
	for action in ["contract","extend","bias_left","bias_right"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	await test_walk()
	await test_camera_and_diagonal()
	await test_response()
	await test_air()
	await test_climbing_priority()
	await test_dynamic_support()
	await test_main_reset()
	check(budgets_ok,"every measured walk force and attitude torque stays within finite profile budgets")
	print("GROUND LOCOMOTION RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
