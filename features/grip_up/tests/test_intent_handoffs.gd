extends "res://features/grip_up/tests/test_intent_integration.gd"
## Actual mouse actions through two deliberate transfers on the existing Step.
var continuous_support:=true
var pending_unladen:=true
var observations:Array=[]

func observe(_delta:float) -> void:
	if app.controller._attached_ids().is_empty():continuous_support=false
	for id in 2:
		if app.controller.get_hand_state(id)=="REACHING" and app.controller.pending_diagnostics(id).get("active",false):
			pending_unladen=pending_unladen and app.controller.get_arm_force(id)==Vector3.ZERO and app.controller.hands[id].allocation==0
	if observations.size()<2000:
		observations.append({"time":app.trial.elapsed,"position":app.torso.position,"velocity":app.torso.linear_velocity,"states":[app.controller.get_hand_state(0),app.controller.get_hand_state(1)],"force":app.controller.telemetry().total_force,"mode":app.controller.telemetry().get("intent_locomotion",{}).get("support_mode","")})

func run() -> void:
	await fresh(6,true)
	app._set_distant_targeting(true)
	check(await grip(0,app.level.transfer_points[0]) and await grip(1,app.level.transfer_points[1]),"Step starts with two actually held low contacts")
	app.controller.sample_ready.connect(observe)
	await ticks(.3)
	Input.action_press("contract")
	await ticks(3)
	var old_anchor=app.controller.hands[1].anchor
	var pose:Transform3D=app.torso.global_transform
	var velocity:Vector3=app.torso.linear_velocity
	button(0,false)
	check(app.controller.hands[1].anchor==old_anchor and app.torso.global_transform==pose and app.torso.linear_velocity==velocity,"first release preserves supporting right anchor, pose and momentum")
	var first:bool=await grip(0,app.level.transfer_points[2])
	check(first,"left hand actually reaches the first higher selected point")
	await ticks(.25)
	var left_anchor=app.controller.hands[0].anchor
	pose=app.torso.global_transform
	velocity=app.torso.linear_velocity
	button(1,false)
	check(app.controller.hands[0].anchor==left_anchor and app.torso.global_transform==pose and app.torso.linear_velocity==velocity,"second release preserves new left support without a handoff snap")
	aim(app.level.transfer_points[3])
	button(1,true)
	var selected:Dictionary=app.controller.pending_diagnostics(1).duplicate(true)
	check(selected.get("active",false),"one right press remembers the second higher contact")
	Input.action_press("bias_right")
	for frame in int(3*hz):
		if frame==int(.3*hz):Input.action_release("bias_right")
		await ticks(1.0/hz)
		if app.controller.get_hand_state(1)=="ATTACHED":break
		if app.controller.get_hand_state(1) in ["FREE","RELEASED"]:break
	var second:bool=app.controller.get_hand_state(1)=="ATTACHED"
	Input.action_release("bias_right")
	check(second,"W with a brief deliberate D request earns the second higher right contact")
	check(second and app.controller.hands[1].anchor.local_point==selected.get("local_point",Vector3.INF),"the right request never retargets the chosen material point")
	Input.action_release("contract")
	await ticks(.4)
	check(continuous_support,"both higher handoffs retain at least one real support throughout")
	check(pending_unladen,"future right target never contributes force or allocation before contact")
	check(budgets_ok,"handoffs preserve same shared hands, feet and combined moment caps")
	report={"physics_hz":hz,"first_caught":first,"second_caught":second,"second_selection":selected,"final_pending":app.controller.pending_diagnostics(1),"final_intent":app.controller.telemetry().get("intent_locomotion",{}),"end_position":app.torso.position,"continuous_support":continuous_support,"samples":observations,"checks":checks,"failures":failures}
	app.controller.sample_ready.disconnect(observe)
	for id in 2:button(id,false)
	app.queue_free()
	await ticks(.03)
	FileAccess.open("res://builds/intent_handoffs_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("INTENT HANDOFFS RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
