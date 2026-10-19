extends RefCounted
## Tier 1: geometric target planning only; all physical forces remain in ArmActuator.
## Reuses arm_target_coordinator's braking-envelope / acceleration-limited update.
const SupportFrame = preload("res://features/grip_up/scripts/locomotion_support_frame.gd")
var frame = SupportFrame.new()
var records: Dictionary = {}
var input := Vector2.ZERO
var requested := Vector2.ZERO
var camera_right := Vector3.RIGHT
var ground: Dictionary = {}
var data: Dictionary = {}
var swing := Vector3.ZERO
var foot_contract := 0.0
var foot_extend := 0.0
var _had_support := false
var _previous_requested := Vector2.ZERO
var _input_frame_id := 0
var _input_timestamp := 0.0
var _origin_frame: Dictionary = {}
var _start_position := Vector3.ZERO
var _position_initialized := false
var _voluntary_reversals := 0

func reset() -> void:
	frame.reset()
	records.clear()
	input = Vector2.ZERO
	requested = Vector2.ZERO
	ground.clear()
	data.clear()
	swing = Vector3.ZERO
	_had_support = false
	_previous_requested = Vector2.ZERO
	_input_frame_id = 0
	_input_timestamp = 0.0
	_origin_frame.clear()
	_position_initialized = false
	_voluntary_reversals = 0

func set_input(value: Vector2, reference_right: Vector3) -> void:
	requested = value.limit_length(1.0) if value.is_finite() else Vector2.ZERO
	if reference_right.is_finite() and reference_right.length_squared()>.01:camera_right = reference_right.normalized()

func step(controller: Node, delta: float, enabled: bool) -> void:
	var began := Time.get_ticks_usec()
	var tuning: Resource = controller.tuning
	if not _position_initialized:
		_start_position = controller.torso.global_position
		_position_initialized = true
	var contacts: Array[Dictionary] = []
	var ids: Array[int] = []
	var slipping := false
	var support_velocity := Vector3.ZERO
	var support_weight := 0.0
	for id in controller._attached_ids():
		var hand: Dictionary = controller.hands[id]
		if hand.state!="ATTACHED":
			slipping = true
			continue
		var material: PhysicsBody3D = hand.anchor.support_body()
		if not is_instance_valid(material):continue
		ids.append(id)
		var weight: float = maxf(.05,Vector3(hand.force).length()/maxf(1.0,controller.torso.mass*9.8))
		contacts.append({"id":material.get_instance_id(),"support":material,"normal":hand.anchor.world_normal(),"weight":weight,"kind":"hand"})
		support_velocity += hand.anchor.point_velocity()*weight
		support_weight += weight
	var feet := 0
	if controller.feet_solver!=null and tuning.physical_feet:
		for foot in controller.feet_solver.feet:
			if foot.state=="SUPPORTING" and is_instance_valid(foot.support):
				if ground.get("grounded",false) and foot.support.get_instance_id()==int(ground.get("support_id",0)):continue
				feet += 1
				var foot_weight: float = maxf(.05,Vector3(foot.force).length()/maxf(1.0,controller.torso.mass*9.8))
				contacts.append({"id":foot.support.get_instance_id(),"support":foot.support,"normal":foot.normal,"weight":foot_weight,"kind":"foot"})
	var grounded: bool = ground.get("grounded",false)
	var ground_authority: float = clampf(float(ground.get("authority",1.0)),0.0,1.0) if grounded else 0.0
	var mode := "CLIMB_HANDS_FEET" if not ids.is_empty() and feet>0 else "CLIMB_TWO_HANDS" if ids.size()==2 else "HANG_ONE_HAND" if ids.size()==1 else "GROUNDED_REACHING" if grounded and controller.hands.any(func(hand):return hand.state=="REACHING") else "GROUNDED" if grounded else "AIRBORNE"
	if grounded and not ids.is_empty() and ground_authority>.01 and ground_authority<.99 or ids.is_empty() and feet>0:mode = "FOOT_TRANSITION"
	if not grounded and ids.is_empty() and feet==0 and _had_support:mode = "FALLING_RECOVERY"
	if not ids.is_empty() or feet>0:_had_support = true
	var current_frame: Dictionary = frame.update(contacts,camera_right,delta)
	if requested!=_previous_requested:
		if requested.dot(_previous_requested)<-.01:_voluntary_reversals += 1
		_input_frame_id += 1
		_input_timestamp = controller.simulation_time
		_origin_frame = current_frame.duplicate(true)
		_previous_requested = requested
	var command := requested if enabled and (not ids.is_empty() or feet>0) else Vector2.ZERO
	input = input.move_toward(command,delta/maxf(.001,tuning.traversal_input_ramp_s))
	if not enabled or ids.is_empty() and feet==0:input = Vector2.ZERO
	# The material support frame transports intent. Camera orbit alone cannot
	# rotate it; real support geometry may change it through the finite filter.
	var direction: Vector3 = (frame.right*input.x+frame.up*input.y).limit_length(1.0)
	var desired: Vector3 = direction*tuning.traversal_speed_m_s
	var relative_velocity: Vector3 = controller.torso.linear_velocity-support_velocity/maxf(.000001,support_weight)
	var acceleration: Vector3 = ((desired-relative_velocity.slide(frame.normal))*tuning.traversal_velocity_response).limit_length(tuning.traversal_plan_max_acceleration)
	# Plan requested displacement, not extrapolated falling displacement. Using
	# v_actual here would extend the arm when W is pressed during a downward
	# swing, a positive feedback error especially visible at60Hz.
	var body_step: Vector3 = desired*tuning.traversal_prediction_s+acceleration*(.5*tuning.traversal_prediction_s*tuning.traversal_prediction_s)
	# While real ground owns walk, it alone requests horizontal translation.
	if grounded:body_step = Vector3.UP*body_step.y+body_step.slide(Vector3.UP)*(1.0-ground_authority)
	# No zero-input momentum cancellation target: neutral means hold achieved
	# actuator posture, while physical swing/damping continues independently.
	if command.length_squared()<.00001:body_step = Vector3.ZERO
	body_step = body_step.limit_length(tuning.traversal_max_target_offset)
	var reason := "HOLD_ACHIEVED_POSTURE"
	if not enabled:reason = "FEATURE_DISABLED"
	elif ids.is_empty():reason = "TARGET_PENDING_ONLY" if controller.hands.any(func(hand):return hand.state=="REACHING") else "NO_REAL_SUPPORT"
	elif slipping:reason = "GRIP_LIMIT_SLIPPING"
	var telemetry: Dictionary = controller.telemetry()
	var saturated: bool = float(telemetry.get("total_force",0.0))>tuning.total_pull_force_budget*.94 or float(telemetry.get("budget_scale",1.0))<.90
	var feasible := false
	for id in ids:
		var axis: Vector3 = (controller.hands[id].anchor_world-controller.get_shoulder_world(id)).normalized()
		feasible = feasible or absf(axis.dot(direction))>.12
	if not feasible and direction.length()>.01:body_step = Vector3.ZERO
	if saturated:reason = "ARM_FORCE_SATURATED"
	elif not feasible and direction.length()>.01:reason = "DIRECTION_UNACTUATABLE_AXIAL_SWING_ONLY"
	elif direction.length()>.01:reason = "BOUNDED_TARGET_TRACKING"
	var rates := {}
	var accelerations := {}
	var goals := {}
	for id in ids:
		var hand: Dictionary = controller.hands[id]
		if not records.has(id) or records[id].anchor!=hand.anchor:
			records[id] = {"anchor":hand.anchor,"hold":hand.rest_length,"velocity":0.0,"previous_actual":hand.actual_length,"stall":0.0,"last_direction":0,"idle":0.0}
		var record: Dictionary = records[id]
		var actual: float = hand.actual_length
		var rest: float = hand.rest_length
		var progress: float = absf(actual-float(record.previous_actual))/maxf(delta,.000001)
		record.stall = record.stall+delta if absf(actual-rest)>tuning.traversal_tracking_tolerance and progress<.025 else 0.0
		record.previous_actual = actual
		record.idle = record.idle+delta if command.length_squared()<.00001 else 0.0
		# Capture achieved contraction/extension, never an unachieved request.
		# A short settling window cannot ratchet passive elastic sag forever.
		if record.idle<.25:
			if record.last_direction<0 and actual<=rest+tuning.traversal_hold_tolerance:record.hold = minf(record.hold,rest)
			elif record.last_direction>0:record.hold = maxf(record.hold,minf(rest,actual-tuning.traversal_hold_tolerance))
		var shoulder: Vector3 = controller.get_shoulder_world(id)
		var geometric_change: float = (shoulder+body_step).distance_to(hand.anchor_world)-actual
		var goal: float = record.hold+geometric_change
		if command.length()>.001:
			# Bound remaining strain to actual geometry; holding a blocked command
			# for minutes does not integrate minutes of target displacement.
			goal = clampf(goal,actual-tuning.traversal_max_target_offset,actual+tuning.traversal_max_target_offset)
			if absf(geometric_change)>.00001:record.last_direction = int(signf(geometric_change))
		if record.stall>tuning.traversal_stall_confirm_s:
			reason = "POSTURE_TARGET_NOT_REACHED"
		if not enabled or slipping or saturated or record.stall>tuning.traversal_stall_confirm_s:goal = rest
		goal = clampf(goal,tuning.min_arm_length,tuning.max_arm_length)
		var error: float = goal-rest
		var target_velocity: float = signf(error)*minf(tuning.traversal_target_max_rate,maxf(0.0,sqrt(2.0*tuning.traversal_target_max_acceleration*absf(error))-tuning.traversal_target_max_acceleration*delta))
		if hand.blend_elapsed<tuning.grip_blend_duration or not enabled:target_velocity = 0.0
		var previous_velocity: float = record.velocity
		record.velocity = move_toward(previous_velocity,target_velocity,tuning.traversal_target_max_acceleration*delta)
		if enabled:hand.rest_length = clampf(rest+record.velocity*delta,tuning.min_arm_length,tuning.max_arm_length)
		rates[id] = (hand.rest_length-rest)/delta
		accelerations[id] = (record.velocity-previous_velocity)/delta
		goals[id] = goal
	for id in records.keys():
		if id not in ids:records.erase(id)
	var climb_share := 1.0-ground_authority
	swing = direction*climb_share if enabled and not ids.is_empty() and not slipping else Vector3.ZERO
	# Ground motor owns horizontal walk. Upward traction can start while feet
	# still bear weight, avoiding an authority=1 / zero hand load deadlock.
	foot_contract = maxf(0.0,input.y) if enabled and (not ids.is_empty() or feet>0) else 0.0
	foot_extend = maxf(0.0,-input.y) if enabled and (not ids.is_empty() or feet>0) else 0.0
	var ground_diagnostics := ground.duplicate(true)
	ground_diagnostics.erase("support") # Immutable telemetry must outlive scene bodies.
	data = {"enabled":enabled,"support_mode":mode,"frame":current_frame,"movement_intent_local":input,"requested_input":requested,
		"movement_intent_world":direction,"intent_strength":input.length(),"desired_com_velocity":desired,"virtual_acceleration":acceleration,
		"actual_relative_velocity":relative_velocity,"planned_arm_rest_lengths":goals,"target_rates":rates,"target_accelerations":accelerations,
		"movement_block_reason":reason,"actual_hand_ids":ids,"actual_foot_count":feet,"ground":ground_diagnostics,"recommended_climb_share":climb_share,
		"input_frame_id":_input_frame_id,"input_timestamp":_input_timestamp,"originating_support_frame":_origin_frame.duplicate(true),"input_ramp_s":tuning.traversal_input_ramp_s,
		"voluntary_reversals":_voluntary_reversals,"actual_com_displacement":controller.torso.global_position-_start_position,
		"actual_height_gain":controller.torso.global_position.y-_start_position.y,"actuator_saturated":saturated,
		"planned_foot_action":Vector2(foot_contract,foot_extend),"aim_input_does_not_change_length":true,"tier":1,
		"planner_cpu_usec":Time.get_ticks_usec()-began}
