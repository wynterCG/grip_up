extends "res://features/grip_up/tests/test_intent_integration.gd"
## An engineering/safety result is separate from the measured M6 acceptance gate.

func run()->void:
	app=Lab.new()
	root.add_child(app)
	current_scene=app
	await ticks(.1)
	check(app.input_profile==2 and not app.controller.intent_auto_mantle_enabled,"startup keeps the approved default and mantle OFF")
	report.variants=[]
	for feet_on in [false,true]:
		await fresh(11,feet_on)
		app.won=false
		app._set_distant_targeting(true)
		check(app.controller.intent_auto_mantle_enabled and app.input_profile==4,"ledge arena explicitly enables the isolated experiment")
		check(await grip(0,app.level.transfer_points[0]),"finite left edge acquisition feet%s"%feet_on)
		check(await grip(1,app.level.transfer_points[1]),"finite right edge acquisition feet%s"%feet_on)
		await ticks(.65)
		check(not app.won and not app.mantle_completed and not app.rating_panel.visible,"edge contact alone cannot claim a top-out")
		var start:Vector3=app.torso.position
		var peak_y:float=start.y
		var top_ground_seen:=false
		var max_feet:=0.0
		Input.action_press("contract")
		for frame in 4*hz:
			await ticks(1.0/hz)
			peak_y=maxf(peak_y,app.torso.position.y)
			top_ground_seen=top_ground_seen or app.ground_motor.grounded and app.ground_motor.support_body==app.level.platform
			max_feet=maxf(max_feet,app.controller.telemetry().leg_force)
		Input.action_release("contract")
		report.variants.append({"physical_feet":feet_on,"start":start,"end":app.torso.position,"peak_y":peak_y,"actual_top_ground_seen":top_ground_seen,"max_foot_force":max_feet,"acceptance_gate_met":app.mantle_completed,"ledge_transfer":app.controller.telemetry().get("ledge_transfer",{})})
		check(not app.mantle_completed or top_ground_seen,"completion requires measured ground on the real platform")
		for id in 2:button(id,false)
		await ticks(.15)
		check(app.controller.telemetry().total_force==0,"release removes both real hand loads")
		check(Vector3(app.controller.telemetry().get("ledge_transfer",{}).get("applied_torque",Vector3.ZERO)).length()<.001,"no mantle torque survives loss of real hands")
	await fresh(10,true)
	check(not app.controller.intent_auto_mantle_enabled,"returning to the approved route disables mantle")
	check(budgets_ok,"experiment respects unchanged360N hands180N feet150Nm combined budget")
	report.physics_hz=hz
	report.checks=checks
	report.failures=failures
	FileAccess.open("res://builds/mantle_integration_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	app.queue_free()
	await ticks(.03)
	print("MANTLE INTEGRATION RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
