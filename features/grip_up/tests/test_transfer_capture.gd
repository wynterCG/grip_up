extends SceneTree
const Lab=preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var hz:=120
var checks:=0
var failures:=0
var reports: Array[Dictionary]=[]

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

func mouse(down: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=app.pointer
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=down
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()

func setup(advice: bool,buffer: bool,early: bool) -> void:
	await physics_frame
	app=Lab.new()
	app.input_profile=3
	app.reach_prediction_enabled=advice
	app.catch_buffer_enabled=buffer
	app.transfer_diagnostics_enabled=true
	root.add_child(app)
	current_scene=app
	app._set_posture_policy(0)
	# Identical initial-state fixtures, not a runtime locomotion mechanism.
	app.torso.position=Vector3(0,3,.45)
	app.torso.gravity_scale=0
	app.torso.linear_velocity=Vector3.UP if early else Vector3.ZERO
	app.torso.reset_physics_interpolation()
	app.controller.reset_state()
	await ticks(maxi(1,int(.05*hz)))
	var shoulder: Vector3=app.controller.get_shoulder_world(0)
	var point:=Vector3(shoulder.x,shoulder.y+(.52 if early else .20),0)
	app.camera._update_camera(1)
	app.pointer=app.camera.unproject_position(point)
	app.prediction_clock=0
	app._process(0)

func clear() -> void:
	mouse(false)
	app.queue_free()
	await ticks(4)

func observed_contact(advice: bool) -> Dictionary:
	await setup(advice,false,false)
	check(not app.controller.tuning.predictive_grip,"advisory %s cannot enable physical prediction/buffering" % advice)
	var initial: Transform3D=app.torso.global_transform
	mouse(true)
	check(app.controller.get_hand_state(0)=="REACHING" and app.torso.global_transform==initial,"valid current request starts finite reach without pose jump")
	var cap: float=0
	var moment: float=0
	var contact_time:=-1.0
	for frame in int(.6*hz):
		await physics_frame
		cap=maxf(cap,float(app.controller.telemetry().total_force))
		moment=maxf(moment,Vector3(app.controller.telemetry().torque).length())
		if contact_time<0 and app.controller.get_hand_state(0)=="ATTACHED":contact_time=float(frame+1)/hz
	var report: Dictionary={"advice":advice,"contact_time":contact_time,"pose":app.torso.global_transform,"velocity":app.torso.linear_velocity,"spin":app.torso.angular_velocity,"max_force":cap,"max_torque":moment,"state":app.controller.get_hand_state(0)}
	check(contact_time>0 and report.state=="ATTACHED" and cap<=360.001 and moment<=150.001,"finite contact retains and respects shared physical budgets")
	await clear()
	return report

func run() -> void:
	var off: Dictionary=await observed_contact(false)
	var on: Dictionary=await observed_contact(true)
	check(off.pose==on.pose and off.velocity==on.velocity and off.spin==on.spin and off.contact_time==on.contact_time and off.max_force==on.max_force,"advisory OFF/ON produces exactly identical contact and physical trajectory")
	reports.append(off)
	reports.append(on)
	await setup(true,false,true)
	mouse(true)
	check(app.controller.get_hand_state(0)=="FREE" and not app.grip_intents.held[0],"early press with buffer OFF is rejected, never sticky")
	await ticks(int(.4*hz))
	check(app.controller.get_hand_state(0)=="FREE","advisory never automatically retries an early rejected input")
	await clear()
	await setup(false,true,true)
	var pose: Transform3D=app.torso.global_transform
	var velocity: Vector3=app.torso.linear_velocity
	mouse(true)
	check(app.controller.get_hand_state(0)=="REACHING" and app.controller.hands[0].get("predictive_wait",false),"buffer ON accepts held near-future material point without requiring advisory")
	check(app.controller.tuning.capture_intent_buffer_duration==.12 and app.torso.global_transform==pose and app.torso.linear_velocity==velocity,"120ms pending input preserves body pose and momentum")
	var immutable: Dictionary=app.attempt_assessments[0].duplicate(true)
	app.pointer=Vector2(50,50)
	app._process(.1)
	check(app.attempt_assessments[0]==immutable,"pointer and hover update cannot rewrite intentional press assessment")
	await ticks(int(.6*hz))
	check(app.controller.get_hand_state(0)=="ATTACHED","held buffered target still requires and completes real finite contact")
	check(app.controller.hands[0].anchor.local_point.is_equal_approx(Vector3(immutable.local_point)),"buffer retains original selected material-local point")
	await clear()
	for cancellation in ["release","ui","focus","disabled"]:
		await setup(false,true,true)
		mouse(true)
		match cancellation:
			"release":mouse(false)
			"ui":app.settings.show()
			"focus":root.focus_exited.emit()
			"disabled":app._set_catch_buffer(false)
		await ticks(2)
		check(app.controller.get_hand_state(0) in ["FREE","RELEASED"] and app.grip_intents.entries[0].is_empty(),"pending intent cancels on "+cancellation)
		await ticks(int(.3*hz))
		check(app.controller.get_hand_state(0) in ["FREE","RELEASED"],"cancelled intent cannot later attach: "+cancellation)
		await clear()
	await setup(false,true,false)
	app._set_predictive_grip(false)
	check(app.controller.tuning.predictive_grip,"legacy toggle OFF cannot override explicitly enabled v0.5 buffer")
	app._set_input_profile(1)
	check(not app.controller.tuning.predictive_grip,"v0.5 buffer remains scoped to independent aim")
	app._set_input_profile(3)
	check(app.controller.tuning.predictive_grip,"returning to independent aim restores explicit buffer flag")
	await clear()
	var file:=FileAccess.open("res://builds/transfer_capture_%dhz.json" % hz,FileAccess.WRITE)
	file.store_string(JSON.stringify({"hz":hz,"fixtures":"explicit initial pose/velocity, real input and physics thereafter","advisory_equivalence":reports,"checks":checks,"failures":failures},"\t"))
	print("TRANSFER CAPTURE RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
