extends SceneTree
const Solver = preload("res://features/grip_up/scripts/foot_contact_solver.gd")
const Profile = preload("res://features/grip_up/resources/foot_tuning.gd")
const Sampler = preload("res://features/grip_up/scripts/foothold_candidate_sampler.gd")
var world: Node3D
var torso: RigidBody3D
var solver: RefCounted
var settings: Resource
var hz := 120
var checks := 0
var failures := 0
var budgets := true
var unilateral := true
var no_early := true
var finite_gesture := true
var read_only := true
var sliding_seen := false
var contract := 0.0
var extend := 0.0
var active := true
var apply := false
var allow_new := true

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):
		hz = 60
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)

func fixture(at := Vector3(0,1.0,0), gravity := 0.0) -> void:
	torso = RigidBody3D.new()
	torso.position = at
	torso.mass = 12.0
	torso.gravity_scale = gravity
	torso.can_sleep = false
	torso.collision_layer = 4
	torso.collision_mask = 1
	torso.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	torso.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	torso.linear_damp = 0
	torso.angular_damp = 0
	torso.inertia = Vector3.ONE * 3.0
	var shape := SphereShape3D.new()
	shape.radius = 0.05
	var collision := CollisionShape3D.new()
	collision.shape = shape
	torso.add_child(collision)
	world.add_child(torso)
	settings = Profile.new()
	solver = Solver.new()
	var hips: Array[Vector3] = [Vector3(-0.1,0,0),Vector3(0.1,0,0)]
	var feet: Array[Vector3] = [Vector3(-0.1,-0.75,0),Vector3(0.1,-0.75,0)]
	var lengths: Array[float] = [0.83,0.83]
	var clearances: Array[float] = [0.10,0.10]
	solver.configure(torso,settings,hips,feet,lengths,clearances)
	active = true
	apply = false
	allow_new = true
	contract = 0
	extend = 0

func box(at: Vector3, size: Vector3, dynamic := false, friction := 0.85, rotation := Vector3.ZERO) -> PhysicsBody3D:
	var result: PhysicsBody3D = RigidBody3D.new() if dynamic else StaticBody3D.new()
	result.position = at
	result.rotation = rotation
	result.collision_layer = 1
	result.collision_mask = 0
	var material := PhysicsMaterial.new()
	material.friction = friction
	result.physics_material_override = material
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	result.add_child(collision)
	if dynamic:
		result.mass = 30
		result.gravity_scale = 0
		result.can_sleep = false
		result.inertia = Vector3.ONE * 5
		result.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		result.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		result.linear_damp = 0
		result.angular_damp = 0
	world.add_child(result)
	return result

func tick(scale := 1.0) -> void:
	await physics_frame
	if solver == null:
		return
	var pose := torso.global_transform
	var v := torso.linear_velocity
	var spin := torso.angular_velocity
	var previous: Array[Vector3] = []
	var states: Array[String] = []
	for foot in solver.feet:
		previous.append(foot.ankle)
		states.append(foot.state)
	var entries: Array = solver.prepare(1.0/hz,contract,extend,0,active,allow_new)
	read_only = read_only and torso.global_transform.is_equal_approx(pose) and torso.linear_velocity == v and torso.angular_velocity == spin
	var total := 0.0
	for entry in entries:
		total += entry.force.length()
		var foot: Dictionary = solver.feet[entry.id]
		var n: Vector3 = foot.normal
		var normal: float = entry.force.dot(n)
		var tangent: Vector3 = entry.force - n*normal
		var mu: float = minf(settings.foot_friction,entry.support.physics_material_override.friction)
		unilateral = unilateral and normal >= -0.0001 and tangent.length() <= mu*normal+0.0001
		no_early = no_early and foot.state in ["SUPPORTING","SLIDING"]
	budgets = budgets and total <= settings.total_force_budget+0.0001
	for id in solver.feet.size():
		sliding_seen = sliding_seen or solver.feet[id].state == "SLIDING"
		if states[id] == "PLANTING" or solver.feet[id].state == "PLANTING":
			finite_gesture = finite_gesture and previous[id].distance_to(solver.feet[id].ankle) <= settings.plant_speed/hz+0.00001
	if apply:
		solver.commit(scale)

func ticks(count: int, scale := 1.0) -> void:
	for frame in count:
		await tick(scale)

func clear() -> void:
	solver = null
	for child in world.get_children():
		child.queue_free()
	await physics_frame
	await physics_frame

func supporting() -> int:
	var result := 0
	for foot in solver.feet:
		if foot.state in ["SUPPORTING","SLIDING"]:
			result += 1
	return result

func force_sum() -> float:
	var result := 0.0
	for foot in solver.feet:
		result += foot.force.length()
	return result

func flat_and_controls() -> void:
	fixture()
	box(Vector3(0,0.1,0),Vector3(3,0.2,3))
	await ticks(hz/2)
	check(supporting()==2,"two independent current floor contacts plant")
	check(solver.feet[0].ankle.distance_to(solver.feet[0].contact_point+Vector3.UP*.1)<.00001,"ankle clearance differs from actual force contact")
	check(torso.linear_velocity.length()<.00001,"prepare alone applies no force")
	apply = true
	await ticks(1)
	check(force_sum()>10,"neutral preload generates finite compressive support")
	var before: float = solver.feet[0].rest_length
	contract=1
	await ticks(1)
	check(solver.feet[0].rest_length>before,"W lengthens bounded leg rest target")
	contract=0
	extend=1
	await ticks(1)
	check(solver.feet[0].rest_length<before+.001,"S unloads by shortening rest target")
	active=false
	await ticks(1)
	check(force_sum()==0 and solver.feet[0].state=="FREE","inactive releases both feet immediately")
	solver.reset()
	check(force_sum()==0 and supporting()==0,"reset removes all cached contact forces")
	check(not solver.set_free_foot_world(5,Vector3.ZERO),"invalid foot index rejected")
	check(not solver.set_free_foot_world(0,Vector3(INF,0,0)),"nonfinite passive endpoint rejected")
	check(not solver.set_free_foot_world(0,torso.position+Vector3.UP*2),"out of anatomy passive endpoint rejected")
	await clear()

func missing_and_occluded() -> void:
	fixture()
	var left := box(Vector3(-.32,.3,0),Vector3(.2,.2,.7))
	await ticks(hz/2)
	check(solver.feet[0].state=="SUPPORTING" and solver.feet[1].state=="SEARCHING","one missing foothold does not disable the other leg")
	left.queue_free()
	await ticks(2)
	check(supporting()==0,"disappearing support loses contact without residual force")
	await clear()
	fixture()
	box(Vector3(0,-1,0),Vector3(3,.2,3))
	await ticks(hz/3)
	check(supporting()==0,"floor beyond natural leg reach cannot plant")
	await clear()
	fixture()
	box(Vector3(0,.1,0),Vector3(3,.2,3))
	var blocker := box(Vector3(0,.65,0),Vector3(3,.1,3))
	blocker.set_meta("foot_support",false)
	await ticks(hz/3)
	check(supporting()==0,"occluding nonsupport geometry blocks legs and planting paths")
	await clear()

func sloped_and_wall() -> void:
	fixture()
	box(Vector3(0,.1,0),Vector3(3,.2,3),false,.85,Vector3(0,0,.18))
	await ticks(hz/2)
	check(supporting()==2,"sloped real surfaces plant independently")
	check(solver.feet[0].normal.dot(Vector3.UP)<.995,"surface normal is geometric rather than invented up")
	await clear()
	fixture(Vector3(0,1,.4))
	box(Vector3(0,.55,-.1),Vector3(3,1,.2),false,0.0)
	sliding_seen = false
	await ticks(hz/2)
	apply=true
	await ticks(2)
	check(supporting()>0,"vertical wall permits only compressive contact")
	var any_sliding := false
	var upward := 0.0
	for foot in solver.feet:
		any_sliding = any_sliding or foot.state=="SLIDING"
		upward += foot.force.y
	check(sliding_seen,"untransmissible tangential wall effort enters SLIDING then unloads")
	check(absf(upward)<.00001,"frictionless vertical wall gives zero upward support and no suction")
	await clear()

func budget_and_reaction() -> void:
	fixture()
	var platform := box(Vector3(0,.1,0),Vector3(3,.2,3),true)
	settings.contact_preload=.2
	settings.max_force_per_foot=500
	await ticks(hz/2)
	check(supporting()==2,"dynamic material body accepted")
	var entries: Array = solver.prepare(1.0/hz,1,0,0,true)
	var total := 0.0
	var f := Vector3.ZERO
	var m := Vector3.ZERO
	for entry in entries:
		total += entry.force.length()
		f += entry.force-entry.force
		m += entry.point.cross(entry.force)+entry.point.cross(-entry.force)
	check(total>179 and total<=180.0001,"global sum of leg force magnitudes clamps to 180N")
	check(f.length()<.00001 and m.length()<.00001,"same-point force pairs conserve full external wrench")
	var initial_p: Vector3 = torso.linear_velocity*torso.mass+platform.linear_velocity*platform.mass
	var initial_l: Vector3 = torso.position.cross(torso.linear_velocity*torso.mass)+platform.position.cross(platform.linear_velocity*platform.mass)+torso.angular_velocity*3+platform.angular_velocity*5
	solver.commit(.5)
	var applied := force_sum()
	solver.commit(1)
	check(absf(force_sum()-applied)<.00001 and applied<=90.001,"commit scale bounded and duplicate commit cannot apply twice")
	await physics_frame
	await physics_frame
	var final_p: Vector3 = torso.linear_velocity*torso.mass+platform.linear_velocity*platform.mass
	var final_l: Vector3 = torso.position.cross(torso.linear_velocity*torso.mass)+platform.position.cross(platform.linear_velocity*platform.mass)+torso.angular_velocity*3+platform.angular_velocity*5
	check(torso.linear_velocity.y>0 and platform.linear_velocity.y<0,"actual Jolt bodies receive opposite leg reaction")
	check(final_p.distance_to(initial_p)<.0001,"actual paired impulses conserve linear momentum")
	check(final_l.distance_to(initial_l)<.001,"actual paired impulses conserve angular momentum")
	print("MEASURE reaction momentum_error=",final_p.distance_to(initial_p)," angular_error=",final_l.distance_to(initial_l))
	await clear()

func moving_and_unloaded() -> void:
	fixture()
	var platform := box(Vector3(0,.1,0),Vector3(3,.2,3),true)
	platform.linear_velocity=Vector3(.1,0,0)
	platform.angular_velocity=Vector3(0,.15,0)
	await ticks(hz/2)
	check(supporting()==2,"translating rotating support remains locally sticky")
	var foot: Dictionary = solver.feet[0]
	var expected: Vector3 = platform.to_global(foot.local_point)
	check(foot.contact_point.distance_to(expected)<.00001,"contact follows actual support transform")
	var exact: Vector3 = platform.linear_velocity+platform.angular_velocity.cross(foot.contact_point-Solver.center_of_mass(platform))
	check(Solver.point_velocity(platform,foot.contact_point).distance_to(exact)<.00001,"contact damping includes support angular point velocity")
	for entry in solver._pending:
		check(entry.force.is_finite(),"moving support force remains finite")
	await clear()

func loaded_step() -> void:
	fixture(Vector3(0,1,0),1.0)
	box(Vector3(0,.1,0),Vector3(3,.2,3))
	apply = true
	await ticks(hz*2)
	check(supporting()==2 and torso.position.y>.90 and torso.linear_velocity.length()<.05,"actual 12kg body settles on finite leg compression under gravity")
	check(absf(force_sum()-12*9.81)<4,"neutral legs carry measured gravity load without hand forces")
	var initial := torso.position.y
	contract = 1
	var work := 0.0
	for frame in hz/2:
		await tick()
		for foot in solver.feet:
			work += maxf(0.0,foot.force.dot(Solver.point_velocity(torso,foot.contact_point)))/hz
	check(torso.position.y>initial+.05 and work>.05,"bounded W leg extension does actual positive upward work")
	print("MEASURE loaded_leg rise=",torso.position.y-initial," work=",work," final_force=",force_sum())
	await clear()
	fixture(Vector3(0,1.17,.4))
	box(Vector3(0,.15,.5),Vector3(4,.2,3))
	box(Vector3(0,1,-.15),Vector3(4,3,.3))
	box(Vector3(-.31,.49,.12),Vector3(.2,.2,.4))
	box(Vector3(.31,.49,.12),Vector3(.2,.2,.4))
	await ticks(hz)
	check(supporting()==2 and solver.feet[0].normal.y>.9 and solver.feet[0].contact_point.y>.58,"real raised ledges preferred over nearby wall/floor")
	check(solver.feet[0].ankle.x<-.20 and solver.feet[1].ankle.x>.20,"independent lateral step search finds outside footholds")
	await clear()

func offcenter_reaction() -> void:
	fixture()
	var platform := box(Vector3(-.32,.1,0),Vector3(.2,.2,.7),true)
	await ticks(hz/2)
	check(supporting()==1,"reaction fixture isolates an eccentric single leg")
	var p0: Vector3 = torso.linear_velocity*12+platform.linear_velocity*30
	var l0: Vector3 = torso.position.cross(torso.linear_velocity*12)+platform.position.cross(platform.linear_velocity*30)+torso.angular_velocity*3+platform.angular_velocity*5
	solver.commit(1)
	await physics_frame
	await physics_frame
	var p1: Vector3 = torso.linear_velocity*12+platform.linear_velocity*30
	var l1: Vector3 = torso.position.cross(torso.linear_velocity*12)+platform.position.cross(platform.linear_velocity*30)+torso.angular_velocity*3+platform.angular_velocity*5
	check(torso.angular_velocity.length()>.00001,"eccentric contact creates real torso rotation rather than central thrust")
	check(p1.distance_to(p0)<.0001 and l1.distance_to(l0)<.001,"eccentric dynamic force pair conserves linear and angular momentum")
	await clear()

func contact_independence() -> void:
	fixture()
	var left := box(Vector3(-.32,.1,0),Vector3(.2,.2,.7))
	allow_new = false
	await ticks(hz/3)
	check(supporting()==0 and solver.feet[0].state=="FREE","hands-free mode never begins a new automatic plant")
	allow_new = true
	await ticks(hz/2)
	check(supporting()==1,"left foot can plant without right support")
	allow_new = false
	box(Vector3(.32,.1,0),Vector3(.2,.2,.7))
	await ticks(hz/3)
	check(solver.feet[0].state=="SUPPORTING" and solver.feet[1].state=="FREE","hands-free stance preserves existing foot without acquiring the other")
	left.collision_layer=0
	await ticks(1)
	check(supporting()==0,"disabling support collision loses plant immediately")
	await clear()
	fixture()
	box(Vector3(0,.1,0),Vector3(3,.2,3))
	await ticks(hz/2)
	for leg in solver.feet:
		leg.rest_length=.4
	apply=true
	await ticks(1)
	check(force_sum()==0,"unloaded overlong leg never pulls or brakes its support")
	await clear()

func run() -> void:
	world=Node3D.new()
	root.add_child(world)
	await flat_and_controls()
	await missing_and_occluded()
	await sloped_and_wall()
	await budget_and_reaction()
	await moving_and_unloaded()
	await loaded_step()
	await offcenter_reaction()
	await contact_independence()
	check(budgets,"every fixture obeys leg magnitude budget")
	check(unilateral,"every force obeys unilateral friction cone")
	check(no_early,"no force while FREE SEARCHING or PLANTING")
	check(finite_gesture,"plant gestures obey 2m/s including final contact frame")
	check(read_only,"prepare never changes torso pose or velocities")
	print("FOOT SUPPORT RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
