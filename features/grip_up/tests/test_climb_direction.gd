extends SceneTree
## Isolated physical directional response, not merely torque-vector assertions.
## Body poses/velocities are initialized only before a fixture starts.
const Profile = preload("res://features/grip_up/resources/biped_tuning.gd")
const Controller = preload("res://features/grip_up/scripts/climbing_controller.gd")
var world: Node3D
var body: RigidBody3D
var controller: Node
var hz := 120
var checks := 0
var failures := 0
var budgets := true
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

func ticks(count: int) -> void:
	for index in count:
		await physics_frame
		if is_instance_valid(controller) and not controller.telemetry().is_empty():
			budgets = budgets and controller.telemetry()["total_force"]<=360.001 and controller.telemetry()["torque"].length()<=150.001

func clear() -> void:
	controller.reset_state()
	for child in world.get_children():
		child.queue_free()
	controller = null
	body = null
	await ticks(3)

func setup(rotation: Vector3) -> void:
	body = RigidBody3D.new()
	body.position = Vector3(0,3,0)
	body.rotation = rotation
	body.mass = 12
	body.gravity_scale = 0
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3.ZERO
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0
	body.angular_damp = 0
	# Test anchors are queryable but do not collide with the body, isolating the
	# arm controller from incidental wall/foot collisions in a rotated fixture.
	body.collision_layer = 4
	body.collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4,1.6,0.3)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	controller = Controller.new()
	world.add_child(controller)
	controller.configure(body,Profile.new())

func anchor(point: Vector3, outward: Vector3, dynamic: bool = false) -> PhysicsBody3D:
	var support: PhysicsBody3D = RigidBody3D.new() if dynamic else StaticBody3D.new()
	var radius: float = 0.3 if dynamic else 0.025
	support.position = point+outward*radius
	support.collision_layer = 2
	support.collision_mask = 0
	support.set_meta("grip_load_limit",10000.0)
	if dynamic:
		support.mass = 15
		support.gravity_scale = 0
		support.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		support.center_of_mass = Vector3.ZERO
		support.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		support.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		support.linear_damp = 0
		support.angular_damp = 0
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	support.add_child(collision)
	world.add_child(support)
	return support

func attach(hand: int, support: PhysicsBody3D, point: Vector3, normal: Vector3) -> bool:
	var pose: Transform3D = body.global_transform
	var linear: Vector3 = body.linear_velocity
	var angular: Vector3 = body.angular_velocity
	var ok: bool = controller.request_grip(hand,support,point,normal)
	event_continuity = event_continuity and body.global_transform==pose and body.linear_velocity==linear and body.angular_velocity==angular
	if not ok:
		print("DIRECTION REJECT ",controller.last_rejection)
		return false
	for frame in int(0.7*hz):
		await ticks(1)
		if controller.get_hand_state(hand)=="ATTACHED":
			return true
	print("DIRECTION REACH FAIL ",controller.hands[hand]["reason"])
	return false

func intent(bias: float, right: Vector3, contract: float = 1.0) -> void:
	var pose: Transform3D = body.global_transform
	var linear: Vector3 = body.linear_velocity
	var angular: Vector3 = body.angular_velocity
	controller.set_climb_intent(contract,0,bias,right)
	event_continuity = event_continuity and body.global_transform==pose and body.linear_velocity==linear and body.angular_velocity==angular

func single_probe(rotation: Vector3, right: Vector3, bias: float) -> Dictionary:
	setup(rotation)
	await ticks(3)
	var shoulder: Vector3 = controller.get_shoulder_world(0)
	var radial: Vector3 = (shoulder-body.global_position).normalized()
	var point: Vector3 = shoulder+radial*0.35
	var support := anchor(point,radial)
	var attached: bool = await attach(0,support,point,-radial)
	await ticks(int(0.1*hz))
	var initial: Vector3 = body.position
	intent(bias,right)
	# Include the biped's 120 ms intent ramp before measuring directional travel.
	await ticks(int(0.35*hz))
	var result := {"attached":attached and controller.get_hand_state(0)=="ATTACHED","shift":(body.position-initial).dot(right),"speed":body.linear_velocity.dot(right)}
	await clear()
	return result

func test_single_rotations() -> void:
	var cases := [Vector3.ZERO,Vector3(0,PI/2,0),Vector3(0,PI,0),Vector3(0,-PI/2,0),Vector3(0,0,PI/2),Vector3(0,0,-PI/2),Vector3(0,0,PI),Vector3(0,0,-PI),Vector3(0,PI/2,PI/2),Vector3(0,-PI/2,-PI/2)]
	for right in [Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT]:
		for rotation in cases:
			var left: Dictionary = await single_probe(rotation,right,-1)
			var toward_right: Dictionary = await single_probe(rotation,right,1)
			var delta: float = toward_right["shift"]-left["shift"]
			print("DIRECTION SINGLE rotation=",rotation," camera_right=",right," D_minus_A=",delta)
			check(left["attached"] and toward_right["attached"] and delta>0.0001,"rotated single-grip D response remains camera-right relative to A")

func test_dual(swapped: bool, yaw: float, collinear: bool = false) -> void:
	setup(Vector3(0,yaw,0))
	await ticks(3)
	var right := Vector3.RIGHT
	var midpoint: Vector3 = (controller.get_shoulder_world(0)+controller.get_shoulder_world(1))*0.5+Vector3.UP*0.38
	# Depth-separated surfaces have identical screen-horizontal projection while
	# leaving both real hand approach paths unobstructed by the other support.
	var separation: Vector3 = Vector3.FORWARD*0.12 if collinear else right*0.22
	var points: Array[Vector3] = [midpoint-separation,midpoint+separation]
	if swapped:
		points.reverse()
	var complete := true
	for hand in 2:
		var axis: Vector3 = (points[hand]-controller.get_shoulder_world(hand)).normalized()
		var support := anchor(points[hand],axis)
		complete = await attach(hand,support,points[hand],-axis) and complete
	await ticks(int(0.8*hz))
	var before: Array[float] = [controller.hands[0]["rest_length"],controller.hands[1]["rest_length"]]
	intent(1,right)
	await ticks(int(0.30*hz))
	var weight0: float = controller.hands[0]["allocation"]
	var weight1: float = controller.hands[1]["allocation"]
	var contraction0: float = before[0]-controller.hands[0]["rest_length"]
	var contraction1: float = before[1]-controller.hands[1]["rest_length"]
	if collinear:
		check(complete and absf(weight0-weight1)<0.01 and absf(contraction0-contraction1)<0.005,"screen-collinear anchors fade lateral bias without an arbitrary hand-id preference")
	else:
		var difference: float = (weight0-weight1) if swapped else (weight1-weight0)
		var shortening: float = (contraction0-contraction1) if swapped else (contraction1-contraction0)
		check(complete and difference>0.15 and shortening>0.01,"dual effort and contraction follow rightmost anchor despite swapped hand IDs/body yaw")
	await clear()

func angular_momentum(item: RigidBody3D) -> Vector3:
	return item.global_position.cross(item.linear_velocity*item.mass)+item.get_inverse_inertia_tensor().inverse()*item.angular_velocity

func test_reactive() -> void:
	setup(Vector3(0,PI/2,PI/2))
	await ticks(3)
	var shoulder: Vector3 = controller.get_shoulder_world(0)
	var axis: Vector3 = (shoulder-body.global_position).normalized()
	var point: Vector3 = shoulder+axis*0.35
	var support: RigidBody3D = anchor(point,axis,true)
	check(await attach(0,support,point,-axis),"rotated directional fixture reaches a movable material anchor")
	await ticks(int(0.1*hz))
	intent(1,Vector3.FORWARD)
	await ticks(int(0.18*hz))
	var momentum: Vector3 = body.linear_velocity*body.mass+support.linear_velocity*support.mass
	var angular: Vector3 = angular_momentum(body)+angular_momentum(support)
	print("DIRECTION REACTIVE momentum=",momentum.length()," angular=",angular.length())
	check(momentum.length()<0.03 and angular.length()<0.1,"view-relative assist and pulling retain opposite dynamic-support reaction")
	await clear()

func test_no_anchor() -> void:
	setup(Vector3(0,PI,PI/2))
	await ticks(3)
	intent(1,Vector3.FORWARD)
	await ticks(int(0.25*hz))
	check(body.linear_velocity.length()<0.00001 and body.angular_velocity.length()<0.00001,"camera-relative input cannot become a free-flight force or torque")
	intent(1,Vector3(INF,0,0))
	await ticks(2)
	check(controller.telemetry()["control_right"].is_finite(),"non-finite view reference is sanitized")
	await clear()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	await test_single_rotations()
	for yaw in [0.0,PI/2,PI]:
		await test_dual(false,yaw)
		await test_dual(true,yaw)
	await test_dual(false,PI,true)
	await test_reactive()
	await test_no_anchor()
	check(budgets,"all rotated single/dual trials keep shared force and resultant torque limits")
	check(event_continuity,"view intent and grip events never assign torso pose or velocities")
	print("CLIMB DIRECTION RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
