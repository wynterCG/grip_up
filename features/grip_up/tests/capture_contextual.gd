extends Node
## Native relative-input run, started via Godot MCP Pro; no body writes.
var app
var hz := 120
var report := {"complete":false,"checks":[],"snapshots":[]}

func _ready() -> void:
	app=get_parent()
	hz=Engine.physics_ticks_per_second
	run.call_deferred()

func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func check(ok: bool,label: String) -> void:
	report.checks.append({"passed":ok,"label":label})

func move(raw: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=Vector2(960,540)
	event.relative=raw
	event.screen_relative=raw
	Input.parse_input_event(event.xformed_by(get_viewport().get_final_transform()))
	Input.flush_buffered_events()

func button(id: MouseButton,pressed: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=Vector2(960,540)
	event.button_index=id
	event.pressed=pressed
	Input.parse_input_event(event.xformed_by(get_viewport().get_final_transform()))
	Input.flush_buffered_events()

func aim_at(id: int,point: Vector3) -> void:
	var axes: Basis=app.contextual.frame(app.camera)
	var shoulder: Vector3=app.controller.get_shoulder_world(id)
	var plane:=Plane(axes.z,shoulder-axes.z*app.controller.get_max_reach()*.35)
	var intersection: Vector3=plane.intersects_ray(app.camera.global_position,(point-app.camera.global_position).normalized())
	var relative:=intersection-shoulder
	var offset:=Vector2(relative.dot(axes.x),relative.y)
	var delta: Vector2=offset-app.contextual.offsets[id]
	move(Vector2(delta.x,-delta.y)/app.contextual.sensitivity)

func shot(label: String) -> void:
	var row := {"label":label,"position":str(app.torso.position),"owner":app._control_owner(),"mouse_mode":Input.mouse_mode,"hands":[],"input":app.contextual.diagnostics()}
	for hand in app.controller.hands:
		row.hands.append({"state":hand.state,"target":hand.rest_length,"actual":hand.actual_length,"force":Vector3(hand.force).length()})
	report.snapshots.append(row)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/contextual_%dhz_%s.png" % [hz,label])

func run() -> void:
	report.physics_hz=hz
	check(app.input_profile==2 and app.controller.control_profile==2,"native startup selects contextual arms")
	check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"native game captures relative mouse without a screen-edge cursor")
	app.load_test(3)
	app.capture_trace.path="user://contextual_rendered_%dhz.jsonl" % hz
	app.capture_trace.enabled=true
	await wait_seconds(.5)
	move(Vector2.ZERO)
	aim_at(0,app.level.holds[0].global_position)
	await wait_seconds(.15)
	await shot("free_aim")
	button(MOUSE_BUTTON_LEFT,true)
	await wait_seconds(.4)
	check(app.controller.get_hand_state(0)=="ATTACHED","virtual L raycast and held button acquire actual contact")
	var start: float=app.torso.position.y
	for step in 60:
		move(Vector2(0,5))
		await wait_seconds(.016)
	await wait_seconds(.25)
	report.rise_m=app.torso.position.y-start
	check(report.rise_m>.04,"relative downward drag produces actual supported rise")
	var contracted: float=app.controller.hands[0].rest_length
	await shot("contracted")
	move(Vector2(0,-90))
	check(app.controller.hands[0].rest_length==contracted,"aim input does not immediately write a cursor-derived arm length")
	var high: float=app.torso.position.y
	for step in 45:
		move(Vector2(0,-5))
		await wait_seconds(.016)
	await wait_seconds(.3)
	report.lower_m=high-app.torso.position.y
	check(report.lower_m>.03 and app.controller.hands[0].rest_length>contracted+.02,"upward relative effort physically extends the arm and lowers the body")
	await shot("aim_reposition")
	aim_at(1,app.level.holds[1].global_position)
	button(MOUSE_BUTTON_RIGHT,true)
	await wait_seconds(.7)
	check(app.controller.get_hand_state(1)=="ATTACHED","second virtual hand catches after the first contracted")
	move(Vector2(40,-10))
	await wait_seconds(.7) # Finish the gesture/physical catch transient before testing orbit.
	check(app.controller.telemetry().total_force<=360.001,"dual contextual effort respects shared hand budget")
	await shot("dual_posture")
	var left: float=app.controller.hands[0].rest_length
	var right: float=app.controller.hands[1].rest_length
	button(MOUSE_BUTTON_MIDDLE,true)
	move(Vector2(60,30))
	await wait_seconds(.2)
	button(MOUSE_BUTTON_MIDDLE,false)
	await wait_seconds(.2)
	check(absf(app.controller.hands[0].rest_length-left)<.004 and absf(app.controller.hands[1].rest_length-right)<.004,"MMB orbit does not command arm posture")
	Input.action_press("contract")
	await wait_seconds(.1)
	var direction: Vector3=app.controller.telemetry().swing_requested
	button(MOUSE_BUTTON_MIDDLE,true)
	move(Vector2(70,0))
	await wait_seconds(.15)
	button(MOUSE_BUTTON_MIDDLE,false)
	check(Vector3(app.controller.telemetry().swing_requested).distance_to(direction)<.001,"held W keeps its world swing direction while camera orbits")
	Input.action_release("contract")
	button(MOUSE_BUTTON_LEFT,false)
	check(app.controller.get_hand_state(1)=="ATTACHED","releasing left preserves the contextual right grip")
	button(MOUSE_BUTTON_RIGHT,false)
	app.capture_trace.enabled=false
	app.capture_trace.close()
	app.load_test(0)
	app.settings.show()
	await wait_seconds(.1)
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Controls frees native mouse for UI")
	await shot("controls")
	app.settings.hide()
	check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"closing Controls resumes relative capture")
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/contextual_capture_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	queue_free()
