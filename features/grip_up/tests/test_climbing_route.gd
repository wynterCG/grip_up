extends "res://features/grip_up/tests/test_intent_integration.gd"
## Actual held mouse/actions through the authored short course; no body writes.
var samples:Array=[]
var contacts:Array=[]
var continuous:=true
var started_route:=false
var elapsed:=0.0
var next_sample:=0.0
var suspension_run:=0.0
var longest_suspension:=0.0
var peaks:={"hand_force":0.0,"leg_force":0.0,"combined_moment":0.0}

func sample(delta:float)->void:
	var ids:Array=[]
	for id in 2:
		if app.controller.get_hand_state(id)=="ATTACHED":ids.append(id)
	if started_route and ids.is_empty():continuous=false
	if not ids.is_empty():started_route=true
	var data:Dictionary=app.controller.telemetry()
	elapsed+=delta
	peaks.hand_force=maxf(peaks.hand_force,data.total_force)
	peaks.leg_force=maxf(peaks.leg_force,data.leg_force)
	peaks.combined_moment=maxf(peaks.combined_moment,(Vector3(data.torque)+app.ground_motor.applied_torque).length())
	var on_finish:bool=app.controller.hands.any(func(hand):return hand.state=="ATTACHED" and hand.support==app.level.holds[-1])
	var suspended:bool=on_finish and app.torso.position.y>=1.6 and not app.ground_motor.grounded and data.leg_force<=1
	suspension_run=suspension_run+delta if suspended else 0.0
	longest_suspension=maxf(longest_suspension,suspension_run)
	if elapsed>=next_sample:
		next_sample=elapsed+.1
		samples.append({"time":elapsed,"position":app.torso.position,"velocity":app.torso.linear_velocity,"hands":ids,"grounded":app.ground_motor.grounded,"stage":app.climbing_route.stage,"force":data.total_force,"leg_force":data.leg_force,"torque":Vector3(data.torque).length(),"left_state":app.controller.get_hand_state(0),"right_state":app.controller.get_hand_state(1)})

func transfer(id:int,index:int,seconds:float=3.0)->bool:
	button(id,false)
	aim(app.level.transfer_points[index])
	button(id,true)
	for frame in int(seconds*hz):
		await ticks(1.0/hz)
		if app.controller.get_hand_state(id)=="ATTACHED":
			contacts.append({"index":index,"hand":id,"position":app.torso.position,"contact":app.controller.hands[id].anchor.world_point(),"pending":app.controller.pending_diagnostics(id)})
			return true
	print("ROUTE BLOCK ",index," position ",app.torso.position," state ",app.controller.get_hand_state(id)," pending ",app.controller.pending_diagnostics(id))
	return false

func wait_reach_window(id:int,index:int,seconds:float)->void:
	for frame in int(seconds*hz):
		if app.controller.get_shoulder_world(id).distance_to(app.level.transfer_points[index])<.64:return
		await ticks(1.0/hz)

func run()->void:
	await fresh(10,true)
	app.won=false
	app._set_distant_targeting(true)
	check(await grip(0,app.level.transfer_points[0]),"initial left finite wall contact")
	check(await grip(1,app.level.transfer_points[1]),"initial right finite wall contact")
	app.controller.sample_ready.connect(sample)
	await ticks(.3)
	var start_y:float=app.torso.position.y
	Input.action_press("contract")
	await ticks(3)
	check(await transfer(0,2),"higher left wall transfer")
	await ticks(.25)
	Input.action_press("bias_right")
	check(await transfer(1,3),"higher right wall transfer")
	Input.action_release("bias_right")
	await ticks(1.0)
	Input.action_press("bias_right")
	check(await transfer(0,4),"left transfer into crossing region")
	await ticks(.6)
	check(await transfer(1,5),"right transfer toward wall edge")
	await ticks(.3)
	await wait_reach_window(0,6,2)
	check(await transfer(0,6),"left finite contact on first hanging bar")
	await ticks(.3)
	check(await transfer(1,7),"right finite intermediate contact on first hanging bar")
	await ticks(.3)
	check(await transfer(0,8),"left finite aligning contact on first hanging bar")
	await ticks(.3)
	check(await transfer(1,9),"right finite contact on finish hanging bar")
	await ticks(.6)
	Input.action_release("bias_right")
	await ticks(.8)
	check(app.climbing_route.completed,"all three broad stages physically completed")
	check(continuous,"one real supporting hand retained through every transfer")
	check(app.torso.position.y>1.6 and not app.ground_motor.grounded,"finish elevated above safe floor with actual suspension")
	check(longest_suspension>=.2,"finish has continuous actual arm-only suspension for at least200ms")
	check(budgets_ok,"hand leg and combined actuator moment budgets respected")
	report={"physics_hz":hz,"checks":checks,"failures":failures,"contacts":contacts,"samples":samples,"progress":app.climbing_route.diagnostics(),"height_gain":app.torso.position.y-start_y,"final_position":app.torso.position,"longest_suspension":longest_suspension,"peaks":peaks}
	FileAccess.open("res://builds/climbing_route_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	for action in ["contract","bias_right"]:Input.action_release(action)
	app.queue_free()
	await ticks(.03)
	print("CLIMBING ROUTE RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
