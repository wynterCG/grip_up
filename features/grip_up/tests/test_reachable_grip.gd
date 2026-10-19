extends "res://features/grip_up/tests/test_pending_contact.gd"
## Profile4 user override: resolve once to real reachable material, not a click teleport.
var resolution_report: Dictionary = {"runs":[]}

func selected(definition: Dictionary, profile_id: int = 4, flag: bool = true) -> void:
	await setup(definition,false)
	controller.set_control_profile(profile_id)
	controller.tuning.allow_out_of_reach_grip_targets = flag
	controller.intent_climb_enabled = false

func resolved_limit() -> void:
	await selected({"label":"wall_just_beyond","offset_y":.60})
	var clicked: Vector3 = anchor.world_point()
	var original_local: Vector3 = support.to_local(clicked)
	var pose := body.global_transform
	var velocity := body.linear_velocity
	var spin := body.angular_velocity
	check(controller.request_held_grip(0,support,clicked,Vector3.BACK),"profile4 accepts a click just outside anatomy for reachable same-surface resolution")
	var data: Dictionary = controller.pending_diagnostics(0)
	var resolved: Vector3 = controller.hands[0].anchor_world
	var local: Vector3 = support.to_local(resolved)
	check(data.contact_resolution_applied and data.original_selection_local.is_equal_approx(original_local) and data.original_selection_world==clicked and resolved.distance_to(clicked)>.02,"diagnostics preserve original click separately from actual resolved material contact")
	var contact_distance: float = controller.get_shoulder_world(0).distance_to(resolved)
	check(absf(contact_distance-controller.get_max_reach())<.000002,"resolved wall contact uses full existing anatomical reach, without90percent/artificial margin")
	check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin and controller.get_hand_state(0)=="REACHING","resolution itself neither attaches nor writes torso pose/velocity")
	var precontact_zero := true
	var finite := true
	var peak := 0.0
	var first_contact := -1.0
	var correct_material := true
	for index in int(.8*hz):
		await controller.sample_ready
		var hand: Dictionary = controller.hands[0]
		var pending: Dictionary = controller.pending_diagnostics(0)
		finite = finite and float(pending.get("gesture_speed",0.0))<=4.0002
		correct_material = correct_material and hand.anchor!=null and hand.anchor.support_body()==support and hand.anchor.local_point.distance_to(local)<.00001
		if hand.state=="REACHING":precontact_zero = precontact_zero and hand.force==Vector3.ZERO and hand.allocation==0.0
		elif hand.state=="ATTACHED" and first_contact<0:
			first_contact = controller.simulation_time-float(pending.selected_time)
			check(controller.capture_evaluator.evaluate(controller,0).accepted,"actual endpoint arrival at resolved full-extension surface passes unchanged capture evaluator")
		peak = maxf(peak,controller.get_arm_force(0).length())
	check(first_contact>0 and controller.get_hand_state(0)=="ATTACHED" and finite,"full-extension gesture reaches and retains a real contact finitely at4m/s")
	check(precontact_zero and peak>1.0 and controller.hands[0].rest_length==.62,"unattached reach exerts zero force; actual resolved contact can then transmit bounded axial traction")
	check(correct_material and controller.telemetry().total_force<=360.001 and controller.telemetry().assist_torque.length()<=20.001 and controller.telemetry().torque.length()<=150.001,"resolution stays fixed on the same material and preserves all shared caps")
	resolution_report.runs.append({"mode":"full_extension_wall","original_distance":data.original_selection_distance,"resolved_distance":contact_distance,"reach":controller.get_max_reach(),"contact_time":first_contact,"peak_force":peak,"state":controller.get_hand_state(0)})
	controller.set_hand_held(0,false,"input_released")
	check(controller.get_hand_state(0)=="RELEASED" and controller.get_arm_force(0)==Vector3.ZERO,"button-up releases resolved attachment immediately")
	await clear()

func legacy_and_cancel() -> void:
	await selected({"label":"profile3_exact","offset_y":.60},3,true)
	var clicked: Vector3 = anchor.world_point()
	check(controller.request_held_grip(0,support,clicked,Vector3.BACK),"profile3 retains original v0.6 distant selection")
	await ticks(int(.5*hz))
	check(controller.get_hand_state(0)=="REACHING" and controller.hands[0].anchor.world_point().distance_to(clicked)<.000001 and not controller.pending_diagnostics(0).has("contact_resolution_applied"),"profile3 keeps exact clicked point and zero-force pending instead of new clamping")
	check(controller.get_arm_force(0)==Vector3.ZERO,"profile3 exact unreachable point cannot supply a force")
	await clear()
	await selected({"label":"flag_off","offset_y":.60},4,false)
	check(not controller.request_held_grip(0,support,anchor.world_point(),Vector3.BACK) and controller.last_rejection=="out_of_reach","flagOFF retains original anatomical request rejection")
	await clear()
	await selected({"label":"cancel_before_contact","offset_y":.60})
	controller.request_held_grip(0,support,anchor.world_point(),Vector3.BACK)
	controller.set_hand_held(0,false,"input_focus_lost")
	await ticks(int(.6*hz))
	check(controller.get_hand_state(0)=="FREE" and controller.metrics.attaches==0 and controller.get_arm_force(0)==Vector3.ZERO,"cancelled resolved reach never attaches or applies delayed effort")
	await clear()

func invalid_proposals() -> void:
	for kind in ["plane_outside","missing_surface","other_collider"]:
		await selected({"label":kind,"offset_y":.60,"offset_z":-.90 if kind=="plane_outside" else -.35})
		if kind=="missing_surface":
			var shape: BoxShape3D = support.get_child(0).shape
			shape.size = Vector3(.04,.04,.10)
		var obstruction: StaticBody3D
		if kind=="other_collider":
			var shoulder: Vector3 = controller.get_shoulder_world(0)
			var projected: Vector3 = shoulder+Vector3(0,sqrt(controller.get_max_reach()*controller.get_max_reach()-.35*.35),-.35)
			obstruction = surface_at(shoulder.lerp(projected,.5),Vector3(.15,.15,.15))
			await ticks(2)
		var original: Vector3 = anchor.world_point()
		check(controller.request_held_grip(0,support,original,Vector3.BACK),"unresolvable %s remains a legitimate exact pending request" % kind)
		var pending: Dictionary = controller.pending_diagnostics(0)
		check(not pending.contact_resolution_applied and controller.hands[0].anchor.support_body()==support and controller.hands[0].anchor.world_point().distance_to(original)<.000001,"%s cannot attach to an imaginary plane or substitute another collider" % kind)
		await ticks(int(.5*hz))
		check(controller.get_hand_state(0)=="REACHING" and controller.get_arm_force(0)==Vector3.ZERO,"%s supplies zero force and no invented current contact" % kind)
		resolution_report.runs.append({"mode":kind,"reason":pending.contact_resolution_reason,"blocker":pending.contact_resolution_blocker_id})
		await clear()

func moving_material() -> void:
	await selected({"label":"moving_resolved_point","offset_y":.60,"moving":true,"target_velocity":Vector3.DOWN*.10})
	var initial_momentum: Vector3 = body.linear_velocity*body.mass+support.linear_velocity*support.mass
	var clicked: Vector3 = anchor.world_point()
	controller.request_held_grip(0,support,clicked,Vector3.BACK)
	var local: Vector3 = controller.hands[0].anchor.local_point
	var original_local: Vector3 = support.to_local(clicked)
	var fixed := true
	var early_zero := true
	for index in int(.7*hz):
		await controller.sample_ready
		var hand: Dictionary = controller.hands[0]
		fixed = fixed and hand.anchor!=null and hand.anchor.local_point.distance_to(local)<.000001 and hand.target_world.distance_to(support.to_global(local))<.00001
		if hand.state=="REACHING":early_zero = early_zero and hand.force==Vector3.ZERO
	var final_momentum: Vector3 = body.linear_velocity*body.mass+support.linear_velocity*support.mass
	check(fixed and local.distance_to(original_local)>.02,"resolved point stays fixed in moving material instead of sliding/re-resolving as body or support moves")
	check(early_zero and controller.get_hand_state(0)=="ATTACHED","moving resolved material still needs finite actual contact before support force")
	check(final_momentum.distance_to(initial_momentum)<.001,"traction after moving resolved contact preserves complete opposite linear reaction")
	check(controller.hands[0].capture.out_of_reach_selection and controller.hands[0].capture.contact_resolution_applied,"capture metadata retains original out-of-range selection after resolved contact succeeds")
	resolution_report.runs.append({"mode":"moving_material","momentum_residual":final_momentum.distance_to(initial_momentum),"resolved_local":local,"original_local":original_local,"state":controller.get_hand_state(0)})
	await clear()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	await resolved_limit()
	await legacy_and_cancel()
	await invalid_proposals()
	await moving_material()
	FileAccess.open("res://builds/reachable_grip_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify({"hz":hz,"checks":checks,"failures":failures,"report":resolution_report},"\t"))
	print("REACHABLE GRIP RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
