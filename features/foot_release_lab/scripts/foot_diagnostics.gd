extends Node
## Opt-in F0 observer. Reads applied forces and real input; never drives physics.
const Solver=preload("res://features/grip_up/scripts/foot_contact_solver.gd")
const Sampler=preload("res://features/grip_up/scripts/foothold_candidate_sampler.gd")
var app:Node
var output_dir:=""
var condition:="B1"
var stage:="manual"
var recording:=false
var tick:=0
var elapsed:=0.0
var rows:=0
var _trace:FileAccess
var _render_trace:FileAccess
var _panel:PanelContainer
var _text:Label
var _sections:Dictionary={"actuator":true,"native":true,"IK":true,"opposition":true}
var _latest:Dictionary={}
var _biped:Node
var _render_sample:Dictionary={}
var _render_sole_offsets:Array[Vector3]=[]
var _markers:Dictionary={}
var _marker_root:Node3D
var _ik_callback:Callable
var _ui_clock:=0.0

static func json_value(value:Variant)->Variant:
	if value is Vector3:return [value.x,value.y,value.z]
	if value is Vector2:return [value.x,value.y]
	if value is Transform3D:return {"origin":json_value(value.origin),"basis":[json_value(value.basis.x),json_value(value.basis.y),json_value(value.basis.z)]}
	if value is Dictionary:
		var result:Dictionary={}
		for key in value:result[str(key)]=json_value(value[key])
		return result
	if value is Array:
		var result:Array=[]
		for entry in value:result.append(json_value(entry))
		return result
	return value

static func save_json(path:String,value:Dictionary)->void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	assert(file!=null,"Diagnostic output must be writable")
	file.store_string(JSON.stringify(json_value(value),"\t",true,true))

func _ready()->void:
	process_physics_priority=100
	if output_dir.is_empty():output_dir="res://builds/foot_release_v14_r1/manual_%d_%d"%[OS.get_process_id(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(output_dir)
	_build_hud()
	_build_markers()

func setup_receipt()->Dictionary:
	var c=app.controller
	return {"condition":condition,"physics_hz":Engine.physics_ticks_per_second,"profile":app.input_profile,"level":app.level_id,"title":app.level.title,
		"physical_feet":app.physical_feet_enabled,"allocation":app.movement_allocation,"B2":app.intent_aware_feet_enabled,
		"hands":"hold" if app.hold_mode else "toggle","hybrid":app.hybrid_mantle_v09_enabled,"vault":app.contextual_vault_v10_enabled,
		"mass_kg":app.torso.mass,"reach_m":c.get_max_reach(),"arm_values":[c.tuning.traversal_speed_m_s,c.tuning.traversal_input_ramp_s,c.tuning.traversal_target_max_rate,c.tuning.traversal_target_max_acceleration],
		"foot_values":{ "total_N":c.feet_solver.tuning.total_force_budget,"per_foot_N":c.feet_solver.tuning.max_force_per_foot,"spring":c.feet_solver.tuning.stiffness,"damping":c.feet_solver.tuning.damping,"preload":c.feet_solver.tuning.contact_preload,"load_in_s":c.feet_solver.tuning.engagement_time,"plant_m_s":c.feet_solver.tuning.plant_speed,"friction":c.feet_solver.tuning.foot_friction},
		"camera":app.camera.global_transform,"input_source":"LIVE_REAL_ACTIONS_OR_DELIVERED_MOUSE_EVENTS_NO_SYNTHETIC_FOOT_ANCHORS","rendered":DisplayServer.get_name()!="headless","schema":"foot_diagnosis_v14_F0"}

func start_recording()->void:
	assert(not recording,"Finish prior recording before starting another")
	if FileAccess.file_exists(output_dir.path_join("physics.jsonl")):
		output_dir=output_dir.get_base_dir().path_join(output_dir.get_file()+"_take_%d"%Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(output_dir)
	_trace=FileAccess.open(output_dir.path_join("physics.jsonl"),FileAccess.WRITE)
	_render_trace=FileAccess.open(output_dir.path_join("render.jsonl"),FileAccess.WRITE)
	assert(_trace!=null and _render_trace!=null)
	save_json(output_dir.path_join("setup.json"),setup_receipt())
	recording=true;tick=0;elapsed=0;rows=0

func stop_recording()->Dictionary:
	recording=false
	if _trace!=null:_trace.flush();_trace.close();_trace=null
	if _render_trace!=null:_render_trace.flush();_render_trace.close();_render_trace=null
	var result:Dictionary={"condition":condition,"ticks":rows,"elapsed_s":elapsed,"output_dir":output_dir,"phase":"POST_CONTROL_BEFORE_NEXT_INTEGRATION","human_feel_validated":false}
	save_json(output_dir.path_join("receipt.json"),result)
	return result

func _exit_tree()->void:
	if recording:stop_recording()
	_unbind_visual()
	if is_instance_valid(_panel):_panel.queue_free()

func _unbind_visual()->void:
	if is_instance_valid(_biped) and is_instance_valid(_biped.hand_pose) and _ik_callback.is_valid() and _biped.hand_pose.modification_processed.is_connected(_ik_callback):
		_biped.hand_pose.modification_processed.disconnect(_ik_callback)

func _bind_visual()->void:
	if is_instance_valid(_biped) and _biped==app.biped:return
	_unbind_visual()
	_biped=app.biped
	_render_sample.clear();_render_sole_offsets.clear()
	var skeleton_to_body:Transform3D=_biped.global_transform.affine_inverse()*_biped.skeleton.global_transform
	for id in 2:
		var bone:int=_biped.skeleton.find_bone("foot_l" if id==0 else "foot_r")
		var rest:Transform3D=skeleton_to_body*_biped.skeleton.get_bone_global_rest(bone)
		_render_sole_offsets.append(rest.affine_inverse()*(rest.origin+Vector3.DOWN*_biped.foot_clearance[id]))
	_ik_callback=_after_ik.bind(_biped)
	_biped.hand_pose.modification_processed.connect(_ik_callback)

func _visual_owner()->Dictionary:
	if not is_instance_valid(_biped):return {"mode":"UNKNOWN","fingerprint":"UNKNOWN"}
	var driver_mode:="INACTIVE"
	if is_instance_valid(_biped.mantle_driver) and _biped.mantle_driver.is_driving():driver_mode=_biped.mantle_driver.mode
	var mode:String="HYBRID_"+driver_mode if driver_mode!="INACTIVE" else "GROUND_ANIMATION" if _biped.ik.influence<.001 else "CLIMBING_IK" if _biped.ik.influence>.999 and _biped.animation_clip=="A_TPose" else "ANIMATION_IK_BLEND"
	return {"mode":mode,"driver_mode":driver_mode,"animation_clip":_biped.animation_clip,"shared_IK_weight":_biped.ik.influence,"weight_scope":"SHARED_FOUR_LIMB_IK_NOT_PER_FOOT_LOAD","fingerprint":mode+"|"+driver_mode+"|"+str(_biped.animation_clip)}

func _render_status()->Dictionary:
	var visual_owner:Dictionary=_visual_owner()
	if visual_owner.mode.begins_with("HYBRID_"):
		return {"status":"UNKNOWN_HYBRID_RENDER_NOT_SAMPLED_BY_ORDINARY_MODIFIER","current_owner":visual_owner}
	if _render_sample.is_empty():return {"status":"UNKNOWN_NO_POST_MODIFIER_SAMPLE","current_owner":visual_owner}
	var frame_age:int=maxi(0,Engine.get_process_frames()-int(_render_sample.render_frame))
	var tick_age:int=maxi(0,tick-int(_render_sample.last_observed_physics_tick))
	var time_age:float=maxf(0.0,(Time.get_ticks_usec()-int(_render_sample.wall_usec))/1000000.0)
	var status:="AVAILABLE_SEPARATE_RENDER_CLOCK"
	if visual_owner.fingerprint!=_render_sample.owner.fingerprint:status="UNKNOWN_OWNER_CHANGED"
	elif frame_age>2 or time_age>.25 or tick_age>ceili(Engine.physics_ticks_per_second*.25):status="UNKNOWN_STALE_POST_MODIFIER_SAMPLE"
	return {"status":status,"render_frame_age":frame_age,"physics_tick_age":tick_age,"wall_age_s":time_age,"current_owner":visual_owner,"sample_owner":_render_sample.owner,"same_physics_tick_claimed":false}

func _after_ik(observed_visual:Node)->void:
	if not is_instance_valid(observed_visual) or observed_visual!=_biped or _biped!=app.biped:return
	var visual_owner:Dictionary=_visual_owner()
	if visual_owner.mode.begins_with("HYBRID_"):return
	var feet:Array=[]
	for id in 2:
		var bone:int=_biped.skeleton.find_bone("foot_l" if id==0 else "foot_r")
		var pose:Transform3D=_biped.skeleton.global_transform*_biped.skeleton.get_bone_global_pose(bone)
		feet.append({"id":id,"rendered_ankle":pose.origin,"rendered_sole_proxy":pose*_render_sole_offsets[id],"sole_scope":"REST_CALIBRATED_RENDER_SOLE_PROXY_NOT_MESH_CONTACT","IK_target":_biped.targets[id+2].global_position,"IK_weight":_biped.ik.influence,"weight_scope":"SHARED_FOUR_LIMB_IK_NOT_PER_FOOT_LOAD","ankle_target_error_m":pose.origin.distance_to(_biped.targets[id+2].global_position)})
	_render_sample={"phase":"RENDER_AFTER_HAND_POSE_MODIFICATION","render_frame":Engine.get_process_frames(),"last_observed_physics_tick":tick,"wall_usec":Time.get_ticks_usec(),"feet":feet,"owner":visual_owner}
	if recording and _render_trace!=null:_render_trace.store_line(JSON.stringify(json_value(_render_sample),"",true,true))

func _native_contacts(body:RigidBody3D)->Dictionary:
	var direct:=PhysicsServer3D.body_get_direct_state(body.get_rid())
	if direct==null or body.max_contacts_reported==0:return {"status":"UNKNOWN","reason":"DIRECT_STATE_OR_CONTACT_REPORTING_UNAVAILABLE","contacts":[]}
	var contacts:Array=[]
	for index in direct.get_contact_count():
		var shape:int=direct.get_contact_local_shape(index)
		var shape_owner:Object=body.shape_owner_get_owner(body.shape_find_owner(shape)) if shape>=0 and shape<PhysicsServer3D.body_get_shape_count(body.get_rid()) else null
		contacts.append({"shape":str(shape_owner.name) if shape_owner!=null else "UNKNOWN","collider_id":direct.get_contact_collider_id(index),"local_point":direct.get_contact_local_position(index),"local_normal":direct.get_contact_local_normal(index),"impulse_Ns":direct.get_contact_impulse(index)})
	var status:String="OBSERVED_CONTACTS" if not contacts.is_empty() else "UNKNOWN_FROZEN_BODY_NO_SOLVED_CONTACTS_REPORTED" if body.freeze else "NO_REPORTED_CONTACTS_NOT_PROOF_OF_ABSENCE"
	var counts:Dictionary={"FootBase":0,"LowerCapsule":0}
	var peak:=0.0
	for contact:Dictionary in contacts:
		if counts.has(contact.shape):counts[contact.shape]+=1
		peak=maxf(peak,Vector3(contact.impulse_Ns).length())
	return {"status":status,"body_frozen":body.freeze,"freeze_mode":body.freeze_mode,"buffer_full":contacts.size()>=body.max_contacts_reported,"max_reported":body.max_contacts_reported,"shape_reported_counts":counts,"peak_reported_impulse_Ns":peak,"contacts":contacts}

func _physics_process(delta:float)->void:
	if not is_instance_valid(app) or not is_instance_valid(app.controller):return
	_bind_visual()
	tick+=1;elapsed+=delta
	var c=app.controller
	var body:RigidBody3D=app.torso
	var solver=c.feet_solver
	var ownership:bool=c.assisted_motion_owned or not c.tuning.physical_feet
	var intent:Vector3=c.intent_locomotion.data.get("movement_intent_world",Vector3.ZERO)
	var direction:Vector3=intent.normalized()
	var center:=Solver.center_of_mass(body)
	var feet:Array=[]
	for id in solver.feet.size():
		var foot:Dictionary=solver.feet[id]
		var support:PhysicsBody3D=foot.support if is_instance_valid(foot.support) else null
		var hip:Vector3=solver.get_hip_world(id)
		var applied:Vector3=Vector3.ZERO if ownership else Vector3(foot.force)
		var point:Vector3=foot.contact_point
		var native_anchor:Variant=null
		var support_id:Variant=null
		var support_name:Variant=null
		if support!=null:
			native_anchor=support.to_global(foot.local_point)
			support_id=support.get_instance_id()
			support_name=str(support.name)
		var relative_velocity:Vector3=Solver.point_velocity(body,point)-(Solver.point_velocity(support,point) if support!=null else Vector3.ZERO)
		var length:float=hip.distance_to(foot.ankle)
		var admitted:bool=solver._pending.any(func(entry):return entry.id==id) and not ownership
		var ground_filtered:bool=app.ground_motor.grounded and support==app.ground_motor.support_body and not admitted
		feet.append({"id":id,"side":"left" if id==0 else "right","state":foot.state,"reason":foot.reason,"support_id":support_id,"support_name":support_name,"candidate":solver.candidate_selection().get("feet",{}).get(id,{}),
			"local_point":foot.local_point,"local_normal":foot.local_normal,"force_application_point":point,"current_material_anchor":native_anchor,"normal":foot.normal,"ankle":foot.ankle,"hip":hip,"hip_distance_m":length,"max_leg_length_m":solver._lengths[id],"workspace_margin_m":solver._lengths[id]*.999-length,
			"path_validity":Sampler.validate(body,solver.tuning,hip,foot.ankle,solver._lengths[id],support,point,foot.normal,solver._clearances[id]) if support!=null else "NO_SUPPORT",
			"rest_length_m":foot.rest_length,"load_in_weight":foot.blend,"raw_cached_force_N":foot.force,"actual_applied_force_N":applied,"normal_N":maxf(0,applied.dot(foot.normal)),"tangent_N":applied-foot.normal*maxf(0,applied.dot(foot.normal)),"reaction_N":-applied if support is RigidBody3D and not support.freeze else Vector3.ZERO,"reaction_scope":"DYNAMIC_OPPOSITE_AT_SAME_POINT" if support is RigidBody3D and not support.freeze else "STATIC_WORLD",
			"admitted_request":admitted,"ground_owner_filtered":ground_filtered,"reaction_observation":"DERIVED_FROM_ACTUAL_BODY_FORCE_AND_SOURCE_COMMIT_CONTRACT_NOT_INDEPENDENT_SENSOR","candidate_status":"CURRENT_PLANT_TARGET" if foot.state=="PLANTING" else "B1_ALTERNATIVE_CANDIDATES_NOT_EXPORTED","support_point_velocity":Solver.point_velocity(support,point) if support!=null else Vector3.ZERO,"support_angular_velocity":support.angular_velocity if support is RigidBody3D else support.constant_angular_velocity if support is StaticBody3D else Vector3.ZERO,"force_along_intent_N":applied.dot(direction),"relative_work_rate_W":applied.dot(relative_velocity),"hip_axis_dot_intent":(hip-foot.ankle).normalized().dot(direction),"foot_moment_Nm":(point-center).cross(applied),"visual_physics_endpoint":_biped.leg_motion.feet[id]})
	var render_status:Dictionary=_render_status()
	_latest={"schema":"foot_diagnosis_v14_F0","tick":tick,"delta_s":delta,"time_s":elapsed,"phase":"POST_CONTROL_BEFORE_NEXT_INTEGRATION","condition":condition,"stage":stage,"body_id":body.get_instance_id(),"feet_enabled":c.tuning.physical_feet,"B2":c.intent_aware_feet_enabled,"allocation":app.movement_allocation,"body_COM":center,"body_velocity":body.linear_velocity,"body_spin":body.angular_velocity,"FootBase_transform":body.get_node("FootBase").global_transform,"lower_collider_transform":body.get_node("LowerCapsule").global_transform,
		"intent":intent,"requested_input":c.intent_locomotion.requested,"support_frame":c.intent_locomotion.frame.snapshot(),"actual_intent_speed_m_s":body.linear_velocity.dot(direction),"hands":c.hands.map(func(hand):return {"state":hand.state,"force_N":Vector3.ZERO if c.assisted_motion_owned else hand.force,"anchor":hand.anchor_world}),"grounded":app.ground_motor.grounded,"ground_motor_force_N":app.ground_motor.applied_force,"ground_motor_torque_Nm":app.ground_motor.applied_torque,"hybrid_owned":c.assisted_motion_owned,"native":_native_contacts(body),"feet":feet,"render_sample_separate_phase":_render_sample,"render_sample_status":render_status.status,"render_clock":render_status}
	if recording and _trace!=null:
		_trace.store_line(JSON.stringify(json_value(_latest),"",true,true));rows+=1
	_ui_clock+=delta
	if _ui_clock>.1:_ui_clock=0;_update_hud()

func _marker(marker_name:String,color:Color,radius:float=.025)->MeshInstance3D:
	var instance:=MeshInstance3D.new()
	instance.name=marker_name
	var sphere:=SphereMesh.new()
	sphere.radius=radius;sphere.height=radius*2.0
	sphere.radial_segments=12;sphere.rings=6
	instance.mesh=sphere
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test=true
	instance.material_override=material
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visible=false
	_marker_root.add_child(instance)
	return instance

func _build_markers()->void:
	_marker_root=Node3D.new()
	_marker_root.name="DiagnosticRenderOnlyMarkers"
	add_child(_marker_root)
	for id in 2:
		_markers["sole_%d"%id]=_marker("ObservedSole%d"%id,Color("70e794"),.022)
		_markers["target_%d"%id]=_marker("IKTarget%d"%id,Color("ed76d0"),.015)
		_markers["anchor_%d"%id]=_marker("CurrentContact%d"%id,Color("ffad55"),.025)
	_markers.native_sole=_marker("NativeSoleCenter",Color("53dce9"),.018)
	var box:=_marker("NativeFootBase",Color("53dce9"))
	var box_mesh:=BoxMesh.new()
	box_mesh.size=app.torso.get_node("FootBase").shape.size
	box.mesh=box_mesh
	var box_material:StandardMaterial3D=box.material_override
	box_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	box_material.albedo_color=Color(.20,.85,.90,.16)
	box_material.no_depth_test=false
	_markers.native_box=box

func _process(_delta:float)->void:
	for entry_marker:MeshInstance3D in _markers.values():entry_marker.visible=false
	if _latest.is_empty() or not is_instance_valid(app) or not is_instance_valid(app.torso):return
	if int(_latest.get("body_id",0))!=app.torso.get_instance_id():return
	if _sections.native:
		var sole:CollisionShape3D=app.torso.get_node("FootBase")
		var interpolated:Transform3D=app.torso.get_global_transform_interpolated()*sole.transform
		_markers.native_box.global_transform=interpolated
		_markers.native_box.visible=true
		_markers.native_sole.global_position=interpolated*(Vector3.DOWN*Vector3(sole.shape.size).y*.5)
		_markers.native_sole.visible=true
	if _sections.actuator and _latest.feet_enabled and not _latest.hybrid_owned:
		for foot:Dictionary in _latest.feet:
			if foot.state in ["SUPPORTING","SLIDING"] and foot.current_material_anchor is Vector3:
				var anchor_marker:MeshInstance3D=_markers["anchor_%d"%int(foot.id)]
				anchor_marker.global_position=foot.current_material_anchor
				anchor_marker.visible=true
	var render_status:Dictionary=_render_status()
	if _sections.IK and render_status.status=="AVAILABLE_SEPARATE_RENDER_CLOCK":
		for foot:Dictionary in _render_sample.feet:
			var sole_marker:MeshInstance3D=_markers["sole_%d"%int(foot.id)]
			sole_marker.global_position=foot.rendered_sole_proxy
			sole_marker.visible=true
			var target_marker:MeshInstance3D=_markers["target_%d"%int(foot.id)]
			target_marker.global_position=foot.IK_target
			target_marker.visible=true

func _build_hud()->void:
	_panel=PanelContainer.new();_panel.position=Vector2(32,420);_panel.custom_minimum_size=Vector2(510,0)
	app.hud.add_child(_panel)
	var box:=VBoxContainer.new();_panel.add_child(box)
	var bar:=HBoxContainer.new();box.add_child(bar)
	for section:String in _sections:
		var section_name:String=section
		var toggle:=CheckButton.new();toggle.text=section_name;toggle.button_pressed=true;bar.add_child(toggle)
		toggle.toggled.connect(func(value:bool):_sections[section_name]=value;_update_hud())
	var actions:=HBoxContainer.new();box.add_child(actions)
	for enabled in [false,true]:
		var on:bool=enabled
		var button:=Button.new();button.text="Fresh B1 / current" if on else "Fresh B0 / feet OFF";actions.add_child(button)
		button.pressed.connect(func():
			if recording:stop_recording()
			app._set_movement_allocation(0);app._set_intent_aware_feet(false)
			app._open_first_ascent();app._set_physical_feet(on);condition="B1" if on else "B0"
			output_dir="res://builds/foot_release_v14_r1/manual_%s_%d"%[condition,Time.get_ticks_usec()];DirAccess.make_dir_recursive_absolute(output_dir);start_recording()
		)
	var record:=Button.new();record.text="Record / stop";actions.add_child(record)
	record.pressed.connect(func():
		if recording:stop_recording()
		else:start_recording()
	)
	_text=Label.new();_text.add_theme_font_size_override("font_size",14);box.add_child(_text)

func _update_hud()->void:
	if _latest.is_empty() or not is_instance_valid(_text):return
	var lines:Array[String]=["F0 / %s / %s / %s"%[condition,stage,"REC" if recording else "not recording"]]
	if _sections.native:
		lines.append("Native: %s | ground %s | hybrid %s"%[_latest.native.status,_latest.grounded,_latest.hybrid_owned])
		var counts:Dictionary=_latest.native.get("shape_reported_counts",{})
		lines.append("  FootBase %s | lower %s | reported peak %s Ns"%[str(counts.get("FootBase","UNKNOWN")),str(counts.get("LowerCapsule","UNKNOWN")),str(_latest.native.get("peak_reported_impulse_Ns","UNKNOWN"))])
	for foot:Dictionary in _latest.feet:
		if _sections.actuator:lines.append("%s %s | N %.1f | F %.1f | blend %.2f | ground-filter %s"%[foot.side,foot.state,foot.normal_N,Vector3(foot.actual_applied_force_N).length(),foot.load_in_weight,foot.ground_owner_filtered])
		if _sections.opposition:lines.append("  intent force %.1f N | room %.3f m | speed %.3f m/s"%[foot.force_along_intent_N,foot.workspace_margin_m,_latest.actual_intent_speed_m_s])
	if _sections.IK:
		var render_status:Dictionary=_render_status()
		lines.append("IK: %s"%render_status.status)
		var visual_owner:Dictionary=render_status.current_owner
		lines.append("  %s | clip %s | SHARED IK %.2f"%[visual_owner.mode,str(visual_owner.get("animation_clip","UNKNOWN")),float(visual_owner.get("shared_IK_weight",0))])
		if render_status.has("render_frame_age"):lines.append("  render age %df / physics age %dt (separate clocks)"%[render_status.render_frame_age,render_status.physics_tick_age])
		if render_status.status=="AVAILABLE_SEPARATE_RENDER_CLOCK":
			for foot:Dictionary in _render_sample.feet:lines.append("  foot%d ankle-target %.3f m"%[foot.id,foot.ankle_target_error_m])
	lines.append("cyan=native | green=sole proxy | pink=IK | orange=contact")
	_text.text="\n".join(lines)
