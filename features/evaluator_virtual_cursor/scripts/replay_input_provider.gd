extends RefCounted
## Test-only owner: no world, ray, grip, camera or body mutation authority.
const Frame=preload("res://features/grip_up/scripts/grip_input_frame.gd")
var state:="DISABLED"
var reason:=""
var frame
var initial:Dictionary={}
var previous:Dictionary={}
var rejected:Array[Dictionary]=[]
var rejected_count:=0
var external_focus:="ACTIVE"
var lifecycle:Array[String]=["DISABLED"]
var last_engine_tick:=-1
var environment:Dictionary={}

func _environment(app:Node)->Dictionary:
	var vp:Viewport=app.get_viewport()
	var bindings:Dictionary={}
	for action in app.router.DEFAULTS:bindings[action]=InputMap.action_get_events(action).map(func(event):return event.as_text())
	return {"world_id":app.world.get_instance_id(),"torso_id":app.torso.get_instance_id(),"controller_id":app.controller.get_instance_id(),"size":vp.get_visible_rect().size,"canvas":vp.get_canvas_transform(),"final":vp.get_final_transform(),"window_size":app.get_window().size,"window_mode":app.get_window().mode,"camera_id":app.camera.get_instance_id(),"fov":app.camera.fov,"near":app.camera.near,"far":app.camera.far,"projection":app.camera.projection,"bindings":bindings}

func _state(value:String)->void:state=value;lifecycle.append(value)
func owns_input()->bool:return state in ["ARMING","ACTIVE","INVALID","FINISHING"]
func arm(app:Node,session:Dictionary)->String:
	if state!="DISABLED":return "PROVIDER_ALREADY_OWNED"
	_state("ARMING");initial=session.duplicate(true)
	if not OS.is_debug_build() or not OS.get_cmdline_user_args().has("--virtual-cursor-evaluator"):return invalidate("TEST_FLAG_REQUIRED")
	if app.input_profile!=4 or is_instance_valid(app.hybrid_mantle) or is_instance_valid(app.mantle_v08):return invalidate("UNSUPPORTED_REPLAY_CASE:INPUT_ISOLATION_INCOMPLETE")
	if app.movement_allocation!=0 or not app.physical_feet_enabled or not app.hold_mode:return invalidate("UNSUPPORTED_REPLAY_CASE:BASELINE")
	previous.clear();frame=null;reason="";last_engine_tick=-1;environment=_environment(app);_state("ACTIVE");return ""
func invalidate(value:String)->String:
	if reason.is_empty():reason=value
	_state("INVALID");return reason
func commit(value:Dictionary,app:Node)->String:
	if state!="ACTIVE":return invalidate("INPUT_SOURCE_MISMATCH:NOT_ACTIVE")
	var engine_tick:int=Engine.get_physics_frames()
	if engine_tick==last_engine_tick:return invalidate("DUPLICATE_TICK")
	if last_engine_tick>=0 and engine_tick!=last_engine_tick+1:return invalidate("MISSING_TICK")
	var checked:String=Frame.validate(value,previous)
	if not checked.is_empty():return invalidate(checked)
	if value.source_kind!="VIRTUAL_REPLAY":return invalidate("INPUT_SOURCE_MISMATCH")
	if value.focus_policy_state=="RUNTIME_PAUSED" or app.get_tree().paused:return invalidate("RUNTIME_SUSPENDED")
	if previous.is_empty() and int(value.tick_index)!=1:return invalidate("MISSING_TICK")
	var size:Vector2=app.get_viewport().get_visible_rect().size
	if value.viewport_size_px!=[size.x,size.y] or value.viewport_id!="GAME_ROOT":return invalidate("ENVIRONMENT_NOT_COMPARABLE:VIEWPORT")
	if int(value.physics_hz)!=Engine.physics_ticks_per_second:return invalidate("ENVIRONMENT_NOT_COMPARABLE:HZ")
	if not app.camera.current or app.get_viewport().get_camera_3d()!=app.camera:return invalidate("CURSOR_OR_CAMERA_MISMATCH:OWNER")
	if app.input_profile!=4 or app.settings.visible or app.rating_panel.visible or app.binding_action!="" or is_instance_valid(app.hybrid_mantle) or is_instance_valid(app.mantle_v08):return invalidate("EXTERNAL_UI_INTERFERENCE")
	if _environment(app)!=environment:return invalidate("ENVIRONMENT_NOT_COMPARABLE:VIEWPORT_CAMERA_BINDINGS")
	previous=value.duplicate(true);frame=Frame.new(value);last_engine_tick=engine_tick;return ""
func reject_event(event:InputEvent)->void:
	rejected_count+=1
	if rejected.size()<64:rejected.append({"tick":previous.get("tick_index",0),"kind":event.get_class(),"reason":"EXTERNAL_INPUT_REJECTED"})
func focus_changed(focused:bool)->void:external_focus="ACTIVE" if focused else "EXTERNALLY_UNFOCUSED"
func finish()->void:
	if state=="DISABLED":return
	_state("FINISHING");frame=null;previous.clear();_state("DISABLED")
