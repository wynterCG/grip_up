extends "res://features/grip_up/tests/test_hybrid_sequence.gd"
const VaultLab=preload("res://features/grip_up/tests/vault_test_lab.gd")

func fresh(index:int,feet:bool=false)->void:
	for action in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:
		if InputMap.has_action(action):Input.action_release(action)
	if is_instance_valid(app):app.queue_free();await ticks(.03)
	app=VaultLab.new()
	root.add_child(app)
	current_scene=app
	app._open_intent_arena(index,feet)
	app.won=true
	await ticks(.45)

func run()->void:
	trials.append(await ascent(0))
	trials.append(await ascent(1))
	check(app.contextual_vault_v10_enabled and app.hybrid_mantle.animation_driver.contextual_vault_v10_enabled,"explicit experiment propagates to presentation")
	check(absf(app.hybrid_mantle.route.duration-1.15)<.00001,"v1.0 retains certified route duration")
	await varied(-1)
	await varied(1)
	await two_ledges()
	check(budgets_ok,"v1.0 preserves dynamic actuator budgets")
	FileAccess.open("res://builds/vault_v10_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"physics_hz":hz,"trials":trials,"runs":sequence_rows,"human_feel":"PENDING","provenance":"Automated ordinary-input v1.0 opt-in, not human evaluation"},"\t"))
	app.queue_free()
	await ticks(.03)
	print("VAULT V10 RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
