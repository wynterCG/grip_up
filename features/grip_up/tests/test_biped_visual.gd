extends SceneTree
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var checks := 0
var failures := 0
var measured: Dictionary = {}

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):
		Engine.physics_ticks_per_second = 60
	run.call_deferred()

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ",label)

func sample() -> void:
	var visual = app.biped
	var skeleton: Skeleton3D = visual.skeleton
	for i in 2:
		var suffix := "l" if i == 0 else "r"
		var shoulder := skeleton.get_bone_global_pose(skeleton.find_bone("upperarm_" + suffix))
		var elbow := skeleton.get_bone_global_pose(skeleton.find_bone("lowerarm_" + suffix))
		var wrist := skeleton.get_bone_global_pose(skeleton.find_bone("hand_" + suffix))
		measured[i] = {"shoulder":skeleton.to_global(shoulder.origin),"wrist":skeleton.to_global(wrist.origin),"upper":shoulder.origin.distance_to(elbow.origin),"lower":elbow.origin.distance_to(wrist.origin)}

func run() -> void:
	app = Lab.new()
	root.add_child(app)
	current_scene = app
	app.biped.hand_pose.modification_processed.connect(sample)
	await ticks(90)
	check(app.torso.name == "BipedTorso" and app.biped.skeleton.get_bone_count() == 65,"playable scene instantiates the skinned biped")
	check(app.torso.get_children().filter(func(n):return n is CollisionShape3D).size()==4,"one dynamic torso uses head/torso/legs proxies and a flat foot base")
	check(app.biped.animation.is_playing() and app.biped.animation_clip=="Idle" and app.biped.ik.influence<0.001,"grounded biped uses authored idle with physical IK blended out")
	# Explicit modifier evaluation also makes this test independent of render FPS.
	app.biped._update_targets()
	app.biped.skeleton.advance(0.016)
	check(measured.size()==2,"arm IK and palm modifiers execute")
	for i in measured:
		check(absf(measured[i].upper-0.27444)<0.002 and absf(measured[i].lower-0.27264)<0.002,"IK preserves authored bone lengths: %d" % i)
		print("RIG ",i," measured=",measured[i]," target=",app.biped.targets[i].global_position)
	var hold: PhysicsBody3D = app.level.holds[0]
	var from: Vector3 = app.controller.get_shoulder_world(0)
	var ray := PhysicsRayQueryParameters3D.create(from,hold.global_position,3,[app.torso.get_rid()])
	var hit: Dictionary = app.torso.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and app.controller.request_grip(0,hold,hit.position,hit.normal),"biped acquires an actual surface using existing physical core")
	await ticks(90)
	app.biped._update_targets()
	app.biped.skeleton.advance(0.016)
	check(app.controller.get_hand_state(0)=="ATTACHED","biped reaches and holds with finite physical arm")
	check(app.biped.animation_clip=="A_TPose" and app.biped.ik.influence>0.999,"physical endpoint IK takes over after reaching starts")
	for i in measured:
		check(measured[i].shoulder.distance_to(app.controller.get_shoulder_world(i))<0.006,"climbing mesh and physical shoulder agree: %d" % i)
	if measured.has(0):
		check(measured[0].wrist.distance_to(app.biped.targets[0].global_position)<0.015,"attached wrist follows controller palm target")
	var body_transform: Transform3D = app.torso.transform
	var velocity: Vector3 = app.torso.linear_velocity
	app.biped._update_targets()
	app.biped.skeleton.advance(0.016)
	check(app.torso.transform==body_transform and app.torso.linear_velocity==velocity,"evaluating visual IK never edits torso transform or velocity")
	app.controller.release_grip(0)
	await ticks(30)
	check(app.controller.get_hand_state(0)=="FREE","released hand returns to finite-speed physical free state")
	var old_visual = app.biped
	app.load_test(0)
	await ticks(3)
	check(not is_instance_valid(old_visual),"reset frees old rig and its controller references")
	print("BIPED VISUAL RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
