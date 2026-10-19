extends Node
signal sample_ready(delta: float)
signal transfer_event(event: Dictionary)
const Tuning = preload("res://features/grip_up/resources/climbing_tuning.gd")
const Anchor = preload("res://features/grip_up/scripts/grip_anchor.gd")
const Actuator = preload("res://features/grip_up/scripts/arm_actuator.gd")
const CapturePredictor = preload("res://features/grip_up/scripts/grip_capture_predictor.gd")
const CaptureEvaluator = preload("res://features/grip_up/scripts/grip_capture_evaluator.gd")
const FootSolver = preload("res://features/grip_up/scripts/foot_contact_solver.gd")
const FootProfile = preload("res://features/grip_up/resources/foot_tuning.gd")
const SupportedSwing = preload("res://features/grip_up/scripts/supported_swing.gd")
const PosturePlanner = preload("res://features/grip_up/scripts/support_posture_planner.gd")
const TargetCoordinator = preload("res://features/grip_up/scripts/arm_target_coordinator.gd")
const TransferDiagnostics = preload("res://features/grip_up/scripts/transfer_diagnostics.gd")
const TwistRefinement = preload("res://features/grip_up/scripts/supported_twist_refinement.gd")
const PostureRefinement = preload("res://features/grip_up/scripts/supported_posture_refinement.gd")
const IntentLocomotion = preload("res://features/grip_up/scripts/intent_locomotion_coordinator.gd")
const PendingGripTarget = preload("res://features/grip_up/scripts/pending_grip_target.gd")
const ReachableGripResolver = preload("res://features/grip_up/scripts/reachable_grip_resolver.gd")
const LedgeTransfer = preload("res://features/grip_up/scripts/ledge_transfer.gd")
const PalmSupport = preload("res://features/grip_up/scripts/palm_support_solver.gd")
var _held_targets: Dictionary = {}
var _held_target_serial := 0
var transfer_assist_enabled := false
var posture_variant := 0
var _twist_refinement = TwistRefinement.new()
var _posture_refinement = PostureRefinement.new()
var transfer_journal = TransferDiagnostics.new()
var transfer_diagnostics_enabled := false:
	set(value):
		if transfer_diagnostics_enabled!=value:
			transfer_diagnostics_enabled = value
			transfer_journal.reset()
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
var feet_solver: RefCounted
var free_foot_positions: Array[Vector3] = []
var grounded_for_walking := false
var intent_climb_enabled := false
var intent_locomotion = IntentLocomotion.new()
var intent_auto_mantle_enabled := false
var ledge_transfer = LedgeTransfer.new()
var physics_mantle_v08_enabled := false
var palm_compression_enabled := false
var palm_solver = PalmSupport.new()
var control_profile := 0
var posture_policy := 0
var independent_aim_enabled := true
var posture_assist_enabled := true
var supported_wasd_swing_enabled := true
var posture_tilt_assist_enabled := true
var experimental_launch_enabled := false
var _arm_deltas: Dictionary = {}
var _swing_requested := Vector3.ZERO
var _swing_reference_right := Vector3.RIGHT
var _experimental_heading_active := false
var _supported_swing = SupportedSwing.new()
var _swing_torque := Vector3.ZERO
var _contextual_requested := Vector2.ZERO
var _contextual_filtered := Vector2.ZERO
var _contextual_actuation := Vector2.ZERO
var _contextual_right := Vector3.RIGHT
var _contextual_world_filtered := Vector3.ZERO
var _contextual_holds: Dictionary = {}
var _free_hand_targets: Dictionary = {}
var posture_planner = PosturePlanner.new()
var posture_coordinator = TargetCoordinator.new()
var _posture_signature := ""
var _posture_tilt_blend := 0.0
var _posture_tilt_torque := Vector3.ZERO

func configure(body: RigidBody3D, configuration: Resource = null) -> void:
	torso = body
	if configuration != null:
		tuning = configuration
	reset_state()

func reset_state() -> void:
	palm_solver.reset()
	ledge_transfer.reset()
	intent_locomotion.reset()
	_held_targets.clear()
	_twist_refinement.reset()
	_posture_refinement.reset()
	transfer_journal.reset()
	posture_planner.reset()
	posture_coordinator.reset()
	_posture_signature = ""
	_posture_tilt_blend = 0.0
	_posture_tilt_torque = Vector3.ZERO
	_clear_contextual_state()
	_arm_deltas.clear()
	_swing_requested = Vector3.ZERO
	_supported_swing.reset()
	_swing_torque = Vector3.ZERO
	_experimental_heading_active = false
	if feet_solver!=null:
		feet_solver.reset()
	free_foot_positions.clear()
	grounded_for_walking = false
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

func configure_feet(hips: Array[Vector3], rest_feet: Array[Vector3], lengths: Array[float], clearances: Array[float]) -> void:
	feet_solver = FootSolver.new()
	feet_solver.configure(torso,FootProfile.new(),hips,rest_feet,lengths,clearances)

func set_climb_intent(contract: float, extend: float, bias: float, view_right: Vector3 = Vector3.RIGHT) -> void:
	if control_profile in [1,2,3,4]:
		_intent_target = Vector3.ZERO
		_contract = 0.0
		_extend = 0.0
		_bias = 0.0
		return
	_intent_target = Vector3(clampf(contract, 0.0, 1.0),clampf(extend, 0.0, 1.0),clampf(bias, -1.0, 1.0))
	if tuning.intent_response_time <= 0.0:
		_contract = _intent_target.x
		_extend = _intent_target.y
		_bias = _intent_target.z
	if view_right.is_finite():
		var horizontal := view_right.slide(Vector3.UP)
		if horizontal.length_squared()>0.0001:
			_view_right = horizontal.normalized()

func set_control_profile(profile: int) -> void:
	var next := clampi(profile,0,4)
	if next == control_profile:
		return
	for hand_id in _held_targets.keys():
		if _held_targets[hand_id].active and get_hand_state(hand_id)=="REACHING":
			release_grip(hand_id,"input_released")
	control_profile = next
	palm_solver.reset()
	ledge_transfer.reset()
	intent_locomotion.reset()
	_twist_refinement.reset()
	_posture_refinement.reset()
	transfer_journal.reset()
	_posture_tilt_blend = 0.0
	_posture_tilt_torque = Vector3.ZERO
	posture_planner.reset()
	posture_coordinator.reset()
	_posture_signature = ""
	_clear_contextual_state()
	_arm_deltas.clear()
	_swing_requested = Vector3.ZERO
	_supported_swing.reset()
	_swing_torque = Vector3.ZERO
	_experimental_heading_active = false
	_intent_target = Vector3.ZERO
	_contract = 0.0
	_extend = 0.0
	_bias = 0.0
	cancel_launch()

func set_traversal_input(value: Vector2, camera_right: Vector3 = Vector3.RIGHT) -> void:
	intent_locomotion.set_input(value,camera_right)

func is_palm_hand(id:int)->bool:
	return palm_solver.is_palm(id)

func set_ground_support(snapshot: Dictionary) -> void:
	intent_locomotion.ground = snapshot.duplicate(true)

func set_posture_policy(policy: int) -> void:
	var next := clampi(policy,0,2)
	if next!=posture_policy:
		posture_policy = next
		_posture_signature = ""
		posture_coordinator.reset()

func set_posture_variant(variant: int) -> void:
	posture_variant = clampi(variant,0,2)

func _update_independent_posture(attached: Array[int], delta: float) -> void:
	if attached.is_empty() or posture_policy==0 or not posture_assist_enabled or not independent_aim_enabled or _launch_state!="IDLE":
		posture_coordinator.reset()
		_posture_signature = ""
		for id in attached:
			hands[id]["planned_length"] = hands[id]["rest_length"]
			hands[id]["posture_reason"] = "hold_current_length" if posture_policy==0 else "posture_assistance_inactive"
			hands[id]["posture_event"] = 0
		return
	var key: String = posture_planner.signature(self,attached,posture_policy)
	if key!=_posture_signature:
		_posture_signature = key
		posture_coordinator.begin(posture_planner.build(self,attached,posture_policy),self,attached)
	posture_planner.refresh(posture_coordinator.plan)
	posture_coordinator.step(self,delta)
	for id in attached:
		hands[id]["planned_length"] = posture_coordinator.plan.goals.get(id,hands[id]["rest_length"])
		hands[id]["posture_reason"] = posture_coordinator.reason
		hands[id]["posture_event"] = posture_coordinator.plan.event

func queue_arm_length_delta(id: int, metres: float) -> bool:
	if control_profile != 1 or id < 0 or id >= hands.size() or not is_finite(metres) or hands[id]["state"] not in ["ATTACHED","SLIPPING"]:
		return false
	var anchor = hands[id]["anchor"]
	if not _arm_deltas.has(id) or _arm_deltas[id].anchor != anchor:
		_arm_deltas[id] = {"anchor":anchor,"metres":0.0}
	_arm_deltas[id].metres += metres
	return true

func clear_drag_requests(id: int = -1) -> void:
	if id < 0:
		_arm_deltas.clear()
	else:
		_arm_deltas.erase(id)

func _clear_contextual_state() -> void:
	_contextual_requested = Vector2.ZERO
	_contextual_filtered = Vector2.ZERO
	_contextual_actuation = Vector2.ZERO
	_contextual_world_filtered = Vector3.ZERO
	_contextual_holds.clear()
	_free_hand_targets.clear()

func set_contextual_effort(effort: Vector2, reference_right: Vector3 = Vector3.RIGHT) -> void:
	if control_profile in [3,4]:
		return
	_contextual_requested = effort.limit_length(1.0) if effort.is_finite() else Vector2.ZERO
	if reference_right.is_finite():
		var right := reference_right.slide(Vector3.UP)
		if right.length_squared()>0.0001:
			_contextual_right = right.normalized()

func set_free_hand_target(id: int, world_point: Vector3) -> bool:
	if control_profile != 2 or id < 0 or id >= hands.size() or hands[id]["state"] not in ["FREE","RELEASED"] or not world_point.is_finite():
		return false
	_free_hand_targets[id] = world_point
	return true

func clear_free_hand_targets(id: int = -1) -> void:
	if id < 0:
		_free_hand_targets.clear()
	else:
		_free_hand_targets.erase(id)

func _apply_contextual_arm(id: int, delta: float) -> void:
	var hand: Dictionary = hands[id]
	if not _contextual_holds.has(id) or _contextual_holds[id].anchor != hand["anchor"]:
		_contextual_holds[id] = {"anchor":hand["anchor"],"length":hand["rest_length"],"direction":0}
	var hold: Dictionary = _contextual_holds[id]
	# Capture only geometry already reached, allowing the existing elastic
	# deformation under load. An obstructed torso cannot wind the target down
	# indefinitely. Pointer displacement is never integrated into this length.
	var tolerance: float = minf(maxf(0.0,tuning.contextual_hold_tolerance),tuning.max_elastic_extension)
	var effort := _contextual_filtered.y
	if absf(effort)>0.001:
		hold.direction = 1 if effort>0.0 else -1
	if hold.direction>0 and hand["actual_length"] <= hand["rest_length"]+tolerance:
		hold.length = minf(hold.length,hand["rest_length"])
	elif hold.direction<0:
		# A longer requested rope is not an achieved lowering. Capture only
		# the actual extension, excluding loaded elastic stretch; a floor or
		# obstacle therefore cannot wind up a future drop.
		hold.length = maxf(hold.length,minf(hand["rest_length"],hand["actual_length"]-tolerance))
	var target: float = hold.length
	if effort>0.001:
		target = minf(hold.length,hand["actual_length"]-effort*tuning.contextual_pull_offset)
	elif effort< -0.001:
		target = maxf(hold.length,hand["actual_length"]-effort*tuning.contextual_pull_offset)
	target = clampf(target,tuning.min_arm_length,tuning.max_arm_length)
	var previous: float = hand["rest_length"]
	var rate: float = tuning.arm_target_max_rate_m_s
	if target>previous:
		rate = minf(rate,tuning.contextual_extension_max_rate_m_s)
		if effort< -0.001:
			# Gravity already supplies the lowering work. Fade the allowed
			# extension rate with transient effort, so a tiny filter tail cannot
			# keep following the loaded arm at full lowering speed.
			rate *= absf(effort)
	hand["rest_length"] = move_toward(previous,target,maxf(0.0,rate)*delta)
	_contextual_actuation[id] = (hand["rest_length"]-previous)/delta

func set_swing_intent(world_dir: Vector3, reference_right: Vector3 = Vector3.RIGHT) -> void:
	_swing_requested = world_dir.slide(Vector3.UP).limit_length(1.0) if world_dir.is_finite() else Vector3.ZERO
	if reference_right.is_finite():
		var right := reference_right.slide(Vector3.UP)
		if right.length_squared()>0.0001:
			_swing_reference_right = right.normalized()

func get_shoulder_world(id: int) -> Vector3:
	if not is_instance_valid(torso):
		return Vector3.ZERO
	var local: Vector3 = tuning.shoulder_left if id == 0 else tuning.shoulder_right
	return (torso.global_transform if torso.is_inside_tree() else torso.transform) * local

func request_launch_charge(pressed: bool) -> bool:
	if control_profile in [1,2,3,4] and not experimental_launch_enabled:
		return false
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

func request_held_grip(id: int, support: PhysicsBody3D, world_point: Vector3, normal: Vector3) -> bool:
	if not tuning.allow_out_of_reach_grip_targets:
		return request_grip(id,support,world_point,normal)
	if _transfer_enabled():
		transfer_journal.begin_attempt(self,id,support,world_point,normal)
		_publish_transfer_events()
	metrics["attempts"] += 1
	if id not in [0,1] or not is_instance_valid(torso) or not is_instance_valid(support) or support==torso:
		return _reject("invalid_hand_or_support")
	if get_hand_state(id) not in ["FREE","RELEASED"]:
		return _reject("release_hand_before_regrip")
	if not support is StaticBody3D and not support is RigidBody3D:
		return _reject("unsupported_body_type")
	if not support.is_inside_tree() or not bool(support.get_meta("grippable",true)):
		return _reject("surface_not_grippable")
	if not world_point.is_finite() or not normal.is_finite() or normal.length_squared()<.5:
		return _reject("invalid_surface_point")
	var original_point := world_point
	var original_normal := normal.normalized()
	var resolution: Dictionary = {}
	if control_profile==4:
		resolution = ReachableGripResolver.new().resolve(torso,get_shoulder_world(id),support,world_point,normal,get_max_reach(),tuning.allowed_grip_surface_mask)
		if resolution.resolved:
			world_point = resolution.point
			normal = resolution.normal
	var hand: Dictionary = hands[id]
	var selected = Anchor.new(support,world_point,normal.normalized())
	selected.use_actual_center_of_mass = true
	var pending = PendingGripTarget.new()
	_held_target_serial += 1
	var journal_attempt: int = int(transfer_journal.last_by_hand.get(id,{}).get("attempt_id",-1)) if _transfer_enabled() else -1
	pending.configure(selected,Transform3D(torso.global_basis.orthonormalized(),get_shoulder_world(id)),hand.hand_world,simulation_time,_held_target_serial,get_max_reach(),journal_attempt)
	if control_profile==4:
		pending.snapshot.merge({"original_selection_world":original_point,"original_selection_local":support.to_local(original_point),
			"original_selection_normal_local":support.global_basis.inverse()*original_normal,"original_selection_distance":get_shoulder_world(id).distance_to(original_point),
			"contact_resolution_applied":resolution.resolved,"contact_resolution_reason":resolution.reason,
			"contact_resolution_blocker_id":resolution.blocker_id,"selection_policy":"REACHABLE_SAME_COLLIDER_ON_REQUEST"},true)
		if resolution.resolved:
			pending.snapshot["resolved_contact_world_at_selection"] = world_point
			pending.snapshot["resolved_contact_distance"] = resolution.distance
	if Vector3(hand.get("release_normal",Vector3.ZERO)).length_squared()>.5 and Vector3(hand.hand_world).distance_to(hand.anchor_world)<.015:
		pending.set_departure(hand.hand_world,hand.release_normal,tuning.hand_surface_approach_distance)
	_held_targets[id] = pending
	_free_hand_targets.erase(id)
	hand.merge({"state":"REACHING","anchor":selected,"support":support,"elapsed":0.0,
		"target_world":world_point,"anchor_world":world_point,"actual_length":get_shoulder_world(id).distance_to(world_point),
		"force":Vector3.ZERO,"reaction_force":Vector3.ZERO,"allocation":0.0,"reason":"",
		"held_target_pending":true,"predictive_wait":false},true)
	hand["capture"] = {"input_time":simulation_time,"buffered":false,"persistent_target":true,"out_of_reach_selection":hand.actual_length>get_max_reach(),
		"predicted_entry_time":-1.0,"predicted_contact_time":-1.0,"predicted_target":world_point,
		"predicted_target_time":-1.0,"actual_arrival":-1.0,"failure_reason":""}
	if control_profile==4:
		hand["capture"].merge({"out_of_reach_selection":get_shoulder_world(id).distance_to(original_point)>get_max_reach(),
			"original_selection_world":original_point,"original_selection_local":support.to_local(original_point),
			"contact_resolution_applied":resolution.resolved,"contact_resolution_reason":resolution.reason},true)
	last_rejection = ""
	if _transfer_enabled():
		var selection_distance: float = get_shoulder_world(id).distance_to(original_point) if control_profile==4 else hand.actual_length
		transfer_journal.observe(self,id,"TARGET_SELECTED_OUT_OF_REACH" if selection_distance>get_max_reach() else "TARGET_SELECTED_IN_REACH","TRANSIT","held_material_target_selected",{"pending":pending.diagnostics()})
		_publish_transfer_events()
	return true

func set_hand_held(id: int, held: bool, reason: String = "input_released") -> void:
	if not _held_targets.has(id) or not _held_targets[id].active:
		return
	_held_targets[id].held = held
	if not held:release_grip(id,reason)

func pending_diagnostics(id: int) -> Dictionary:
	return _held_targets[id].diagnostics() if _held_targets.has(id) else {"active":false,"held":false}

func _try_held_contact(id: int) -> void:
	var hand: Dictionary = hands[id]
	var pending = _held_targets[id]
	if not pending.held or not pending.active or not pending.anchor.is_valid():return
	var data: Dictionary = pending.diagnostics()
	if not data.endpoint_valid or data.blocked or not data.physical_in_reach:return
	if Vector3(hand.hand_world).distance_to(pending.anchor.world_point())>.000001:return
	# Current geometry authorizes. No forecast, time horizon, label hysteresis
	# or relative-speed risk estimate can replace this physical contact test.
	var capture: Dictionary = capture_evaluator.evaluate(self,id)
	if not capture.accepted:
		pending.snapshot["contact_rejection_reason"] = capture.reason
		return
	var point: Vector3 = pending.anchor.world_point()
	var separation := get_shoulder_world(id).distance_to(point)
	var previous_supports := _attached_ids().size()
	hand["capture"].merge(capture,true)
	hand["capture"]["actual_arrival"] = simulation_time-pending.selected_time
	hand["capture"]["prediction_error"] = -1.0
	hand.merge({"state":"ATTACHED","hand_world":point,"anchor_world":point,"target_world":point,
		"actual_length":separation,"rest_length":clampf(separation,tuning.min_arm_length,tuning.max_arm_length),
		"blend_elapsed":0.0,"overload_time":0.0,"slip_elapsed":0.0,"recovery_time":0.0,
		"allocation":1.0 if previous_supports==0 else 0.0,"held_target_pending":false,"reason":""},true)
	pending.attached(simulation_time,separation,hand.rest_length,hand.capture)
	metrics["attaches"] += 1
	if _transfer_enabled():
		transfer_journal.observe(self,id,"HAND_CONTACT_VALID","CONTACT","actual_held_material_point_contact",{"pending":pending.diagnostics()})
		_publish_transfer_events()

func request_buffered_grip(id: int, support: PhysicsBody3D, world_point: Vector3, normal: Vector3) -> bool:
	if not tuning.predictive_grip:
		return request_grip(id,support,world_point,normal)
	return _request_grip(id,support,world_point,normal,true)

func _request_grip(id: int, support: PhysicsBody3D, world_point: Vector3, normal: Vector3, predictive: bool) -> bool:
	if _transfer_enabled():
		transfer_journal.begin_attempt(self,id,support,world_point,normal)
		_publish_transfer_events()
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
	_free_hand_targets.erase(id)
	hand["departing_surface"] = departure_normal.length_squared()>0.5 and Vector3(hand["hand_world"]).distance_to(hand["anchor_world"])<0.015
	hand["departure_world"] = hand["hand_world"]+departure_normal*tuning.hand_surface_approach_distance
	hand["strict_departure_sweep"] = false
	if control_profile == 2 and not hand["departing_surface"]:
		var shoulder := get_shoulder_world(id)
		var previous: Vector3 = hand["hand_world"]
		var approach: Vector3 = world_point+normal.normalized()*tuning.hand_surface_approach_distance
		approach = shoulder+(approach-shoulder).limit_length(get_max_reach())
		var query := PhysicsRayQueryParameters3D.create(previous,approach)
		query.exclude = [torso.get_rid()]
		query.collision_mask = tuning.allowed_grip_surface_mask
		query.hit_from_inside = true
		var hit := torso.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and previous.distance_to(world_point)>0.003:
			# A FREE hand may be beside a rounded hold while the newly selected
			# point is on its front. The diagonal to that front approach can cut
			# through the flank. Fold back along the existing free arm first, then
			# approach from the shoulder-visible side. Every actual leg is swept.
			hand["departure_world"] = shoulder+(previous-shoulder).normalized()*minf(tuning.min_arm_length,previous.distance_to(shoulder)*0.5)
			hand["departing_surface"] = true
			hand["strict_departure_sweep"] = true
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
	if _transfer_enabled():
		transfer_journal.accept(self,id)
		_publish_transfer_events()
	return true

func _reject(reason: String) -> bool:
	if _transfer_enabled():
		transfer_journal.reject(self,reason)
		_publish_transfer_events()
	last_rejection = reason
	metrics["misses"] += 1
	return false

func release_grip(id: int, reason: String = "manual") -> void:
	if id < 0 or id >= hands.size():
		return
	if _held_targets.has(id) and _held_targets[id].active:
		_held_targets[id].cancel(reason)
	if _transfer_enabled():
		transfer_journal.release(self,id,reason)
		_publish_transfer_events()
	var hand: Dictionary = hands[id]
	palm_solver.release(id)
	if hand.has("palm"):
		hand.contact_mode="FREE"
		hand.palm={"valid":false,"reason":reason,"requested_force":Vector3.ZERO,"applied_force":Vector3.ZERO,"applied_normal":0.0,"applied_tangent":Vector3.ZERO,"reaction_force":Vector3.ZERO}
	_arm_deltas.erase(id)
	_contextual_holds.erase(id)
	_free_hand_targets.erase(id)
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
	hand["held_target_pending"] = false

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
	if hand["state"]=="REACHING" and hand.get("held_target_pending",false):
		var pending = _held_targets.get(id)
		if pending==null or not pending.held or not tuning.allow_out_of_reach_grip_targets:
			release_grip(id,"input_released")
			return
		if not pending.anchor.is_valid() or not bool(pending.anchor.support_body().get_meta("grippable",true)):
			release_grip(id,"support_invalidated")
			return
		var before: Dictionary = pending.diagnostics()
		hand["hand_world"] = pending.step(torso,Transform3D(torso.global_basis.orthonormalized(),shoulder),hand.hand_world,get_max_reach(),tuning.hand_reach_speed,tuning.allowed_grip_surface_mask,simulation_time,delta,tuning.hand_surface_approach_distance,tuning.min_arm_length,tuning.pending_reach_label_hysteresis)
		hand["target_world"] = pending.anchor.world_point()
		hand["anchor_world"] = hand["target_world"]
		hand["actual_length"] = shoulder.distance_to(hand["target_world"])
		var after: Dictionary = pending.diagnostics()
		if _transfer_enabled():
			if before.label_in_reach!=after.label_in_reach:
				# Leaving is reversible pending information, not a failed transfer.
				transfer_journal.observe(self,id,"TARGET_ENTERED_REACH" if after.label_in_reach else "TARGET_LEFT_REACH_PENDING","TRANSIT","pending_reach_label_transition",{"pending":after})
			if before.blocked!=after.blocked:
				transfer_journal.observe(self,id,"HAND_PATH_BLOCKED" if after.blocked else "HAND_PATH_CLEAR","TRANSIT","pending_path_transition",{"pending":after})
			if before.missed_window_count!=after.missed_window_count:
				transfer_journal.observe(self,id,"HAND_WINDOW_MISSED","TRANSIT",after.last_window_reason,{"pending":after})
			_publish_transfer_events()
		if not after.endpoint_valid:
			if _transfer_enabled():
				transfer_journal.observe(self,id,"WORKSPACE_SWEEP_CONFLICT","TRANSIT","no_collision_free_anatomical_finite_segment",{"pending":after})
				_publish_transfer_events()
			release_grip(id,"WORKSPACE_SWEEP_CONFLICT")
		else:
			_try_held_contact(id)
		return
	if hand["state"] == "RELEASED":
		hand["state"] = "FREE"
	if hand["state"] == "FREE":
		var rest_offset: Vector3 = tuning.free_hand_rest_left if id == 0 else tuning.free_hand_rest_right
		var rest: Vector3 = shoulder + torso.global_basis * rest_offset
		if control_profile == 2 and _free_hand_targets.has(id):
			rest = shoulder+(Vector3(_free_hand_targets[id])-shoulder).limit_length(get_max_reach())
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
		if control_profile == 2:
			rest = shoulder+(rest-shoulder).limit_length(get_max_reach())
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
			if control_profile == 2:
				# Contact clearance must not add a hidden jump to a finite gesture.
				next = previous+(next-previous).limit_length(tuning.hand_reach_speed*delta)
		hand["hand_world"] = next
		if _held_targets.has(id) and not _held_targets[id].active and not _held_targets[id].snapshot.get("endpoint_valid",true):
			if shoulder.distance_to(next)<=get_max_reach()+.00005:
				_held_targets[id].snapshot.endpoint_valid = true
				_held_targets[id].snapshot.workspace_valid = true
		return
	var anchor = hand["anchor"]
	if anchor == null or not anchor.is_valid():
		release_grip(id, "support_invalidated")
		return
	if _held_targets.has(id) and _held_targets[id].active and anchor==_held_targets[id].anchor:
		if not _held_targets[id].held or not bool(anchor.support_body().get_meta("grippable",true)):
			release_grip(id,"input_released" if not _held_targets[id].held else "support_invalidated")
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
		query.hit_from_inside = not hand.get("departing_surface",false) or hand.get("strict_departure_sweep",false)
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
		elif not hand.get("approaching_surface", false) and next.distance_to(point) <= (0.000001 if tuning.predictive_grip or control_profile in [1,2,3,4] else tuning.attach_distance_tolerance):
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
	elif _held_targets.has(id) and _held_targets[id].active and anchor==_held_targets[id].anchor:
		_held_targets[id].update_attached(shoulder,point,get_max_reach(),hand.state)

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
			var baseline_twist := Vector3.ZERO
			if authority>0.000001:
				var error := current_right.normalized().signed_angle_to(target_right.normalized(),axis)
				var moment: float = error*tuning.twist_stiffness-torso.angular_velocity.dot(axis)*tuning.twist_damping
				# Only longitudinal trunk twist is stabilized. Pendular tilt,
				# shoulder forces and opposite support reaction remain physical.
				baseline_twist = axis*(moment*authority*engagement)
				assist += baseline_twist
			if control_profile==3 and _twist_refinement.blend>0.0:
				assist += _twist_refinement.correction(axis,current_right,baseline_twist,torso.angular_velocity,engagement,tuning)
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
		var diagnostic_previous: Vector3 = hands[id]["hand_world"] if _transfer_enabled() else Vector3.ZERO
		var diagnostic_state: String = hands[id]["state"] if _transfer_enabled() else ""
		_update_hand(id, delta)
		if _transfer_enabled():
			transfer_journal.advance(self,id,diagnostic_previous,delta)
			if diagnostic_state=="REACHING" and hands[id]["state"]=="ATTACHED":
				transfer_journal.contact(self,id)
				_publish_transfer_events()
	_advance_launch(delta)
	palm_solver.prepare(self,delta,control_profile==4 and physics_mantle_v08_enabled and palm_compression_enabled and _launch_state=="IDLE")
	var attached: Array[int] = _attached_ids()
	var torque_attached:Array[int]=attached.duplicate()
	if palm_solver.enabled:
		# A purely axial palm is not an adhesive gripper joint. The old20Nm
		# assist may react only through remaining actual TRACTION hands.
		torque_attached=torque_attached.filter(func(id):return not is_palm_hand(id))
	if control_profile == 4:
		ledge_transfer.step(self,delta,intent_auto_mantle_enabled and intent_climb_enabled and _launch_state=="IDLE")
		intent_locomotion.step(self,delta,intent_climb_enabled and _launch_state=="IDLE")
	if control_profile == 3:
		_update_independent_posture(attached,delta)
	if control_profile in [1,2,3,4]:
		if attached.is_empty():
			_experimental_heading_active = false
			_supported_swing.reset()
		elif not _experimental_heading_active:
			_view_right = _swing_reference_right
			_experimental_heading_active = true
	if control_profile==3:
		_twist_refinement.update(self,attached,delta,transfer_assist_enabled and posture_variant in [1,2])
	_contextual_actuation = Vector2.ZERO
	if control_profile == 2:
		if attached.is_empty():
			_contextual_filtered = Vector2.ZERO
			_contextual_world_filtered = Vector3.ZERO
			_contextual_holds.clear()
		else:
			var response: float = 1.0-exp(-delta/maxf(0.001,tuning.contextual_response_time))
			_contextual_filtered = _contextual_filtered.lerp(_contextual_requested,response)
			# Filter lateral effort in world space: orbiting a camera while a
			# released gesture decays must not rotate that residual effort.
			_contextual_world_filtered = _contextual_world_filtered.lerp(_contextual_right*_contextual_requested.x,response)
	var forces: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var palm_releases:Dictionary={}
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
		if control_profile==3 and posture_policy==2 and not posture_coordinator.plan.is_empty() and posture_coordinator.plan.feasible:
			desired = posture_coordinator.plan.allocations.get(id,desired)
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
		if control_profile == 1 and _arm_deltas.has(id) and _arm_deltas[id].anchor == hand["anchor"]:
			var change: float = clampf(_arm_deltas[id].metres,-maxf(0.0,tuning.arm_target_max_rate_m_s)*delta,maxf(0.0,tuning.arm_target_max_rate_m_s)*delta)
			hand["rest_length"] = clampf(hand["rest_length"]+change,tuning.min_arm_length,tuning.max_arm_length)
		if control_profile == 2 and _launch_state == "IDLE":
			_apply_contextual_arm(id,delta)
		hand["blend_elapsed"] += delta
		var blend: float = smoothstep(0.0, maxf(0.001, tuning.grip_blend_duration), hand["blend_elapsed"])
		var effort: float = hand["allocation"]
		var result:Dictionary
		var raw:float
		if is_palm_hand(id):
			result=palm_solver.evaluate(self,id,tuning.arm_stiffness*effort,tuning.arm_damping*effort,delta,blend)
			raw=Vector3(result.force).length()
			if result.release_reason!="":palm_releases[id]=result.release_reason
		else:
			result=Actuator.evaluate(torso, get_shoulder_world(id), hand["anchor"], hand["rest_length"], tuning.arm_stiffness * effort, tuning.arm_damping * effort, tuning.max_length_error, delta)
			raw=minf(result["tension"] * blend, tuning.max_force_per_arm)
		raw_tensions[id] = raw
		if hand["state"] == "SLIPPING":
			raw *= tuning.slip_force_multiplier
		forces[id] = result["axis"] * raw
		hand["force_axis"] = result["axis"]
		sum_force += forces[id].length()
		moments += (get_shoulder_world(id) - center).cross(forces[id])
	_arm_deltas.clear()
	var assist: Vector3 = _compute_attitude_assist(torque_attached,forces,center,sum_force)
	var mantle_assist:=Vector3.ZERO
	var diagnostic_attitude: Vector3 = assist if _transfer_enabled() else Vector3.ZERO
	var before_tilt_assist := assist
	var baseline_tilt_request := Vector3.ZERO
	_posture_tilt_torque = Vector3.ZERO
	if control_profile==3:
		var tilt_active: bool = posture_tilt_assist_enabled and posture_assist_enabled and posture_policy>0 and not attached.is_empty() and not posture_coordinator.plan.is_empty() and posture_coordinator.plan.feasible
		_posture_tilt_blend = move_toward(_posture_tilt_blend,1.0 if tilt_active else 0.0,delta/.20)
		if tilt_active:
			var target_up: Vector3 = posture_coordinator.plan.desired_pose.basis.y.normalized()
			var tilt_error := torso.global_basis.y.normalized().cross(target_up)
			var tilt_spin := torso.angular_velocity.slide(target_up)
			var manual_authority: float = 1.0-.8*minf(1.0,_swing_requested.length())
			var engaged := 0.0
			var allocated := 0.0
			for id in attached:
				var share: float = hands[id]["allocation"]
				allocated += share
				engaged += share*smoothstep(0.0,maxf(.001,tuning.grip_blend_duration),hands[id]["blend_elapsed"])
			var requested_tilt: Vector3 = (tilt_error*tuning.posture_tilt_stiffness-tilt_spin*tuning.posture_tilt_damping-moments.slide(target_up)*tuning.posture_gravity_moment_compensation)*(_posture_tilt_blend*manual_authority*engaged/maxf(allocated,.000001))
			baseline_tilt_request = requested_tilt
			var base_assist := assist
			assist = (assist+requested_tilt).limit_length(tuning.max_attitude_torque)
			_posture_tilt_torque = assist-base_assist
		var requested_posture: Vector3 = _posture_refinement.evaluate(self,attached,center,moments,sum_force,delta,transfer_assist_enabled and posture_variant==2,_twist_refinement.reference_right)
		if _posture_refinement.blend>0.0:
			var preferred_tilt := baseline_tilt_request.lerp(requested_posture,_posture_refinement.blend)
			assist = (before_tilt_assist+preferred_tilt).limit_length(tuning.max_attitude_torque)
			_posture_tilt_torque = assist-before_tilt_assist
	_swing_torque = Vector3.ZERO
	var support_torque_weights: Dictionary = {}
	var diagnostic_swing_lever := Vector3.ZERO
	var diagnostic_swing_engagement := 0.0
	if control_profile in [1,2,3,4] and not torque_attached.is_empty():
		var lever := Vector3.ZERO
		var support_spin := Vector3.ZERO
		var engaged_weight := 0.0
		var allocation_weight := 0.0
		for id in torque_attached:
			var allocation: float = maxf(0.0,hands[id]["allocation"])
			var weight: float = allocation*smoothstep(0.0,maxf(0.001,tuning.grip_blend_duration),hands[id]["blend_elapsed"])
			support_torque_weights[id] = weight
			engaged_weight += weight
			allocation_weight += allocation
			lever += (get_shoulder_world(id)-center)*weight
			var support: PhysicsBody3D = hands[id]["anchor"].support_body()
			if support is RigidBody3D:
				support_spin += support.angular_velocity*weight
			elif support is StaticBody3D:
				support_spin += support.constant_angular_velocity*weight
		lever /= maxf(engaged_weight,0.000001)
		support_spin /= maxf(engaged_weight,0.000001)
		for id in torque_attached:
			support_torque_weights[id] /= maxf(engaged_weight,0.000001)
		var engagement: float = engaged_weight/maxf(allocation_weight,0.000001)
		if _transfer_enabled():
			diagnostic_swing_lever = lever
			diagnostic_swing_engagement = engagement
		var base_assist := assist
		var requested := _swing_requested
		if control_profile == 4:
			requested = intent_locomotion.swing if supported_wasd_swing_enabled else Vector3.ZERO
		if control_profile == 3 and not supported_wasd_swing_enabled:
			requested = Vector3.ZERO
		if control_profile == 2:
			requested = (requested+_contextual_world_filtered).limit_length(1.0)
		var requested_swing: Vector3 = _supported_swing.evaluate(delta,requested,lever,torso.angular_velocity-support_spin,engagement,tuning)
		assist = (base_assist+requested_swing).limit_length(tuning.max_attitude_torque)
		_swing_torque = assist-base_assist
	# M6 is the final incremental attitude contribution, sharing the same20Nm
	# cap and the existing actual-anchor reaction pair. No separate torso motor.
	if control_profile==4 and intent_auto_mantle_enabled and not torque_attached.is_empty():
		var before_mantle:=assist
		assist=(assist+ledge_transfer.torque).limit_length(tuning.max_attitude_torque)
		mantle_assist=assist-before_mantle
	var foot_requests: Array[Dictionary] = []
	var leg_force := 0.0
	var leg_moment := Vector3.ZERO
	var leg_scale := 1.0
	var leg_budget := 0.0
	if feet_solver!=null:
		for id in mini(2,free_foot_positions.size()):
			feet_solver.set_free_foot_world(id,free_foot_positions[id])
		var climbing: bool = hands.any(func(hand):return hand.state in ["REACHING","ATTACHED","SLIPPING"] and not hand.get("held_target_pending",false))
		var foot_stance: bool = feet_solver.feet.any(func(foot):return foot.state in ["SUPPORTING","SLIDING"]) and not grounded_for_walking
		if control_profile == 4:
			climbing = intent_climb_enabled and attached.any(func(hand_id):return hands[hand_id].state=="ATTACHED")
			var foot_w: float = intent_locomotion.foot_contract
			var foot_s: float = intent_locomotion.foot_extend
			foot_requests = feet_solver.prepare(delta,foot_w,foot_s,0.0,tuning.physical_feet and (climbing or foot_stance) and _launch_state=="IDLE",climbing)
			if intent_locomotion.ground.get("grounded",false):
				var ground_id: int = int(intent_locomotion.ground.get("support_id",0))
				# One contact owner: commit consumes this exact same request list.
				foot_requests = foot_requests.filter(func(request):return request.support.get_instance_id()!=ground_id)
				feet_solver._pending = foot_requests
		else:
			foot_requests = feet_solver.prepare(delta,_contract,_extend,_bias,tuning.physical_feet and (climbing or foot_stance) and _launch_state=="IDLE",climbing)
		leg_budget = feet_solver.tuning.total_force_budget
		for request in foot_requests:
			leg_force += Vector3(request.force).length()
			leg_moment += (Vector3(request.point)-center).cross(Vector3(request.force))
		leg_scale = minf(1.0,leg_budget/maxf(leg_force,0.000001))
		leg_moment *= leg_scale
	# Reused magnitude-sum / resultant-torque allocation from physics_grabber.
	var scale_factor: float = minf(1.0, minf(tuning.total_pull_force_budget / maxf(sum_force, 0.000001), tuning.max_total_torque / maxf((moments + leg_moment + assist).length(), 0.000001)))
	if control_profile==4:
		var ground_torque: Vector3 = intent_locomotion.ground.get("applied_torque",Vector3.ZERO)
		var climb_torque := moments+leg_moment+assist
		if (ground_torque+climb_torque*scale_factor).length()>tuning.max_total_torque and climb_torque.length_squared()>.000001:
			# Solve |ground + s*climb| <= cap with ground already applied this tick.
			var b: float = 2.0*ground_torque.dot(climb_torque)
			var c: float = ground_torque.length_squared()-tuning.max_total_torque*tuning.max_total_torque
			var feasible_scale: float = (-b+sqrt(maxf(0.0,b*b-4.0*climb_torque.length_squared()*c)))/(2.0*climb_torque.length_squared())
			scale_factor = minf(scale_factor,maxf(0.0,feasible_scale))
	if feet_solver!=null:
		feet_solver.commit(leg_scale*scale_factor)
	var diagnostic_applied: Array[Dictionary] = []
	for id in attached:
		var hand: Dictionary = hands[id]
		var force: Vector3 = forces[id] * scale_factor
		hand["force"] = force
		hand["reaction_force"] = -force
		if is_palm_hand(id):palm_solver.admitted(self,id,force)
		if _held_targets.has(id) and _held_targets[id].active and hand["anchor"]==_held_targets[id].anchor:
			var pending_load: Dictionary = _held_targets[id].snapshot
			pending_load.current_force = force.length()
			if pending_load.first_applied_load<0.0:pending_load.first_applied_load = force.length()
			if hand["blend_elapsed"]<=tuning.grip_blend_duration:pending_load.peak_blend_load = maxf(pending_load.peak_blend_load,force.length())
		torso.apply_force(force, get_shoulder_world(id) - torso.global_position)
		var support: PhysicsBody3D = hand["anchor"].support_body()
		if _transfer_enabled():
			# Snapshot before integrity may clear a released hand's diagnostic
			# force. That force was still physically applied on this exact tick.
			diagnostic_applied.append({"id":id,"support":support,"point":hand["anchor_world"],
				"shoulder":get_shoulder_world(id),"force":force,"allocation":hand["allocation"],
				"torque_weight":float(support_torque_weights.get(id,0.0)),"point_velocity":hand["anchor"].point_velocity()})
		if support is RigidBody3D:
			support.apply_force(-force, hand["anchor_world"] - support.global_position)
			if control_profile in [1,2,3,4]:
				support.apply_torque(-assist * scale_factor * float(support_torque_weights.get(id,0.0 if palm_solver.enabled else 1.0/float(attached.size()))))
			else:
				support.apply_torque(-assist * scale_factor / float(attached.size()))
			support.sleeping = false
		if is_palm_hand(id):
			if palm_releases.has(id):release_grip(id,palm_releases[id])
		else:
			_update_integrity(id, raw_tensions[id] * scale_factor, delta)
	if not attached.is_empty():
		torso.apply_torque(assist * scale_factor)
		torso.sleeping = false
	_diagnostics = {"step": _step, "physics_delta": delta, "attached_count": attached.size(),
		"control_profile":control_profile,"swing_intent":_supported_swing.intent if control_profile in [1,2,3,4] else Vector3.ZERO,"swing_requested":_swing_requested,"swing_torque":_swing_torque*scale_factor,
		"intent_locomotion":intent_locomotion.data.duplicate(true) if control_profile==4 else {},"aim_input_does_not_change_length":control_profile in [3,4],"posture_policy":posture_policy,"posture_assist_enabled":posture_assist_enabled,"supported_wasd_swing_enabled":supported_wasd_swing_enabled,
		"posture":posture_coordinator.diagnostics(self) if control_profile==3 else {},
		"posture_tilt_assist_enabled":posture_tilt_assist_enabled,"posture_tilt_torque":_posture_tilt_torque*scale_factor,
		"contextual_requested":_contextual_requested,"contextual_filtered":_contextual_filtered,"contextual_actuation":_contextual_actuation,
		"contextual_world_effort":_contextual_world_filtered,
		"simulation_time":simulation_time,"input_intent":Vector3(_contract,_extend,_bias),"requested_intent":_intent_target,
		"features":{"predictive_grip":tuning.predictive_grip,"physical_feet":tuning.physical_feet,"posture_solver":tuning.posture_solver,"directional_grip_quality":tuning.directional_grip_quality,"reactive_challenge":tuning.reactive_challenge},
		"launch_state":_launch_state,"launch_elapsed":_launch_elapsed,"launch_charge":_launch_charge,
		"total_force": sum_force * scale_factor, "force_budget": tuning.total_pull_force_budget,
		"torque": (moments + leg_moment + assist) * scale_factor, "assist_torque": assist * scale_factor,
		"leg_force":leg_force*leg_scale*scale_factor,"leg_force_budget":leg_budget,"leg_torque":leg_moment*scale_factor,
		"combined_force":(sum_force+leg_force*leg_scale)*scale_factor,
		"budget_scale": scale_factor, "control_right": _view_right, "hands": hands.duplicate(true),
		"torso_position": torso.global_position, "linear_velocity": torso.linear_velocity,
		"angular_velocity": torso.angular_velocity, "metrics": metrics.duplicate()}
	if control_profile==4:
		_diagnostics["ledge_transfer"]=ledge_transfer.data.duplicate(true)
		_diagnostics["ledge_transfer"]["applied_torque"]=mantle_assist*scale_factor
		if physics_mantle_v08_enabled:
			_diagnostics["ledge_transfer"]["palm_support"]=palm_solver.diagnostics()
		_diagnostics["combined_ground_climb_torque"] = Vector3(intent_locomotion.ground.get("applied_torque",Vector3.ZERO))+(moments+leg_moment+assist)*scale_factor
	if control_profile==3:
		_diagnostics["transfer_posture"] = {"enabled":transfer_assist_enabled,"variant":posture_variant,
			"available":true,"status":"P2" if _posture_refinement.blend>0.0 else "P1" if _twist_refinement.blend>0.0 else "P0",
			"twist":_twist_refinement.diagnostics(),"posture":_posture_refinement.diagnostics()}
	if _transfer_enabled():
		transfer_journal.sample(self,delta,{"attitude":diagnostic_attitude*scale_factor,"posture_tilt":_posture_tilt_torque*scale_factor,
			"swing":_swing_torque*scale_factor,"mantle":mantle_assist*scale_factor,"assist":assist*scale_factor,"shoulder_moment":moments*scale_factor,
			"leg_moment":leg_moment*scale_factor,"total_moment":(moments+leg_moment+assist)*scale_factor,
			"raw_hand_force_sum":sum_force,"hand_force_sum":sum_force*scale_factor,"force_limit":tuning.total_pull_force_budget,
			"assist_limit":tuning.max_attitude_torque,"total_moment_limit":tuning.max_total_torque,"allocator_scale":scale_factor,
			"weights":support_torque_weights,"swing_lever":diagnostic_swing_lever,"swing_engagement":diagnostic_swing_engagement,"applied":diagnostic_applied})
		_diagnostics["transfer_diagnostics"] = transfer_journal.diagnostics()
		_publish_transfer_events()
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
			if _transfer_enabled():
				transfer_journal.slipping(self,id,unweakened_force)
				_publish_transfer_events()
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

func _transfer_enabled() -> bool:
	return control_profile in [3,4] and transfer_diagnostics_enabled

func _publish_transfer_events() -> void:
	for event in transfer_journal.drain_events():
		transfer_event.emit(event)

func transfer_diagnostics(include_events: bool = false) -> Dictionary:
	return transfer_journal.diagnostics(include_events) if _transfer_enabled() else {"enabled":false}

func record_unselected_attempt(id: int, reason: String = "no_surface") -> void:
	if _transfer_enabled():
		transfer_journal.unselected(self,id,reason)
		_publish_transfer_events()
