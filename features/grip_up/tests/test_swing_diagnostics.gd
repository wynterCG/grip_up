extends "res://features/grip_up/tests/test_posture_study.gd"
## Separate runner keeps M3's long holds within the project20k-frame watchdog.
func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	report.physics_hz = hz
	report.scope = "M3_read_only_incremental_swing_power"
	for variant in [0,1,2]:
		var coast: Dictionary = await trial(variant,"neutral")
		var pump: Dictionary = await trial(variant,"pump")
		var brake: Dictionary = await trial(variant,"brake")
		check(coast.swing_phases.NEUTRAL==6*hz and absf(coast.swing_work)<.000001,"P%d coast contains zero incremental swing work" % variant)
		check(pump.swing_phases.PUMPING>0 and pump.swing_work>0,"P%d phase pump supplies positive measured incremental swing work" % variant)
		check(brake.swing_phases.BRAKING>0 and brake.swing_work<0,"P%d phase brake removes measured incremental swing energy" % variant)
		for dual in [false,true]:
			await constant_held(variant,dual)
	check(budgets and finite_reach,"all swing diagnostic trials retain finite gestures and360N20Nm150Nm")
	FileAccess.open("res://builds/swing_diagnostics_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SWING DIAGNOSTICS RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
