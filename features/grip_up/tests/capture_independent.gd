extends Node
## Native Godot MCP Pro evidence: real input, authored geometry, no body writes.
var app
var hz := 120
var report := {"complete":false,"checks":[],"snapshots":[],"variants":[],"focus_events":[]}
var record_folder := "C:/Users/Wynter/grip_up/builds/v04_demo_frames_complete"
var recording := false
var frame_number := 0
var record_clock := 0.0
var record_busy := false

func _ready() -> void:
	app=get_parent()
	hz=Engine.physics_ticks_per_second
	get_window().focus_exited.connect(func():report.focus_events.append({"scene":app.level_id,"policy":app.posture_policy,"step":app.session_ticks}))
	run.call_deferred()

func _process(delta: float) -> void:
	if not recording or record_busy:return
	record_clock+=delta
	if record_clock<1.0/15.0:return
	record_clock=fmod(record_clock,1.0/15.0)
	record_busy=true
	await RenderingServer.frame_post_draw
	var frame_image:=get_viewport().get_texture().get_image()
	frame_image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	frame_image.save_jpg(record_folder+"/%05d.jpg" % frame_number,.85)
	frame_number+=1
	record_busy=false

func ticks(seconds: float) -> void:
	for frame in int(seconds*hz):await get_tree().physics_frame

func check(ok: bool,label: String) -> void:
	report.checks.append({"passed":ok,"label":label})

func motion(position: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=position
	event.relative=position-app.pointer
	event.screen_relative=event.relative
	Input.parse_input_event(event.xformed_by(get_viewport().get_final_transform()))
	Input.flush_buffered_events()

func aim(point: Vector3) -> void:
	motion(app.camera.unproject_position(point))

func button(id: MouseButton,down: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=app.pointer
	event.button_index=id
	event.pressed=down
	Input.parse_input_event(event.xformed_by(get_viewport().get_final_transform()))
	Input.flush_buffered_events()

func send_action(action_name: String,down: bool) -> void:
	var event:=InputEventAction.new()
	event.action=action_name
	event.pressed=down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func shot(label: String) -> void:
	var data: Dictionary=app.controller.telemetry()
	var row := {"label":label,"position":str(app.torso.position),"velocity":str(app.torso.linear_velocity),"policy":app.posture_policy,"posture":data.get("posture",{}),"hands":[]}
	for hand in app.controller.hands:
		row.hands.append({"state":hand.state,"target":hand.rest_length,"actual":hand.actual_length,"force":Vector3(hand.force).length(),"reason":hand.reason})
	report.snapshots.append(row)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/v04_%dhz_%s.png" % [hz,label])

func reset_scene(index: int,policy: int=1) -> void:
	for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:button(id,false)
	for action in ["contract","extend","bias_left","bias_right","launch"]:Input.action_release(action)
	app.settings.hide()
	app._set_posture_policy(policy)
	app.load_test(index)
	app.hint_time=0
	await ticks(.45)

func run() -> void:
	report.physics_hz=hz
	report.baseline={"mass":12,"body_friction":.12,"spring_k":6000,"spring_d":220,"force_budget":360,"assist_torque":20,"total_torque":150,"hand_speed":4,"target_range":[.18,.62],"elastic":.04,"anatomical_reach":.65708}
	app._set_input_profile(3)
	app._set_predictive_grip(false)
	app._set_physical_feet(false)
	app._set_experimental_launch(false)
	app.capture_trace.path="user://v04_rendered_%dhz.jsonl" % hz
	app.capture_trace.enabled=true
	check(app.controller.control_profile==3 and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"opt-in native independent aim uses visible full-screen pointer")
	check(not app.controller.experimental_launch_enabled,"Space remains OFF for initial independent-aim comparison")
	if hz==120:
		DirAccess.make_dir_recursive_absolute(record_folder)
		recording=true
	for policy in [0,1,2]:
		await reset_scene(3,policy)
		aim(app.level.holds[0].global_position)
		button(MOUSE_BUTTON_LEFT,true)
		check(app.controller.get_hand_state(0)=="REACHING","variant %d press starts finite reach" % policy)
		await ticks(.35)
		check(app.controller.get_hand_state(0)=="ATTACHED","variant %d actual left contact acquired" % policy)
		var start: float=app.torso.position.y
		var initial: float=app.controller.hands[0].rest_length
		await ticks(1.4)
		var settled: float=app.controller.hands[0].rest_length
		var before: Dictionary=app.controller.telemetry().posture.duplicate(true)
		motion(Vector2(100,950))
		await ticks(.12)
		motion(Vector2(1500,10))
		await ticks(.12)
		var after: Dictionary=app.controller.telemetry().posture
		check(before.event==after.event and before.planned_lengths==after.planned_lengths,"variant %d upward aim never changes posture plan" % policy)
		check(absf(app.controller.hands[0].rest_length-settled)<.002,"variant %d settled support target is independent of cursor" % policy)
		report.variants.append({"policy":policy,"initial_length":initial,"settled_length":settled,"rise":app.torso.position.y-start,"plan":after})
		await shot("variant_%d_single" % policy)
		aim(app.level.holds[1].global_position)
		var pose: Transform3D=app.torso.global_transform
		var velocity: Vector3=app.torso.linear_velocity
		button(MOUSE_BUTTON_RIGHT,true)
		check(app.torso.global_transform==pose and app.torso.linear_velocity==velocity,"variant %d second press preserves pose and velocity" % policy)
		await ticks(.65)
		check(app.controller.get_hand_state(1)=="ATTACHED" and app.controller.get_hand_state(0)=="ATTACHED","variant %d right finite catch preserves held left" % policy)
		await ticks(1.0)
		await shot("variant_%d_dual" % policy)
		button(MOUSE_BUTTON_LEFT,false)
		check(app.controller.get_hand_state(1)=="ATTACHED","variant %d handoff preserves surviving right anchor" % policy)
		await ticks(.3)
		button(MOUSE_BUTTON_RIGHT,false)
	await reset_scene(1)
	aim(app.level.holds[0].global_position)
	button(MOUSE_BUTTON_LEFT,true)
	await ticks(.5)
	check(app.controller.get_hand_state(0)=="ATTACHED","swing scene first surface catches")
	for action in ["contract","extend","bias_left","bias_right"]:
		Input.action_press(action)
		await ticks(.35)
		var request: Vector3=app.controller.telemetry().swing_requested
		check(request.length()>.5,"native %s requests supported swing" % action)
		if action=="contract":
			var event_before: int=app.controller.telemetry().posture.event
			button(MOUSE_BUTTON_MIDDLE,true)
			motion(app.pointer+Vector2(50,15))
			await ticks(.15)
			button(MOUSE_BUTTON_MIDDLE,false)
			check(Vector3(app.controller.telemetry().swing_requested).distance_to(request)<.001 and app.controller.telemetry().posture.event==event_before,"MMB preserves cached W world command and posture event")
		Input.action_release(action)
	await shot("supported_swing")
	button(MOUSE_BUTTON_LEFT,false)
	await ticks(.1)
	check(app.controller.telemetry().total_force<.001 and Vector3(app.controller.telemetry().torque).length()<.001,"last release removes all climb actuation in flight")
	await reset_scene(2)
	aim(app.level.holds[0].global_position)
	button(MOUSE_BUTTON_RIGHT,true)
	await ticks(.45)
	check(app.controller.get_hand_state(1)=="ATTACHED","reactive beam caught at actual material point")
	if app.controller.hands[1].anchor!=null:
		var local_point: Vector3=app.controller.hands[1].anchor.local_point
		Input.action_press("bias_left")
		await ticks(.6)
		Input.action_release("bias_left")
		check(app.controller.hands[1].anchor!=null and app.controller.hands[1].anchor.local_point==local_point and app.level.beam.angular_velocity.length()<10 and app.torso.linear_velocity.length()<5,"moving beam preserves local anchor and remains bounded under supported input")
		aim(app.level.beam.global_transform*Vector3(-.30,0,.12))
		button(MOUSE_BUTTON_LEFT,true)
		await ticks(.4)
		check(app.controller.get_hand_state(0)=="ATTACHED" and app.controller.get_hand_state(1)=="ATTACHED","two independent material contacts share moving beam load")
		button(MOUSE_BUTTON_RIGHT,false)
		check(app.controller.get_hand_state(0)=="ATTACHED","beam handoff preserves surviving left contact")
		app._set_experimental_launch(true)
		send_action("launch",true)
		await ticks(.45)
		check(app.controller.telemetry().launch_state=="CHARGING","explicit native Space ON uses preserved charge")
		send_action("launch",false)
		await ticks(.4)
		check(app.controller._attached_ids().is_empty(),"explicit native Space release ends finite pull and releases old contacts")
		app._set_experimental_launch(false)
	report.beam_angle=app.level.beam.rotation.z
	await shot("dynamic_beam")
	button(MOUSE_BUTTON_RIGHT,false)
	recording=false
	report.demo_frames=frame_number
	app.capture_trace.enabled=false
	app.capture_trace.close()
	await reset_scene(0)
	app.settings.show()
	await ticks(.1)
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Controls retains visible mouse")
	await shot("controls")
	app.settings.hide()
	app._refresh_pointer_capture()
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/independent_capture_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	queue_free()
