extends RefCounted
## Opt-in C1, two sagittal segments on the SAME dynamic body. No limb force,
## body transform/velocity writes, collision-mask changes, or disabled colliders.
## Call step from _physics_process, outside _integrate_forces/query callbacks,
## BEFORE deriving foot/ground contacts. Loaded contacts must first relinquish load.
const FLEX_RATE := 0.65
const MAX_SWEEP_DISPLACEMENT := 0.002
const QUERY_SKIN := 0.0005
const STATIONARY_CONTACT_TOLERANCE := 0.002
var body: RigidBody3D
var leg: CollisionShape3D
var sole: CollisionShape3D
var shin: CollisionShape3D
var original_shape: CapsuleShape3D
var original_leg_transform: Transform3D
var original_sole_transform: Transform3D
var original_inertia := Vector3.ZERO
var fixed_inertia := Vector3.ZERO
var requested_flex := 0.0
var achieved_flex := 0.0
var active := false
var blocked := false
var reason := "DISABLED"
var blocked_requests := 0
var last_audit: Dictionary = {}
var contact_diagnostics: Dictionary = {}
var length := 0.27
var radius := 0.15
var hip := Vector3(0,-0.2267,0)
var ankle_to_sole := Vector3(0,-0.11,-0.035)
var segment_shape: CapsuleShape3D

func configure(target: RigidBody3D, lower_capsule: CollisionShape3D, foot: CollisionShape3D, _tuning: Resource = null) -> void:
	body=target
	leg=lower_capsule
	sole=foot
	original_shape=leg.shape
	original_leg_transform=leg.transform
	original_sole_transform=sole.transform
	original_inertia=body.inertia
	radius=original_shape.radius
	length=(original_shape.height-2.0*radius)*0.5
	hip=leg.position+Vector3.UP*length
	var ankle:Vector3=leg.position-Vector3.UP*length
	ankle_to_sole=sole.position-ankle
	segment_shape=CapsuleShape3D.new()
	segment_shape.radius=radius
	segment_shape.height=length+2.0*radius

func request_flex(value: float) -> void:
	requested_flex=clampf(value,0.0,1.0)

func pose_for(flex: float) -> Dictionary:
	var a:float=deg_to_rad(75.0)*clampf(flex,0.0,1.0)
	# Hip flex75°, knee flex150°: shin inclines75° rearward from down.
	var b:float=deg_to_rad(75.0)*clampf(flex,0.0,1.0)
	var knee:Vector3=hip+Vector3(0,-cos(a),-sin(a))*length
	var ankle:Vector3=knee+Vector3(0,-cos(b),sin(b))*length
	return {"thigh":_segment(hip,knee),"shin":_segment(knee,ankle),"sole":Transform3D(original_sole_transform.basis,ankle+ankle_to_sole),"hip":hip,"knee":knee,"ankle":ankle}

func _segment(start: Vector3, end: Vector3) -> Transform3D:
	var axis:Vector3=(start-end).normalized()
	var z:Vector3=Vector3.RIGHT.cross(axis).normalized()
	return Transform3D(Basis(Vector3.RIGHT,axis,z),(start+end)*0.5)

func _motion_bound(flex_span: float) -> float:
	# Maximum motion of any proxy point over this interval, from arc-length
	# bounds, including capsule radius under rotation. Sole stays level.
	return absf(flex_span)*(length+radius)*(deg_to_rad(75.0)+deg_to_rad(75.0))

func _inflated(shape: Shape3D, padding: float) -> Shape3D:
	if shape is CapsuleShape3D:
		var result:=CapsuleShape3D.new()
		result.radius=shape.radius+padding
		result.height=shape.height+2.0*padding
		return result
	if shape is SphereShape3D:
		var result:=SphereShape3D.new()
		result.radius=shape.radius+padding
		return result
	if shape is BoxShape3D:
		var result:=BoxShape3D.new()
		result.size=shape.size+Vector3.ONE*2.0*padding
		return result
	return shape

func _query(shape: Shape3D, local_pose: Transform3D, padding: float = 0.0) -> Array[Dictionary]:
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=_inflated(shape,padding)
	query.transform=body.global_transform*local_pose
	query.collision_mask=body.collision_mask
	query.exclude=[body.get_rid()]
	query.margin=0.0
	return body.get_world_3d().direct_space_state.intersect_shape(query,8)

func audit_pose(flex: float, padding: float = QUERY_SKIN) -> Dictionary:
	var pose:Dictionary=pose_for(flex)
	var probes:Array=[{"name":"thigh","shape":segment_shape,"pose":pose.thigh,"moving":true},{"name":"shin","shape":segment_shape,"pose":pose.shin,"moving":true},{"name":"sole","shape":sole.shape,"pose":pose.sole,"moving":true}]
	for child in body.get_children():
		if child is CollisionShape3D and child!=leg and child!=sole and child!=shin and not child.disabled:
			probes.append({"name":str(child.name),"shape":child.shape,"pose":child.transform,"moving":false})
	for probe in probes:
		# Torso/head do not participate in the lower-limb arc. Inflating them
		# would reject harmless native wall contact for every crouch request.
		var hits:Array[Dictionary]=_query(probe.shape,probe.pose,padding if probe.moving else 0.0)
		if not hits.is_empty():
			if not probe.moving and _penetration(probe.shape,probe.pose)<=STATIONARY_CONTACT_TOLERANCE:continue
			return {"clear":false,"flex":flex,"shape":probe.name,"blocker_id":hits[0].collider_id,"padding":padding,"reason":"COLLIDER_PATH_BLOCKED"}
	return {"clear":true,"flex":flex,"padding":padding,"reason":"CLEAR"}

func audit_path(from_flex: float, to_flex: float) -> Dictionary:
	var count:int=maxi(1,ceili(_motion_bound(to_flex-from_flex)/MAX_SWEEP_DISPLACEMENT))
	var padding:float=QUERY_SKIN+_motion_bound(to_flex-from_flex)/float(count)*0.5
	# Midpoint inflated by a proven arc-length bound covers every intermediate
	# pose (rotation included); this is not merely endpoint sampling.
	for index in count:
		var midpoint:float=lerpf(from_flex,to_flex,(index+0.5)/float(count))
		var result:Dictionary=audit_pose(midpoint,padding)
		if not result.clear:
			result["last_safe_flex"]=lerpf(from_flex,to_flex,index/float(count))
			result["substeps"]=count
			return result
	var result:Dictionary=audit_pose(to_flex)
	result["last_safe_flex"]=to_flex if result.clear else from_flex
	result["substeps"]=count
	return result

func _activate() -> bool:
	var state:=PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state==null:
		return false
	var inverse:Vector3=state.inverse_inertia
	if inverse.x<=0.0 or inverse.y<=0.0 or inverse.z<=0.0:return false
	fixed_inertia=Vector3(1.0/inverse.x,1.0/inverse.y,1.0/inverse.z)
	body.inertia=fixed_inertia
	shin=CollisionShape3D.new()
	shin.name="AdaptiveShin"
	shin.shape=segment_shape
	shin.transform=pose_for(0.0).shin
	body.add_child(shin)
	leg.shape=segment_shape
	leg.transform=pose_for(0.0).thigh
	active=true
	return true

func _restore_standing_representation() -> void:
	# Restore original full capsule before removing its redundant lower half.
	leg.shape=original_shape
	leg.transform=original_leg_transform
	sole.transform=original_sole_transform
	body.remove_child(shin)
	shin.free()
	shin=null
	body.inertia=original_inertia
	active=false

func step(delta: float, enabled: bool, loaded_foot_force_n: float = 0.0) -> Dictionary:
	blocked=false
	_read_contacts()
	if not enabled and not active:
		reason="DISABLED"
		return telemetry()
	if not active and not _activate():
		reason="WAITING_FOR_SOLVED_INERTIA"
		return telemetry()
	var target:float=requested_flex if enabled else 0.0
	if is_equal_approx(target,achieved_flex):
		reason="AT_REQUESTED_POSE"
		if not enabled and achieved_flex<=0.000001:_restore_standing_representation()
		return telemetry()
	if loaded_foot_force_n>1.0:
		blocked=true
		reason="LOAD_TRANSFER_REQUIRED"
		blocked_requests+=1
		return telemetry()
	var next:float=move_toward(achieved_flex,target,FLEX_RATE*maxf(0.0,delta))
	last_audit=audit_path(achieved_flex,next)
	if not last_audit.clear:
		blocked=true
		reason=last_audit.reason
		blocked_requests+=1
		# A conservative whole tick is denied. This preserves the last applied
		# valid pose even if an obstacle enters after the previous solved tick.
		return telemetry()
	achieved_flex=next
	var pose:Dictionary=pose_for(achieved_flex)
	leg.transform=pose.thigh
	shin.transform=pose.shin
	sole.transform=pose.sole
	reason="FLEXING" if target>achieved_flex else "EXTENDING"
	if not enabled and achieved_flex<=0.000001:_restore_standing_representation()
	return telemetry()

func _read_contacts() -> void:
	var state:=PhysicsServer3D.body_get_direct_state(body.get_rid())
	var maximum:=0.0
	var contacts:Array=[]
	if state!=null:
		for index in state.get_contact_count():
			var impulse:Vector3=state.get_contact_impulse(index)
			maximum=maxf(maximum,impulse.length())
			contacts.append({"shape":state.get_contact_local_shape(index),"point":state.get_contact_local_position(index),"impulse":impulse,"collider_id":state.get_contact_collider_id(index)})
	contact_diagnostics={"contacts":contacts,"peak_impulse_ns":maximum,"speed_m_s":body.linear_velocity.length(),"angular_speed_rad_s":body.angular_velocity.length()}

func foot_local_transform() -> Transform3D:
	return sole.transform

func _penetration(shape: Shape3D, local_pose: Transform3D) -> float:
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform=body.global_transform*local_pose
	query.collision_mask=body.collision_mask
	query.exclude=[body.get_rid()]
	query.margin=0.0
	var pairs:PackedVector3Array=body.get_world_3d().direct_space_state.collide_shape(query,32)
	var depth:=0.0
	for index in range(0,pairs.size()-1,2):depth=maxf(depth,pairs[index].distance_to(pairs[index+1]))
	return depth

func clearance_diagnostics() -> Dictionary:
	# Queries report geometric contacts, not native solved contact impulses.
	# Paired points give a penetration estimate; inflation bins give a
	# conservative whole-body separation lower bound when no overlap exists.
	var maximum_penetration:=0.0
	var pairs_count:=0
	for child in body.get_children():
		if not child is CollisionShape3D or child.disabled:continue
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=child.shape
		query.transform=child.global_transform
		query.collision_mask=body.collision_mask
		query.exclude=[body.get_rid()]
		query.margin=0.0
		var pairs:PackedVector3Array=body.get_world_3d().direct_space_state.collide_shape(query,32)
		pairs_count+=pairs.size()/2
		for index in range(0,pairs.size()-1,2):
			maximum_penetration=maxf(maximum_penetration,pairs[index].distance_to(pairs[index+1]))
	var lower_bound:=0.0
	if pairs_count==0:
		for margin in [.001,.003,.01,.03,.05]:
			var all_clear:=true
			for child in body.get_children():
				if child is CollisionShape3D and not child.disabled and not _query(child.shape,child.transform,margin).is_empty():
					all_clear=false
					break
			if not all_clear:break
			lower_bound=margin
	return {"max_penetration_estimate_m":maximum_penetration,"contact_pairs":pairs_count,"separation_lower_bound_m":lower_bound,"not_native_solved_contact":true}

func telemetry() -> Dictionary:
	return {"enabled_shape_configuration":active,"desired_leg_flex":requested_flex,"actual_leg_flex":achieved_flex,"blocked":blocked,"reason":reason,"blocked_requests":blocked_requests,"path":last_audit.duplicate(true),"contacts":contact_diagnostics.duplicate(true),"foot_local_transform":sole.transform,"fixed_inertia":fixed_inertia,"body_mass":body.mass,"representation":"SAME_BODY_TWO_SAGITTAL_CAPSULES","force_authority_n":0.0,"minimum_query_skin_m":QUERY_SKIN}
