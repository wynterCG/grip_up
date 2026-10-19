extends "res://features/grip_up/tests/test_intent_integration.gd"
## Same geometry, explicit A/B/C baseline versus profile4 hands and feet.
const Actuator=preload("res://features/grip_up/scripts/arm_actuator.gd")

func step_trial(profile:int,policy:int,feet_on:bool) -> Dictionary:
	await fresh(6,feet_on)
	app._set_input_profile(profile)
	app._set_posture_policy(policy)
	check(await grip(0,app.level.transfer_points[0]),"Step left real contact profile%d policy%d feet%s" % [profile,policy,feet_on])
	check(await grip(1,app.level.transfer_points[1]),"Step right real contact profile%d policy%d feet%s" % [profile,policy,feet_on])
	await ticks(.3)
	var row:={"profile":profile,"policy":policy,"physical_feet":feet_on,"start_y":app.torso.position.y,"samples":[],"max_hand_force":0.0,"max_feet_force":0.0,"hand_load_integral":0.0,"foot_work_positive":0.0,"ground_authority":[],"first_higher_catch":false}
	Input.action_press("contract")
	for frame in 3*hz:
		await ticks(1.0/hz)
		var data:Dictionary=app.controller.telemetry()
		row.max_hand_force=maxf(row.max_hand_force,data.total_force)
		row.max_feet_force=maxf(row.max_feet_force,data.leg_force)
		row.hand_load_integral+=data.total_force/hz
		if app.controller.feet_solver!=null:
			for foot in app.controller.feet_solver.feet:
				row.foot_work_positive+=maxf(0.0,Vector3(foot.force).dot(Actuator.point_velocity(app.torso,foot.contact_point)))/hz
		if frame%(hz/10)==0:
			row.samples.append({"time":float(frame)/hz,"position":str(app.torso.position),"velocity":str(app.torso.linear_velocity),"hand_load":data.total_force,"foot_load":data.leg_force,"intent":data.get("intent_locomotion",{}),"step_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000})
		row.ground_authority.append(app.ground_motor.motor_authority)
	row.rise=app.torso.position.y-row.start_y
	row.higher_distance=app.controller.get_shoulder_world(0).distance_to(app.level.transfer_points[2])
	button(0,false)
	await ticks(.03)
	row.first_higher_catch=await grip(0,app.level.transfer_points[2])
	Input.action_release("contract")
	row.higher_catch_time=app.trial.elapsed
	row.end_hands=app.controller._attached_ids().size()
	for id in 2:button(id,false)
	await ticks(.1)
	report.runs.append(row)
	return row

func traverse_trial() -> void:
	await fresh(8)
	check(await grip(0,app.level.transfer_points[0]) and await grip(1,app.level.transfer_points[1]),"Traverse starts from two actual chosen free-surface contacts")
	var start:Vector3=app.torso.position
	Input.action_press("bias_right")
	await ticks(1.2)
	Input.action_release("bias_right")
	var change:Vector3=app.torso.position-start
	check(change.x>.015,"D produces actual supported lateral progress in Traverse")
	report.runs.append({"arena":"Traverse","displacement":str(change),"intent":app.controller.telemetry().get("intent_locomotion",{})})

func run() -> void:
	for policy in [0,1,2]:await step_trial(3,policy,false)
	var off:Dictionary=await step_trial(4,1,false)
	var on:Dictionary=await step_trial(4,1,true)
	check(off.rise>.05 and on.rise>.05,"Step variants request and realize COM rise with unchanged actuators")
	check(on.first_higher_catch,"Step feet-ON candidate reaches player's explicitly chosen higher contact")
	check(on.max_feet_force>1 and on.foot_work_positive>.005,"Step feet actually carry load and do positive physical work")
	check(on.hand_load_integral<off.hand_load_integral or on.rise>off.rise+.01,"real feet improve measured hand demand or attainable progress")
	var mixed_direction:Vector3=on.samples[-1].intent.get("movement_intent_world",Vector3.ZERO)
	check(mixed_direction.dot(Vector3.UP)>.7,"loading horizontal feet never turns wall-up W into an inward-wall command")
	await traverse_trial()
	check(budgets_ok,"all arena trials respect shared caps including ground handoff")
	report.physics_hz=hz
	report.checks=checks
	report.failures=failures
	FileAccess.open("res://builds/intent_arenas_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	app.queue_free()
	await ticks(.03)
	print("INTENT ARENAS RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
