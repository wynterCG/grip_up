extends Node
## MCP-only view inspection, excluded from game builds.
func _ready() -> void:
	var app = get_parent()
	Engine.physics_ticks_per_second = 120
	app.load_test(0)
	app._set_predictive_grip(true)
	app.settings.show()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/m1_controls.png")
	app.settings.hide()
	app.debug_visible = true
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/m1_debug.png")
	app.debug_visible = false
	queue_free()
