extends Node3D
## Rendered comparison launched by Godot MCP Pro. Never shipped in the export.
var app
var report := {"complete":false,"runs":[]}

func _ready() -> void:
	app = get_parent()
	app._set_input_profile(0) # Preserve this older baseline capture.
	run.call_deferred()

func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func action(action_name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click(hand: int, point: Vector3, pressed: bool) -> void:
	app.pointer = app.camera.unproject_position(point)
	var event := InputEventMouseButton.new()
	event.position = app.pointer
	event.button_index = MOUSE_BUTTON_LEFT if hand==0 else MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	Input.parse_input_event(event.xformed_by(get_viewport().get_final_transform()))
	Input.flush_buffered_events()

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/m1_%dhz_" % Engine.physics_ticks_per_second+label+".png")

func route(enabled: bool) -> Dictionary:
	app._set_predictive_grip(false)
	app.load_test(0)
	await wait_seconds(0.5)
	Input.action_press("contract")
	for step in 6:
		var hand: int = step%2
		app.controller.release_grip(hand)
		var shoulder: Vector3 = app.controller.get_shoulder_world(hand)
		app.pointer = app.camera.unproject_position(Vector3(clampf(shoulder.x,-0.16,0.16),shoulder.y+0.32,0))
		app.request_hand(hand)
		await wait_seconds(1.65)
	Input.action_release("contract")
	app._set_predictive_grip(enabled)
	var target := Vector3(-0.12,app.controller.get_shoulder_world(0).y+0.72,0)
	var row := {"enabled":enabled,"target":str(target),"initial_distance":app.controller.get_shoulder_world(0).distance_to(target),"requested":false,"caught":false,"retained":false,"entry":-1.0,"arrival":-1.0}
	action("launch",true)
	await wait_seconds(0.48)
	action("launch",false)
	var clicked := false
	for frame in 180:
		await get_tree().physics_frame
		if not clicked and app.controller.get_hand_state(0) in ["ATTACHED","SLIPPING"]:
			continue
		var candidate: Dictionary = app.targeting.candidate(app.camera,app.camera.unproject_position(target),app.torso)
		if candidate.is_empty():
			continue
		var forecast: Dictionary = app.controller.capture_predictor.evaluate(app.controller,0,candidate.collider,candidate.position,candidate.normal)
		if not clicked and forecast.status=="SOON" and forecast.predicted_entry_time<=0.15:
			clicked = true
			row.requested = true
			row.entry = forecast.predicted_entry_time
			row.distance_at_input = app.controller.get_shoulder_world(0).distance_to(candidate.position)
			row.forecast = forecast
			click(0,target,true)
			row.accepted = app.controller.get_hand_state(0)=="REACHING"
			row.rejection = app.controller.last_rejection
			await shot("early_"+("on" if enabled else "off"))
		if clicked and app.controller.get_hand_state(0)=="ATTACHED":
			row.caught = true
			row.arrival = app.controller.hands[0].capture.get("actual_arrival",-1.0)
			break
	if row.caught:
		Input.action_press("contract")
		await wait_seconds(1.0)
		row.retained = app.controller.get_hand_state(0)=="ATTACHED"
		app.rating_panel.hide()
		await shot("retained_"+("on" if enabled else "off"))
	row.final_state = app.controller.get_hand_state(0)
	row.failure = app.controller.hands[0].get("capture",{}).get("failure_reason","")
	click(0,target,false)
	Input.action_release("contract")
	return row

func run() -> void:
	report.physics_hz = Engine.physics_ticks_per_second
	app.capture_trace.path = "user://m1_rendered_capture_%dhz.jsonl" % Engine.physics_ticks_per_second
	app.capture_trace.enabled = true
	for enabled in [false,true]:
		report.runs.append(await route(enabled))
	app.capture_trace.enabled = false
	app.capture_trace.close()
	report.complete = true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/predictive_capture_%dhz.json" % Engine.physics_ticks_per_second,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	app.load_test(0)
	app._set_predictive_grip(true)
	queue_free()
