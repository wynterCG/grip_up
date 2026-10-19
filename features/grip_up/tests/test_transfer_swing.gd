extends SceneTree
## Deliberate phase pumping and one intentional catch on the separate swing route.
const Lab=preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var hz:=120
var early_targets:=false
var checks:=0
var failures:=0
var report:={"runs":[]}

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):hz=60
	early_targets=OS.get_cmdline_user_args().has("--distant")
	Engine.physics_ticks_per_second=hz
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func ticks(seconds: float) -> void:
	for frame in int(seconds*hz):await physics_frame

func click(hand: int,down: bool,point: Vector3) -> void:
	var screen: Vector2=app.camera.unproject_position(point)
	var move:=InputEventMouseMotion.new()
	move.position=screen
	move.relative=screen-app.pointer
	move.screen_relative=move.relative
	Input.parse_input_event(move.xformed_by(root.get_final_transform()))
	var event:=InputEventMouseButton.new()
	event.position=screen
	event.button_index=MOUSE_BUTTON_LEFT if hand==0 else MOUSE_BUTTON_RIGHT
	event.pressed=down
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()

func trial(variant: int) -> void:
	app=Lab.new()
	root.add_child(app)
	current_scene=app
	app.transfer_assist_enabled=variant>0
	app._set_posture_variant(variant)
	app._open_transfer_lab(5)
	if early_targets:app._set_distant_targeting(true)
	app.won=true
	await ticks(.45)
	var point: Vector3=app.level.transfer_points[1]+Vector3(0,-.051,0)
	var row:={"variant":variant,"static_distance":app.controller.get_shoulder_world(1).distance_to(point),"inputs":[],"caught":false,"samples":[],"max_force":0.0,"max_torque":0.0}
	app.controller.sample_ready.connect(func(_delta:float):
		var data: Dictionary=app.controller.telemetry()
		row.max_force=maxf(row.max_force,data.total_force)
		row.max_torque=maxf(row.max_torque,Vector3(data.torque).length()))
	check(row.static_distance>app.controller.get_max_reach(),"P%d swing target begins outside anatomical static reach" % variant)
	click(0,true,app.level.transfer_points[0])
	await ticks(.5)
	check(app.controller.get_hand_state(0)=="ATTACHED","P%d starts from actual held left contact" % variant)
	if early_targets:
		row.early_selection_time=app.trial.elapsed
		var pose:Transform3D=app.torso.global_transform
		var velocity:Vector3=app.torso.linear_velocity
		click(1,true,point)
		row.initial_selection=app.controller.pending_diagnostics(1).duplicate(true)
		check(row.initial_selection.get("active",false) and row.initial_selection.get("reach_margin",0)<0,"far destination selected once before swing, outside actual reach")
		check(app.torso.global_transform==pose and app.torso.linear_velocity==velocity,"early selection never attracts or snaps the body")
	var active_action:=""
	var opportunity:=false
	var last_distance:=10.0
	for frame in 8*hz:
		var speed: float=app.torso.linear_velocity.dot(app.camera.global_basis.x)
		var next_action: String="bias_right" if speed>=-.04 else "bias_left"
		if active_action!=next_action:
			if active_action!="":Input.action_release(active_action)
			active_action=next_action
			Input.action_press(active_action)
			row.inputs.append({"time":app.trial.elapsed,"action":active_action})
		await physics_frame
		var hit: Dictionary=app.targeting.candidate(app.camera,app.camera.unproject_position(point),app.torso)
		var target: Vector3=hit.get("position",point)
		var distance: float=app.controller.get_shoulder_world(1).distance_to(target)
		if frame%6==0:row.samples.append({"time":app.trial.elapsed,"distance":distance,"body":str(app.torso.position),"motion":app.controller.transfer_diagnostics().get("motion",{})})
		if early_targets and app.controller.get_hand_state(1)=="ATTACHED":opportunity=true;break
		if distance<app.controller.get_max_reach()-.03 and distance<last_distance:
			opportunity=true
			row.press_distance=distance
			row.press_speed=app.torso.linear_velocity.length()
			break
		last_distance=distance
	if active_action!="":Input.action_release(active_action)
	check(opportunity,"P%d phase-timed supported input opens a real catch window" % variant)
	if opportunity:
		var pose: Transform3D=app.torso.global_transform
		var velocity: Vector3=app.torso.linear_velocity
		if not early_targets:click(1,true,point)
		if early_targets:
			check(app.controller.hands[1].anchor!=null and app.controller.hands[1].anchor.local_point==row.initial_selection.local_point,"full supported swing preserves the original queued material point")
		else:check(app.torso.global_transform==pose and app.torso.linear_velocity==velocity,"catch request never snaps body or overwrites momentum")
		var started: float=app.trial.elapsed
		for frame in hz:
			await physics_frame
			if app.controller.get_hand_state(1)=="ATTACHED":
				row.caught=true
				row.contact_speed=app.torso.linear_velocity.length()
				if early_targets:
					var contact:Dictionary=app.controller.pending_diagnostics(1)
					row.selection_to_contact=contact.get("contact_time",app.trial.elapsed)-contact.get("selected_time",row.early_selection_time)
					row.remaining_wait_after_range_observation=app.trial.elapsed-started
				else:row.hand_travel_time=app.trial.elapsed-started
				break
			if app.controller.get_hand_state(1) in ["FREE","RELEASED"]:break
		row.contact=app.controller.transfer_diagnostics().get("last_by_hand",{}).get(1,{})
		check(row.caught,"P%d finite right hand catches moving-body opportunity" % variant)
		if row.caught:
			click(0,false,point)
			await ticks(.6)
			check(app.controller.get_hand_state(1)=="ATTACHED","new right support retains real incoming load after old hand releases")
		else:check(false,"new right support retention requires a real catch")
	else:
		row.failure=app.controller.transfer_diagnostics().get("last_by_hand",{})
		check(false,"no catch attempted outside anatomical reach")
		check(false,"no unsupported retention is fabricated")
	check(row.max_force<=360.001 and row.max_torque<=150.001,"swing/catch uses unchanged shared force and torque caps")
	for hand in 2:click(hand,false,point)
	await ticks(.05)
	check(app.controller.telemetry().total_force==0 and Vector3(app.controller.telemetry().torque).length()<.00001,"release leaves no climbing actuation in flight")
	row.events=app.controller.transfer_journal.events
	report.runs.append(row)
	app.queue_free()
	await ticks(.05)

func run() -> void:
	report.physics_hz=hz
	for variant in [0,1,2]:await trial(variant)
	FileAccess.open("res://builds/transfer_swing%s_%dhz.json" % ["_distant" if early_targets else "",hz],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRANSFER SWING RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
