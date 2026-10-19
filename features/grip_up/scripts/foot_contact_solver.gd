extends RefCounted
## M2 massless compressive legs: never a joint, a suction constraint or a pose writer.
const Profile = preload("res://features/grip_up/resources/foot_tuning.gd")
const Sampler = preload("res://features/grip_up/scripts/foothold_candidate_sampler.gd")
var body: RigidBody3D
var tuning: Resource
var feet: Array[Dictionary] = []
var _hips: Array[Vector3] = []
var _rest: Array[Vector3] = []
var _lengths: Array[float] = []
var _clearances: Array[float] = []
var _pending: Array[Dictionary] = []
var _committed := true
## v0.8 only: world ankle positions admitted by the current physical proxy pose.
var collision_pose_guard:Array[Vector3]=[]

func configure(torso: RigidBody3D, settings: Resource, hips: Array[Vector3], rest_feet: Array[Vector3], lengths: Array[float], clearances: Array[float]) -> void:
	body = torso
	tuning = settings if settings != null else Profile.new()
	_hips = hips.duplicate()
	_rest = rest_feet.duplicate()
	_lengths = lengths.duplicate()
	_clearances = clearances.duplicate()
	reset()

func reset() -> void:
	_pending.clear()
	_committed = true
	feet.clear()
	for id in mini(_hips.size(), mini(_rest.size(), mini(_lengths.size(), _clearances.size()))):
		feet.append({"id": id, "state": "FREE", "support": null, "local_point": Vector3.ZERO,
			"local_normal": Vector3.UP, "contact_point": Vector3.ZERO,
			"ankle": body.global_transform * _rest[id], "normal": Vector3.UP,
			"normal_force": 0.0, "tangent_force": Vector3.ZERO, "force": Vector3.ZERO,
			"slip": 0.0, "reason": "reset", "rest_length": 0.0, "blend": 0.0, "clock": 0.0})

func set_free_foot_world(id: int, point: Vector3) -> bool:
	if id < 0 or id >= feet.size() or not point.is_finite() or feet[id].state not in ["FREE", "SEARCHING"]:
		return false
	if not Sampler.anatomy(body, tuning, body.global_transform * _hips[id], point, _lengths[id]):
		return false
	feet[id].ankle = point
	return true

func get_foot_world(id: int) -> Vector3:
	return feet[id].ankle if id >= 0 and id < feet.size() else Vector3.ZERO

func get_hip_world(id: int) -> Vector3:
	return body.global_transform * _hips[id] if id >= 0 and id < _hips.size() else Vector3.ZERO

func _release(foot: Dictionary, reason: String) -> void:
	foot.state = "SEARCHING"
	foot.support = null
	foot.reason = reason
	foot.blend = 0.0
	foot.clock = 0.0

static func center_of_mass(target: RigidBody3D) -> Vector3:
	var state := PhysicsServer3D.body_get_direct_state(target.get_rid())
	return target.global_position + state.center_of_mass if state != null else target.global_transform * target.center_of_mass

static func point_velocity(target: PhysicsBody3D, point: Vector3) -> Vector3:
	if target is RigidBody3D:
		return target.linear_velocity + target.angular_velocity.cross(point - center_of_mass(target))
	if target is StaticBody3D:
		return target.constant_linear_velocity + target.constant_angular_velocity.cross(point - target.global_position)
	return Vector3.ZERO

static func inverse_mass(target: RigidBody3D, point: Vector3, axis: Vector3) -> float:
	var lever := point - center_of_mass(target)
	return 1.0 / target.mass + maxf(0.0, axis.dot((target.get_inverse_inertia_tensor() * lever.cross(axis)).cross(lever)))

func prepare(delta: float, contract: float, extend: float, _bias: float, active: bool, allow_new_contacts: bool = true) -> Array[Dictionary]:
	_pending.clear()
	_committed = false
	if not is_instance_valid(body) or not body.is_inside_tree() or delta <= 0.0:
		return _pending
	for id in feet.size():
		var foot := feet[id]
		foot.force = Vector3.ZERO
		foot.normal_force = 0.0
		foot.tangent_force = Vector3.ZERO
		foot.slip = 0.0
		var hip: Vector3 = body.global_transform * _hips[id]
		if not active:
			_release(foot, "inactive")
			foot.state = "FREE"
			continue
		foot.clock += delta
		# Existing contacts may support a hands-free stance. That is distinct
		# from autonomously seeking or completing a new climbing foothold.
		if not allow_new_contacts and foot.state in ["FREE", "SEARCHING", "PLANTING"]:
			_release(foot, "no_climbing_intent")
			foot.state = "FREE"
			continue
		if foot.state in ["FREE", "SEARCHING"]:
			if foot.state == "SEARCHING" and foot.clock < tuning.search_interval:
				continue
			foot.state = "SEARCHING"
			foot.clock = 0.0
			var candidate := Sampler.sample(body, tuning, hip, body.global_transform * _rest[id], foot.ankle, _lengths[id], _clearances[id], id)
			if candidate.is_empty():
				foot.reason = "no_surface"
				continue
			foot.support = candidate.support
			foot.local_point = candidate.support.to_local(candidate.point)
			foot.local_normal = candidate.support.global_basis.transposed() * candidate.normal
			foot.state = "PLANTING"
			foot.reason = "approaching"
			foot.plant_start = foot.ankle
			foot.plant_phase = 0 if candidate.normal.dot(Vector3.UP) > 0.5 else 2
		if not is_instance_valid(foot.support):
			_release(foot, "support_lost")
			continue
		var support: PhysicsBody3D = foot.support
		var point: Vector3 = support.to_global(foot.local_point)
		var normal: Vector3 = (support.global_basis.inverse().transposed() * foot.local_normal).normalized()
		var ankle: Vector3 = point + normal * _clearances[id]
		if id<collision_pose_guard.size():
			var mismatch:Vector3=ankle-collision_pose_guard[id]
			if absf(mismatch.dot(normal))>.005 or mismatch.slide(normal).length()>.08:
				_release(foot,"physical_foot_pose_mismatch")
				continue
		var invalid := Sampler.validate(body, tuning, hip, ankle, _lengths[id], support, point, normal, _clearances[id])
		if invalid != "":
			_release(foot, invalid)
			continue
		foot.contact_point = point
		foot.normal = normal
		if foot.state == "PLANTING":
			# A raised foothold needs a finite step OVER its front edge. A straight
			# ankle diagonal would intersect the riser despite a valid final plant.
			var waypoint: Vector3 = ankle
			if foot.plant_phase == 0:
				waypoint = Vector3(foot.plant_start.x, maxf(foot.plant_start.y, ankle.y + tuning.step_clearance), foot.plant_start.z)
			elif foot.plant_phase == 1:
				waypoint = ankle + Vector3.UP * tuning.step_clearance
			var next: Vector3 = foot.ankle.move_toward(waypoint, tuning.plant_speed * delta)
			if not Sampler.ray(body, foot.ankle, next).is_empty() or not Sampler.anatomy(body, tuning, hip, next, _lengths[id]):
				_release(foot, "foot_path_obstructed")
				continue
			foot.ankle = next
			if foot.plant_phase < 2:
				if next.distance_to(waypoint) <= 0.000001:
					foot.plant_phase += 1
				continue
			if next.distance_to(ankle) > 0.000001:
				continue
			foot.state = "SUPPORTING"
			foot.reason = "contact"
			foot.rest_length = minf(_lengths[id] * 0.999, hip.distance_to(ankle) + tuning.contact_preload)
			foot.blend = 0.0
		else:
			# Material-local contact motion is not an active foot gesture.
			foot.ankle = ankle
		foot.blend = minf(1.0, foot.blend + delta / maxf(0.001, tuning.engagement_time))
		foot.rest_length = clampf(foot.rest_length + (clampf(contract, 0.0, 1.0) * tuning.extension_rate - clampf(extend, 0.0, 1.0) * tuning.lower_rate) * delta, _lengths[id] * tuning.minimum_length_ratio, _lengths[id] * 0.999)
		var separation := hip - ankle
		var length := separation.length()
		var axis := separation / maxf(length, 0.000001)
		var speed := (point_velocity(body, point) - point_velocity(support, point)).dot(axis)
		var inv := inverse_mass(body, point, axis)
		if support is RigidBody3D:
			inv += inverse_mass(support, point, axis)
		# Implicit spring denominator is the proven grabber/arm algorithm, sign reversed
		# for compression. A separated leg cannot brake or pull on its support.
		var error: float = foot.rest_length - length
		var effort := 0.0
		if error >= -0.002:
			effort = maxf(0.0, (tuning.stiffness * maxf(0.0, error) - tuning.damping * speed) / (1.0 + (tuning.damping * delta + tuning.stiffness * delta * delta) * inv))
		effort = minf(effort, tuning.max_force_per_foot) * foot.blend
		var wanted := axis * effort
		var normal_force := maxf(0.0, wanted.dot(normal))
		var tangent := wanted - normal * wanted.dot(normal)
		var friction: float = tuning.foot_friction
		if support is RigidBody3D or support is StaticBody3D:
			if support.physics_material_override != null:
				friction = minf(friction, maxf(0.0, support.physics_material_override.friction))
		var limit := friction * normal_force
		var excess := maxf(0.0, tangent.length() - limit)
		var force := normal * normal_force + tangent.limit_length(limit)
		foot.slip = excess
		foot.state = "SLIDING" if excess > 0.05 else "SUPPORTING"
		foot.reason = "friction_limit" if excess > 0.05 else "contact"
		_pending.append({"id": id, "force": force, "point": point, "support": support})
		if excess > 0.05:
			# Slip opposes the tangential push that the leg cannot transmit. Raycast
			# each new material point; an edge/void loses contact rather than gluing it.
			var slide: Vector3 = -tangent.normalized() * tuning.slip_speed * minf(1.0, excess / maxf(effort, 0.001)) * delta
			var moved := Sampler.ray(body, point + slide + normal * 0.025, point + slide - normal * 0.025)
			if moved.is_empty() or moved.collider != support or moved.normal.dot(normal) < 0.85:
				_release(foot, "slid_off_edge")
				_pending.pop_back()
			else:
				foot.local_point = support.to_local(moved.position)
	var total := 0.0
	for entry in _pending:
		total += entry.force.length()
	var scale := minf(1.0, maxf(0.0, tuning.total_force_budget) / maxf(total, 0.000001))
	for entry in _pending:
		entry.force *= scale
	return _pending

func commit(scale: float) -> void:
	if _committed:
		return
	_committed = true
	var bounded := clampf(scale, 0.0, 1.0) if is_finite(scale) else 0.0
	for entry in _pending:
		var force: Vector3 = entry.force * bounded
		if not is_instance_valid(entry.support) or not entry.support.is_inside_tree():
			continue
		# SAME world point makes the complete pair conserve linear and angular momentum.
		body.apply_force(force, entry.point - body.global_position)
		if entry.support is RigidBody3D and not entry.support.freeze:
			entry.support.apply_force(-force, entry.point - entry.support.global_position)
		var foot := feet[entry.id]
		foot.force = force
		foot.normal_force = maxf(0.0, force.dot(foot.normal))
		foot.tangent_force = force - foot.normal * foot.normal_force
