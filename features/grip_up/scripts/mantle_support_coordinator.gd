extends Node
## Read-only contact recognition and collision-pose requests. No body force/pose.
const LegCollision=preload("res://features/grip_up/scripts/adaptive_leg_collision.gd")
var controller:Node
var body:RigidBody3D
var ground:Node
var level:Node3D
var legs=LegCollision.new()
var adaptive_enabled:=false
var handoff_enabled:=false
var phase:="NONE"
var data:Dictionary={}
var candidate:Dictionary={}
var standing_shapes:Array=[]
var stable_time:=0.0
var ground_distance:=0.0
var walk_previous:=Vector3.ZERO
var previous_walk_support:=0
var had_hanging_start:=false
var completed:=false
var suspended_run:=0.0
var last_phase:="NONE"
var events:Array=[]
var lower:CollisionShape3D
var sole:CollisionShape3D

func configure(grips:Node,motor:Node,arena:Node3D,lower_shape:CollisionShape3D,foot_shape:CollisionShape3D)->void:
	controller=grips
	body=controller.torso
	ground=motor
	level=arena
	lower=lower_shape
	sole=foot_shape
	legs.configure(body,lower,sole,controller.tuning)
	body.set_meta("adaptive_legs",legs)
	body.max_contacts_reported=16
	process_physics_priority=-20
	for child in body.get_children():
		if child is CollisionShape3D:standing_shapes.append({"shape":child.shape.duplicate(),"transform":child.transform})

func _ray(a:Vector3,b:Vector3)->Dictionary:
	return body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,body.collision_mask,[body.get_rid()]))

func _standing_destination(point:Vector3,inward:Vector3)->bool:
	var pose:=Transform3D(Basis.looking_at(inward,Vector3.UP),point+inward*.5+Vector3.UP*.93)
	for item in standing_shapes:
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=item.shape
		query.transform=pose*item.transform
		query.collision_mask=body.collision_mask
		query.exclude=[body.get_rid()]
		query.margin=.001
		if not body.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
	return true

func _candidate()->Dictionary:
	for hand in controller.hands:
		if hand.state!="ATTACHED" or hand.anchor==null or not hand.anchor.is_valid():continue
		var support:PhysicsBody3D=hand.anchor.support_body()
		var point:Vector3=hand.anchor.world_point()
		var normal:Vector3=hand.anchor.world_normal()
		var inward:Vector3=-normal.slide(Vector3.UP).normalized()
		if normal.dot(Vector3.UP)>.85:
			inward=(point-body.global_position).slide(Vector3.UP).normalized()
			if inward.length_squared()<.5:inward=-body.global_basis.z.slide(Vector3.UP).normalized()
		if inward.length_squared()<.5:continue
		var origin:Vector3=point+inward*.08
		var hit:=_ray(origin+Vector3.UP*.28,origin-Vector3.UP*.12)
		if hit.is_empty() or hit.collider!=support or Vector3(hit.normal).dot(Vector3.UP)<.85:continue
		var rear:=_ray(hit.position+inward*.35+Vector3.UP*.1,hit.position+inward*.35-Vector3.UP*.1)
		var bearing:bool=not rear.is_empty() and rear.collider==support and Vector3(rear.normal).dot(Vector3.UP)>.85 and absf(rear.position.y-hit.position.y)<.025
		var landing:Vector3=hit.position+inward*.05
		var right:Vector3=inward.cross(Vector3.UP).normalized()
		var palm_region:=true
		for x in [-.035,0.0,.035]:
			for z in [-.05,0.0,.05]:
				var sample:Vector3=landing+right*x+inward*z
				var ray:=_ray(sample+Vector3.UP*.02,sample-Vector3.UP*.02)
				palm_region=palm_region and not ray.is_empty() and ray.collider==support and Vector3(ray.normal).dot(Vector3.UP)>.85
		var destination:bool=bearing and _standing_destination(hit.position,inward)
		return {"support_id":support.get_instance_id(),"point":hit.position,"normal":hit.normal,"inward":inward,"top_bearing":"PASS" if bearing else "FAIL","palm_region":"PASS" if palm_region else "FAIL","standing_destination":"PASS" if destination else "FAIL","hand_route":"UNKNOWN","body_path":"UNKNOWN","path_reason":"PATH_NOT_CERTIFIED","eligible":bearing and palm_region and destination}
	return {"eligible":false,"top_bearing":"UNKNOWN","palm_region":"UNKNOWN","standing_destination":"UNKNOWN","hand_route":"UNKNOWN","body_path":"UNKNOWN","path_reason":"NO_ACTUAL_LEDGE_SUPPORT"}

func _lower_load(delta:float)->float:
	var load:=0.0
	var state:=PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state!=null:
		for i in state.get_contact_count():
			var shape_index:int=state.get_contact_local_shape(i)
			if shape_index<0 or shape_index>=PhysicsServer3D.body_get_shape_count(body.get_rid()):continue
			var owner:int=body.shape_find_owner(shape_index)
			var shape_node:Object=body.shape_owner_get_owner(owner)
			if shape_node==lower or shape_node==sole or shape_node==legs.shin:load+=maxf(0.0,state.get_contact_impulse(i).dot(Vector3.UP))/maxf(.001,delta)
	if controller.feet_solver!=null:
		for foot in controller.feet_solver.feet:load+=Vector3(foot.force).length()
	return load

func _physics_process(delta:float)->void:
	if not is_instance_valid(body):return
	var enabled:bool=controller.physics_mantle_v08_enabled and controller.control_profile==4
	var hands:Array=[]
	var palms:=0
	var load:=0.0
	for id in 2:
		var hand:Dictionary=controller.hands[id]
		if hand.state=="ATTACHED" and hand.anchor!=null and hand.anchor.is_valid():
			hands.append(id)
			load+=Vector3(hand.force).length()
			if hand.get("contact_mode","")=="PALM_CONTACT" and Vector3(hand.force).length()>1:palms+=1
	candidate=_candidate() if enabled else {"eligible":false,"path_reason":"FEATURE_DISABLED"}
	var upward:bool=enabled and controller.intent_locomotion.requested.y>.01
	var active:bool=handoff_enabled and upward and candidate.get("eligible",false) and not hands.is_empty()
	var top_ground:bool=ground.grounded and is_instance_valid(ground.support_body) and ground.support_body.get_instance_id()==int(candidate.get("support_id",0))
	# Keep material identity once genuinely identified, including after hand release.
	if enabled and level.get("platform")!=null:top_ground=ground.grounded and ground.support_body==level.platform
	var suspended:bool=not ground.grounded and not hands.is_empty() and load>body.mass*9.8*.5
	suspended_run=suspended_run+delta if suspended else 0.0
	if suspended_run>=.2:had_hanging_start=true
	var near_lip:bool=candidate.has("point") and absf(body.global_position.y-Vector3(candidate.point).y)<.9
	var desired_flex:=1.0 if active and near_lip and not top_ground else 0.0
	legs.request_flex(desired_flex)
	var previous:float=legs.achieved_flex
	var leg_data:Dictionary=legs.step(delta,enabled and adaptive_enabled,_lower_load(delta))
	if absf(previous-legs.achieved_flex)>.000001 and controller.feet_solver!=null:
		for foot in controller.feet_solver.feet:
			if Vector3(foot.force).length()<=1:controller.feet_solver._release(foot,"COLLIDER_POSE_CHANGED")
	# Contact force requests at obsolete lower-body poses are never retained.
	var guarded:Array[Vector3]=[]
	if enabled and adaptive_enabled:
		var shift:Vector3=sole.position-controller.tuning.foot_base_offset
		for id in 2:
			guarded.append(body.global_transform*(controller.feet_solver._rest[id]+shift))
	if controller.feet_solver!=null:controller.feet_solver.collision_pose_guard=guarded
	body.set_meta("mantle_v08_request",{"enabled":active,"inward":candidate.get("inward",Vector3.ZERO),"phase":phase,"candidate_eligible":candidate.get("eligible",false)})
	var no_hands:bool=controller.hands.all(func(hand):return hand.state in ["FREE","RELEASED"])
	var upright:bool=body.global_basis.y.dot(Vector3.UP)>.94 and body.angular_velocity.length()<.5
	var standing:bool=legs.achieved_flex<.001 and not legs.blocked
	var support_stable:bool=enabled and top_ground and no_hands and upright and standing and had_hanging_start
	stable_time=stable_time+delta if support_stable else 0.0
	var material_position:=Vector3.ZERO
	var material_id:=0
	if top_ground:
		material_position=ground.support_body.to_local(body.global_position)
		material_id=ground.support_body.get_instance_id()
	if stable_time>=.3 and material_id==previous_walk_support:
		if ground.walking:ground_distance+=(ground.support_body.global_basis*(material_position-walk_previous)).slide(Vector3.UP).length()
	elif not completed:ground_distance=0.0
	walk_previous=material_position
	previous_walk_support=material_id
	completed=completed or support_stable and ground_distance>=.3
	phase="NONE" if not enabled else "COMPLETE" if completed else "STAND_RECOVERY" if top_ground else "PALM_SUPPORT" if palms>0 else "PALM_TRANSFER" if controller.hands.any(func(hand):return hand.state=="REACHING") and not hands.is_empty() else "EDGE_PULL" if active else "LEDGE_CANDIDATE" if candidate.get("eligible",false) else "ABORTED" if hands.is_empty() and had_hanging_start else "NONE"
	if phase!=last_phase:
		events.append({"time":controller.simulation_time,"phase":phase,"reason":candidate.get("path_reason","")})
		last_phase=phase
	data={"enabled":enabled,"phase":phase,"candidate":candidate.duplicate(true),"leg_collision":leg_data,"actual_hand_ids":hands,"actual_palms_loaded":palms,"actual_top_ground":top_ground,"hands_released":no_hands,"standing_shape_restored":standing,"had_valid_hanging_start":had_hanging_start,"ground_stable_s":stable_time,"ground_walk_distance":ground_distance,"functional_completion":completed,"failure_reason":"" if completed else "PATH_NOT_CERTIFIED" if active else candidate.get("path_reason",""),"body_origin_height":body.global_position.y,"events":events.duplicate(true)}
