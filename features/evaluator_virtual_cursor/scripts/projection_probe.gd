extends RefCounted
## Test-only observations. No body, camera, input, query or contact mutation.
const SCHEMA="grip_projection_pick_v132b"
const UNAVAILABLE="UNAVAILABLE_PUBLIC_API"
var manifest:Dictionary={}
var requested:Dictionary={}
var actual_delta:=0.0
var records:Array[Dictionary]=[]
var active:=false
var current:Dictionary={}
var error:=""
var cost_usec:=0
var started:=0

static func encode(value:Variant)->Variant:
	match typeof(value):
		TYPE_VECTOR2,TYPE_VECTOR2I:return [value.x,value.y]
		TYPE_VECTOR3:return [value.x,value.y,value.z]
		TYPE_VECTOR4:return [value.x,value.y,value.z,value.w]
		TYPE_TRANSFORM2D:return [encode(value.x),encode(value.y),encode(value.origin)]
		TYPE_TRANSFORM3D:return [encode(value.basis.x),encode(value.basis.y),encode(value.basis.z),encode(value.origin)]
		TYPE_PROJECTION:return [encode(value.x),encode(value.y),encode(value.z),encode(value.w)]
		TYPE_RECT2:return {"position":encode(value.position),"size":encode(value.size)}
		TYPE_ARRAY:
			var a:Array=[]
			for item in value:a.append(encode(item))
			return a
		TYPE_DICTIONARY:
			var d:Dictionary={}
			for key in value:d[key]=encode(value[key])
			return d
	return value

static func number_bits(value:Variant,path:String="",result:Dictionary={})->Dictionary:
	if value is float:
		var b:=PackedByteArray();b.resize(8);b.encode_double(0,value);result[path]=b.hex_encode()
	elif value is Array:
		for i in value.size():number_bits(value[i],path+"/"+str(i),result)
	elif value is Dictionary:
		for k in value:number_bits(value[k],path+"/"+str(k),result)
	return result

static func finite(value:Variant)->bool:
	if value is float:return is_finite(value)
	if value is Array:
		for v in value:
			if not finite(v):return false
	if value is Dictionary:
		for v in value.values():
			if not finite(v):return false
	return true

static func environment(app:Node)->Dictionary:
	var vp:Viewport=app.get_viewport();var w:Window=app.get_window();var camera:Camera3D=app.camera
	return encode({"window":{"size":w.size,"mode":w.mode,"position":w.position,"screen":w.current_screen,"content_scale_size":w.content_scale_size,"content_scale_mode":w.content_scale_mode,"content_scale_aspect":w.content_scale_aspect,"content_scale_factor":w.content_scale_factor,"content_scale_stretch":w.content_scale_stretch,"display_server":DisplayServer.get_name(),"dpi":DisplayServer.screen_get_dpi(w.current_screen) if DisplayServer.get_name()!="headless" else UNAVAILABLE,"os_scale":DisplayServer.screen_get_scale(w.current_screen) if DisplayServer.get_name()!="headless" else UNAVAILABLE},"viewport":{"runtime_id":vp.get_instance_id(),"class":vp.get_class(),"path":str(vp.get_path()),"visible_rect":vp.get_visible_rect(),"size_public":vp.call("get_size") if vp.has_method("get_size") else UNAVAILABLE,"final":vp.get_final_transform(),"stretch":vp.get_stretch_transform(),"canvas":vp.get_canvas_transform(),"global_canvas":vp.global_canvas_transform,"camera_rect_size":UNAVAILABLE,"camera_coords":UNAVAILABLE,"active_camera_runtime_id":vp.get_camera_3d().get_instance_id() if vp.get_camera_3d()!=null else 0},"camera":camera_values(camera)})

static func camera_values(camera:Camera3D)->Dictionary:
	return {"runtime_id":camera.get_instance_id(),"global_transform":camera.global_transform,"effective_transform":camera.get_camera_transform(),"projection_matrix":camera.get_camera_projection(),"projection_type":camera.projection,"fov":camera.fov,"near":camera.near,"far":camera.far,"keep_aspect":camera.keep_aspect,"h_offset":camera.h_offset,"v_offset":camera.v_offset,"frustum_offset":camera.frustum_offset,"current":camera.current,"v0_focus":camera.focus,"v0_yaw":camera.yaw,"v0_elevation":camera.elevation,"v0_distance":camera.distance,"v0_source_pose":camera.virtual_source_pose,"obstruction_query_result":"NOT_STORED_BY_CAMERA"}

func begin_pick(app:Node,hand:int)->void:
	started=Time.get_ticks_usec();active=true
	var frame:Dictionary=app.input_frame.data()
	var size:Array=manifest.projection_config.window_size
	if app.get_window().size!=Vector2i(int(size[0]),int(size[1])) or app.get_viewport().get_visible_rect().size!=Vector2(float(frame.viewport_size_px[0]),float(frame.viewport_size_px[1])):error="INVALID_TRACE:REQUESTED_WINDOW_OR_LOGICAL_SIZE"
	if not is_equal_approx(actual_delta,1.0/Engine.physics_ticks_per_second):error="INVALID_TRACE:ACTUAL_DELTA"
	current={"schema":SCHEMA,"trial_id":manifest.run_id,"git_commit":manifest.code_commit,"engine_full_version":Engine.get_version_info(),"renderer":{"method":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name()},"run_mode":manifest.engine_mode,"scenario_id":manifest.scenario_ids[0],"tape_sha256":manifest.virtual_tape_sha256,"tick":int(frame.tick_index),"physics_hz":Engine.physics_ticks_per_second,"physics_delta":actual_delta,"input_stage":"PRE_PICK_AFTER_V0_CAMERA_EVALUATION","is_in_physics_frame":Engine.is_in_physics_frame(),"pick_call_index":records.size(),"hand":hand,"provider_state":app.replay_input_provider.state,"focus_active":app.get_window().has_focus(),"paused":app.get_tree().paused,"requested":requested.duplicate(true),"effective":frame,"cursor":{"raw_tape":frame.aim_position_viewport_px,"space":"viewport_logical","actual_vector":app.pointer,"conversion":"Vector2 from unchanged tape components, no recenter/round"},"environment":environment(app),"rays":[],"precision":{"vector_component_16777217":Vector3(16777217.0,0,0).x,"encoding":"JSON.stringify full_precision=true plus little-endian IEEE754 binary64 promoted scalar bits"},"hand_state_before":app.controller.get_hand_state(hand)}

func observe_ray(camera:Camera3D,point:Vector2,offset:Vector2,origin:Vector3,direction:Vector3,query:PhysicsRayQueryParameters3D,hit:Dictionary)->void:
	if not active:return
	# Actual origin/direction/query/hit are passed from production, never re-queried.
	var before:Transform3D=camera.global_transform
	var local:Vector3=camera.project_local_ray_normal(point)
	var adjacent:Vector3=camera.project_ray_normal(point)
	var transform:Transform3D=camera.get_camera_transform()
	var row:Dictionary={"query_index":current.rays.size(),"offset":offset,"screen_point":point,"origin":origin,"world_normal_used":direction,"local_normal_adjacent":local,"world_normal_adjacent":adjacent,"effective_transform_adjacent":transform,"query_from":query.from,"query_to":query.to,"distance_m":70.0,"mask":query.collision_mask,"exclusions":["torso"],"excluded_rid_count":query.exclude.size(),"ordering":["production_origin","production_world_normal","create_query","single_intersect_ray","adjacent_local","adjacent_world","adjacent_effective_transform"],"camera_unchanged":before==camera.global_transform,"reason":"MISS" if hit.is_empty() else "INELIGIBLE" if not hit.collider.get_meta("grippable",false) else "SELECTED"}
	if not hit.is_empty():
		var collider:Node3D=hit.collider
		row["hit"]={"collider_key":str(collider.get_meta("mastery_surface",collider.name)),"runtime_id":collider.get_instance_id(),"shape":hit.get("shape"),"world_point":hit.position,"world_normal":hit.normal,"material_point":collider.to_local(hit.position),"material_normal":collider.global_basis.inverse()*Vector3(hit.normal),"collider_transform":collider.global_transform,"surface_material_id":str(collider.get_meta("mastery_surface",collider.name))}
	if not row.camera_unchanged or adjacent!=direction:error="INVALID_TRACE:CAMERA_OR_ADJACENT_WORLD_CHANGED"
	current.rays.append(row)

func end_pick(app:Node,hand:int,hit:Dictionary)->void:
	if not active:return
	current["selected"]=not hit.is_empty()
	current["hand_state_after_selection_before_request"]=app.controller.get_hand_state(hand)
	current["environment_after"]=environment(app)
	var encoded:Dictionary=encode(current)
	if not Engine.is_in_physics_frame() or app.get_viewport().get_camera_3d()!=app.camera or encoded.environment!=encoded.environment_after or not finite(encoded):error="INVALID_TRACE:PHASE_OWNER_FINITE_OR_MOVEMENT"
	encoded["numeric_bits"]=number_bits(encoded,"",{})
	records.append(encoded);active=false;current={};cost_usec+=Time.get_ticks_usec()-started

func write(path:String)->Dictionary:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return {"error":"PROJECTION_WRITE_FAILED"}
	for row in records:file.store_line(JSON.stringify(row,"",true,true))
	file.close()
	return {"schema":SCHEMA,"records":records.size(),"error":error,"probe_usec":cost_usec,"path":path,"sha256":FileAccess.get_sha256(path)}
