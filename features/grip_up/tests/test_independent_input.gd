extends SceneTree
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var hz := 120
var checks := 0
var failures := 0

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):hz=60
	Engine.physics_ticks_per_second=hz
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func ticks(count: int) -> void:
	for frame in count:await physics_frame

func motion(position: Vector2,raw: Vector2=Vector2.ZERO) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=position
	event.relative=raw
	event.screen_relative=raw
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()

func button(id: MouseButton,down: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=app.pointer
	event.button_index=id
	event.pressed=down
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()

func aim(point: Vector3) -> void:
	var screen: Vector2=app.camera.unproject_position(point)
	motion(screen,screen-app.pointer)

func run() -> void:
	app=Lab.new()
	root.add_child(app)
	current_scene=app
	check(app.input_profile==2,"v0.4 stays opt-in and preserves startup comparison profile")
	app._set_input_profile(3)
	app._set_posture_policy(0)
	app.load_test(3)
	await ticks(int(.45*hz))
	check(app.controller.control_profile==3 and app.profile_choice.selected==3,"independent-aim profile is explicitly selectable")
	check(app.hold_mode and app.hold_toggle.disabled,"hold-to-grip remains mandatory")
	check(app.controller.independent_aim_enabled and app.controller.posture_policy==0,"variant A and feature flags reach controller")
	aim(app.level.holds[0].global_position)
	button(MOUSE_BUTTON_LEFT,true)
	check(app.controller.get_hand_state(0)=="REACHING","actual pointer press begins finite-speed left reach")
	var selected: Vector3=app.controller.hands[0].anchor.world_point()
	motion(Vector2(1500,180),Vector2(500,-700))
	await ticks(int(.4*hz))
	check(app.controller.get_hand_state(0)=="ATTACHED" and app.controller.hands[0].anchor_world.distance_to(selected)<.00001,"pointer motion never retargets a reaching/attached hand")
	var rest: float=app.controller.hands[0].rest_length
	for position in [Vector2(100,5),Vector2(800,950),Vector2(1300,30),Vector2(1920,0),Vector2(300,900)]:
		motion(position,Vector2(1000,-1000))
		await ticks(4)
	check(absf(app.controller.hands[0].rest_length-rest)<.00001,"M1 gate: large upward/downward aiming never changes supporting arm target")
	check(app.controller.telemetry().aim_input_does_not_change_length,"explicit aim independence telemetry marker is true")
	check(app.router.pending_y==[0.0,0.0] and app.contextual.pending==Vector2.ZERO,"independent aim queues neither drag lengths nor contextual effort")
	aim(app.level.holds[1].global_position)
	button(MOUSE_BUTTON_RIGHT,true)
	check(app.controller.get_hand_state(1)=="REACHING","free upward aim can start independent right reach while left remains held")
	motion(Vector2(60,10),Vector2(-1000,-1000))
	await ticks(int(.4*hz))
	check(app.controller.get_hand_state(1)=="ATTACHED" and app.controller.get_hand_state(0)=="ATTACHED","right finite reach completes while preserving left material anchor")
	check(absf(app.controller.hands[0].rest_length-rest)<.00001,"second acquisition plus aim cannot extend supporting left arm in A")
	var right: float=app.controller.hands[1].rest_length
	button(MOUSE_BUTTON_MIDDLE,true)
	motion(app.pointer+Vector2(80,20),Vector2(80,20))
	await ticks(3)
	button(MOUSE_BUTTON_MIDDLE,false)
	check(absf(app.controller.hands[0].rest_length-rest)<.00001 and absf(app.controller.hands[1].rest_length-right)<.00001,"MMB orbit preserves both arm targets and anchors")
	Input.action_press("contract")
	await ticks(2)
	var direction: Vector3=app.controller.telemetry().swing_requested
	app.camera.orbit(Vector2(90,0))
	app.camera._update_camera(1)
	await ticks(3)
	check(Vector3(app.controller.telemetry().swing_requested).distance_to(direction)<.00001,"W gesture keeps world depth command through orbit")
	check(app.controller.hands[0].rest_length==rest and app.controller.hands[1].rest_length==right,"W commands swing rather than direct arm contraction")
	Input.action_release("contract")
	check(not app.controller.request_launch_charge(true),"legacy Space impulse remains explicitly OFF")
	button(MOUSE_BUTTON_LEFT,false)
	check(app.controller.get_hand_state(0)=="RELEASED" and app.controller.get_hand_state(1)=="ATTACHED","left mouse-up releases only left support")
	app.settings.show()
	motion(Vector2(1500,10),Vector2(0,-2000))
	button(MOUSE_BUTTON_RIGHT,false)
	check(app.controller.get_hand_state(1)=="RELEASED","right release works even over UI")
	app.settings.hide()
	app.load_test(3)
	await ticks(int(.4*hz))
	aim(app.level.holds[0].global_position)
	button(MOUSE_BUTTON_LEFT,true)
	await ticks(int(.35*hz))
	root.focus_exited.emit()
	await ticks(2)
	check(app.controller._attached_ids().is_empty(),"focus loss cancels independent held grips")
	for policy in [0,1,2]:
		app._set_posture_policy(policy)
		check(app.controller.posture_policy==policy and app.posture_choice.selected==policy,"all three posture variants are selectable; policy %d" % policy)
	for policy in [1,2]:
		app._set_posture_policy(policy)
		app.load_test(3)
		await ticks(int(.4*hz))
		aim(app.level.holds[0].global_position)
		button(MOUSE_BUTTON_LEFT,true)
		await ticks(int(.3*hz))
		var before: Dictionary=app.controller.telemetry().posture.duplicate(true)
		check(not before.planned_lengths.is_empty(),"B/C acquisition creates a bounded geometric plan; policy %d" % policy)
		for point in [Vector2(50,5),Vector2(1750,920),Vector2(900,0)]:
			motion(point,Vector2(1000,-1000))
			await ticks(5)
		var after: Dictionary=app.controller.telemetry().posture
		check(after.event==before.event and after.planned_lengths==before.planned_lengths,"mouse cannot replan ongoing B/C movement; policy %d" % policy)
		app.posture_assist_enabled=false
		app._apply_independent_settings()
		await ticks(2)
		var frozen: float=app.controller.hands[0].rest_length
		motion(Vector2(100,900),Vector2(0,2000))
		await ticks(int(.2*hz))
		check(absf(frozen-app.controller.hands[0].rest_length)<.00001,"posture OFF preserves targets despite aim; policy %d" % policy)
		app.posture_tilt_assist_enabled=false
		app.supported_wasd_swing_enabled=false
		app._apply_independent_settings()
		Input.action_press("bias_right")
		await ticks(int(.3*hz))
		check(Vector3(app.controller.telemetry().swing_torque).length()<.00001 and Vector3(app.controller.telemetry().posture_tilt_torque).length()<.00001,"independent tilt/swing OFF flags remove their physical contributions")
		Input.action_release("bias_right")
		button(MOUSE_BUTTON_LEFT,false)
		app.posture_assist_enabled=true
		app.posture_tilt_assist_enabled=true
		app.supported_wasd_swing_enabled=true
		app._apply_independent_settings()
	app._set_input_profile(1)
	check(app.controller.control_profile==1 and not app.controller.independent_aim_enabled,"prior drag profile is restored explicitly")
	app._set_input_profile(3)
	app._set_posture_policy(0)
	app.load_test(3)
	check(app.input_profile==3 and app.controller.posture_policy==0,"retry preserves independent profile and selected posture policy")
	app.queue_free()
	await ticks(3)
	print("INDEPENDENT INPUT RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
