extends SceneTree
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var checks := 0
var failures := 0

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

func mouse(point: Vector2, button_index: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button_index
	event.pressed = pressed
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()

func click(point: Vector2, button_index := MOUSE_BUTTON_LEFT) -> void:
	mouse(point,button_index,true)
	mouse(point,button_index,false)

func launch_key(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = "launch"
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	app = Lab.new()
	app.input_profile = 0 # Explicitly exercise the preserved legacy control profile.
	root.add_child(app)
	current_scene = app
	await ticks(90)
	check(app.hold_mode,"hold-to-grip is the default")
	var hold = app.level.holds[0]
	var screen: Vector2 = app.camera.unproject_position(hold.global_position)
	mouse(screen,MOUSE_BUTTON_LEFT,true)
	await ticks(90)
	check(app.controller.get_hand_state(0)=="ATTACHED","holding actual LMB acquires left hand with default camera")
	check(app.controller.get_hand_state(1)=="FREE","holding LMB does not operate right hand")
	app.request_hand(0)
	check(app.controller.get_hand_state(0)=="ATTACHED","repeated press cannot toggle a held hand off")
	var anchor: Vector3 = app.controller.hands[0].anchor_world
	app.camera.orbit(Vector2(75,-20))
	app.camera.dolly(-1)
	await ticks(30)
	check(app.controller.get_hand_state(0)=="ATTACHED" and app.controller.hands[0].anchor_world==anchor,"camera orbit and dolly preserve material attachment")
	check(app.controller.telemetry().control_right.dot(app.camera.global_basis.x.normalized())>0.999,"climbing reference follows camera orbit independently of torso axes")
	launch_key(true)
	await ticks(15)
	check(app.controller.telemetry().launch_state=="CHARGING","mapped launch press starts charging while gripping")
	app.settings.show()
	launch_key(false)
	await ticks(2)
	check(app.controller.telemetry().launch_state=="IDLE" and app.controller.get_hand_state(0)=="ATTACHED","opening controls cancels charging and releasing over UI cannot launch")
	app.settings.hide()
	launch_key(true)
	await ticks(15)
	root.focus_exited.emit()
	await ticks(2)
	check(app.controller.telemetry().launch_state=="IDLE" and not Input.is_action_pressed("launch"),"focus loss clears charge and held launch input")
	launch_key(false)
	# Reacquire for the pre-existing mouse-up-over-UI regression.
	screen = app.camera.unproject_position(hold.global_position)
	mouse(screen,MOUSE_BUTTON_LEFT,true)
	await ticks(90)
	screen = app.camera.unproject_position(hold.global_position)
	# Mouse-up is delivered by _input even when a UI panel consumes the event.
	app.settings.show()
	mouse(Vector2(470,190),MOUSE_BUTTON_LEFT,false)
	await ticks(3)
	check(app.controller.get_hand_state(0)=="FREE","releasing LMB over GUI releases the physical hand")
	app.settings.hide()
	app.load_test(0)
	await ticks(90)
	screen = app.camera.unproject_position(app.level.holds[0].global_position)
	mouse(screen,MOUSE_BUTTON_LEFT,true)
	mouse(screen,MOUSE_BUTTON_LEFT,false)
	await ticks(3)
	check(app.controller.get_hand_state(0)=="FREE","release during REACHING cancels the pending grip")
	app.load_test(2)
	await ticks(90)
	var beam_point: Vector3 = app.level.beam.to_global(Vector3(-0.15,0,0.13))
	screen = app.camera.unproject_position(beam_point)
	mouse(screen,MOUSE_BUTTON_LEFT,true)
	mouse(screen,MOUSE_BUTTON_RIGHT,true)
	await ticks(90)
	check(app.controller.get_hand_state(0)=="ATTACHED" and app.controller.get_hand_state(1)=="ATTACHED","holding both actual mouse buttons attaches independent hands")
	mouse(screen,MOUSE_BUTTON_LEFT,false)
	await ticks(3)
	check(app.controller.get_hand_state(0)=="FREE" and app.controller.get_hand_state(1)=="ATTACHED","releasing LMB preserves held RMB grip")
	root.focus_exited.emit()
	await ticks(3)
	check(app.controller.get_hand_state(1)=="FREE","focus loss releases held grips instead of leaving a stuck button")
	mouse(screen,MOUSE_BUTTON_RIGHT,false)
	app.load_test(0)
	await ticks(90)
	app.hold_mode = false
	screen = app.camera.unproject_position(app.level.holds[0].global_position)
	click(screen)
	await ticks(90)
	check(app.controller.get_hand_state(0)=="ATTACHED","optional toggle mode retains grip after mouse-up")
	click(screen)
	await ticks(3)
	check(app.controller.get_hand_state(0)=="FREE","optional toggle releases on second click")
	app.hold_mode = true
	var old_torso = app.torso
	app.load_test(0)
	await ticks(3)
	check(not is_instance_valid(old_torso),"reset frees old physics body and grip references")
	check(app.controller.get_hand_state(0)=="FREE" and app.controller.get_hand_state(1)=="FREE","reset clears arm states")
	app.checkpoint_active = true
	app.load_test(0,true)
	await ticks(90)
	check(app.checkpoint_active and app.torso.position.distance_to(app.level.checkpoint)<0.25,"checkpoint reset creates a safe landing and preserves checkpoint")
	app.load_test(2)
	await ticks(90)
	var original_geometry: Vector3 = app.level.beam.get_child(0).shape.size
	app.toggle_beam()
	await ticks(90)
	check(app.fixed_beam and app.level.beam.freeze,"fixed-vs-hinged comparison switch fixes beam")
	check(app.level.beam.get_child(0).shape.size==original_geometry,"comparison preserves exact beam geometry")
	var fixed_body = app.level.beam
	var at: Vector3 = fixed_body.to_global(Vector3(-0.15,0,0.13))
	check(app.controller.request_grip(1,fixed_body,at,Vector3.BACK),"fixed comparison accepts identical material anchor")
	Input.action_press("contract")
	await ticks(300)
	var fixed_angle: float = absf(fixed_body.rotation.z)
	Input.action_release("contract")
	app.toggle_beam()
	await ticks(90)
	var hinged_body = app.level.beam
	at = hinged_body.to_global(Vector3(-0.15,0,0.13))
	check(app.controller.request_grip(1,hinged_body,at,Vector3.BACK),"hinged comparison accepts identical material anchor")
	Input.action_press("contract")
	await ticks(300)
	check(fixed_angle<0.001 and absf(hinged_body.rotation.z)>0.08,"identical pulling input gives fixed-vs-hinged physical difference")
	Input.action_release("contract")
	root.size = Vector2i(2560,1440)
	await ticks(6)
	check(app.hud.size.x>=1920 and app.hud.size.y>=1080,"HUD follows enlarged viewport")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_W
	check(not app.router.bind("extend",event).is_empty(),"rebinding rejects conflicts")
	check(app.router.prompt("contract")!="","input prompts derive from remappable actions")
	print("INTEGRATION RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
