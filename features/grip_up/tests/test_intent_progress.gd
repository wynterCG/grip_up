extends "res://features/grip_up/tests/test_intent_locomotion.gd"
## Isolate the historical absolute strain gate from achieved-geometry capture.
class ErrorToleranceControl:
	extends "res://features/grip_up/scripts/intent_locomotion_coordinator.gd"
	func _capture_achieved_posture(record: Dictionary, actual: float, rest: float) -> void:
		if record.idle<.25:
			if record.last_direction<0 and actual<=rest+.025:record.hold = minf(record.hold,rest)
			elif record.last_direction>0:record.hold = maxf(record.hold,minf(rest,actual-.025))
	func _limit_goal_to_achieved_geometry(_record: Dictionary, actual: float, goal: float, offset: float, _max_error: float) -> float:
		return clampf(goal,actual-offset,actual+offset)

var baseline_only := false

func capture_trial(old_latch: bool) -> Dictionary:
	await acquire(true,false)
	controller.intent_locomotion = ErrorToleranceControl.new() if old_latch else preload("res://features/grip_up/scripts/intent_locomotion_coordinator.gd").new()
	var start := body.global_position
	var initial_rest: float = controller.hands[0].rest_length
	var peak_error := 0.0
	var maximum_rate := 0.0
	var maximum_acceleration := 0.0
	var peak_force := 0.0
	var retained := true
	var samples: Array = []
	controller.set_traversal_input(Vector2(0,1),Vector3.RIGHT)
	for index in int(3.0*hz):
		await controller.sample_ready
		var data: Dictionary = controller.telemetry()
		retained = retained and controller._attached_ids().size()==2
		peak_force = maxf(peak_force,data.total_force)
		for hand in controller.hands:peak_error = maxf(peak_error,absf(hand.actual_length-hand.rest_length))
		for value in data.intent_locomotion.target_rates.values():maximum_rate = maxf(maximum_rate,absf(value))
		for value in data.intent_locomotion.target_accelerations.values():maximum_acceleration = maxf(maximum_acceleration,absf(value))
		if index%int(hz/2)==0:
			var record: Dictionary = controller.intent_locomotion.records.get(0,{})
			samples.append({"time":float(index)/hz,"height":body.global_position.y-start.y,"actual":controller.hands[0].actual_length,"rest":controller.hands[0].rest_length,"hold":record.get("hold",0.0),"reference_actual":record.get("capture_reference_actual",0.0),"direction":record.get("capture_direction",0)})
	var result := {"mode":"continuous_w","old_latch":old_latch,"rise":body.global_position.y-start.y,"initial_rest":initial_rest,"final_rest":controller.hands[0].rest_length,
		"peak_error":peak_error,"max_rate":maximum_rate,"max_acceleration":maximum_acceleration,"peak_force":peak_force,"retained":retained,"samples":samples}
	check(retained and peak_force<=360.001 and maximum_rate<=.2401 and maximum_acceleration<=.9001,"continuousW oldLatch%s preserves real support, force and goal derivative bounds" % old_latch)
	controller.set_traversal_input(Vector2.ZERO,Vector3.LEFT)
	await ticks(int(.9*hz))
	var rest: float = controller.hands[0].rest_length
	await ticks(int(1.5*hz))
	result.neutral_drift = absf(controller.hands[0].rest_length-rest)
	check(result.neutral_drift<.003,"oldLatch%s no-input/camera-only state cannot ratchet achieved posture" % old_latch)
	var before_y: float = body.global_position.y
	var before_rest: float = controller.hands[0].rest_length
	controller.set_traversal_input(Vector2(0,-1),Vector3.RIGHT)
	await ticks(int(.7*hz))
	result.reverse_y = body.global_position.y-before_y
	result.reverse_rest = controller.hands[0].rest_length-before_rest
	check(result.reverse_rest>.02,"oldLatch%s explicitS can reverse active contraction into extension" % old_latch)
	print("PROGRESS_MEASURE ",JSON.stringify(result))
	report.trials.append(result)
	await clear()
	return result

func blocker(at: Vector3, size: Vector3) -> StaticBody3D:
	var material := StaticBody3D.new()
	material.position = at
	material.collision_layer = 1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	material.add_child(collision)
	world.add_child(material)
	return material

func blocked_capture() -> void:
	await acquire(true,false)
	var start := body.global_position
	var cage: Array[Node] = []
	for side in [-1,1]:
		cage.append(blocker(start+Vector3(side*.26,0,0),Vector3(.08,2.2,1.2)))
		cage.append(blocker(start+Vector3(0,side*.91,0),Vector3(1.2,.08,1.2)))
		cage.append(blocker(start+Vector3(0,0,side*.26),Vector3(1.2,2.2,.08)))
	controller.set_traversal_input(Vector2(0,1),Vector3.RIGHT)
	await ticks(int(6.0*hz))
	var held: float = controller.intent_locomotion.records.get(0,{}).get("hold",0.0)
	var rest: float = controller.hands[0].rest_length
	var blocked_move := body.global_position.distance_to(start)
	check(controller._attached_ids().size()==2 and held>.30 and rest>.30 and blocked_move<.10,"six seconds blocked cannot integrate tiny oscillations into a fully-contracted future posture")
	controller.set_traversal_input(Vector2.ZERO,Vector3.RIGHT)
	await ticks(int(.8*hz))
	var released_rest: float = controller.hands[0].rest_length
	for material in cage:material.queue_free()
	var peak_speed := 0.0
	await ticks(2)
	for index in int(1.0*hz):
		await tick()
		peak_speed = maxf(peak_speed,body.linear_velocity.length())
	check(absf(controller.hands[0].rest_length-released_rest)<.003,"removing obstruction after inputrelease cannot reveal hidden target displacement")
	report["blocked"] = {"hold":held,"rest":rest,"body_displacement":blocked_move,"peak_speed_after_open":peak_speed,"released_rest":released_rest}
	print("PROGRESS_BLOCKED ",JSON.stringify(report.blocked))
	await clear()

func run() -> void:
	baseline_only = OS.get_cmdline_user_args().has("--record-baseline")
	world = Node3D.new()
	root.add_child(world)
	var old: Dictionary = await capture_trial(true)
	var candidate: Dictionary = await capture_trial(false)
	if not baseline_only:
		check(old.peak_error>.025,"loaded fixture genuinely exceeds the historical fixed25mm capture tolerance")
		check(candidate.rise>old.rise+.05 and candidate.final_rest<old.final_rest-.05,"capturing actual progress permits useful continuousW beyond one virtual55mm request")
		check(candidate.reverse_y<-.03,"activeS physically lowers an already contracted body instead of merely changing targets")
		await blocked_capture()
	var filename := "res://builds/intent_progress_baseline_%dhz.json" if baseline_only else "res://builds/intent_progress_%dhz.json"
	FileAccess.open(filename % hz,FileAccess.WRITE).store_string(JSON.stringify({"hz":hz,"checks":checks,"failures":failures,"report":report},"\t"))
	print("INTENT PROGRESS RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
