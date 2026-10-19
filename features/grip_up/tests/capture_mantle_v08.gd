extends "res://features/grip_up/tests/capture_intent_candidate.gd"
## Native failed functional evidence, using in-app input only; no OS focus grab.
var active_row:Dictionary={}
var elapsed:=0.0
var sample_next:=0.0

func observe(delta:float)->void:
	if active_row.is_empty():return
	elapsed+=delta
	for hand in app.controller.hands:
		if hand.get("contact_mode","")=="PALM_CONTACT":
			active_row.max_palm_force=maxf(active_row.max_palm_force,Vector3(hand.force).length())
	active_row.max_speed=maxf(active_row.max_speed,app.torso.linear_velocity.length())
	if elapsed>=sample_next:
		sample_next=elapsed+.1
		active_row.samples.append({"time":elapsed,"position":app.torso.position,"velocity":app.torso.linear_velocity,"hands":app.controller.hands.map(func(hand):return {"state":hand.state,"reason":hand.reason,"mode":hand.get("contact_mode",""),"force":hand.force,"palm":hand.get("palm",{})}),"support":app.mantle_v08.data.duplicate(true),"visual_foot_error":app.biped.physical_foot_mismatch})

func image_evidence(label:String)->void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/v08_%dhz_%s.png"%[hz,label])

func run()->void:
	report.physics_hz=hz
	report.provenance="Godot MCP Pro in-app held mouse/actions on monitor2; configured hanging fixture; not human ordinary approach"
	report.window_screen=get_window().current_screen
	report.trials=[]
	for index in [12,13]:
		for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
		for action in ["contract","extend","bias_left","bias_right"]:Input.action_release(action)
		app.mantle_hanging_fixture_start=true
		app._open_mantle_v08(index)
		app.controller.sample_ready.connect(audit)
		app.controller.sample_ready.connect(observe)
		await ticks(.35)
		app.camera.orbit(Vector2(0,160))
		app.camera._update_camera(1.0)
		active_row={"top":app.level.top_y,"samples":[],"max_palm_force":0.0,"max_speed":0.0,"body_write_policy":"Scene setup below edge only; no subsequent body pose/velocity writes"}
		elapsed=0
		sample_next=0
		check(await catch_hand(0,app.level.transfer_points[0]),"native finite left edge contact on ledge%d"%index)
		check(await catch_hand(1,app.level.transfer_points[1]),"native finite right edge contact on ledge%d"%index)
		app.level.start_pad.queue_free()
		for frame in 2*hz:
			await ticks(1.0/hz)
			if app.mantle_v08.had_hanging_start:break
		active_row.actual_hanging_start=app.mantle_v08.had_hanging_start
		check(active_row.actual_hanging_start,"native loaded hanging start on ledge%d"%index)
		await image_evidence("hang_%d"%index)
		Input.action_press("contract")
		await ticks(.7)
		button(MOUSE_BUTTON_LEFT,false)
		active_row.h0_contact=await catch_hand(0,app.level.transfer_points[2])
		await ticks(.1)
		await image_evidence("palm_%d"%index)
		await ticks(.4)
		if active_row.h0_contact and app.controller.get_arm_force(0).length()>1:
			button(MOUSE_BUTTON_RIGHT,false)
			active_row.right_palm_contact=await catch_hand(1,app.level.transfer_points[3])
		for frame in 8*hz:
			await ticks(1.0/hz)
			if app.ground_motor.grounded and app.ground_motor.support_body==app.level.platform:
				for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
		Input.action_release("contract")
		active_row.functional_completion=app.mantle_v08.completed
		active_row.final=app.mantle_v08.data.duplicate(true)
		await image_evidence("failed_topout_%d"%index)
		check(not active_row.functional_completion or active_row.final.actual_top_ground,"native completion cannot bypass real top ground on ledge%d"%index)
		report.trials.append(active_row)
		active_row={}
		for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
		await ticks(.1)
		check(app.controller.telemetry().total_force==0,"native release removes all hand load on ledge%d"%index)
	check(caps_ok,"native unchanged hand/foot and combined moment limits")
	report.functional_gate_met=report.trials.all(func(row):return row.functional_completion)
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/mantle_v08_native_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	Engine.physics_ticks_per_second=120
	app.mantle_hanging_fixture_start=false
	app._open_mantle_v08(12)
	app.hint_time=0
	queue_free()
