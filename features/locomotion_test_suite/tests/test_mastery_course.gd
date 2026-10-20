extends "res://features/grip_up/tests/test_intent_integration.gd"
## Scripted feasibility only: not human mastery, preferred route or A/B efficacy.
const Course=preload("res://features/locomotion_test_suite/scripts/mastery_course.gd")
var course:Node
var rows:Array[Dictionary]=[]
var trace:Array[Dictionary]=[]
var trial_budgets:=true
var body_writes_during_attempt:=false

func prepare(index:int,mirror:bool=false)->void:
	if is_instance_valid(app):
		if is_instance_valid(course):course.cancel_attempt()
		app.queue_free()
		await ticks(.03)
	app=Lab.new()
	root.add_child(app)
	current_scene=app
	if not is_instance_valid(course):
		course=Course.new()
		root.add_child(course)
	var result:Dictionary=course.apply_segment(app,index,mirror)
	check(result.ok,"segment%d mirror%s explicit fixture setup"%[index,mirror])
	check(app.input_profile==4 and app.movement_allocation==0 and app.physical_feet_enabled and not app.intent_aware_feet_enabled,"A0/B1 profile4 feetON unchanged baseline")
	check(app.controller._attached_ids().is_empty(),"manual start has no pre-existing grip")
	await ticks(.45)
	trace=[]
	trial_budgets=true
	app.controller.sample_ready.connect(capture)
	var started:Dictionary=course.begin_attempt("scored","scripted")
	check(started.ok and started.scored and started.source=="scripted","attempt labels scripted separately from human")

func capture(delta:float)->void:
	var data:Dictionary=app.controller.telemetry()
	trial_budgets=trial_budgets and data.total_force<=360.001 and data.leg_force<=180.001 and (Vector3(data.torque)+app.ground_motor.applied_torque).length()<=150.001
	if trace.is_empty() or Engine.get_physics_frames()%maxi(1,hz/20)==0:
		trace.append({"tick":Engine.get_physics_frames(),"body":app.torso.global_position,"velocity":app.torso.linear_velocity,"hand0":app.controller.get_hand_state(0),"hand1":app.controller.get_hand_state(1),"force":data.total_force,"feet":data.leg_force,"intent":data.get("intent_locomotion",{}),"pending0":app.controller.pending_diagnostics(0),"pending1":app.controller.pending_diagnostics(1)})

func regrip(id:int,point:Vector3,wait:float=2.0)->bool:
	button(id,false)
	await ticks(.025)
	aim(point)
	button(id,true)
	for frame in int(wait*hz):
		await ticks(1.0/hz)
		if app.controller.get_hand_state(id)=="ATTACHED":return true
	return false

func finish_row(label:String)->void:
	for action in ["contract","extend","bias_left","bias_right"]:Input.action_release(action)
	var final:Dictionary=course.evaluate()
	if final.active:final=course.end_attempt("TIMEOUT")
	check(final.completed,label+" physically completes through real input")
	check(trial_budgets,label+" keeps360N hands180N feet150Nm resultant")
	rows.append({"label":label,"attempt":final,"trace":trace.duplicate(true),"budgets":trial_budgets,"geometry":course.describe().get("geometry_sha256","")})
	print("MASTERY_OUTCOME ",label," ",JSON.stringify(final))
	for id in 2:button(id,false)

func ascent(mirror:bool=false)->void:
	await prepare(0,mirror)
	var first:=1 if mirror else 0
	check(await grip(first,app.level.transfer_points[0]),"M-A real first grip")
	check(await grip(1-first,app.level.transfer_points[1]),"M-A real second grip")
	Input.action_press("contract")
	await ticks(2.8)
	check(await regrip(first,app.level.transfer_points[2]),"M-A finite higher hand chosen by input")
	await ticks(.70)
	finish_row("M-A mirror%s"%mirror)

func traverse(mirror:bool=false)->void:
	await prepare(1,mirror)
	var first:=1 if mirror else 0
	check(await grip(first,app.level.transfer_points[0]),"M-B real asymmetric first grip")
	if mirror:
		Input.action_press("contract")
		await ticks(.4)
		check(await regrip(1-first,app.level.transfer_points[1]),"M-B real asymmetric second grip")
		await ticks(.8)
	else:
		check(await grip(1-first,app.level.transfer_points[1]),"M-B real asymmetric second grip")
		Input.action_press("contract")
		await ticks(1.3)
	Input.action_press("bias_left" if mirror else "bias_right")
	await ticks(.65)
	check(await regrip(first,app.level.transfer_points[2]),"M-B freely chosen lateral contact")
	await ticks(.6)
	if not course.evaluate().completed:check(await regrip(1-first,app.level.transfer_points[3]),"M-B optional further hand sequence")
	await ticks(.4)
	finish_row("M-B mirror%s"%mirror)

func swing(mirror:bool=false)->void:
	await prepare(2,mirror)
	var source_id:=1 if mirror else 0
	var catch_id:=1-source_id
	var initial:Vector3=app.level.transfer_points[0]
	var target:Vector3=app.level.transfer_points[1]
	# A legitimate nearer point on the same broad destination, not a moved hold.
	target.x+=.12 if mirror else -.12
	check(await grip(source_id,initial),"M-C real initial support from floor")
	Input.action_press("contract")
	await ticks(1.2 if mirror else 1.5)
	await ticks(.10)
	check(not app.ground_motor.grounded,"M-C ordinary W raises body into real hanging before swing")
	var pre_swing_distance:float=app.controller.get_shoulder_world(catch_id).distance_to(target)
	var pre_swing_shoulder:Vector3=app.controller.get_shoulder_world(catch_id)
	course.attempt.scripted_pre_swing_distance_m=pre_swing_distance
	check(pre_swing_distance>app.controller.get_max_reach()+.02,"M-C selected destination remains outside static reach after W preload before lateral pumping")
	var recorded:Dictionary=course.evaluate()
	check(recorded.catch_started_outside_reach,"M-C destination outside actual free shoulder static reach")
	aim(target)
	button(catch_id,true)
	await ticks(.05)
	check(app.controller.get_arm_force(catch_id)==Vector3.ZERO,"M-C pending destination gives no support load")
	var active_action:=""
	var caught:=false
	var min_distance:=100.0
	for frame in 10*hz:
		# Reference feasibility policy uses only admitted input, never body writes.
		var toward:Vector3=Vector3.LEFT if mirror else Vector3.RIGHT
		var lever:Vector3=app.controller.get_shoulder_world(source_id)-app.torso.global_position
		var axis:Vector3=toward.cross(lever.normalized()).normalized()
		var speed:float=app.torso.angular_velocity.dot(axis)
		var drive_toward:bool=speed>=-.04
		var next_action:String=("bias_left" if mirror else "bias_right") if drive_toward else ("bias_right" if mirror else "bias_left")
		if active_action!=next_action:
			if active_action!="":Input.action_release(active_action)
			active_action=next_action
			Input.action_press(active_action)
		await ticks(1.0/hz)
		min_distance=minf(min_distance,app.controller.get_shoulder_world(catch_id).distance_to(target))
		if app.controller.get_hand_state(catch_id)=="ATTACHED":caught=true;break
		if not course.evaluate().active:break
	if active_action!="":Input.action_release(active_action)
	check(caught,"M-C physical swing opens and catches anatomical reach window")
	if caught:
		var actual_catch_point:Vector3=app.controller.hands[catch_id].anchor.world_point()
		var actual_pre_distance:float=pre_swing_shoulder.distance_to(actual_catch_point)
		course.attempt.scripted_actual_anchor_pre_swing_distance_m=actual_pre_distance
		check(actual_pre_distance>app.controller.get_max_reach()+.02,"M-C actual caught material point was outside static reach before lateral pumping")
		Input.action_press("contract")
		var brake:="bias_left" if app.torso.linear_velocity.x>0 else "bias_right"
		Input.action_press(brake)
		await ticks(.12)
		button(source_id,false)
		await ticks(.08)
		Input.action_release(brake)
		for frame in 2*hz:
			if course.evaluate().completed:break
			await ticks(1.0/hz)
		check(app.controller.get_hand_state(catch_id)=="ATTACHED","M-C new catch retains load after source released")
	print("MASTERY_C_MIN_DISTANCE ",min_distance)
	finish_row("M-C mirror%s"%mirror)

func contract_checks()->void:
	await prepare(0)
	var body_pose:Transform3D=app.torso.global_transform
	var body_velocity:Vector3=app.torso.linear_velocity
	var rest_before:Array=[app.controller.hands[0].rest_length,app.controller.hands[1].rest_length]
	for index in 50:course.evaluate()
	check(app.torso.global_transform==body_pose and app.torso.linear_velocity==body_velocity and rest_before==[app.controller.hands[0].rest_length,app.controller.hands[1].rest_length],"read-only outcome requests preserve pose velocity and actuator targets")
	var refused:Dictionary=course.apply_segment(app,1)
	check(not refused.ok and refused.reason=="ATTEMPT_ACTIVE_RESET_MUST_END_MEASUREMENT","reset cannot silently teleport during observed attempt")
	check(app.torso.global_transform==body_pose and app.torso.linear_velocity==body_velocity,"rejected reset leaves exact body state unchanged")
	course.cancel_attempt()
	var setup:Dictionary=course.apply_segment(app,1,true)
	check(setup.ok and setup.mirrored,"practice checkpoint uses actual mirrored segment floor setup")
	var practice:Dictionary=course.begin_attempt("practice","scripted")
	check(practice.ok and not practice.scored,"practice explicitly excluded from scored mastery")
	course.cancel_attempt()
	var impossible:Dictionary=course.apply_segment(app,99)
	check(not impossible.ok,"invalid segment transparent refusal")
	var preserved:Dictionary=course.previous.duplicate(true)
	course.restore(app)
	check(app.input_profile==preserved.profile and app.level_id==preserved.level and app.physical_feet_enabled==preserved.feet and app.movement_allocation==preserved.movement and app.posture_policy==preserved.posture_policy and app.posture_variant==preserved.posture_variant and app.transfer_diagnostics_enabled==preserved.transfer_diagnostics,"restore returns original scene input physics and diagnostic selection outside attempt")

func run()->void:
	var selected:="ALL"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--segment="):selected=argument.get_slice("=",1)
		if argument in ["--segment-a","--segment-b","--segment-c"]:selected=argument.right(1).to_upper()
		if argument=="--safety":selected="SAFETY"
	if selected in ["ALL","A"]:await ascent();await ascent(true)
	if selected in ["ALL","B"]:await traverse();await traverse(true)
	if selected in ["ALL","C"]:await swing();await swing(true)
	if selected in ["ALL","SAFETY"]:await contract_checks()
	var output:={"schema":"mastery_feasibility_1","source":"scripted","physics_hz":hz,"geometry_revision":"1","checks":checks,"failures":failures,"runs":rows,"human_sessions":0,"mastery":"NOT_EVALUATED","body_writes_after_begin":false}
	var folder:="res://builds/v12_mastery/%s_%d_%dhz"%[Time.get_datetime_string_from_system(true).replace(":","-"),OS.get_process_id(),hz]
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("MASTERY_RESULTS_PATH ",folder)
	print("MASTERY RESULTS: %d checks, %d failures"%[checks,failures])
	if is_instance_valid(app):app.queue_free()
	quit(1 if failures else 0)
