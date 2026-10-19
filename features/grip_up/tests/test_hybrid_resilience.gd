extends "res://features/grip_up/tests/test_intent_integration.gd"
## Negative/recovery contracts, never a substitute for F1/F2 functional ascent.
## Ordinary real-input approach unless a row explicitly says fixture fault injection.
var rows:Array=[]
var trace:Array=[]
var force_authority_ok:=true
var normal_shapes:Array=[]
var case_number:=0
var ground_support_truth_ok:=true
var native_ground_samples:=0

func snapshot(label:String)->Dictionary:
	var item:Dictionary={"label":label,"position":app.torso.global_position,"body_basis":app.torso.global_basis,"body_angular_velocity":app.torso.angular_velocity,"body_up":app.torso.global_basis.y.dot(Vector3.UP),"body_forward":-app.torso.global_basis.z,"grounded":app.ground_motor.grounded,"hand_states":app.controller.hands.map(func(hand):return hand.state),"hybrid":app.hybrid_mantle.data.duplicate(true),"shape_count":app.torso.get_child_count(),"shapes":shape_signature(),"force_authority_ok":force_authority_ok}
	rows.append(item)
	return item

func sample_guard(_delta:float)->void:
	if app.ground_motor.grounded:
		native_ground_samples+=1
		ground_support_truth_ok=ground_support_truth_ok and actual_sole_load()
	if app.controller.assisted_motion_owned:
		force_authority_ok=force_authority_ok and app.controller._attached_ids().is_empty() and app.controller.telemetry().get("total_force",0)==0 and app.controller.telemetry().get("leg_force",0)==0 and app.ground_motor.applied_force.length()<.0001 and app.ground_motor.applied_torque.length()<.0001
	if trace.is_empty() or int(trace[-1].case)!=case_number or app.controller.simulation_time-float(trace[-1].time)>=.05:
		trace.append({"case":case_number,"time":app.controller.simulation_time,"position":app.torso.global_position,"state":app.hybrid_mantle.state,"progress":app.hybrid_mantle.progress,"animation_progress":app.hybrid_mantle.animation_driver.progress,"commits":app.hybrid_mantle.commits,"restores":app.hybrid_mantle.restores,"freeze":app.torso.freeze})

func actual_sole_load()->bool:
	var state:=PhysicsServer3D.body_get_direct_state(app.torso.get_rid())
	if state==null or not is_instance_valid(app.ground_motor.support_body):return false
	for index in state.get_contact_count():
		var shape_index:int=state.get_contact_local_shape(index)
		if shape_index<0 or shape_index>=PhysicsServer3D.body_get_shape_count(app.torso.get_rid()):continue
		var node:Object=app.torso.shape_owner_get_owner(app.torso.shape_find_owner(shape_index))
		if node!=null and node.name=="FootBase" and state.get_contact_collider_id(index)==app.ground_motor.support_body.get_instance_id() and state.get_contact_impulse(index).dot(Vector3.UP)>.0001:return true
	return false

func open_case(scenario:int)->void:
	await fresh(0,false)
	app._open_hybrid_mantle(scenario)
	app.won=false
	await ticks(.4)
	case_number+=1
	normal_shapes=shape_signature()
	app.controller.sample_ready.connect(sample_guard)

func actual_grips()->bool:
	var left:bool=await grip(0,app.level.transfer_points[0])
	var right:bool=await grip(1,app.level.transfer_points[1])
	return left and right

func commit_low()->bool:
	await open_case(0)
	if not await actual_grips():return false
	Input.action_press("contract")
	for frame in 3*hz:
		await ticks(1.0/hz)
		if app.hybrid_mantle.commits>0:
			Input.action_release("contract")
			return true
	Input.action_release("contract")
	return false

func action_event(action:String,pressed:bool)->void:
	var event:=InputEventAction.new()
	event.action=action
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func shape_signature()->Array:
	var result:Array=[]
	for child in app.torso.get_children():
		if not child is CollisionShape3D:continue
		var size:Variant=child.shape.size if child.shape is BoxShape3D else Vector2(child.shape.radius,child.shape.height) if child.shape is CapsuleShape3D else child.shape.radius
		var stable_name:String="HeadSphere" if child.shape is SphereShape3D else str(child.name)
		result.append({"name":stable_name,"type":child.shape.get_class(),"size":str(size),"pose":str(child.transform),"disabled":child.disabled})
	return result

func reset_actual_input(label:String)->void:
	var old_body_id:int=app.torso.get_instance_id()
	action_event("restart",true)
	action_event("restart",false)
	await ticks(.15)
	check(app.torso.get_instance_id()!=old_body_id and not app.torso.freeze and not app.controller.assisted_motion_owned,label+" R creates fresh dynamic body without old assisted authority")
	check(app.hybrid_mantle.state=="DYNAMIC" and app.hybrid_mantle.commits==0 and app.hybrid_mantle.restores==0 and app.hybrid_mantle.progress==0,label+" R clears phase progress counters and pending route")
	check(shape_signature()==normal_shapes and not app.torso.has_meta("adaptive_legs") and not app.controller.physics_mantle_v08_enabled and not app.controller.palm_compression_enabled,label+" R restores full baseline shapes and keeps v08 capabilities OFF")
	check(app.torso.mass==12 and app.torso.collision_layer==4 and app.torso.collision_mask==3 and app.torso.gravity_scale==1 and not app.ground_motor.assisted_authority_suspended,label+" R restores normal mass collision filters gravity and ground authority")
	for id in 2:button(id,false)
	Input.action_release("contract")
	snapshot(label+" reset")

func geometry_rejections()->void:
	for scenario in [2,3,4,5]:
		await open_case(scenario)
		var obtained:bool=await actual_grips()
		check(obtained,"scenario%d refusal starts from genuine finite actual grips"%scenario)
		var observed:Array=[]
		Input.action_press("contract")
		for frame in int(1.8*hz):
			await ticks(1.0/hz)
			var reason:String=app.hybrid_mantle.reason
			if not observed.has(reason):observed.append(reason)
			if reason in ["TOO_NARROW","TARGET_OCCUPIED","CEILING_BLOCKED","PATH_BLOCKED","UNSUPPORTED_DYNAMIC_PLATFORM"]:break
		Input.action_release("contract")
		var expected:Array=["TOO_NARROW"] if scenario==2 else ["UNSUPPORTED_DYNAMIC_PLATFORM"] if scenario==5 else ["TARGET_OCCUPIED","CEILING_BLOCKED","PATH_BLOCKED"]
		check(observed.any(func(reason):return reason in expected),"scenario%d exposes live geometry/static-support rejection reason"%scenario)
		check(app.hybrid_mantle.commits==0 and not app.torso.freeze and not app.controller.assisted_motion_owned and not app.hybrid_mantle.completed,"scenario%d refused geometry never captures authority or declares completion"%scenario)
		var row:=snapshot("geometry rejection%d"%scenario)
		row["observed_reasons"]=observed
		for id in 2:button(id,false)
	# Distinct unsupported-body type. Replace static platform before any grip;
	# only fixture setup differs, then acquisition uses the normal real ray path.
	await open_case(0)
	var old:PhysicsBody3D=app.level.platform
	var animatable:=AnimatableBody3D.new()
	animatable.transform=old.transform
	animatable.collision_layer=old.collision_layer
	animatable.collision_mask=old.collision_mask
	animatable.set_meta("grippable",true)
	animatable.set_meta("grip_load_limit",460.0)
	for child in old.get_children():
		if child is CollisionShape3D:animatable.add_child(child.duplicate())
	app.level.add_child(animatable)
	app.level.platform=animatable
	old.queue_free()
	await ticks(.05)
	check(await actual_grips(),"AnimatableBody fixture earns actual grips without pretending it is static world")
	var found:Dictionary=app.hybrid_mantle.detector.detect()
	check(not found.eligible and found.eligibility_reason=="UNSUPPORTED_DYNAMIC_PLATFORM" and app.hybrid_mantle.commits==0,"AnimatableBody support explicitly rejected even at zero authored velocity")
	snapshot("animatable support rejection / fixture platform replacement before grip")

func before_commit_contracts()->void:
	await open_case(0)
	check(await actual_grips(),"precommit release fixture starts from actual held grips")
	for id in 2:button(id,false)
	Input.action_press("contract")
	await ticks(.3)
	check(app.controller._attached_ids().is_empty() and app.hybrid_mantle.commits==0 and not app.torso.freeze,"F6 release before commitment preserves immediate hold-to-grip release")
	Input.action_release("contract")
	snapshot("release before commit")
	await open_case(0)
	check(await actual_grips(),"precommit focus fixture starts from actual held grips")
	Input.action_press("contract")
	# Actual app focus-exit callback chain, emitted headlessly; no OS-window test.
	app.get_window().focus_exited.emit()
	app.get_window().focus_exited.emit()
	await ticks(.25)
	check(app.hybrid_mantle.commits==0 and app.controller._attached_ids().is_empty() and not Input.is_action_pressed("contract") and not app.torso.freeze,"repeated focus loss before commitment releases actions and creates no assisted start")
	snapshot("simulated actual focus callbacks before commit")

func pause_and_rearm()->void:
	var started:bool=await commit_low()
	check(started,"pause/rearm trial commits from ordinary low-ledge grip and W")
	if not started:return
	await ticks(.12)
	var hybrid:Node=app.hybrid_mantle
	var progress_before:float=hybrid.progress
	var body_before:Transform3D=app.torso.global_transform
	var animation_before:float=hybrid.animation_driver.progress
	var original_route:Transform3D=hybrid.route.standing
	action_event("controls_menu",true)
	action_event("controls_menu",false)
	await ticks(.3)
	check(app.settings.visible and hybrid.progress==progress_before and app.torso.global_transform.is_equal_approx(body_before),"Esc pause holds collision-body pose and validated route progress together")
	check(hybrid.animation_driver.progress==animation_before and app.torso.freeze and hybrid.commits==1,"pause holds animation pose progress without a second commit")
	app.camera.orbit(Vector2(120,0))
	app.camera.dolly(.3)
	check(hybrid.route.standing.is_equal_approx(original_route),"camera orbit/dolly cannot rewrite committed ledge/body route")
	action_event("controls_menu",true)
	action_event("controls_menu",false)
	# Duplicate callback injection: internal entry handler must also be idempotent.
	hybrid._commit()
	hybrid._commit()
	check(hybrid.commits==1 and hybrid.progress==progress_before,"repeated COMMIT callbacks cannot reinitialize active route or animation")
	for frame in 3*hz:
		await ticks(1.0/hz)
		if hybrid.state in ["DYNAMIC_GROUNDED","BLOCKED_RECOVERY"]:break
	check(hybrid.state=="DYNAMIC_GROUNDED" and hybrid.restores==1 and not app.torso.freeze,"paused committed action resumes and restores dynamic authority once")
	check(app.controller._attached_ids().is_empty() and not hybrid.allows_grip(0) and not app.request_hand(0),"stale held grip buttons cannot reattach at restored ledge")
	for id in 2:button(id,false)
	await ticks(.05)
	check(hybrid.allows_grip(0) and hybrid.allows_grip(1),"fresh grip release rearms normal acquisition after committed travel")
	var request_count:int=app.trial.attempts
	aim(Vector3(0,app.level.top_y,-.65))
	button(0,true)
	await ticks(.05)
	check(app.trial.attempts>request_count,"fresh real grip press reaches ordinary acquisition path after handoff")
	button(0,false)
	check(hybrid.commits==1 and hybrid.animation_driver.started_count==1,"rapid release/fresh grip input never duplicates mantle animation ownership")
	snapshot("pause resume stale-button rearm / no functional-walk claim")

func runtime_blocker()->void:
	var started:bool=await commit_low()
	check(started,"runtime blocker trial commits from ordinary valid geometry")
	if not started:return
	var hybrid:Node=app.hybrid_mantle
	var target:Transform3D=hybrid.route.sample(.48).pose
	var blocker:PhysicsBody3D=app.level.box("Runtime head corridor blocker",target.origin+Vector3.UP*.75,Vector3(.8,.15,.8),Color.ORANGE,false)
	for frame in 2*hz:
		await ticks(1.0/hz)
		if hybrid.state=="BLOCKED_RECOVERY":break
	check(hybrid.state=="BLOCKED_RECOVERY" and hybrid.progress<1 and not hybrid.completed,"runtime geometry stops route before false animation/ground completion")
	var stopped:Transform3D=app.torso.global_transform
	var animation_stop:float=hybrid.animation_driver.progress
	await ticks(.55)
	check(app.torso.global_transform.is_equal_approx(stopped) and hybrid.animation_driver.progress==animation_stop and app.torso.freeze,"blocked recovery preserves last safe collider and synchronized animation pose")
	check(hybrid.result=="BLOCKED / R TO RESTART" and hybrid.motor._audit(app.torso.global_transform,hybrid.motor.flex,0).get("clear",false),"persistent blocker exposes controlled reset without deep shape insertion")
	snapshot("runtime obstacle last safe recovery")
	blocker.queue_free()
	await reset_actual_input("runtime obstacle")

func committed_release()->void:
	var started:bool=await commit_low()
	check(started,"F5 release-after-commit fixture starts from real grip/W transition")
	if not started:return
	var before:float=app.hybrid_mantle.progress
	for id in 2:button(id,false)
	Input.action_release("contract")
	await ticks(.15)
	check(app.hybrid_mantle.state=="ASSISTED_TRAVERSE" and app.hybrid_mantle.progress>before and app.torso.freeze,"F5 releasing both grip buttons and W after commitment does not drop the coherent action")
	check(app.controller._attached_ids().is_empty() and not app.hybrid_mantle.allows_grip(0),"committed visual hand ownership never recreates old physical grip authority")
	snapshot("release after commit / reset before functional acceptance")
	await reset_actual_input("active traversal")

func interruption_resets()->void:
	var started:bool=await commit_low()
	check(started,"midcommit focus fixture starts from real input")
	if not started:return
	await ticks(.1)
	var progress_before:float=app.hybrid_mantle.progress
	app.get_window().focus_exited.emit()
	app.get_window().focus_exited.emit()
	await ticks(.55)
	check(app.hybrid_mantle.state=="BLOCKED_RECOVERY" and app.hybrid_mantle.progress==progress_before and app.hybrid_mantle.commits==1,"repeated focus loss midcommit retains one safe owned pose without auto-restart")
	check(app.hybrid_mantle.animation_driver.progress==progress_before and not Input.is_action_pressed("contract") and app.controller._attached_ids().is_empty(),"focus clears input and old grip authority while retaining synchronized authored pose")
	snapshot("simulated actual focus callbacks midcommit")
	await reset_actual_input("focus loss")
	started=await commit_low()
	check(started,"support invalidation fixture starts from actual input commitment")
	if not started:return
	app.level.platform.queue_free()
	await ticks(.55)
	check(app.hybrid_mantle.state=="BLOCKED_RECOVERY" and app.hybrid_mantle.reason=="SUPPORT_INVALIDATED" and not app.hybrid_mantle.completed,"destroyed support cannot retain eligibility or false completion")
	check(app.torso.freeze and app.controller.assisted_motion_owned and app.controller._attached_ids().is_empty(),"invalidated support retains controlled safe-reset ownership instead of uncontrolled dynamic release")
	snapshot("support invalidation")
	await reset_actual_input("invalid support")

func run()->void:
	await geometry_rejections()
	await before_commit_contracts()
	await pause_and_rearm()
	await committed_release()
	await runtime_blocker()
	await interruption_resets()
	check(force_authority_ok,"all observed assisted ticks have zero old hand foot ground force authority")
	check(ground_support_truth_ok and native_ground_samples>0,"v09 actual ground authority always has matched native sole load and was positively exercised")
	report={"physics_hz":hz,"checks":checks,"failures":failures,"scope":"M5 resilience and negative contracts; does NOT accept F1/F2,30cm walking or human feel","provenance":"ordinary in-app grip/W input; focus signals emitted headlessly; duplicate COMMIT callback explicitly fault-injected; Animatable fixture replaced before grip","rows":rows,"trace":trace,"force_authority_ok":force_authority_ok,"ground_support_truth_ok":ground_support_truth_ok,"native_ground_samples":native_ground_samples}
	FileAccess.open("res://builds/hybrid_resilience_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	app.queue_free()
	await ticks(.03)
	print("HYBRID RESILIENCE RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
