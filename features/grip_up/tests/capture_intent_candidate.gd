extends "res://features/grip_up/tests/capture_independent.gd"
## Scripted MCP evidence only; leaves the Step ready for human comparison.
var caps_ok:=true

func audit(_delta:float) -> void:
	var data:Dictionary=app.controller.telemetry()
	caps_ok=caps_ok and data.total_force<=360.001 and data.leg_force<=180.001
	caps_ok=caps_ok and (Vector3(data.torque)+app.ground_motor.applied_torque).length()<=150.001

func prepare(index:int,feet_on:bool) -> void:
	for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
	for action in ["contract","extend","bias_left","bias_right"]:Input.action_release(action)
	app._open_intent_arena(index,feet_on)
	app.won=true
	app.controller.sample_ready.connect(audit)
	await ticks(.45)

func catch_hand(id:int,point:Vector3) -> bool:
	aim(point)
	button(MOUSE_BUTTON_LEFT if id==0 else MOUSE_BUTTON_RIGHT,true)
	for frame in hz:
		await get_tree().physics_frame
		if app.controller.get_hand_state(id)=="ATTACHED":return true
	return false

func run() -> void:
	report.physics_hz=hz
	report.provenance="Godot MCP Pro scripted input; no human comfort/agency claim"
	app.capture_trace.path="user://v07_native_%dhz.jsonl" % hz
	FileAccess.open(app.capture_trace.path,FileAccess.WRITE).close()
	app.capture_trace.enabled=true
	record_folder="C:/Users/Wynter/grip_up/builds/v07_candidate_frames"
	DirAccess.make_dir_recursive_absolute(record_folder)
	recording=hz==120
	report.steps=[]
	for feet_on in [false,true]:
		await prepare(6,feet_on)
		check(await catch_hand(0,app.level.transfer_points[0]),"native left Step contact feet%s" % feet_on)
		check(await catch_hand(1,app.level.transfer_points[1]),"native right Step contact feet%s" % feet_on)
		await ticks(.3)
		var step_start:Vector3=app.torso.position
		var hand_load:=0.0
		var foot_load:=0.0
		Input.action_press("contract")
		for frame in 3*hz:
			await get_tree().physics_frame
			var data:Dictionary=app.controller.telemetry()
			hand_load+=data.total_force/hz
			foot_load+=data.leg_force/hz
		Input.action_release("contract")
		var rise:float=app.torso.position.y-step_start.y
		var row:={"feet":feet_on,"rise":rise,"hand_load_integral":hand_load,"foot_load_integral":foot_load,"position":str(app.torso.position),"intent":app.controller.telemetry().intent_locomotion}
		check(rise>.05,"native W has actual upward progress feet%s" % feet_on)
		await shot("v07_step_%s" % feet_on)
		button(MOUSE_BUTTON_LEFT,false)
		row.higher_caught=await catch_hand(0,app.level.transfer_points[2])
		if feet_on:check(row.higher_caught,"native physical feet earn the deliberately selected higher grip")
		report.steps.append(row)
	check(report.steps[1].foot_load_integral>1,"native physical feet carry genuine load")
	check(report.steps[1].rise>report.steps[0].rise+.02,"native feet improve actual Step progress over hands-only")
	await prepare(8,false)
	check(await catch_hand(0,app.level.transfer_points[0]) and await catch_hand(1,app.level.transfer_points[1]),"native Traverse starts with two real supports")
	var start:Vector3=app.torso.position
	Input.action_press("bias_right")
	await ticks(.12)
	var direction:Vector3=app.controller.telemetry().intent_locomotion.movement_intent_world
	var before_supports:int=app.controller._attached_ids().size()
	button(MOUSE_BUTTON_MIDDLE,true)
	motion(app.pointer+Vector2(130,0))
	await ticks(.1)
	button(MOUSE_BUTTON_MIDDLE,false)
	var after:Vector3=app.controller.telemetry().intent_locomotion.movement_intent_world
	check(before_supports>0 and app.controller._attached_ids().size()>0 and direction.normalized().dot(after.normalized())>.999,"native MMB orbit preserves held D command direction while real support persists")
	Input.action_release("bias_right")
	report.traverse={"change":str(app.torso.position-start),"retained_hands":app.controller._attached_ids().size(),"intent":app.controller.telemetry().intent_locomotion}
	check(app.torso.position.x>start.x+.02,"native traversal request produces actual lateral displacement")
	await shot("v07_traverse")
	await prepare(7,false)
	check(await catch_hand(0,app.level.transfer_points[0]),"native Hang starts from one explicit bar contact")
	Input.action_press("bias_right")
	await ticks(.4)
	Input.action_release("bias_right")
	Input.action_press("bias_left")
	await ticks(.3)
	Input.action_release("bias_left")
	await shot("v07_hang")
	check(caps_ok,"native all support budgets including ground handoff stay bounded")
	for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
	await ticks(.1)
	check(app.controller.telemetry().total_force==0 and Vector3(app.controller.telemetry().torque)==Vector3.ZERO,"native release removes climb actuation")
	recording=false
	report.demo_frames=frame_number
	app.capture_trace.enabled=false
	app.capture_trace.close()
	app.debug_visible=false
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/intent_native_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	Engine.physics_ticks_per_second=120
	app._open_intent_arena(6,true)
	app.debug_visible=false
	app.hint_time=0
	queue_free()
