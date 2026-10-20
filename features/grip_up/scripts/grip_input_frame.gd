extends RefCounted
## Immutable-by-interface input value. Consumers receive detached copies only.
const SCHEMA="grip_input_frame_v1"
var _value:Dictionary

func _init(value:Dictionary={}) -> void:
	_value=value.duplicate(true)
	_value.make_read_only()

func data() -> Dictionary:return _value.duplicate(true)
func held(action:String) -> bool:return float(_value.get("strengths",{}).get(action,0.0))>0.0
func strength(action:String) -> float:return float(_value.get("strengths",{}).get(action,0.0))
func ground_axis() -> Vector2:
	if _value.get("source_kind","")=="LIVE" and _value.has("ground_axis_live"):
		return Vector2(_value.ground_axis_live[0],_value.ground_axis_live[1])
	return Vector2(strength("bias_right")-strength("bias_left"),strength("extend")-strength("contract")).limit_length(1.0)
func traversal_axis() -> Vector2:
	return Vector2(strength("bias_right")-strength("bias_left"),strength("contract")-strength("extend")).limit_length(1.0)

static func validate(value:Dictionary,previous:Dictionary={}) -> String:
	if value.get("schema_version","")!=SCHEMA:return "LEGACY_POINTER_AMBIGUOUS"
	for key in ["session_id","tape_sha256","tick_index","physics_hz","source_kind","viewport_id","viewport_size_px","aim_valid","aim_position_viewport_px","pointer_motion_valid","camera_orbit_delta","camera_zoom_steps","strengths","button_edges","action_edges","focus_policy_state","input_source_sequence"]:
		if not value.has(key):return "MISSING_FIELD:"+key
	if value.source_kind not in ["LIVE","VIRTUAL_REPLAY"]:return "INPUT_SOURCE_MISMATCH"
	if int(value.physics_hz) not in [60,120]:return "ENVIRONMENT_NOT_COMPARABLE:HZ"
	if not value.aim_valid is bool or not value.pointer_motion_valid is bool:return "INPUT_SCHEMA_BOOLEAN"
	for key in ["viewport_size_px","aim_position_viewport_px","camera_orbit_delta"]:
		if not value[key] is Array or value[key].size()!=2:return "INPUT_SCHEMA_VECTOR:"+key
		for component in value[key]:
			if not (component is float or component is int) or not is_finite(float(component)):return "INPUT_NONFINITE:"+key
	var size:=Vector2(float(value.viewport_size_px[0]),float(value.viewport_size_px[1]))
	var aim:=Vector2(float(value.aim_position_viewport_px[0]),float(value.aim_position_viewport_px[1]))
	if size.x<=0 or size.y<=0:return "ENVIRONMENT_NOT_COMPARABLE:VIEWPORT"
	if value.aim_valid and (aim.x<0 or aim.y<0 or aim.x>=size.x or aim.y>=size.y):return "CURSOR_OR_CAMERA_MISMATCH:BOUNDS"
	if not value.strengths is Dictionary or not value.button_edges is Array or not value.action_edges is Array or not value.camera_zoom_steps is Array:return "INPUT_SCHEMA_COLLECTION"
	for action in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:
		if not value.strengths.has(action) or not is_finite(float(value.strengths[action])) or float(value.strengths[action])<0 or float(value.strengths[action])>1:return "INPUT_STRENGTH:"+action
	for step in value.camera_zoom_steps:
		if not (step is float or step is int) or float(step)!=float(int(step)) or int(step) not in [-1,1]:return "INPUT_ZOOM_STEP"
	if not value.action_edges.is_empty():return "UNSUPPORTED_REPLAY_CASE:ACTION_EDGES"
	if value.focus_policy_state not in ["ACTIVE","EXTERNALLY_UNFOCUSED","RUNTIME_PAUSED"]:return "INPUT_FOCUS_POLICY"
	var last:Dictionary=previous.get("strengths",{"grip_left":0.0,"grip_right":0.0}).duplicate(true)
	for edge in value.button_edges:
		if not edge is Dictionary or not edge.get("pressed") is bool:return "INPUT_BUTTON_EDGE"
		var hand:Variant=edge.get("hand")
		if not (hand is float or hand is int) or not is_finite(float(hand)) or float(hand)!=float(int(hand)) or int(hand) not in [0,1]:return "INPUT_BUTTON_EDGE"
		var action:String="grip_left" if int(edge.hand)==0 else "grip_right"
		if bool(float(last[action])>0)==edge.pressed:return "INPUT_BUTTON_EDGE_ORDER"
		last[action]=1.0 if edge.pressed else 0.0
	for action in ["grip_left","grip_right"]:
		if bool(float(last[action])>0)!=bool(float(value.strengths[action])>0):return "INPUT_BUTTON_HELD_EDGE_MISMATCH"
	if not previous.is_empty():
		var difference:int=int(value.tick_index)-int(previous.tick_index)
		if difference==0:return "DUPLICATE_TICK"
		if difference!=1:return "MISSING_TICK"
		if value.session_id!=previous.session_id or value.tape_sha256!=previous.tape_sha256 or value.source_kind!=previous.source_kind:return "INPUT_SOURCE_MISMATCH"
		if int(value.input_source_sequence)!=int(previous.input_source_sequence)+1:return "INPUT_SEQUENCE_MISMATCH"
	return ""
