extends "res://features/grip_up/tests/test_drag_swing_physics.gd"
## M1 only: real finite requests and read-only diagnostic equivalence.
var emitted: Array[Dictionary] = []

func surface(id: int, offset: Vector3, dynamic := false) -> Dictionary:
	var point: Vector3 = controller.get_shoulder_world(id)+offset
	var support: PhysicsBody3D = RigidBody3D.new() if dynamic else StaticBody3D.new()
	support.position = point+offset.normalized()*.025
	support.collision_layer = 2
	support.collision_mask = 0
	support.set_meta("grip_load_limit",10000.0)
	if dynamic:
		support.gravity_scale = 0
		support.mass = 200
		support.can_sleep = false
	var shape := SphereShape3D.new()
	shape.radius = .025
	var collision := CollisionShape3D.new()
	collision.shape = shape
	support.add_child(collision)
	world.add_child(support)
	return {"support":support,"point":point,"normal":-offset.normalized()}

func enable() -> void:
	controller.transfer_diagnostics_enabled = true
	emitted.clear()
	controller.transfer_event.connect(func(event: Dictionary):emitted.append(event.duplicate(true)))

func last(id: int = 1) -> Dictionary:
	return controller.transfer_journal.last_by_hand.get(id,{})

func press(target: Dictionary, id: int = 1) -> bool:
	return controller.request_grip(id,target.support,target.point,target.normal)

func wait_contact(id: int = 1) -> bool:
	for frame in hz:
		await tick()
		if controller.get_hand_state(id) in ["ATTACHED","FREE","RELEASED"]:
			break
	return controller.get_hand_state(id)=="ATTACHED"

func request_classification() -> void:
	await setup(false,Vector3.ZERO,true,3)
	enable()
	var before_pose := body.global_transform
	var before_v := body.linear_velocity
	var before_w := body.angular_velocity
	controller.record_unselected_attempt(1)
	check(last().code=="CONTACT_REJECTED" and last().stage=="REQUEST" and last().candidate_world==null and last().local_point==null and not last().has_candidate,"empty pointer press records rejection without an invented material point")
	check(body.global_transform==before_pose and body.linear_velocity==before_v and body.angular_velocity==before_w,"diagnostic-only empty press cannot change physical body state")
	var far := surface(1,Vector3(0,.8,-.08))
	await ticks(2)
	check(not press(far) and last().code=="POSE_UNREACHABLE" and last().anatomical_distance>last().max_reach and last().stage=="REQUEST","actual out-of-reach request is a pose failure, not catch failure")
	var failed_id: int = last().attempt_id
	controller.release_grip(1,"manual")
	check(last().attempt_id==failed_id and last().code=="POSE_UNREACHABLE","cleanup manual release cannot erase rejected attempt diagnosis")
	controller.record_unselected_attempt(1,"no_surface")
	check(last().attempt_id>failed_id and last().reason=="no_surface" and last().primary_failure=="CONTACT_REJECTED","new attempt clears earlier manual/rejection history")
	var valid := surface(1,Vector3(.06,.4,-.08))
	await ticks(2)
	check(not controller.request_grip(1,valid.support,valid.point,Vector3.ZERO) and last().code=="CONTACT_REJECTED","malformed surface normal is contact rejection without pose inference")
	var obstacle := StaticBody3D.new()
	obstacle.position = controller.get_shoulder_world(1).lerp(valid.point,.5)
	obstacle.collision_layer = 2
	var box := BoxShape3D.new()
	box.size = Vector3(.12,.10,.12)
	var col := CollisionShape3D.new()
	col.shape = box
	obstacle.add_child(col)
	world.add_child(obstacle)
	await ticks(2)
	check(not press(valid) and last().code=="PATH_OBSTRUCTED" and last().stage=="REQUEST","real LOS obstacle is distinguished from anatomical reach")
	var rows: Array[Dictionary] = controller.transfer_journal.events
	var retained_reason: String = rows[0].reason
	rows[0].reason = "external_mutation"
	var copied: Dictionary = controller.transfer_diagnostics(true)
	copied.events.clear()
	check(controller.transfer_journal.events[0].reason==retained_reason and not controller.transfer_journal.events.is_empty(),"journal and explicit event snapshots are detached immutable copies")
	check(not controller.transfer_diagnostics().has("events") and not controller.telemetry().get("transfer_diagnostics",{}).has("events"),"default sampled diagnostics omit the event ring")
	for attempt in 150:
		controller.record_unselected_attempt(1)
	check(controller.transfer_journal.events.size()==256 and emitted.size()>256,"journal remains bounded while event signal preserves live delivery")
	await clear()

func transit_failures() -> void:
	await setup(false,Vector3.ZERO,true,3)
	enable()
	controller.tuning.candidate_hold_timeout = .03 # fixture: finite path cannot finish in30ms.
	var target := surface(1,Vector3(0,.4,-.08))
	await ticks(2)
	check(press(target),"timeout fixture starts from eligible actual geometry")
	await ticks(hz/5)
	check(last().code=="HAND_TOO_SLOW" and last().stage=="TRANSIT" and last().contact_time<0 and last().minimum_remaining_hand_time>0,"observed timeout with currently visible target is transit, never retention")
	await clear()
	await setup(false,Vector3.ZERO,true,3)
	enable()
	target = surface(1,Vector3(0,.4,-.08),true)
	await ticks(2)
	check(press(target),"moving target is initially within real reach")
	target.support.linear_velocity = Vector3(8,0,0) # fixture initial motion, no controller write.
	await ticks(hz/5)
	check(last().code=="TARGET_LEFT_REACH" and last().contact_time<0 and last().anatomical_distance>last().max_reach,"moving material target leaving envelope is not called a catch overload")
	await clear()
	await setup(false,Vector3.ZERO,true,3)
	enable()
	target = surface(1,Vector3(0,.4,-.08))
	await ticks(2)
	check(press(target),"support-loss fixture begins finite transit")
	target.support.queue_free()
	await ticks(3)
	check(last().code=="SUPPORT_LOST" and last().stage=="TRANSIT","disappearing support has distinct event before contact")
	await clear()

func contact_and_retention() -> void:
	await setup(false,Vector3.ZERO,true,3)
	controller.release_grip(0)
	enable()
	var target := surface(1,Vector3(.05,.43,-.08))
	target.support.set_meta("grip_load_limit",1.0)
	await ticks(2)
	check(press(target) and await wait_contact(),"contact fixture reaches actual surface at finite hand speed")
	var contact: Dictionary = last()
	check(contact.code=="SUCCESS" and contact.stage=="CONTACT" and contact.primary_failure=="" and contact.travel_distance>0 and contact.elapsed>0,"SUCCESS certifies contact only, with observed travel history")
	check(contact.predicted_contact_time==-1 and contact.window_remaining==-1 and contact.prediction=="not_evaluated","unknown future window and arrival prediction are explicit")
	body.gravity_scale = 1 # physical load begins after real contact.
	await ticks(int(.65*hz))
	var seen_catch := false
	var seen_slip := false
	for row in controller.transfer_journal.events:
		seen_catch = seen_catch or row.code=="CATCH_OVERLOAD"
		seen_slip = seen_slip or row.code=="GRIP_SLIP"
	check(seen_catch and seen_slip and contact.code=="SUCCESS","actual load limit crossing records catch overload/slip without rewriting contact SUCCESS")
	check(last().stage=="RETENTION" and last().primary_failure in ["CATCH_OVERLOAD","GRIP_SLIP"] and last().force_magnitude>=0,"retention failure keeps its own primary cause and measured load")
	await clear()

func owner_cancellation() -> void:
	await setup(false,Vector3.ZERO,true,3)
	controller.release_grip(0)
	enable()
	controller.tuning.predictive_grip = true
	var target := surface(1,Vector3(0,.70,-.04),true)
	await ticks(2)
	target.support.linear_velocity = Vector3.DOWN # Fixture incoming support window.
	var buffer = preload("res://features/grip_up/scripts/grip_intent_buffer.gd").new()
	check(buffer.press(controller,1,target.support,target.point,target.normal) and controller.hands[1].get("predictive_wait",false),"real held-intent buffer accepts an early SOON request while actual point is out of range")
	buffer.release(controller,1)
	check(last().code=="CANCELLED" and last().reason=="input_released" and last().primary_failure=="" and last().contact_time<0,"early held-button release is neutral cancellation, not contact rejection")
	check(buffer.press(controller,1,target.support,target.point,target.normal),"new held attempt after cancellation starts independently")
	controller.release_grip(1,"input_focus_lost")
	check(last().code=="CANCELLED" and last().reason=="input_focus_lost" and last().primary_failure=="","actual app focus-loss reason cancels reaching without fabricated failure")
	await ticks(hz/3)
	check(controller.get_hand_state(1)=="FREE" and controller.get_arm_force(1)==Vector3.ZERO,"cancelled pending attempts never attach later or supply hidden effort")
	await clear()

func dynamics_and_flags() -> void:
	await setup(true,Vector3.ZERO,true,3,true)
	enable()
	controller.set_swing_intent(Vector3.RIGHT,Vector3.RIGHT)
	await ticks(hz/3)
	var data: Dictionary = controller.transfer_diagnostics()
	var motion: Dictionary = data.motion
	var budget: Dictionary = motion.budget
	var reactions: Dictionary = motion.support_reactions
	var reaction_force := Vector3.ZERO
	var reaction_torque := Vector3.ZERO
	for value in reactions.values():
		reaction_force += Vector3(value.force)
		reaction_torque += Vector3(value.torque)
	check(reactions.size()==1 and reaction_torque.distance_to(-budget.assist)<.00001,"two anchors on one dynamic beam report one conserved opposite assist couple")
	check(reaction_force.distance_to(-controller.get_arm_force(0)-controller.get_arm_force(1))<.00001,"support force decomposition equals actual applied arm reaction")
	check((budget.attitude+budget.posture_tilt+budget.swing).distance_to(budget.assist)<.00001 and (budget.shoulder_moment+budget.leg_moment+budget.assist).distance_to(budget.total_moment)<.00001,"applied torque decomposition sums to existing shared budget telemetry")
	check(motion.pendulum_valid and motion.twist_valid and is_finite(motion.relative_rotation_energy) and is_finite(motion.arm_power) and is_finite(motion.estimated_grip_moment_work),"pendulum, anatomical twist, relative energy and estimated work are finite independent observations")
	check(motion.energy_scope.contains("excludes"),"energy accounting explicitly excludes external contacts/gravity/drag")
	controller.set_control_profile(0)
	controller.record_unselected_attempt(1)
	await ticks(2)
	check(not controller.transfer_diagnostics().enabled and controller.transfer_journal.events.is_empty() and not controller.telemetry().has("transfer_diagnostics"),"diagnostics enabled flag cannot activate outside independent profile3")
	controller.set_control_profile(3)
	controller.transfer_diagnostics_enabled = false
	controller.record_unselected_attempt(1)
	await ticks(2)
	check(not controller.transfer_diagnostics().enabled and controller.transfer_journal.events.is_empty(),"default/off gate leaves journal and telemetry inert")
	await clear()

func trace(enabled: bool) -> Array[Dictionary]:
	await setup(true,Vector3.ZERO,true,3,true)
	controller.transfer_diagnostics_enabled = enabled
	controller.set_posture_policy(1)
	var rows: Array[Dictionary] = []
	for frame in hz:
		controller.set_swing_intent(Vector3.RIGHT if frame<hz/2 else Vector3.LEFT,Vector3.RIGHT)
		await tick()
		rows.append({"p":body.global_position,"v":body.linear_velocity,"w":body.angular_velocity,
			"f0":controller.get_arm_force(0),"f1":controller.get_arm_force(1),"t":controller.telemetry().assist_torque,
			"s0":controller.get_hand_state(0),"s1":controller.get_hand_state(1),"l0":controller.hands[0].rest_length,"l1":controller.hands[1].rest_length})
	await clear()
	return rows

func unactuated_axis() -> void:
	# Tilt the actual asymmetric left shoulder lever into the horizontal plane.
	await setup(false,Vector3(0,0,atan2(.5241,.1919)),true,3)
	enable()
	var lever: Vector3 = controller.get_shoulder_world(0)-body.global_position
	controller.set_swing_intent(lever.slide(Vector3.UP).normalized(),Vector3.RIGHT)
	await ticks(hz/10)
	var matches := 0
	var maximum_unactuated_effort := 0.0
	for row in controller.transfer_journal.events:
		if row.code=="SWING_AXIS_UNACTUATED":
			matches += 1
			maximum_unactuated_effort = maxf(maximum_unactuated_effort,Vector3(row.applied_swing_torque).length())
	check(matches==1 and maximum_unactuated_effort<.02,"parallel horizontal request on actually rolled body logs unactuated axis once without inventing effort")
	await clear()

func difference(left: Array[Dictionary], right: Array[Dictionary]) -> Dictionary:
	var value := {"position":0.0,"velocity":0.0,"spin":0.0,"force":0.0,"torque":0.0,"length":0.0,"states":true}
	for i in left.size():
		value.position = maxf(value.position,Vector3(left[i].p).distance_to(right[i].p))
		value.velocity = maxf(value.velocity,Vector3(left[i].v).distance_to(right[i].v))
		value.spin = maxf(value.spin,Vector3(left[i].w).distance_to(right[i].w))
		value.force = maxf(value.force,maxf(Vector3(left[i].f0).distance_to(right[i].f0),Vector3(left[i].f1).distance_to(right[i].f1)))
		value.torque = maxf(value.torque,Vector3(left[i].t).distance_to(right[i].t))
		value.length = maxf(value.length,maxf(absf(left[i].l0-right[i].l0),absf(left[i].l1-right[i].l1)))
		value.states = value.states and left[i].s0==right[i].s0 and left[i].s1==right[i].s1
	return value

func equivalence() -> void:
	var off0 := await trace(false)
	var off1 := await trace(false)
	var on0 := await trace(true)
	var on1 := await trace(true)
	var repeat := difference(off0,off1)
	var active_repeat := difference(on0,on1)
	var enabled_delta := difference(off0,on0)
	print("TRANSFER EQUIVALENCE ",JSON.stringify({"off_off":repeat,"on_on":active_repeat,"off_on":enabled_delta}))
	var same: bool = enabled_delta.states and enabled_delta.length<.000001
	for key in ["position","velocity","spin","force","torque"]:
		same = same and enabled_delta[key]<=maxf(repeat[key],active_repeat[key])*2.0+.00001
	check(repeat.position<.002 and active_repeat.position<.002 and repeat.force<.03 and active_repeat.force<.03,"OFF/OFF and ON/ON control trials bound physical repeatability before comparison")
	check(same,"flag ON/OFF preserves physical trajectories, arm targets, forces, torque and hand states within measured repeatability")

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	await request_classification()
	await transit_failures()
	await contact_and_retention()
	await owner_cancellation()
	await dynamics_and_flags()
	await unactuated_axis()
	await equivalence()
	check(budgets and finite_reach,"diagnostics fixtures preserve finite hand motion and360N/20Nm/150Nm budgets")
	print("TRANSFER DIAGNOSTICS RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
