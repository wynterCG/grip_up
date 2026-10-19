extends Node
signal sample_ready(delta: float)
const Tuning = preload("res://features/grip_up/resources/climbing_tuning.gd")
const Anchor = preload("res://features/grip_up/scripts/grip_anchor.gd")
const Actuator = preload("res://features/grip_up/scripts/arm_actuator.gd")
const CapturePredictor = preload("res://features/grip_up/scripts/grip_capture_predictor.gd")
const CaptureEvaluator = preload("res://features/grip_up/scripts/grip_capture_evaluator.gd")
var torso: RigidBody3D
var tuning: Resource = Tuning.new()
var hands: Array[Dictionary] = []
var last_rejection: String = ""
var metrics: Dictionary = {}
var _contract: float = 0.0
var _extend: float = 0.0
var _bias: float = 0.0
var _intent_target := Vector3.ZERO
var _view_right := Vector3.RIGHT
var _step: int = 0
var _diagnostics: Dictionary = {}
var _launch_state := "IDLE"
var _launch_elapsed := 0.0
var _launch_charge := 0.0
var _launch_anchors: Dictionary = {}
var simulation_time := 0.0
var capture_predictor = CapturePredictor.new()
var capture_evaluator = CaptureEvaluator.new()

func configure(body: RigidBody3D, configuration: Resource = null) -> void:
	torso = body
	if configuration != null:
		tuning = configuration
	reset_state()

func reset_state() -> void:
	hands.clear()
	_contract = 0.0
	_extend = 0.0
	_bias = 0.0
	_intent_target = Vector3.ZERO
	_view_right = Vector3.RIGHT
	_step = 0
	simulation_time = 0.0
	_diagnostics.clear()
	cancel_launch()
	metrics = {"attempts": 0, "misses": 0, "attaches": 0, "slips": 0, "releases": 0}
	for id in 2:
		var shoulder: Vector3 = get_shoulder_world(id)
		hands.append({"state": "FREE", "anchor": null, "support": null,
			"anchor_world": shoulder, "target_world": shoulder,
			"hand_world": shoulder,
			"rest_length": tuning.max_arm_length, "actual_length": 0.0,
			"force": Vector3.ZERO, "reaction_force": Vector3.ZERO,
			"allocation": 0.0, "elapsed": 0.0, "blend_elapsed": 0.0,
			"overload_time": 0.0, "slip_elapsed": 0.0, "recovery_time": 0.0,
			"grip_limit": tuning.grip_force_limit, "reason": ""})
	last_rejection = ""

func set_climb_intent(contract: float, extend: float, bias: float, view_right: Vector3 = Vector3.RIGHT) -> void:
	_intent_target = Vector3(clampf(contract, 0.0, 1.0),clampf(extend, 0.0, 1.0),clampf(bias, -1.0, 1.0))
	if tuning.intent_response_time <= 0.0:
		_contract = _intent_target.x
		_extend = _intent_target.y
		_bias = _intent_target.z
	if view_right.is_finite():
		var horizontal := view_right.slide(Vector3.UP)
		if horizontal.length_squared()>0.0001:
			_view_right = horizontal.normalized()

func get_shoulder_world(id: int) -> Vector3:
	if not is_instance_valid(torso):
		return Vector3.ZERO
	var local: Vector3 = tuning.shoulder_left if id == 0 else tuning.shoulder_right
	return (torso.global_transform if torso.is_inside_tree() else torso.transform) * local

func request_launch_charge(pressed: bool) -> bool:
	if pressed:
		if _launch_state!="IDLE" or tuning.launch_contraction_speed<=0.0:
			return false
		var attached := _attached_ids()
		if attached.is_empty():
			return false
		for id in attached:
			if hands[id]["state"]!="ATTACHED":
				return false
		_launch_anchors.clear()
		for id in attached:
			_launch_anchors[id] = hands[id]["anchor"]
		_launch_state = "CHARGING"
		_launch_elapsed = 0.0
		_launch_charge = 0.0
		return true
	if _launch_state!="CHARGING":
		return false
	if _launch_elapsed<0.08:
		cancel_launch()
		return false
	_launch_state = "PULLING"
	_launch_elapsed = 0.0
	return true

func cancel_launch() -> void:
	_launch_state = "IDLE"
	_launch_elapsed = 0.0
	_launch_charge = 0.0
	_launch_anchors.clear()

func _advance_launch(delta: float) -> void:
	if _launch_state=="IDLE":
		return
	_launch_elapsed += delta
	if _launch_state=="COOLDOWN":
		if _launch_elapsed>=tuning.launch_cooldown:
			cancel_launch()
		return
	var active := 0
	for id in _launch_anchors:
		if hands[id]["state"]=="ATTACHED" and hands[id]["anchor"]==_launch_anchors[id]:
			active += 1
	if active==0:
		_launch_state = "COOLDOWN"
		_launch_elapsed = 0.0
	elif _launch_state=="CHARGING":
		_launch_charge = clampf(_launch_elapsed/maxf(0.001,tuning.launch_charge_duration),0.0,1.0)
	elif _launch_elapsed>=lerpf(0.10,tuning.launch_duration,_launch_charge):
		# Detach only the original anchors; a freshly caught grip is preserved.
		for id in _launch_anchors:
			if hands[id]["anchor"]==_launch_anchors[id]:
				release_grip(id,"launch")
		_launch_state = "COOLDOWN"
		_launch_elapsed = 0.0

func get_hand_state(id: int) -> String:
	return str(hands[id]["state"]) if id >= 0 and id < hands.size() else "FREE"

func get_max_reach() -> float:
	return tuning.max_reach_length if tuning.max_reach_length>0.0 else tuning.max_arm_length+tuning.attach_distance_tolerance

func get_hand_world(id: int) -> Vector3:
	return hands[id]["hand_world"] if id >= 0 and id < hands.size() else Vector3.ZERO

func get_arm_force(id: int) -> Vector3:
	return hands[id]["force"] if id >= 0 and id < hands.size() else Vector3.ZERO

func request_grip(id: int, support: PhysicsBody3D, world_point: Vector3, normal: Vector3) -> bool:
	return _request_grip(id,support,world_point,normal,false)

func request_buffered_grip(id: int, support: PhysicsBody3D, world_point: Vector3, normal: Vector3) -> bool:
	if not tuning.predictive_grip:
		return request_grip(id,support,world_point,normal)
	return _request_grip(id,support,world_point,normal,true)

func _request_grip(id: int, support: PhysicsBody3D, world_point: Vector3, normal: Vector3, predictive: bool) -> bool:
	metrics["attempts"] += 1
	if id < 0 or id >= hands.size() or not is_instance_valid(torso) or not is_instance_valid(support) or support == torso:
		return _reject("invalid_hand_or_support")
	if get_hand_state(id) in ["ATTACHED", "SLIPPING"]:
		return _reject("release_hand_before_regrip")
	if not support is StaticBody3D and not support is RigidBody3D:
		return _reject("unsupported_body_type")
	if not bool(support.get_meta("grippable", true)):
		return _reject("surface_not_grippable")
	if not world_point.is_finite() or not normal.is_finite() or normal.length_squared() < 0.5:
		return _reject("invalid_surface_point")
	var pending: bool = get_shoulder_world(id).distance_to(world_point)>get_max_reach()+0.00005
	var forecast: Dictionary = {}
	if predictive:
		forecast = capture_predictor.evaluate(self,id,support,world_point,normal)
	if pending:
		if not predictive or forecast.get("status")!="SOON":
			return _reject("out_of_reach")
		if float(forecast.get("predicted_entry_time",INF))>clampf(tuning.capture_intent_buffer_duration,0.10,0.15):
			return _reject("outside_buffer_window")
	if not _accessible(get_shoulder_world(id), world_point, normal.normalized(), support):
		return _reject("surface_obstructed")
	var hand: Dictionary = hands[id]
	var departure_normal: Vector3 = hand.get("release_normal",Vector3.ZERO)
	hand["departing_surface"] = departure_normal.length_squared()>0.5 and Vector3(hand["hand_world"]).distance_to(hand["anchor_world"])<0.015
	hand["departure_world"] = hand["hand_world"]+departure_normal*tuning.hand_surface_approach_distance
	hand["anchor"] = Anchor.new(support, world_point, normal.normalized())
	hand["support"] = support
	hand["state"] = "REACHING"
	hand["elapsed"] = 0.0
	hand["target_world"] = world_point
	hand["approaching_surface"] = true
	hand["reason"] = ""
	hand["predictive_wait"] = pending
	hand["capture"] = {"input_time":simulation_time,"buffered":pending,"predicted_entry_time":forecast.get("predicted_entry_time",-1.0),
		"predicted_contact_time":forecast.get("predicted_contact_time",-1.0),"predicted_target":forecast.get("predicted_target",world_point),
		"predicted_target_time":forecast.get("predicted_target_time",-1.0),"actual_arrival":-1.0,"failure_reason":""}
	last_rejection = ""
	return true

func _reject(reason: String) -> bool:
	last_rejection = reason
	metrics["misses"] += 1
	return false

func release_grip(id: int, reason: String = "manual") -> void:
	if id < 0 or id >= hands.size():
		return
	var hand: Dictionary = hands[id]
	if hand.has("capture") and reason not in ["manual","launch"]:
		hand["capture"]["failure_reason"] = reason
		if tuning.predictive_grip and reason=="arm_extension_limit" and hand["capture"].get("load_risk",false):
			hand["capture"]["failure_reason"] = "excessive_relative_speed"
	if OS.get_cmdline_user_args().has("--debug-reach") and hand["state"]=="REACHING":
		print("REACH_RELEASE id=",id," reason=",reason," actual=",hand["actual_length"]," endpoint=",hand["hand_world"])
	if hand["state"] in ["ATTACHED", "SLIPPING"]:
		metrics["releases"] += 1
		hand["release_normal"] = hand["anchor"].world_normal() if hand["anchor"]!=null and hand["anchor"].is_valid() else Vector3.ZERO
	hand["state"] = "RELEASED"
	hand["anchor"] = null
	hand["support"] = null
	hand["force"] = Vector3.ZERO
	hand["reaction_force"] = Vector3.ZERO
	hand["allocation"] = 0.0
	hand["elapsed"] = 0.0
	hand["reason"] = reason

func _accessible(from: Vector3, point: Vector3, normal: Vector3, support: PhysicsBody3D) -> bool:
	if not torso.is_inside_tree():
		return false
	# Extend the same line through the endpoint. Offsetting along the surface
	# normal changes a steep ray's intersection and falsely rejects visible holds.
	var query := PhysicsRayQueryParameters3D.create(from, point + (point - from).normalized() * 0.025)
	query.collision_mask = tuning.allowed_grip_surface_mask
	query.exclude = [torso.get_rid()]
	query.hit_from_inside = true
	var hit: Dictionary = torso.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == support and hit.position.distance_to(point) <= 0.06 and hit.normal.dot(normal) > 0.3

func _update_hand(id: int, delta: float) -> void:
	var hand: Dictionary = hands[id]
	hand["force"] = Vector3.ZERO
	hand["reaction_force"] = Vector3.ZERO
	hand["elapsed"] += delta
	var shoulder: Vector3 = get_shoulder_world(id)
	if hand["state"] == "RELEASED":
		hand["state"] = "FREE"
	if hand["state"] == "FREE":
		var rest_offset: Vector3 = tuning.free_hand_rest_left if id == 0 else tuning.free_hand_rest_right
		var rest: Vector3 = shoulder + torso.global_basis * rest_offset
		var space: PhysicsDirectSpaceState3D = torso.get_world_3d().direct_space_state
		# A resting virtual hand must remain on the free side of walls/platforms.
		# Otherwise a fallen/rotated torso parks it inside a solid and every later
		# reaching sweep rejects its own embedded starting point.
		var rest_query := PhysicsRayQueryParameters3D.create(shoulder, rest)
		rest_query.exclude = [torso.get_rid()]
		rest_query.collision_mask = tuning.allowed_grip_surface_mask
		var rest_hit: Dictionary = space.intersect_ray(rest_query)
		if not rest_hit.is_empty():
			rest = rest_hit.position + rest_hit.normal * 0.025
		var previous: Vector3 = hand["hand_world"]
		var next: Vector3 = previous.move_toward(rest, tuning.hand_reach_speed * delta)
		var sweep := PhysicsRayQueryParameters3D.create(previous, next)
		sweep.exclude = [torso.get_rid()]
		sweep.collision_mask = tuning.allowed_grip_surface_mask
		# false also lets an already embedded FREE endpoint leave a moving solid
		# at the same finite hand speed. No forces or torso state are changed.
		sweep.hit_from_inside = false
		var hit: Dictionary = space.intersect_ray(sweep)
		if not hit.is_empty():
			next = hit.position + hit.normal * 0.025
		hand["hand_world"] = next
		return
	var anchor = hand["anchor"]
	if anchor == null or not anchor.is_valid():
		release_grip(id, "support_invalidated")
		return
	var point: Vector3 = anchor.world_point()
	hand["target_world"] = point
	hand["anchor_world"] = point
	hand["actual_length"] = shoulder.distance_to(point)
	if hand["state"] == "REACHING":
		if hand["actual_length"] > get_max_reach()+0.00005:
			if not hand.get("predictive_wait",false):
				release_grip(id, "target_left_reach")
				return
			if hand["elapsed"]>clampf(tuning.capture_intent_buffer_duration,0.10,0.15):
				release_grip(id,"capture_window_expired")
				return
		elif hand.get("predictive_wait",false):
			hand["predictive_wait"] = false
		if hand["elapsed"] > tuning.candidate_hold_timeout or not _accessible(shoulder, point, anchor.world_normal(), anchor.support_body()):
			release_grip(id, "candidate_timeout_or_obstructed")
			return
		var previous: Vector3 = hand["hand_world"]
		# Approach in the free half-space first, then close along the normal.
		# A straight path from a low resting hand can otherwise hit the underside
		# of a hold whose selected front face is perfectly visible to the shoulder.
		var destination: Vector3 = point
		if hand.get("departing_surface",false):
			destination = hand["departure_world"]
		elif hand.get("predictive_wait",false):
			destination = shoulder+(point-shoulder).limit_length(get_max_reach())
		elif hand.get("approaching_surface",false):
			# Keep the approach waypoint inside the same anatomical reach sphere.
			var offset := point-shoulder
			var normal: Vector3 = anchor.world_normal()
			var projection := offset.dot(normal)
			var clearance := -projection+sqrt(maxf(0.0,projection*projection+get_max_reach()*get_max_reach()-offset.length_squared()))
			destination += normal*minf(tuning.hand_surface_approach_distance,maxf(0.0,clearance))
		var next: Vector3 = previous.move_toward(destination, tuning.hand_reach_speed * delta)
		if shoulder.distance_to(next) > get_max_reach()+0.00005:
			release_grip(id, "hand_path_left_reach")
			return
		var query := PhysicsRayQueryParameters3D.create(previous, next)
		query.exclude = [torso.get_rid()]
		query.collision_mask = tuning.allowed_grip_surface_mask
		# A just-released surface first gets a short outward-normal clearance
		# leg, before traversing to the new approach point. No through-wall ray.
		query.hit_from_inside = not hand.get("departing_surface",false)
		var hit: Dictionary = torso.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and (hit.collider != anchor.support_body() or hit.position.distance_to(point) > 0.06):
			if OS.get_cmdline_user_args().has("--debug-reach"):
				print("REACH_COLLISION id=", id, " from=", previous, " next=", next, " target=", point, " hit=", hit.position, " collider=", hit.collider.name, " shoulder=", shoulder)
			release_grip(id, "hand_path_obstructed")
			return
		hand["hand_world"] = next
		if hand.get("predictive_wait",false):
			if hand.get("departing_surface",false) and next.distance_to(destination)<0.001:
				hand["departing_surface"] = false
			return
		if hand.get("departing_surface",false) and next.distance_to(destination)<0.001:
			hand["departing_surface"] = false
		elif hand.get("approaching_surface", false) and next.distance_to(destination) < 0.001:
			hand["approaching_surface"] = false
		elif not hand.get("approaching_surface", false) and next.distance_to(point) <= (0.000001 if tuning.predictive_grip else tuning.attach_distance_tolerance):
			if tuning.predictive_grip:
				var capture: Dictionary = capture_evaluator.evaluate(self,id)
				if not capture.accepted:
					release_grip(id,capture.reason)
					return
				hand["capture"].merge(capture,true)
			if hand.has("capture"):
				hand["capture"]["actual_arrival"] = simulation_time-float(hand["capture"]["input_time"])
				hand["capture"]["prediction_error"] = Vector3(hand["capture"]["predicted_target"]).distance_to(point) if float(hand["capture"]["predicted_contact_time"])>=0.0 else -1.0
			hand["state"] = "ATTACHED"
			hand["hand_world"] = point
			hand["rest_length"] = clampf(hand["actual_length"], tuning.min_arm_length, tuning.max_arm_length)
			hand["blend_elapsed"] = 0.0
			hand["overload_time"] = 0.0
			hand["allocation"] = 1.0 if _attached_ids().size() == 1 else 0.0
			metrics["attaches"] += 1
		return
	hand["hand_world"] = point
	if hand["actual_length"] > tuning.max_arm_length + tuning.max_elastic_extension:
		release_grip(id, "arm_extension_limit")

func _attached_ids() -> Array[int]:
	var result: Array[int] = []
	for id in hands.size():
		if hands[id]["state"] in ["ATTACHED", "SLIPPING"]:
			result.append(id)
	return result

func _compute_attitude_assist(attached: Array[int], _forces: Array[Vector3], center: Vector3, sum_force: float) -> Vector3:
	if attached.is_empty():
		return Vector3.ZERO
	var assist: Vector3 = -torso.angular_velocity*tuning.attitude_damping if sum_force>5.0 else Vector3.ZERO
	if attached.size()==1 and sum_force>5.0:
		# This lateral input remains a bounded moment about the shoulder, rather
		# than a translational thruster or a body-space left/right convention.
		var lever := (get_shoulder_world(attached[0])-center).normalized()
		assist += _view_right.cross(lever)*(_bias*tuning.single_bias_torque)
	if tuning.twist_stiffness>0.0 or tuning.twist_damping>0.0:
		var engagement := 0.0
		var allocation := 0.0
		for id in attached:
			var blend: float = smoothstep(0.0,maxf(0.001,tuning.grip_blend_duration),hands[id]["blend_elapsed"])
			engagement += hands[id]["allocation"]*blend
			allocation += hands[id]["allocation"]
		engagement /= maxf(allocation,0.000001)
		# Twist is rotation about the trunk, not about a nearly horizontal short
		# arm. Using the arm axis there lets the torso turn sideways on the floor.
		# A loaded or lightly loaded attached hand still supplies this bounded
		# rotational reaction; an ungripped body receives no assistance.
		var spine: Vector3 = (get_shoulder_world(0)+get_shoulder_world(1))*0.5-center
		if spine.length_squared()>0.0001:
			var axis := spine.normalized()
			var current_right := torso.global_basis.x.slide(axis)
			var target_right := _view_right.slide(axis)
			# Heading is undefined if either lateral axis points along the load.
			# Fade continuously there instead of switching to another Euler axis.
			var authority := current_right.length_squared()*target_right.length_squared()
			if authority>0.000001:
				var error := current_right.normalized().signed_angle_to(target_right.normalized(),axis)
				var moment: float = error*tuning.twist_stiffness-torso.angular_velocity.dot(axis)*tuning.twist_damping
				# Only longitudinal trunk twist is stabilized. Pendular tilt,
				# shoulder forces and opposite support reaction remain physical.
				assist += axis*(moment*authority*engagement)
	return assist.limit_length(tuning.max_attitude_torque)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(torso):
		return
	_step += 1
	simulation_time += delta
	var intent_response: float = 1.0 if tuning.intent_response_time <= 0.0 else 1.0-exp(-delta/tuning.intent_response_time)
	_contract = lerpf(_contract,_intent_target.x,intent_response)
	_extend = lerpf(_extend,_intent_target.y,intent_response)
	_bias = lerpf(_bias,_intent_target.z,intent_response)
	for id in hands.size():
		_update_hand(id, delta)
	_advance_launch(delta)
	var attached: Array[int] = _attached_ids()
	var forces: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var raw_tensions: Array[float] = [0.0, 0.0]
	var center: Vector3 = torso.global_transform * torso.center_of_mass
	var sum_force: float = 0.0
	var moments := Vector3.ZERO
	var alignment := 0.0
	if attached.size() == 2:
		var span: Vector3 = hands[1]["anchor_world"]-hands[0]["anchor_world"]
		alignment = span.normalized().dot(_view_right)
	for id in attached:
		var hand: Dictionary = hands[id]
		# Bias the screen-side anchor, irrespective of which hand holds it.
		var side: float = alignment if id == 1 else -alignment
		var desired: float = 1.0 if attached.size() == 1 else 0.5 + 0.35 * _bias * side
		var response: float = 1.0 - exp(-delta / maxf(0.001, tuning.allocation_response_time))
		hand["allocation"] = lerpf(hand["allocation"], desired, response)
		var contraction: float = _contract * tuning.contraction_speed * (1.0 + 0.45 * _bias * side if attached.size() == 2 else 1.0)
		var extension: float = _extend*tuning.extension_speed
		if _launch_anchors.get(id)!=null and _launch_anchors[id]==hand["anchor"]:
			if _launch_state=="CHARGING":
				contraction = 0.0
				extension = tuning.launch_charge_extension_speed if _launch_charge<1.0 else 0.0
			elif _launch_state=="PULLING":
				contraction = lerpf(tuning.contraction_speed,tuning.launch_contraction_speed,_launch_charge)
				extension = 0.0
		hand["rest_length"] = clampf(hand["rest_length"] + (extension - contraction) * delta, tuning.min_arm_length, tuning.max_arm_length)
		hand["blend_elapsed"] += delta
		var blend: float = smoothstep(0.0, maxf(0.001, tuning.grip_blend_duration), hand["blend_elapsed"])
		var effort: float = hand["allocation"]
		var result: Dictionary = Actuator.evaluate(torso, get_shoulder_world(id), hand["anchor"], hand["rest_length"], tuning.arm_stiffness * effort, tuning.arm_damping * effort, tuning.max_length_error, delta)
		var raw: float = minf(result["tension"] * blend, tuning.max_force_per_arm)
		raw_tensions[id] = raw
		if hand["state"] == "SLIPPING":
			raw *= tuning.slip_force_multiplier
		forces[id] = result["axis"] * raw
		hand["force_axis"] = result["axis"]
		sum_force += forces[id].length()
		moments += (get_shoulder_world(id) - center).cross(forces[id])
	var assist: Vector3 = _compute_attitude_assist(attached,forces,center,sum_force)
	# Reused magnitude-sum / resultant-torque allocation from physics_grabber.
	var scale_factor: float = minf(1.0, minf(tuning.total_pull_force_budget / maxf(sum_force, 0.000001), tuning.max_total_torque / maxf((moments + assist).length(), 0.000001)))
	for id in attached:
		var hand: Dictionary = hands[id]
		var force: Vector3 = forces[id] * scale_factor
		hand["force"] = force
		hand["reaction_force"] = -force
		torso.apply_force(force, get_shoulder_world(id) - torso.global_position)
		var support: PhysicsBody3D = hand["anchor"].support_body()
		if support is RigidBody3D:
			support.apply_force(-force, hand["anchor_world"] - support.global_position)
			support.apply_torque(-assist * scale_factor / float(attached.size()))
			support.sleeping = false
		_update_integrity(id, raw_tensions[id] * scale_factor, delta)
	if not attached.is_empty():
		torso.apply_torque(assist * scale_factor)
		torso.sleeping = false
	_diagnostics = {"step": _step, "physics_delta": delta, "attached_count": attached.size(),
		"simulation_time":simulation_time,"input_intent":Vector3(_contract,_extend,_bias),"requested_intent":_intent_target,
		"features":{"predictive_grip":tuning.predictive_grip,"physical_feet":tuning.physical_feet,"posture_solver":tuning.posture_solver,"directional_grip_quality":tuning.directional_grip_quality,"reactive_challenge":tuning.reactive_challenge},
		"launch_state":_launch_state,"launch_elapsed":_launch_elapsed,"launch_charge":_launch_charge,
		"total_force": sum_force * scale_factor, "force_budget": tuning.total_pull_force_budget,
		"torque": (moments + assist) * scale_factor, "assist_torque": assist * scale_factor,
		"budget_scale": scale_factor, "control_right": _view_right, "hands": hands.duplicate(true),
		"torso_position": torso.global_position, "linear_velocity": torso.linear_velocity,
		"angular_velocity": torso.angular_velocity, "metrics": metrics.duplicate()}
	sample_ready.emit(delta)

func _update_integrity(id: int, unweakened_force: float, delta: float) -> void:
	var hand: Dictionary = hands[id]
	var support: PhysicsBody3D = hand["anchor"].support_body()
	var limit: float = maxf(1.0, float(support.get_meta("grip_load_limit", tuning.grip_force_limit)))
	hand["grip_limit"] = limit
	if hand["state"] == "ATTACHED":
		hand["overload_time"] = hand["overload_time"] + delta if unweakened_force > limit else maxf(0.0, hand["overload_time"] - delta * 2.0)
		if hand["overload_time"] >= tuning.overload_confirm_time:
			hand["state"] = "SLIPPING"
			hand["slip_elapsed"] = 0.0
			hand["recovery_time"] = 0.0
			hand["reason"] = "load_limit_exceeded"
			metrics["slips"] += 1
	else:
		hand["slip_elapsed"] += delta
		hand["recovery_time"] = hand["recovery_time"] + delta if unweakened_force < limit * tuning.slip_recovery_ratio else 0.0
		if hand["recovery_time"] >= tuning.slip_recovery_time:
			hand["state"] = "ATTACHED"
			hand["overload_time"] = 0.0
			hand["reason"] = "load_recovered"
		elif hand["slip_elapsed"] >= tuning.slip_duration:
			release_grip(id, "grip_overload")

func telemetry() -> Dictionary:
	return _diagnostics
