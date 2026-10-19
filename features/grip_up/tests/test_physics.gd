extends SceneTree
const Controller = preload("res://features/grip_up/scripts/climbing_controller.gd")
const Tuning = preload("res://features/grip_up/resources/climbing_tuning.gd")
const Actuator = preload("res://features/grip_up/scripts/arm_actuator.gd")
const Anchor = preload("res://features/grip_up/scripts/grip_anchor.gd")
var world: Node3D
var controller: Node
var checks: int = 0
var failures: int = 0
var hz: int = 120
var started_usec: int = 0

func _init() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):
		hz = 60
	Engine.physics_ticks_per_second = hz
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)

func ticks(count: int) -> void:
	for index in count:
		await physics_frame

func seconds(duration: float) -> void:
	await ticks(int(round(duration * hz)))

func solid(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body

func rigid(at: Vector3, size: Vector3, mass: float = 12.0) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.position = at
	body.mass = mass
	body.continuous_cd = true
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.08
	body.angular_damp = 0.35
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body

func setup(body: RigidBody3D, tuning: Resource = null) -> void:
	controller = Controller.new()
	world.add_child(controller)
	controller.configure(body, tuning)

func clear_world() -> void:
	if is_instance_valid(controller):
		controller.reset_state()
	for node in world.get_children():
		node.queue_free()
	controller = null
	await ticks(3)

func acquire(id: int, support: PhysicsBody3D, point: Vector3, normal: Vector3 = Vector3.BACK) -> bool:
	if not controller.request_grip(id, support, point, normal):
		print("ACQUIRE REJECTED ", controller.last_rejection)
		return false
	for tick in int(0.9 * hz):
		await physics_frame
		if controller.get_hand_state(id) == "ATTACHED":
			return true
	print("ACQUIRE END ", controller.hands[id])
	return false

func valid_budget() -> bool:
	var sum: float = controller.get_arm_force(0).length() + controller.get_arm_force(1).length()
	return sum <= controller.tuning.total_pull_force_budget + 0.001 and controller.telemetry().get("torque", Vector3.ZERO).length() <= controller.tuning.max_total_torque + 0.001

func _run() -> void:
	started_usec = Time.get_ticks_usec()
	world = Node3D.new()
	root.add_child(world)
	check(ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics", "integrated Jolt backend")
	_test_signs()
	await _test_freeflight()
	await _test_reach_and_climb()
	await _test_obstruction()
	await _test_reach_regressions()
	await _test_shared_budget()
	await _test_torque_budget()
	await _test_dynamic_reaction()
	await _test_slip_and_reset()
	await _test_swing()
	await _test_pin_baseline()
	if checks < 35:
		check(false, "all scenarios completed without script abort")
	print("PHYSICS BENCHMARK Hz=%d wall_ms=%.2f physics_frames=%d" % [hz, (Time.get_ticks_usec() - started_usec) / 1000.0, Engine.get_physics_frames()])
	print("GRIP UP PHYSICS RESULTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_signs() -> void:
	var dt: float = 1.0 / hz
	var still: float = Actuator.tension(0.2, 0, 900, 70, 1.0 / 12.0, dt)
	var toward: float = Actuator.tension(0.2, 1, 900, 70, 1.0 / 12.0, dt)
	var away: float = Actuator.tension(0.2, -1, 900, 70, 1.0 / 12.0, dt)
	check(still > 0 and toward < still and away > still, "damping sign reduces tension when shoulder moves toward anchor")
	check(Actuator.tension(-0.1, -10, 900, 70, 1.0 / 12.0, dt) == 0, "slack arm never becomes a compression actuator")
	check(Actuator.tension(0.0, 10, 900, 70, 1.0 / 12.0, dt) == 0, "toward motion cannot produce negative pushing force")
	var legacy: float = 110.0 / (1.0 + (70.0 * dt + 900.0 * dt * dt) / 12.0)
	check(absf(toward - legacy) < 0.00001, "axial spring reuses original grabber implicit denominator")

func _test_freeflight() -> void:
	var body := rigid(Vector3(0, 6, 0.6), Vector3(0.8, 1.1, 0.45))
	var reference := rigid(Vector3(4, 6, 0.6), Vector3(0.8, 1.1, 0.45))
	setup(body)
	for tick in hz:
		controller.set_climb_intent(1.0, 1.0, 1.0 if tick % 2 else -1.0)
		await physics_frame
	check(body.linear_velocity.distance_to(reference.linear_velocity) < 0.00001 and body.angular_velocity.length() < 0.00001, "W S A D without attachments exactly match uncontrolled freefall")
	check(controller.get_arm_force(0) == Vector3.ZERO and controller.get_arm_force(1) == Vector3.ZERO, "no attachment means no actuator force")
	await clear_world()

func _test_reach_and_climb() -> void:
	solid(Vector3(0, -0.1, 0), Vector3(12, 0.2, 12))
	var hold := solid(Vector3(0, 2.2, -0.1), Vector3(1.8, 0.2, 0.2))
	var body := rigid(Vector3(0, 0.55, 0.65), Vector3(0.8, 1.1, 0.45))
	setup(body)
	await seconds(0.2)
	check(not controller.request_grip(0, hold, Vector3(0, 8, 0), Vector3.BACK) and controller.last_rejection == "out_of_reach", "out-of-range requests are rejected")
	var pose: Transform3D = body.global_transform
	var velocity: Vector3 = body.linear_velocity
	check(controller.request_grip(0, hold, Vector3(-0.32, 2.2, 0), Vector3.BACK), "surface-valid first hold begins reaching")
	check(controller.get_hand_state(0) == "REACHING" and body.global_transform == pose and body.linear_velocity == velocity, "request does not instantly attach, move or accelerate torso")
	var traveled_ok: bool = true
	var previous: Vector3 = controller.get_hand_world(0)
	for tick in int(0.5 * hz):
		await physics_frame
		var point: Vector3 = controller.get_hand_world(0)
		traveled_ok = traveled_ok and previous.distance_to(point) <= controller.tuning.hand_reach_speed / hz + controller.tuning.attach_distance_tolerance + 0.001
		previous = point
		if controller.get_hand_state(0) == "ATTACHED":
			break
	check(traveled_ok and controller.get_hand_state(0) == "ATTACHED", "hand reaches in finite time without crossing its speed bound")
	check(await acquire(1, hold, Vector3(0.32, 2.2, 0)), "second hand independently reaches and attaches")
	controller.set_climb_intent(1, 0, 0)
	var budgets_ok: bool = true
	var radial_ok: bool = true
	for tick in 2 * hz:
		await physics_frame
		budgets_ok = budgets_ok and valid_budget()
		for id in 2:
			var axis: Vector3 = controller.hands[id].get("force_axis", Vector3.ZERO)
			var force: Vector3 = controller.get_arm_force(id)
			radial_ok = radial_ok and force.dot(axis) >= -0.001 and force.cross(axis.normalized()).length() < 0.01
	print("MEASURE climb y=%.4f v=%.4f states=%s/%s" % [body.position.y, body.linear_velocity.length(), controller.get_hand_state(0), controller.get_hand_state(1)])
	check(body.position.y > 1.05 and not body.freeze, "bounded arm contraction raises live 12kg torso against gravity")
	check(budgets_ok and radial_ok, "climb respects shared budget and applies only axial pulling forces")
	controller.set_climb_intent(0, 0, 0)
	var before: Transform3D = body.global_transform
	var linear: Vector3 = body.linear_velocity
	var angular: Vector3 = body.angular_velocity
	controller.release_grip(0)
	check(body.global_transform == before and body.linear_velocity == linear and body.angular_velocity == angular and controller.get_hand_state(1) == "ATTACHED", "releasing one hand preserves instantaneous pose and both velocities")
	await seconds(0.7)
	check(controller.get_hand_state(1) == "ATTACHED" and body.position.y > 0.65, "remaining single grip physically supports torso")
	var length: float = controller.hands[1]["rest_length"]
	controller.set_climb_intent(0, 1, 0)
	await seconds(0.4)
	check(float(controller.hands[1]["rest_length"]) > length and controller.get_arm_force(1).dot(controller.hands[1]["anchor_world"] - controller.get_shoulder_world(1)) >= 0, "extension lengthens rope without applying downward thrust")
	await clear_world()

func _test_obstruction() -> void:
	var hold := solid(Vector3(0, 2, -0.1), Vector3(2, 0.3, 0.2))
	var body := rigid(Vector3(0, 0.55, 0.65), Vector3(0.8, 1.1, 0.45))
	body.gravity_scale = 0
	setup(body)
	var blocker := solid(Vector3(0, 1.3, 0.3), Vector3(4, 3, 0.1))
	await ticks(2)
	check(not controller.request_grip(0, hold, Vector3(-0.32, 2, 0), Vector3.BACK), "shoulder-to-hold line of sight rejects an intervening solid")
	blocker.queue_free()
	await ticks(2)
	check(not controller.request_grip(0, hold, Vector3(-0.32, 2, -0.2), Vector3.FORWARD), "same-body rear face cannot be attached through its front")
	hold.set_meta("grippable", false)
	check(not controller.request_grip(0, hold, Vector3(-0.32, 2, 0), Vector3.BACK) and controller.last_rejection == "surface_not_grippable", "surface capability metadata is enforced")
	await clear_world()

func _test_reach_regressions() -> void:
	# Matches the integrated first hold: steep rays must hit the selected front
	# point, rather than a normal-offset ray intersecting below it.
	var hold := solid(Vector3(-0.65, 1.95, 0), Vector3(0.45, 0.22, 0.55))
	var body := rigid(Vector3(0, 0.775, 0.55), Vector3(0.8, 1.05, 0.45))
	body.gravity_scale = 0
	setup(body)
	await ticks(3)
	check(await acquire(0, hold, Vector3(-0.65, 1.95, 0.275)), "steep upward front-surface ray reaches exact integrated hold point")
	check(not controller.request_grip(0, hold, Vector3(-0.65, 1.95, 0.275), Vector3.BACK) and controller.last_rejection == "release_hand_before_regrip", "attached hand cannot silently replace its anchor")
	controller.release_grip(0)
	await ticks(2)
	check(controller.request_grip(0, hold, Vector3(-0.65, 1.95, 0.275), Vector3.BACK), "released hand may start a fresh finite reach")
	var blocker := solid(Vector3(-0.4, 1.5, 0.4), Vector3(2, 0.3, 0.15))
	await ticks(4)
	check(controller.get_hand_state(0) == "FREE" and controller.hands[0]["reason"] == "candidate_timeout_or_obstructed", "new obstacle during reaching cancels attachment before force activation")
	blocker.queue_free()
	await ticks(2)
	check(controller.request_grip(0, hold, Vector3(-0.65, 1.95, 0.275), Vector3.BACK), "candidate can be retried after obstacle removal")
	# Moving the candidate is a fixture operation on a static support, never the
	# active torso. Material-local anchor must follow it and invalidate reach.
	hold.position.y += 5.0
	await ticks(3)
	check(controller.get_hand_state(0) == "FREE" and controller.hands[0]["reason"] == "target_left_reach", "moving candidate outside arm range cancels finite reach")
	await clear_world()
	hold = solid(Vector3(0.65, 2.73, 0), Vector3(0.72, 0.24, 0.55))
	body = rigid(Vector3(0, 1.0, 0.55), Vector3(0.8, 1.05, 0.45))
	body.gravity_scale = 0
	setup(body)
	await ticks(3)
	controller.hands[1]["hand_world"] = Vector3(0.1, 1.0, 0.15)
	check(await acquire(1, hold, Vector3(0.65, 2.73, 0.275)), "finite normal approach avoids hold underside when free hand begins behind front-face plane")
	await clear_world()

func _test_shared_budget() -> void:
	solid(Vector3(0, -0.1, 0), Vector3(12, 0.2, 12))
	var hold := solid(Vector3(0, 2.2, -0.1), Vector3(2, 0.2, 0.2))
	hold.set_meta("grip_load_limit", 10000.0)
	var body := rigid(Vector3(0, 0.55, 0.65), Vector3(0.8, 1.1, 0.45), 50)
	setup(body)
	await ticks(3)
	check(await acquire(0, hold, Vector3(-0.32, 2.2, 0)), "heavy-load budget trial acquires one hand")
	controller.set_climb_intent(1, 0, 0)
	var one_peak: float = 0.0
	for tick in hz:
		await physics_frame
		one_peak = maxf(one_peak, controller.get_arm_force(0).length())
	await clear_world()
	solid(Vector3(0, -0.1, 0), Vector3(12, 0.2, 12))
	hold = solid(Vector3(0, 2.2, -0.1), Vector3(2, 0.2, 0.2))
	hold.set_meta("grip_load_limit", 10000.0)
	body = rigid(Vector3(0, 0.55, 0.65), Vector3(0.8, 1.1, 0.45), 50)
	setup(body)
	await ticks(3)
	check(await acquire(0, hold, Vector3(-0.32, 2.2, 0)) and await acquire(1, hold, Vector3(0.32, 2.2, 0)), "independent heavy-load fixture acquires both hands before contraction")
	controller.set_climb_intent(1, 0, 0)
	var two_peak: float = 0.0
	var budgets_ok: bool = true
	for tick in hz:
		await physics_frame
		budgets_ok = budgets_ok and valid_budget()
		two_peak = maxf(two_peak, controller.get_arm_force(0).length() + controller.get_arm_force(1).length())
	print("MEASURE force peaks one=%.3f two=%.3f shared=%.3f" % [one_peak, two_peak, controller.tuning.total_pull_force_budget])
	check(budgets_ok and one_peak <= 360.001 and two_peak <= 360.001, "adding second hand does not duplicate global force or torque budgets")
	check(body.position.y < 1.3, "strength-limited arms cannot freely lift an overweight torso")
	await clear_world()

func _test_torque_budget() -> void:
	solid(Vector3(0, -0.1, 0), Vector3(12, 0.2, 12))
	var hold := solid(Vector3(0, 2.2, -0.1), Vector3(2, 0.2, 0.2))
	hold.set_meta("grip_load_limit", 10000.0)
	var body := rigid(Vector3(0, 0.55, 0.65), Vector3(0.8, 1.1, 0.45))
	var tuning: Resource = Tuning.new()
	tuning.max_total_torque = 2.0
	setup(body, tuning)
	await ticks(3)
	check(await acquire(0, hold, Vector3(-0.32, 2.2, 0)), "off-center torque trial acquires physical anchor")
	controller.set_climb_intent(1, 0, 1)
	var peak: float = 0.0
	var bounded: bool = true
	var clamped: bool = false
	for tick in hz:
		await physics_frame
		peak = maxf(peak, controller.telemetry()["torque"].length())
		bounded = bounded and valid_budget()
		clamped = clamped or controller.telemetry()["budget_scale"] < 0.5
	check(bounded and clamped and peak > 1.9, "resultant torque cap includes shoulder moments and A/D assist in same allocation")
	await clear_world()

func _test_dynamic_reaction() -> void:
	var support := rigid(Vector3(0, 2.2, -0.1), Vector3(1.8, 0.2, 0.2), 10)
	var body := rigid(Vector3(0, 0.55, 0.65), Vector3(0.8, 1.1, 0.45))
	for item: RigidBody3D in [body, support]:
		item.gravity_scale = 0
		item.linear_damp = 0
		item.angular_damp = 0
	var tuning: Resource = Tuning.new()
	tuning.attitude_damping = 0
	tuning.single_bias_torque = 0
	setup(body, tuning)
	await ticks(3)
	check(await acquire(0, support, Vector3(-0.32, 2.2, 0)), "dynamic support accepts finite-time attachment")
	var anchor = controller.hands[0]["anchor"]
	var start_body: Vector3 = body.position
	var start_support: Vector3 = support.position
	controller.set_climb_intent(1, 0, 0)
	var paired: bool = true
	var local_ok: bool = true
	for tick in int(0.6 * hz):
		await physics_frame
		paired = paired and (controller.hands[0]["force"] + controller.hands[0]["reaction_force"]).length() < 0.00001
		local_ok = local_ok and anchor.world_point().distance_to(support.to_global(anchor.local_point)) < 0.00001
	var momentum: Vector3 = body.linear_velocity * body.mass + support.linear_velocity * support.mass
	print("MEASURE dynamic dy torso=%.4f support=%.4f momentum=%.6f" % [body.position.y - start_body.y, support.position.y - start_support.y, momentum.length()])
	check(paired and local_ok, "dynamic anchor stays material-local and receives exact opposite force")
	check(body.position.y > start_body.y + 0.05 and support.position.y < start_support.y - 0.05 and momentum.length() < 0.05, "actual dynamic reaction moves support and conserves pair linear momentum")
	var expected: Vector3 = support.linear_velocity + support.angular_velocity.cross(anchor.world_point() - support.global_transform * support.center_of_mass)
	check(anchor.point_velocity().distance_to(expected) < 0.00001, "moving anchor damping includes angular point velocity")
	support.queue_free()
	await ticks(3)
	check(controller.get_hand_state(0) == "FREE" and controller.hands[0]["reason"] == "support_invalidated", "destroyed support releases cleanly without stale anchor")
	await clear_world()

func _test_slip_and_reset() -> void:
	solid(Vector3(0, -0.1, 0), Vector3(12, 0.2, 12))
	var hold := solid(Vector3(0, 2.2, -0.1), Vector3(2, 0.2, 0.2))
	hold.set_meta("grip_load_limit", 45.0)
	var body := rigid(Vector3(0, 0.55, 0.65), Vector3(0.8, 1.1, 0.45))
	setup(body)
	await ticks(3)
	check(await acquire(0, hold, Vector3(-0.32, 2.2, 0)), "weak hold initially attaches normally")
	controller.set_climb_intent(1, 0, 0)
	var slipped: bool = false
	for tick in 2 * hz:
		await physics_frame
		slipped = slipped or controller.get_hand_state(0) == "SLIPPING"
	check(slipped and controller.metrics["slips"] > 0 and controller.hands[0]["reason"] == "grip_overload", "sustained overload gives deterministic slipping then explicit release reason")
	var pose: Transform3D = body.global_transform
	var velocity: Vector3 = body.linear_velocity
	controller.reset_state()
	check(body.global_transform == pose and body.linear_velocity == velocity, "resetting controller never resets torso pose or momentum implicitly")
	await ticks(3)
	check(controller.hands[0]["anchor"] == null and controller.hands[1]["anchor"] == null and controller.telemetry()["total_force"] == 0, "reset clears both anchors, pending intent and actuator force")
	await clear_world()

func _test_swing() -> void:
	var hold := solid(Vector3(0, 4, -0.1), Vector3(2, 0.2, 0.2))
	var body := rigid(Vector3(0.7, 2.0, 0.65), Vector3(0.8, 1.1, 0.45))
	body.gravity_scale = 0
	setup(body)
	await ticks(3)
	check(await acquire(0, hold, Vector3(0, 4, 0)), "offset swing hold attaches within finite arm reach")
	body.gravity_scale = 1
	var min_x: float = body.position.x
	var max_x: float = min_x
	var peak_speed: float = 0.0
	var bounded: bool = true
	for tick in 4 * hz:
		controller.set_climb_intent(1.0 if (tick / int(hz / 2)) % 2 == 0 else 0.0, 0.0 if (tick / int(hz / 2)) % 2 == 0 else 0.7, -1.0 if body.linear_velocity.x < 0 else 1.0)
		await physics_frame
		min_x = minf(min_x, body.position.x)
		max_x = maxf(max_x, body.position.x)
		peak_speed = maxf(peak_speed, absf(body.linear_velocity.x))
		bounded = bounded and valid_budget()
	print("MEASURE swing x_span=%.4f peak_horizontal=%.4f state=%s" % [max_x - min_x, peak_speed, controller.get_hand_state(0)])
	check(max_x - min_x > 0.7 and peak_speed > 0.5 and bounded, "off-center tension and finite anchored work generate useful physical swing")
	await clear_world()

func _test_pin_baseline() -> void:
	var body := rigid(Vector3(0, 3, 0), Vector3(0.8, 1.1, 0.45), 50)
	var pin := PinJoint3D.new()
	world.add_child(pin)
	pin.global_position = Vector3(-0.32, 3.3, 0)
	pin.node_b = pin.get_path_to(body)
	await seconds(2)
	var drift: float = body.to_global(Vector3(-0.32, 0.3, 0)).distance_to(pin.global_position)
	print("MEASURE Jolt PinJoint50kg anchor_drift=%.5f despite weight490N > player budget360N" % drift)
	check(drift < 0.05, "built-in pin baseline supports weight beyond player budget; requires different limiter model")
	await clear_world()
