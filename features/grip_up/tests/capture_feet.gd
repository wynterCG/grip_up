extends Node3D
## Rendered ON/OFF foot-support comparison driven through Godot MCP Pro.
var app
var report := {"complete":false,"runs":[]}

func _ready() -> void:
	app = get_parent()
	run.call_deferred()

func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func mouse(hand: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = app.camera.unproject_position(app.level.holds[hand].global_position)
	event.button_index = MOUSE_BUTTON_LEFT if hand==0 else MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	Input.parse_input_event(event.xformed_by(get_viewport().get_final_transform()))
	Input.flush_buffered_events()

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/m2_%dhz_" % Engine.physics_ticks_per_second+label+".png")

func compare(enabled: bool) -> Dictionary:
	app._set_physical_feet(enabled)
	app.load_test(3)
	await wait_seconds(0.5)
	mouse(0,true)
	mouse(1,true)
	await wait_seconds(0.6)
	var row := {"enabled":enabled,"hands_before":app.controller._attached_ids().size(),"samples":0,"hand_load":0.0,"leg_load":0.0,"planted_samples":0}
	Input.action_press("contract")
	await wait_seconds(1.0)
	Input.action_release("contract")
	await wait_seconds(0.4)
	for frame in Engine.physics_ticks_per_second:
		await get_tree().physics_frame
		row.samples += 1
		row.hand_load += app.controller.get_arm_force(0).length()+app.controller.get_arm_force(1).length()
		row.leg_load += float(app.controller.telemetry().leg_force)
		for foot in app.controller.feet_solver.feet:
			if foot.state=="SUPPORTING":
				row.planted_samples += 1
	row.hand_load /= row.samples
	row.leg_load /= row.samples
	row.position = str(app.torso.position)
	row.hands_after = app.controller._attached_ids().size()
	row.feet = []
	for foot in app.controller.feet_solver.feet:
		row.feet.append({"state":foot.state,"support":str(foot.support.name) if is_instance_valid(foot.support) else "","normal_force":foot.normal_force,"tangent_force":str(foot.tangent_force),"point":str(foot.contact_point),"ankle":str(foot.ankle),"reason":foot.reason})
	await shot("support_"+("on" if enabled else "off"))
	if enabled:
		app.debug_visible = true
		await shot("debug")
		app.debug_visible = false
	mouse(0,false)
	mouse(1,false)
	return row

func run() -> void:
	report.physics_hz = Engine.physics_ticks_per_second
	app._set_predictive_grip(false)
	app.capture_trace.path = "user://m2_rendered_capture_%dhz.jsonl" % Engine.physics_ticks_per_second
	app.capture_trace.enabled = true
	for enabled in [false,true]:
		report.runs.append(await compare(enabled))
	app.capture_trace.enabled = false
	app.capture_trace.close()
	report.complete = true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/feet_capture_%dhz.json" % Engine.physics_ticks_per_second,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	app.load_test(3)
	app.settings.show()
	await shot("controls")
	app.settings.hide()
	queue_free()
