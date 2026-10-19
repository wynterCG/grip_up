extends Node
const Lab=preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var hz:=120
var checks:=0
var failures:=0
var report:Dictionary={}
var budgets_ok:=true
var continuous:=true
var started_route:=false
var elapsed:=0.0
var next_sample:=0.0
var peaks:={"hand_force":0.0,"leg_force":0.0,"combined_moment":0.0}

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func ticks(seconds:float)->void:
	for frame in int(seconds*hz):
		await get_tree().physics_frame
		if is_instance_valid(app) and not app.controller.telemetry().is_empty():
			var data:Dictionary=app.controller.telemetry()
			budgets_ok=budgets_ok and data.total_force<=360.001 and data.leg_force<=180.001
			budgets_ok=budgets_ok and (Vector3(data.torque)+app.ground_motor.applied_torque).length()<=150.001

func aim(point:Vector3)->void:
	var event:=InputEventMouseMotion.new()
	event.position=app.camera.unproject_position(point)
	event.relative=event.position-app.pointer
	event.screen_relative=event.relative
	Input.parse_input_event(event.xformed_by(get_tree().root.get_final_transform()))
	Input.flush_buffered_events()

func button(id:int,down:bool)->void:
	var event:=InputEventMouseButton.new()
	event.position=app.pointer
	event.button_index=MOUSE_BUTTON_LEFT if id==0 else MOUSE_BUTTON_RIGHT
	event.pressed=down
	Input.parse_input_event(event.xformed_by(get_tree().root.get_final_transform()))
	Input.flush_buffered_events()

func fresh(index:int,feet:bool=false)->void:
	for action in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:
		if InputMap.has_action(action):Input.action_release(action)
	if not is_instance_valid(app):
		app=Lab.new()
		get_tree().root.add_child(app)
		get_tree().current_scene=app
	app._open_intent_arena(index,feet)
	app.won=true
	await ticks(.45)

func grip(id:int,point:Vector3)->bool:
	aim(point)
	button(id,true)
	for frame in hz:
		await get_tree().physics_frame
		if app.controller.get_hand_state(id)=="ATTACHED":return true
	return false

func wait_reach_window(id:int,index:int,seconds:float)->void:
	for frame in int(seconds*hz):
		if app.controller.get_shoulder_world(id).distance_to(app.level.transfer_points[index])<.64:return
		await ticks(1.0/hz)

## One continuous ordinary-spawn approach; real mouse/actions only. Additional
## points are free surface choices, not fixture motion or forced attachments.
var ascent_samples:Array=[]
var ascent_contacts:Array=[]
var old_route_done_before_commit:=false
var failed_transfer:Dictionary={}
var entry_height:=0.0

func sample(delta:float)->void:
	var hybrid:Node=app.hybrid_mantle
	var attached:Array=app.controller._attached_ids()
	if started_route and attached.is_empty() and hybrid.commits==0:continuous=false
	if not attached.is_empty():started_route=true
	if hybrid.commits==0 and app.climbing_route.completed:old_route_done_before_commit=true
	elapsed+=delta
	var force:Dictionary=app.controller.telemetry()
	peaks.hand_force=maxf(peaks.hand_force,force.total_force)
	peaks.leg_force=maxf(peaks.leg_force,force.leg_force)
	peaks.combined_moment=maxf(peaks.combined_moment,(Vector3(force.torque)+app.ground_motor.applied_torque).length())
	if elapsed>=next_sample:
		next_sample=elapsed+.1
		ascent_samples.append({"time":elapsed,"position":app.torso.position,"velocity":app.torso.linear_velocity,"grounded":app.ground_motor.grounded,"ground_support_id":app.ground_motor.support_body.get_instance_id() if is_instance_valid(app.ground_motor.support_body) else 0,"hands":app.controller.hands.map(func(hand):return {"state":hand.state,"force":hand.force,"point":hand.anchor_world,"reason":hand.reason}),"stage":app.climbing_route.stage,"route_completed":app.climbing_route.completed,"hand_force":force.total_force,"leg_force":force.leg_force,"hybrid_state":hybrid.state,"hybrid_reason":hybrid.reason,"hybrid_progress":hybrid.progress})

func surface_transfer(id:int,point:Vector3,label:String,seconds:float=3.0)->bool:
	if app.hybrid_mantle.commits>0:return true
	button(id,false)
	aim(point)
	button(id,true)
	var start:float=elapsed
	for frame in int(seconds*hz):
		await ticks(1.0/hz)
		if app.hybrid_mantle.commits>0:return true
		if app.controller.get_hand_state(id)=="ATTACHED":
			var hand:Dictionary=app.controller.hands[id]
			var support:PhysicsBody3D=hand.anchor.support_body()
			ascent_contacts.append({"label":label,"time":elapsed,"duration":elapsed-start,"hand":id,"selected":point,"contact":hand.anchor.world_point(),"support":str(support.name),"platform_contact":support==app.level.platform,"position":app.torso.position,"pending":app.controller.pending_diagnostics(id)})
			return true
	failed_transfer={"label":label,"hand":id,"point":point,"position":app.torso.position,"shoulder":app.controller.get_shoulder_world(id),"distance":app.controller.get_shoulder_world(id).distance_to(point),"pending":app.controller.pending_diagnostics(id),"hybrid":app.hybrid_mantle.data.duplicate(true)}
	print("ASCENT BLOCK ",failed_transfer)
	return false

func original_course()->bool:
	check(await grip(0,app.level.transfer_points[0]),"ordinary-spawn left actual finite grip")
	check(await grip(1,app.level.transfer_points[1]),"ordinary-spawn right actual finite grip")
	app.controller.sample_ready.connect(sample)
	await ticks(.3)
	entry_height=app.torso.position.y
	Input.action_press("contract")
	await ticks(3)
	if not await surface_transfer(0,app.level.transfer_points[2],"higher left wall"):return false
	await ticks(.25)
	Input.action_press("bias_right")
	if not await surface_transfer(1,app.level.transfer_points[3],"higher right wall"):return false
	Input.action_release("bias_right")
	await ticks(1)
	Input.action_press("bias_right")
	if not await surface_transfer(0,app.level.transfer_points[4],"left crossing"):return false
	await ticks(.6)
	# The level's representative marker stays outside the first bar footprint.
	if not await surface_transfer(1,app.level.transfer_points[5],"right uncovered wall edge"):return false
	await ticks(.3)
	if not await surface_transfer(1,Vector3(.69,2.51,.20),"right around bar leading edge"):return false
	await ticks(.3)
	await wait_reach_window(0,6,2)
	if not await surface_transfer(0,Vector3(.74,2.53,.20),"first bar left"):return false
	Input.action_release("bias_right")
	Input.action_press("bias_left")
	await ticks(.15)
	Input.action_release("bias_left")
	await ticks(.25)
	await wait_reach_window(1,7,1)
	if not await surface_transfer(1,app.level.transfer_points[7],"first bar right"):return false
	await ticks(1.0)
	if not await surface_transfer(0,app.level.transfer_points[8],"align left bar"):return false
	await ticks(.8)
	Input.action_press("bias_right")
	var entry_point:=Vector3(1.60,app.level.transfer_points[9].y,app.level.transfer_points[9].z)
	await wait_reach_window(1,9,2)
	if not await surface_transfer(1,entry_point,"finish bar right"):return false
	await ticks(.6)
	Input.action_release("bias_right")
	await ticks(.8)
	# Rendered physics may reach the broad region a little later than the
	# headless replay. Wait for its actual contact/height dwell, not a fixed
	# animation delay or a fabricated completion event.
	for frame in 3*hz:
		if app.climbing_route.completed:break
		await ticks(1.0/hz)
	check(app.climbing_route.completed,"original climb traverse suspension stages earned before top-out")
	check(not app.hybrid_mantle.completed and app.hybrid_mantle.commits==0,"bar finish alone never declares the new top-out")
	return app.climbing_route.completed

func exercise_first_ascent()->Dictionary:
	await fresh(0,false)
	app._open_first_ascent()
	app.won=false
	await ticks(.4)
	app._set_distant_targeting(true)
	check(app.level.scenario=="FIRST_ASCENT" and app.hybrid_mantle.enabled and app.hybrid_mantle.contextual_vault_v10_enabled,"explicit new level enables its authored vault without changing old route")
	var course_ok:bool=await original_course()
	if course_ok:
		Input.action_press("bias_right")
		var front:float=app.level.transfer_points[11].z
		var bar_y:float=app.level.transfer_points[9].y
		var sequence:Array=[
			{"id":0,"point":Vector3(1.60,bar_y,front),"label":"align left on finish bar"},
			{"id":1,"point":Vector3(2.02,2.60,front),"label":"right slab approach"},
			{"id":0,"point":Vector3(2.06,2.65,front),"label":"left slab approach"},
			{"id":1,"point":Vector3(2.30,2.82,front),"label":"right slab climb"},
			{"id":0,"point":Vector3(2.16,2.88,front),"label":"left upper face"},
			{"id":1,"point":Vector3(2.34,3.06,front),"label":"right upper lip"}
		]
		for entry in sequence:
			if entry.label=="right upper lip":
				# Keep the lower real grip while W earns a comfortable catch
				# window. A contact at full reach on a descending body is fragile.
				for frame in 6*hz:
					var ready_height:float=app.level.top_y-1.08
					if app.torso.position.y>=ready_height and app.controller.get_shoulder_world(entry.id).distance_to(entry.point)<.60:break
					await ticks(1.0/hz)
			var caught:bool=await surface_transfer(entry.id,entry.point,entry.label)
			check(caught,"real surface transfer / "+entry.label)
			if not caught:break
			if entry.label=="right slab approach":Input.action_release("bias_right")
			await ticks(.8 if entry.label!="align left on finish bar" else .35)
			if app.hybrid_mantle.commits>0:break
	Input.action_release("bias_right")
	# W is explicit throughout; the hybrid is allowed only after collision-backed
	# candidate detection. No direct candidate, route or ownership calls here.
	for frame in 5*hz:
		await ticks(1.0/hz)
		if app.hybrid_mantle.state in ["DYNAMIC_GROUNDED","BLOCKED_RECOVERY"]:break
	check(app.hybrid_mantle.commits==1 and old_route_done_before_commit,"one committed top-out follows actual continuous three-stage traversal")
	check(app.hybrid_mantle.state=="DYNAMIC_GROUNDED" and app.hybrid_mantle._native_ground() and app.ground_motor.support_body==app.level.platform,"original standing sole earns actual native top-platform support")
	for id in 2:button(id,false)
	for frame in 2*hz:
		await ticks(1.0/hz)
		if app.hybrid_mantle.completed:break
	Input.action_release("contract")
	check(app.hybrid_mantle.completed and app.hybrid_mantle.walk_distance>=.30 and app.controller._attached_ids().is_empty(),"hands free and real ordinary walking earns30cm beyond top-out")
	check(continuous,"no loss of all real hand support before explicit assisted commitment")
	check(not app.torso.freeze and not app.controller.assisted_motion_owned and not app.ground_motor.assisted_authority_suspended,"completed ascent returns normal dynamic and ground ownership")
	check(budgets_ok,"all unassisted actions respect existing hand foot and total moment caps")
	report={"physics_hz":hz,"checks":checks,"failures":failures,"scope":"automated actual input from ordinary floor; no character pose velocity or solver writes; no human feel claim","contacts":ascent_contacts,"samples":ascent_samples,"failed_transfer":failed_transfer,"initial_height":entry_height,"final_position":app.torso.position,"height_gain":app.torso.position.y-entry_height,"peaks":peaks,"course_progress":app.climbing_route.diagnostics(),"hybrid":app.hybrid_mantle.data.duplicate(true)}
	# Rendered subclasses may reuse this exact exercise and inspect the live app
	# before taking screenshots. This helper never closes or recreates the app.
	return report

