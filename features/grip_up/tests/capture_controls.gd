extends Node
## Native-rendered input checks, invoked through Godot MCP Pro. No body writes.
var app
var report := {"complete":false,"checks":[],"snapshots":[]}
var hz := 120

func _ready() -> void:
	app=get_parent()
	hz=Engine.physics_ticks_per_second
	run.call_deferred()

func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func check(ok: bool,label: String) -> void:
	report.checks.append({"passed":ok,"label":label})

func motion(delta: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=app.pointer+delta
	event.relative=delta
	event.screen_relative=delta
	Input.parse_input_event(event.xformed_by(get_viewport().get_final_transform()))
	Input.flush_buffered_events()

func button(id: MouseButton,down: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=app.pointer
	event.button_index=id
	event.pressed=down
	Input.parse_input_event(event.xformed_by(get_viewport().get_final_transform()))
	Input.flush_buffered_events()

func snapshot(label: String) -> void:
	var data: Dictionary=app.controller.telemetry()
	var row: Dictionary={"label":label,"profile":app.input_profile,"owner":app.router.owner,"position":str(app.torso.position),"velocity":str(app.torso.linear_velocity),"swing":str(data.get("swing_requested",Vector3.ZERO)),"swing_torque":str(data.get("swing_torque",Vector3.ZERO)),"hands":[]}
	for hand in app.controller.hands:
		row.hands.append({"state":hand.state,"target":hand.rest_length,"actual":hand.actual_length,"force":Vector3(hand.force).length()})
	report.snapshots.append(row)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/v03_%dhz_%s.png" % [hz,label])

func reset_scene(index: int,profile: int=1) -> void:
	for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:button(id,false)
	for action in ["contract","extend","bias_left","bias_right"]:Input.action_release(action)
	app.settings.hide()
	app._set_input_profile(profile)
	app.load_test(index)
	await wait_seconds(.45)
	app.pointer=app.camera.unproject_position(app.level.holds[0].global_position)
	motion(Vector2.ZERO)
	button(MOUSE_BUTTON_LEFT,true)
	await wait_seconds(.45)

func drag(pixels: float) -> void:
	for step in 20:
		motion(Vector2(0,pixels/20))
		await wait_seconds(.015)

func run() -> void:
	app._set_input_profile(1) # Preserved earlier drag-profile comparison.
	report.physics_hz=hz
	check(app.input_profile==1 and app.controller.control_profile==1,"explicit profile selects mouse arm drag")
	app._set_predictive_grip(false)
	app._set_physical_feet(false)
	app.capture_trace.path="user://v03_rendered_%dhz.jsonl" % hz
	app.capture_trace.enabled=true
	await reset_scene(3)
	check(app.controller.get_hand_state(0)=="ATTACHED","held LMB acquires fixed surface")
	var original: float=app.controller.hands[0].rest_length
	await drag(-40)
	var contracted: float=app.controller.hands[0].rest_length
	check(absf(contracted-original+.06)<.002,"slow upward drag shortens target by 60mm")
	await snapshot("single_drag")
	await drag(40)
	check(absf(app.controller.hands[0].rest_length-original)<.002,"downward drag extends the target back")
	Input.action_press("contract")
	await wait_seconds(.25)
	Input.action_release("contract")
	Input.action_press("extend")
	await wait_seconds(.25)
	Input.action_release("extend")
	check(absf(app.controller.hands[0].rest_length-original)<.002,"native W and S never actuate arm length")
	# Actual aiming motion deliberately changes the already attached arm.
	var right_point: Vector2=app.camera.unproject_position(app.level.holds[1].global_position)
	var aim_y: float=right_point.y-app.pointer.y
	motion(right_point-app.pointer)
	await wait_seconds(.04)
	var before_press: float=app.controller.hands[0].rest_length
	button(MOUSE_BUTTON_RIGHT,true)
	check(app.controller.hands[0].rest_length==before_press,"RMB press alone never applies another arm delta")
	motion(Vector2(0,-2))
	await wait_seconds(.05)
	check(absf(app.controller.hands[0].rest_length-before_press+.003)<.001,"supporting arm responds while other hand reaches")
	await wait_seconds(.4)
	report.aim_delta_y=aim_y
	check(app.controller.get_hand_state(1)=="ATTACHED","RMB reaches second actual contact")
	var left: float=app.controller.hands[0].rest_length
	var right: float=app.controller.hands[1].rest_length
	await drag(-10)
	check(absf(app.controller.hands[0].rest_length-left+.015)<.002 and absf(app.controller.hands[1].rest_length-right+.015)<.002,"shared drag updates both targets once")
	await snapshot("dual_drag")
	button(MOUSE_BUTTON_LEFT,false)
	check(app.controller.get_hand_state(0)=="RELEASED" and app.controller.get_hand_state(1)=="ATTACHED","releasing LMB leaves RMB attached")
	var target: float=app.controller.hands[1].rest_length
	button(MOUSE_BUTTON_MIDDLE,true)
	motion(Vector2(40,20))
	await wait_seconds(.1)
	button(MOUSE_BUTTON_MIDDLE,false)
	await wait_seconds(.1)
	check(absf(app.controller.hands[1].rest_length-target)<.001,"MMB orbit does not drag arms or store a later delta")
	button(MOUSE_BUTTON_RIGHT,false)
	await reset_scene(1)
	check(app.controller.get_hand_state(0)=="ATTACHED","swing scene acquires first actual contact")
	await drag(-100)
	await wait_seconds(.3)
	for action in ["contract","extend","bias_right","bias_left"]:
		Input.action_press(action)
		await wait_seconds(.5)
		await snapshot("swing_"+action)
		Input.action_release(action)
	check(app.controller._attached_ids().size()>0 and app.torso.linear_velocity.length()<5,"four supported swing gestures keep bounded live support")
	await reset_scene(2)
	report.dynamic_initial_state=app.controller.get_hand_state(0)
	if app.controller.get_hand_state(0)=="ATTACHED":
		await drag(-40)
		Input.action_press("bias_right")
		await wait_seconds(.6)
		Input.action_release("bias_right")
		report.beam_angle=app.level.beam.rotation.z
		check(app.torso.linear_velocity.length()<5 and app.level.beam.angular_velocity.length()<10,"hinged support stays finite under drag and swing")
	else:
		check(false,"hinged beam acquired through actual pointer selection")
	await snapshot("dynamic_support")
	await reset_scene(3,0)
	var legacy: float=app.controller.hands[0].rest_length
	await drag(20)
	check(absf(app.controller.hands[0].rest_length-legacy)<.002,"explicit legacy profile ignores mouse arm drag")
	Input.action_press("contract")
	await wait_seconds(.15)
	Input.action_release("contract")
	check(app.controller.hands[0].rest_length<legacy-.005,"explicit legacy comparison retains W contraction")
	button(MOUSE_BUTTON_LEFT,false)
	app.capture_trace.enabled=false
	app.capture_trace.close()
	app._set_input_profile(1)
	app.load_test(0)
	app.settings.show()
	await wait_seconds(.1)
	await snapshot("controls")
	app.settings.hide()
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/controls_capture_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	queue_free()
