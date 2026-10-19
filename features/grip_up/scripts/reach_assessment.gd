extends RefCounted
## Optional advisory. Existing contact/reach checks remain the only authority.
## Reuses the tested predictor's constant-force/rotation short-horizon model.
const STEP := 1.0/120.0

func inverse_point_mass(body: RigidBody3D, point: Vector3, axis: Vector3) -> float:
	var center: Vector3=body.global_transform*body.center_of_mass
	var state:=PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state!=null:center=body.global_position+state.center_of_mass
	var lever:=point-center
	return 1.0/maxf(.001,body.mass)+axis.dot((body.get_inverse_inertia_tensor()*lever.cross(axis)).cross(lever))

func point_velocity_at(body: PhysicsBody3D, motion: Dictionary, pose: Transform3D, point: Vector3, time: float, accelerate: bool) -> Vector3:
	if body is StaticBody3D:
		return body.constant_linear_velocity+body.constant_angular_velocity.cross(point-body.global_position)
	var velocity: Vector3=motion.velocity
	if accelerate:
		velocity+=Vector3(motion.gravity)*time+Vector3(motion.arm_acceleration)*minf(time,motion.known_force_time)
	var center: Vector3=pose*Vector3(motion.com_local)
	return velocity+Vector3(motion.spin).cross(point-center)

func evaluate(controller: Node,id: int,support: PhysicsBody3D,point: Vector3,normal: Vector3) -> Dictionary:
	if not is_instance_valid(support) or id not in [0,1]:
		return {"classification":"UNAVAILABLE","reason":"invalid_hand_or_support","authorization":false}
	if controller.get_hand_state(id) not in ["FREE","RELEASED"]:
		return {"classification":"HAND BUSY","reason":"new_press_requires_free_hand","authorization":false}
	var predictor=controller.capture_predictor
	var result: Dictionary=predictor.evaluate(controller,id,support,point,normal).duplicate(true)
	result.authorization=false
	result.requires_actual_contact=true
	result.classification="IN RANGE" if result.get("reachable_now",false) else "NEEDS SWING"
	result.confidence="short_horizon_estimate"
	result.contact_relative_velocity=null
	result.timing_certified=false
	result.window_intervals=[]
	if result.get("reason")=="surface_obstructed":
		result.classification="OBSTRUCTED"
		return result
	if not result.has("horizon"):
		result.classification="UNAVAILABLE"
		return result
	var body: RigidBody3D=controller.torso
	var body_motion: Dictionary=predictor._motion(body)
	var target_motion: Dictionary=predictor._motion(support)
	var force:=Vector3.ZERO
	for hand in 2:force+=controller.get_arm_force(hand)
	body_motion.arm_acceleration=force/maxf(.001,body.mass)
	body_motion.known_force_time=result.horizon
	var telemetry: Dictionary=controller.telemetry()
	if telemetry.get("launch_state")=="PULLING":
		var duration: float=lerpf(.10,controller.tuning.launch_duration,telemetry.get("launch_charge",0.0))
		body_motion.known_force_time=maxf(0.0,duration-telemetry.get("launch_elapsed",0.0))
	var shoulder_local: Vector3=controller.tuning.shoulder_left if id==0 else controller.tuning.shoulder_right
	var local_point: Vector3=support.to_local(point)
	var horizon: float=result.horizon
	var count: int=maxi(1,ceili(horizon/STEP))
	var opened:=-1.0
	var last_inside:=-1.0
	for index in count+1:
		var time: float=float(index)*horizon/count
		var body_pose: Transform3D=predictor._pose_at(body_motion,time,true)
		var target_pose: Transform3D=predictor._pose_at(target_motion,time,false)
		var inside: bool=(body_pose*shoulder_local).distance_to(target_pose*local_point)<=controller.get_max_reach()+.00005
		if inside and opened<0:opened=time
		elif not inside and opened>=0:
			result.window_intervals.append({"entry":opened,"exit":last_inside,"clipped":false})
			opened=-1.0
		if inside:last_inside=time
	if opened>=0:result.window_intervals.append({"entry":opened,"exit":horizon,"clipped":true})
	result.window_scope="predicted anatomical sphere; current LOS/path only; future contacts unmodelled"
	result.window_sample_resolution=horizon/count
	result.current_distance_hand_time=controller.get_hand_world(id).distance_to(point)/maxf(.001,controller.tuning.hand_reach_speed)
	result.arrival_outside_horizon=result.predicted_contact_time<0 and result.current_distance_hand_time>horizon
	if support is RigidBody3D and not support.freeze:
		result.confidence="low_dynamic_constraints_unmodelled"
		if support.angular_velocity.length()*horizon>.15:result.confidence="low_rotating_support"
	elif controller.grounded_for_walking:
		result.confidence="low_ground_contacts_unmodelled"
	elif body.angular_velocity.length()*horizon>.15:
		result.confidence="low_body_rotation_unmodelled"
	elif not controller._attached_ids().is_empty():
		result.confidence="low_supported_dynamics_unmodelled"
	result.predicted_support_angle=Vector3(target_motion.spin).length()*horizon
	if result.get("status")=="SOON":
		if result.get("arrival_feasible",false) and result.predicted_contact_time>=0:
			result.classification="PREDICTED CATCH WINDOW"
		else:result.advisory_reason="geometric_window_only; finite_hand_arrival_unknown"
	if result.get("prediction_reason")=="predicted_hand_path_obstructed":result.classification="OBSTRUCTED"
	elif result.get("prediction_reason")=="predicted_hand_path_out_of_reach" and result.reachable_now:
		result.classification="UNSAFE CATCH"
		result.risk_reason="predicted_hand_path_left_reach_estimate"
	var arrival: float=result.predicted_contact_time
	if arrival>=0:
		var body_pose: Transform3D=predictor._pose_at(body_motion,arrival,true)
		var target_pose: Transform3D=predictor._pose_at(target_motion,arrival,false)
		var future_shoulder: Vector3=body_pose*shoulder_local
		var target: Vector3=target_pose*local_point
		result.contact_relative_velocity=point_velocity_at(body,body_motion,body_pose,future_shoulder,arrival,true)-point_velocity_at(support,target_motion,target_pose,target,arrival,false)
		result.timing_certified=false # Prediction is never a physical guarantee.
	var shoulder: Vector3=controller.get_shoulder_world(id)
	var axis: Vector3=(point-shoulder).normalized()
	var inverse_mass: float=inverse_point_mass(body,shoulder,axis)
	if support is RigidBody3D and not support.freeze:inverse_mass+=inverse_point_mass(support,point,-axis)
	var effective_mass: float=1.0/maxf(.000001,inverse_mass)
	var separating_speed: float=maxf(0.0,result.radial_speed)
	var stopping_distance: float=maxf(0.0,controller.tuning.max_arm_length+controller.tuning.max_elastic_extension-result.distance)
	var capacity: float=minf(controller.tuning.total_pull_force_budget,float(support.get_meta("grip_load_limit",controller.tuning.grip_force_limit)))
	var kinetic: float=.5*effective_mass*separating_speed*separating_speed
	var work_upper: float=capacity*stopping_distance
	result.catch_load_estimate={"effective_point_mass":effective_mass,"outward_speed":separating_speed,"outward_energy":kinetic,"remaining_extension":stopping_distance,"stopping_work_upper_bound":work_upper,"force_upper_bound":capacity,"scope":"instant current-axis estimate; ignores future arm allocation, rotation and contacts; never authorizes or denies"}
	if result.reachable_now and separating_speed>.1 and kinetic>work_upper+.01 and result.classification!="OBSTRUCTED":
		result.classification="UNSAFE CATCH"
		result.risk_reason="estimated_outward_energy_exceeds_stopping_work_upper_bound"
	return result
