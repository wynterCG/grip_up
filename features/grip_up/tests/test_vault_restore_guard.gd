extends "res://features/grip_up/tests/test_hybrid_resilience.gd"
## Ordinary finite grips and W reach RESTORE_DYNAMIC. Only the support is
## fault-injected there: no test writes the character's pose or velocity.
var guard_trials:Array=[]

func restore_fixture(flag:bool)->bool:
	await fresh(0,false)
	app._open_hybrid_mantle(0,flag)
	app.won=false
	await ticks(.4)
	normal_shapes=shape_signature()
	check(app.hybrid_mantle.contextual_vault_v10_enabled==flag and app.hybrid_mantle.animation_driver.contextual_vault_v10_enabled==flag,"flag %s reaches driver before configuration"%flag)
	if not await actual_grips():
		check(false,"fixture acquires actual finite grips")
		return false
	Input.action_press("contract")
	for frame in 5*hz:
		await ticks(1.0/hz)
		if app.hybrid_mantle.commits>0:break
	Input.action_release("contract")
	for id in 2:button(id,false)
	for frame in 3*hz:
		await ticks(1.0/hz)
		if app.hybrid_mantle.state=="RESTORE_DYNAMIC":break
	var entered:bool=app.hybrid_mantle.state=="RESTORE_DYNAMIC"
	check(entered and not app.torso.freeze and not app.hybrid_mantle.motor.active,"flag %s intercepts real RESTORE after native motor unfreeze"%flag)
	return entered

func invalid_restore(flag:bool,fault:String)->void:
	if not await restore_fixture(flag):return
	var hybrid:Node=app.hybrid_mantle
	var platform:PhysicsBody3D=app.level.platform
	var support_pose:Transform3D=platform.global_transform
	var before_pose:Transform3D=app.torso.global_transform
	var before_shapes:Array=shape_signature()
	var shape_ids:Array=app.torso.get_children().filter(func(node):return node is CollisionShape3D).map(func(node):return node.shape.get_instance_id())
	# Exact RESTORE window: the motor already restored original geometry and
	# relinquished its frozen state, but native ground handoff has not happened.
	if fault=="velocity":platform.constant_linear_velocity=Vector3(.4,0,0)
	elif fault=="moved":platform.position+=Vector3(4,0,0)
	else:
		platform.free()
	check(not hybrid._same_support(),"%s support fault invalidates committed material snapshot"%fault)
	# Execute the real next state-machine callback at a known phase so the test
	# can detect even a tiny pose rewind independently of Jolt's next integration.
	hybrid.set_physics_process(false)
	hybrid._physics_process(1.0/hz)
	var first_state:String=hybrid.state
	var frozen_pose:Transform3D=app.torso.global_transform
	var immediate_unchanged:bool=frozen_pose.is_equal_approx(before_pose)
	hybrid.set_physics_process(true)
	await ticks(.8)
	var row:Dictionary={"flag":flag,"fault":fault,"support_pose":support_pose,"before_pose":before_pose,"first_state":first_state,"first_pose":frozen_pose,"final":hybrid.data.duplicate(true),"pose_unchanged_at_guard":immediate_unchanged,"shapes_unchanged":shape_signature()==before_shapes}
	guard_trials.append(row)
	if not flag:
		check(not app.torso.freeze and first_state!="BLOCKED_RECOVERY","OFF preserves legacy unguarded RESTORE behavior")
		check(hybrid.state=="DYNAMIC_GROUNDED","OFF control reproduces invalid moving support being handed to walking")
		return
	check(first_state=="BLOCKED_RECOVERY" and hybrid.reason=="SUPPORT_INVALIDATED","ON %s refuses invalid support before dynamic ground handoff"%fault)
	check(immediate_unchanged and app.torso.global_transform.is_equal_approx(frozen_pose),"ON %s freezes current solved pose without rewind or continued travel"%fault)
	check(app.torso.freeze and app.controller.assisted_motion_owned and app.ground_motor.assisted_authority_suspended,"ON %s holds frozen recovery with both old force owners suspended"%fault)
	check(not hybrid.motor.active and shape_signature()==before_shapes and app.torso.get_children().filter(func(node):return node is CollisionShape3D).map(func(node):return node.shape.get_instance_id())==shape_ids,"ON %s never rebuilds or reuses a geometry transition"%fault)
	check(not hybrid.completed and not hybrid.standing_clear_at_restore and hybrid.result=="BLOCKED / R TO RESTART","ON %s cannot declare top-out or silently resume"%fault)
	check(app.controller._attached_ids().is_empty() and app.controller.telemetry().get("total_force",0)==0 and app.ground_motor.applied_force==Vector3.ZERO and app.ground_motor.applied_torque==Vector3.ZERO,"ON %s has no old hand foot or ground force"%fault)
	check(app.torso.mass==12 and app.torso.collision_layer==4 and app.torso.collision_mask==3,"ON recovery preserves actual body mass and collision filters")
	await reset_actual_input("RESTORE "+fault)

func valid_handoff(flag:bool)->void:
	if not await restore_fixture(flag):return
	var hybrid:Node=app.hybrid_mantle
	for frame in hz:
		await ticks(1.0/hz)
		if hybrid.state=="DYNAMIC_GROUNDED":break
	check(hybrid.state=="DYNAMIC_GROUNDED" and not app.torso.freeze and not app.controller.assisted_motion_owned,"valid flag %s restores ordinary dynamic walking"%flag)
	Input.action_press("contract")
	for frame in 2*hz:
		await ticks(1.0/hz)
		if hybrid.completed:break
	Input.action_release("contract")
	check(hybrid.completed and hybrid.walk_distance>=.30,"valid flag %s earns actual top-ground and 30cm walking"%flag)
	guard_trials.append({"flag":flag,"fault":"none","completed":hybrid.completed,"duration":hybrid.route.duration,"final":hybrid.data.duplicate(true)})
	if flag:
		app.level.platform.constant_linear_velocity=Vector3(.4,0,0)
		await ticks(.15)
		check(not app.torso.freeze and not app.controller.assisted_motion_owned and not app.ground_motor.assisted_authority_suspended and hybrid.state=="DYNAMIC_GROUNDED","completed DYNAMIC_GROUNDED remains ordinary physics when ground later changes")

func run()->void:
	await invalid_restore(false,"velocity")
	await invalid_restore(true,"velocity")
	await invalid_restore(true,"moved")
	await invalid_restore(true,"destroyed")
	await valid_handoff(false)
	await valid_handoff(true)
	check(budgets_ok,"all real-input fixture ticks preserve legacy force and torque budgets")
	report={"physics_hz":hz,"checks":checks,"failures":failures,"trials":guard_trials,"scope":"RESTORE_DYNAMIC support invalidation; support-only fault injection; no character pose or velocity writes; automated rather than human feel"}
	FileAccess.open("res://builds/vault_restore_guard_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	app.queue_free()
	await ticks(.03)
	print("VAULT RESTORE GUARD RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
