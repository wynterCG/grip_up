extends "res://features/grip_up/tests/capture_independent.gd"
## Scripted native evidence, separate from the interactive pilot archives.
func run() -> void:
	record_folder="C:/Users/Wynter/grip_up/builds/v05_final_frames"
	DirAccess.make_dir_recursive_absolute(record_folder)
	report.physics_hz=hz
	report.provenance="Godot MCP Pro scripted input; not a human comfort assessment"
	app.transfer_assist_enabled=true
	app._set_posture_variant(1)
	app._set_predictive_grip(false)
	app._set_catch_buffer(false)
	app.reach_prediction_enabled=true
	app._open_transfer_lab(4)
	app.won=true
	app.capture_trace.path="user://v05_final_native_%dhz.jsonl" % hz
	FileAccess.open(app.capture_trace.path,FileAccess.WRITE).close()
	app.capture_trace.enabled=true
	await ticks(.45)
	report.route_session=app.transfer_session_id
	check(app.controller.posture_variant==1 and app.controller.transfer_assist_enabled,"native explicit P1 flag reaches physical controller")
	check(not app.controller.tuning.predictive_grip,"advisory-only cannot enable physical catch buffer")
	recording=hz==120
	var previous:=-1
	for index in 11:
		var hand: int=index%2
		var point: Vector3=app.level.transfer_points[index]
		if previous>=0:
			for frame in 2*hz:
				if app.controller.get_shoulder_world(hand).distance_to(point)<app.controller.get_max_reach()-.005:break
				await get_tree().physics_frame
		aim(point)
		await ticks(.05)
		button(MOUSE_BUTTON_LEFT if hand==0 else MOUSE_BUTTON_RIGHT,true)
		var caught:=false
		for frame in int(.9*hz):
			await get_tree().physics_frame
			if app.controller.get_hand_state(hand)=="ATTACHED":caught=true;break
			if app.controller.get_hand_state(hand) in ["FREE","RELEASED"]:break
		check(caught,"native P1 finite contact %02d" % index)
		if not caught:break
		await ticks(.35)
		if previous>=0:button(MOUSE_BUTTON_LEFT if previous==0 else MOUSE_BUTTON_RIGHT,false)
		previous=hand
		await ticks(1.1)
	report.route=app.transfer_progress.diagnostics()
	check(app.transfer_progress.transfers==10 and app.transfer_progress.recoveries==0,"native P1 same reference geometry completes uninterrupted ten transfers")
	app.debug_visible=true
	await shot("v05_final_ten")
	recording=false
	report.demo_frames=frame_number
	for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
	# Independent initial-condition calibration: not an authored route success.
	report.buffer_cases=[]
	for buffer in [false,true]:
		app._set_catch_buffer(buffer)
		app.load_test(0)
		app.won=true
		app.torso.position=Vector3(0,3,.45)
		app.torso.gravity_scale=0
		app.torso.linear_velocity=Vector3.UP
		app.torso.reset_physics_interpolation()
		app.controller.reset_state()
		await ticks(.05)
		var shoulder: Vector3=app.controller.get_shoulder_world(0)
		app.camera._update_camera(1)
		aim(Vector3(shoulder.x,shoulder.y+.52,0))
		app.prediction_clock=0
		app._process(0)
		var pose: Transform3D=app.torso.global_transform
		var velocity: Vector3=app.torso.linear_velocity
		button(MOUSE_BUTTON_LEFT,true)
		var waiting: bool=app.controller.hands[0].get("predictive_wait",false)
		check(waiting==buffer,"native early press buffer %s has expected pending status" % buffer)
		check(app.torso.global_transform==pose and app.torso.linear_velocity==velocity,"native request preserves body pose and momentum")
		var assessment: Dictionary=app.attempt_assessments[0].duplicate(true)
		motion(Vector2(50,50))
		await ticks(.6)
		check((app.controller.get_hand_state(0)=="ATTACHED")==buffer,"native finite catch requires held buffer when press precedes reach")
		check(app.attempt_assessments[0]==assessment,"native hover movement never rewrites captured attempt assessment")
		report.buffer_cases.append({"buffer":buffer,"assessment":assessment,"actual_state":app.controller.get_hand_state(0),"fixture":"same explicit initial position, 1m/s upward, gravity off; real physics after setup"})
		await shot("v05_buffer_"+str(buffer))
		button(MOUSE_BUTTON_LEFT,false)
	app.capture_trace.enabled=false
	app.capture_trace.close()
	app.transfer_assist_enabled=false
	app._set_posture_variant(0)
	app.reach_prediction_enabled=false
	app._set_catch_buffer(false)
	app._open_transfer_lab(4)
	app.debug_visible=false
	app.hint_time=0
	app.settings.show()
	await ticks(.1)
	await shot("v05_controls")
	app.settings.hide()
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/transfer_final_native_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	queue_free()
