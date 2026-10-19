extends SceneTree
## Diagnostic fixtures only. Active torso transforms/velocities are never set.
const Controller = preload("res://features/grip_up/scripts/climbing_controller.gd")
var world: Node3D
var controller: Node
var body: RigidBody3D
var rows: Array[Dictionary] = []
var checks := 0
var failures := 0
var hz := 120

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):
		hz = 60
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)

func box(label: String, at: Vector3, size: Vector3, grippable := false) -> StaticBody3D:
	var solid := StaticBody3D.new()
	solid.name = label
	solid.position = at
	solid.set_meta("grippable", grippable)
	solid.set_meta("grip_load_limit", 460.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	solid.add_child(collision)
	world.add_child(solid)
	return solid

func torso(at: Vector3, friction: float) -> RigidBody3D:
	var item := RigidBody3D.new()
	item.position = at
	item.mass = 12
	item.can_sleep = false
	item.continuous_cd = true
	item.linear_damp = 0.08
	item.angular_damp = 0.35
	item.contact_monitor = true
	item.max_contacts_reported = 16
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.bounce = 0
	item.physics_material_override = material
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.05
	collision.shape = shape
	item.add_child(collision)
	world.add_child(item)
	return item

func clear() -> void:
	if is_instance_valid(controller):
		controller.reset_state()
	for child in world.get_children():
		child.queue_free()
	await ticks(3)

func inside_at(point: Vector3) -> Array[String]:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.exclude = [body.get_rid()]
	var result: Array[String] = []
	for hit in body.get_world_3d().direct_space_state.intersect_point(query):
		result.append(str(hit.collider.name))
	return result

func fallen_recovery(hand: int, friction: float) -> void:
	box("Wall",Vector3(0,3,-0.65),Vector3(5.8,7,0.4))
	box("Start",Vector3(0,0.1,0.55),Vector3(4,0.3,2.8))
	var hold_a := box("Hold01",Vector3(-0.65,1.95,0),Vector3(0.72,0.24,0.55),true)
	var hold_b := box("Hold02",Vector3(0.65,2.73,0),Vector3(0.72,0.24,0.55),true)
	body = torso(Vector3(0.998856,0.56952,-0.121048),friction)
	# Exact observed recovery pose, assigned only during fixture initialization.
	body.rotation = Vector3(-1.169217,-0.045273,1.570782)
	controller = Controller.new()
	world.add_child(controller)
	controller.configure(body)
	var free_clear := true
	var free_bounded := true
	var previous_hand: Vector3 = controller.get_hand_world(hand)
	for frame in int(0.5*hz):
		await physics_frame
		var current_hand: Vector3 = controller.get_hand_world(hand)
		free_clear = free_clear and inside_at(current_hand).is_empty()
		free_bounded = free_bounded and previous_hand.distance_to(current_hand) <= controller.tuning.hand_reach_speed/hz + 0.001
		previous_hand = current_hand
	check(free_clear and free_bounded,"fallen FREE hand%d stays outside Wall/Start at finite hand speed" % hand)
	var start_pose: Transform3D = body.global_transform
	var hand_before: Vector3 = controller.get_hand_world(hand)
	var shoulder: Vector3 = controller.get_shoulder_world(hand)
	var support: PhysicsBody3D = hold_a if hand == 0 else hold_b
	var ray := PhysicsRayQueryParameters3D.create(shoulder,support.global_position)
	ray.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(ray)
	var requested := false
	if not hit.is_empty() and hit.collider == support:
		requested = controller.request_grip(hand,support,hit.position,hit.normal)
	print("FALLEN BEFORE hand=",hand," friction=",friction," torso=",body.position," shoulder=",shoulder," endpoint=",hand_before," endpoint_inside=",inside_at(hand_before)," real_hit=",hit," requested=",requested," reject=",controller.last_rejection)
	await ticks(int(0.8*hz))
	var attached: bool = controller.get_hand_state(hand) == "ATTACHED"
	print("FALLEN AFTER hand=",hand," state=",controller.get_hand_state(hand)," reason=",controller.hands[hand]["reason"]," torso_drift=",body.position.distance_to(start_pose.origin))
	check(requested and attached,"fallen snapshot hand%d friction%.2f can reacquire real visible hold" % [hand,friction])
	if hand == 1 and attached:
		var start_y: float = body.position.y
		controller.set_climb_intent(1,0,0)
		await ticks(int(2.0*hz))
		print("FALLEN W RECOVERY friction=",friction," y_before=",start_y," y_after=",body.position.y," state=",controller.get_hand_state(hand)," force=",controller.get_arm_force(hand).length())
		check(body.position.y > start_y + 0.25 and controller.get_hand_state(hand) == "ATTACHED","fallen RIGHT grip02 and W physically lift torso out of resting pose")
	await clear()

func sample(label: String, friction: float, depth: float, face: String, dual: bool, bias: float, ledge := false) -> Dictionary:
	box("Wall", Vector3(0,3,-0.65), Vector3(6,7,0.4))
	box("Floor", Vector3(0,0.1,0.55), Vector3(5,0.3,3))
	var hold := box("Hold", Vector3(0,2.2,0), Vector3(0.72,0.24,depth), true)
	if ledge:
		box("Ledge", Vector3(0.9,1.55,0.4), Vector3(0.8,0.2,1.0))
	var spawn := Vector3(0,0.775,0.55)
	if face == "top":
		spawn = Vector3(0,3.15,0.55)
	body = torso(spawn, friction)
	controller = Controller.new()
	world.add_child(controller)
	controller.configure(body)
	await ticks(3)
	var point := Vector3(-0.22,2.2,depth/2.0)
	var normal := Vector3.BACK
	if face == "bottom":
		point = Vector3(-0.22,2.08,minf(0.15,depth/4.0))
		normal = Vector3.DOWN
	elif face == "top":
		point = Vector3(-0.22,2.32,minf(0.15,depth/4.0))
		normal = Vector3.UP
	var requested: bool = controller.request_grip(0,hold,point,normal)
	await ticks(int(hz * 0.6))
	var attached: bool = controller.get_hand_state(0) == "ATTACHED"
	if dual and attached:
		point.x = 0.22
		controller.request_grip(1,hold,point,normal)
		await ticks(int(hz * 0.6))
	controller.set_climb_intent(1,0,bias)
	var peak_force := 0.0
	var hold_contacts := 0
	var ledge_contacts := 0
	var end_window_start := Vector3.ZERO
	for frame in 6 * hz:
		await physics_frame
		peak_force = maxf(peak_force,controller.get_arm_force(0).length()+controller.get_arm_force(1).length())
		for other in body.get_colliding_bodies():
			if other.name == "Hold":
				hold_contacts += 1
			if other.name == "Ledge":
				ledge_contacts += 1
		if frame == 5 * hz:
			end_window_start = body.position
	var before: Vector3 = body.position
	var row := {"label":label,"friction":friction,"depth":depth,"face":face,"dual":dual,"bias":bias,"requested":requested,"attached":attached,
		"position":str(body.position),"rotation":str(body.rotation),"speed":body.linear_velocity.length(),"end_drift":body.position.distance_to(end_window_start),
		"actual_length":controller.hands[0]["actual_length"],"rest_length":controller.hands[0]["rest_length"],"force":controller.get_arm_force(0).length(),
		"peak_force":peak_force,"hold_contact_frames":hold_contacts,"ledge_contact_frames":ledge_contacts,"state":controller.get_hand_state(0)}
	controller.set_climb_intent(0,1,0)
	await ticks(hz)
	row["extend_distance"] = body.position.distance_to(before)
	row["extend_y"] = body.position.y - before.y
	controller.release_grip(0)
	controller.release_grip(1)
	await ticks(hz)
	row["release_position"] = str(body.position)
	row["release_speed"] = body.linear_velocity.length()
	print("PLATFORM PROBE ",JSON.stringify(row))
	rows.append(row)
	check(requested and attached, label + " uses a real accessible surface and finite reach")
	check(peak_force <= 360.001, label + " force budget preserved")
	await clear()
	return row

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	for friction in [1.0,0.05]:
		await sample("front_one",friction,0.55,"front",false,0)
		await sample("front_dual",friction,0.55,"front",true,0)
		await sample("bottom",friction,0.55,"bottom",false,0)
		await sample("front_lean_A",friction,0.55,"front",false,-1)
		await sample("front_lean_D",friction,0.55,"front",false,1)
		await sample("top",friction,0.55,"top",false,0)
		await sample("ledge_side",friction,0.55,"front",false,-1,true)
	await sample("shallower_front",1.0,0.30,"front",false,-1)
	await sample("shallower_bottom",1.0,0.30,"bottom",false,0)
	for friction in [1.0,0.05]:
		await fallen_recovery(0,friction)
		await fallen_recovery(1,friction)
	print("PLATFORM PROBE RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
