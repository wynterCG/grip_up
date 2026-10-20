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

static func _point_velocity(target:PhysicsBody3D,point:Vector3)->Vector3:
	if target is RigidBody3D:
		var state:=PhysicsServer3D.body_get_direct_state(target.get_rid())
		var center:Vector3=target.global_position+state.center_of_mass if state!=null else target.global_transform*target.center_of_mass
		return target.linear_velocity+target.angular_velocity.cross(point-center)
	if target is StaticBody3D:return target.constant_linear_velocity+target.constant_angular_velocity.cross(point-target.global_position)
	return Vector3.ZERO

static func _intent_score(body:RigidBody3D,tuning:Resource,hip:Vector3,current:Vector3,length:float,ankle:Vector3,point:Vector3,normal:Vector3,support:PhysicsBody3D,context:Dictionary)->Dictionary:
	var intent:Vector3=context.get("intent",Vector3.ZERO)
	intent=intent.limit_length(1.0) if intent.is_finite() else Vector3.ZERO
	var leg:Vector3=hip-ankle
	var axis:Vector3=leg.normalized()
	var pressure:float=maxf(0.0,axis.dot(normal))
	var tangent:Vector3=axis-normal*axis.dot(normal)
	var friction:float=tuning.foot_friction
	if support is RigidBody3D or support is StaticBody3D:
		if support.physics_material_override!=null:friction=minf(friction,maxf(0.0,support.physics_material_override.friction))
	# The same unilateral cone as the force solver, evaluated as a direction
	# quality only. A candidate is not a planted contact or promised force.
	var transmissible:Vector3=normal*pressure+tangent.limit_length(friction*pressure)
	var utility:float=transmissible.dot(intent)
	var bearing:float=maxf(0.0,transmissible.dot(Vector3.UP))
	var extension_room:float=maxf(0.0,length*.999-leg.length())
	var room_quality:float=clampf(extension_room/maxf(.001,tuning.contact_preload*2.0),0.0,1.0)
	var travel_time:float=current.distance_to(ankle)/maxf(.001,tuning.plant_speed)
	var relative_velocity:Vector3=_point_velocity(support,point)-_point_velocity(body,current)
	var drift:float=minf(.4,relative_velocity.length()*travel_time)
	var previous:Dictionary=context.get("previous",{})
	var hysteresis:=0.0
	if int(previous.get("support_id",0))==support.get_instance_id() and previous.has("local_point"):
		var old_world:Vector3=support.to_global(previous.local_point)
		var nearby:float=old_world.distance_to(point)
		if nearby<.08:hysteresis=.035*(1.0-nearby/.08)
	var adjustment:float=-.35*utility+.15*(1.0-bearing)+.10*(1.0-room_quality)+.35*drift-hysteresis
	return {"adjustment":adjustment,"signed_push_utility":utility,"bearing_quality":bearing,"normal_per_unit_effort":pressure,"friction":friction,"extension_room":extension_room,"gesture_time_estimate":travel_time,"relative_support_velocity":relative_velocity,"drift_penalty_distance":drift,"hysteresis_bonus":hysteresis,"compression_feasible":pressure>.000001 and extension_room>0,"reason":"LOCAL_COMPRESSIVE_PUSH_RANKING"}

static func sample(body: RigidBody3D, tuning: Resource, hip: Vector3, rest: Vector3, current: Vector3, length: float, clearance: float, id: int, context:Dictionary={}) -> Dictionary:
	var right := body.global_basis.x.normalized()
	var forward := -body.global_basis.z.normalized()
	var side := -1.0 if id == 0 else 1.0
	var best: Dictionary = {}
	var score := INF
	var aware:bool=bool(context.get("enabled",false))
	var candidates:Array=[]
	var rejected:Dictionary={}
	var chosen:Dictionary={}
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
				var invalid:String=validate(body, tuning, hip, ankle, length, hit.collider, point, normal, clearance)
				if invalid != "":
					if aware:rejected[invalid]=int(rejected.get(invalid,0))+1
					continue
				# Prefer an available higher step over remaining on the floor until
				# the leg goes taut. Height is still limited by actual anatomy/queries.
				var cost: float = current.distance_to(ankle) + absf(offset) * 0.12 - maxf(0.0, ankle.y - rest.y) * tuning.step_preference + (1.0 - maxf(0.0, normal.y)) * tuning.bearing_preference
				var row:Dictionary={}
				if aware:
					row=_intent_score(body,tuning,hip,current,length,ankle,point,normal,hit.collider,context)
					row.merge({"point":point,"normal":normal,"support_id":hit.collider.get_instance_id(),"support_name":str(hit.collider.name),"baseline_cost":cost},true)
					cost+=float(row.adjustment)
					row["cost"]=cost
					candidates.append(row)
				if cost < score:
					score = cost
					best = {"support": hit.collider, "point": point, "normal": normal, "ankle": ankle}
					if aware:chosen=row.duplicate(true)
	if aware:context["diagnostics"]={"reason":"NO_VALID_CURRENT_CANDIDATE" if best.is_empty() else "LOCAL_CANDIDATE_SELECTED","candidate_count":candidates.size(),"selected":chosen,"rejected":rejected,"candidates":candidates,"future_contact_authorized":false}
	return best
