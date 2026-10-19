extends "res://features/grip_up/tests/capture_intent_candidate.gd"
## Native real-input follow-up: Step comparison, two handoffs and counter-command.
var watch_support:=false
var supported_throughout:=true
var pending_unladen:=true

func audit(delta:float) -> void:
	super.audit(delta)
	if watch_support and app.controller._attached_ids().is_empty():supported_throughout=false
	for id in 2:
		if app.controller.get_hand_state(id)=="REACHING" and app.controller.pending_diagnostics(id).get("active",false):
			pending_unladen=pending_unladen and app.controller.get_arm_force(id)==Vector3.ZERO and app.controller.hands[id].allocation==0

func run() -> void:
	report.physics_hz=hz
	report.provenance="Scripted Godot MCP Pro input, not human evaluation of v0.7.1"
	record_folder="C:/Users/Wynter/grip_up/builds/v071_candidate_frames"
	DirAccess.make_dir_recursive_absolute(record_folder)
	app.capture_trace.path="user://v071_native_%dhz.jsonl" % hz
	FileAccess.open(app.capture_trace.path,FileAccess.WRITE).close()
	app.capture_trace.enabled=true
	recording=hz==120
	report.steps=[]
	for feet_on in [false,true]:
		await prepare(6,feet_on)
		app._set_distant_targeting(true)
		check(await catch_hand(0,app.level.transfer_points[0]),"native left finite low contact feet%s" % feet_on)
		check(await catch_hand(1,app.level.transfer_points[1]),"native right finite low contact feet%s" % feet_on)
		watch_support=feet_on
		await ticks(.3)
		var initial_y:float=app.torso.position.y
		var hand_load:=0.0
		var foot_load:=0.0
		Input.action_press("contract")
		for frame in 3*hz:
			await get_tree().physics_frame
			var data:Dictionary=app.controller.telemetry()
			hand_load+=data.total_force/hz
			foot_load+=data.leg_force/hz
		var row:={"feet":feet_on,"rise":app.torso.position.y-initial_y,"hand_load_integral":hand_load,"foot_load_integral":foot_load,"higher_caught":false}
		check(row.rise>.05,"native W produces physical progress feet%s" % feet_on)
		await shot("v071_step_%s" % feet_on)
		if feet_on:
			var survivor=app.controller.hands[1].anchor
			var pose:Transform3D=app.torso.global_transform
			var velocity:Vector3=app.torso.linear_velocity
			button(MOUSE_BUTTON_LEFT,false)
			check(app.controller.hands[1].anchor==survivor and app.torso.global_transform==pose and app.torso.linear_velocity==velocity,"native old hand release preserves survivor and momentum")
			row.higher_caught=await catch_hand(0,app.level.transfer_points[2])
			check(row.higher_caught,"native first chosen higher hand contact succeeds")
			await shot("v071_first_handoff")
			if row.higher_caught:
				await ticks(.25)
				button(MOUSE_BUTTON_RIGHT,false)
				aim(app.level.transfer_points[3])
				button(MOUSE_BUTTON_RIGHT,true)
				var selection:Dictionary=app.controller.pending_diagnostics(1).duplicate(true)
				Input.action_press("bias_right")
				for frame in 3*hz:
					if frame==int(.3*hz):Input.action_release("bias_right")
					await get_tree().physics_frame
					if app.controller.get_hand_state(1)=="ATTACHED":break
					if app.controller.get_hand_state(1) in ["FREE","RELEASED"]:break
				Input.action_release("bias_right")
				var caught:bool=app.controller.get_hand_state(1)=="ATTACHED"
				check(caught,"native second chosen higher contact succeeds with W and brief D")
				check(caught and app.controller.hands[1].anchor.local_point==selection.get("local_point",Vector3.INF),"native second contact retains the exact point from one press")
				report.second_handoff={"selection":selection,"contact":app.controller.pending_diagnostics(1),"caught":caught}
				await shot("v071_second_handoff")
		Input.action_release("contract")
		watch_support=false
		report.steps.append(row)
	check(supported_throughout,"native two transfers never lose all real hand supports")
	check(pending_unladen,"native pending hands remain unladen throughout")
	await prepare(7,false)
	app._set_distant_targeting(true)
	check(await catch_hand(0,app.level.transfer_points[0]),"native Hang starts from actual grip")
	Input.action_press("bias_right")
	await ticks(.4)
	Input.action_release("bias_right")
	Input.action_press("bias_left")
	await ticks(.2)
	var counter:Dictionary=app.controller.telemetry().intent_locomotion
	check(counter.get("swing_reversal_active",false),"native opposite A command activates the shorter counter-command path")
	report.counter_command=counter
	await shot("v071_hang")
	Input.action_release("bias_left")
	for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
	await ticks(.1)
	check(app.controller.telemetry().total_force==0 and Vector3(app.controller.telemetry().torque)==Vector3.ZERO,"native actual release removes climb actuation")
	check(caps_ok,"native hand foot and common moment caps stay unchanged")
	recording=false
	report.demo_frames=frame_number
	app.capture_trace.enabled=false
	app.capture_trace.close()
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/intent_refinement_native_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	Engine.physics_ticks_per_second=120
	app._open_intent_arena(6,true)
	app._set_distant_targeting(true)
	app.debug_visible=false
	app.hint_time=0
	queue_free()
