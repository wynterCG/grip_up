extends "res://features/grip_up/tests/test_hybrid_resilience.gd"
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
