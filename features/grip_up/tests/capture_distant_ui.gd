extends Node
## Final UI evidence; leaves a fresh v0.6 reference route ready for human play.
func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var app=get_parent()
	Engine.physics_ticks_per_second=120
	app._set_distant_targeting(false)
	app._open_transfer_lab(4)
	app.settings.show()
	await get_tree().process_frame
	var scroll:ScrollContainer=app.settings.find_children("*","ScrollContainer",true,false)[0]
	for toggle in app.settings.find_children("*","CheckButton",true,false):
		if toggle.text.begins_with("v0.6 select distant"):
			scroll.ensure_control_visible(toggle)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/v06_controls_final.png")
	var data:={"window":str(get_window().size),"viewport":str(get_viewport().get_visible_rect().size),"hud":str(app.hud.size),"hud_matches_viewport":app.hud.size.is_equal_approx(get_viewport().get_visible_rect().size),"distant_flag_off":not app.allow_out_of_reach_grip_targets,"other_new_flags_off":not app.transfer_assist_enabled and not app.reach_prediction_enabled and not app.catch_buffer_enabled,"posture_variant":app.posture_variant,"physics_hz":Engine.physics_ticks_per_second}
	FileAccess.open("C:/Users/Wynter/grip_up/builds/v06_ui_final.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	app.settings.hide()
	app._open_distant_lab(4)
	app.debug_visible=false
	app.hint_time=0
	queue_free()
