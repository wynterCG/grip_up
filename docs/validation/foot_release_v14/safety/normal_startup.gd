extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	var app=load("res://features/grip_up/scenes/grip_up_lab.tscn").instantiate()
	root.add_child(app);current_scene=app
	for frame in 5:await physics_frame
	var bindings={}
	for action in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:bindings[action]=InputMap.action_get_events(action).map(func(event):return event.as_text())
	var value={"profile":app.input_profile,"allocation":app.movement_allocation,"physics_hz":Engine.physics_ticks_per_second,"hold":app.hold_mode,"physical_feet":app.physical_feet_enabled,"intent_aware_feet":app.intent_aware_feet_enabled,"observer":app.locomotion_diagnostics_enabled,"capture_recorder":app.capture_trace.enabled,"mass":app.torso.mass,"reach":app.controller.get_max_reach(),"values":[app.controller.tuning.traversal_speed_m_s,app.controller.tuning.traversal_input_ramp_s,app.controller.tuning.traversal_target_max_rate,app.controller.tuning.traversal_target_max_acceleration],"bindings":bindings}
	var safety={"provider_disabled":app.replay_input_provider==null,"arming":app.virtual_input_arming,"camera_virtual":app.camera.virtual_physics_follow,"source_kind":app.input_frame.data().source_kind}
	var file=FileAccess.open("C:/Users/Wynter/grip_up/builds/foot_release_v14_r1/safety/normal_runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify({"normal":value,"safety":safety}));file.close()
	quit(0 if safety.provider_disabled and not safety.arming and not safety.camera_virtual and safety.source_kind=="LIVE" else 1)
