extends RefCounted
var body:RigidBody3D
var controller:Node
var ground:Node
var camera:Camera3D
var motor:RefCounted
var support_history:Dictionary={}
var observed_moving:Dictionary={}

func configure(grips:Node,ground_motor:Node,view:Camera3D,collision_motor:RefCounted)->void:
	controller=grips
	body=grips.torso
	ground=ground_motor
	camera=view
	motor=collision_motor

func _ray(from:Vector3,to:Vector3)->Dictionary:
	return body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,body.collision_mask,[body.get_rid()]))

func reject(reason:String)->Dictionary:
	return {"eligible":false,"eligibility_reason":reason,"candidate_timestamp":Time.get_ticks_msec()}

func detect()->Dictionary:
	var ids:Array[int]=[]
	for id in 2:
		if controller.hands[id].state=="ATTACHED" and controller.hands[id].anchor!=null and controller.hands[id].anchor.is_valid():ids.append(id)
	if ids.is_empty():return reject("GRIP_SLIPPING" if controller.hands.any(func(hand):return hand.state=="SLIPPING") else "NO_REAL_GRIP")
	var refused:=reject("NOT_A_LEDGE")
	for id in ids:
		var current:=_from_hand(id,ids)
		if current.eligible:return current
		refused=current
	return refused

func _from_hand(id:int,ids:Array[int])->Dictionary:
	var hand:Dictionary=controller.hands[id]
	var support:PhysicsBody3D=hand.anchor.support_body()
	if not support is StaticBody3D or support is AnimatableBody3D:return reject("UNSUPPORTED_DYNAMIC_PLATFORM")
	var identity:int=support.get_instance_id()
	if support_history.has(identity) and not support.global_transform.is_equal_approx(support_history[identity]):observed_moving[identity]=true
	support_history[identity]=support.global_transform
	if observed_moving.has(identity):return reject("UNSUPPORTED_DYNAMIC_PLATFORM")
	if support.constant_linear_velocity.length()>.0001 or support.constant_angular_velocity.length()>.0001:return reject("UNSUPPORTED_DYNAMIC_PLATFORM")
	var anchor:Vector3=hand.anchor.world_point()
	var outward:Vector3=hand.anchor.world_normal().slide(Vector3.UP).normalized()
	if outward.length_squared()<.5:outward=(body.global_position-anchor).slide(Vector3.UP).normalized()
	if outward.length_squared()<.5:return reject("NOT_A_LEDGE")
	var inward:Vector3=-outward
	var tangent:Vector3=Vector3.UP.cross(outward).normalized()
	var top:=_ray(anchor+inward*.055+Vector3.UP*.25,anchor+inward*.055-Vector3.UP*.10)
	if top.is_empty() or top.collider!=support or Vector3(top.normal).dot(Vector3.UP)<.85:return reject("NO_FLAT_TOP")
	var height:float=Vector3(top.position).y
	if absf(height-anchor.y)>.20:return reject("NOT_A_LEDGE")
	var edge:Vector3=anchor
	edge.y=height
	var away:float=(body.global_position-edge).dot(outward)
	var below:float=height-body.global_position.y
	# Existing shoulder offset.524m plus actual arm reach permits a body origin
	# about1.1m below the top; the source grip still must be truly ATTACHED.
	if ground.grounded or away<.18 or away>.72 or below<.1 or below>1.10 or body.global_basis.y.dot(Vector3.UP)<.70 or body.linear_velocity.length()>3.2 or body.angular_velocity.length()>3.0:return reject("START_POSE_OUTSIDE_ENVELOPE")
	if (-body.global_basis.z).dot(inward)<.2 or (-camera.global_basis.z).slide(Vector3.UP).normalized().dot(inward)<.15:return reject("START_POSE_OUTSIDE_ENVELOPE")
	# A corridor, not a single point: full standing sole plus side margins and
	# depth for entry, standing and at least30cm subsequent walking.
	for x in [-.31,0.0,.31]:
		for z in [.08,.35,.65,1.12]:
			var point:Vector3=edge+tangent*x+inward*z
			var hit:=_ray(point+Vector3.UP*.06,point-Vector3.UP*.06)
			if hit.is_empty() or hit.collider!=support or Vector3(hit.normal).dot(Vector3.UP)<.85 or absf(hit.position.y-height)>.015:return reject("TOO_NARROW")
	var standing_height:float=-motor.lowest_point(0)+.0083
	var destination:=Transform3D(Basis.looking_at(inward,Vector3.UP),edge+inward*.65+Vector3.UP*standing_height)
	destination.origin.x=body.global_position.x if absf(outward.z)>.9 else destination.origin.x
	var fit:Dictionary=motor.standing_clear(destination)
	if not fit.get("clear",false):return reject("TARGET_OCCUPIED")
	var anchors:Array[Vector3]=[]
	for source_id in ids:anchors.append(controller.hands[source_id].anchor.world_point())
	return {"eligible":true,"eligibility_reason":"ELIGIBLE","clearance_reason":"PREFLIGHT_REQUIRED","support_id":support.get_instance_id(),"support":support,"source_hands":ids,"hand_anchors_world":anchors,"anchor_local_on_support":support.to_local(anchor),"top_reference_world":edge,"top_normal_world":top.normal,"outward_world":outward,"inward_world":inward,"edge_tangent_world":tangent,"start_pose_world":body.global_transform,"target_standing_pose_world":destination,"allowed_collision_profile_id":"MANTLE_TUCKED","candidate_timestamp":Time.get_ticks_msec(),"support_transform":support.global_transform,"hand_release_start":.25,"hand_release_end":.38}
