extends RefCounted
## Remembered material point and finite swept gesture. Never an arm constraint.
## M2: real moving workspace/obstruction recovery; attachment remains disabled.
var anchor: RefCounted
var held := true
var active := true
var selected_time := 0.0
var target_selection_id := 0
var previous_frame := Transform3D.IDENTITY
var snapshot: Dictionary = {}
var phase := "APPROACH"
var departure_world := Vector3.ZERO
var departure_normal := Vector3.ZERO
var _label_inside := false
var _physical_inside := false
var _retraction_used := false

func configure(material_anchor: RefCounted, frame: Transform3D, endpoint: Vector3, time: float, serial: int, reach: float, journal_attempt: int = -1) -> void:
	anchor = material_anchor
	previous_frame = frame
	selected_time = time
	target_selection_id = serial
	var point: Vector3 = anchor.world_point()
	var distance := frame.origin.distance_to(point)
	_label_inside = distance<=reach+.00005
	_physical_inside = _label_inside
	snapshot = {"active":true,"held":true,"attempt_id":journal_attempt,"target_selection_id":serial,"selected_time":time,
		"substate":"REACHING" if _label_inside else "PENDING_OUT_OF_REACH",
		"support_id":anchor.support_body().get_instance_id(),"local_point":anchor.local_point,"local_normal":anchor.local_normal,
		"target_world":point,"normal_world":anchor.world_normal(),"shoulder_world":frame.origin,
		"hand_world":endpoint,"hand_goal":frame.origin+(point-frame.origin).limit_length(reach),
		"distance":distance,"reach_margin":reach-distance,"pending_time":0.0,"transition_count":0,
		"blocked":false,"blocker_id":0,"world_speed":0.0,"gesture_speed":0.0,"transport_speed":0.0,
		"world_velocity":Vector3.ZERO,"gesture_velocity":Vector3.ZERO,"transport_velocity":Vector3.ZERO,
		"target_relative_speed":0.0,"workspace_valid":frame.origin.distance_to(endpoint)<=reach+.00005,"endpoint_valid":true,
		"physical_in_reach":_physical_inside,"label_in_reach":_label_inside,"physical_transition_count":0,"phase":phase,
		"reason":"","contact_time":-1.0,"acquisition_load":0.0,"motion_scope":"shoulder-frame transport plus finite relative gesture; full world sweep"}

func cancel(reason: String) -> void:
	active = false
	held = false
	snapshot.active = false
	snapshot.held = false
	snapshot.substate = "CANCELLED"
	snapshot.reason = reason

func set_departure(endpoint: Vector3, normal: Vector3, clearance: float) -> void:
	if normal.length_squared()<.5:return
	phase = "DEPARTURE"
	departure_normal = normal.normalized()
	departure_world = endpoint+departure_normal*clearance

func _sphere_interval(start: Vector3, finish: Vector3, center: Vector3, radius: float) -> Vector2:
	var direction := finish-start
	var offset := start-center
	var a := direction.length_squared()
	var c := offset.length_squared()-radius*radius
	if a<.000000000001:return Vector2(0,1) if c<=.0000001 else Vector2(1,-1)
	var b := 2.0*offset.dot(direction)
	var discriminant := b*b-4.0*a*c
	if discriminant<0.0:return Vector2(1,-1)
	var root := sqrt(discriminant)
	return Vector2(maxf(0.0,(-b-root)/(2.0*a)),minf(1.0,(-b+root)/(2.0*a)))

func _approach_goal(shoulder: Vector3, point: Vector3, normal: Vector3, reach: float, clearance: float) -> Vector3:
	var offset := point-shoulder
	if offset.length()>reach:return shoulder+(offset+normal*clearance).limit_length(reach)
	var projection := offset.dot(normal)
	var allowed := -projection+sqrt(maxf(0.0,projection*projection+reach*reach-offset.length_squared()))
	return point+normal*minf(clearance,maxf(0.0,allowed))

func _sweep(body: RigidBody3D, start: Vector3, finish: Vector3, mask: int) -> Dictionary:
	if start.distance_squared_to(finish)<.000000000001:return {}
	var path := PhysicsRayQueryParameters3D.create(start,finish,mask,[body.get_rid()])
	# Only measured outward departure may leave a quantized released boundary.
	# Other legs reject inside-solid starts; this is not a through-surface ray.
	path.hit_from_inside = not (phase=="DEPARTURE" and (finish-start).normalized().dot(departure_normal)>.5)
	return body.get_world_3d().direct_space_state.intersect_ray(path)

func step(body: RigidBody3D, frame: Transform3D, endpoint: Vector3, reach: float, speed: float, mask: int, time: float, delta: float, clearance: float, minimum_length: float, hysteresis: float) -> Vector3:
	var point: Vector3 = anchor.world_point()
	var normal: Vector3 = anchor.world_normal()
	var shoulder := frame.origin
	var distance := shoulder.distance_to(point)
	var inside := distance<=reach+.00005
	if _physical_inside!=inside:snapshot.physical_transition_count += 1
	_physical_inside = inside
	var prior_label := _label_inside
	if _label_inside and distance>reach+hysteresis:_label_inside = false
	elif not _label_inside and distance<reach-hysteresis:_label_inside = true
	if prior_label!=_label_inside:snapshot.transition_count += 1
	var carried: Vector3 = frame*(previous_frame.affine_inverse()*endpoint)
	var destination := _approach_goal(shoulder,point,normal,reach,clearance)
	if phase in ["DEPARTURE","RETRACT"]:
		destination = shoulder+(departure_world-shoulder).limit_length(reach)
	elif phase=="FINAL" and inside:destination = point
	elif not inside:phase = "APPROACH"
	var candidate := carried.move_toward(destination,speed*delta)
	if phase=="APPROACH" and not _retraction_used and not _sweep(body,endpoint,candidate,mask).is_empty():
		# Choose the safe fold before advancing into the flank. Clipping first
		# can leave the endpoint in a corner with no straight retraction route.
		var folded := shoulder+(endpoint-shoulder).normalized()*minf(minimum_length,endpoint.distance_to(shoulder)*.5)
		if _sweep(body,endpoint,folded,mask).is_empty():
			departure_world = folded
			phase = "RETRACT"
			_retraction_used = true
			destination = folded
			candidate = carried.move_toward(destination,speed*delta)
	var transport_velocity := (carried-endpoint)/maxf(.000001,delta)
	var requested_gesture_velocity := (candidate-carried)/maxf(.000001,delta)
	var space := body.get_world_3d().direct_space_state
	var hit: Dictionary = _sweep(body,endpoint,candidate,mask)
	var blocked := not hit.is_empty()
	var blocker_id := 0
	var clear_fraction := 1.0
	if blocked:
		blocker_id = hit.collider.get_instance_id()
		var exact_contact: bool = phase=="FINAL" and hit.collider==anchor.support_body() and Vector3(hit.position).distance_to(point)<=.00001 and candidate.distance_to(point)<=.000001 and Vector3(hit.normal).dot(normal)>.3
		if exact_contact:
			blocked = false
			blocker_id = 0
		else:clear_fraction = clampf((endpoint.distance_to(hit.position)-.0001)/maxf(.000001,endpoint.distance_to(candidate)),0.0,1.0)
	# Intersect the genuinely clear segment with both this tick's anatomical
	# sphere AND finite relative-gesture sphere. No off-segment normal jump.
	var workspace := _sphere_interval(endpoint,candidate,shoulder,reach+.0000005)
	var muscle := _sphere_interval(endpoint,candidate,carried,speed*delta+.0000005)
	var enter := maxf(workspace.x,muscle.x)
	var leave := minf(clear_fraction,minf(workspace.y,muscle.y))
	var valid := enter<=leave and enter<=1.0 and leave>=0.0
	if valid:candidate = endpoint.lerp(candidate,leave)
	else:candidate = endpoint # Historical sample, explicitly not a valid hand pose.
	var sight := PhysicsRayQueryParameters3D.create(shoulder,point+(point-shoulder).normalized()*.025,mask,[body.get_rid()])
	sight.hit_from_inside = true
	var surface: Dictionary = space.intersect_ray(sight)
	var visible: bool = not surface.is_empty() and surface.collider==anchor.support_body() and Vector3(surface.position).distance_to(point)<=.06 and Vector3(surface.normal).dot(normal)>.3
	if not visible:
		blocked = true
		if blocker_id==0 and not surface.is_empty():blocker_id = surface.collider.get_instance_id()
	if valid and not blocked and candidate.distance_to(destination)<=.000001:
		if phase in ["DEPARTURE","RETRACT"]:phase = "APPROACH"
		elif phase=="APPROACH" and inside:phase = "FINAL"
	var reason := "WORKSPACE_SWEEP_CONFLICT" if not valid else "hand_path_blocked" if blocked else "out_of_reach" if not inside else "contact_not_enabled_m2"
	var world_velocity := (candidate-endpoint)/maxf(.000001,delta)
	var gesture_velocity := (candidate-carried)/maxf(.000001,delta)
	var target_velocity: Vector3 = anchor.point_velocity()
	snapshot.merge({"active":active,"held":held,"substate":"PENDING_OBSTRUCTED" if blocked else "REACHING" if _label_inside else "PENDING_OUT_OF_REACH",
		"target_world":point,"normal_world":normal,"shoulder_world":shoulder,"hand_world":candidate,"hand_goal":destination,
		"distance":distance,"reach_margin":reach-distance,"pending_time":time-selected_time,"physical_in_reach":inside,"label_in_reach":_label_inside,"phase":phase,
		"blocked":blocked,"blocker_id":blocker_id,"world_speed":world_velocity.length(),"gesture_speed":gesture_velocity.length(),"transport_speed":transport_velocity.length(),
		"world_velocity":world_velocity,"gesture_velocity":gesture_velocity,"transport_velocity":transport_velocity,
		"requested_gesture_velocity":requested_gesture_velocity,"requested_gesture_speed":requested_gesture_velocity.length(),
		"target_velocity":target_velocity,"target_relative_speed":(world_velocity-target_velocity).length(),"workspace_valid":valid,"endpoint_valid":valid,"reason":reason},true)
	previous_frame = frame
	return candidate

func diagnostics() -> Dictionary:
	return snapshot.duplicate(true)
