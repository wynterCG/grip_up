extends Node3D
## Short rendered QA through MCP Pro; excluded from the playable export.
func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var app = get_parent()
	app.load_test(0)
	await get_tree().create_timer(0.4).timeout
	var start: Vector3 = app.torso.position
	Input.action_press("extend")
	await get_tree().create_timer(0.65).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/ground_walk.png")
	var report := {"start":str(start),"walking_position":str(app.torso.position),"walking_speed":app.torso.linear_velocity.length(),"grounded":app.ground_motor.grounded,"animation":app.biped.animation_clip,"ik_weight":app.biped.ik.influence,"heading":str(-app.torso.global_basis.z),"hands":[app.controller.get_hand_state(0),app.controller.get_hand_state(1)]}
	Input.action_release("extend")
	await get_tree().create_timer(0.7).timeout
	report.stopped_speed = app.torso.linear_velocity.length()
	report.stopped_animation = app.biped.animation_clip
	FileAccess.open("C:/Users/Wynter/grip_up/builds/ground_walk_capture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	app.load_test(0)
	queue_free()
