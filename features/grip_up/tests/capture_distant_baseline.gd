extends "res://features/grip_up/tests/capture_independent.gd"
func run() -> void:
	app._save_trial("v0.6_baseline_capture")
	app._set_predictive_grip(false)
	app._set_catch_buffer(false)
	app.reach_prediction_enabled=false
	app.transfer_assist_enabled=false
	app._set_posture_variant(0)
	app._open_transfer_lab(5)
	app.won=true
	await ticks(.45)
	aim(app.level.transfer_points[0])
	button(MOUSE_BUTTON_LEFT,true)
	await ticks(.5)
	check(app.controller.get_hand_state(0)=="ATTACHED","native baseline real left support")
	var point:Vector3=app.level.transfer_points[1]+Vector3(0,-.051,0)
	aim(point)
	button(MOUSE_BUTTON_RIGHT,true)
	var result:Dictionary=app.controller.transfer_diagnostics().last_by_hand.get(1,{})
	check(result.get("code")=="POSE_UNREACHABLE" and app.controller.get_hand_state(1)=="FREE","native v0.5 rejects distant right target at mouse-down")
	app.debug_visible=true
	await shot("v06_baseline_rejection")
	report.event=result
	report.baseline="dac5f6d"
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/distant_native_baseline.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	button(MOUSE_BUTTON_RIGHT,false)
	button(MOUSE_BUTTON_LEFT,false)
	app.debug_visible=false
	queue_free()
