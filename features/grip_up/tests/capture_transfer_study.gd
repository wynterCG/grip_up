extends "res://features/grip_up/tests/capture_independent.gd"
## Native scripted-player evidence. Human session requirements remain separate.
func run() -> void:
	record_folder="C:/Users/Wynter/grip_up/builds/v05_m1_route_frames_final"
	DirAccess.make_dir_recursive_absolute(record_folder)
	app._set_posture_policy(1)
	app._set_predictive_grip(false)
	app._set_physical_feet(false)
	app._set_experimental_launch(false)
	app._open_transfer_lab(4)
	app.won=true
	report.session_id=app.transfer_session_id
	app.capture_trace.path="user://v05_m1_rendered_%dhz.jsonl" % hz
	FileAccess.open(app.capture_trace.path,FileAccess.WRITE).close()
	app.capture_trace.enabled=true
	await ticks(.45)
	report.physics_hz=hz
	report.phase="v0.5 M1 / P0 unchanged suspension"
	recording=hz==120
	app.debug_visible=true
	aim(Vector3(1,3.4,0))
	button(MOUSE_BUTTON_RIGHT,true)
	var failure: Dictionary=app.controller.transfer_diagnostics().last_by_hand.get(1,{})
	check(failure.get("code")=="POSE_UNREACHABLE" and failure.get("anatomical_distance",0)>app.controller.get_max_reach(),"native failed admission has measured geometric diagnosis")
	await ticks(.1)
	await shot("v05_m1_pose_failure")
	button(MOUSE_BUTTON_RIGHT,false)
	app.debug_visible=false
	var previous:=-1
	var timing_wait:=0.0
	var catches: Array=[]
	for index in 11:
		var hand: int=index%2
		var point: Vector3=app.level.transfer_points[index]
		if previous>=0:
			for frame in 2*hz:
				if app.controller.get_shoulder_world(hand).distance_to(point)<app.controller.get_max_reach()-.005:break
				await get_tree().physics_frame
				timing_wait+=1.0/hz
		aim(point)
		button(MOUSE_BUTTON_LEFT if hand==0 else MOUSE_BUTTON_RIGHT,true)
		var caught:=false
		for frame in int(.9*hz):
			await get_tree().physics_frame
			if app.controller.get_hand_state(hand)=="ATTACHED":
				caught=true
				break
			if app.controller.get_hand_state(hand) in ["FREE","RELEASED"]:break
		catches.append({"index":index,"caught":caught,"diagnosis":app.controller.transfer_diagnostics().last_by_hand.get(hand,{})})
		if not caught:break
		await ticks(.35)
		if previous>=0:button(MOUSE_BUTTON_LEFT if previous==0 else MOUSE_BUTTON_RIGHT,false)
		previous=hand
		await ticks(1.1)
	report.route=app.transfer_progress.diagnostics()
	report.route.timing_wait=timing_wait
	report.route.catches=catches
	report.route.elapsed=app.trial.elapsed
	check(app.transfer_progress.transfers==10,"native reference route completes ten contacts through real input and timing")
	check(app.transfer_progress.recoveries==0,"native reference route has no unsupported interruption")
	app.debug_visible=true
	await shot("v05_m1_ten_transfers")
	recording=false
	report.demo_frames=frame_number
	for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
	app.capture_trace.enabled=false
	app.capture_trace.close()
	app._open_transfer_lab(4)
	app.settings.show()
	await ticks(.1)
	await shot("v05_m1_controls")
	app.settings.hide()
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/transfer_study_m1_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	queue_free()
