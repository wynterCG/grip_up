extends SceneTree
## Actual input-driven route through the authored SWING & CATCH level.
## No transforms, velocities, forces, masses or level geometry are assigned.
## W + D from left grip 01 opens the right-hand catch window; aim at the
## underside of 02, transfer after ATTACHED, then keep W and release D.
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var checks := 0
var failures := 0
var hz := 120

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):
		hz = 60
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)

func intent(contract: float, extend: float, bias: float) -> void:
	for action in ["contract", "extend", "bias_left", "bias_right"]:
		Input.action_release(action)
	if contract > 0:
		Input.action_press("contract", contract)
	if extend > 0:
		Input.action_press("extend", extend)
	if bias < 0:
		Input.action_press("bias_left", -bias)
	if bias > 0:
		Input.action_press("bias_right", bias)

func run() -> void:
	app = Lab.new()
	root.add_child(app)
	current_scene = app
	if OS.get_cmdline_user_args().has("--feet"):
		app._set_physical_feet(true)
	app.load_test(1)
	await ticks(int(0.75 * hz))
	var hold_a: PhysicsBody3D = app.level.holds[0]
	var hold_b: PhysicsBody3D = app.level.holds[1]
	var query := PhysicsRayQueryParameters3D.create(app.controller.get_shoulder_world(0),hold_a.global_position)
	query.exclude = [app.torso.get_rid()]
	var first_surface: Dictionary = app.torso.get_world_3d().direct_space_state.intersect_ray(query)
	var point_a: Vector3 = first_surface.position
	# Actual underside of the authored 0.30 x 0.10 x 0.18 m bar.
	var point_b: Vector3 = hold_b.to_global(Vector3(-0.08, -0.05, 0.03))
	check(not app.controller.request_grip(1, hold_b, point_b, Vector3.DOWN) and app.controller.last_rejection == "out_of_reach", "far hold is initially beyond finite reach")
	check(app.controller.request_grip(0, hold_a, point_a, first_surface.normal), "first hold can be reached from launch platform")
	await ticks(int((2.0 / 3.0) * hz))
	check(app.controller.get_hand_state(0) == "ATTACHED", "first hand physically reaches its anchor")
	var caught := false
	var requested := false
	var released := false
	var bounded := true
	var min_x: float = app.torso.position.x
	var max_x: float = min_x
	var peak_vx := 0.0
	var min_reach := 100.0
	var last_reason := ""
	var catch_requests := 0
	var accepted_requests := 0
	intent(1, 0, 1)
	for frame in 15 * hz:
		await physics_frame
		if app.level_id != 1 or app.level.holds[0] != hold_a:
			break
		min_x = minf(min_x, app.torso.position.x)
		max_x = maxf(max_x, app.torso.position.x)
		peak_vx = maxf(peak_vx, absf(app.torso.linear_velocity.x))
		var reach: float = app.controller.get_shoulder_world(1).distance_to(point_b)
		min_reach = minf(min_reach, reach)
		bounded = bounded and app.controller.get_arm_force(0).length() + app.controller.get_arm_force(1).length() <= 360.001 and app.controller.telemetry().get("torque", Vector3.ZERO).length() <= 150.001
		if not caught and app.controller.get_hand_state(1) == "FREE":
			if reach < app.controller.tuning.max_arm_length-0.01:
				catch_requests += 1
				var accepted: bool = app.controller.request_grip(1, hold_b, point_b, Vector3.DOWN)
				if accepted:
					accepted_requests += 1
					print("CATCH REQUEST frame=", frame, " reach=", reach, " torso=", app.torso.position)
				requested = accepted or requested
				last_reason = app.controller.last_rejection
		if app.controller.get_hand_state(1) == "ATTACHED" and not caught:
			caught = true
			print("CATCH frame=", frame, " torso=", app.torso.position, " velocity=", app.torso.linear_velocity)
			app.controller.release_grip(0)
			intent(1, 0, 0)
			released = true
		if frame % hz == 0:
			print("SWING frame=", frame, " torso=", app.torso.position, " reach=", reach, " states=", app.controller.get_hand_state(0), "/", app.controller.get_hand_state(1), " reject=", last_reason)
		if app.won:
			break
	intent(0, 0, 0)
	check(requested and caught, "physical lateral motion opens a finite reach window for catch 02")
	check(accepted_requests == 1, "one successful catch request completes its reach without retrying an aborted hand path")
	check(released and app.controller.get_hand_state(0) == "FREE", "transfer releases first grip only after second attaches")
	check(max_x - min_x > 0.7 and peak_vx > 0.5, "bounded anchored work produces useful swing displacement and lateral speed")
	check(bounded, "entire swing and catch remain within shared force and resultant torque limits")
	check(app.won, "original SWING & CATCH geometry completes with live torso physics")
	check(app.trial.large_step_events == 0, "no detected torso teleport in complete swing trajectory")
	print("SWING MEASURE x_span=%.4f peak_vx=%.4f nearest_reach=%.4f requests=%d accepted=%d final=%s" % [max_x-min_x, peak_vx, min_reach, catch_requests, accepted_requests, app.torso.position])
	print("SWING PLAYTHROUGH RESULTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
