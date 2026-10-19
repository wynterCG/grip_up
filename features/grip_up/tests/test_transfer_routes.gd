extends SceneTree
## Real input on separate reference/swing routes, diagnostics enabled, P0 physics.
const Lab=preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var hz:=120
var variant:=0
var checks:=0
var failures:=0
var report:={"runs":[]}

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):hz=60
	if OS.get_cmdline_user_args().has("--p1"):variant=1
	if OS.get_cmdline_user_args().has("--p2"):variant=2
	Engine.physics_ticks_per_second=hz
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func ticks(seconds: float) -> void:
	for frame in int(seconds*hz):await physics_frame

func mouse(hand: int,down: bool,point: Vector3) -> void:
	var screen: Vector2=app.camera.unproject_position(point)
	var motion:=InputEventMouseMotion.new()
	motion.position=screen
	motion.relative=screen-app.pointer
	motion.screen_relative=motion.relative
	Input.parse_input_event(motion.xformed_by(root.get_final_transform()))
	var event:=InputEventMouseButton.new()
	event.position=screen
	event.button_index=MOUSE_BUTTON_LEFT if hand==0 else MOUSE_BUTTON_RIGHT
	event.pressed=down
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()

func basic(spacing: float) -> void:
	app=Lab.new()
	root.add_child(app)
	current_scene=app
	app.transfer_assist_enabled=variant>0
	app._set_posture_variant(variant)
	app.transfer_route_spacing=spacing
	app._open_transfer_lab(4)
	app.won=true # Keep final rating popup from interrupting evidence collection.
	await ticks(.45)
	var row:={"spacing":spacing,"posture_variant":variant,"events":[],"max_force":0.0,"max_torque":0.0,"extra_inputs":0,"transfers":0}
	app.controller.sample_ready.connect(func(_delta:float):
		var data: Dictionary=app.controller.telemetry()
		row.max_force=maxf(row.max_force,data.total_force)
		row.max_torque=maxf(row.max_torque,Vector3(data.torque).length()))
	var previous:=-1
	for index in 11:
		var hand: int=index%2
		var point: Vector3=app.level.transfer_points[index]
		var distance: float=app.controller.get_shoulder_world(hand).distance_to(point)
		var waited:=0.0
		if previous>=0:
			for frame in 2*hz:
				if app.controller.get_shoulder_world(hand).distance_to(point)<app.controller.get_max_reach()-.005:break
				await physics_frame
				waited+=1.0/hz
		mouse(hand,true,point)
		var caught:=false
		for frame in int(.9*hz):
			await physics_frame
			if app.controller.get_hand_state(hand)=="ATTACHED":
				caught=true
				break
			if app.controller.get_hand_state(hand) in ["FREE","RELEASED"]:break
		row.events.append({"index":index,"distance_before":distance,"wait_for_reach":waited,"caught":caught,"diagnosis":app.controller.transfer_diagnostics().get("last_by_hand",{}).get(hand,{}),"body":str(app.torso.position)})
		if not caught:break
		await ticks(.35)
		if previous>=0:mouse(previous,false,point)
		previous=hand
		await ticks(1.1)
	row.transfers=app.transfer_progress.transfers
	row.recoveries=app.transfer_progress.recoveries
	row.elapsed=app.trial.elapsed
	row.session_id=app.transfer_session_id
	row.diagnostics=app.controller.transfer_journal.events
	var log_path: String="user://transfer_sessions/%s.jsonl" % app.transfer_session_id
	var lines: PackedStringArray=FileAccess.get_file_as_string(log_path).strip_edges().split("\n")
	var valid_log: bool=not lines.is_empty()
	for line in lines:
		var event = JSON.parse_string(line)
		valid_log=valid_log and event is Dictionary and event.get("session_id")==app.transfer_session_id
	check(valid_log,"session-isolated JSONL has complete parseable attempt records")
	report.runs.append(row)
	check(row.transfers==10,"basic route ten actual-input transfers without swing/modifiers; spacing %.2f" % spacing)
	check(row.recoveries==0,"reference route continuous support retained")
	check(row.max_force<=360.001 and row.max_torque<=150.001,"basic route same force and torque budgets")
	check(row.events.all(func(event):return event.caught),"each scored handoff requires physically attached contact")
	for hand in 2:mouse(hand,false,Vector3(0,2,0))
	app.queue_free()
	await ticks(.05)

func run() -> void:
	report.physics_hz=hz
	for spacing in [.12,.14]:await basic(spacing)
	app=Lab.new()
	root.add_child(app)
	current_scene=app
	app._open_transfer_lab(5)
	await ticks(.4)
	var target: Vector3=app.level.transfer_points[1]
	check(app.controller.get_shoulder_world(1).distance_to(target)>app.controller.get_max_reach(),"swing route's far target is deliberately outside static reach")
	mouse(1,true,target)
	check(app.controller.last_rejection=="out_of_reach","static swing-gate failure remains real")
	var last: Dictionary=app.controller.transfer_diagnostics().get("last_by_hand",{}).get(1,{})
	check(last.get("code")=="POSE_UNREACHABLE","swing gate reports geometric failure instead of stale manual reason")
	check(app.controller.tuning.body_mass==12 and app.controller.tuning.total_pull_force_budget==360,"new routes preserve biped tuning")
	app.queue_free()
	await ticks(.05)
	FileAccess.open("res://builds/transfer_routes%s_%dhz.json" % ["_p%d" % variant if variant>0 else "",hz],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRANSFER ROUTES RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
