extends RefCounted
## Read-only short-horizon UX forecast. This never requests or authorizes a grip.
## NOW means current request geometry is valid, not instantaneous attachment.
## Moving supports use their material-local point and constant COM velocity/spin;
## unknown future constraints/contact impulses are deliberately not fabricated.
const STEP := 1.0/120.0

func evaluate(controller: Node, id: int, support: PhysicsBody3D, world_point: Vector3, normal: Vector3) -> Dictionary:
	var result := {"status":"UNAVAILABLE","reason":"invalid_hand_or_support","prediction_reason":"not_evaluated", "predicted_contact_time":-1.0,"predicted_entry_time":-1.0,"distance":-1.0,"predicted_distance":-1.0,"relative_speed":0.0,"radial_speed":0.0,"reachable_now":false,"arrival_feasible":false,"predicted_target":world_point,"predicted_target_time":0.0,"target_velocity":Vector3.ZERO,"shoulder_velocity":Vector3.ZERO,"authorization":false,"confidence":"short_horizon_estimate"}
	if not is_instance_valid(controller) or not is_instance_valid(support) or id<0 or id>=controller.hands.size():
		return result
	var torso: RigidBody3D = controller.torso
	if not is_instance_valid(torso) or not torso.is_inside_tree() or not support.is_inside_tree() or support==torso:
		return result
	if not support is StaticBody3D and not support is RigidBody3D:
		result.reason = "unsupported_body_type"
		return result
	if not bool(support.get_meta("grippable",true)):
		result.reason = "surface_not_grippable"
		return result
	if not world_point.is_finite() or not normal.is_finite() or normal.length_squared()<0.5:
		result.reason = "invalid_surface_point"
		return result
	if controller.get_hand_state(id) in ["ATTACHED","SLIPPING"]:
		result.reason = "release_hand_before_regrip"
		return result
	var shoulder: Vector3 = controller.get_shoulder_world(id)
	var reach: float = controller.get_max_reach()
	var distance := shoulder.distance_to(world_point)
	result.distance = distance
	result.reachable_now = distance<=reach+0.00005
	var horizon := 0.20
	var configured = controller.tuning.get("capture_prediction_horizon")
	if configured is float or configured is int:
		horizon = clampf(float(configured),0.10,0.25)
	result["horizon"] = horizon
	var local_point := support.to_local(world_point)
	var local_normal := support.global_basis.transposed()*normal.normalized()
	result["local_point"] = local_point
	var torso_motion := _motion(torso)
	var support_motion := _motion(support)
	var torso_force := Vector3.ZERO
	for hand in controller.hands.size():
		torso_force += controller.get_arm_force(hand)
	torso_motion["arm_acceleration"] = torso_force/maxf(torso.mass,0.001)
	var known_force_time := horizon
	var telemetry: Dictionary = controller.telemetry()
	if telemetry.get("launch_state","")=="PULLING":
		var duration: float = lerpf(0.10,controller.tuning.launch_duration,float(telemetry.get("launch_charge",0.0)))
		known_force_time = maxf(0.0,duration-float(telemetry.get("launch_elapsed",0.0)))
	torso_motion["known_force_time"] = known_force_time
	# A conveyor's constant velocity affects contact, but does not translate its
	# collider. Only dynamic bodies have an extrapolated geometric trajectory.
	var target_velocity := _point_velocity(support,support_motion,world_point)
	var shoulder_velocity := _point_velocity(torso,torso_motion,shoulder)
	var relative := shoulder_velocity-target_velocity
	result.target_velocity = target_velocity
	result.shoulder_velocity = shoulder_velocity
	result.relative_speed = relative.length()
	result.radial_speed = relative.dot((shoulder-world_point).normalized())
	if not _visible(controller,shoulder,world_point,normal.normalized(),support):
		result.reason = "surface_obstructed"
		return result
	result.status = "NOW" if result.reachable_now else "UNAVAILABLE"
	result.reason = "reachable_now" if result.reachable_now else "out_of_reach"
	var forecast := _forecast(controller,id,support,local_point,local_normal,torso_motion,support_motion,reach,horizon)
	for key in forecast:
		result[key] = forecast[key]
	if not result.reachable_now and result.predicted_entry_time>=0:
		result.status = "SOON"
		result.reason = "predicted_reach_window"
	# A short forecast must not deny a valid legacy request merely because the
	# finite hand needs longer than the bounded horizon to complete its path.
	return result

func _motion(body: PhysicsBody3D) -> Dictionary:
	var pose := body.global_transform
	var motion := {"pose":pose,"center":pose.origin,"com_local":Vector3.ZERO,"velocity":Vector3.ZERO,"spin":Vector3.ZERO,"gravity":Vector3.ZERO,"arm_acceleration":Vector3.ZERO,"known_force_time":0.0,"dynamic":false}
	if body is RigidBody3D and not body.freeze:
		motion.dynamic = true
		motion.velocity = body.linear_velocity
		motion.spin = body.angular_velocity
		var state := PhysicsServer3D.body_get_direct_state(body.get_rid())
		if state!=null:
			# center_of_mass is an oriented world-space OFFSET from body origin;
			# center_of_mass_local would instead need the full body transform.
			motion.center = pose.origin+state.center_of_mass
			motion.gravity = state.total_gravity
		else:
			motion.center = pose*body.center_of_mass
			motion.gravity = Vector3.DOWN*9.8*body.gravity_scale
		motion.com_local = pose.affine_inverse()*Vector3(motion.center)
	return motion

func _point_velocity(body: PhysicsBody3D, motion: Dictionary, point: Vector3) -> Vector3:
	if body is StaticBody3D:
		return body.constant_linear_velocity+body.constant_angular_velocity.cross(point-body.global_position)
	return motion.velocity+Vector3(motion.spin).cross(point-Vector3(motion.center))

func _pose_at(motion: Dictionary, time: float, include_acceleration: bool) -> Transform3D:
	var pose: Transform3D = motion.pose
	if not motion.dynamic:
		return pose
	var spin: Vector3 = motion.spin
	var rotation := Basis.IDENTITY
	if spin.length_squared()>0.000001:
		rotation = Basis(spin.normalized(),spin.length()*time)
	var basis := rotation*pose.basis
	var center: Vector3 = motion.center+Vector3(motion.velocity)*time
	if include_acceleration:
		center += Vector3(motion.gravity)*(0.5*time*time)
		var force_time: float = minf(time,motion.known_force_time)
		center += Vector3(motion.arm_acceleration)*(0.5*force_time*force_time+force_time*(time-force_time))
	return Transform3D(basis,center-basis*Vector3(motion.com_local))

func _visible(controller: Node, from: Vector3, point: Vector3, normal: Vector3, support: PhysicsBody3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from,point+(point-from).normalized()*0.025)
	query.collision_mask = controller.tuning.allowed_grip_surface_mask
	query.exclude = [controller.torso.get_rid()]
	query.hit_from_inside = true
	var hit: Dictionary = controller.torso.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider==support and hit.position.distance_to(point)<=0.06 and hit.normal.dot(normal)>0.3

func _forecast(controller: Node, id: int, support: PhysicsBody3D, local_point: Vector3, local_normal: Vector3, torso_motion: Dictionary, support_motion: Dictionary, reach: float, horizon: float) -> Dictionary:
	var result := {"prediction_reason":"no_reach_window_in_horizon","predicted_entry_time":-1.0,"predicted_contact_time":-1.0,"arrival_feasible":false,"predicted_distance":INF}
	var hand: Dictionary = controller.hands[id]
	var endpoint: Vector3 = controller.get_hand_world(id)
	var shoulder_local: Vector3 = controller.tuning.shoulder_left if id==0 else controller.tuning.shoulder_right
	var already_reaching: bool = controller.get_hand_state(id)=="REACHING"
	var phase := 1 if not already_reaching or hand.get("approaching_surface",true) else 2
	if hand.get("departing_surface",false) or (hand.get("release_normal",Vector3.ZERO).length_squared()>0.5 and endpoint.distance_to(hand["anchor_world"])<0.015):
		phase = 0
	var departure: Vector3 = hand.get("departure_world",endpoint) if already_reaching else endpoint+Vector3(hand.get("release_normal",Vector3.ZERO))*controller.tuning.hand_surface_approach_distance
	var steps := maxi(1,ceili(horizon/STEP))
	var dt := horizon/steps
	for index in steps+1:
		var time := minf(horizon,index*dt)
		var body_pose := _pose_at(torso_motion,time,true)
		var support_pose := _pose_at(support_motion,time,false)
		var shoulder := body_pose*shoulder_local
		var point := support_pose*local_point
		var normal := (support_pose.basis.inverse().transposed()*local_normal).normalized()
		var distance := shoulder.distance_to(point)
		result.predicted_distance = minf(result.predicted_distance,distance)
		result["predicted_target"] = point
		result["predicted_target_time"] = time
		var reachable := distance<=reach+0.00005
		if reachable and result.predicted_entry_time<0:
			result.predicted_entry_time = time
			result.prediction_reason = "contact_beyond_horizon"
		if index==0:
			continue
		var destination := point
		if not reachable:
			# Anticipatory reach is still finite and anatomically clamped. This is
			# only a prediction of the pending gesture, never an actual hand write.
			destination = shoulder+(point-shoulder).limit_length(reach)
		elif phase==0:
			destination = departure
		elif phase==1:
			var offset := point-shoulder
			var projection := offset.dot(normal)
			var clearance := -projection+sqrt(maxf(0.0,projection*projection+reach*reach-offset.length_squared()))
			destination += normal*minf(controller.tuning.hand_surface_approach_distance,maxf(0.0,clearance))
		var next := endpoint.move_toward(destination,controller.tuning.hand_reach_speed*dt)
		if shoulder.distance_to(next)>reach+0.00005:
			result.prediction_reason = "predicted_hand_path_out_of_reach"
			return result
		var query := PhysicsRayQueryParameters3D.create(endpoint,next)
		query.collision_mask = controller.tuning.allowed_grip_surface_mask
		query.exclude = [controller.torso.get_rid(),support.get_rid()]
		query.hit_from_inside = phase!=0
		var hit: Dictionary = controller.torso.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			result.prediction_reason = "predicted_hand_path_obstructed"
			return result
		endpoint = next
		if reachable and phase==0 and endpoint.distance_to(destination)<0.001:
			phase = 1
		elif reachable and phase==1 and endpoint.distance_to(destination)<0.001:
			phase = 2
		elif reachable and phase==2 and endpoint.distance_to(point)<=0.000001:
			result.predicted_contact_time = time
			result.arrival_feasible = true
			result.prediction_reason = "predicted_contact"
			return result
	return result
