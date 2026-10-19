extends "res://features/grip_up/tests/test_pending_grip.gd"
## M3: real contact and bounded attachment, separate capture from retention.
var contact_report: Dictionary = {"attempts":[]}

func actual_contact(definition: Dictionary, id: int = 0, observe_time: float = .8) -> Dictionary:
	await setup(definition,false)
	controller.set_control_profile(3)
	controller.set_posture_policy(0)
	controller.tuning.allow_out_of_reach_grip_targets = true
	controller.transfer_diagnostics_enabled = true
	if definition.get("hand_fixture","")=="shoulder":
		# Explicit valid initial free-hand fixture for deliberately extreme
		# body speed; the legacy FREE gesture otherwise already trails >reach.
		controller.hands[id].hand_world = controller.get_shoulder_world(id)
	var pose := body.global_transform
	var velocity := body.linear_velocity
	var spin := body.angular_velocity
	var selected_point: Vector3 = anchor.world_point()
	var local_point: Vector3 = support.to_local(selected_point)
	var accepted: bool = controller.request_held_grip(id,support,selected_point,anchor.world_normal())
	var record: Dictionary = {"label":definition.label,"accepted":accepted,"start_distance":controller.get_shoulder_world(id).distance_to(selected_point),
		"caught":false,"arrival":-1.0,"precontact_zero":true,"valid_contact":true,"continuous":true,"finite":true,"caps":true,
		"peak_force":0.0,"peak_torque":0.0,"contact_pose":Transform3D.IDENTITY,"contact_velocity":Vector3.ZERO,"contact_spin":Vector3.ZERO,
		"request_preserved":body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin}
	var capture := func(_delta: float):
		var hand: Dictionary = controller.hands[id]
		var pending: Dictionary = controller.pending_diagnostics(id)
		var data: Dictionary = controller.telemetry()
		record.caps = record.caps and data.total_force<=360.001 and Vector3(data.torque).length()<=150.001 and Vector3(data.assist_torque).length()<=20.001
		record.peak_force = maxf(record.peak_force,data.total_force)
		record.peak_torque = maxf(record.peak_torque,Vector3(data.torque).length())
		if hand.state=="REACHING":
			record.precontact_zero = record.precontact_zero and hand.force==Vector3.ZERO and hand.reaction_force==Vector3.ZERO and hand.allocation==0.0
			record.finite = record.finite and pending.endpoint_valid and pending.gesture_speed<=4.0002
		if not record.caught and hand.state in ["ATTACHED","SLIPPING"]:
			record.caught = true
			record.arrival = controller.simulation_time-pending.selected_time
			record.contact_pose = body.global_transform
			record.contact_velocity = body.linear_velocity
			record.contact_spin = body.angular_velocity
			record.contact_distance = pending.contact_distance
			record.rest_at_contact = pending.contact_rest_length
			record.contact_capture = hand.capture.duplicate(true)
			record.pending_time = pending.pending_time
			record.valid_contact = controller.capture_evaluator.evaluate(controller,id).accepted and hand.anchor.local_point.is_equal_approx(local_point)
			record.finite = record.finite and pending.gesture_speed<=4.0002
	controller.sample_ready.connect(capture)
	await ticks(int(observe_time*hz))
	controller.sample_ready.disconnect(capture)
	record.state = controller.get_hand_state(id)
	record.reason = controller.hands[id].reason
	record.capture_failure = controller.hands[id].get("capture",{}).get("failure_reason","")
	record.retained = record.caught and record.state=="ATTACHED"
	record.events = controller.transfer_journal.events.map(func(event):return {"code":event.code,"stage":event.stage,"reason":event.reason})
	record.pending = controller.pending_diagnostics(id)
	record.final_velocity = body.linear_velocity
	contact_report.attempts.append(record.duplicate(true))
	return record

func simple_contact() -> void:
	var result: Dictionary = await actual_contact({"label":"static_valid"})
	check(result.accepted and result.request_preserved and result.caught and result.arrival>0.0,"current-valid held selection reaches actual contact finitely without request pose/velocity writes")
	check(result.valid_contact and result.precontact_zero and result.finite and result.caps,"new contact always passes actual evaluator, finite gesture and unchanged strength/assist limits")
	check(result.retained and result.pending.contact_time>0 and is_equal_approx(result.pending.pending_time,result.pending_time),"valid new grip retains and pending duration freezes at actual contact")
	check(result.pending.substate=="ATTACHED" and not controller.hands[0].held_target_pending and controller._attached_ids()==[0],"newly attached grip becomes one real support instead of remaining a zero-load pending hand")
	check(result.pending.contact_rest_length==clampf(result.pending.contact_distance,.18,.62),"rest target initializes from actual separation within unchanged existing target limits")
	var success: Array = controller.transfer_journal.events.filter(func(event):return event.code=="SUCCESS")
	check(success.size()==1 and success[0].candidate_world.is_equal_approx(controller.hands[0].anchor.world_point()) and success[0].contact_time==result.pending.contact_time,"journal SUCCESS records real contact time and original material point exactly once")
	var pose := body.global_transform
	var velocity := body.linear_velocity
	var spin := body.angular_velocity
	controller.set_hand_held(0,false,"input_released")
	check(controller.get_hand_state(0)=="RELEASED" and controller.hands[0].anchor==null and body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"held button-up releases an attached new grip synchronously and preserves momentum")
	await clear()

func incoming_contact() -> void:
	var result: Dictionary = await actual_contact({"label":"incoming_body","velocity":Vector3.UP*.9,"offset_y":1.0},0,1.0)
	check(result.start_distance>controller.get_max_reach() and result.caught,"initially distant static material target is caught by one continuous held gesture during natural incoming body motion")
	check(result.valid_contact and result.precontact_zero and result.finite and result.caps,"incoming catch retains exact current anatomical/contact/force authority")
	check(Vector3(result.contact_velocity).length()>.1 and result.contact_distance<=controller.get_max_reach()+.00005,"capture never erases incoming body momentum or substitutes a future reach point")
	await clear()

func maximum_reach_contact() -> void:
	var reach: float = Profile.new().max_reach_length
	var result: Dictionary = await actual_contact({"label":"full_anatomical_reach","offset_y":sqrt(reach*reach-.35*.35)},0,.7)
	check(result.caught and result.valid_contact and result.contact_distance<=reach+.00005,"full anatomical extension can establish actual current contact without enlarging reach")
	check(result.caught and result.rest_at_contact==.62 and result.contact_distance>.65 and result.caps,"full-reach catch caches real separation but retains .62rest/.04elastic authority and bounded blend")
	await clear()

func dynamic_reactions() -> void:
	var result: Dictionary = await actual_contact({"label":"incoming_dynamic","moving":true,"target_velocity":Vector3.DOWN*.4,"offset_y":.80},0,1.0)
	check(result.start_distance>controller.get_max_reach() and result.caught and result.valid_contact,"moving dynamic support reaches current contact on the selected local point")
	check(result.precontact_zero and result.finite and result.caps,"incoming moving support receives no force before valid finite contact")
	await clear()

func surface_at(point: Vector3, size: Vector3 = Vector3(.35,.35,.10)) -> StaticBody3D:
	var material := StaticBody3D.new()
	material.position = point-Vector3.BACK*size.z*.5
	material.collision_layer = 2
	material.collision_mask = 0
	material.set_meta("grippable",true)
	material.set_meta("grip_load_limit",10000.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	material.add_child(shape)
	world.add_child(material)
	return material

func two_hand_handoff() -> void:
	await setup({"label":"two_hand_handoff","velocity":Vector3.RIGHT*.4},false)
	controller.set_control_profile(3)
	controller.set_posture_policy(0)
	controller.request_grip(0,support,anchor.world_point(),anchor.world_normal())
	for frame in int(.5*hz):
		await tick()
		if controller.get_hand_state(0)=="ATTACHED":break
	check(controller.get_hand_state(0)=="ATTACHED","handoff starts on a physically caught left support")
	var original_anchor = controller.hands[0].anchor
	var original_rest: float = controller.hands[0].rest_length
	var point: Vector3 = controller.get_shoulder_world(1)+Vector3(.66,.08,-.25)
	var upper := surface_at(point)
	controller.tuning.allow_out_of_reach_grip_targets = true
	var pose := body.global_transform
	var velocity := body.linear_velocity
	var spin := body.angular_velocity
	check(controller.request_held_grip(1,upper,point,Vector3.BACK) and controller.pending_diagnostics(1).distance>controller.get_max_reach(),"second initially unreachable target is selected while preserving original real support")
	check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"pending second selection does not add an impulse or pose jump")
	var preserved := true
	var no_preload := true
	var caps := true
	for frame in int(1.1*hz):
		await tick()
		if controller.get_hand_state(1)=="REACHING":
			preserved = preserved and controller.hands[0].anchor==original_anchor and controller.hands[0].rest_length==original_rest and controller.hands[0].allocation==1.0
			no_preload = no_preload and controller.get_arm_force(1)==Vector3.ZERO
		caps = caps and controller.telemetry().total_force<=360.001 and Vector3(controller.telemetry().torque).length()<=150.001 and Vector3(controller.telemetry().assist_torque).length()<=20.001
		if controller.get_hand_state(1)=="ATTACHED":break
	check(preserved and no_preload,"supporting anchor/rest/allocation remain unchanged for the entire pending second attempt")
	check(controller.get_hand_state(0)=="ATTACHED" and controller.get_hand_state(1)=="ATTACHED","natural supported body motion earns the selected second contact without another press")
	if controller.get_hand_state(1)=="ATTACHED":
		var right_anchor = controller.hands[1].anchor
		await ticks(int(.20*hz))
		pose = body.global_transform
		velocity = body.linear_velocity
		spin = body.angular_velocity
		controller.release_grip(0,"input_released")
		check(controller.get_hand_state(1)=="ATTACHED" and controller.hands[1].anchor==right_anchor and body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"left release preserves new right anchor and instantaneous body momentum")
		await ticks(int(.2*hz))
		check(controller.get_hand_state(1)=="ATTACHED" and caps,"new single support retains with original globally shared force/torque limits")
	else:
		check(false,"left release preserves new right anchor and instantaneous body momentum")
		check(false,"new single support retains with original globally shared force/torque limits")
	contact_report.handoff = {"right_state":controller.get_hand_state(1),"right_reason":controller.hands[1].reason,"right":controller.pending_diagnostics(1),"old_preserved":preserved,"caps":caps}
	await clear()

func momentum(material: RigidBody3D) -> Dictionary:
	var actual := PhysicsServer3D.body_get_direct_state(material.get_rid())
	var center: Vector3 = actual.transform.origin+actual.center_of_mass
	var linear: Vector3 = actual.linear_velocity*material.mass
	var inertia := actual.inverse_inertia_tensor.inverse()
	return {"p":linear,"l":center.cross(linear)+inertia*actual.angular_velocity}

func free_pair_reaction() -> void:
	# A free anisotropic spinning capsule is a useful engine-control: measure
	# angular-momentum drift with absolutely no controller force before using
	# an isotropic-inertia closed pair to isolate action/reaction accounting.
	await setup({"label":"free_gyro_control","moving":true,"velocity":Vector3.DOWN*.4,"spin":Vector3(0,.12,.2)},false)
	body.collision_mask = 0
	await controller.sample_ready
	var free_l: Vector3 = momentum(body).l+momentum(support).l
	controller.set_physics_process(false)
	await ticks(int(.8*hz))
	var free_error: float = Vector3(momentum(body).l+momentum(support).l).distance_to(free_l)
	contact_report.gyroscopic_control = {"angular_drift_without_controller":free_error,"duration":.8}
	print("PENDING_GYRO_CONTROL ",free_error)
	await clear()
	await pair_trial(false,free_error)
	await pair_trial(true,free_error)

func pair_trial(isotropic: bool, free_error: float) -> void:
	await setup({"label":"free_pair_two_supports","moving":true,"velocity":Vector3.DOWN*.4,"spin":Vector3(0,.12,.2)},false)
	body.collision_mask = 0 # Closed force-pair fixture; avoid incidental contact constraints.
	if isotropic:body.inertia = Vector3(3,3,3) # Extra controlled-inertia trial; original anisotropic fixture is retained too.
	controller.set_control_profile(3)
	controller.tuning.allow_out_of_reach_grip_targets = true
	controller.transfer_diagnostics_enabled = true
	await controller.sample_ready
	var body_before: Dictionary = momentum(body)
	var support_before: Dictionary = momentum(support)
	var initial_p: Vector3 = body_before.p+support_before.p
	var initial_l: Vector3 = body_before.l+support_before.l
	controller.request_held_grip(0,support,anchor.world_point(),anchor.world_normal())
	controller.request_held_grip(1,support,anchor.world_point()+Vector3(.35,0,0),anchor.world_normal())
	var observed: Dictionary = {"linear_error":0.0,"angular_error":0.0,"reaction_error":0.0,"torque_error":0.0,"peak_assist":0.0,"dual_samples":0,"caps":true}
	var capture := func(_delta: float):
		var a: Dictionary = momentum(body)
		var b: Dictionary = momentum(support)
		observed.linear_error = maxf(observed.linear_error,Vector3(a.p+b.p).distance_to(initial_p))
		observed.angular_error = maxf(observed.angular_error,Vector3(a.l+b.l).distance_to(initial_l))
		var data: Dictionary = controller.telemetry()
		observed.caps = observed.caps and data.total_force<=360.001 and Vector3(data.torque).length()<=150.001 and Vector3(data.assist_torque).length()<=20.001
		if controller._attached_ids().size()==2:
			observed.dual_samples += 1
			var net_force := Vector3.ZERO
			var net_moment := Vector3.ZERO
			for id in 2:
				var hand: Dictionary = controller.hands[id]
				net_force += Vector3(hand.force)+Vector3(hand.reaction_force)
				net_moment += controller.get_shoulder_world(id).cross(hand.force)+Vector3(hand.anchor_world).cross(hand.reaction_force)
			var motion: Dictionary = controller.transfer_diagnostics().motion
			var reactions: Dictionary = motion.get("support_reactions",{})
			var reaction_torque := Vector3.ZERO
			for item in reactions.values():reaction_torque += Vector3(item.torque)
			observed.reaction_error = maxf(observed.reaction_error,net_force.length())
			observed.torque_error = maxf(observed.torque_error,net_moment.length()+Vector3(data.assist_torque+reaction_torque).length())
			observed.peak_assist = maxf(observed.peak_assist,Vector3(data.assist_torque).length())
	controller.sample_ready.connect(capture)
	await ticks(int(.8*hz))
	controller.sample_ready.disconnect(capture)
	print("PENDING_PAIR ",JSON.stringify({"isotropic":isotropic,"observed":observed,"initial_p":initial_p,"final_p":Vector3(momentum(body).p+momentum(support).p),"initial_l":initial_l,"final_l":Vector3(momentum(body).l+momentum(support).l),"gravity":[body.gravity_scale,support.gravity_scale],"damp":[body.linear_damp,support.linear_damp]}))
	check(observed.dual_samples>hz*.1 and controller._attached_ids().size()==2,"both new finite grips physically engage the same free dynamic support")
	check(observed.reaction_error<.00001 and observed.torque_error<.001 and observed.peak_assist>.01,"two anchors share one opposite support torque and conserve the applied pair force/moment wrench")
	if isotropic:
		check(observed.linear_error<.002 and observed.angular_error<.001,"isotropic closed Jolt pair conserves total linear/angular momentum through catches")
	else:
		check(observed.linear_error<.002 and observed.angular_error<=free_error+.005,"original anisotropic pair conserves linear momentum and angular drift stays inside measured unactuated control envelope")
	check(observed.caps,"two dynamic-support grips retain360N shared hand,20Nm assist and150Nm resultant authority")
	contact_report["isotropic_pair" if isotropic else "anisotropic_pair"] = observed
	await clear()

func speed_matrix() -> void:
	var slow: Dictionary = await actual_contact({"label":"timed_lateral_catch","velocity":Vector3.RIGHT*.7,"offset_x":1.0,"offset_y":.10},0,1.4)
	check(slow.start_distance>controller.get_max_reach() and slow.caught and slow.valid_contact,"timed moderate-speed reach window produces an actual earned catch from early selection")
	check(slow.precontact_zero and slow.finite and slow.caps and Vector3(slow.contact_velocity).length()>.1,"moderate catch respects finite hand travel and does not erase incoming speed")
	await clear()
	var fast: Dictionary = await actual_contact({"label":"window_too_short","velocity":Vector3.RIGHT*12.0,"offset_x":2.0,"offset_y":.10,"hand_fixture":"shoulder"},0,.45)
	check(fast.start_distance>controller.get_max_reach() and not fast.caught and fast.pending.missed_window_count>=1,"a deliberately short high-speed window can pass without any impossible guaranteed catch")
	check(fast.pending.last_window_reason=="HAND_TOO_SLOW" and fast.precontact_zero and fast.finite and Vector3(fast.final_velocity).length()>11.9,"miss is explained by finite hand travel while body momentum remains untouched")
	check(fast.pending.active and fast.pending.held and fast.state=="REACHING","a missed window does not invent a timeout or silently drop the still-held material target")
	await clear()

func weak_contact_retention() -> void:
	var result: Dictionary = await actual_contact({"label":"valid_contact_then_weak_load"},0,.5)
	check(result.caught and result.retained,"adverse load fixture starts from real captured/retained contact")
	support.set_meta("grip_load_limit",1.0)
	body.gravity_scale = 1.0 # Explicit fixture loading, no pose or velocity assignment.
	await ticks(int(.85*hz))
	var events: Array[Dictionary] = controller.transfer_journal.events
	var contact_index := -1
	var slip_index := -1
	var overload_index := -1
	for index in events.size():
		if events[index].code=="SUCCESS":contact_index = index
		if events[index].code=="GRIP_SLIP" and slip_index<0:slip_index = index
		if events[index].code=="CATCH_OVERLOAD":overload_index = index
	check(contact_index>=0 and slip_index>contact_index,"contact success and later real grip overload/slip are recorded as separate physical stages")
	check(controller.get_hand_state(0) in ["SLIPPING","FREE","RELEASED"] and controller.hands[0].reason in ["load_limit_exceeded","grip_overload","arm_extension_limit"],"weak support is allowed to lose an unsustainable catch instead of increasing strength")
	contact_report.weak = {"state":controller.get_hand_state(0),"reason":controller.hands[0].reason,"contact_event":contact_index,"slip_event":slip_index,"catch_overload_event":overload_index}
	await clear()

func fresh_capture_after_release() -> void:
	await actual_contact({"label":"capture_reset_regrip"})
	var old_time: float = controller.hands[0].capture.input_time
	controller.set_hand_held(0,false)
	await ticks(2)
	var point: Vector3 = controller.get_shoulder_world(0)+Vector3(0,1.4,-.35)
	var remote := surface_at(point)
	controller.request_held_grip(0,remote,point,Vector3.BACK)
	var fresh: Dictionary = controller.hands[0].capture
	check(fresh.input_time>old_time and fresh.actual_arrival==-1.0 and fresh.failure_reason=="" and fresh.persistent_target and not fresh.buffered,"regrip after old contact creates fresh capture metadata instead of inheriting prior arrival/failure")
	check(fresh.predicted_contact_time==-1.0 and controller.pending_diagnostics(0).contact_time==-1.0 and controller.get_hand_state(0)=="REACHING","new pending selection cannot advertise old catch time or prediction authority")
	controller.reset_state()
	check(not controller.pending_diagnostics(0).active and controller.hands[0].anchor==null and controller.get_arm_force(0)==Vector3.ZERO,"reset clears both pending/attached capture ownership without ghost effort")
	await clear()

func attached_lifecycle() -> void:
	for invalidation in ["ungrabbable","destroyed","reset"]:
		await actual_contact({"label":"attached_"+invalidation},0,.5)
		var pose := body.global_transform
		var velocity := body.linear_velocity
		var spin := body.angular_velocity
		match invalidation:
			"ungrabbable":support.set_meta("grippable",false)
			"destroyed":support.queue_free()
			"reset":controller.reset_state()
		await ticks(3)
		check(not controller.pending_diagnostics(0).active and controller.hands[0].anchor==null and controller.get_arm_force(0)==Vector3.ZERO,"new attached grip cannot survive invalid ownership: "+invalidation)
		check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"invalidating a neutral new attached grip causes no body impulse or pose reset: "+invalidation)
		await clear()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	await simple_contact()
	await incoming_contact()
	await maximum_reach_contact()
	await dynamic_reactions()
	await two_hand_handoff()
	await free_pair_reaction()
	await speed_matrix()
	await weak_contact_retention()
	await fresh_capture_after_release()
	await attached_lifecycle()
	check(no_early_force and budgets,"all observed new-branch steps respect zero precontact force and shared force/torque budgets")
	var file := FileAccess.open("res://builds/pending_grip_m3_%dhz.json" % hz,FileAccess.WRITE)
	file.store_string(JSON.stringify({"hz":hz,"checks":checks,"failures":failures,"report":contact_report},"\t"))
	print("PENDING CONTACT RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
