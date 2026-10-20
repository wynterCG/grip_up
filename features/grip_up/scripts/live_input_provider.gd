extends RefCounted
const Frame=preload("res://features/grip_up/scripts/grip_input_frame.gd")
var tick:=0
func snapshot(app:Node):
	tick+=1
	var strengths:Dictionary={}
	for action in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:strengths[action]=Input.get_action_strength(action)
	var axis:Vector2=Input.get_vector("bias_left","bias_right","contract","extend")
	var size:Vector2=app.get_viewport().get_visible_rect().size
	return Frame.new({"schema_version":Frame.SCHEMA,"session_id":"LIVE","tape_sha256":"","tick_index":tick,"physics_hz":Engine.physics_ticks_per_second,"source_kind":"LIVE","viewport_id":str(app.get_viewport().get_instance_id()),"viewport_size_px":[size.x,size.y],"aim_valid":true,"aim_position_viewport_px":[app.pointer.x,app.pointer.y],"pointer_motion_valid":false,"camera_orbit_delta":[0.0,0.0],"camera_zoom_steps":[],"strengths":strengths,"ground_axis_live":[axis.x,axis.y],"button_edges":[],"action_edges":[],"focus_policy_state":"ACTIVE" if app.get_window().has_focus() else "EXTERNALLY_UNFOCUSED","input_source_sequence":tick})
