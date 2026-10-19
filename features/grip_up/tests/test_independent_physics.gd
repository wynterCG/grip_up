extends "res://features/grip_up/tests/test_drag_swing_physics.gd"
## v0.4 gates. No pointer/API traffic may become arm actuation in profile3.

func hold_gate() -> void:
	await setup(true,Vector3.ZERO,false,3)
	controller.set_posture_policy(0)
	var left: float=controller.hands[0].rest_length
	var right: float=controller.hands[1].rest_length
	var pose:=body.global_transform
	var velocity:=body.linear_velocity
	var spin:=body.angular_velocity
	check(not controller.queue_arm_length_delta(0,-100) and not controller.set_free_hand_target(1,Vector3.ZERO),"independent aim refuses direct arm drag and virtual hand targets")
	controller.set_contextual_effort(Vector2.ONE,Vector3.FORWARD)
	controller.set_climb_intent(1,1,1,Vector3.FORWARD)
	check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"aim/API setters preserve body pose and both velocities")
	for frame in hz:
		controller.set_contextual_effort(Vector2(sin(frame),cos(frame)),Vector3.FORWARD)
		controller.queue_arm_length_delta(0,-1)
		controller.queue_arm_length_delta(1,1)
		controller.set_climb_intent(1,1,1,Vector3.FORWARD)
		await tick()
	check(controller.hands[0].rest_length==left and controller.hands[1].rest_length==right,"HOLD_LENGTH cursor traffic never changes either target")
	check(controller.telemetry().aim_input_does_not_change_length and controller.telemetry().swing_intent==Vector3.ZERO,"independent assertion and zero unintended supported effort are explicit")
	check(not controller.request_launch_charge(true),"legacy charged impulse remains explicit opt-in")
	controller.release_grip(0)
	await ticks(hz/2)
	check(controller.get_hand_state(1)=="ATTACHED" and controller.hands[1].rest_length==right,"HOLD_LENGTH transfer preserves surviving hand target")
	controller.supported_wasd_swing_enabled=false
	controller.set_swing_intent(Vector3.RIGHT,Vector3.RIGHT)
	await ticks(hz)
	check(controller.telemetry().swing_torque.length()<.00001,"supported swing flag disables new effort independently of posture")
	await clear()

func auto_trial(policy: int, dual: bool) -> Dictionary:
	await setup(dual,Vector3.ZERO,false,3)
	var start:=body.position.y
	controller.set_posture_policy(policy)
	var limits:=true
	for frame in int(2.4*hz):
		controller.set_contextual_effort(Vector2(1,sin(frame)),Vector3.FORWARD)
		await tick()
		var data: Dictionary=controller.telemetry().posture
		for id in data.rates:
			limits=limits and absf(data.rates[id])<=.25001 and absf(data.accelerations[id])<=1.0001
	var result: Dictionary={"rise":body.position.y-start,"retained":controller.get_hand_state(0)=="ATTACHED","data":controller.telemetry().posture.duplicate(true)}
	print("INDEPENDENT AUTO policy=",policy," dual=",dual," rise=",result.rise," plan=",result.data)
	check(limits,"posture targets obey .25m/s and1m/s²; policy%d dual%s" % [policy,dual])
	if policy>0:
		check(result.retained and result.rise>.07,"absolute supported auto-plan creates actual physical rise; policy%d dual%s" % [policy,dual])
		check(result.data.planned_lengths[0]>.24 and result.data.planned_lengths[0]<.50,"comfortable target is geometric and distinct from minimum contraction")
		var event: int=result.data.event
		var target: float=controller.hands[0].rest_length
		await ticks(hz*3)
		check(controller.telemetry().posture.event==event and absf(controller.hands[0].rest_length-target)<.003,"unchanged support cannot continuously replan or climb")
		controller.posture_assist_enabled=false
		await ticks(hz/2)
		check(controller.hands[0].rest_length==target and controller.hands[0].posture_reason=="posture_assistance_inactive","posture flag independently restores current-length holding")
	await clear()
	return result

func policy_comparison() -> void:
	for dual in [false,true]:
		var hold: Dictionary=await auto_trial(0,dual)
		var pull: Dictionary=await auto_trial(1,dual)
		check(pull.rise>hold.rise+.07,"B adds supported rise compared with A at identical strength")
	await setup(true,Vector3.ZERO,false,3)
	supports[0].set_meta("grip_load_limit",150.0)
	supports[1].set_meta("grip_load_limit",500.0)
	controller.set_posture_policy(2)
	await ticks(hz*2)
	var data: Dictionary=controller.telemetry().posture
	check(data.allocations[1]>.65 and controller.hands[1].allocation>.60,"C gives greater shared allocation to support with higher geometric load capacity")
	check(controller.telemetry().total_force<=360.001 and controller._attached_ids().size()==2,"load-aware allocation never duplicates strength or loses healthy grips")
	await clear()

func blockers() -> void:
	await setup(true,Vector3.ZERO,false,3)
	var ceiling:=StaticBody3D.new()
	ceiling.position=body.position+Vector3(0,.905,0)
	ceiling.collision_layer=1
	ceiling.collision_mask=4
	var shape:=BoxShape3D.new()
	shape.size=Vector3(.25,.1,.45)
	var collision:=CollisionShape3D.new()
	collision.shape=shape
	ceiling.add_child(collision)
	world.add_child(ceiling)
	controller.set_posture_policy(1)
	await ticks(hz*3)
	var data: Dictionary=controller.telemetry().posture
	print("INDEPENDENT BLOCKED ",data)
	check(data.state=="ABORTED" and data.reason in ["actuator_saturation","blocked_tracking_error"],"real obstructed body aborts bounded automatic settling")
	check(data.braking_advance<=.07,"safety braking adds at most finite stopping-distance target advance")
	var target: float=controller.hands[0].rest_length
	await ticks(hz)
	check(controller.hands[0].rest_length==target,"aborted blocked plan cannot keep winding actuator target")
	await clear()
	await setup(false,Vector3.ZERO,false,3)
	supports[0].set_meta("grip_load_limit",20.0)
	controller.set_posture_policy(1)
	var slipped:=false
	for frame in hz:
		await tick()
		if controller.get_hand_state(0)=="SLIPPING":
			slipped=true
			break
	await ticks(2)
	check(slipped and controller.telemetry().posture.reason=="support_slipping_or_lost","real overloaded grip stops automatic target advancement with explicit slip reason")
	await clear()
	await setup(false,Vector3.ZERO,false,3)
	controller.tuning.posture_body_surface_clearance=2.0
	controller.set_posture_policy(1)
	await ticks(2)
	check(controller.telemetry().posture.reason=="infeasible_supported_geometry" and controller.telemetry().posture.state=="ABORTED","infeasible comfortable body geometry is rejected without corrective teleport")
	await clear()

func fresh_blend_and_regrip() -> void:
	await setup(false,Vector3.ZERO,false,3)
	var point: Vector3=controller.hands[0].anchor.world_point()
	var normal: Vector3=controller.hands[0].anchor.world_normal()
	var support: PhysicsBody3D=controller.hands[0].anchor.support_body()
	controller.release_grip(0)
	controller.set_posture_policy(1)
	check(controller.request_grip(0,support,point,normal),"fresh actual regrip begins finite approach for blend regression")
	for frame in hz:
		await tick()
		if controller.get_hand_state(0)=="ATTACHED":
			break
	check(controller.telemetry().posture.state=="ACTIVE","fresh blend waits rather than falsely completing unadvanced target")
	await ticks(hz*3)
	var planned: float=controller.telemetry().posture.planned_lengths[0]
	var height:=body.position.y
	var max_height:=height
	var same:=true
	for attempt in 5:
		point=controller.hands[0].anchor.world_point()
		normal=controller.hands[0].anchor.world_normal()
		controller.release_grip(0)
		var accepted: bool=controller.request_grip(0,support,point,normal)
		for frame in hz:
			await tick()
			if controller.get_hand_state(0)=="ATTACHED":
				break
		same=same and accepted and controller.get_hand_state(0)=="ATTACHED"
		await ticks(hz)
		if not controller.telemetry().posture.is_empty() and controller.telemetry().posture.has("planned_lengths"):
			same=same and absf(controller.telemetry().posture.planned_lengths.get(0,-1)-planned)<.00001
		max_height=maxf(max_height,body.position.y)
	check(same,"same material point regrips reuse exactly the same absolute target")
	check(max_height<height+.05,"five same-point regrips cannot grant repeated height increments")
	await clear()

func dynamic_plan() -> void:
	await setup(true,Vector3.ZERO,true,3,true)
	var before:=momentum()
	controller.set_posture_policy(1)
	await ticks(hz)
	var after:=momentum()
	check(Vector3(after.linear).distance_to(before.linear)<.001 and Vector3(after.angular).distance_to(before.angular)<.01,"automatic posture work retains opposite forces and torques on moving shared beam")
	check(supports[0].linear_velocity.length()>.001,"automatic pull moves the finite-mass support instead of treating it as world")
	await clear()

func tilt_trial(enabled: bool, mode: String="passive") -> Dictionary:
	await setup(false,Vector3.ZERO,false,3)
	controller.posture_tilt_assist_enabled=enabled
	controller.set_posture_policy(1)
	await ticks(hz*2)
	var angle:=0.0
	var amplitude:=0.0
	var speed:=0.0
	var pivot: Vector3=controller.hands[0].anchor_world
	for frame in hz*4:
		var direction:=Vector3.RIGHT*signf(body.linear_velocity.x) if mode=="pump" else Vector3.ZERO
		controller.set_swing_intent(direction,Vector3.RIGHT)
		await tick()
		if frame>hz*2:
			angle=maxf(angle,acos(clampf(body.global_basis.y.dot(Vector3.UP),-1,1)))
			amplitude=maxf(amplitude,absf(body.position.x-pivot.x))
			speed=maxf(speed,absf(body.linear_velocity.x))
	var result: Dictionary={"tilt":angle,"amplitude":amplitude,"speed":speed,"retained":controller.get_hand_state(0)=="ATTACHED"}
	print("INDEPENDENT TILT enabled=",enabled," mode=",mode," ",JSON.stringify(result))
	await clear()
	return result

func supported_swing_gate() -> void:
	var off: Dictionary=await tilt_trial(false)
	var quiet: Dictionary=await tilt_trial(true)
	var pumped: Dictionary=await tilt_trial(true,"pump")
	check(quiet.tilt<off.tilt*.85,"bounded optional tilt assistance measurably reduces unsupported roll")
	check(pumped.retained and pumped.amplitude>quiet.amplitude+.05 and pumped.speed>quiet.speed+.10,"WASD can still pump real pendular motion with automatic posture enabled")
	var coast: float=await independent_brake(false)
	var brake: float=await independent_brake(true)
	check(brake<coast-.02,"opposite supported WASD still brakes momentum with automatic posture enabled")
	await setup(false,Vector3.ZERO,false,3)
	controller.set_posture_policy(1)
	await ticks(hz*2)
	controller.release_grip(0)
	await tick()
	var velocity:=body.linear_velocity
	controller.set_swing_intent(Vector3.RIGHT,Vector3.RIGHT)
	await ticks(hz/4)
	check(controller.telemetry().total_force==0 and controller.telemetry().assist_torque.length()==0 and absf(body.linear_velocity.x)<=absf(velocity.x)+.0001,"independent WASD without supports cannot supply airborne propulsion")
	await clear()

func independent_brake(brake: bool) -> float:
	await setup(false,Vector3.ZERO,false,3)
	controller.set_posture_policy(1)
	await ticks(hz*2)
	controller.set_swing_intent(Vector3.RIGHT,Vector3.RIGHT)
	await ticks(int(.45*hz))
	controller.set_swing_intent(Vector3.LEFT if brake else Vector3.ZERO,Vector3.RIGHT)
	await ticks(int(.45*hz))
	var velocity:=body.linear_velocity.x
	print("INDEPENDENT BRAKE active=",brake," velocity=",velocity)
	await clear()
	return velocity

func request_space(pressed: bool) -> bool:
	var pose:=body.global_transform
	var velocity:=body.linear_velocity
	var spin:=body.angular_velocity
	var accepted: bool=controller.request_launch_charge(pressed)
	check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"profile3 Space request preserves instantaneous pose and momentum")
	return accepted

func space_opt_in_and_new_catch() -> void:
	await setup(false,Vector3.ZERO,false,3)
	controller.set_posture_policy(1)
	await ticks(hz*2)
	check(not controller.request_launch_charge(true) and controller.telemetry().launch_state=="IDLE","Space OFF cannot initiate charge in independent profile")
	controller.experimental_launch_enabled=true
	check(request_space(true),"Space ON explicitly opts independent profile into preserved charged actuator")
	await ticks(int(.45*hz))
	check(controller.telemetry().launch_state=="CHARGING" and controller.get_hand_state(0)=="ATTACHED","profile3 preload retains its original real material anchor")
	check(request_space(false),"Space release begins real finite pulling phase")
	var shoulder: Vector3=controller.get_shoulder_world(1)
	var offset:=Vector3(.18,-.15,0)
	var point:=shoulder+offset
	var support:=StaticBody3D.new()
	support.position=point+offset.normalized()*.03
	support.collision_layer=2
	support.collision_mask=0
	support.set_meta("grip_load_limit",10000.0)
	var sphere:=SphereShape3D.new()
	sphere.radius=.03
	var collision:=CollisionShape3D.new()
	collision.shape=sphere
	support.add_child(collision)
	world.add_child(support)
	await ticks(2)
	var pose:=body.global_transform
	var velocity:=body.linear_velocity
	var spin:=body.angular_velocity
	var accepted: bool=controller.request_grip(1,support,point,-offset.normalized())
	check(accepted and body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"new mid-pull grip request adds no position or velocity impulse")
	var caught:=false
	var moving_catch:=false
	var completed:=false
	var speed_at_catch:=0.0
	for frame in int(.6*hz):
		await tick()
		if not caught and controller.get_hand_state(1)=="ATTACHED":
			caught=true
			speed_at_catch=body.linear_velocity.length()
			moving_catch=speed_at_catch>.10
		if controller.telemetry().launch_state=="COOLDOWN":
			completed=true
			break
	print("INDEPENDENT SPACE moving_catch_speed=",speed_at_catch," new_state=",controller.get_hand_state(1)," old_state=",controller.get_hand_state(0)," launch=",controller.telemetry().launch_state)
	check(completed and caught and moving_catch,"profile3 completes launch and catches through finite hand motion while body is moving")
	check(controller.get_hand_state(0) in ["FREE","RELEASED"] and controller.get_hand_state(1)=="ATTACHED" and controller.hands[1].support==support,"launch releases only original identities and preserves newly acquired anchor")
	await ticks(int(.6*hz))
	check(controller.get_hand_state(1)=="ATTACHED" and controller.hands[1].actual_length<=.6601,"new profile3 catch remains supported after launch timer and cooldown")
	controller.release_grip(1,"focus_lost")
	await ticks(2)
	check(controller._attached_ids().is_empty() and controller.telemetry().total_force==0 and controller.telemetry().assist_torque.length()==0,"focus-style safety release clears all new-catch force and torque")
	check(not controller.request_launch_charge(true),"Space ON still cannot create another airborne launch without a grip")
	var pose_before:=body.global_transform
	var velocity_before:=body.linear_velocity
	var spin_before:=body.angular_velocity
	controller.reset_state()
	check(body.global_transform==pose_before and body.linear_velocity==velocity_before and body.angular_velocity==spin_before and controller.posture_coordinator.plan.is_empty() and controller.telemetry().is_empty(),"reset clears launch/posture references without changing body momentum")
	await clear()

func independent_feature_and_release_gate() -> void:
	await setup(true,Vector3.ZERO,false,3)
	var left: float=controller.hands[0].rest_length
	var right: float=controller.hands[1].rest_length
	controller.independent_aim_enabled=false
	controller.set_posture_policy(2)
	await ticks(hz)
	check(controller.hands[0].rest_length==left and controller.hands[1].rest_length==right and controller.posture_coordinator.plan.is_empty(),"independent feature flag disables automatic planning while maintaining current grips")
	controller.independent_aim_enabled=true
	await ticks(hz/4)
	var pose:=body.global_transform
	var velocity:=body.linear_velocity
	var spin:=body.angular_velocity
	controller.release_grip(0,"ui_mouse_up")
	check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin and controller.get_hand_state(1)=="ATTACHED","UI-style single-hand release preserves survivor and exact instantaneous body state")
	controller.release_grip(1,"focus_lost")
	await ticks(2)
	check(controller.posture_coordinator.plan.is_empty() and controller.telemetry().total_force==0,"all-owner release during active plan cancels posture without residual effort")
	await clear()

func opted_launch_dynamic_reaction() -> void:
	await setup(true,Vector3.ZERO,true,3,true)
	# HOLD_LENGTH preserves a loaded launch stroke in this zero-gravity closed
	# system. Prior auto-pull would shorten the geometry before charge, leaving
	# the subsequent finite pull slack and making a reaction assertion vacuous.
	controller.set_posture_policy(0)
	controller.experimental_launch_enabled=true
	var before:=momentum()
	var support_velocity: Vector3=supports[0].linear_velocity
	check(request_space(true),"profile3 Space ON charges while both hands share a dynamic beam")
	await ticks(int(.45*hz))
	check(request_space(false),"dynamic supported charge begins preserved finite pull")
	await ticks(int(.4*hz))
	var after:=momentum()
	var dp: float=Vector3(after.linear).distance_to(before.linear)
	var dl: float=Vector3(after.angular).distance_to(before.angular)
	print("INDEPENDENT SPACE DYNAMIC dp=",dp," dL=",dl," support_dv=",Vector3(supports[0].linear_velocity).distance_to(support_velocity))
	check(dp<.001 and dl<.01,"profile3 opted launch preserves complete dynamic action/reaction momentum")
	check(Vector3(supports[0].linear_velocity).distance_to(support_velocity)>.001,"opted launch actually moves shared dynamic support")
	await clear()

func run() -> void:
	world=Node3D.new()
	root.add_child(world)
	await hold_gate()
	await policy_comparison()
	await blockers()
	await fresh_blend_and_regrip()
	await dynamic_plan()
	await supported_swing_gate()
	await space_opt_in_and_new_catch()
	await independent_feature_and_release_gate()
	await opted_launch_dynamic_reaction()
	check(budgets,"independent HOLD_LENGTH keeps360N20Nm150Nm")
	print("INDEPENDENT PHYSICS RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
