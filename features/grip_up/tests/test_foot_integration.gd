extends SceneTree
## Full biped/controller comparison: physical feet, shared allocator and UI/reset.
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
const Actuator = preload("res://features/grip_up/scripts/arm_actuator.gd")
var app
var hz := 120
var checks := 0
var failures := 0
var budgets := true
var visual_reach := true

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

func ticks(count: int) -> void:
	for frame in count:
		await physics_frame
		if not is_instance_valid(app) or app.controller.telemetry().is_empty():
			continue
		var data: Dictionary = app.controller.telemetry()
		budgets = budgets and data.total_force<=360.001 and data.leg_force<=180.001 and data.torque.length()<=150.001
		for id in 2:
			var hip: Vector3 = app.biped.leg_motion._pose*app.biped.leg_motion.hips[id]
			visual_reach = visual_reach and hip.distance_to(app.biped.leg_motion.feet[id])<=app.biped.leg_motion.leg_lengths[id]+0.001

func acquire(id: int) -> bool:
	var support: PhysicsBody3D = app.level.holds[id]
	var shoulder: Vector3 = app.controller.get_shoulder_world(id)
	var ray := PhysicsRayQueryParameters3D.create(shoulder,support.global_position,3,[app.torso.get_rid()])
	var hit: Dictionary = app.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and app.controller.request_grip(id,support,hit.position,hit.normal)

func setup(enabled: bool) -> void:
	app = Lab.new()
	root.add_child(app)
	current_scene = app
	app.load_test(3)
	app._set_physical_feet(enabled)
	await ticks(int(0.4*hz))
	check(acquire(0) and acquire(1),"two fixed physical hand targets are selectable, feet=%s" % enabled)
	await ticks(int(0.6*hz))
	check(app.controller._attached_ids().size()==2,"both real hands remain independent, feet=%s" % enabled)

func compare(enabled: bool) -> Dictionary:
	await setup(enabled)
	var push_work := 0.0
	var initial_y: float = app.torso.position.y
	Input.action_press("contract")
	for frame in hz:
		await ticks(1)
		for foot in app.controller.feet_solver.feet:
			push_work += maxf(0.0,Vector3(foot.force).dot(Actuator.point_velocity(app.torso,foot.contact_point)))/hz
	Input.action_release("contract")
	await ticks(int(0.4*hz))
	var force := 0.0
	var leg_force := 0.0
	var planted := 0
	var start_y: float = app.torso.position.y
	for frame in hz:
		await ticks(1)
		force += app.controller.get_arm_force(0).length()+app.controller.get_arm_force(1).length()
		leg_force += float(app.controller.telemetry().leg_force)
		for foot in app.controller.feet_solver.feet:
			if foot.state=="SUPPORTING":
				planted += 1
	var result := {"enabled":enabled,"hand_load":force/hz,"leg_load":leg_force/hz,"planted_samples":planted,"height":app.torso.position.y,"settle_drift":app.torso.position.y-start_y,"leg_positive_work":push_work,"climb_height":app.torso.position.y-initial_y,"hands_retained":app.controller._attached_ids().size()==2}
	# The same W command must also produce useful upward work through actual feet.
	var before: float = app.torso.position.y
	Input.action_press("contract")
	await ticks(int(0.3*hz))
	Input.action_release("contract")
	result.upward = app.torso.position.y-before
	print("FOOT INTEGRATION SAMPLE ",JSON.stringify(result))
	if enabled:
		app.controller.release_grip(0)
		app.controller.release_grip(1)
		await ticks(int(0.10*hz))
		check(app.controller.telemetry().leg_force>1.0 and app.controller.feet_solver.feet.any(func(foot):return foot.state in ["SUPPORTING","SLIDING"]),"releasing hands preserves a physically valid independent foot stance")
	app.queue_free()
	await ticks(4)
	return result

func run() -> void:
	var off := await compare(false)
	var on := await compare(true)
	check(on.planted_samples>hz/2 and on.leg_load>10.0,"real footholds establish loaded physical foot support")
	check(on.hand_load<off.hand_load*0.85,"planted feet measurably reduce hand demand on identical fixed geometry")
	check(on.leg_positive_work>0.02 and on.climb_height>0.05 and on.hands_retained,"W lets real planted feet contribute positive work to upward movement")
	check(visual_reach,"physical foot presentation preserves measured leg lengths")
	check(budgets,"combined arm/leg allocator respects 360 N hands, 180 N feet and 150 Nm total")
	await setup(true)
	check(app.controller.request_launch_charge(true),"original arm launch still starts with automatic feet enabled")
	await ticks(2)
	check(app.controller.telemetry().leg_force==0.0 and app.controller.feet_solver.feet.all(func(foot):return foot.force==Vector3.ZERO),"launch preparation disengages legs without adding a launch impulse")
	app.controller.cancel_launch()
	app.settings.show()
	await ticks(2)
	app._set_physical_feet(false)
	await ticks(2)
	check(app.controller._attached_ids().size()==2 and app.controller.telemetry().leg_force==0.0,"turning feet off preserves attached hands and removes foot forces")
	app.settings.hide()
	app._set_physical_feet(true)
	app.load_test(3)
	await ticks(2)
	check(app.physical_feet_enabled and app.controller.tuning.physical_feet and app.controller.feet_solver.feet.all(func(foot):return foot.support==null and foot.force==Vector3.ZERO),"reset preserves the experiment choice and clears both old foot contacts")
	check(not app.ground_motor.has_climbing_intent() and app.controller.telemetry().leg_force==0.0,"free-hand ground walking does not receive a second leg motor")
	app.queue_free()
	await ticks(3)
	print("FOOT INTEGRATION RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
