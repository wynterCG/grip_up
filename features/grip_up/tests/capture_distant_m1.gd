extends "res://features/grip_up/tests/capture_independent.gd"
func run() -> void:
	app._set_distant_targeting(false)
	app._open_transfer_lab(5)
	app._set_posture_policy(0)
	app.won=true
	await ticks(.45)
	aim(app.level.transfer_points[0])
	button(MOUSE_BUTTON_LEFT,true)
	await ticks(.5)
	check(app.controller.get_hand_state(0)=="ATTACHED","native baseline supporting left acquired")
	app._set_distant_targeting(true)
	aim(app.level.transfer_points[1]+Vector3(0,-.051,0))
	button(MOUSE_BUTTON_RIGHT,true)
	var selected:Vector3=app.controller.hands[1].anchor.local_point
	motion(Vector2(50,50))
	await ticks(2)
	var data:Dictionary=app.controller.pending_diagnostics(1)
	check(data.active and app.controller.get_hand_state(1)=="REACHING" and app.controller.hands[1].anchor.local_point==selected,"native two-second pending persists without pointer retarget")
	check(app.controller.get_arm_force(1)==Vector3.ZERO and app.controller.hands[1].allocation==0 and data.workspace_valid,"native pending has no load and stays in anatomical workspace")
	app.debug_visible=true
	await shot("v06_m1_pending")
	report.pending=data
	button(MOUSE_BUTTON_RIGHT,false)
	check(not app.controller.pending_diagnostics(1).active and app.controller.get_hand_state(0)=="ATTACHED","native right release preserves left support")
	await ticks(.2)
	check(app.controller.get_hand_state(1)=="FREE","native cancelled target does not attach later")
	button(MOUSE_BUTTON_LEFT,false)
	app.debug_visible=false
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/distant_m1_native.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	queue_free()
