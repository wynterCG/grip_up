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

func move(raw: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	# Every absolute position is identical: only relative input can move the aim.
	event.position=Vector2(960,540)
	event.relative=raw
	event.screen_relative=raw
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()

func button(id: MouseButton,pressed: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=Vector2(960,540)
	event.button_index=id
	event.pressed=pressed
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
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

func pull(seconds: float) -> void:
	for frame in int(seconds*hz):
		move(Vector2(0,400.0/hz))
		await ticks(1)

func extend(seconds: float) -> void:
	for frame in int(seconds*hz):
		move(Vector2(0,-400.0/hz))
		await ticks(1)

func run() -> void:
	app=Lab.new()
	root.add_child(app)
	current_scene=app
	check(app.input_profile==2 and app.controller.control_profile==2 and app.profile_choice.selected==2,"contextual profile is the actual startup and UI selection")
	check(app.hold_mode and app.hold_toggle.disabled,"contextual grip always uses hold semantics")
	app.load_test(3)
	await ticks(int(.4*hz))
	move(Vector2.ZERO)
	check(app.biped.free_aim_ik.influence>.9 and app.biped.ik.influence<.1,"grounded contextual hands use arm IK while keeping authored walking legs")
	var initial: Vector2=app.contextual.offsets[0]
	move(Vector2(8,-4))
	check(app.contextual.offsets[0].distance_to(initial+Vector2(8,4)*app.contextual.sensitivity)<.00001,"raw relative delta moves free-hand aim even at constant absolute cursor position")
	move(Vector2(100000,-100000))
	for id in 2:
		check(app.contextual.target(id,app.controller,app.camera).distance_to(app.controller.get_shoulder_world(id))<=app.controller.get_max_reach()+.00001,"virtual target stays within anatomical reach; hand %d" % id)
	var edge: Vector2=app.contextual.offsets[0]
	move(Vector2(-3,3))
	check(app.contextual.offsets[0].distance_to(edge)>.001,"reverse movement responds immediately after saturated aim without stored windup")
	await ticks(2)
	check(app.controller.telemetry().total_force==0,"relative free-hand aiming provides no support force")
	aim_at(0,app.level.holds[0].global_position)
	check(not app.contextual.candidate(0,app.controller,app.camera).is_empty(),"virtual left aim selects an actual reachable raycast surface")
	button(MOUSE_BUTTON_LEFT,true)
	check(app.controller.get_hand_state(0)=="REACHING","held LMB begins a finite physical reach")
	await ticks(int(.4*hz))
	check(app.controller.get_hand_state(0)=="ATTACHED","left palm reaches actual selected surface")
	var before: float=app.torso.position.y
	await pull(.65)
	await ticks(int(.3*hz))
	check(app.torso.position.y>before+.03,"relative downward drag requests pull and physically raises supported body")
	var contracted: float=app.controller.hands[0].rest_length
	var free_before: Vector2=app.contextual.offsets[1]
	move(Vector2(0,-80))
	check(app.controller.hands[0].rest_length==contracted,"relative aim event does not write arm length before physical integration")
	await ticks(int(.2*hz))
	check(app.contextual.offsets[1].y>free_before.y+.05,"upward aim remains available for the free hand after contraction")
	var raised: float=app.torso.position.y
	await extend(.65)
	await ticks(int(.7*hz)) # Let the effort filter and any floor-blocked slack relax.
	check(app.controller.hands[0].rest_length>contracted+.02 and app.torso.position.y<raised-.02,"sustained upward relative effort genuinely extends the supported arm and lowers body")
	var held: float=app.controller.hands[0].rest_length
	await ticks(int(.3*hz))
	if absf(app.controller.hands[0].rest_length-held)>=.003:
		print("IDLE HOLD before=",held," after=",app.controller.hands[0].rest_length," actual=",app.controller.hands[0].actual_length," filtered=",app.controller.telemetry().get("contextual_filtered")," holds=",app.controller._contextual_holds)
	check(absf(app.controller.hands[0].rest_length-held)<.003,"stationary mouse retains achieved arm posture without input tail")
	aim_at(1,app.level.holds[1].global_position)
	button(MOUSE_BUTTON_RIGHT,true)
	check(app.controller.get_hand_state(1)=="REACHING","independent held RMB reaches from the virtual free-hand aim")
	await ticks(int(.4*hz))
	if app.controller.get_hand_state(1)!="ATTACHED":
		print("SECOND CATCH ",app.controller.hands[1]," torso ",app.torso.position)
	check(app.controller.get_hand_state(1)=="ATTACHED","second hand reaches contact after contracted first hand is retained")
	var left_offset: Vector2=app.contextual.offsets[0]
	var right_offset: Vector2=app.contextual.offsets[1]
	move(Vector2(12,-8))
	await ticks(3)
	check(app.contextual.offsets[0]==left_offset and app.contextual.offsets[1]==right_offset,"two attached hands route mouse to supported posture rather than free aim")
	check(app.controller.telemetry().total_force<=360.001,"two hands preserve the shared force budget")
	await ticks(int(.6*hz)) # Isolate camera input from the preceding pull/catch transient.
	var left_rest: float=app.controller.hands[0].rest_length
	var right_rest: float=app.controller.hands[1].rest_length
	button(MOUSE_BUTTON_MIDDLE,true)
	move(Vector2(80,60))
	await ticks(3)
	button(MOUSE_BUTTON_MIDDLE,false)
	await ticks(3)
	check(absf(app.controller.hands[0].rest_length-left_rest)<.003 and absf(app.controller.hands[1].rest_length-right_rest)<.003,"camera orbit does not create arm-effort input or release grips")
	check(app.controller._attached_ids().size()==2,"MMB retains both material anchors")
	Input.action_press("contract")
	await ticks(2)
	var direction: Vector3=app.controller.telemetry().swing_requested
	app.camera.orbit(Vector2(100,0))
	app.camera._update_camera(1)
	await ticks(3)
	check(Vector3(app.controller.telemetry().swing_requested).distance_to(direction)<.00001,"contextual mode retains per-gesture WASD reference through orbit")
	Input.action_release("contract")
	check(not app.controller.request_launch_charge(true),"Space comparison stays off by default")
	app.settings.show()
	move(Vector2(0,-1000))
	await ticks(3)
	app.settings.hide()
	move(Vector2(0,-1000)) # First delta after reacquisition is rebased.
	await ticks(3)
	check(app.contextual.pending==Vector2.ZERO,"UI capture and return discard hidden effort deltas")
	button(MOUSE_BUTTON_LEFT,false)
	check(app.controller.get_hand_state(0)=="RELEASED" and app.controller.get_hand_state(1)=="ATTACHED","mouse-up releases only its own contextual grip")
	await ticks(2)
	var released_aim: Vector2=app.contextual.offsets[0]
	move(Vector2(-10,10))
	check(app.contextual.offsets[0].distance_to(released_aim)>.005,"released hand immediately becomes a movable anatomical aim")
	root.focus_exited.emit()
	await ticks(2)
	check(app.contextual_paused and app.controller._attached_ids().is_empty() and app.contextual.pending==Vector2.ZERO,"focus loss clears effort, releases held hands and pauses capture")
	button(MOUSE_BUTTON_LEFT,true)
	check(not app.contextual_paused and app.controller.get_hand_state(0)!="REACHING","resume click cannot accidentally acquire a grip")
	button(MOUSE_BUTTON_LEFT,false)
	app.load_test(3)
	await ticks(2)
	check(app.input_profile==2 and app.contextual.pending==Vector2.ZERO,"reset preserves contextual profile without stale effort")
	for action in ["contract","extend","bias_left","bias_right"]:Input.action_release(action)
	app.queue_free()
	await ticks(3)
	print("CONTEXTUAL INPUT RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
