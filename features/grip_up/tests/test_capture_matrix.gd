extends SceneTree
## Deliberately well-conditioned physical catches, plus explicit adverse cases.
## Fixture transforms/velocities are assigned only before simulation starts.
const Profile = preload("res://features/grip_up/resources/biped_tuning.gd")
const Controller = preload("res://features/grip_up/scripts/climbing_controller.gd")
const Predictor = preload("res://features/grip_up/scripts/grip_capture_predictor.gd")
const Anchor = preload("res://features/grip_up/scripts/grip_anchor.gd")
var world: Node3D
var body: RigidBody3D
var controller: Node
var support: PhysicsBody3D
var anchor: RefCounted
var predictor = Predictor.new()
var hz := 120
var checks := 0
var failures := 0
var no_early_force := true
var budgets := true
var read_only := true
var finite_path := true
var request_continuity := true
var max_entry_error := 0.0
var entry_error_samples := 0
var max_contact_error := 0.0
var contact_error_samples := 0

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

func tick() -> void:
	await physics_frame
	if is_instance_valid(controller):
		var data: Dictionary = controller.telemetry()
		if not data.is_empty():
			budgets = budgets and data.total_force<=360.001 and data.torque.length()<=150.001
			for hand in controller.hands:
				if not hand.state in ["ATTACHED","SLIPPING"]:
					no_early_force = no_early_force and Vector3(hand.force).length()<0.00001

func ticks(count: int) -> void:
	for frame in count:
		await tick()

func setup(definition: Dictionary, enabled: bool) -> void:
	await physics_frame
	body = RigidBody3D.new()
	body.position = Vector3(0,3,0.50)
	body.rotation = definition.get("rotation",Vector3.ZERO)
	body.mass = 12
	body.gravity_scale = definition.get("gravity",0.0)
	body.linear_velocity = definition.get("velocity",Vector3.ZERO)
	body.angular_velocity = definition.get("spin",Vector3.ZERO)
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3.ZERO
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0
	body.angular_damp = 0
	body.collision_layer = 4
	body.collision_mask = 3
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.70
	capsule.radius = 0.20
	var body_shape := CollisionShape3D.new()
	body_shape.shape = capsule
	body.add_child(body_shape)
	world.add_child(body)
	var tuning := Profile.new()
	tuning.predictive_grip = enabled
	controller = Controller.new()
	world.add_child(controller)
	controller.configure(body,tuning)
	await ticks(maxi(1,int(0.05*hz)))
	var point: Vector3 = controller.get_shoulder_world(0)+Vector3(definition.get("offset_x",0.0),definition.get("offset_y",0.28),definition.get("offset_z",-0.35))
	var moving: bool = definition.get("moving",false)
	support = RigidBody3D.new() if moving else StaticBody3D.new()
	support.position = point-Vector3.BACK*0.05
	support.collision_layer = 2
	support.collision_mask = 0
	support.set_meta("grippable",true)
	support.set_meta("grip_load_limit",10000.0)
	if moving:
		support.mass = 30
		support.inertia = Vector3(3,3,3)
		support.gravity_scale = 0
		support.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		support.center_of_mass = Vector3(-0.25,0,0)
		support.linear_velocity = definition.get("target_velocity",Vector3.ZERO)
		support.angular_velocity = definition.get("target_spin",Vector3.ZERO)
		support.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		support.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		support.linear_damp = 0
		support.angular_damp = 0
	var box := BoxShape3D.new()
	box.size = Vector3(1.2,1.0,0.10)
	var target_shape := CollisionShape3D.new()
	target_shape.shape = box
	support.add_child(target_shape)
	world.add_child(support)
	anchor = Anchor.new(support,point,Vector3.BACK)
	await ticks(maxi(1,int(0.05*hz)))

func clear() -> void:
	controller.reset_state()
	for child in world.get_children():
		child.queue_free()
	controller = null
	body = null
	support = null
	anchor = null
	for frame in 3:
		await physics_frame

func evaluate() -> Dictionary:
	var pose: Transform3D = body.global_transform
	var velocity: Vector3 = body.linear_velocity
	var spin: Vector3 = body.angular_velocity
	var hand_state: Array = controller.hands.duplicate(true)
	var metrics: Dictionary = controller.metrics.duplicate(true)
	var support_pose: Transform3D = support.global_transform
	var support_velocity: Vector3 = support.linear_velocity if support is RigidBody3D else support.constant_linear_velocity
	var support_spin: Vector3 = support.angular_velocity if support is RigidBody3D else support.constant_angular_velocity
	var result: Dictionary = predictor.evaluate(controller,0,support,anchor.world_point(),anchor.world_normal())
	var after_velocity: Vector3 = support.linear_velocity if support is RigidBody3D else support.constant_linear_velocity
	var after_spin: Vector3 = support.angular_velocity if support is RigidBody3D else support.constant_angular_velocity
	read_only = read_only and pose==body.global_transform and velocity==body.linear_velocity and spin==body.angular_velocity and controller.hands==hand_state and controller.metrics==metrics and support_pose==support.global_transform and support_velocity==after_velocity and support_spin==after_spin and not result.authorization
	return result

func attempt(definition: Dictionary, enabled: bool, observe: bool = true) -> Dictionary:
	await setup(definition,enabled)
	var forecast: Dictionary = evaluate() if observe else {}
	var started := false
	var before_pose: Transform3D = body.global_transform
	var before_velocity: Vector3 = body.linear_velocity
	var before_spin: Vector3 = body.angular_velocity
	if enabled and controller.has_method("request_buffered_grip"):
		started = controller.request_buffered_grip(0,support,anchor.world_point(),anchor.world_normal())
	else:
		started = controller.request_grip(0,support,anchor.world_point(),anchor.world_normal())
	request_continuity = request_continuity and before_pose==body.global_transform and before_velocity==body.linear_velocity and before_spin==body.angular_velocity
	var caught := false
	var arrival := -1.0
	var actual_entry := 0.0 if controller.get_shoulder_world(0).distance_to(anchor.world_point())<=controller.get_max_reach()+0.00005 else -1.0
	var previous_hand: Vector3 = controller.get_hand_world(0)
	for frame in int(0.65*hz):
		await tick()
		var actual_distance: float = controller.get_shoulder_world(0).distance_to(anchor.world_point())
		if actual_entry<0 and actual_distance<=controller.get_max_reach()+0.00005:
			actual_entry = float(frame+1)/hz
		var endpoint: Vector3 = controller.get_hand_world(0)
		if controller.get_hand_state(0)=="REACHING" or (enabled and controller.get_hand_state(0)=="ATTACHED"):
			finite_path = finite_path and endpoint.distance_to(previous_hand)<=controller.tuning.hand_reach_speed/hz+0.0001 and endpoint.distance_to(controller.get_shoulder_world(0))<=controller.get_max_reach()+0.0001
		previous_hand = endpoint
		if controller.get_hand_state(0)=="ATTACHED":
			caught = true
			arrival = float(frame+1)/hz
			break
		if not started or controller.get_hand_state(0) in ["FREE","RELEASED"]:
			break
	if caught:
		# Isolate capturing incoming momentum from a subsequent active pull. An
		# immediate W dyno against an unconstrained light moving body is a separate
		# manipulation/load test, not a test of whether this catch was admissible.
		controller.set_climb_intent(0,0,0)
		await ticks(int(1.0*hz))
	var retained: bool = caught and controller.get_hand_state(0)=="ATTACHED"
	if started and actual_entry>=0 and forecast.get("predicted_entry_time",-1.0)>=0:
		max_entry_error = maxf(max_entry_error,absf(actual_entry-float(forecast.predicted_entry_time)))
		entry_error_samples += 1
	if caught and forecast.get("predicted_contact_time",-1.0)>=0:
		max_contact_error = maxf(max_contact_error,absf(arrival-float(forecast.predicted_contact_time)))
		contact_error_samples += 1
	var capture: Dictionary = controller.hands[0].get("capture",{})
	var result := {"label":definition.label,"enabled":enabled,"started":started,"caught":caught,"retained":retained,"arrival":arrival,"prediction":forecast,"reason":controller.hands[0].reason if started else controller.last_rejection,"position":body.position,"velocity":body.linear_velocity,"force":controller.get_arm_force(0)}
	print("CAPTURE ATTEMPT ",JSON.stringify({"label":definition.label,"flag":enabled,"caught":caught,"retained":retained,"retention_seconds":1.0,"post_capture_intent":"neutral","arrival":arrival,"predicted":forecast.get("predicted_contact_time",-1),"entry_actual":actual_entry,"entry_predicted":forecast.get("predicted_entry_time",-1),"status":forecast.get("status","not_called"),"reason":result.reason,"capture_failure":capture.get("failure_reason",""),"prediction_reason":forecast.get("prediction_reason","")}))
	await clear()
	return result

func pending_cancellation() -> void:
	await setup({"label":"pending_cancel","offset_y":0.80,"velocity":Vector3.UP*2.0},true)
	check(controller.request_buffered_grip(0,support,anchor.world_point(),anchor.world_normal()),"future-only target starts a finite pending gesture")
	await ticks(1)
	check(controller.get_hand_state(0)=="REACHING" and controller.hands[0].predictive_wait and controller.get_arm_force(0)==Vector3.ZERO,"pending hand moves with no force before actual reach")
	controller.release_grip(0)
	await ticks(int(0.30*hz))
	check(controller.get_hand_state(0)=="FREE" and controller.hands[0].anchor==null and controller.get_arm_force(0)==Vector3.ZERO,"releasing intent immediately cancels pending target and cannot auto-catch later")
	await clear()
	await setup({"label":"pending_support_removed","offset_y":0.80,"velocity":Vector3.UP*2.0},true)
	check(controller.request_buffered_grip(0,support,anchor.world_point(),anchor.world_normal()),"removable support starts pending before contact")
	support.queue_free()
	await ticks(3)
	check(controller.get_hand_state(0)=="FREE" and controller.hands[0].reason=="support_invalidated","losing the physical support invalidates its local pending anchor")
	await clear()
	await setup({"label":"outside_buffer","offset_y":0.90,"velocity":Vector3.UP*2.0},true)
	controller.tuning.capture_intent_buffer_duration = 0.10
	var forecast := evaluate()
	check(forecast.status=="SOON" and forecast.predicted_entry_time>0.10 and not controller.request_buffered_grip(0,support,anchor.world_point(),anchor.world_normal()) and controller.last_rejection=="outside_buffer_window","prediction beyond the held buffer cannot silently extend its lifetime")
	await clear()

func classifications() -> void:
	await setup({"label":"stationary"},true)
	var now := evaluate()
	check(now.status=="NOW" and now.reachable_now and now.predicted_entry_time==0.0,"stationary valid geometry is NOW without granting attachment")
	check(controller.get_hand_state(0)=="FREE","prediction cannot silently request a hand")
	controller.tuning.capture_prediction_horizon = 10.0
	var bounded_forecast := evaluate()
	check(bounded_forecast.horizon==0.25 and bounded_forecast.predicted_contact_time<=0.25,"prediction horizon is hard bounded to 250 ms")
	var invalid := predictor.evaluate(controller,0,support,Vector3(INF,0,0),Vector3.BACK)
	check(invalid.status=="UNAVAILABLE" and invalid.reason=="invalid_surface_point","non-finite candidate fails with a specific cause")
	support.set_meta("grippable",false)
	check(evaluate().reason=="surface_not_grippable","explicit non-grippable surfaces remain unavailable")
	support.set_meta("grippable",true)
	var block := StaticBody3D.new()
	block.position = controller.get_shoulder_world(0).lerp(anchor.world_point(),0.5)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4,0.4,0.06)
	shape.shape = box
	block.add_child(shape)
	world.add_child(block)
	await ticks(2)
	check(evaluate().reason=="surface_obstructed","real intervening geometry is unavailable rather than predicted through")
	await clear()
	await setup({"label":"outside","offset_y":1.2},true)
	var outside := evaluate()
	check(outside.status=="UNAVAILABLE" and outside.reason=="out_of_reach","stationary distant point is unavailable beyond bounded horizon")
	await clear()
	await setup({"label":"approaching","offset_y":0.72,"velocity":Vector3.UP*2.0},true)
	var soon := evaluate()
	check(soon.status=="SOON" and not soon.reachable_now and soon.predicted_entry_time>0 and soon.predicted_entry_time<=0.20,"approaching airborne torso exposes a bounded future reach window")
	check(not controller.request_grip(0,support,anchor.world_point(),anchor.world_normal()) and controller.last_rejection=="out_of_reach","SOON never bypasses the actual current-reach guard")
	await clear()
	await setup({"label":"rotating_support","moving":true,"target_spin":Vector3(0,0,1.5),"target_velocity":Vector3(0.2,0,0)},true)
	var moving := evaluate()
	var state := PhysicsServer3D.body_get_direct_state(support.get_rid())
	var expected: Vector3 = support.linear_velocity+support.angular_velocity.cross(anchor.world_point()-support.position-state.center_of_mass)
	check(Vector3(moving.target_velocity).distance_to(expected)<0.00001 and Vector3(moving.target_velocity).distance_to(support.linear_velocity)>0.2,"rotating support contact velocity includes its actual COM lever")
	await clear()
	await setup({"label":"conveyor"},true)
	support.constant_linear_velocity = Vector3(2,0,0)
	var conveyor := evaluate()
	check(Vector3(conveyor.target_velocity).distance_to(Vector3(2,0,0))<0.00001 and Vector3(conveyor.predicted_target).distance_to(anchor.world_point())<0.00001,"static conveyor velocity does not falsely translate its geometric surface")
	await clear()
	await setup({"label":"long_stationary_path","offset_y":0.50},true)
	await ticks(int(0.2*hz))
	var long_path := evaluate()
	check(long_path.status=="NOW" and long_path.predicted_contact_time<0 and not long_path.arrival_feasible,"valid current reach is not denied because a finite hand needs longer than the bounded forecast")
	await clear()
	await setup({"label":"outward_too_fast","velocity":Vector3.DOWN*3.0},true)
	var fast := evaluate()
	check(fast.status=="NOW" and fast.radial_speed>1.0 and not fast.arrival_feasible,"outward contact speed is reported without an arbitrary instantaneous speed rejection")
	await clear()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	await classifications()
	await pending_cancellation()
	var base_case := {"label":"disabled_equivalence"}
	var without := await attempt(base_case,false,false)
	var observed := await attempt(base_case,false,true)
	check(Vector3(without.position).distance_to(observed.position)<0.0001 and Vector3(without.velocity).distance_to(observed.velocity)<0.0001 and Vector3(without.force).distance_to(observed.force)<0.001,"disabled feature plus read-only forecast preserves baseline trajectory and forces")
	var categories := [
		{"label":"stationary"},
		{"label":"offset_crossed","offset_x":0.30,"offset_y":0.18,"rotation":Vector3(0,0.25,0)},
		{"label":"swing_toward","velocity":Vector3(0.6,0,0),"offset_x":0.12},
		{"label":"upward_launch","velocity":Vector3(0,1.5,0),"gravity":1.0},
		{"label":"angular_launch","velocity":Vector3(0,2.0,0),"spin":Vector3(0,1.0,0),"gravity":1.0},
		{"label":"moving_support","moving":true,"target_velocity":Vector3(0.2,0.10,0),"target_spin":Vector3(0,0,0.5)}
	]
	for enabled in [false,true]:
		var successes := 0
		var attempts := 0
		for category in categories:
			var category_success := 0
			for repetition in 4:
				var definition: Dictionary = category.duplicate(true)
				definition["offset_y"] = float(definition.get("offset_y",0.28))+(repetition-1.5)*0.01
				var result := await attempt(definition,enabled)
				attempts += 1
				if result.caught and result.retained:
					successes += 1
					category_success += 1
			check(category_success>=3,"designed %s catches remain repeatable, predictive=%s" % [category.label,enabled])
		print("CAPTURE MATRIX FLAG ",enabled," success=",successes," attempts=",attempts," ratio=",float(successes)/attempts)
		check(float(successes)/attempts>=0.90,"designed well-conditioned physical matrix reaches at least 90 percent")
	# Keep the discovered boundary case visible instead of silently counting a
	# late, already-descending catch as one of the well-conditioned success rigs.
	var adverse := await attempt({"label":"late_descending_angular_boundary","velocity":Vector3(0,1.1,0),"spin":Vector3(0,1.0,0),"gravity":1.0},false)
	check(adverse.caught and (adverse.retained or adverse.reason=="arm_extension_limit"),"late descending angular boundary records a retained catch or explicit anatomical failure")
	var soon_cases := [
		{"label":"soon_vertical_translation","offset_y":0.72,"velocity":Vector3.UP*2.0},
		{"label":"soon_lateral_swing","offset_x":0.75,"offset_y":0.05,"velocity":Vector3.RIGHT*2.0},
		{"label":"soon_moving_support","offset_y":0.72,"velocity":Vector3.UP*0.8,"moving":true,"target_velocity":Vector3.DOWN*0.4,"target_spin":Vector3(0,0,0.1)}
	]
	var soon_success := 0
	var soon_attempts := 0
	for category in soon_cases:
		for repetition in 4:
			var definition: Dictionary = category.duplicate(true)
			definition["offset_y"] = float(definition.get("offset_y",0.28))+(repetition-1.5)*0.004
			var disabled := await attempt(definition,false)
			check(not disabled.started and disabled.reason=="out_of_reach","disabled prediction preserves current-reach rejection for future-only targets")
			var enabled := await attempt(definition,true)
			soon_attempts += 1
			if enabled.caught and enabled.retained:
				soon_success += 1
	print("CAPTURE MATRIX SOON success=",soon_success," attempts=",soon_attempts," ratio=",float(soon_success)/soon_attempts)
	check(float(soon_success)/soon_attempts>=0.90,"held pending gesture captures at least 90 percent of well-conditioned future windows")
	var moving_adverse := await attempt({"label":"fast_free_rotating_support_boundary","offset_y":0.72,"velocity":Vector3.UP*1.2,"moving":true,"target_velocity":Vector3.DOWN*0.8,"target_spin":Vector3(0,0,0.2)},true)
	check(moving_adverse.caught and not moving_adverse.retained and moving_adverse.reason=="arm_extension_limit","fast unconstrained rotating support exposes a post-contact extension failure separately")
	check(read_only,"predictor never mutates hands, metrics, bodies, momentum or authorization")
	check(request_continuity,"buffered and immediate requests never assign body pose or velocities")
	check(finite_path,"pending and reaching hands keep finite speed and current anatomical reach")
	print("CAPTURE PREDICTION ERRORS entry_max=",max_entry_error," entry_samples=",entry_error_samples," contact_max=",max_contact_error," contact_samples=",contact_error_samples)
	check(entry_error_samples>0 and max_entry_error<=2.0/hz+1.0/120.0,"predicted entry timing agrees within sampled integration uncertainty")
	check(contact_error_samples>0 and max_contact_error<=2.0/hz+1.0/120.0,"reported in-horizon contact times agree with actual finite arrival")
	check(no_early_force,"no pending or reaching hand applies grip force before physical attachment")
	check(budgets,"all matrix captures retain shared 360 N / 150 Nm limits")
	print("CAPTURE MATRIX RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
