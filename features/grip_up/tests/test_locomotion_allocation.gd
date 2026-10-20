extends "res://features/grip_up/tests/test_capture_matrix.gd"
## Matched real-physics A0/A1 fixtures. Setup may place bodies before simulation;
## the planner never writes body pose/velocity, changes strength or makes contacts.
const Coordinator=preload("res://features/grip_up/scripts/intent_locomotion_coordinator.gd")
var trials:Array=[]
var comparisons:Array=[]

func prepare(kind:String,variant:int,moving:bool=false)->void:
	await setup({"label":kind,"offset_y":.38,"moving":moving},false)
	controller.set_control_profile(4)
	controller.intent_climb_enabled=true
	controller.intent_locomotion.movement_allocation=variant
	body.linear_damp=0.0 if moving else .08
	body.angular_damp=0.0 if moving else .35
	if moving:body.inertia=Vector3(2,2,2)
	(support.get_child(0) as CollisionShape3D).shape.size=Vector3(2,1.2,.10)
	var left:Vector3=controller.get_shoulder_world(0)+Vector3(-.10 if kind=="asymmetric" else 0,.42 if kind=="asymmetric" else .38,-.35)
	var right:Vector3=controller.get_shoulder_world(1)+Vector3(.10 if kind=="asymmetric" else 0,.20 if kind=="asymmetric" else .38,-.35)
	check(controller.request_grip(0,support,left,Vector3.BACK),"%s A%d begins finite actual left acquisition"%[kind,variant])
	if kind!="single":check(controller.request_grip(1,support,right,Vector3.BACK),"%s A%d begins finite actual right acquisition"%[kind,variant])
	await ticks(int(.7*hz))
	check(controller._attached_ids().size()==(1 if kind=="single" else 2),"%s A%d acquires actual contacts before applying movement"%[kind,variant])
	body.gravity_scale=0.0 if moving else 1.0
	await ticks(int(.20*hz))

func measure(kind:String,variant:int,input:Vector2,warm_a1:bool=false)->Dictionary:
	await prepare(kind,variant)
	if warm_a1:
		# Unused previous helper cache must not leak into the A0 physical path.
		controller.intent_locomotion.constraint_allocation.data={"stale":true}
	var start:Vector3=body.global_position
	var useful:=0.0
	var twist_square:=0.0
	var tilt_square:=0.0
	var peak_force:=0.0
	var peak_moment:=0.0
	var max_rate:=0.0
	var max_acceleration:=0.0
	var retained:=true
	var samples:Array=[]
	var exact:Array=[]
	var samples_attached:=0
	var unchanged_anchors:Array=controller.hands.map(func(hand):return hand.anchor)
	controller.set_traversal_input(input,Vector3.RIGHT)
	for index in int(1.4*hz):
		await controller.sample_ready
		var state:Dictionary=controller.telemetry()
		retained=retained and controller._attached_ids().size()==(1 if kind=="single" else 2)
		if not controller._attached_ids().is_empty():samples_attached+=1
		var trunk:Vector3=((controller.get_shoulder_world(0)+controller.get_shoulder_world(1))*.5-body.global_position).normalized()
		var current:Vector3=body.global_basis.x.slide(trunk)
		var reference:Vector3=Vector3.RIGHT.slide(trunk)
		var twist:float=current.normalized().signed_angle_to(reference.normalized(),trunk) if current.length_squared()>.000001 and reference.length_squared()>.000001 else 0.0
		var tilt:float=acos(clampf(body.global_basis.y.dot(Vector3.UP),-1,1))
		twist_square+=twist*twist
		tilt_square+=tilt*tilt
		peak_force=maxf(peak_force,state.total_force)
		peak_moment=maxf(peak_moment,Vector3(state.torque).length())
		for rate in state.intent_locomotion.target_rates.values():max_rate=maxf(max_rate,absf(rate))
		for rate in state.intent_locomotion.target_accelerations.values():max_acceleration=maxf(max_acceleration,absf(rate))
		exact.append([body.global_transform,body.linear_velocity,body.angular_velocity,controller.hands[0].rest_length,state.total_force,state.assist_torque])
		if index%maxi(1,int(hz/10))==0:samples.append({"time":float(index)/hz,"position":body.global_position,"twist":twist,"tilt":tilt,"force":state.total_force,"moment":state.torque,"allocation":state.intent_locomotion.get("movement_allocation",{})})
	var count:float=maxf(1,float(int(1.4*hz)))
	var desired:=Vector3(input.x,input.y,0).normalized()
	useful=(body.global_position-start).dot(desired)
	var row:Dictionary={"kind":kind,"variant":variant,"input":input,"useful_displacement":useful,"twist_rms":sqrt(twist_square/count),"tilt_rms":sqrt(tilt_square/count),"peak_force":peak_force,"peak_moment":peak_moment,"max_target_rate":max_rate,"max_target_acceleration":max_acceleration,"retained":retained,"attached_samples":samples_attached,"samples":samples,"exact":exact}
	check(samples_attached>hz*.5 and peak_force<=360.001 and peak_moment<=150.001 and max_rate<=.2401 and max_acceleration<=.9001,"%s A%d physically exercises capped actuation and unchanged target derivative bounds"%[kind,variant])
	check(controller.hands[0].anchor==unchanged_anchors[0] or controller.get_hand_state(0) in ["FREE","RELEASED"],"A%d cannot replace the selected material anchor"%variant)
	controller.set_traversal_input(Vector2.ZERO,Vector3.LEFT)
	await ticks(int(.9*hz))
	var rest:float=controller.hands[0].rest_length
	await ticks(int(.7*hz))
	row.neutral_drift=absf(controller.hands[0].rest_length-rest)
	check(row.neutral_drift<.003,"%s A%d finite neutral settling does not accumulate posture"%[kind,variant])
	trials.append(row)
	await clear()
	return row

func no_authority()->void:
	var paths:Array=[]
	for variant in [0,1]:
		await setup({"gravity":1.0},false)
		controller.set_control_profile(4)
		controller.intent_climb_enabled=true
		controller.intent_locomotion.movement_allocation=variant
		controller.set_traversal_input(Vector2.ONE,Vector3.RIGHT)
		await ticks(int(.4*hz))
		paths.append([body.global_position,body.linear_velocity,body.angular_velocity])
		check(controller.telemetry().total_force==0 and controller.telemetry().assist_torque==Vector3.ZERO,"A%d without support has exactly zero muscle authority"%variant)
		await clear()
	check(paths[0]==paths[1],"A0/A1 unsupported trajectories are identical")
	await setup({"offset_y":1.2},false)
	controller.set_control_profile(4)
	controller.intent_climb_enabled=true
	controller.intent_locomotion.movement_allocation=1
	controller.tuning.allow_out_of_reach_grip_targets=true
	controller.request_held_grip(0,support,anchor.world_point(),Vector3.BACK)
	controller.set_traversal_input(Vector2.ONE,Vector3.RIGHT)
	await ticks(int(.3*hz))
	check(controller.get_hand_state(0)=="REACHING" and controller.telemetry().total_force==0 and controller.intent_locomotion.constraint_allocation.data.advisory_classification=="NO_SUPPORT","A1 assigns no effort or contact feasibility to a distant pending hand")
	await clear()

func helper_contract()->void:
	await prepare("asymmetric",1)
	var pose:Transform3D=body.global_transform
	var velocity:Vector3=body.linear_velocity
	var spin:Vector3=body.angular_velocity
	var lengths:Array=controller.hands.map(func(hand):return hand.rest_length)
	var result:Dictionary=controller.intent_locomotion.constraint_allocation.evaluate(controller,controller._attached_ids(),Vector3.UP*.05,Vector3.UP,1.0/hz)
	check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin and controller.hands.map(func(hand):return hand.rest_length)==lengths,"A1 evaluation is read-only for body and actuator state")
	check(result.weights.values().all(func(value):return float(value)>=0 and float(value)<=1) and not result.collision_assessed,"A1 never amplifies contraction or claims future collision clearance")
	var lower:Dictionary=controller.intent_locomotion.constraint_allocation.evaluate(controller,controller._attached_ids(),Vector3.DOWN*.05,Vector3.DOWN,1.0/hz)
	check(lower.changes==lower.source_changes,"A1 preserves geometry-based tension relief for lowering without inventing a push")
	var clean=Coordinator.new()
	var cached=Coordinator.new()
	cached.constraint_allocation.data={"stale":true}
	var twin=Controller.new()
	twin.torso=body
	twin.tuning=controller.tuning
	twin.hands=controller.hands.duplicate(true)
	twin.simulation_time=controller.simulation_time
	twin._diagnostics=controller.telemetry().duplicate(true)
	var a0_equal:=true
	clean.set_input(Vector2(0,1),Vector3.RIGHT)
	cached.set_input(Vector2(0,1),Vector3.RIGHT)
	for index in 30:
		clean.step(controller,1.0/hz,true)
		cached.step(twin,1.0/hz,true)
		var a:Dictionary=clean.data.duplicate(true)
		var b:Dictionary=cached.data.duplicate(true)
		a.erase("planner_cpu_usec")
		b.erase("planner_cpu_usec")
		a0_equal=a0_equal and a==b and controller.hands.map(func(hand):return hand.rest_length)==twin.hands.map(func(hand):return hand.rest_length)
	check(a0_equal,"A0 target/state outputs are exact on identical live geometry regardless of unused A1 cache")
	twin.free()
	controller.retire_for_assisted_motion()
	await ticks(2)
	check(controller.intent_locomotion.constraint_allocation.data.is_empty() and controller.telemetry().total_force==0,"hybrid retirement clears helper state and old muscle authority")
	await clear()

func dynamic_reaction()->void:
	await prepare("symmetric",1,true)
	var material:=support as RigidBody3D
	await ticks(3)
	# The fixture's custom COM and isotropic inertia isolate applied wrench
	# conservation from the known AUTO/asymmetric solver approximation.
	var initial:Vector3=body.linear_velocity*body.mass+material.linear_velocity*material.mass
	var initial_spin:Vector3=pair_angular_momentum(material)
	controller.set_traversal_input(Vector2(.5,1),Vector3.RIGHT)
	var peak:=0.0
	for index in int(.5*hz):
		await controller.sample_ready
		peak=maxf(peak,controller.telemetry().total_force)
	var final:Vector3=body.linear_velocity*body.mass+material.linear_velocity*material.mass
	var spin_error:float=pair_angular_momentum(material).distance_to(initial_spin)
	comparisons.append({"kind":"dynamic_pair","linear_initial":initial,"linear_final":final,"linear_error":final.distance_to(initial),"angular_error":spin_error,"peak_force":peak,"body_gravity":body.gravity_scale,"support_gravity":material.gravity_scale})
	print("ALLOCATION_DYNAMIC ",comparisons[-1])
	check(peak>1 and final.distance_to(initial)<.02,"A1 nonzero effort still reacts on the dynamic material rather than propelling the pair")
	check(spin_error<.01,"closed isotropic A1 pair also retains angular momentum with reacted assistance")
	await clear()

func pair_angular_momentum(material:RigidBody3D)->Vector3:
	var total:=Vector3.ZERO
	for target in [body,material]:
		var center:Vector3=target.global_transform*target.center_of_mass
		total+=center.cross(target.linear_velocity*target.mass)+target.get_inverse_inertia_tensor().inverse()*target.angular_velocity
	return total

func obstacle(at:Vector3,size:Vector3)->StaticBody3D:
	var wall:=StaticBody3D.new()
	wall.position=at
	wall.collision_layer=1
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=size
	shape.shape=box
	wall.add_child(shape)
	world.add_child(wall)
	return wall

func blocked_request()->void:
	await prepare("symmetric",1)
	var start:Vector3=body.global_position
	var cage:Array=[]
	for side in [-1,1]:
		cage.append(obstacle(start+Vector3(side*.26,0,0),Vector3(.08,2.2,1.2)))
		cage.append(obstacle(start+Vector3(0,side*.91,0),Vector3(1.2,.08,1.2)))
		cage.append(obstacle(start+Vector3(0,0,side*.26),Vector3(1.2,2.2,.08)))
	controller.set_traversal_input(Vector2(0,1),Vector3.RIGHT)
	await ticks(int(4*hz))
	var before:float=controller.hands[0].rest_length
	var held:float=controller.intent_locomotion.records.get(0,{}).get("hold",0)
	check(controller._attached_ids().size()==2 and held>.25 and before>.25 and body.global_position.distance_to(start)<.10,"A1 four-second rigid obstruction cannot wind up an arbitrary contracted posture")
	controller.set_traversal_input(Vector2.ZERO,Vector3.RIGHT)
	await ticks(int(.9*hz))
	var settled:float=controller.hands[0].rest_length
	for wall in cage:wall.queue_free()
	await ticks(int(.8*hz))
	var drift:float=absf(controller.hands[0].rest_length-settled)
	comparisons.append({"kind":"blocked","held_length":held,"blocked_target":before,"post_release_target_drift":drift})
	check(drift<.003,"A1 opening a block after neutral does not reveal stored future pull")
	controller.reset_state()
	check(controller.intent_locomotion.constraint_allocation.data.is_empty(),"ordinary reset clears A1 remembered allocation without a stale helper plan")
	await clear()

func run()->void:
	world=Node3D.new()
	root.add_child(world)
	check(Coordinator.new().movement_allocation==0,"A0 remains the default coordinator policy")
	await no_authority()
	await helper_contract()
	var reference:Dictionary=await measure("symmetric",0,Vector2(0,1))
	var after_cache:Dictionary=await measure("symmetric",0,Vector2(0,1),true)
	# Independent Jolt runs need not be bit-identical. Exact policy equivalence
	# is asserted above against the same live body; archive this repeatability.
	comparisons.append({"kind":"A0_repeatability","useful_difference":absf(reference.useful_displacement-after_cache.useful_displacement),"twist_difference":absf(reference.twist_rms-after_cache.twist_rms)})
	for kind in ["symmetric","asymmetric","single"]:
		var a0:Dictionary=reference if kind=="symmetric" else await measure(kind,0,Vector2(0,1))
		var a1:Dictionary=await measure(kind,1,Vector2(0,1))
		comparisons.append({"kind":kind,"a0_useful":a0.useful_displacement,"a1_useful":a1.useful_displacement,"a0_twist":a0.twist_rms,"a1_twist":a1.twist_rms,"a0_tilt":a0.tilt_rms,"a1_tilt":a1.tilt_rms,"a0_retained":a0.retained,"a1_retained":a1.retained})
	var lateral_a0:Dictionary=await measure("asymmetric",0,Vector2(.7,1))
	var lateral_a1:Dictionary=await measure("asymmetric",1,Vector2(.7,1))
	comparisons.append({"kind":"asymmetric_diagonal","a0_useful":lateral_a0.useful_displacement,"a1_useful":lateral_a1.useful_displacement,"a0_twist":lateral_a0.twist_rms,"a1_twist":lateral_a1.twist_rms,"a0_tilt":lateral_a0.tilt_rms,"a1_tilt":lateral_a1.tilt_rms,"a0_retained":lateral_a0.retained,"a1_retained":lateral_a1.retained})
	await dynamic_reaction()
	await blocked_request()
	check(budgets and no_early_force,"all observed fixtures respect shared caps and zero precontact force")
	for row in trials:row.erase("exact")
	var regression:=false
	for row in comparisons:
		if row.has("a0_useful") and row.a1_useful<row.a0_useful-.01 and row.a1_twist>row.a0_twist+.01:regression=true
	var report:Dictionary={"physics_hz":hz,"checks":checks,"failures":failures,"trials":trials,"comparisons":comparisons,"decision":"REVISE" if regression else "CANDIDATE_HUMAN_REVIEW_PENDING","benefit_established":false,"default_promotion":false,"scope":"matched automated A0/A1 mechanics, not human improvement; no new force or reach budget"}
	FileAccess.open("res://builds/locomotion_allocation_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("LOCOMOTION ALLOCATION RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
