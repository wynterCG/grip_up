extends RefCounted
## Observations only. No predictor, authorization, force application, or body writes.
const Actuator = preload("res://features/grip_up/scripts/arm_actuator.gd")
const MAX_EVENTS := 256
const SWING_POWER_EPSILON := 0.01 # W; diagnostic sign deadband, never actuation.
var _events: Array[Dictionary] = []
var _last: Dictionary = {}
var _attempts: Dictionary = {}
var _supports: Dictionary = {}
var _pending: Array[Dictionary] = []
var _request := -1
var _serial := 0
var _session := 0
var _motion: Dictionary = {}
var _arm_work := 0.0
var _moment_work := 0.0
var _swing_work := 0.0
var _axis_unactuated := false
var events: Array[Dictionary]:
	get: return _events.duplicate(true)
var last_by_hand: Dictionary:
	get: return _last.duplicate(true)

func reset() -> void:
	_events.clear()
	_last.clear()
	_attempts.clear()
	_supports.clear()
	_pending.clear()
	_request = -1
	_session += 1
	_motion.clear()
	_arm_work = 0.0
	_moment_work = 0.0
	_swing_work = 0.0
	_axis_unactuated = false

func drain_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = _pending.duplicate(true)
	_pending.clear()
	return result

func diagnostics(include_events: bool = false) -> Dictionary:
	var result := {"enabled":true,"session":_session,"event_count":_events.size(),"event_capacity":MAX_EVENTS,
		"last_by_hand":last_by_hand,"motion":_motion.duplicate(true)}
	if include_events:
		result["events"] = events
	return result

func _emit(row: Dictionary) -> void:
	_events.append(row.duplicate(true))
	if _events.size()>MAX_EVENTS:
		_events.pop_front()
	_pending.append(row.duplicate(true))
	if _pending.size()>MAX_EVENTS:
		_pending.pop_front()
	if int(row.hand)>=0:
		_last[row.hand] = row.duplicate(true)

func begin_attempt(controller: Node, id: int, support: PhysicsBody3D, point: Vector3, normal: Vector3, has_candidate: bool = true) -> void:
	var requested_hand := id
	id = id if id in [0,1] else -1
	_serial += 1
	_request = id
	var shoulder: Vector3 = controller.get_shoulder_world(id)
	var valid := is_instance_valid(support)
	_supports[id] = weakref(support) if valid else null
	_attempts[id] = {"attempt_id":_serial,"input_time":controller.simulation_time,"hand":id,
		"requested_hand":requested_hand,"has_candidate":has_candidate,
		"support_id":support.get_instance_id() if valid else 0,"support_name":str(support.name) if valid else "",
		"local_point":null,"candidate_world":null,"normal":null,
		"input_shoulder":shoulder,"input_hand":controller.get_hand_world(id),"input_distance":shoulder.distance_to(point) if has_candidate else -1.0,
		"travel_distance":0.0,"in_range_time":0.0,"contact_time":-1.0,"primary_failure":"","closed":false}
	if has_candidate:
		_attempts[id].candidate_world = point
		_attempts[id].normal = normal
	if valid:
		_attempts[id].local_point = support.to_local(point)
	observe(controller,id,"ATTEMPT_STARTED","REQUEST","input_press")

func unselected(controller: Node, id: int, reason: String) -> void:
	begin_attempt(controller,id,null,Vector3.ZERO,Vector3.ZERO,false)
	var key := id if id in [0,1] else -1
	observe(controller,key,"CONTACT_REJECTED","REQUEST",reason)
	_attempts[key].closed = true

func accept(controller: Node, id: int) -> void:
	observe(controller,id,"REQUEST_ACCEPTED","TRANSIT","finite_reach_started")

func reject(controller: Node, reason: String) -> void:
	var code := "CONTACT_REJECTED"
	if reason in ["out_of_reach","outside_buffer_window"]:
		code = "POSE_UNREACHABLE"
	elif reason=="surface_obstructed":
		code = "PATH_OBSTRUCTED"
	observe(controller,_request,code,"REQUEST",reason)
	if _attempts.has(_request):
		_attempts[_request].closed = true

func observe(controller: Node, id: int, code: String, stage: String, reason: String, extra: Dictionary = {}) -> void:
	if not _attempts.has(id):
		return # Enabling diagnostics never fabricates a historical press/catch.
	var attempt: Dictionary = _attempts[id]
	if code in ["POSE_UNREACHABLE","PATH_OBSTRUCTED","HAND_TOO_SLOW","TARGET_LEFT_REACH","CONTACT_REJECTED","CATCH_OVERLOAD","GRIP_SLIP","SUPPORT_LOST"] and attempt.primary_failure=="":
		attempt.primary_failure = code
	var row: Dictionary = attempt.duplicate(true)
	row.merge({"session":_session,"time":controller.simulation_time,"step":controller._step,"code":code,"stage":stage,"reason":reason,
		"state":controller.get_hand_state(id),"elapsed":controller.simulation_time-float(attempt.input_time),
		"window_remaining":-1.0,"predicted_contact_time":-1.0,"prediction":"not_evaluated","certainty":"observed"},true)
	if id>=0 and id<controller.hands.size() and is_instance_valid(controller.torso):
		var hand: Dictionary = controller.hands[id]
		var anchor = hand.anchor
		var shoulder: Vector3 = controller.get_shoulder_world(id)
		row.merge({"shoulder_world":shoulder,"hand_world":hand.hand_world,
			"body_pose":controller.torso.global_transform,"body_velocity":controller.torso.linear_velocity,"body_spin":controller.torso.angular_velocity},true)
		if not attempt.has_candidate:
			row.merge(extra,true)
			_emit(row)
			return
		var use_anchor: bool = stage!="REQUEST" and anchor!=null and anchor.is_valid()
		var point: Vector3 = anchor.world_point() if use_anchor else attempt.candidate_world
		var target_velocity := Vector3.ZERO
		if use_anchor:
			target_velocity = anchor.point_velocity()
		elif _supports.get(id)!=null:
			var support: PhysicsBody3D = _supports[id].get_ref()
			if is_instance_valid(support):
				if support is RigidBody3D:
					target_velocity = Actuator.point_velocity(support,point)
				elif support is StaticBody3D:
					target_velocity = support.constant_linear_velocity+support.constant_angular_velocity.cross(point-support.global_position)
		var relative: Vector3 = Actuator.point_velocity(controller.torso,shoulder)-target_velocity
		row.merge({"candidate_world":point,
			"anatomical_distance":shoulder.distance_to(point),"max_reach":controller.get_max_reach(),
			"reach_margin":controller.get_max_reach()-shoulder.distance_to(point),"actual_length":hand.actual_length,
			"target_length":hand.rest_length,"hand_remaining_distance":Vector3(hand.hand_world).distance_to(point),
			"minimum_remaining_hand_time":Vector3(hand.hand_world).distance_to(point)/maxf(.001,controller.tuning.hand_reach_speed),
			"relative_velocity":relative,"relative_speed":relative.length(),"radial_speed":relative.dot((shoulder-point).normalized()),
			"force":hand.force,"force_magnitude":Vector3(hand.force).length(),"grip_limit":hand.grip_limit,
			"body_pose":controller.torso.global_transform,"body_velocity":controller.torso.linear_velocity,"body_spin":controller.torso.angular_velocity},true)
	row.merge(extra,true)
	_emit(row)

func advance(controller: Node, id: int, previous: Vector3, delta: float) -> void:
	if not _attempts.has(id) or _attempts[id].closed:
		return
	var attempt: Dictionary = _attempts[id]
	attempt.travel_distance += previous.distance_to(controller.get_hand_world(id))
	var hand: Dictionary = controller.hands[id]
	if hand.state=="REACHING" and hand.actual_length<=controller.get_max_reach()+.00005:
		attempt.in_range_time += delta

func contact(controller: Node, id: int) -> void:
	if _attempts.has(id):
		_attempts[id].contact_time = controller.simulation_time
	observe(controller,id,"SUCCESS","CONTACT","physical_surface_contact")

func slipping(controller: Node, id: int, force: float) -> void:
	if not _attempts.has(id):
		return
	var contact_time: float = _attempts[id].contact_time
	# This is the actual force-blend + integrity-confirmation interval, not an
	# invented speed cutoff. Later load failures remain retention slip only.
	if contact_time>=0 and controller.simulation_time-contact_time<=controller.tuning.grip_blend_duration+controller.tuning.overload_confirm_time+2.0*controller.get_physics_process_delta_time():
		observe(controller,id,"CATCH_OVERLOAD","RETENTION","load_limit_exceeded",{"unweakened_force":force})
	observe(controller,id,"GRIP_SLIP","RETENTION","load_limit_exceeded",{"unweakened_force":force})

func release(controller: Node, id: int, reason: String) -> void:
	if not _attempts.has(id) or _attempts[id].closed:
		return
	var state: String = controller.get_hand_state(id)
	var code := "RELEASED" if state in ["ATTACHED","SLIPPING"] else "CANCELLED"
	if reason=="support_invalidated":
		code = "SUPPORT_LOST"
	elif reason in ["target_left_reach","hand_path_left_reach","capture_window_expired"]:
		code = "TARGET_LEFT_REACH"
	elif reason=="hand_path_obstructed":
		code = "PATH_OBSTRUCTED"
	elif reason=="candidate_timeout_or_obstructed":
		# Observe the actual branch condition; do not guess from combined text.
		var hand: Dictionary = controller.hands[id]
		var anchor = hand.anchor
		var visible: bool = anchor!=null and anchor.is_valid() and controller._accessible(controller.get_shoulder_world(id),anchor.world_point(),anchor.world_normal(),anchor.support_body())
		code = "HAND_TOO_SLOW" if float(hand.elapsed)>controller.tuning.candidate_hold_timeout and visible else "PATH_OBSTRUCTED"
	elif reason=="grip_overload":
		code = "GRIP_SLIP"
	elif reason=="arm_extension_limit":
		code = "TARGET_LEFT_REACH"
	elif reason not in ["manual","launch","focus_lost","ui_mouse_up","mouse_up","input_focus_lost","input_released","hold_mode_enabled"]:
		code = "CONTACT_REJECTED" if state=="REACHING" else code
	observe(controller,id,code,"RETENTION" if state in ["ATTACHED","SLIPPING"] else "TRANSIT",reason)
	_attempts[id].closed = true

func sample(controller: Node, delta: float, decomposition: Dictionary) -> void:
	var center: Vector3 = controller.torso.global_transform*controller.torso.center_of_mass
	var anchor_center := Vector3.ZERO
	var anchor_velocity := Vector3.ZERO
	var support_spin := Vector3.ZERO
	var total_weight := 0.0
	var arm_power := 0.0
	var support_moment_power := 0.0
	var reaction_weighted_spin := Vector3.ZERO
	var reactions: Dictionary = {}
	for applied in decomposition.applied:
		var support: PhysicsBody3D = applied.support
		if not is_instance_valid(support):
			continue
		var weight: float = maxf(.000001,applied.allocation)
		anchor_center += Vector3(applied.point)*weight
		anchor_velocity += Vector3(applied.point_velocity)*weight
		var spin: Vector3 = support.angular_velocity if support is RigidBody3D else support.constant_angular_velocity if support is StaticBody3D else Vector3.ZERO
		support_spin += spin*weight
		total_weight += weight
		arm_power += Vector3(applied.force).dot(Actuator.point_velocity(controller.torso,applied.shoulder)-Vector3(applied.point_velocity))
		var torque: Vector3 = -Vector3(decomposition.assist)*float(applied.torque_weight)
		support_moment_power += torque.dot(spin)
		reaction_weighted_spin += spin*float(applied.torque_weight)
		var key: int = support.get_instance_id()
		if not reactions.has(key):
			reactions[key] = {"support_id":key,"name":str(support.name),"dynamic":support is RigidBody3D,"force":Vector3.ZERO,"torque":Vector3.ZERO}
		reactions[key].force -= Vector3(applied.force)
		reactions[key].torque += torque
	var has_support := total_weight>0.0
	if has_support:
		anchor_center /= total_weight
		anchor_velocity /= total_weight
		support_spin /= total_weight
	var relative_velocity: Vector3 = controller.torso.linear_velocity-anchor_velocity
	var relative_spin: Vector3 = controller.torso.angular_velocity-support_spin
	var radius: Vector3 = center-anchor_center
	var pendulum_valid := has_support and radius.length_squared()>.000001
	var pendulum_spin: Vector3 = radius.cross(relative_velocity)/radius.length_squared() if pendulum_valid else Vector3.ZERO
	var spine: Vector3 = ((controller.get_shoulder_world(0)+controller.get_shoulder_world(1))*.5-center).normalized()
	var current_right: Vector3 = controller.torso.global_basis.x.slide(spine)
	var reference_right: Vector3 = controller._view_right.slide(spine)
	var twist_valid := current_right.length_squared()>.000001 and reference_right.length_squared()>.000001
	var moment_power: float = Vector3(decomposition.assist).dot(controller.torso.angular_velocity)+support_moment_power
	var swing_relative_spin: Vector3 = controller.torso.angular_velocity-reaction_weighted_spin
	var swing_power: float = Vector3(decomposition.swing).dot(swing_relative_spin)
	var swing_phase := "PUMPING" if swing_power>SWING_POWER_EPSILON else "BRAKING" if swing_power<-SWING_POWER_EPSILON else "NEUTRAL"
	_arm_work += arm_power*delta
	_moment_work += moment_power*delta
	_swing_work += swing_power*delta
	var rotational_energy := 0.0
	var inverse_inertia: Basis = controller.torso.get_inverse_inertia_tensor()
	if absf(inverse_inertia.determinant())>.000000001:
		rotational_energy = .5*relative_spin.dot(inverse_inertia.inverse()*relative_spin)
	var budget: Dictionary = decomposition.duplicate(true)
	budget.erase("applied") # No body/node references escape into immutable JSON snapshots.
	_motion = {"support_valid":has_support,"anchor_center":anchor_center,"relative_velocity":relative_velocity,"relative_spin":relative_spin,
		"pendulum_valid":pendulum_valid,"pendulum_angle":acos(clampf(radius.normalized().dot(Vector3.DOWN),-1.0,1.0)) if pendulum_valid else 0.0,
		"pendulum_angular_velocity":pendulum_spin,"pendulum_angular_speed":pendulum_spin.length(),"trunk_axis":spine,
		"twist_valid":twist_valid,"trunk_twist":current_right.normalized().signed_angle_to(reference_right.normalized(),spine) if twist_valid else 0.0,
		"trunk_twist_rate":relative_spin.dot(spine),"trunk_tilt":acos(clampf(controller.torso.global_basis.y.normalized().dot(Vector3.UP),-1.0,1.0)),
		"relative_translation_energy":.5*controller.torso.mass*relative_velocity.length_squared(),"relative_rotation_energy":rotational_energy,
		"arm_power":arm_power,"grip_moment_power":moment_power,"estimated_arm_work":_arm_work,"estimated_grip_moment_work":_moment_work,
		"swing_power":swing_power,"estimated_swing_work":_swing_work,"swing_phase":swing_phase,"swing_phase_epsilon_w":SWING_POWER_EPSILON,
		"swing_relative_spin":swing_relative_spin,"swing_work_scope":"incremental_swing_after_common_cap; actual_blended_reaction_weighted_support_spin",
		"energy_scope":"body_relative_to_weighted_support; excludes gravity/contact/joint/drag work and support kinetic energy",
		"budget":budget,"support_reactions":reactions}
	var request: Vector3 = controller.get_effective_swing_request()
	var lever: Vector3 = decomposition.swing_lever
	var unactuated := has_support and float(decomposition.swing_engagement)>.000001 and request.length_squared()>.000001 and (lever.length_squared()<.000001 or request.cross(lever.normalized()).length_squared()<.000001)
	if unactuated and not _axis_unactuated:
		_emit({"attempt_id":0,"hand":-1,"session":_session,"time":controller.simulation_time,"step":controller._step,
			"code":"SWING_AXIS_UNACTUATED","stage":"SWING","reason":"request_parallel_to_actual_shoulder_lever","requested":request,"lever":lever,
			"applied_swing_torque":decomposition.swing})
	_axis_unactuated = unactuated
