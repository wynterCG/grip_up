extends RefCounted
## Adapted directly from physics_grabber.gd: point velocity, rotational effective
## mass and implicit denominator. The 3D spring becomes an axial tension spring.
static func point_velocity(body: RigidBody3D, world_point: Vector3) -> Vector3:
	var center: Vector3 = body.global_transform * body.center_of_mass
	return body.linear_velocity + body.angular_velocity.cross(world_point - center)

static func inverse_effective_mass(body: RigidBody3D, world_point: Vector3, direction: Vector3) -> float:
	var center: Vector3 = body.global_transform * body.center_of_mass
	var lever: Vector3 = world_point - center
	var inverse_inertia: Basis = body.get_inverse_inertia_tensor()
	return 1.0 / body.mass + direction.dot((inverse_inertia * lever.cross(direction)).cross(lever))

static func tension(length_error: float, relative_speed: float, stiffness: float, damping: float, inverse_mass: float, delta: float) -> float:
	if length_error < -0.02:
		return 0.0
	var raw: float = stiffness * maxf(0.0, length_error) - damping * relative_speed
	var denominator: float = 1.0 + (damping * delta + stiffness * delta * delta) * inverse_mass
	return maxf(0.0, raw / denominator)

static func evaluate(torso: RigidBody3D, shoulder: Vector3, anchor, rest_length: float, stiffness: float, damping: float, max_error: float, delta: float) -> Dictionary:
	var anchor_point: Vector3 = anchor.world_point()
	var separation: Vector3 = anchor_point - shoulder
	var length: float = separation.length()
	var axis: Vector3 = separation / maxf(length, 0.000001)
	var relative_speed: float = (point_velocity(torso, shoulder) - anchor.point_velocity()).dot(axis)
	var inverse_mass: float = inverse_effective_mass(torso, shoulder, axis)
	var support: PhysicsBody3D = anchor.support_body()
	if support is RigidBody3D:
		inverse_mass += inverse_effective_mass(support, anchor_point, -axis)
	var error: float = clampf(length - rest_length, -max_error, max_error)
	return {"length": length, "axis": axis, "relative_speed": relative_speed,
		"error": error, "tension": tension(error, relative_speed, stiffness, damping, inverse_mass, delta)}
