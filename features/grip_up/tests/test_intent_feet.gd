extends "res://features/grip_up/tests/test_foot_support.gd"
## B2 ranking fixtures plus B0/B1/B2 on the unchanged full-biped Step.
const Lab=preload("res://features/grip_up/scripts/grip_up_lab.gd")
const Arm=preload("res://features/grip_up/scripts/arm_actuator.gd")
var app
var cases:Array=[]
var app_budget:=true
var app_friction:=true
var app_no_early:=true

func one_leg()->void:
	fixture()
	var hips:Array[Vector3]=[Vector3.ZERO]
	var rest:Array[Vector3]=[Vector3(0,-.75,0)]
	var lengths:Array[float]=[.83]
	var clearances:Array[float]=[.10]
	solver.configure(torso,settings,hips,rest,lengths,clearances)

func ranking_contracts()->void:
	one_leg()
	var left:PhysicsBody3D=box(Vector3(-.16,.05,0),Vector3(.10,.10,.8))
	var right:PhysicsBody3D=box(Vector3(.16,.05,0),Vector3(.10,.10,.8))
	await physics_frame
	var hip:Vector3=torso.position
	var rest:Vector3=torso.position+Vector3(0,-.75,0)
	var before:Transform3D=torso.global_transform
	var velocity:Vector3=torso.linear_velocity
	var old:Dictionary=Sampler.sample(torso,settings,hip,rest,rest,.83,.10,0)
	var disabled:Dictionary=Sampler.sample(torso,settings,hip,rest,rest,.83,.10,0,{"enabled":false,"intent":Vector3.LEFT})
	check(not old.is_empty() and old==disabled,"B2 OFF preserves exact existing sampler result/order with identical geometry")
	var context:Dictionary={"enabled":true,"intent":Vector3.LEFT}
	var candidate:Dictionary=Sampler.sample(torso,settings,hip,rest,rest,.83,.10,0,context)
	check(old.support==left and candidate.support==right,"signed leftward push chooses the right-hand bearing ledge, not a destination to the left")
	check(context.diagnostics.selected.signed_push_utility>0 and not context.diagnostics.future_contact_authorized,"candidate report explains compressive utility without granting contact authority")
	check(torso.global_transform==before and torso.linear_velocity==velocity,"ranking never changes live body pose or velocity")
	var prior:Dictionary={"support_id":right.get_instance_id(),"local_point":right.to_local(candidate.point)}
	var soft:Dictionary={"enabled":true,"intent":Vector3.RIGHT*.01,"previous":prior}
	var kept:Dictionary=Sampler.sample(torso,settings,hip,rest,rest,.83,.10,0,soft)
	check(kept.support==right and soft.diagnostics.selected.hysteresis_bonus>0,"small near-equal score reversal retains previous valid material candidate")
	var strong:Dictionary={"enabled":true,"intent":Vector3.RIGHT,"previous":prior}
	check(Sampler.sample(torso,settings,hip,rest,rest,.83,.10,0,strong).support==left,"clear opposite intention can outrank bounded candidate hysteresis")
	right.collision_layer=0
	await physics_frame
	var lost:Dictionary=Sampler.sample(torso,settings,hip,rest,rest,.83,.10,0,soft)
	check(not lost.is_empty() and lost.support==left,"history cannot preserve a candidate whose real collision disappeared")
	cases.append({"kind":"ranking","baseline_selected_x":old.point.x,"intent_selected_x":candidate.point.x,"selection":context.diagnostics,"small_reversal":soft.diagnostics})
	await clear()

func isolated_push(aware:bool,dynamic:bool=false)->Dictionary:
	one_leg()
	solver.intent_aware_selection=aware
	solver.selection_intent=Vector3.LEFT
	var left:PhysicsBody3D=box(Vector3(-.16,.05,0),Vector3(.10,.10,.8),dynamic)
	var right:PhysicsBody3D=box(Vector3(.16,.05,0),Vector3(.10,.10,.8),dynamic)
	await ticks(int(.7*hz))
	check(supporting()==1 and force_sum()==0,"B%d finite plant completes before any explicit commit applies force"%(2 if aware else 1))
	var selected:PhysicsBody3D=solver.feet[0].support
	var start:Vector3=torso.position
	var initial_p:Vector3=torso.linear_velocity*torso.mass
	if dynamic:initial_p+=left.linear_velocity*left.mass+right.linear_velocity*right.mass
	var work:=0.0
	var peak:=0.0
	contract=1
	apply=true
	for frame in int(.25*hz):
		await tick()
		peak=maxf(peak,force_sum())
		for foot in solver.feet:work+=Vector3(foot.force).dot(Solver.point_velocity(torso,foot.contact_point)-Solver.point_velocity(selected,foot.contact_point))/hz
	var final_p:Vector3=torso.linear_velocity*torso.mass
	if dynamic:final_p+=left.linear_velocity*left.mass+right.linear_velocity*right.mass
	var row:Dictionary={"kind":"isolated_dynamic" if dynamic else "isolated_push","aware":aware,"selected_side":"right" if selected==right else "left","dx":torso.position.x-start.x,"dy":torso.position.y-start.y,"leg_work":work,"peak_force":peak,"linear_error":final_p.distance_to(initial_p),"selection":solver.candidate_selection()}
	check(peak>1 and peak<=120.001,"isolated B%d actually exercises unchanged single-leg effort cap"%(2 if aware else 1))
	if dynamic:check(final_p.distance_to(initial_p)<.001,"B2 actual dynamic bearing support receives opposite leg reaction")
	cases.append(row)
	await clear()
	return row

func adverse()->void:
	fixture(Vector3(0,1,.4))
	solver.intent_aware_selection=true
	solver.selection_intent=Vector3.UP
	box(Vector3(0,.55,-.1),Vector3(3,1,.2),false,0)
	await ticks(int(.5*hz))
	apply=true
	await ticks(2)
	check(solver.feet.all(func(foot):return absf(Vector3(foot.force).y)<.00001),"B2 ranking cannot create upward adhesion on a frictionless wall")
	active=false
	await ticks(1)
	check(force_sum()==0,"B2 inactive still releases all contact authority immediately")
	solver.reset()
	check(solver.candidate_selection(true).feet.is_empty() and solver.candidate_selection().switch_count==0,"reset clears B2 selection history and diagnostics")
	await clear()

func app_ticks(count:int)->void:
	for frame in count:
		await physics_frame
		var state:Dictionary=app.controller.telemetry()
		if state.is_empty():continue
		app_budget=app_budget and state.total_force<=360.001 and state.leg_force<=180.001 and (Vector3(state.torque)+app.ground_motor.applied_torque).length()<=150.001
		for foot in app.controller.feet_solver.feet:
			var n:float=Vector3(foot.force).dot(foot.normal)
			var tangent:Vector3=Vector3(foot.force)-foot.normal*n
			var mu:float=app.controller.feet_solver.tuning.foot_friction
			if is_instance_valid(foot.support) and foot.support.physics_material_override!=null:mu=minf(mu,foot.support.physics_material_override.friction)
			app_friction=app_friction and n>=-.0001 and tangent.length()<=mu*n+.0001 and Vector3(foot.force).length()<=120.001
			if foot.state not in ["SUPPORTING","SLIDING"]:app_no_early=app_no_early and Vector3(foot.force).length()<.00001

func step_trial(mode:String)->Dictionary:
	for action in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:
		if InputMap.has_action(action):Input.action_release(action)
	app=Lab.new()
	root.add_child(app)
	current_scene=app
	app._open_intent_arena(6,mode!="B0")
	app._set_movement_allocation(0)
	app._set_intent_aware_feet(mode=="B2")
	app.won=true
	await app_ticks(int(.45*hz))
	var wall:PhysicsBody3D=app.level.holds[0]
	var requested:=true
	for id in 2:
		Input.action_press("grip_left" if id==0 else "grip_right")
		requested=requested and app.controller.request_grip(id,wall,app.level.transfer_points[id],Vector3.BACK)
	await app_ticks(int(.65*hz))
	check(requested and app.controller._attached_ids().size()==2,"%s Step earns both real finite hand contacts with A0 fixed"%mode)
	var start:Vector3=app.torso.position
	var hand_load_integral:=0.0
	var foot_work:=0.0
	var peak_leg:=0.0
	var plant_samples:=0
	var retained:=true
	var samples:Array=[]
	Input.action_press("contract")
	for frame in 3*hz:
		await app_ticks(1)
		var state:Dictionary=app.controller.telemetry()
		hand_load_integral+=state.total_force/hz
		peak_leg=maxf(peak_leg,state.leg_force)
		retained=retained and app.controller._attached_ids().size()==2
		for foot in app.controller.feet_solver.feet:
			if foot.state in ["SUPPORTING","SLIDING"]:
				plant_samples+=1
				foot_work+=maxf(0.0,Vector3(foot.force).dot(Arm.point_velocity(app.torso,foot.contact_point)))/hz
		if frame%maxi(1,int(hz/10))==0:samples.append({"time":float(frame)/hz,"position":app.torso.position,"hand_force":state.total_force,"leg_force":state.leg_force,"feet":app.controller.feet_solver.feet.map(func(foot):return {"state":foot.state,"force":foot.force,"point":foot.contact_point,"reason":foot.reason}),"selection":app.controller.feet_solver.candidate_selection()})
	Input.action_release("contract")
	var row:Dictionary={"kind":"full_biped_step","mode":mode,"rise":app.torso.position.y-start.y,"hand_load_integral":hand_load_integral,"foot_positive_work":foot_work,"peak_leg_force":peak_leg,"planted_samples":plant_samples,"retained":retained,"selection":app.controller.feet_solver.candidate_selection(),"samples":samples}
	check(app.controller.intent_locomotion.movement_allocation==0 and app.controller.feet_solver.intent_aware_selection==(mode=="B2"),"%s selector never silently enables A1 or changes the chosen foot policy"%mode)
	if mode=="B0":check(peak_leg==0 and foot_work==0,"B0 has no hidden physical foot contribution")
	else:check(peak_leg>1 and foot_work>0,"%s has measured finite planted foot work, not visual leg activity"%mode)
	cases.append(row)
	for action in ["contract","grip_left","grip_right"]:Input.action_release(action)
	app.queue_free()
	app=null
	for frame in 3:await physics_frame
	return row

func run()->void:
	world=Node3D.new()
	root.add_child(world)
	await ranking_contracts()
	var b1:Dictionary=await isolated_push(false)
	var b2:Dictionary=await isolated_push(true)
	check(b1.dx>0 and b2.dx<0,"same isolated geometry/input changes actual push sign through a better local support, not a new body force")
	await isolated_push(true,true)
	await adverse()
	var off:Dictionary=await step_trial("B0")
	var baseline:Dictionary=await step_trial("B1")
	var candidate:Dictionary=await step_trial("B2")
	check(budgets and unilateral and finite_gesture and no_early and read_only,"all isolated ticks retain finite planting, unilateral cone, budgets and read-only prepare")
	check(app_budget and app_friction and app_no_early,"all actual biped B0/B1/B2 ticks preserve 360/180/150 caps, friction and no preplant force")
	var comparison:Dictionary={"B0_rise":off.rise,"B1_rise":baseline.rise,"B2_rise":candidate.rise,"B0_hand_integral":off.hand_load_integral,"B1_hand_integral":baseline.hand_load_integral,"B2_hand_integral":candidate.hand_load_integral,"B1_work":baseline.foot_positive_work,"B2_work":candidate.foot_positive_work}
	FileAccess.open("res://builds/intent_feet_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify({"physics_hz":hz,"checks":checks,"failures":failures,"cases":cases,"step_comparison":comparison,"decision":"LOCAL_SELECTION_EXPERIMENT; GAMEPLAY_BENEFIT_UNPROVEN","scope":"isolated point-foot fixtures plus unchanged actual Step with A0; API hand acquisition and real W input; no body pose/velocity writes during actuation; not human feel"},"\t"))
	print("INTENT FEET RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
