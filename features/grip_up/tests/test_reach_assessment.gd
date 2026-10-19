extends "res://features/grip_up/tests/test_capture_matrix.gd"
## M4 advisory review: actual physics bodies; no assessment can authorize contact.
const Assessment = preload("res://features/grip_up/scripts/reach_assessment.gd")
const Actuator = preload("res://features/grip_up/scripts/arm_actuator.gd")
var assessment = Assessment.new()
var review: Dictionary = {"cases":[]}

func assess() -> Dictionary:
	var pose := body.global_transform
	var velocity := body.linear_velocity
	var spin := body.angular_velocity
	var hands_before: Array[Dictionary] = controller.hands.duplicate(true)
	var metrics_before: Dictionary = controller.metrics.duplicate(true)
	var target_pose := support.global_transform
	var target_velocity: Vector3 = support.linear_velocity if support is RigidBody3D else support.constant_linear_velocity
	var target_spin: Vector3 = support.angular_velocity if support is RigidBody3D else support.constant_angular_velocity
	var predictive_flag: bool = controller.tuning.predictive_grip
	var result: Dictionary = assessment.evaluate(controller,0,support,anchor.world_point(),anchor.world_normal())
	read_only = read_only and pose==body.global_transform and velocity==body.linear_velocity and spin==body.angular_velocity and hands_before==controller.hands and metrics_before==controller.metrics and target_pose==support.global_transform and not result.authorization and predictive_flag==controller.tuning.predictive_grip
	read_only = read_only and target_velocity==(support.linear_velocity if support is RigidBody3D else support.constant_linear_velocity) and target_spin==(support.angular_velocity if support is RigidBody3D else support.constant_angular_velocity)
	return result

func advisory_invariance() -> void:
	await setup({"label":"advisory_static"},false)
	controller.set_control_profile(3)
	var baseline := assess()
	check(baseline.classification=="IN RANGE" and baseline.reachable_now and not baseline.authorization and not baseline.timing_certified,"stationary real surface assessment is geometric eligibility, never attachment authority")
	var camera := Camera3D.new()
	world.add_child(camera)
	var invariant := true
	for index in 12:
		camera.position = Vector3(sin(index)*5,4,cos(index)*5)
		camera.rotation = Vector3(index*.1,index*.5,0)
		controller.set_contextual_effort(Vector2(index*50,-index*30),camera.global_basis.x)
		controller.set_climb_intent(1,1,1,camera.global_basis.x)
		controller.set_swing_intent(Vector3.ZERO,camera.global_basis.x)
		invariant = invariant and assess()==baseline
	check(invariant,"pointer-like API traffic and camera orbit leave same-world-point advisory bit-identical")
	check(controller.get_hand_state(0)=="FREE" and controller.get_arm_force(0)==Vector3.ZERO and controller.metrics.attempts==0 and not controller.tuning.predictive_grip,"advisory polling neither starts reach nor enables the physical buffer")
	var copy: Dictionary = baseline.duplicate(true)
	baseline.window_intervals.clear()
	check(assess().window_intervals==copy.window_intervals,"caller-owned assessment cannot mutate later forecast state")
	controller.grounded_for_walking = true
	check(assess().confidence=="low_ground_contacts_unmodelled","known ground-contact constraints lower advisory confidence")
	controller.grounded_for_walking = false
	check(controller.request_grip(1,support,anchor.world_point(),anchor.world_normal()),"supported-confidence fixture requests a real second-side finite grip")
	for frame in hz/2:
		await tick()
		if controller.get_hand_state(1)=="ATTACHED":
			break
	check(controller.get_hand_state(1)=="ATTACHED" and assess().confidence=="low_supported_dynamics_unmodelled","actual attached-arm dynamics lower free-hand forecast confidence")
	check(assessment.evaluate(controller,-1,support,anchor.world_point(),anchor.world_normal()).classification=="UNAVAILABLE","invalid hand cannot become advisory authorization")
	check(not assessment.evaluate(controller,0,null,Vector3.ZERO,Vector3.UP).authorization,"invalid support cannot authorize a grip")
	await clear()

func finite_horizon_and_capture() -> void:
	await setup({"label":"long_actual_reach","offset_y":.55,"offset_z":-.30},false)
	controller.set_control_profile(3)
	var result := assess()
	check(result.reachable_now and result.current_distance_hand_time>result.horizon and result.predicted_contact_time<0 and result.arrival_outside_horizon,"valid current reach can require more finite hand travel than advisory horizon")
	check(result.classification=="IN RANGE" and result.contact_relative_velocity==null and not result.timing_certified,"unknown future arrival does not deny current eligibility or fabricate contact velocity")
	var immutable := result.duplicate(true)
	check(controller.request_grip(0,support,anchor.world_point(),anchor.world_normal()),"actual finite controller accepts valid request even when advisory contact is beyond horizon")
	check(assessment.evaluate(controller,0,support,anchor.world_point(),anchor.world_normal()).classification=="HAND BUSY","advisory cannot retarget an already reaching hand")
	var previous: Vector3 = controller.get_hand_world(0)
	var caught := false
	var duration := 0.0
	for frame in int(.6*hz):
		await tick()
		var current: Vector3 = controller.get_hand_world(0)
		if controller.get_hand_state(0) in ["REACHING","ATTACHED"]:
			finite_path = finite_path and current.distance_to(previous)<=4.0/hz+.0001
		previous = current
		if controller.get_hand_state(0)=="ATTACHED":
			caught = true
			duration = float(frame+1)/hz
			break
	check(caught and duration>result.horizon,"real finite contact occurs beyond short forecast rather than snapping into it")
	await ticks(hz/2)
	check(controller.get_hand_state(0)=="ATTACHED" and immutable.predicted_contact_time<0,"later actual retention does not rewrite immutable press-time unknown prediction")
	await clear()
	await setup({"label":"future_geometry_only","offset_y":.80,"velocity":Vector3.UP*2},false)
	controller.set_control_profile(3)
	result = assess()
	check(not result.reachable_now and result.status=="SOON" and not result.arrival_feasible and result.classification!="PREDICTED CATCH WINDOW","future anatomical window without finite arrival is not promoted to a catch window")
	check(result.get("advisory_reason","").contains("finite_hand_arrival_unknown") and not controller.request_grip(0,support,anchor.world_point(),anchor.world_normal()),"geometric-only SOON estimate leaves unbuffered actual out-of-range press rejected")
	await ticks(hz/8)
	check(controller.get_hand_state(0)=="FREE" and controller.get_arm_force(0)==Vector3.ZERO,"advisory alone never catches later when body enters reach")
	await clear()

func interval_sampling() -> void:
	await setup({"label":"exiting_window","offset_y":.30,"velocity":Vector3.BACK*2},false)
	controller.set_control_profile(3)
	var result := assess()
	var motion: Dictionary = predictor._motion(body)
	var target_motion: Dictionary = predictor._motion(support)
	var local_point: Vector3 = support.to_local(anchor.world_point())
	var inside := true
	var observed_exit := false
	for interval in result.window_intervals:
		for time in [interval.entry,interval.exit]:
			var shoulder: Vector3 = predictor._pose_at(motion,time,true)*controller.tuning.shoulder_left
			var point: Vector3 = predictor._pose_at(target_motion,time,false)*local_point
			inside = inside and shoulder.distance_to(point)<=controller.get_max_reach()+.000051
		if not interval.clipped:
			observed_exit = true
			var next_time: float = interval.exit+result.window_sample_resolution
			var shoulder: Vector3 = predictor._pose_at(motion,next_time,true)*controller.tuning.shoulder_left
			var point: Vector3 = predictor._pose_at(target_motion,next_time,false)*local_point
			inside = inside and shoulder.distance_to(point)>controller.get_max_reach()+.00005
	check(observed_exit and inside,"published window exit is the last sampled inside pose, not first known outside pose")
	check(result.window_sample_resolution<=1.0/120.0+.000001 and result.horizon>=.10 and result.horizon<=.25,"forecast intervals expose bounded horizon and explicit sample resolution")
	await clear()

func predicted_contact_velocity() -> void:
	await setup({"label":"finite_arrival_velocity","moving":true,"offset_y":.10,"offset_z":-.25,"target_velocity":Vector3(.15,0,0),"target_spin":Vector3(0,.2,0)},false)
	controller.set_control_profile(3)
	var result := assess()
	check(result.arrival_feasible and result.predicted_contact_time>=0 and result.predicted_contact_time<=result.horizon and result.contact_relative_velocity is Vector3,"finite in-horizon hand trajectory reports an estimated contact-relative velocity")
	if result.predicted_contact_time>=0:
		await ticks(ceili(float(result.predicted_contact_time)*hz))
		await controller.sample_ready
		var actual_relative: Vector3 = Actuator.point_velocity(body,controller.get_shoulder_world(0))-anchor.point_velocity()
		check(Vector3(result.contact_relative_velocity).distance_to(actual_relative)<.01,"predicted contact-relative velocity agrees with unconstrained real body/material-point motion")
	else:
		check(false,"predicted contact-relative velocity fixture requires a known finite arrival")
	check(controller.metrics.attempts==0 and controller.get_hand_state(0)=="FREE" and not result.timing_certified,"passing predicted contact time alone never starts or authorizes a physical catch")
	await clear()
	await setup({"label":"future_arrival","offset_y":-.80,"velocity":Vector3.DOWN*2},false)
	controller.set_control_profile(3)
	result = assess()
	print("ASSESSMENT FUTURE status=",result.status," entry=",result.predicted_entry_time," contact=",result.predicted_contact_time," classification=",result.classification)
	check(result.status=="SOON" and result.arrival_feasible and result.predicted_contact_time>=0 and result.classification=="PREDICTED CATCH WINDOW" and not result.authorization,"catch-window label requires both future geometric entry and finite predicted arrival")
	await clear()

func com_and_motion() -> void:
	await setup({"label":"moving_custom_COM","moving":true,"target_velocity":Vector3(.25,0,0),"target_spin":Vector3(0,1.1,0)},false)
	controller.set_control_profile(3)
	await controller.sample_ready
	var result := assess()
	check(result.confidence=="low_rotating_support" and result.predicted_support_angle>.15,"actual translating/rotating support lowers confidence and exposes angular forecast extent")
	var motion: Dictionary = predictor._motion(support)
	var point: Vector3 = anchor.world_point()
	var state := PhysicsServer3D.body_get_direct_state(support.get_rid())
	var center: Vector3 = support.global_position+state.center_of_mass
	var expected: Vector3 = support.linear_velocity+support.angular_velocity.cross(point-center)
	check(Vector3(result.target_velocity).distance_to(expected)<.00001,"material-point target velocity includes actual offset COM and angular lever")
	var analytic_pose: Transform3D = predictor._pose_at(motion,.10,false)
	var analytic_point: Vector3 = analytic_pose*anchor.local_point
	var start_point := point
	await ticks(int(.10*hz))
	await controller.sample_ready
	var error: float = anchor.world_point().distance_to(analytic_point)
	print("ASSESSMENT MOTION hz=",hz," target_error_100ms=",error," displacement=",anchor.world_point().distance_to(start_point))
	check(error<.012 and anchor.world_point().distance_to(start_point)>.01,"short-horizon material-point trajectory agrees with real unconstrained rigid motion")
	var shape: CollisionShape3D = support.get_child(0)
	shape.position = Vector3(.30,.12,-.08) # Fixture authors an asymmetric AUTO-COM body.
	support.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_AUTO
	await ticks(3)
	await controller.sample_ready
	state = PhysicsServer3D.body_get_direct_state(support.get_rid())
	center = support.global_position+state.center_of_mass
	point = support.to_global(shape.position+Vector3.BACK*.05)
	var axis := Vector3.UP
	var angular_lever := (point-center).cross(axis)
	var exact: float = 1.0/support.mass+angular_lever.dot(support.get_inverse_inertia_tensor()*angular_lever)
	var naive_lever := (point-support.global_position).cross(axis)
	var naive: float = 1.0/support.mass+naive_lever.dot(support.get_inverse_inertia_tensor()*naive_lever)
	check(state.center_of_mass.length()>.1 and absf(naive-exact)>.001,"AUTO-COM fixture distinguishes real centroid from body origin")
	check(absf(assessment.inverse_point_mass(support,point,axis)-exact)<.000001,"effective point mass uses actual AUTO COM and rotational inverse inertia")
	motion = predictor._motion(support)
	expected = support.linear_velocity+support.angular_velocity.cross(point-center)
	check(assessment.point_velocity_at(support,motion,support.global_transform,point,0,false).distance_to(expected)<.00001,"advisory point velocity and effective mass agree on AUTO-COM lever")
	await clear()
	await setup({"label":"translating","moving":true,"target_velocity":Vector3(.25,0,0)},false)
	controller.set_control_profile(3)
	check(assess().confidence=="low_dynamic_constraints_unmodelled","translating dynamic body is not falsely treated as a known future static collider")
	await clear()
	await setup({"label":"body_rotation","spin":Vector3(0,1.0,0)},false)
	controller.set_control_profile(3)
	check(assess().confidence=="low_body_rotation_unmodelled","body angular trajectory uncertainty lowers confidence even on a fixed target")
	await clear()

func risk_and_obstruction() -> void:
	await setup({"label":"separating_risk","offset_y":.45,"offset_z":-.30,"velocity":Vector3.BACK*3},false)
	controller.set_control_profile(3)
	var result := assess()
	var estimate: Dictionary = result.catch_load_estimate
	print("ASSESSMENT RISK ",JSON.stringify(estimate))
	check(result.reachable_now and estimate.outward_speed>.1 and estimate.outward_energy>estimate.stopping_work_upper_bound+.01,"actual separating body exceeds current-axis finite stopping-work upper estimate")
	check(result.classification=="UNSAFE CATCH" and result.risk_reason.contains("estimated") and not result.authorization,"high-speed warning remains labelled advisory estimate")
	var axis: Vector3 = (anchor.world_point()-controller.get_shoulder_world(0)).normalized()
	var expected_mass: float = 1.0/assessment.inverse_point_mass(body,controller.get_shoulder_world(0),axis)
	check(absf(estimate.effective_point_mass-expected_mass)<.00001 and estimate.force_upper_bound<=360,"load warning uses rotational effective mass and unchanged hand budget")
	check(controller.request_grip(0,support,anchor.world_point(),anchor.world_normal()),"warning does not impose a new speed denial on an otherwise currently valid request")
	controller.release_grip(0,"input_released")
	await clear()
	await setup({"label":"blocked"},false)
	controller.set_control_profile(3)
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = 2
	obstacle.position = controller.get_shoulder_world(0).lerp(anchor.world_point(),.5)
	var box := BoxShape3D.new()
	box.size = Vector3(.1,.1,.1)
	var collision := CollisionShape3D.new()
	collision.shape = box
	obstacle.add_child(collision)
	world.add_child(obstacle)
	await ticks(2)
	result = assess()
	check(result.classification=="OBSTRUCTED" and not result.authorization and not controller.request_grip(0,support,anchor.world_point(),anchor.world_normal()),"real LOS obstacle stays an obstruction; advisory cannot bypass physical request rejection")
	await clear()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	await advisory_invariance()
	await finite_horizon_and_capture()
	await interval_sampling()
	await predicted_contact_velocity()
	await com_and_motion()
	await risk_and_obstruction()
	check(read_only,"all advisory evaluations preserve exact body/support pose, velocity, hand state, force flags and metrics")
	check(budgets and finite_path and no_early_force,"physical verification retains finite4m/s gestures, no pre-contact force and existing360N150Nm caps")
	print("REACH ASSESSMENT RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
