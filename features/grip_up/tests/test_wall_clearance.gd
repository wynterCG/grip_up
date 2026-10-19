extends SceneTree
## Frozen robot-scale regression fixture for the original shelf obstruction.
## The biped's anatomical clearance is exercised in test_biped_profile instead.
const Controller = preload("res://features/grip_up/scripts/climbing_controller.gd")
const Level = preload("res://features/grip_up/scripts/climb_test_level.gd")
var fixture: Node3D
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

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ",text)

func sample(old_shelves: bool) -> Dictionary:
	if is_instance_valid(fixture):
		fixture.free()
	fixture = Node3D.new()
	root.add_child(fixture)
	# Discard the playable layout and construct the frozen regression geometry.
	var level = Level.new()
	fixture.add_child(level)
	for child in level.get_children():
		child.free()
	level.holds.clear()
	level.box("Wall",Vector3(0,3,-0.65),Vector3(5.8,7,0.4),Color.WHITE)
	level.box("Start",Vector3(0,0.1,0.55),Vector3(4,0.3,2.8),Color.WHITE)
	for i in 6:
		var at := Vector3(-0.65 if i%2==0 else 0.65,1.95+i*0.78,0 if old_shelves else -0.4)
		if old_shelves:
			level.holds.append(level.box("OldShelf_%d"%i,at,Vector3(0.72,0.24,0.55),Color.WHITE,true))
		else:
			var hold := StaticBody3D.new()
			hold.position = at
			hold.collision_layer = 2
			hold.set_meta("grippable",true)
			var mesh := SphereMesh.new()
			mesh.radius = 0.18
			mesh.height = 0.24
			mesh.radial_segments = 16
			mesh.rings = 8
			var points := PackedVector3Array()
			for vertex in mesh.get_mesh_arrays()[Mesh.ARRAY_VERTEX]:
				points.append(vertex*Vector3(1,1,0.55))
			var shape := ConvexPolygonShape3D.new()
			shape.points = points
			var collision := CollisionShape3D.new()
			collision.shape = shape
			hold.add_child(collision)
			level.add_child(hold)
			level.holds.append(hold)
	var torso := RigidBody3D.new()
	torso.mass = 12
	torso.can_sleep = false
	torso.continuous_cd = true
	torso.collision_layer = 4
	torso.collision_mask = 3
	torso.linear_damp = 0.08
	torso.angular_damp = 0.35
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.05
	collision.shape = capsule
	torso.add_child(collision)
	fixture.add_child(torso)
	var controller := Controller.new()
	fixture.add_child(controller)
	# Align two holds for a direct ascent past the lower obstacle.
	level.holds[1].position.x = -0.65
	# Initial fixture only. From here the torso moves exclusively through physics.
	torso.position = Vector3(-0.65,1.0,0.55)
	controller.configure(torso)
	torso.contact_monitor = true
	torso.max_contacts_reported = 24
	await ticks(3)
	var target = level.holds[1]
	var shoulder: Vector3 = controller.get_shoulder_world(0)
	var toward: Vector3 = target.global_position
	if old_shelves:
		toward.z = 0.275
	var query := PhysicsRayQueryParameters3D.create(shoulder,toward+(toward-shoulder).normalized()*0.01,3,[torso.get_rid()])
	var hit: Dictionary = torso.get_world_3d().direct_space_state.intersect_ray(query)
	var accepted: bool = not hit.is_empty() and hit.collider == target and controller.request_grip(0,target,hit.position,hit.normal)
	await ticks(int(hz*0.5))
	var attached: bool = controller.get_hand_state(0)=="ATTACHED"
	controller.set_climb_intent(1,0,-1)
	var contacts := 0
	var bounded := true
	var peak_y: float = torso.position.y
	for i in 5*hz:
		await physics_frame
		peak_y = maxf(peak_y,torso.position.y)
		bounded = bounded and controller.get_arm_force(0).length()+controller.get_arm_force(1).length()<=360.001
		for body in torso.get_colliding_bodies():
			if body == level.holds[0]:
				contacts += 1
	controller.set_climb_intent(0,0,0)
	var result := {"old_shelves":old_shelves,"accepted":accepted,"attached":attached,"peak_y":peak_y,"final_y":torso.position.y,"contact_frames":contacts,"bounded":bounded,"position":str(torso.position)}
	print("CLEARANCE ",JSON.stringify(result))
	return result

func run() -> void:
	var old: Dictionary = await sample(true)
	var rounded: Dictionary = await sample(false)
	check(old.accepted and old.attached,"old shelf fixture acquires a real upper anchor")
	check(rounded.accepted and rounded.attached,"new climbing hold acquires a real upper anchor")
	check(old.contact_frames>0 and old.final_y<1.5,"aligned old shelves reproduce torso obstruction")
	check(rounded.peak_y>old.peak_y+0.1,"rounded profile reduces vertical obstruction on the same ascent input")
	check(rounded.contact_frames>0,"new holds retain real torso collisions")
	check(rounded.bounded,"clearance uses the unchanged shared force budget")
	print("WALL CLEARANCE RESULTS: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
