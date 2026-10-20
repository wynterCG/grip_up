extends RefCounted

var audit_enabled := false
var last_audit:Dictionary={}

func candidate(camera: Camera3D, pointer: Vector2, torso: RigidBody3D) -> Dictionary:
	var best: Dictionary = {}
	if audit_enabled:last_audit={"pointer":pointer,"mask":3,"range_m":70.0,"rays":[],"winner":null}
	# Assistance samples real rays; an occluding solid always wins each ray.
	for offset in [Vector2.ZERO, Vector2(12,0), Vector2(-12,0), Vector2(0,12), Vector2(0,-12), Vector2(8,8), Vector2(-8,-8)]:
		var point: Vector2 = pointer + offset
		var origin := camera.project_ray_origin(point)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(point) * 70.0, 3, [torso.get_rid()])
		var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
		if audit_enabled:
			var row:Dictionary={"offset_px":offset,"point_px":point,"origin_m":origin,"direction":camera.project_ray_normal(point),"reason":"MISS" if hit.is_empty() else "INELIGIBLE" if not hit.collider.get_meta("grippable",false) else "SELECTED"}
			if not hit.is_empty():row.merge({"collider_key":str(hit.collider.get_meta("mastery_surface",hit.collider.name)),"collider_runtime_id":hit.collider.get_instance_id(),"local_point_m":hit.collider.to_local(hit.position),"local_normal":hit.collider.global_basis.inverse()*Vector3(hit.normal),"world_point_m":hit.position,"world_normal":hit.normal,"shape":hit.get("shape",null)})
			last_audit.rays.append(row)
			if row.reason=="SELECTED":last_audit.winner=row.duplicate(true)
		if hit.is_empty() or not hit.collider.get_meta("grippable", false):
			continue
		best = hit
		break
	return best
