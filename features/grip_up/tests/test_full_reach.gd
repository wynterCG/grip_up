extends SceneTree
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var hz := 120
var checks := 0
var failures := 0

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):
		hz = 60
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func ticks(count: int) -> void:
	for frame in count:
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ",label)

func run() -> void:
	app = Lab.new()
	root.add_child(app)
	current_scene = app
	# A stationary geometry fixture isolates anatomical reach from catch momentum;
	# test_launch and test_biped_profile exercise gravity and dynamic grip loads.
	app.torso.freeze = true
	app.torso.position = Vector3(0,3,0.45)
	app.torso.reset_physics_interpolation()
	app.controller.reset_state()
	await ticks(3)
	var reach: float = app.controller.get_max_reach()
	check(absf(reach-(app.controller.tuning.skeletal_arm_length+app.controller.tuning.palm_contact_offset))<0.00001,"selection reach includes the complete measured arm and palm")
	check(app.controller.tuning.max_arm_length==0.62 and app.controller.tuning.max_elastic_extension==0.04,"full reach does not increase spring rest length or elastic stretch limits")
	var shoulder: Vector3 = app.controller.get_shoulder_world(0)
	var point := shoulder+Vector3.UP*reach
	var normal := Vector3(1,-0.001,0).normalized()
	var support := StaticBody3D.new()
	support.position = point-normal*0.03
	support.rotation.z = atan2(normal.y,normal.x)
	support.collision_layer = 2
	support.set_meta("grippable",true)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.06,2,2)
	collision.shape = shape
	support.add_child(collision)
	app.world.add_child(support)
	await ticks(3)
	check(app.controller.request_grip(0,support,point,normal),"a real visible surface at 100 percent extension is accepted")
	await ticks(int(0.6*hz))
	check(app.controller.get_hand_state(0)=="ATTACHED" and app.controller.get_hand_world(0).distance_to(point)<0.001,"glancing surface approach stays inside reach and completes without cancellation")
	var skeleton: Skeleton3D = app.biped.skeleton
	var measured: Dictionary = {}
	# Native SkeletonModifiers restore authored poses after evaluation; inspect
	# their result in modification_processed, like the existing rig regression.
	app.biped.hand_pose.modification_processed.connect(func():
		measured["wrist"] = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("hand_l")).origin)
		measured["upper"] = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("upperarm_l")).origin)
	)
	app.biped._update_targets()
	skeleton.advance(0.016)
	await process_frame
	await process_frame
	if measured.is_empty():
		check(false,"native rig modifiers produced a full-reach pose")
		print("FULL REACH RESULTS: %d checks, %d failures" % [checks,failures])
		quit(1)
		return
	var wrist: Vector3 = measured["wrist"]
	var upper: Vector3 = measured["upper"]
	check(absf(upper.distance_to(wrist)-app.controller.tuning.skeletal_arm_length)<0.001,"rendered wrist reaches the full chain length without stretching bones")
	print("FULL REACH RIG upper=",upper," wrist=",wrist," target=",app.biped.targets[0].global_position," error=",wrist.distance_to(app.biped.targets[0].global_position))
	check(wrist.distance_to(app.biped.targets[0].global_position)<0.002,"fully extended rendered hand meets the physical palm target")
	app.controller.release_grip(0)
	check(not app.controller.request_grip(0,support,point+Vector3.UP*0.01,normal) and app.controller.last_rejection=="out_of_reach","points beyond anatomical reach remain rejected")
	print("FULL REACH RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
