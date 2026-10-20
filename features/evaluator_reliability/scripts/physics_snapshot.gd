extends RefCounted
## Current direct-state COM and admitted controller forces; never a new observer
## with physics authority. Runtime IDs are retained beside stable fixture labels.
static func identity(support:PhysicsBody3D)->Dictionary:
	if not is_instance_valid(support):return {"key":"NONE","runtime_id":0}
	return {"key":str(support.get_meta("mastery_surface",support.name)),"runtime_id":support.get_instance_id(),"type":support.get_class(),"pose":support.global_transform}
static func optional(value:Variant)->Variant:return value
static func stable_initial(row:Dictionary)->Dictionary:
	var body:Dictionary=row.get("body",{})
	var stable:Dictionary={"sample_phase":row.get("sample_phase"),"body":{"com_m":body.get("com_m"),"pose":body.get("pose"),"linear_velocity_m_s":body.get("linear_velocity_m_s"),"angular_velocity_rad_s":body.get("angular_velocity_rad_s"),"mass_kg":body.get("mass_kg"),"sleeping":body.get("sleeping"),"shapes":body.get("shapes",[])},"hands":[],"feet":[],"profile":row.get("profile"),"command_accepted":row.get("command_accepted",{})}
	var accepted:Dictionary=row.get("command_accepted",{})
	stable.command_accepted={"intent_world":accepted.get("intent_world"),"accepted_input":accepted.get("accepted_input"),"hand_held":accepted.get("hand_held"),"input_owner":accepted.get("input_owner"),"blocked":accepted.get("blocked")}
	stable["configuration"]=row.get("configuration",{}).duplicate(true)
	stable.configuration.erase("observer_enabled")
	stable.body["contacts"]=[]
	for contact:Dictionary in body.get("contacts",[]):stable.body.contacts.append({"collider_key":contact.collider.key,"shape":contact.shape,"collider_shape":contact.collider_shape,"api_local_position_m":contact.position_m,"api_local_normal":contact.normal,"impulse_ns":contact.impulse_ns})
	for hand:Dictionary in row.get("hands",[]):stable.hands.append({"id":hand.id,"state":hand.state,"hand_world_m":hand.hand_world_m,"shoulder_world_m":hand.shoulder_world_m,"force_n":hand.force_n,"support_key":hand.support.key,"material_local_point_m":hand.material_local_point_m,"rest_length_m":hand.rest_length_m})
	for foot:Dictionary in row.get("feet",[]):stable.feet.append({"state":foot.state,"force_n":foot.force_n,"point_m":foot.point_m,"support_key":foot.support.key,"loaded":foot.loaded})
	return stable
static func direct(body:RigidBody3D)->Dictionary:
	var state:PhysicsDirectBodyState3D=PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state==null:return {"valid":false,"reason":"NO_DIRECT_STATE"}
	return {"valid":true,"com_m":state.transform.origin+state.center_of_mass,"pose":state.transform,"node_pose":body.global_transform,"linear_velocity_m_s":state.linear_velocity,"angular_velocity_rad_s":state.angular_velocity,"sleeping":state.sleeping,"mass_kg":body.mass,"contacts":contacts(state),"collision_layer":body.collision_layer,"collision_mask":body.collision_mask,"gravity_scale":body.gravity_scale,"linear_damp":body.linear_damp,"angular_damp":body.angular_damp,"linear_damp_mode":body.linear_damp_mode,"angular_damp_mode":body.angular_damp_mode}
static func contacts(state:PhysicsDirectBodyState3D)->Array:
	var result:Array=[]
	for index in state.get_contact_count():
		var collider=state.get_contact_collider_object(index)
		var label:Dictionary=identity(collider) if collider is PhysicsBody3D else {"key":"NON_BODY","runtime_id":state.get_contact_collider_id(index)}
		result.append({"collider":label,"position_m":state.get_contact_local_position(index),"normal":state.get_contact_local_normal(index),"impulse_ns":state.get_contact_impulse(index),"shape":state.get_contact_local_shape(index),"collider_shape":state.get_contact_collider_shape(index)})
	return result
static func point_velocity(support:PhysicsBody3D,point:Vector3)->Dictionary:
	if support is StaticBody3D:return {"valid":true,"linear":support.constant_linear_velocity+support.constant_angular_velocity.cross(point-support.global_position),"angular":support.constant_angular_velocity}
	if support is RigidBody3D:
		var state:PhysicsDirectBodyState3D=PhysicsServer3D.body_get_direct_state(support.get_rid())
		if state!=null:return {"valid":true,"linear":state.linear_velocity+state.angular_velocity.cross(point-state.transform.origin-state.center_of_mass),"angular":state.angular_velocity}
	return {"valid":false,"linear":null,"angular":null}
func read(app:Node)->Dictionary:
	var controller:Node=app.controller
	var body:Dictionary=direct(app.torso)
	var com:Vector3=body.get("com_m",app.torso.global_position)
	var telemetry:Dictionary=controller.telemetry()
	var hands:Array=[]
	var supports:Dictionary={}
	for id in 2:
		var hand:Dictionary=controller.hands[id]
		var anchor=hand.anchor
		var selected=controller._held_targets.get(id)
		if anchor==null and selected!=null:anchor=selected.anchor
		var support:PhysicsBody3D=anchor.support_body() if anchor!=null and anchor.is_valid() else null
		var target:Variant=anchor.world_point() if support!=null else hand.get("target_world")
		var pending:Dictionary=controller.pending_diagnostics(id)
		var row:Dictionary={"id":id,"state":hand.state,"attached":hand.state=="ATTACHED","hand_world_m":controller.get_hand_world(id),"shoulder_world_m":controller.get_shoulder_world(id),"force_n":controller.get_arm_force(id),"reaction_force_n":hand.get("reaction_force",Vector3.ZERO),"allocation":hand.get("allocation",0.0),"blend":hand.get("blend",null),"rest_length_m":hand.rest_length,"actual_length_m":hand.actual_length,"reason":hand.reason,"capture":hand.get("capture",{}).duplicate(true),"pending":pending,"target_world_m":target,"support":identity(support),"material_local_point_m":optional(anchor.local_point) if support!=null else null,"material_local_normal":optional(anchor.local_normal) if support!=null else null,"anchor_runtime_id":anchor.get_instance_id() if anchor!=null else 0,"reach_m":controller.get_max_reach()}
		if target is Vector3:row["shoulder_distance_m"]=controller.get_shoulder_world(id).distance_to(target);row["hand_target_distance_m"]=controller.get_hand_world(id).distance_to(target)
		if support!=null:row["target_velocity"]=point_velocity(support,target)
		hands.append(row)
		if support!=null and hand.state in ["ATTACHED","SLIPPING"]:supports[support.get_instance_id()]=support
	var feet:Array=[]
	if controller.feet_solver!=null:
		for foot:Dictionary in controller.feet_solver.feet:
			var actual:bool=foot.state in ["SUPPORTING","SLIDING"] and Vector3(foot.force).length()>1 and is_instance_valid(foot.support)
			feet.append({"state":foot.state,"force_n":foot.force,"normal":foot.normal,"normal_force_n":foot.normal_force,"tangent_force_n":foot.tangent_force,"point_m":foot.contact_point,"reason":foot.reason,"loaded":actual,"support":identity(foot.support)})
			if actual:supports[foot.support.get_instance_id()]=foot.support
	var support_row:Dictionary={"valid":not supports.is_empty(),"grounded":app.ground_motor.grounded,"hybrid_owned":controller.assisted_motion_owned,"ids":[],"frame_id":"NO_SUPPORT","point_m":null,"point_velocity_m_s":null,"angular_velocity_rad_s":null}
	var all_static:bool=not supports.is_empty()
	for support:PhysicsBody3D in supports.values():
		support_row.ids.append(identity(support))
		all_static=all_static and support is StaticBody3D and support.constant_linear_velocity==Vector3.ZERO and support.constant_angular_velocity==Vector3.ZERO
	if all_static:
		support_row.merge({"frame_id":"COMMON_STATIC_WORLD","point_m":Vector3.ZERO,"point_velocity_m_s":Vector3.ZERO,"angular_velocity_rad_s":Vector3.ZERO,"scope":"All actual supports are stationary; exact common static world reference, not an arbitrary representative material point"},true)
	elif supports.size()==1:
		var sole:PhysicsBody3D=supports.values()[0]
		var velocity:Dictionary=point_velocity(sole,com)
		support_row.merge({"frame_id":identity(sole).key,"point_m":sole.global_position,"point_velocity_m_s":velocity.linear,"angular_velocity_rad_s":velocity.angular,"scope":"Actual single support velocity evaluated at COM; point_m is material origin"},true)
	else:support_row["scope"]="No exact common moving support reference; optional measurements remain unknown"
	var movement:Dictionary=controller.intent_locomotion.data
	var frame:Dictionary=movement.get("frame",{})
	var raw:Vector2=controller.intent_locomotion.requested
	var accepted_world:=Vector3.ZERO
	if frame.get("valid",false):accepted_world=Vector3(frame.right)*raw.x+Vector3(frame.up)*raw.y
	var shapes:Array=[]
	for child in app.torso.get_children():
		if child is CollisionShape3D:
			var dimensions:Dictionary={}
			if child.shape!=null:
				for property:Dictionary in child.shape.get_property_list():
					if property.name in ["radius","height","size","margin"]:dimensions[property.name]=child.shape.get(property.name)
			shapes.append({"name":str(child.name),"disabled":child.disabled,"transform":child.transform,"shape_class":child.shape.get_class() if child.shape!=null else "NONE","dimensions":dimensions})
	body["shapes"]=shapes
	return {"body":body,"hands":hands,"feet":feet,"support":support_row,"command_accepted":{"intent_world":accepted_world,"accepted_input":raw,"accepted_input_time":movement.get("input_timestamp"),"hand_held":[Input.is_action_pressed("grip_left"),Input.is_action_pressed("grip_right")],"input_owner":app.router.owner,"blocked":app.settings.visible or app.rating_panel.visible,"window_has_focus":app.get_window().has_focus()},"frame":frame.duplicate(true),"force_budget":{"hands_n":telemetry.get("total_force"),"feet_n":telemetry.get("leg_force"),"assist_nm":telemetry.get("assist_torque"),"combined_nm":telemetry.get("combined_ground_climb_torque",telemetry.get("torque")),"ground_force_n":app.ground_motor.applied_force,"ground_torque_nm":app.ground_motor.applied_torque},"motion":controller.transfer_diagnostics().get("motion",{}),"camera":{"pose":app.camera.global_transform,"fov":app.camera.fov,"viewport_size":app.get_viewport().get_visible_rect().size,"pointer":app.pointer,"physics_interpolation_fraction":Engine.get_physics_interpolation_fraction()},"configuration":{"input_profile":app.input_profile,"movement_allocation":controller.intent_locomotion.movement_allocation,"physical_feet":controller.tuning.physical_feet,"intent_aware_feet":controller.intent_aware_feet_enabled,"intent_climb_enabled":controller.intent_climb_enabled,"observer_enabled":controller.locomotion_diagnostics_enabled,"baseline_parameters":{"traversal_speed_m_s":controller.tuning.traversal_speed_m_s,"traversal_input_ramp_s":controller.tuning.traversal_input_ramp_s,"traversal_target_max_rate":controller.tuning.traversal_target_max_rate,"traversal_target_max_acceleration":controller.tuning.traversal_target_max_acceleration}},"controller_step":controller._step,"controller_time_s":controller.simulation_time,"profile":controller.control_profile}
