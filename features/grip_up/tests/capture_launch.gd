extends Node3D
var app
var report: Dictionary = {"complete":false}

func _ready() -> void:
	app = get_parent()
	app._set_input_profile(0) # Preserve this older baseline capture.
	run.call_deferred()

func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func launch_key(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = "launch"
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func wall_grip(hand: int, point: Vector3) -> bool:
	app.pointer = app.camera.unproject_position(point)
	return app.request_hand(hand)

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/launch_"+label+".png")

func run() -> void:
	app.load_test(0)
	await wait_seconds(0.5)
	Input.action_press("contract")
	for step in 6:
		var hand: int = step%2
		if app.controller.get_hand_state(hand)=="ATTACHED":
			app.controller.release_grip(hand)
		var shoulder: Vector3 = app.controller.get_shoulder_world(hand)
		wall_grip(hand,Vector3(clampf(shoulder.x,-0.16,0.16),shoulder.y+0.32,0))
		await wait_seconds(1.65)
	Input.action_release("contract")
	var start: Vector3 = app.torso.position
	var target := Vector3(-0.12,app.controller.get_shoulder_world(0).y+0.72,0)
	report.initial_reach = app.controller.get_shoulder_world(0).distance_to(target)
	report.reach_limit = app.controller.get_max_reach()
	launch_key(true)
	await wait_seconds(0.48)
	report.charged_position = str(app.torso.position)
	await shot("charged")
	launch_key(false)
	var peak_y: float = app.torso.position.y
	var peak_vy := 0.0
	var requested := false
	var caught := false
	var takeoff_shot := false
	for frame in 300:
		await get_tree().physics_frame
		peak_y = maxf(peak_y,app.torso.position.y)
		peak_vy = maxf(peak_vy,app.torso.linear_velocity.y)
		if not takeoff_shot and app.controller.get_hand_state(0)=="FREE":
			takeoff_shot = true
			await shot("flight")
		if not requested and app.controller.get_hand_state(0)=="FREE" and app.controller.get_shoulder_world(0).distance_to(target)<app.controller.get_max_reach()-0.005:
			requested = wall_grip(0,target)
		if requested and app.controller.get_hand_state(0)=="ATTACHED":
			caught = true
			break
	if caught:
		Input.action_press("contract")
		await wait_seconds(0.5)
		report.higher_grip_retained = app.controller.get_hand_state(0)=="ATTACHED"
		await shot("catch")
	Input.action_release("contract")
	report.complete = true
	report.start = str(start)
	report.peak_height_over_start = peak_y-start.y
	report.peak_upward_speed = peak_vy
	report.higher_grip_requested = requested
	report.higher_grip_caught = caught
	report.target = str(target)
	report.falls = app.trial.falls
	FileAccess.open("C:/Users/Wynter/grip_up/builds/launch_capture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	app.load_test(0)
	queue_free()
