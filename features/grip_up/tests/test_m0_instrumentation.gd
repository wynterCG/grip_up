extends SceneTree
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
var checks := 0
var failures := 0
var hz := 120

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):
		hz = 60
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ",label)

func run() -> void:
	var app = Lab.new()
	root.add_child(app)
	for frame in 20:
		await physics_frame
	var data: Dictionary = app.controller.telemetry()
	check(data.features.values().all(func(flag):return not flag),"all v0.2 feature flags default off")
	check(data.has("input_intent") and data.has("requested_intent") and data.has("simulation_time"),"telemetry adds actual/requested intent and simulation time")
	app.capture_trace.path = "user://m0_instrumentation_test.jsonl"
	FileAccess.open(app.capture_trace.path,FileAccess.WRITE).close()
	app.capture_trace.enabled = true
	var pose: Transform3D = app.torso.global_transform
	var linear: Vector3 = app.torso.linear_velocity
	var angular: Vector3 = app.torso.angular_velocity
	var force: Vector3 = app.controller.get_arm_force(0)
	app.capture_trace.sample(1.0,app.controller)
	check(app.torso.global_transform==pose and app.torso.linear_velocity==linear and app.torso.angular_velocity==angular and app.controller.get_arm_force(0)==force,"recording cannot change body pose, momentum or actuator force")
	for frame in 20:
		await physics_frame
	app.capture_trace.close()
	var lines := FileAccess.get_file_as_string(app.capture_trace.path).strip_edges().split("\n")
	var row: Dictionary = JSON.parse_string(lines[0])
	check(lines.size()>1 and row.has("physics_hz") and row.has("features") and row.has("total_force"),"sampled JSONL recording contains physics rate, features and force budget data")
	check(row.hands.size()==2 and row.hands[0].has("target_local") and row.hands[0].has("relative_velocity") and row.hands[0].has("reason"),"per-hand JSONL contains local target, relative speed and failure reason")
	app.capture_trace.enabled = false
	app.queue_free()
	await physics_frame
	print("M0 INSTRUMENTATION RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
