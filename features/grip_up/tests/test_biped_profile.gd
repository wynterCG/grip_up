extends SceneTree
const MODEL = "res://features/grip_up/assets/characters/quaternius_mannequin/mannequin.glb"
const Profile = preload("res://features/grip_up/resources/biped_tuning.gd")
const Controller = preload("res://features/grip_up/scripts/climbing_controller.gd")
var world: Node3D
var controller: Node
var profile = Profile.new()
var checks := 0
var failures := 0
var hz := 120

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
	for frame in count:
		await physics_frame

func clear() -> void:
	if is_instance_valid(controller):
		controller.reset_state()
	for child in world.get_children():
		child.queue_free()
	await ticks(3)

func box(at: Vector3, size: Vector3, dynamic := false, mass := 12.0) -> PhysicsBody3D:
	var item: PhysicsBody3D = RigidBody3D.new() if dynamic else StaticBody3D.new()
	item.position = at
	item.set_meta("grippable",true)
	item.set_meta("grip_load_limit",460.0)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	item.add_child(collision)
	if dynamic:
		item.mass = mass
		item.continuous_cd = true
	world.add_child(item)
	return item

func body_at(at: Vector3, friction: float = 0.12, compound: bool = true) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.position = at
	body.mass = profile.body_mass
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = profile.body_center_of_mass
	body.continuous_cd = true
	body.can_sleep = false
	body.contact_monitor = true
	body.max_contacts_reported = 16
	body.linear_damp = 0.08
	body.angular_damp = 0.35
	var material := PhysicsMaterial.new()
	material.friction = friction
	body.physics_material_override = material
	if compound:
		for dimensions in [Vector3(profile.torso_capsule_height,profile.torso_capsule_radius,profile.torso_capsule_center_y),Vector3(profile.leg_capsule_height,profile.leg_capsule_radius,profile.leg_capsule_center_y)]:
			var shape := CapsuleShape3D.new()
			shape.height = dimensions.x
			shape.radius = dimensions.y
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position.y = dimensions.z
			body.add_child(collision)
		var head := SphereShape3D.new()
		head.radius = profile.head_radius
		var collision := CollisionShape3D.new()
		collision.shape = head
		collision.position.y = profile.head_center_y
		body.add_child(collision)
		var sole := BoxShape3D.new()
		sole.size = profile.foot_base_size
		var sole_collision := CollisionShape3D.new()
		sole_collision.shape = sole
		sole_collision.position = profile.foot_base_offset
		body.add_child(sole_collision)
	else:
		var shape := CapsuleShape3D.new()
		shape.height = profile.capsule_height
		shape.radius = profile.capsule_radius
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
	world.add_child(body)
	controller = Controller.new()
	world.add_child(controller)
	controller.configure(body,profile)
	return body

func acquire(id: int, support: PhysicsBody3D, point: Vector3, normal := Vector3.BACK) -> bool:
	if not controller.request_grip(id,support,point,normal):
		print("BIPED REJECT ",controller.last_rejection," point=",point," shoulder=",controller.get_shoulder_world(id))
		return false
	for frame in int(hz * 0.7):
		await physics_frame
		if controller.get_hand_state(id) == "ATTACHED":
			return true
	print("BIPED REACH FAIL ",controller.get_hand_state(id)," ",controller.hands[id]["reason"])
	return false

func model_measurements() -> void:
	var model: Node3D = load(MODEL).instantiate()
	world.add_child(model)
	var skeleton: Skeleton3D = model.find_children("*","Skeleton3D",true,false)[0]
	var upper: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("upperarm_l")).origin
	var elbow: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("lowerarm_l")).origin
	var wrist: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("hand_l")).origin
	var actual_length: float = upper.distance_to(elbow) + elbow.distance_to(wrist)
	var alignment := Transform3D(Basis(Vector3.UP,profile.model_y_rotation),profile.model_visual_offset)
	check((alignment*upper).distance_to(profile.shoulder_left) < 0.0001,"physical left shoulder matches transformed skeleton upperarm root")
	check(absf(actual_length-profile.skeletal_arm_length)<0.0001,"measured upper arm plus forearm equals 0.54708m")
	check(profile.max_arm_length+profile.max_elastic_extension <= actual_length+profile.palm_contact_offset+0.003,"entire attached range fits anatomical wrist chain plus palm")
	check(absf(profile.capsule_height/2.0+profile.model_visual_offset.y)<0.01,"whole-body capsule floor matches model feet within 1cm")
	print("BIPED MEASURE upper=",upper.distance_to(elbow)," lower=",elbow.distance_to(wrist)," palm_max=",actual_length+profile.palm_contact_offset," shoulders=",profile.shoulder_left," / ",profile.shoulder_right)
	if OS.get_cmdline_user_args().has("--measure"):
		for index in skeleton.get_bone_count():
			print("BONE ",skeleton.get_bone_name(index)," rest=",skeleton.get_bone_global_rest(index).origin)
	await clear()

func round_hold(at: Vector3, small: bool = false) -> StaticBody3D:
	var item := StaticBody3D.new()
	item.position = at
	item.set_meta("grippable",true)
	item.set_meta("grip_load_limit",460.0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.09 if small else 0.18
	mesh.height = 0.12 if small else 0.24
	mesh.radial_segments = 16
	mesh.rings = 8
	var points := PackedVector3Array()
	for vertex in mesh.get_mesh_arrays()[Mesh.ARRAY_VERTEX]:
		points.append(vertex*Vector3(1,1,0.55))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	item.add_child(collision)
	world.add_child(item)
	return item

func real_surface(support: PhysicsBody3D,id: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(controller.get_shoulder_world(id),support.global_position)
	query.exclude = [controller.torso.get_rid()]
	return controller.torso.get_world_3d().direct_space_state.intersect_ray(query)

func grounded_contraction(dual: bool, rounded: bool = false, friction: float = 1.0, compound: bool = false) -> void:
	box(Vector3(0,0.1,0.4),Vector3(4,0.3,3))
	box(Vector3(0,2,-0.2),Vector3(4,5,0.4))
	var hold: PhysicsBody3D = round_hold(Vector3(-0.22,2,0.05)) if rounded else box(Vector3(0,2,0.1),Vector3(0.8,0.12,0.12))
	var hold_b: PhysicsBody3D = round_hold(Vector3(0.22,2,0.05)) if rounded else hold
	var body := body_at(Vector3(0,1.17,0.4),friction,compound)
	await ticks(4)
	var hit: Dictionary = real_surface(hold,0)
	check(await acquire(0,hold,hit.position,hit.normal),"biped finite grounded first reach")
	if dual:
		hit = real_surface(hold_b,1)
		check(await acquire(1,hold_b,hit.position,hit.normal),"biped second hand attaches independently")
	controller.set_climb_intent(1,0,0)
	var bounded := true
	var peak_length := 0.0
	for frame in 2*hz:
		await physics_frame
		bounded = bounded and controller.telemetry()["total_force"] <= 360.001 and controller.telemetry()["torque"].length() <= 150.001
		for hand in controller.hands:
			if hand["state"] in ["ATTACHED","SLIPPING"]:
				peak_length = maxf(peak_length,hand["actual_length"])
	print("BIPED GROUNDED dual=",dual," rounded=",rounded," compound=",compound," mu=",friction," pelvis=",body.position," state=",controller.get_hand_state(0)," actual=",controller.hands[0]["actual_length"]," rest=",controller.hands[0]["rest_length"]," peak=",peak_length)
	if friction < 0.5 and dual:
		check(body.position.y>(1.20 if compound else 1.25) and controller.get_hand_state(0)=="ATTACHED","natural-length biped contraction lifts body against gravity")
	elif friction < 0.5:
		check(controller.get_hand_state(0)=="ATTACHED" and controller.hands[0]["actual_length"] < 0.25,"single low first hold settles at a supported near-minimum arm length")
	else:
		check(body.position.y<1.25,"broad high-friction whole capsule is the obstructed control fixture")
	print("BIPED NEXT reach=",controller.get_shoulder_world(1).distance_to(Vector3(0.22,2.30,0.15)))
	check(bounded and peak_length<=0.66+0.005,"biped force/torque budget and anatomical maximum remain bounded")
	await clear()

func loaded_maximum(blend: bool) -> void:
	var body := body_at(Vector3(0,3,0.4))
	body.gravity_scale = 0
	var point: Vector3 = controller.get_shoulder_world(0) + Vector3(0,0.60,-0.08)
	var hold := box(point-Vector3(0,0,0.03),Vector3(0.4,0.12,0.06))
	check(await acquire(0,hold,point),"near-maximum natural arm reaches in finite time")
	if not blend:
		await ticks(int(hz*0.2))
	body.gravity_scale = 1
	var peak := 0.0
	for frame in hz:
		await physics_frame
		peak = maxf(peak,controller.hands[0]["actual_length"])
	print("BIPED MAX blend_active=",blend," peak=",peak," state=",controller.get_hand_state(0)," reason=",controller.hands[0]["reason"])
	check(controller.get_hand_state(0)=="ATTACHED" and peak<=0.665,"single 12kg hang including fresh blend stays within palm length")
	await clear()

func dynamic_reaction() -> void:
	var body := body_at(Vector3(0,3,0.4))
	body.gravity_scale = 0
	body.linear_damp = 0
	body.angular_damp = 0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	var point: Vector3 = controller.get_shoulder_world(0)+Vector3(0,0.43,-0.08)
	var support: RigidBody3D = box(point-Vector3(0,0,0.03),Vector3(0.5,0.12,0.06),true,10)
	support.gravity_scale = 0
	support.linear_damp = 0
	support.angular_damp = 0
	support.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	support.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	check(await acquire(0,support,point),"biped moving support uses same finite anchor API")
	var initial: Vector3 = support.position
	controller.set_climb_intent(1,0,0)
	await ticks(int(hz*0.35))
	var momentum: Vector3 = body.linear_velocity*body.mass+support.linear_velocity*support.mass
	check(support.position.y<initial.y-0.01 and momentum.length()<0.02,"short biped arms transmit actual opposite support reaction")
	print("BIPED DYNAMIC support_dy=",support.position.y-initial.y," momentum=",momentum.length()," state=",controller.get_hand_state(0))
	await clear()

func static_six() -> void:
	box(Vector3(0,0.1,0.4),Vector3(4,0.3,3))
	box(Vector3(0,2,-0.2),Vector3(4,5,0.4))
	var holds: Array[PhysicsBody3D] = []
	for index in 6:
		holds.append(round_hold(Vector3(-0.34 if index%2==0 else 0.34,2.15+index*0.22,0.10),true))
	var body := body_at(Vector3(0,1.17,0.4))
	await ticks(4)
	controller.set_climb_intent(1,0,0)
	var previous := -1
	for index in 6:
		var id: int = index%2
		if controller.get_hand_state(id)=="ATTACHED":
			controller.release_grip(id)
		var obtained := false
		for frame in 6*hz:
			if controller.get_hand_state(id)=="ATTACHED":
				obtained = true
				break
			if controller.get_hand_state(id)=="FREE" and frame%4==0:
				var hit: Dictionary = real_surface(holds[index],id)
				if not hit.is_empty() and hit.collider==holds[index] and controller.get_shoulder_world(id).distance_to(hit.position)<0.61:
					controller.request_grip(id,holds[index],hit.position,hit.normal)
			await physics_frame
		check(obtained,"natural biped alternating static hold%d" % (index+1))
		if not obtained:
			print("BIPED STATIC FAIL index=",index," body=",body.position," rot=",body.rotation," shoulder=",controller.get_shoulder_world(id)," state=",controller.get_hand_state(id)," reason=",controller.hands[id]["reason"]," OTHER=",controller.hands[1-id]," CONTACTS=",body.get_colliding_bodies())
			break
		previous = id
		await ticks(int(1.2*hz))
		print("BIPED STATIC hold=",index+1," pelvis=",body.position," state=",controller.get_hand_state(id))
	check(body.position.y>2.25,"six .22m static steps finish using anatomy-sized arms")
	await clear()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	await model_measurements()
	await grounded_contraction(false)
	await grounded_contraction(true)
	await grounded_contraction(true,true)
	await grounded_contraction(true,true,0.12)
	await grounded_contraction(true,false,0.12)
	await grounded_contraction(true,true,1.0,true)
	await grounded_contraction(true,false,1.0,true)
	await grounded_contraction(false,true,1.0,true)
	await grounded_contraction(true,true,0.12,true)
	await grounded_contraction(true,false,0.12,true)
	await grounded_contraction(false,true,0.12,true)
	await loaded_maximum(false)
	await loaded_maximum(true)
	await dynamic_reaction()
	await static_six()
	print("BIPED PROFILE RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
