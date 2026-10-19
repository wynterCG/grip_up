extends RefCounted
## Absolute material-anchor plans, never current-height increments. Cached plans
## survive release/regrip so revisiting a support cannot earn another upward step.
var cache: Dictionary = {}
var events := 0

func reset() -> void:
	cache.clear()
	events = 0

func signature(controller: Node, ids: Array[int], policy: int) -> String:
	var result := str(policy)
	for id in ids:
		var anchor = controller.hands[id]["anchor"]
		result += "|%d:%d:%s" % [id,anchor.support_body().get_instance_id(),str(anchor.local_point.snapped(Vector3.ONE*.004))]
	return result

func build(controller: Node, ids: Array[int], policy: int) -> Dictionary:
	var key := signature(controller,ids,policy)
	events += 1
	if cache.has(key):
		var cached: Dictionary = cache[key].duplicate(true)
		cached.event = events
		cached.reason = "material_configuration_revisited"
		refresh(cached)
		return cached
	var tuning: Resource = controller.tuning
	var out := Vector3.ZERO
	for id in ids:
		out += controller.hands[id]["anchor"].world_normal().slide(Vector3.UP)
	if out.length_squared()<.0001:
		out = controller.hands[ids[0]]["anchor"].support_body().global_basis.z.slide(Vector3.UP)
	if out.length_squared()<.0001:
		out = Vector3.BACK
	out = out.normalized()
	var frame := Basis(Vector3.UP.cross(out).normalized(),Vector3.UP,out)
	var comfortable: float = lerpf(tuning.min_arm_length,tuning.max_arm_length,clampf(tuning.posture_comfort_extension_ratio,.1,.9))
	var candidates: Dictionary = {}
	var weights: Dictionary = {}
	var candidate := Vector3.ZERO
	for id in ids:
		var local: Vector3 = tuning.shoulder_left if id==0 else tuning.shoulder_right
		var stand: float = maxf(0.08,tuning.posture_body_surface_clearance+(frame*local).dot(out))
		var drop := sqrt(maxf(.06*.06,comfortable*comfortable-stand*stand))
		candidates[id] = controller.hands[id]["anchor"].world_point()-frame*local+out*stand-Vector3.UP*drop
		weights[id] = 1.0/ids.size()
		candidate += Vector3(candidates[id])/ids.size()
	if policy==2 and ids.size()==2:
		var total := 0.0
		for id in ids:
			var local: Vector3 = tuning.shoulder_left if id==0 else tuning.shoulder_right
			var anchor = controller.hands[id]["anchor"]
			var axis: Vector3 = (anchor.world_point()-(candidate+frame*local)).normalized()
			var support: PhysicsBody3D = anchor.support_body()
			var capacity: float = maxf(.05,axis.dot(Vector3.UP))*maxf(1.0,float(support.get_meta("grip_load_limit",tuning.grip_force_limit)))
			if support is RigidBody3D:
				capacity *= support.mass/(support.mass+controller.torso.mass)
			weights[id] = capacity
			total += capacity
		weights[ids[0]] = clampf(weights[ids[0]]/maxf(.001,total),.2,.8)
		weights[ids[1]] = 1.0-weights[ids[0]]
		candidate = Vector3.ZERO
		for id in ids:
			candidate += Vector3(candidates[id])*float(weights[id])
	var goals: Dictionary = {}
	var feasible := true
	var reason := "support_acquisition"
	for id in ids:
		var local: Vector3 = tuning.shoulder_left if id==0 else tuning.shoulder_right
		var offset: Vector3 = controller.hands[id]["anchor"].world_point()-(candidate+frame*local)
		if offset.length()>tuning.max_arm_length-.005 or offset.y<.025:
			feasible = false
			reason = "infeasible_supported_geometry"
		goals[id] = clampf(offset.length(),tuning.min_arm_length,tuning.max_arm_length)
	var desired := Transform3D(frame,candidate)
	var material_body: PhysicsBody3D = controller.hands[ids[0]]["anchor"].support_body()
	var plan := {"signature":key,"event":events,"goals":goals,"allocations":weights,
		"desired_pose":desired,"reference":weakref(material_body),"local_pose":material_body.global_transform.affine_inverse()*desired,
		"feasible":feasible,"reason":reason,"policy":policy}
	cache[key] = plan.duplicate(true)
	return plan

func refresh(plan: Dictionary) -> void:
	var material_body: PhysicsBody3D = plan.reference.get_ref()
	if is_instance_valid(material_body) and material_body.is_inside_tree():
		plan.desired_pose = material_body.global_transform*Transform3D(plan.local_pose)
	else:
		plan.feasible = false
		plan.reason = "support_lost"
