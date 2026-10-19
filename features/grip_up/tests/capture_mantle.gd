extends "res://features/grip_up/tests/capture_intent_candidate.gd"
## MCP native evidence. Safety checks and measured top-out success are distinct.

func run()->void:
	report.physics_hz=hz
	report.provenance="Godot MCP Pro real held mouse/actions; M6 capability experiment, not human feel evidence"
	report.capability=[]
	app.capture_trace.path="user://v074_native_%dhz.jsonl"%hz
	FileAccess.open(app.capture_trace.path,FileAccess.WRITE).close()
	app.capture_trace.enabled=true
	for feet_on in [false,true]:
		await prepare(11,feet_on)
		app._set_distant_targeting(true)
		app.won=false
		check(app.controller.intent_auto_mantle_enabled,"native ledge explicitly enables the experiment feet%s"%feet_on)
		check(await catch_hand(0,app.level.transfer_points[0]),"native left finite ledge contact feet%s"%feet_on)
		check(await catch_hand(1,app.level.transfer_points[1]),"native right finite ledge contact feet%s"%feet_on)
		await ticks(.65)
		check(not app.won and not app.mantle_completed,"native edge contact never masquerades as a top-out")
		await shot("v074_ledge_start_%s"%feet_on)
		var start:Vector3=app.torso.position
		var row:={"physical_feet":feet_on,"start":start,"peak_y":start.y,"actual_top_ground_seen":false,"max_foot_force":0.0,"samples":[]}
		Input.action_press("contract")
		for frame in 4*hz:
			await get_tree().physics_frame
			var data:Dictionary=app.controller.telemetry()
			row.peak_y=maxf(row.peak_y,app.torso.position.y)
			row.max_foot_force=maxf(row.max_foot_force,data.leg_force)
			row.actual_top_ground_seen=row.actual_top_ground_seen or app.ground_motor.grounded and app.ground_motor.support_body==app.level.platform
			if frame%maxi(1,int(hz*.1))==0:row.samples.append({"t":float(frame)/hz,"position":app.torso.position,"hand_force":data.total_force,"feet_force":data.leg_force,"ledge":data.get("ledge_transfer",{})})
		Input.action_release("contract")
		row.end=app.torso.position
		row.acceptance_gate_met=app.mantle_completed
		row.ledge_transfer=app.controller.telemetry().get("ledge_transfer",{})
		report.capability.append(row)
		check(not app.mantle_completed or row.actual_top_ground_seen,"native completion requires real platform ground")
		await shot("v074_ledge_attempt_%s"%feet_on)
		for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
		await ticks(.15)
		check(app.controller.telemetry().total_force==0,"native release removes both hand loads")
		check(Vector3(app.controller.telemetry().get("ledge_transfer",{}).get("applied_torque",Vector3.ZERO)).length()<.001,"native release removes mantle torque")
	check(caps_ok,"native unchanged hand feet and combined moment limits")
	app.capture_trace.enabled=false
	app.capture_trace.close()
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/mantle_native_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	Engine.physics_ticks_per_second=120
	app._open_intent_arena(11,true)
	app._set_distant_targeting(true)
	app.hint_time=0
	queue_free()
