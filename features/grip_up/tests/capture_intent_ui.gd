extends Node
var evidence_prefix:="v07"
func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var app=get_parent()
	Engine.physics_ticks_per_second=120
	app._open_intent_arena(6,true)
	if evidence_prefix in ["v071","v072"]:app._set_distant_targeting(true)
	app.debug_visible=false
	app.settings.show()
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll:ScrollContainer=app.settings.find_children("*","ScrollContainer",true,false)[0]
	scroll.scroll_vertical=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/%s_controls_final.png" % evidence_prefix)
	var data:={"profile":app.input_profile,"intent_climb_enabled":app.intent_climb_enabled,"physical_feet":app.physical_feet_enabled,"posture_variant":app.posture_variant,"posture_policy":app.posture_policy,"launch":app.experimental_launch_enabled,"distant_targets":app.allow_out_of_reach_grip_targets,"hud_matches_viewport":app.hud.size.is_equal_approx(get_viewport().get_visible_rect().size),"physics_hz":Engine.physics_ticks_per_second,"provenance":"Deliberately prepared human candidate, not application startup defaults"}
	FileAccess.open("C:/Users/Wynter/grip_up/builds/%s_ui_final.json" % evidence_prefix,FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	app.settings.hide()
	app.hint_time=0
	queue_free()
