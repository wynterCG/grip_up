extends Node
const Motor=preload("res://features/grip_up/scripts/mantle_kinematic_motor.gd")
const Detector=preload("res://features/grip_up/scripts/mantle_candidate_detector.gd")
const Route=preload("res://features/grip_up/scripts/hybrid_mantle_route.gd")
const AnimationDriver=preload("res://features/grip_up/scripts/mantle_animation_driver.gd")
var enabled:=false
var contextual_vault_v10_enabled:=false
var state:="DYNAMIC"
var body:RigidBody3D
var controller:Node
var ground:Node
var biped:Node3D
var camera:Camera3D
var motor=Motor.new()
var detector=Detector.new()
var route=Route.new()
var animation_driver:Node
var candidate:Dictionary={}
var data:Dictionary={}
var events:Array=[]
var samples:Array=[]
var commits:=0
var restores:=0
var progress:=0.0
var dwell:=0.0
var blocked_time:=0.0
var restore_time:=0.0
var ground_stable:=0.0
var walk_distance:=0.0
var completed:=false
var walk_previous:=Vector3.ZERO
var walked_support:=0
var last_motion:=Vector3.ZERO
var incoming:Dictionary={}
var grip_rearm:Array[bool]=[false,false]
var request_rearm:=false
var interrupted:=false
var result:=""
var reason:="NO_REAL_GRIP"
var retry_wait:=0.0
var standing_clear_at_restore:=false

func configure(grips:Node,motor_ground:Node,visual:Node3D,view:Camera3D)->void:
	controller=grips
	body=grips.torso
	ground=motor_ground
	biped=visual
	camera=view
	process_physics_priority=-30
	motor.configure(body)
	detector.configure(controller,ground,camera,motor)
	animation_driver=AnimationDriver.new()
	animation_driver.contextual_vault_v10_enabled=contextual_vault_v10_enabled
	add_child(animation_driver)
	animation_driver.configure(biped,body)

func active()->bool:
	return state in ["COMMIT","ASSISTED_TRAVERSE","BLOCKED_RECOVERY","RESTORE_DYNAMIC"]

func allows_grip(id:int)->bool:
	return not active() and not grip_rearm[id]

func transition(next:String,why:String)->void:
	if state==next:return
	events.append({"time":controller.simulation_time,"from":state,"state":next,"reason":why,"progress":progress,"pose":body.global_transform})
	state=next
	reason=why

func focus_lost()->void:
	request_rearm=true
	interrupted=true
	dwell=0
	if active():transition("BLOCKED_RECOVERY","FOCUS_LOST")

func _same_support()->bool:
	var support=instance_from_id(int(candidate.get("support_id",0)))
	return support is StaticBody3D and not support is AnimatableBody3D and support.global_transform.is_equal_approx(candidate.support_transform) and support.constant_linear_velocity.length()<.0001 and support.constant_angular_velocity.length()<.0001

func _hold_invalid_restore_support()->void:
	# end_dynamic already restored the original standing shapes. Freeze the
	# current solved pose, without replaying a route pose, rebuilding geometry,
	# restoring old velocities or restarting the kinematic motor. The material
	# snapshot is invalid, so only explicit reset may relinquish this ownership.
	body.freeze_mode=RigidBody3D.FREEZE_MODE_KINEMATIC
	body.freeze=true
	controller.assisted_motion_owned=true
	ground.assisted_authority_suspended=true
	standing_clear_at_restore=false
	completed=false
	walk_distance=0
	interrupted=true
	blocked_time=.4
	result="BLOCKED / R TO RESTART"
	transition("BLOCKED_RECOVERY","SUPPORT_INVALIDATED")

func _commit()->void:
	if state!="COMMIT" or motor.active or controller.assisted_motion_owned:return
	incoming={"transform":body.global_transform,"linear_velocity":body.linear_velocity,"angular_velocity":body.angular_velocity,"hands":controller.hands.duplicate(true)}
	if contextual_vault_v10_enabled:
		candidate.approach_context={"body_origin_to_lip_height":Vector3(candidate.top_reference_world).y-body.global_position.y,"body_to_face_distance":(body.global_position-Vector3(candidate.top_reference_world)).dot(candidate.outward_world),"linear_velocity_relative_to_static_support":body.linear_velocity,"upward_speed":body.linear_velocity.dot(Vector3.UP),"inward_speed":body.linear_velocity.dot(candidate.inward_world),"angular_velocity":body.angular_velocity,"attached_hand_count":candidate.source_hands.size(),"selected_style":"VAULT_STYLE","style_choice_reason":"Single refined vault experiment; no contextual classifier or second style"}
	animation_driver.begin(candidate)
	controller.retire_for_assisted_motion()
	ground.assisted_authority_suspended=true
	ground.applied_force=Vector3.ZERO
	ground.applied_torque=Vector3.ZERO
	if not motor.begin():
		controller.assisted_motion_owned=false
		ground.assisted_authority_suspended=false
		animation_driver.cancel()
		transition("DYNAMIC","MOTOR_BEGIN_FAILED")
		return
	commits+=1
	progress=0
	blocked_time=0
	restore_time=0
	ground_stable=0
	standing_clear_at_restore=false
	last_motion=Vector3.ZERO
	completed=false
	walk_distance=0
	result=""
	grip_rearm=[true,true]
	transition("ASSISTED_TRAVERSE","COMMITTED")

func _native_ground()->bool:
	if not ground.grounded or not is_instance_valid(ground.support_body) or ground.support_body.get_instance_id()!=int(candidate.get("support_id",0)):return false
	var direct:=PhysicsServer3D.body_get_direct_state(body.get_rid())
	if direct==null:return false
	for index in direct.get_contact_count():
		var shape_index:int=direct.get_contact_local_shape(index)
		if shape_index<0 or shape_index>=PhysicsServer3D.body_get_shape_count(body.get_rid()):continue
		var owner_node:Object=body.shape_owner_get_owner(body.shape_find_owner(shape_index))
		if owner_node!=null and owner_node.name=="FootBase" and direct.get_contact_collider_id(index)==ground.support_body.get_instance_id() and direct.get_contact_impulse(index).dot(Vector3.UP)>.0001:return true
	return false

func _standing_supported_clear()->bool:
	if not standing_clear_at_restore or absf(motor.flex)>.000001:return false
	if motor.standing_clear(body.global_transform).get("clear",false):return true
	if not _native_ground():return false
	var space:=body.get_world_3d().direct_space_state
	for node in body.get_children():
		if not node is CollisionShape3D or node.disabled:continue
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=node.shape
		query.transform=body.global_transform*node.transform
		query.collision_mask=body.collision_mask
		query.exclude=[body.get_rid()]
		query.margin=0
		var hits:=space.intersect_shape(query,16)
		if hits.is_empty():continue
		# Closed-volume ground contact is expected after settling. Only shallow
		# native-supported sole/lower contact qualifies, never torso penetration.
		if node.name not in ["FootBase","LowerCapsule"] or hits.any(func(hit):return hit.collider!=ground.support_body):return false
		var pairs:=space.collide_shape(query,32)
		for index in range(0,pairs.size()-1,2):
			if pairs[index].distance_to(pairs[index+1])>.004:return false
	return true

func _physics_process(delta:float)->void:
	if not enabled:return
	var ui_blocked:bool=get_parent().get_parent().settings.visible
	retry_wait=maxf(0.0,retry_wait-delta)
	if not active():
		for id in 2:
			if not Input.is_action_pressed("grip_left" if id==0 else "grip_right"):grip_rearm[id]=false
	if not Input.is_action_pressed("contract"):
		request_rearm=false
		if not active():interrupted=false
	if state in ["DYNAMIC","PREPARE"]:
		candidate=detector.detect()
		reason=candidate.eligibility_reason
		var request:bool=Input.is_action_pressed("contract") and not request_rearm and retry_wait<=0 and not ui_blocked and not interrupted and controller._launch_state=="IDLE"
		dwell=dwell+delta if request and candidate.eligible else 0.0
		if dwell>=.10:
			transition("PREPARE","VALIDATING_ROUTE")
			route.configure(candidate,motor)
			var clearance:Dictionary=route.preflight(motor)
			candidate.estimated_path_samples=clearance.samples
			candidate.clearance_reason=clearance.reason
			if clearance.clear:
				transition("COMMIT","PATH_VALIDATED")
				_commit()
			else:
				candidate.clearance_detail=clearance
				retry_wait=.25
				dwell=0
				result="REJECTED"
				transition("DYNAMIC",clearance.reason)
				events[-1].detail=clearance.get("detail",{})
				events[-1].blocked_route_segment=clearance.get("segment",0)
	elif state=="ASSISTED_TRAVERSE":
		if ui_blocked:
			_publish()
			return
		if not _same_support():
			transition("BLOCKED_RECOVERY","SUPPORT_INVALIDATED")
		else:
			var next:float=minf(1.0,progress+delta/route.duration)
			var target:Dictionary=route.sample(next)
			var previous:Vector3=body.global_position
			var movement:Dictionary=motor.move_step(target.pose,target.flex,delta)
			if not movement.get("clear",false):
				candidate.runtime_block=movement
				transition("BLOCKED_RECOVERY",movement.get("reason","PATH_BLOCKED"))
			else:
				last_motion=(body.global_position-previous)/delta
				progress=next
				animation_driver.set_collision_pose(target.flex,motor.pose_for(target.flex))
				animation_driver.set_progress(progress,delta)
				if progress>=1.0:
					if motor.end_dynamic(last_motion):
						standing_clear_at_restore=true
						restores+=1
						restore_time=0
						transition("RESTORE_DYNAMIC","ANIMATION_COMPLETE")
					else:transition("BLOCKED_RECOVERY","STANDING_COLLISION_BLOCKED")
	elif state=="RESTORE_DYNAMIC":
		restore_time+=delta
		if contextual_vault_v10_enabled and not _same_support():
			_hold_invalid_restore_support()
		elif _native_ground() and _standing_supported_clear() and body.global_basis.y.dot(Vector3.UP)>.94:
			animation_driver.finish()
			controller.assisted_motion_owned=false
			ground.assisted_authority_suspended=false
			walk_previous=ground.support_body.to_local(body.global_position)
			walked_support=ground.support_body.get_instance_id()
			transition("DYNAMIC_GROUNDED","TOP_GROUND_VALID")
		elif restore_time>.65:transition("BLOCKED_RECOVERY","TOP_GROUND_NOT_CONFIRMED")
	elif state=="DYNAMIC_GROUNDED":
		if not controller._attached_ids().is_empty():
			dwell=0
			request_rearm=false
			completed=false
			walk_distance=0
			progress=0
			result=""
			standing_clear_at_restore=false
			transition("DYNAMIC","NEW_REAL_GRIP")
		if _native_ground() and _standing_supported_clear():
			ground_stable+=delta
			var local:Vector3=ground.support_body.to_local(body.global_position)
			if ground.walking and ground_stable>.10:walk_distance+=(ground.support_body.global_basis*(local-walk_previous)).slide(Vector3.UP).length()
			walk_previous=local
			if walk_distance>=.30:
				completed=true
				result="COMPLETE"
		else:ground_stable=0
	elif state=="BLOCKED_RECOVERY":
		if ui_blocked:
			_publish()
			return
		blocked_time+=delta
		# A transient obstacle may clear. Otherwise keep the last safe physical
		# pose and expose R; never invent an unchecked reverse route or snap.
		if blocked_time<.4 and not interrupted and _same_support() and progress<1 and body.freeze:
			var retry:Dictionary=route.sample(minf(1,progress+delta/route.duration))
			if motor.validate_segment(body.global_transform,retry.pose,route.sample(progress).flex,retry.flex).get("clear",false):transition("ASSISTED_TRAVERSE","OBSTACLE_CLEARED")
		if blocked_time>=.4:result="BLOCKED / R TO RESTART"
	_publish()

func _publish()->void:
	data={"enabled":enabled,"state":state,"progress":progress,"candidate":candidate.duplicate(true),"commits":commits,"restores":restores,"freeze":body.freeze,"freeze_mode":body.freeze_mode,"motor_ownership":"ASSISTED" if controller.assisted_motion_owned else "DYNAMIC","animation_complete":progress>=1,"standing_collision_clear":_standing_supported_clear(),"standing_collision_clear_at_restore":standing_clear_at_restore,"top_ground_valid":_native_ground(),"grips_released":controller._attached_ids().is_empty(),"dynamic_restored":not body.freeze and not controller.assisted_motion_owned,"walk_distance_relative_to_support":walk_distance,"mantle_complete":completed,"result":result,"reason":reason,"body_pose":body.global_transform,"body_velocity":body.linear_velocity,"animation":animation_driver.telemetry(),"events":events.duplicate(true)}
	if active() or state=="DYNAMIC_GROUNDED":samples.append(data.duplicate(true))
