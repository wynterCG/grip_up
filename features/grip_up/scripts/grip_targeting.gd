extends RefCounted

func candidate(camera: Camera3D, pointer: Vector2, torso: RigidBody3D) -> Dictionary:
	var best: Dictionary = {}
	# Assistance samples real rays; an occluding solid always wins each ray.
	for offset in [Vector2.ZERO, Vector2(12,0), Vector2(-12,0), Vector2(0,12), Vector2(0,-12), Vector2(8,8), Vector2(-8,-8)]:
		var point: Vector2 = pointer + offset
		var origin := camera.project_ray_origin(point)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(point) * 70.0, 3, [torso.get_rid()])
		var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or not hit.collider.get_meta("grippable", false):
			continue
		best = hit
		break
	return best
