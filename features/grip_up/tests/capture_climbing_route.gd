extends "res://features/grip_up/tests/capture_intent_candidate.gd"
## Real native inputs through the course. Never writes character state.
var continuous:=true
var watch_support:=false
var suspension_time:=0.0
var longest_suspension:=0.0

func audit(delta:float) -> void:
	super.audit(delta)
	if watch_support and app.controller._attached_ids().is_empty():continuous=false
	var final_contact:bool=app.controller.hands.any(func(hand):return hand.state=="ATTACHED" and hand.support==app.level.holds[-1])
	var unloaded:bool=not app.ground_motor.grounded and app.torso.position.y>=1.6 and app.controller.telemetry().leg_force<=1
	suspension_time=suspension_time+delta if final_contact and unloaded else 0.0
	longest_suspension=maxf(longest_suspension,suspension_time)

func transfer(id:int,index:int) -> bool:
	button(MOUSE_BUTTON_LEFT if id==0 else MOUSE_BUTTON_RIGHT,false)
	aim(app.level.transfer_points[index])
	button(MOUSE_BUTTON_LEFT if id==0 else MOUSE_BUTTON_RIGHT,true)
	for frame in 3*hz:
		await get_tree().physics_frame
		if app.controller.get_hand_state(id)=="ATTACHED":return true
	return false

func run() -> void:
	report.physics_hz=hz
	report.provenance="Godot MCP Pro scripted route, not human flow evaluation"
	record_folder="C:/Users/Wynter/grip_up/builds/v073_candidate_frames"
	DirAccess.make_dir_recursive_absolute(record_folder)
	app._open_intent_arena(10,true)
	app._set_distant_targeting(true)
	app.debug_visible=false
	app.hint_time=0
	app.capture_trace.path="user://v073_native_%dhz.jsonl" % hz
	FileAccess.open(app.capture_trace.path,FileAccess.WRITE).close()
	app.capture_trace.enabled=true
	app.controller.sample_ready.connect(audit)
	recording=hz==120
	await ticks(.45)
	check(app.input_profile==4 and app.physical_feet_enabled and app.allow_out_of_reach_grip_targets,"native course selects intended existing locomotion and maximum-reach setup")
	check(await catch_hand(0,app.level.transfer_points[0]),"native initial left wall contact")
	check(await catch_hand(1,app.level.transfer_points[1]),"native initial right wall contact")
	watch_support=true
	await ticks(.3)
	await shot("v073_route_start")
	var start_y:float=app.torso.position.y
	Input.action_press("contract")
	await ticks(3)
	check(await transfer(0,2),"native higher left wall transfer")
	await ticks(.25)
	Input.action_press("bias_right")
	check(await transfer(1,3),"native higher right wall transfer")
	Input.action_release("bias_right")
	await ticks(1.0)
	await shot("v073_route_climb")
	Input.action_press("bias_right")
	check(await transfer(0,4),"native left transfer across wall")
	await ticks(.6)
	check(await transfer(1,5),"native right transfer toward hanging section")
	await ticks(.3)
	await shot("v073_route_traverse")
	for frame in 2*hz:
		if app.controller.get_shoulder_world(0).distance_to(app.level.transfer_points[6])<.64:break
		await get_tree().physics_frame
	check(await transfer(0,6),"native first bar finite contact")
	await ticks(.3)
	check(await transfer(1,7),"native right hand advances along the first bar")
	await ticks(.3)
	check(await transfer(0,8),"native left hand advances on the same real bar")
	await ticks(.3)
	check(await transfer(1,9),"native finish bar finite contact")
	await ticks(.6)
	Input.action_release("bias_right")
	await ticks(.8)
	check(app.climbing_route.completed and app.won,"native real contacts complete all three broad regions and finish")
	check(continuous,"native route retains at least one real grip throughout")
	check(longest_suspension>=.2,"native finish includes at least200ms of real elevated suspension with total feet load at most1N")
	check(not app.rating_panel.visible,"native finish leaves movement and mouse control available")
	check(caps_ok,"native course uses unchanged hands feet and common moment caps")
	report.route=app.climbing_route.diagnostics()
	report.height_gain=app.torso.position.y-start_y
	report.longest_suspension=longest_suspension
	report.finish_telemetry=app.controller.telemetry()
	await shot("v073_route_finish")
	watch_support=false
	Input.action_release("contract")
	for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
	await ticks(.1)
	check(app.controller.telemetry().total_force==0,"native release still removes hand actuation after finish")
	recording=false
	report.demo_frames=frame_number
	app.capture_trace.enabled=false
	app.capture_trace.close()
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/climbing_route_native_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	Engine.physics_ticks_per_second=120
	app._open_intent_arena(10,true)
	app._set_distant_targeting(true)
	app.hint_time=0
	queue_free()
