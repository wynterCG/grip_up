extends RefCounted
## Current contact authorizes attachment; forecasts are never consulted here.
const Actuator = preload("res://features/grip_up/scripts/arm_actuator.gd")

func evaluate(controller: Node, id: int) -> Dictionary:
	var hand: Dictionary = controller.hands[id]
	var anchor = hand.anchor
	var result := {"accepted":false,"reason":"support_invalidated","relative_speed":0.0,"radial_speed":0.0,"load_risk":false}
	if anchor==null or not anchor.is_valid():
		return result
	var point: Vector3 = anchor.world_point()
	var shoulder: Vector3 = controller.get_shoulder_world(id)
	var distance := shoulder.distance_to(point)
	if distance>controller.get_max_reach()+0.00005:
		result.reason = "out_of_reach"
		return result
	if Vector3(hand.hand_world).distance_to(point)>0.001:
		result.reason = "hand_not_at_contact"
		return result
	var normal: Vector3 = anchor.world_normal()
	var query := PhysicsRayQueryParameters3D.create(point+normal*0.012,point-normal*0.012,controller.tuning.allowed_grip_surface_mask,[controller.torso.get_rid()])
	var hit: Dictionary = controller.torso.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider!=anchor.support_body() or hit.position.distance_to(point)>0.003 or hit.normal.dot(normal)<0.3:
		result.reason = "surface_contact_missing"
		return result
	if not controller._accessible(shoulder,point,normal,anchor.support_body()):
		result.reason = "surface_obstructed"
		return result
	var relative: Vector3 = Actuator.point_velocity(controller.torso,shoulder)-anchor.point_velocity()
	var axis := (point-shoulder).normalized()
	var outward := maxf(0.0,-relative.dot(axis))
	var inverse_mass: float = Actuator.inverse_effective_mass(controller.torso,shoulder,axis)
	var support: PhysicsBody3D = anchor.support_body()
	if support is RigidBody3D:
		inverse_mass += Actuator.inverse_effective_mass(support,point,-axis)
	var remaining: float = maxf(0.0,controller.tuning.max_arm_length+controller.tuning.max_elastic_extension-distance)
	var energy := 0.5*outward*outward/maxf(0.0001,inverse_mass)
	var work: float = controller.tuning.total_pull_force_budget*remaining
	result.merge({"accepted":true,"reason":"contact_valid","relative_speed":relative.length(),"radial_speed":-relative.dot(axis),
		"load_risk":energy>work,"stopping_energy":energy,"available_work_upper_bound":work},true)
	return result
