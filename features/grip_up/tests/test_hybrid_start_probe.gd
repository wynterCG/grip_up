extends "res://features/grip_up/tests/test_hybrid_mantle.gd"
## Diagnostic replay only. Functional failures remain failures in the receipt.
func run()->void:
	var row:Dictionary=await ascent(0)
	row.motor_audit=app.hybrid_mantle.motor.diagnostics()
	FileAccess.open("res://builds/hybrid_start_probe_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify({"physics_hz":hz,"checks":checks,"failures":failures,"trial":row},"\t"))
	app.queue_free()
	await ticks(.03)
	print("HYBRID START PROBE RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
