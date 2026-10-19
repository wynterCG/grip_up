extends RefCounted
## Queries CURRENT geometry only. A candidate never authorizes a future contact.
static func ray(body: RigidBody3D, from: Vector3, to: Vector3) -> Dictionary:
	if from.distance_squared_to(to) < 0.00000001:
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, body.collision_mask, [body.get_rid()])
	query.hit_from_inside = true
	return body.get_world_3d().direct_space_state.intersect_ray(query)

static func anatomy(body: RigidBody3D, tuning: Resource, hip: Vector3, ankle: Vector3, length: float) -> bool:
	var leg := ankle - hip
	var distance := leg.length()
	if not ankle.is_finite() or distance > length * 0.999 + 0.001 or distance < length * tuning.minimum_length_ratio:
		return false
	return leg.normalized().dot(-body.global_basis.y.normalized()) >= cos(tuning.max_leg_angle)

static func validate(body: RigidBody3D, tuning: Resource, hip: Vector3, ankle: Vector3, length: float, support: PhysicsBody3D, point: Vector3, normal: Vector3, clearance: float) -> String:
	if not is_instance_valid(support) or not support.is_inside_tree() or support.collision_layer & body.collision_mask == 0:
		return "support_lost"
	if not support.get_meta("foot_support", true):
		return "surface_disabled"
	if not anatomy(body, tuning, hip, ankle, length):
		return "leg_reach"
	if normal.length_squared() < 0.5 or normal.dot(hip - point) <= 0.005:
		return "wrong_side"
	var hit := ray(body, point + normal * (clearance + 0.025), point - normal * 0.025)
	if hit.is_empty() or hit.collider != support or hit.position.distance_to(point) > tuning.contact_tolerance or hit.normal.dot(normal) < 0.85:
		return "contact_lost"
	var sight := ray(body, hip, ankle)
	if not sight.is_empty():
		return "leg_obstructed"
	return ""

static func sample(body: RigidBody3D, tuning: Resource, hip: Vector3, rest: Vector3, current: Vector3, length: float, clearance: float, id: int) -> Dictionary:
	var right := body.global_basis.x.normalized()
	var forward := -body.global_basis.z.normalized()
	var side := -1.0 if id == 0 else 1.0
	var best: Dictionary = {}
	var score := INF
	for offset in [0.0, side * 0.16, side * 0.22, side * tuning.lateral_search, -side * 0.16]:
		for advance in [0.0, 0.12, -0.12]:
			var center: Vector3 = rest + right * offset + forward * advance
			var rays: Array = [[center + Vector3.UP * tuning.search_height, center - Vector3.UP * tuning.search_depth],
				[hip + Vector3.DOWN * length * 0.65 + right * offset, hip + Vector3.DOWN * length * 0.65 + right * offset + forward * length]]
			for segment in rays:
				var hit := ray(body, segment[0], segment[1])
				if hit.is_empty() or not hit.collider is PhysicsBody3D:
					continue
				var point: Vector3 = hit.position
				var normal: Vector3 = hit.normal
				var ankle: Vector3 = point + normal * clearance
				if validate(body, tuning, hip, ankle, length, hit.collider, point, normal, clearance) != "":
					continue
				# Prefer an available higher step over remaining on the floor until
				# the leg goes taut. Height is still limited by actual anatomy/queries.
				var cost: float = current.distance_to(ankle) + absf(offset) * 0.12 - maxf(0.0, ankle.y - rest.y) * tuning.step_preference + (1.0 - maxf(0.0, normal.y)) * tuning.bearing_preference
				if cost < score:
					score = cost
					best = {"support": hit.collider, "point": point, "normal": normal, "ankle": ankle}
	return best
