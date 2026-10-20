extends Node
## Original v1.1 A1 failure fixture, mechanically unchanged. Initial placement
## is explicit fixture setup; the measured window only calls existing intents.
const Controller=preload("res://features/grip_up/scripts/climbing_controller.gd")
const Profile=preload("res://features/grip_up/resources/biped_tuning.gd")
const Metrics=preload("res://features/locomotion_test_suite/scripts/movement_metrics.gd")
var body:RigidBody3D
var controller:Node
var support:StaticBody3D
var failed:Dictionary={}

func _tick(count:int)->void:
	for frame in count:
		await get_tree().physics_frame
		if failed.values().any(func(value):return bool(value)):break

func _monitor()->void:
	var state:Dictionary=controller.telemetry()
	if state.is_empty():return
	failed.force_budget_violation=failed.force_budget_violation or state.total_force>360.001 or Vector3(state.torque).length()>150.001 or Vector3(state.assist_torque).length()>20.001
	failed.solver_nonfinite=failed.solver_nonfinite or not body.global_position.is_finite() or not body.linear_velocity.is_finite() or not body.angular_velocity.is_finite()
	for id in 2:
		var hand:Dictionary=controller.hands[id]
		if hand.state not in ["ATTACHED","SLIPPING"] and controller.get_arm_force(id).length()>.0001:failed.pending_support_force=true
		if hand.state in ["ATTACHED","SLIPPING"] and (hand.anchor==null or not hand.anchor.is_valid()):failed.unphysical_grip=true

func _variant(variant:int,candidate:Dictionary,loader:RefCounted,hz:int,definition:Dictionary)->Dictionary:
	# Values copied from test_capture_matrix.setup + test_locomotion_allocation.prepare.
	body=RigidBody3D.new();body.position=Vector3(0,3,.5);body.mass=12;body.gravity_scale=0
	body.center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM;body.center_of_mass=Vector3.ZERO
	body.linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE;body.angular_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp=.08;body.angular_damp=.35;body.collision_layer=4;body.collision_mask=3
	var capsule:=CapsuleShape3D.new();capsule.height=1.7;capsule.radius=.2
	var shape:=CollisionShape3D.new();shape.shape=capsule;body.add_child(shape);add_child(body)
	controller=Controller.new();add_child(controller);controller.configure(body,Profile.new())
	var applied:Dictionary=loader.apply_to(controller,candidate)
	controller.set_control_profile(4);controller.intent_climb_enabled=true
	controller.intent_locomotion.movement_allocation=variant;controller.locomotion_diagnostics_enabled=true
	controller.sample_ready.connect(func(_delta):_monitor())
	if not applied.get("ok",false):return {"completed":false,"reason":"OVERRIDE_FAILED"}
	await _tick(maxi(1,int(.05*hz)))
	var point:Vector3=controller.get_shoulder_world(0)+Vector3(0,.38,-.35)
	support=StaticBody3D.new();support.position=point-Vector3.BACK*.05
	support.collision_layer=2;support.collision_mask=0;support.set_meta("grippable",true);support.set_meta("grip_load_limit",10000.0)
	var box:=BoxShape3D.new();box.size=Vector3(2,1.2,.1)
	var target:=CollisionShape3D.new();target.shape=box;support.add_child(target);add_child(support)
	await _tick(maxi(1,int(.05*hz)))
	var requested:=[]
	for id in 2:
		var raw:Array=definition.policy.left_offset if id==0 else definition.policy.right_offset
		requested.append(controller.request_grip(id,support,controller.get_shoulder_world(id)+Vector3(raw[0],raw[1],raw[2]),Vector3.BACK))
	await _tick(int(.7*hz));body.gravity_scale=1;await _tick(int(.2*hz))
	var initial:Vector3=body.global_position
	var metrics=Metrics.new()
	var signed_input:=Vector2(float(definition.policy.input[0]),float(definition.policy.input[1]))
	var direction:=Vector3(signed_input.x,signed_input.y,0).normalized()
	var sample:Dictionary=controller.locomotion_observer.data
	metrics.start(sample,direction,{"physics_hz":hz})
	var retained:bool=controller._attached_ids().size()==2
	controller.set_traversal_input(signed_input,Vector3.RIGHT)
	for frame in int(float(definition.policy.duration_s)*hz):
		await controller.sample_ready
		metrics.push(controller.locomotion_observer.data)
		retained=retained and controller._attached_ids().size()==2
		if failed.values().any(func(value):return bool(value)):retained=false;break
	var measured:Dictionary=metrics.finish()
	var progress:float=(body.global_position-initial).dot(direction)
	var result:Dictionary={"variant":variant,"completed":requested.all(func(value):return value) and retained,"reason":"" if retained else "CANARY_SUPPORT_NOT_RETAINED","useful_displacement_m":progress,"measurement":measured,"initial_body":initial,"final_body":body.global_position,"actual_parameters":{},"fixture_source":"test_capture_matrix.setup + test_locomotion_allocation.prepare(diagonal)","scope":"legacy isolated capsule fixture; no ground/feet or complete humanoid route claim"}
	for key in candidate.parameter_overrides:result.actual_parameters[key]=controller.tuning.get(key)
	controller.set_traversal_input(Vector2.ZERO,Vector3.RIGHT);controller.reset_state()
	result["restoration"]=loader.restore()
	controller.queue_free();body.queue_free();support.queue_free();await _tick(3)
	return result

func run_case(definition:Dictionary,candidate:Dictionary,loader:RefCounted,hz:int)->Dictionary:
	failed={"force_budget_violation":false,"unphysical_grip":false,"direct_body_transform_mutation":false,"solver_nonfinite":false,"pending_support_force":false,"unauthorized_air_actuation":false,"authority_conflict":false,"protected_parameter_changed":false}
	var comparisons:Array=[]
	for variant in definition.policy.variants:comparisons.append(await _variant(int(variant),candidate,loader,hz,definition))
	var completed:bool=comparisons.all(func(row):return row.completed)
	return {"id":definition.id,"revision":int(definition.revision),"implementation_id":"allocation_canary","status":"completed" if completed else "failed_task","completed":completed,"reason":"" if completed else "A1_CANARY_TASK_FAILURE","metrics":{"useful_displacement_m":comparisons[0].get("useful_displacement_m"),"movement_latency_s":null,"unwanted_twist_rms_rad":null,"grip_retention_rate":null,"controllable_swing":null,"metric_reasons":{"scope":"paired A0/A1 negative control; differences retained, not training reward"}},"capture":{},"invariants":failed.duplicate(true),"scope":definition.scope,"driver":"legacy_declared_public_intent_api","comparisons":comparisons,"applied_parameters":candidate.parameter_overrides.duplicate(true)}
