extends SceneTree
## Ten alternating real-input surface catches in unchanged authored wall geometry.
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var hz := 120
var checks := 0
var failures := 0
var report := {"runs":[]}
var active_row: Dictionary = {}

func audit_frame() -> void:
	if active_row.is_empty() or not is_instance_valid(app):return
	var data: Dictionary=app.controller.telemetry()
	active_row.audited_frames+=1
	active_row.max_force=maxf(active_row.max_force,data.total_force)
	active_row.max_torque=maxf(active_row.max_torque,Vector3(data.get("torque",Vector3.ZERO)).length())
	active_row.bounded=active_row.bounded and active_row.max_force<=360.001 and active_row.max_torque<=150.001

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):hz=60
	Engine.physics_ticks_per_second=hz
	physics_frame.connect(audit_frame)
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func ticks(count: int) -> void:
	for frame in count:await physics_frame

func mouse(hand: int,down: bool,point: Vector3) -> void:
	var position: Vector2=app.camera.unproject_position(point)
	var move:=InputEventMouseMotion.new()
	move.position=position
	move.relative=position-app.pointer
	move.screen_relative=move.relative
	Input.parse_input_event(move.xformed_by(root.get_final_transform()))
	var event:=InputEventMouseButton.new()
	event.position=position
	event.button_index=MOUSE_BUTTON_LEFT if hand==0 else MOUSE_BUTTON_RIGHT
	event.pressed=down
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()

func surface(point: Vector3) -> Dictionary:
	return app.targeting.candidate(app.camera,app.camera.unproject_position(point),app.torso)

func trial(policy: int,spacing: float) -> Dictionary:
	app=Lab.new()
	root.add_child(app)
	current_scene=app
	app._set_input_profile(3)
	app._set_posture_policy(policy)
	app.load_test(0)
	# Suppress only the six-marker victory popup; physical wall and motor stay intact.
	app.won=true
	await ticks(int(.5*hz))
	# Walk to the unadorned wall lane; no physical geometry is moved or removed.
	Input.action_press("bias_left")
	Input.action_press("contract")
	for frame in int(1.0*hz):
		await physics_frame
		if app.torso.position.x<-.70:break
	Input.action_release("bias_left")
	Input.action_release("contract")
	await ticks(int(.4*hz))
	var lane: float=app.torso.position.x
	var row := {"policy":policy,"spacing":spacing,"lane_x":lane,"transfers":0,"attempts":0,"swing_actions":0,"failure":"","bounded":true,"audited_frames":0,"max_force":0.0,"max_torque":0.0,"events":[],"start_y":app.torso.position.y}
	active_row=row
	var previous := -1
	for index in 11:
		var hand: int=index%2
		var point:=Vector3(lane+(-.1919 if hand==0 else .1919),2.05+spacing*index,0)
		var hit: Dictionary=surface(point)
		var actual: Vector3=hit.get("position",point)
		# The same steering rule for all policies: deliberately swing into reach.
		# The specification retains player swing; the route is not an autopilot claim.
		if previous>=0 and app.controller.get_shoulder_world(hand).distance_to(actual)>app.controller.get_max_reach()-.015:
			var side: float=signf((actual-app.controller.get_shoulder_world(hand)).dot(app.camera.global_basis.x))
			var action := ""
			for frame in int(4.0*hz):
				# Pump with the actual pendulum phase; a constant key settles.
				var speed: float=app.torso.linear_velocity.dot(app.camera.global_basis.x)
				var drive: float=side if absf(speed)<.04 else signf(speed)
				var next_action: String="bias_right" if drive>=0 else "bias_left"
				if next_action!=action:
					if action!="":Input.action_release(action)
					action=next_action
					Input.action_press(action)
					row.swing_actions+=1
				await physics_frame
				hit=surface(point)
				actual=hit.get("position",point)
				if app.controller.get_shoulder_world(hand).distance_to(actual)<app.controller.get_max_reach()-.015:break
			if action!="":Input.action_release(action)
		row.attempts+=1
		mouse(hand,true,point)
		var caught:=false
		for frame in int(.9*hz):
			await physics_frame
			if app.controller.get_hand_state(hand)=="ATTACHED":
				caught=true
				break
			if app.controller.get_hand_state(hand) in ["FREE","RELEASED"]:break
		row.events.append({"index":index,"body":str(app.torso.position),"caught":caught,"reason":app.controller.hands[hand].reason,"rejection":app.controller.last_rejection,"intended":str(point),"surface":str(actual),"surface_name":str(hit.get("collider").name) if not hit.is_empty() else "none","reach":app.controller.get_shoulder_world(hand).distance_to(actual),"posture":app.controller.telemetry().get("posture",{})})
		if not caught:
			row.failure=app.controller.last_rejection if app.controller.last_rejection!="" else app.controller.hands[hand].reason
			break
		await ticks(int(.35*hz))
		if previous>=0:
			mouse(previous,false,point)
			row.transfers+=1
		previous=hand
		await ticks(int(1.1*hz))
	row.end_y=app.torso.position.y
	row.elapsed=app.trial.elapsed
	print("INDEPENDENT ROUTE ",JSON.stringify(row))
	for hand in 2:mouse(hand,false,Vector3(0,2,0))
	active_row={}
	app.queue_free()
	await ticks(3)
	return row

func run() -> void:
	report.physics_hz=hz
	for spacing in [.16,.20]:
		for policy in [0,1,2]:
			var row: Dictionary=await trial(policy,spacing)
			report.runs.append(row)
			check(row.bounded,"route respects original force/torque budgets; policy%d spacing%.2f" % [policy,spacing])
			if policy==0:
				check(row.attempts>0,"hold-length reference measured with the same deliberate steering rule")
			else:
				check(row.transfers==10,"ten consecutive real-input hand transfers; policy%d spacing%.2f" % [policy,spacing])
	FileAccess.open("res://builds/independent_routes_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("INDEPENDENT ROUTES RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
