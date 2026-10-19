extends "res://features/grip_up/tests/capture_independent.gd"
## Native player input: an overshot wall click can resolve a real reachable grip.
var caps_ok:=true
var pending_unladen:=true

func audit(_delta:float) -> void:
	var data:Dictionary=app.controller.telemetry()
	caps_ok=caps_ok and data.total_force<=360.001 and data.leg_force<=180.001
	caps_ok=caps_ok and (Vector3(data.torque)+app.ground_motor.applied_torque).length()<=150.001
	if app.controller.get_hand_state(1)=="REACHING":
		pending_unladen=pending_unladen and app.controller.get_arm_force(1)==Vector3.ZERO and app.controller.hands[1].allocation==0

func run() -> void:
	report.physics_hz=hz
	report.provenance="Scripted native Godot MCP Pro input, not human feedback"
	report.trials=[]
	app.capture_trace.path="user://v072_native_%dhz.jsonl" % hz
	FileAccess.open(app.capture_trace.path,FileAccess.WRITE).close()
	app.capture_trace.enabled=true
	for overshoot in [.03,.15]:
		for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
		app._open_intent_arena(6,false)
		app._set_distant_targeting(true)
		app.won=true
		app.hint_time=0
		app.controller.sample_ready.connect(audit)
		await ticks(.5)
		var shoulder:Vector3=app.controller.get_shoulder_world(1)
		var reach:float=app.controller.get_max_reach()
		var height:float=sqrt(maxf(0.0,reach*reach-shoulder.z*shoulder.z))
		var clicked:=Vector3(shoulder.x,shoulder.y+height+overshoot,0)
		var before:Vector3=app.controller.get_hand_world(1)
		var pose:Transform3D=app.torso.global_transform
		var velocity:Vector3=app.torso.linear_velocity
		aim(clicked)
		button(MOUSE_BUTTON_RIGHT,true)
		var selection:Dictionary=app.controller.pending_diagnostics(1).duplicate(true)
		check(shoulder.distance_to(clicked)>reach,"native click truly overshoots anatomy by requested wall height %s" % overshoot)
		check(selection.get("contact_resolution_applied",false),"native overshot wall click resolves an eligible reachable contact %s" % overshoot)
		check(app.controller.get_hand_world(1)==before and app.torso.global_transform==pose and app.torso.linear_velocity==velocity,"native mouse-down never teleports hand/body or edits momentum %s" % overshoot)
		var contacted:=false
		var maximum_force:=0.0
		var contact_point:=Vector3.INF
		for frame in hz:
			await get_tree().physics_frame
			if app.controller.get_hand_state(1)=="ATTACHED":
				contacted=true
				contact_point=app.controller.hands[1].anchor.world_point()
			maximum_force=maxf(maximum_force,app.controller.get_arm_force(1).length())
		check(contacted and maximum_force>1,"native finite hand reaches real contact and then applies load %s" % overshoot)
		check(contacted and contact_point.distance_to(clicked)>.01,"native actual grip is below the unreachable click %s" % overshoot)
		report.trials.append({"overshoot_height":overshoot,"requested_point":clicked,"selection":selection,"contacted":contacted,"actual_contact":contact_point,"maximum_force":maximum_force,"end_state":app.controller.get_hand_state(1),"end_pending":app.controller.pending_diagnostics(1)})
		await shot("v072_reach_%s" % str(overshoot).replace(".","_"))
	check(pending_unladen,"native free hand never exerts load before real contact")
	check(caps_ok,"native maximum reach retains existing shared force and moment caps")
	for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
	await ticks(.1)
	check(app.controller.telemetry().total_force==0,"native mouse-up removes hand actuation")
	app.capture_trace.enabled=false
	app.capture_trace.close()
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/reachable_grip_native_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	Engine.physics_ticks_per_second=120
	app._open_intent_arena(6,true)
	app._set_distant_targeting(true)
	app.debug_visible=false
	app.hint_time=0
	queue_free()
