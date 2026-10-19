extends SceneTree
## Real input through the complete app; no simulated-body pose/velocity writes.
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var hz := 120
var checks := 0
var failures := 0

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):hz=60
	Engine.physics_ticks_per_second=hz
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func ticks(count: int) -> void:
	for frame in count:await physics_frame

func mouse(hand: int, pressed: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=app.pointer
	event.button_index=MOUSE_BUTTON_LEFT if hand==0 else MOUSE_BUTTON_RIGHT
	event.pressed=pressed
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()

func move(delta: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=app.pointer+delta
	event.relative=delta
	event.screen_relative=delta
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()

func camera_button(pressed: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=app.pointer
	event.button_index=MOUSE_BUTTON_MIDDLE
	event.pressed=pressed
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()

func setup() -> void:
	app=Lab.new()
	app.input_profile=1 # Preserve the explicit earlier drag-profile comparison.
	root.add_child(app)
	current_scene=app
	check(app.input_profile==1 and app.controller.control_profile==1 and app.profile_choice.selected==1,"explicit drag/swing profile shows the matching selection")
	app.load_test(3)
	await ticks(int(.4*hz))
	app.pointer=app.camera.unproject_position(app.level.holds[0].global_position)
	move(Vector2.ZERO)
	mouse(0,true)
	await ticks(int(.45*hz))
	check(app.controller.get_hand_state(0)=="ATTACHED","actual held LMB attaches in experimental profile")

func clear() -> void:
	mouse(0,false)
	mouse(1,false)
	for action in ["contract","extend","bias_left","bias_right"]:Input.action_release(action)
	app.queue_free()
	await ticks(3)

func run() -> void:
	await setup()
	check(app.hold_mode and app.hold_toggle.disabled and app.controller.control_profile==1,"profile 1 mandates hold-to-grip with explicit A/B choice")
	check(app.grip_feedback.events>0 and app.grip_feedback.contact.data.size()>100 and app.grip_feedback.contact.get_length()<.06,"actual contact triggers a short generated feedback cue")
	app._set_hold_mode(false)
	check(app.hold_mode,"toggle cannot silently replace experimental hold semantics")
	var initial: float=app.controller.hands[0].rest_length
	move(Vector2(20,-2))
	await ticks(2)
	var shorter: float=app.controller.hands[0].rest_length
	check(absf(shorter-(initial-.003))<.00001,"upward vertical drag contracts; horizontal aiming does not double the delta")
	await ticks(8)
	check(absf(app.controller.hands[0].rest_length-shorter)<.00001,"stationary mouse holds the last target without queued tail")
	move(Vector2(-20,2))
	await ticks(2)
	check(absf(app.controller.hands[0].rest_length-initial)<.00001,"downward mouse movement extends the arm")
	# Move toward the other target while preserving the supporting hand's drag.
	app.pointer=app.camera.unproject_position(app.level.holds[1].global_position)
	move(Vector2(0,-1))
	var left_before: float=app.controller.hands[0].rest_length
	mouse(1,true)
	check(app.controller.get_hand_state(1)=="REACHING","RMB press starts a separate finite reach")
	check(app.controller.hands[0].rest_length==left_before,"starting RMB reach neither jumps nor applies drag twice")
	move(Vector2(0,-1))
	await ticks(2)
	check(absf(app.controller.hands[0].rest_length-(left_before-.003))<.00001,"supporting arm responds to aiming motion before and during the other reach")
	await ticks(int(.4*hz))
	check(app.controller.get_hand_state(1)=="ATTACHED","the other hand reaches actual contact")
	var left: float=app.controller.hands[0].rest_length
	var right: float=app.controller.hands[1].rest_length
	move(Vector2(0,-2))
	await ticks(2)
	check(absf(app.controller.hands[0].rest_length-left+.003)<.00001 and absf(app.controller.hands[1].rest_length-right+.003)<.00001,"one shared drag changes both attached targets by the same displacement")
	mouse(0,false)
	check(app.controller.get_hand_state(0)=="RELEASED" and app.controller.get_hand_state(1)=="ATTACHED","mouse-up immediately releases only its own hand")
	move(Vector2(0,2))
	await ticks(2)
	check(absf(app.controller.hands[1].rest_length-right)<.00001,"remaining arm keeps its target and responds after the other hand releases")
	app.pointer=app.camera.unproject_position(app.level.holds[0].global_position)
	mouse(0,true)
	check(app.controller.get_hand_state(0)=="REACHING","released hand can immediately request a new finite catch with one press")
	await ticks(int(.35*hz))
	check(app.controller.get_hand_state(0)=="ATTACHED","rapid regrab reaches the actual surface without an extra release click")
	mouse(0,false)
	var held_target: float=app.controller.hands[1].rest_length
	camera_button(true)
	move(Vector2(60,25))
	await ticks(2)
	check(absf(app.controller.hands[1].rest_length-held_target)<.00001 and app.controller.get_hand_state(1)=="ATTACHED","MMB orbit owns mouse movement without dropping the grip or changing length")
	camera_button(false)
	await ticks(3)
	check(absf(app.controller.hands[1].rest_length-held_target)<.00001,"MMB release discards camera movement without hidden contraction")
	move(Vector2(0,-2))
	await ticks(2)
	check(absf(app.controller.hands[1].rest_length-held_target+.003)<.00001,"fresh drag resumes immediately after camera ownership")
	Input.action_press("contract")
	var w_target: float=app.controller.hands[1].rest_length
	await ticks(2)
	check(absf(app.controller.hands[1].rest_length-w_target)<.00001,"W requests swing without shortening the arm target")
	var world_direction: Vector3=app.controller.telemetry().swing_requested
	app.camera.orbit(Vector2(100,0))
	app.camera._update_camera(1)
	await ticks(3)
	check(Vector3(app.controller.telemetry().swing_requested).distance_to(world_direction)<.00001,"held W keeps its captured world direction across camera rotation")
	Input.action_release("contract")
	await ticks(2)
	Input.action_press("contract")
	await ticks(2)
	check(Vector3(app.controller.telemetry().swing_requested).distance_to(world_direction)>.1,"a new W gesture captures the updated camera frame")
	Input.action_release("contract")
	Input.action_press("extend")
	await ticks(4)
	check(absf(app.controller.hands[1].rest_length-w_target)<.00001,"S requests swing without extending the arm target")
	Input.action_release("extend")
	check(not app.controller.request_launch_charge(true),"Space launch is opt-in in the new profile")
	app.settings.show()
	move(Vector2(0,100))
	await ticks(2)
	var ui_target: float=app.controller.hands[1].rest_length
	app.settings.hide()
	await ticks(2)
	check(absf(app.controller.hands[1].rest_length-ui_target)<.00001,"UI motion cannot accumulate a delayed arm request")
	root.mouse_exited.emit()
	var held: Array[bool]=[false,true]
	app.router.capture_motion(Vector2(0,2000),app.controller,held)
	await ticks(2)
	root.mouse_entered.emit()
	move(Vector2(0,300))
	await ticks(2)
	check(absf(app.controller.hands[1].rest_length-ui_target)<.00001,"leaving and reentering the window rebases boundary motion")
	move(Vector2(0,2))
	await ticks(2)
	check(absf(app.controller.hands[1].rest_length-ui_target-.003)<.00001,"new deliberate movement resumes after boundary rebasing")
	root.focus_exited.emit()
	await ticks(2)
	check(app.controller._attached_ids().is_empty() and app.router.pending_y==[0.0,0.0],"focus loss releases grips and clears pending motion")
	app.load_test(3)
	await ticks(2)
	check(app.input_profile==1 and app.controller.control_profile==1 and app.router.gestures.is_empty(),"reset preserves profile and clears old gesture/anchor references")
	await clear()
	print("DRAG INPUT RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
