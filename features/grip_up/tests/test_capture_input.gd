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

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ",label)

func ticks(count: int) -> void:
	for frame in count:
		await physics_frame

func mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = app.pointer
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()

func setup() -> void:
	await physics_frame
	app = Lab.new()
	root.add_child(app)
	current_scene = app
	app._set_predictive_grip(true)
	app.torso.position = Vector3(0,3,0.45)
	app.torso.gravity_scale = 0
	app.torso.linear_velocity = Vector3.UP
	app.torso.reset_physics_interpolation()
	app.controller.reset_state()
	await ticks(maxi(1,int(0.05*hz)))
	var shoulder: Vector3 = app.controller.get_shoulder_world(0)
	var point := Vector3(shoulder.x,shoulder.y+0.52,0)
	app.camera._update_camera(1.0)
	app.pointer = app.camera.unproject_position(point)
	app.prediction_clock = 0
	app._process(0)

func clear() -> void:
	mouse(false)
	app.queue_free()
	await ticks(4)

func run() -> void:
	await setup()
	var pose: Transform3D = app.torso.global_transform
	var velocity: Vector3 = app.torso.linear_velocity
	mouse(true)
	check(app.controller.get_hand_state(0)=="REACHING" and app.controller.hands[0].get("predictive_wait",false),"actual held LMB prepares a currently out-of-reach SOON target")
	check(app.torso.global_transform==pose and app.torso.linear_velocity==velocity and app.controller.get_arm_force(0)==Vector3.ZERO,"buffering input never moves or propels the body")
	await ticks(1)
	check(app.controller.get_arm_force(0)==Vector3.ZERO and app.controller.get_shoulder_world(0).distance_to(app.controller.get_hand_world(0))<=app.controller.get_max_reach()+0.0001,"pending hand stays inside real reach and applies no force")
	app.settings.show()
	mouse(false)
	await ticks(2)
	check(app.controller.get_hand_state(0)=="FREE" and app.grip_intents.entries[0].is_empty() and not app.grip_intents.held[0],"mouse-up over UI immediately cancels the buffered hand")
	app.settings.hide()
	await ticks(int(0.4*hz))
	check(app.controller.get_hand_state(0)=="FREE","expired held intention cannot automatically retry or reattach")
	await clear()
	await setup()
	mouse(true)
	root.focus_exited.emit()
	await ticks(2)
	check(app.controller.get_hand_state(0)=="FREE" and app.grip_intents.entries[0].is_empty(),"focus loss cancels a pending prediction and clears held state")
	await clear()
	await setup()
	mouse(true)
	app.load_test(0)
	await ticks(3)
	check(app.controller.get_hand_state(0)=="FREE" and app.grip_intents.entries[0].is_empty(),"reset drops buffered targets and old support references")
	app.debug_visible = true
	app._process(0)
	check(app.capture_debug.visible,"optional debug overlay exposes physical contacts, reach and force vectors")
	app.debug_visible = false
	app._process(0)
	check(not app.capture_debug.visible,"debug vectors stay disabled in ordinary gameplay")
	await clear()
	print("CAPTURE INPUT RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
