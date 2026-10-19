extends RefCounted
## Request-time resolution only. A clicked tangent plane proposes a ray, never
## a contact: the ray must return the same actual collider inside real anatomy.
func resolve(body: RigidBody3D, shoulder: Vector3, material: PhysicsBody3D, clicked: Vector3, clicked_normal: Vector3, reach: float, mask: int) -> Dictionary:
	var result := {"resolved":false,"reason":"clicked_point_already_reachable","original_distance":shoulder.distance_to(clicked),"reach":reach,"blocker_id":0}
	if result.original_distance<=reach:return result
	var normal := clicked_normal.normalized()
	var plane_distance := (clicked-shoulder).dot(normal)
	if absf(plane_distance)>reach:
		result.reason = "clicked_surface_plane_outside_reach"
		return result
	var plane_center := shoulder+normal*plane_distance
	var tangent := clicked-plane_center
	var tangent_radius := sqrt(maxf(0.0,reach*reach-plane_distance*plane_distance))
	var proposed: Vector3 = plane_center+tangent.limit_length(tangent_radius)
	var direction := (proposed-shoulder).normalized()
	if direction.length_squared()<.5:
		result.reason = "degenerate_surface_projection"
		return result
	var query := PhysicsRayQueryParameters3D.create(shoulder,proposed+direction*.025,mask,[body.get_rid()])
	query.hit_from_inside = true
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		result.reason = "no_actual_surface_at_reachable_projection"
		return result
	if hit.collider!=material:
		result.reason = "reachable_projection_obstructed"
		result.blocker_id = hit.collider.get_instance_id()
		return result
	var separation := shoulder.distance_to(hit.position)
	# Float32 ray intersection only: no90percent cushion or extra anatomy.
	if separation>reach+.000001 or Vector3(hit.normal).length_squared()<.5:
		result.reason = "actual_surface_outside_reach"
		return result
	result.merge({"resolved":true,"reason":"same_collider_current_reachable_surface","point":hit.position,"normal":hit.normal,
		"distance":separation,"local_point":material.to_local(hit.position),"proposal_world":proposed},true)
	return result
