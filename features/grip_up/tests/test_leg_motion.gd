extends SceneTree
## Passive target tests plus an actual-app physical equivalence regression.
const Motion = preload("res://features/grip_up/scripts/biped_leg_motion.gd")
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
var checks := 0
var failures := 0
var hz := 120
var anatomy_ok := true
var no_targets: Array[Vector3] = []

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

func model() -> RefCounted:
	var motion = Motion.new()
	var hips: Array[Vector3] = [Vector3(-0.1,-0.04,0),Vector3(0.1,-0.04,0)]
	var feet: Array[Vector3] = [Vector3(-0.1,-0.86,0),Vector3(0.1,-0.86,0)]
	var lengths: Array[float] = [0.82,0.82]
	motion.configure(hips,feet,lengths)
	motion.reset(Transform3D(Basis.IDENTITY,Vector3(0,3,0)))
	return motion

func validate(motion: RefCounted, pose: Transform3D, suspended: bool) -> void:
	for hand in 2:
		var foot: Vector3 = motion.get_foot_world(hand)
		var length: float = foot.distance_to(pose*motion.hips[hand])
		anatomy_ok = anatomy_ok and foot.is_finite() and motion.get_knee_pole_world(hand).is_finite() and length<=motion.leg_lengths[hand]*0.999+0.00001
		if suspended:
			anatomy_ok = anatomy_ok and length>=motion.leg_lengths[hand]*0.998

func trajectory(rate: int) -> Dictionary:
	var motion = model()
	var dt := 1.0/rate
	var samples: Array[Vector3] = []
	var max_lag := 0.0
	var max_acceleration_lag := 0.0
	var extrema := 0
	var previous_slope := 0.0
	var previous_relative_x := 0.0
	var last_extremum := -1.0
	for frame in int(4.0*rate):
		var time := float(frame+1)/rate
		# Smooth body roll, then hold: feet should lag and settle as pendulums.
		var roll := 0.55*minf(time/0.4,1.0)
		var spin := Vector3(0,0,0.55/0.4 if time<=0.4 else 0.0)
		var pose := Transform3D(Basis(Vector3.BACK,roll),Vector3(0,3,0))
		motion.step(dt,pose,Vector3.ZERO,spin,false,no_targets)
		validate(motion,pose,true)
		var rigid_foot: Vector3 = pose*motion.rest_feet[0]
		max_lag = maxf(max_lag,rigid_foot.distance_to(motion.feet[0]))
		var relative_x: float = motion.directions[0].x
		var slope := relative_x-previous_relative_x
		if time>0.5 and slope*previous_slope<0 and time-last_extremum>0.25:
			extrema += 1
			last_extremum = time
		previous_relative_x = relative_x
		previous_slope = slope
		if (frame+1)%(rate/2)==0:
			samples.append(motion.feet[0])
	motion = model()
	# Accelerate right, reverse acceleration, then coast. No autonomous gait input.
	for frame in int(2.0*rate):
		var time := float(frame+1)/rate
		var position: float
		var speed: float
		if time<=0.6:
			position = 1.25*time*time
			speed = 2.5*time
		elif time<=1.2:
			var phase := time-0.6
			position = 0.45+1.5*phase-1.25*phase*phase
			speed = 1.5-2.5*phase
		else:
			position = 0.9
			speed = 0
		var pose := Transform3D(Basis.IDENTITY,Vector3(position,3,0))
		motion.step(dt,pose,Vector3(speed,0,0),Vector3.ZERO,false,no_targets)
		validate(motion,pose,true)
		max_acceleration_lag = maxf(max_acceleration_lag,absf(motion.directions[0].x))
		if (frame+1)%(rate/2)==0:
			samples.append(motion.feet[0])
	return {"samples":samples,"max_roll_lag":max_lag,"max_acceleration_lag":max_acceleration_lag,"extrema":extrema}

func contact_transition() -> void:
	var motion = model()
	var pose := Transform3D(Basis.IDENTITY,Vector3(0,3,0))
	var targets: Array[Vector3] = [pose*motion.hips[0]+Vector3.DOWN*0.55,pose*motion.hips[1]+Vector3.DOWN*0.55]
	var max_step := 0.0
	for frame in int(0.3*hz):
		var previous: Vector3 = motion.feet[0]
		motion.step(1.0/hz,pose,Vector3.ZERO,Vector3.ZERO,true,targets)
		max_step = maxf(max_step,previous.distance_to(motion.feet[0]))
		validate(motion,pose,false)
	check(absf(motion.current_lengths[0]-0.55)<0.001,"ground contact shortens the target and permits knee flexion")
	var lift_step := 0.0
	for frame in int(0.6*hz):
		var previous: Vector3 = motion.feet[0]
		motion.step(1.0/hz,pose,Vector3.ZERO,Vector3.ZERO,false,no_targets)
		lift_step = maxf(lift_step,previous.distance_to(motion.feet[0]))
		validate(motion,pose,false)
	check(absf(motion.current_lengths[0]-0.82*0.999)<0.0001,"suspended feet unfold to near full anatomical length")
	check(max_step<=4.0/hz+0.00001 and lift_step<=0.85/hz+0.00001,"contact-to-air transition has bounded finite motion without a foot jump")
	motion.constrain_foot(0,pose*motion.hips[0]+Vector3.DOWN*0.45,Vector3.UP)
	check(absf(motion.current_lengths[0]-0.45)<0.001,"a real obstacle constraint can flex the leg independently")
	var before: Vector3 = motion.feet[0]
	motion.step(0,pose,Vector3.ZERO,Vector3.ZERO,false,no_targets)
	check(motion.feet[0]==before,"zero-time update cannot jump the foot")

func app_trial(legs_enabled: bool) -> Dictionary:
	# The first trial otherwise starts from a deferred idle callback, whereas
	# later trials resume on physics_frame after teardown. Start every scene in
	# the same phase so its floor settling has exactly the same physics ticks.
	await physics_frame
	var app = Lab.new()
	app.input_profile = 0 # Explicitly exercise the preserved legacy control profile.
	root.add_child(app)
	current_scene = app
	app.biped.set_physics_process(legs_enabled)
	await ticks(int(0.75*hz))
	var actual_lengths: Array = app.biped.leg_motion.leg_lengths
	print("LEG AUTHORED LENGTHS ",actual_lengths)
	var support: PhysicsBody3D = app.level.holds[0]
	var shoulder: Vector3 = app.controller.get_shoulder_world(0)
	var query := PhysicsRayQueryParameters3D.create(shoulder,support.global_position,3,[app.torso.get_rid()])
	var hit: Dictionary = app.torso.get_world_3d().direct_space_state.intersect_ray(query)
	var attached: bool = not hit.is_empty() and app.controller.request_grip(0,support,hit.position,hit.normal)
	await ticks(int(0.7*hz))
	attached = attached and app.controller.get_hand_state(0)=="ATTACHED"
	Input.action_press("contract")
	await ticks(int(0.8*hz))
	Input.action_release("contract")
	var pose: Transform3D = app.torso.global_transform
	var linear: Vector3 = app.torso.linear_velocity
	var angular: Vector3 = app.torso.angular_velocity
	var force: Vector3 = app.controller.get_arm_force(0)
	var motion = app.biped.leg_motion
	motion.step(1.0/hz,pose,linear,angular,false,no_targets)
	app.biped._update_targets()
	app.biped.skeleton.advance(1.0/hz)
	check(app.torso.global_transform==pose and app.torso.linear_velocity==linear and app.torso.angular_velocity==angular and app.controller.get_arm_force(0)==force,"leg target integration and IK never alter torso state or physical grip force")
	var result := {"attached":attached and app.controller.get_hand_state(0)=="ATTACHED","position":app.torso.position,"linear":linear,"angular":angular,"force":force}
	app.queue_free()
	await ticks(4)
	return result

func coordinated_legs(coupled: bool) -> Dictionary:
	var motion = model()
	if not coupled:
		motion.coordination_stiffness = 0.0
		motion.coordination_damping = 0.0
	# Perturb just one leg. Both should share the motion progressively while
	# retaining an initial difference, rather than snapping to the same pose.
	motion.directions[0] = Basis(Vector3.BACK,0.55)*Vector3.DOWN
	var pose := Transform3D(Basis.IDENTITY,Vector3(0,3,0))
	var disagreement := 0.0
	var first_difference := 0.0
	var follower_peak := 0.0
	for frame in hz:
		motion.step(1.0/hz,pose,Vector3.ZERO,Vector3.ZERO,false,no_targets)
		var angle: float = motion.directions[0].angle_to(motion.directions[1])
		if frame==0:
			first_difference = angle
		if frame>hz/2:
			disagreement += angle/hz
		follower_peak = maxf(follower_peak,absf(motion.directions[1].x))
	return {"disagreement":disagreement,"initial":first_difference,"follower":follower_peak}

func run() -> void:
	var slow := trajectory(60)
	var fast := trajectory(120)
	print("LEG DYNAMICS 60 ",slow)
	print("LEG DYNAMICS 120 ",fast)
	check(slow.max_roll_lag>0.10 and fast.max_roll_lag>0.10,"rolling torso produces independent world-space foot lag")
	check(slow.extrema>=2 and fast.extrema>=2,"passive feet reverse direction and oscillate after torso roll")
	check(slow.max_acceleration_lag>0.05 and fast.max_acceleration_lag>0.05,"acceleration and reversal produce inertial legs without a scripted gait")
	var agreement := 0.0
	for i in slow.samples.size():
		agreement = maxf(agreement,slow.samples[i].distance_to(fast.samples[i]))
	print("LEG RATE AGREEMENT max_endpoint_error=",agreement)
	check(agreement<0.035,"60/120 Hz trajectories remain within 3.5 cm")
	await contact_transition()
	var independent := coordinated_legs(false)
	var coupled := coordinated_legs(true)
	print("LEG COORDINATION independent=",independent," coupled=",coupled)
	check(coupled.disagreement<independent.disagreement*0.65 and coupled.follower>0.05,"a disturbed leg gently draws the other into its swing instead of moving independently")
	check(coupled.initial>0.45,"leg coordination retains freedom and never snaps both legs into one rigid pose")
	check(anatomy_ok,"all passive targets stay finite, near straight in air, and within natural chain lengths")
	var enabled := await app_trial(true)
	var disabled := await app_trial(false)
	var enabled_repeat := await app_trial(true)
	var disabled_repeat := await app_trial(false)
	print("LEG REPEAT ENABLED position=",enabled.position.distance_to(enabled_repeat.position)," velocity=",enabled.linear.distance_to(enabled_repeat.linear)," force=",enabled.force.distance_to(enabled_repeat.force))
	print("LEG REPEAT DISABLED position=",disabled.position.distance_to(disabled_repeat.position)," velocity=",disabled.linear.distance_to(disabled_repeat.linear)," force=",disabled.force.distance_to(disabled_repeat.force))
	# Complex contact/turn control can vary by a few floating-point ulps between
	# independent scene instances. Five millinewtons is below 0.005% of weight;
	# the enabled-versus-disabled comparison below keeps its stricter tolerance.
	check(enabled.position.distance_to(enabled_repeat.position)<0.0001 and enabled.linear.distance_to(enabled_repeat.linear)<0.0001 and enabled.force.distance_to(enabled_repeat.force)<0.005,"enabled-to-enabled control has repeatable physical state")
	check(disabled.position.distance_to(disabled_repeat.position)<0.0001 and disabled.linear.distance_to(disabled_repeat.linear)<0.0001 and disabled.force.distance_to(disabled_repeat.force)<0.005,"disabled-to-disabled control has repeatable physical state")
	check(enabled.attached and disabled.attached and enabled_repeat.attached and disabled_repeat.attached,"actual playable biped retains an active grip with passive legs enabled/disabled")
	print("LEG BODY EQUIVALENCE position=",enabled.position.distance_to(disabled.position)," velocity=",enabled.linear.distance_to(disabled.linear)," force=",enabled.force.distance_to(disabled.force))
	check(enabled.position.distance_to(disabled.position)<0.0001 and enabled.linear.distance_to(disabled.linear)<0.0001 and enabled.force.distance_to(disabled.force)<0.001,"enabling passive legs preserves actual torso trajectory and actuator forces")
	print("LEG MOTION RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
