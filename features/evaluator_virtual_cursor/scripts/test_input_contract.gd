extends SceneTree
const Frame=preload("res://features/grip_up/scripts/grip_input_frame.gd")
const Provider=preload("res://features/evaluator_virtual_cursor/scripts/replay_input_provider.gd")
const Driver=preload("res://features/evaluator_virtual_cursor/scripts/virtual_cursor_driver.gd")
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func sample()->Dictionary:
	return {"schema_version":Frame.SCHEMA,"session_id":"unit","tape_sha256":"unit-hash","tick_index":1,"physics_hz":120,"source_kind":"VIRTUAL_REPLAY","viewport_id":"GAME_ROOT","viewport_size_px":[1920.0,1080.0],"aim_valid":false,"aim_position_viewport_px":[0.0,0.0],"pointer_motion_valid":false,"camera_orbit_delta":[0.0,0.0],"camera_zoom_steps":[],"strengths":{"contract":0.0,"extend":0.0,"bias_left":0.0,"bias_right":0.0,"grip_left":0.0,"grip_right":0.0},"button_edges":[],"action_edges":[],"focus_policy_state":"ACTIVE","input_source_sequence":1}
func _initialize()->void:
	var value:Dictionary=sample()
	check(Frame.validate(value)=="","invalid aim is explicit, not rejected")
	value.aim_valid=true;check(Frame.validate(value)=="","explicit top-left zero valid")
	var immutable=Frame.new(value);value.aim_position_viewport_px[0]=90
	check(immutable.data().aim_position_viewport_px==[0.0,0.0],"constructor detached")
	var detached:Dictionary=immutable.data();detached.strengths.grip_left=1.0
	check(not immutable.held("grip_left"),"consumer copy cannot change held")
	value=sample();value.erase("aim_valid");check(Frame.validate(value).begins_with("MISSING_FIELD"),"missing aim distinct zero")
	check(Frame.validate({"schema":"grip_up_replay_v132"})=="LEGACY_POINTER_AMBIGUOUS","legacy pointer ambiguity")
	value=sample();check(Frame.validate(value,value)=="DUPLICATE_TICK","duplicate tick")
	var next:Dictionary=value.duplicate(true);next.tick_index=3;next.input_source_sequence=3
	check(Frame.validate(next,value)=="MISSING_TICK","missing tick")
	next.tick_index=2;next.input_source_sequence=2;next.source_kind="LIVE"
	check(Frame.validate(next,value)=="INPUT_SOURCE_MISMATCH","source switch")
	value=sample();value.aim_valid=true;value.aim_position_viewport_px=[1920.0,0.0]
	check(Frame.validate(value).contains("BOUNDS"),"no implicit bounds clamp")
	value=sample();value.aim_position_viewport_px=[NAN,1.0]
	check(Frame.validate(value).begins_with("INPUT_NONFINITE"),"NaN")
	value=sample();value.strengths.grip_left=1.0
	check(Frame.validate(value)=="INPUT_BUTTON_HELD_EDGE_MISMATCH","held without edge")
	value.button_edges=[{"hand":0,"pressed":true}]
	check(Frame.validate(value)=="","press edge")
	check(Frame.validate(JSON.parse_string(JSON.stringify(value)))=="","real JSON roundtrip preserves integer-valued hand ID")
	var fractional:Dictionary=value.duplicate(true);fractional.button_edges[0].hand=.5
	check(Frame.validate(fractional)=="INPUT_BUTTON_EDGE","fractional hand rejected without rounding")
	var wheel:Dictionary=sample();wheel.camera_zoom_steps=[1,-1]
	check(Frame.validate(JSON.parse_string(JSON.stringify(wheel)))=="","JSON signed wheel roundtrip")
	value.button_edges.append({"hand":0,"pressed":true})
	check(Frame.validate(value)=="INPUT_BUTTON_EDGE_ORDER","double press")
	value=sample();value.button_edges=[{"hand":0,"pressed":true},{"hand":0,"pressed":false}]
	check(Frame.validate(value)=="","ordered press-release same tick")
	value=sample();value.strengths.contract=1.0;value.strengths.bias_right=1.0
	var frame=Frame.new(value)
	check(frame.ground_axis().y<0 and frame.traversal_axis().y>0,"ground/traversal signs preserved")
	value=sample();value.camera_zoom_steps=[1,-1,1];check(Frame.validate(value)=="","ordered zoom")
	value.action_edges=["reset"];check(Frame.validate(value).begins_with("UNSUPPORTED_REPLAY_CASE"),"unsafe tape action rejected")
	var provider=Provider.new();provider.finish();provider.finish();check(provider.state=="DISABLED","idempotent disabled cleanup")
	provider.reject_event(InputEventMouseMotion.new());check(provider.rejected_count==1,"bounded rejection count")
	for index in 100:provider.reject_event(InputEventKey.new())
	check(provider.rejected.size()==64 and provider.rejected_count==101,"bounded diagnostics")
	print("V132A CONTRACT: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
