extends Node3D
## Rendered arbitrary-surface route, driven through the same pointer API.
var report := {"complete":false,"steps":[]}
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	var app = get_parent()
	app.load_test(0)
	await get_tree().create_timer(0.5).timeout
	Input.action_press("contract")
	for step in 12:
		var hand: int = step%2
		if app.controller.get_hand_state(hand)=="ATTACHED":
			app.controller.release_grip(hand)
		var shoulder: Vector3 = app.controller.get_shoulder_world(hand)
		var point := Vector3(clampf(shoulder.x,-0.16,0.16),shoulder.y+0.32,0)
		app.pointer = app.camera.unproject_position(point)
		var accepted: bool = app.request_hand(hand)
		await get_tree().create_timer(0.65).timeout
		var attached: bool = app.controller.get_hand_state(hand)=="ATTACHED"
		report.steps.append({"requested":accepted,"attached":attached,"surface":str(app.controller.hands[hand].support),"point":str(point)})
		if not attached:
			break
		await get_tree().create_timer(1.0).timeout
		if step==5:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/free_climb.png")
		if app.won:
			break
	report.complete = true
	report.won = app.won
	report.position = str(app.torso.position)
	report.falls = app.trial.falls
	report.large_steps = app.trial.large_step_events
	FileAccess.open("C:/Users/Wynter/grip_up/builds/free_climb_capture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	Input.action_release("contract")
	app.load_test(0)
	queue_free()
