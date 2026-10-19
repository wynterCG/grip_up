extends Node3D
## Developer-only visual QA, launched through Godot MCP Pro; excluded from export.
var app: Node3D
var report: Dictionary = {}

func _ready() -> void:
	app = get_parent()
	run.call_deferred()

func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func acquire(support: PhysicsBody3D, hand: int, local := Vector3.ZERO) -> bool:
	for frame in 720:
		if app.controller.get_hand_state(hand)=="ATTACHED":
			return app.controller.hands[hand].support == support
		if app.controller.get_hand_state(hand)=="FREE" and frame%6==0:
			var query := PhysicsRayQueryParameters3D.create(app.controller.get_shoulder_world(hand),support.to_global(local),3,[app.torso.get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider==support:
				app.controller.request_grip(hand,support,hit.position,hit.normal)
		await get_tree().physics_frame
	return false

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/biped_"+label+".png")
	report[label] = {"states":[app.controller.get_hand_state(0),app.controller.get_hand_state(1)],"body":str(app.torso.position),"body_down":str(-app.torso.global_basis.y),"leg_directions":str(app.biped.leg_motion.directions),"leg_lengths":str(app.biped.leg_motion.current_lengths),"beam_rotation":app.level.beam.rotation.z if is_instance_valid(app.level.beam) else 0.0}
	FileAccess.open("C:/Users/Wynter/grip_up/builds/biped_visual_capture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))

func run() -> void:
	report = {"complete":false,"revision":"twist stabilization / smooth arm intent / authored ground gait / suspended leg inertia"}
	FileAccess.open("C:/Users/Wynter/grip_up/builds/biped_visual_capture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	app.load_test(0)
	await wait_seconds(0.5)
	Input.action_press("contract")
	await acquire(app.level.holds[0],0)
	await wait_seconds(1.2)
	await acquire(app.level.holds[1],1)
	await wait_seconds(1.2)
	Input.action_release("contract")
	await shot("static_dual")
	app.load_test(1)
	await wait_seconds(0.5)
	await acquire(app.level.holds[0],0)
	await wait_seconds(0.4)
	Input.action_press("contract")
	Input.action_press("bias_right")
	await acquire(app.level.holds[1],1,Vector3(-0.09,-0.05,0.04))
	app.controller.release_grip(0)
	Input.action_release("bias_right")
	await wait_seconds(0.35)
	await shot("swing")
	await wait_seconds(0.35)
	await shot("swing_late")
	Input.action_release("contract")
	app.load_test(2)
	await wait_seconds(0.5)
	var beam: RigidBody3D = app.level.beam
	await acquire(beam,1,Vector3(0.3,0,0.13))
	Input.action_press("contract")
	await wait_seconds(2.5)
	await acquire(beam,0,Vector3(0.45,-0.08,0.04))
	await wait_seconds(0.5)
	Input.action_release("contract")
	await shot("reactive_dual")
	app.load_test(0)
	report.complete = true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/biped_visual_capture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	queue_free()
