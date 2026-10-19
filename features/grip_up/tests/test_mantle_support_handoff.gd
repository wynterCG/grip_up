extends "res://features/grip_up/tests/test_intent_integration.gd"
## Ground/contact arbitration safety. This test does not claim a functional mantle.

func run()->void:
	await fresh(12,true)
	check(not app.controller.physics_mantle_v08_enabled and not app.mantle_v08.legs.active,"new arena alone leaves explicit candidate flags OFF")
	app._open_mantle_v08(12)
	app.won=false
	await ticks(.4)
	check(app.controller.physics_mantle_v08_enabled and app.controller.palm_compression_enabled,"explicit v0.8 button enables real palm model")
	check(not app.controller.intent_auto_mantle_enabled,"legacy M6 motor remains a separate comparison")
	check(app.ground_motor.grounded and app.ground_motor.support_body==app.level.start_pad,"ordinary approach standing has actual native sole support")
	check(not app.mantle_v08.completed and not app.mantle_v08.had_hanging_start,"approach standing never masquerades as a hanging top-out")
	var original_sole:Transform3D=app.mantle_v08.legs.foot_local_transform()
	app.mantle_v08.legs.request_flex(1)
	app.mantle_v08.legs.step(1.0/hz,true,100)
	check(app.mantle_v08.legs.foot_local_transform()==original_sole and app.mantle_v08.legs.reason=="LOAD_TRANSFER_REQUIRED","load-bearing lower geometry is retained until support transfers")
	Input.action_press("bias_right")
	app.level.start_pad.position.y-=.012
	# physics_frame is emitted before that frame's node callbacks.
	await ticks(2.0/hz)
	check(not app.ground_motor.grounded and app.ground_motor.applied_force.length()<.0001,"nearby floor ray cannot authorize an airborne ground motor")
	Input.action_release("bias_right")
	await ticks(.15)
	check(not app.mantle_v08.completed,"no false completion after losing approach support")
	check(app.mantle_v08.ground_distance==0,"no movement on approach floor counts as top-ground walking")
	app.get_window().focus_exited.emit()
	await ticks(.05)
	check(app.controller._attached_ids().is_empty() and app.controller.telemetry().total_force==0,"focus loss leaves no hand or palm load")
	await fresh(10,true)
	check(not app.controller.physics_mantle_v08_enabled and not app.controller.palm_compression_enabled,"returning to approved route disables new contact model")
	check(not app.torso.has_meta("adaptive_legs"),"approved route keeps its original physical lower body")
	check(budgets_ok,"candidate and return path preserve shared physical budgets")
	report={"physics_hz":hz,"checks":checks,"failures":failures,"provenance":"Contact/arbitration contracts, not M4 functional success"}
	FileAccess.open("res://builds/mantle_support_handoff_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	app.queue_free()
	await ticks(.03)
	print("MANTLE SUPPORT HANDOFF RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
