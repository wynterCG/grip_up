extends RefCounted
## Bounded, acceleration-limited target motion. This never applies a body force.
var plan: Dictionary = {}
var records: Dictionary = {}
var state := "HOLD"
var reason := "hold_current_length"
var elapsed := 0.0
var braking_advance := 0.0
var _stop_reason := ""
var _start_body_position := Vector3.ZERO

func reset() -> void:
	plan.clear()
	records.clear()
	state = "HOLD"
	reason = "hold_current_length"
	elapsed = 0.0
	braking_advance = 0.0
	_stop_reason = ""

func begin(next: Dictionary, controller: Node, ids: Array[int]) -> void:
	var previous := records
	records = {}
	plan = next
	_start_body_position = controller.torso.global_position
	state = "ACTIVE" if plan.feasible else "ABORTED"
	reason = plan.reason
	elapsed = 0.0
	braking_advance = 0.0
	_stop_reason = ""
	for id in ids:
		var hand: Dictionary = controller.hands[id]
		var velocity := 0.0
		if previous.has(id) and previous[id].anchor==hand["anchor"]:
			velocity = previous[id].velocity
		records[id] = {"anchor":hand["anchor"],"goal":plan.goals[id],"velocity":velocity,
			"rate":0.0,"acceleration":0.0,"stall":0.0,"previous_actual":hand["actual_length"]}

func step(controller: Node, delta: float) -> void:
	if plan.is_empty() or state in ["HOLD","ABORTED","COMPLETE"]:
		return
	var tuning: Resource = controller.tuning
	elapsed += delta
	if _stop_reason=="":
		if not plan.feasible:
			_stop_reason = plan.reason
		elif elapsed>tuning.posture_max_settle_time:
			_stop_reason = "bounded_settle_timeout"
		var telemetry: Dictionary = controller.telemetry()
		if not telemetry.is_empty() and (telemetry.total_force>tuning.total_pull_force_budget*tuning.posture_saturation_ratio or telemetry.budget_scale<.90):
			_stop_reason = "actuator_saturation"
		for id in records:
			var hand: Dictionary = controller.hands[id]
			var record: Dictionary = records[id]
			if hand["anchor"]!=record.anchor or hand["state"]!="ATTACHED":
				_stop_reason = "support_slipping_or_lost"
			var progress: float = absf(hand["actual_length"]-record.previous_actual)/delta
			var tracking: float = absf(hand["actual_length"]-hand["rest_length"])
			record.stall = record.stall+delta if tracking>tuning.posture_tracking_tolerance and progress<.025 else 0.0
			record.previous_actual = hand["actual_length"]
			if record.stall>tuning.posture_stall_confirm_time:
				_stop_reason = "blocked_tracking_error"
	if _stop_reason!="":
		state = "BRAKING"
		reason = _stop_reason
	var moving := false
	var remaining := false
	for id in records:
		var record: Dictionary = records[id]
		var hand: Dictionary = controller.hands[id]
		if hand["anchor"]!=record.anchor:
			continue
		if hand["blend_elapsed"]<tuning.grip_blend_duration:
			remaining = true
			continue
		var error: float = record.goal-hand["rest_length"]
		var desired_velocity := 0.0
		if state=="ACTIVE":
			desired_velocity = signf(error)*minf(tuning.posture_target_max_speed,maxf(0.0,sqrt(2.0*tuning.posture_target_max_acceleration*absf(error))-tuning.posture_target_max_acceleration*delta))
		var previous_velocity: float = record.velocity
		record.velocity = move_toward(previous_velocity,desired_velocity,tuning.posture_target_max_acceleration*delta)
		var change: float = record.velocity*delta
		hand["rest_length"] = clampf(hand["rest_length"]+change,tuning.min_arm_length,tuning.max_arm_length)
		record.rate = change/delta
		record.acceleration = (record.velocity-previous_velocity)/delta
		if state=="BRAKING":
			braking_advance += absf(change)
		moving = moving or absf(record.velocity)>.0001
		remaining = remaining or absf(error)>.001
	if state=="BRAKING" and not moving:
		state = "ABORTED"
	elif state=="ACTIVE" and not remaining and not moving:
		state = "COMPLETE"
		reason = "absolute_arm_targets_reached"

func diagnostics(controller: Node) -> Dictionary:
	var result := {"state":state,"reason":reason,"elapsed":elapsed,"braking_advance":braking_advance,
		"event":plan.get("event",0),"planned_lengths":plan.get("goals",{}),"rates":{},"accelerations":{},"allocations":plan.get("allocations",{})}
	for id in records:
		result.rates[id] = records[id].rate
		result.accelerations[id] = records[id].acceleration
	if not plan.is_empty():
		result.desired_posture = plan.desired_pose
		result.body_error = Vector3(plan.desired_pose.origin)-controller.torso.global_position
		result.actual_movement = controller.torso.global_position-_start_body_position
		result.length_errors = {}
		result.requested_lengths = {}
		for id in records:
			result.requested_lengths[id] = controller.hands[id]["rest_length"]
			result.length_errors[id] = controller.hands[id]["actual_length"]-records[id].goal
	return result
