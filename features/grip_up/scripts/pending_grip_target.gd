extends RefCounted
## A remembered material point, never an arm constraint or source of effort.
## M1 only: finite, collision-swept presentation; attachment is a later gate.
var anchor: RefCounted
var held := true
var active := true
var selected_time := 0.0
var attempt_id := 0
var previous_frame := Transform3D.IDENTITY
var snapshot: Dictionary = {}

func configure(material_anchor: RefCounted, frame: Transform3D, endpoint: Vector3, time: float, serial: int, reach: float) -> void:
	anchor = material_anchor
	previous_frame = frame
	selected_time = time
	attempt_id = serial
	var point: Vector3 = anchor.world_point()
	var distance := frame.origin.distance_to(point)
	snapshot = {"active":true,"held":true,"attempt_id":serial,"selected_time":time,
		"substate":"PENDING_OUT_OF_REACH" if distance>reach+.00005 else "REACHING",
		"support_id":anchor.support_body().get_instance_id(),"local_point":anchor.local_point,"local_normal":anchor.local_normal,
		"target_world":point,"normal_world":anchor.world_normal(),"shoulder_world":frame.origin,
		"hand_world":endpoint,"hand_goal":frame.origin+(point-frame.origin).limit_length(reach),
		"distance":distance,"reach_margin":reach-distance,"pending_time":0.0,"transition_count":0,
		"blocked":false,"blocker_id":0,"world_speed":0.0,"gesture_speed":0.0,"transport_speed":0.0,
		"world_velocity":Vector3.ZERO,"gesture_velocity":Vector3.ZERO,"transport_velocity":Vector3.ZERO,
		"target_relative_speed":0.0,"workspace_valid":frame.origin.distance_to(endpoint)<=reach+.00005,
		"reason":"","contact_time":-1.0,"acquisition_load":0.0,"motion_scope":"shoulder-frame transport plus finite relative gesture; full world sweep"}

func cancel(reason: String) -> void:
	active = false
	held = false
	snapshot.active = false
	snapshot.held = false
	snapshot.substate = "CANCELLED"
	snapshot.reason = reason

func step(body: RigidBody3D, frame: Transform3D, endpoint: Vector3, reach: float, speed: float, mask: int, time: float, delta: float) -> Vector3:
	var point: Vector3 = anchor.world_point()
	var normal: Vector3 = anchor.world_normal()
	var shoulder := frame.origin
	var distance := shoulder.distance_to(point)
	var prior_inside: bool = float(snapshot.reach_margin)>=0.0
	var inside := distance<=reach+.00005
	if prior_inside!=inside:snapshot.transition_count += 1
	var carried: Vector3 = frame*(previous_frame.affine_inverse()*endpoint)
	var destination := shoulder+(point-shoulder).limit_length(reach)
	var candidate := carried.move_toward(destination,speed*delta)
	var transport_velocity := (carried-endpoint)/maxf(.000001,delta)
	var requested_gesture_velocity := (candidate-carried)/maxf(.000001,delta)
	var space := body.get_world_3d().direct_space_state
	var path := PhysicsRayQueryParameters3D.create(endpoint,candidate,mask,[body.get_rid()])
	path.hit_from_inside = true
	var hit: Dictionary = space.intersect_ray(path) if endpoint.distance_squared_to(candidate)>.000000000001 else {}
	var blocked := not hit.is_empty()
	var blocker_id := 0
	if blocked:
		blocker_id = hit.collider.get_instance_id()
		# Stop on the original swept segment. A normal offset can silently add
		# speed or push a hand outside its anatomical sphere.
		var displacement := candidate-endpoint
		candidate = endpoint+displacement.normalized()*maxf(0.0,endpoint.distance_to(hit.position)-.0001)
	var sight := PhysicsRayQueryParameters3D.create(shoulder,point+(point-shoulder).normalized()*.025,mask,[body.get_rid()])
	sight.hit_from_inside = true
	var surface: Dictionary = space.intersect_ray(sight)
	var visible: bool = not surface.is_empty() and surface.collider==anchor.support_body() and Vector3(surface.position).distance_to(point)<=.06 and Vector3(surface.normal).dot(normal)>.3
	if not visible:
		blocked = true
		if blocker_id==0 and not surface.is_empty():blocker_id = surface.collider.get_instance_id()
	var valid := shoulder.distance_to(candidate)<=reach+.00005
	var reason := "workspace_sweep_conflict" if not valid else "hand_path_blocked" if blocked else "out_of_reach" if not inside else "contact_not_enabled_m1"
	var world_velocity := (candidate-endpoint)/maxf(.000001,delta)
	var gesture_velocity := (candidate-carried)/maxf(.000001,delta)
	# The requested muscle gesture remains capped even when collision clips
	# shoulder transport. Report both, rather than hiding correction as motion.
	snapshot.merge({"active":active,"held":held,"substate":"PENDING_OBSTRUCTED" if blocked else "REACHING" if inside else "PENDING_OUT_OF_REACH",
		"target_world":point,"normal_world":normal,"shoulder_world":shoulder,"hand_world":candidate,"hand_goal":destination,
		"distance":distance,"reach_margin":reach-distance,"pending_time":time-selected_time,
		"blocked":blocked,"blocker_id":blocker_id,"world_speed":world_velocity.length(),"gesture_speed":gesture_velocity.length(),"transport_speed":transport_velocity.length(),
		"world_velocity":world_velocity,"gesture_velocity":gesture_velocity,"transport_velocity":transport_velocity,
		"requested_gesture_velocity":requested_gesture_velocity,"requested_gesture_speed":requested_gesture_velocity.length(),
		"target_relative_speed":(world_velocity-anchor.point_velocity()).length(),"workspace_valid":valid,"reason":reason},true)
	previous_frame = frame
	return candidate

func diagnostics() -> Dictionary:
	return snapshot.duplicate(true)
