extends "res://features/grip_up/tests/test_intent_integration.gd"
var trials:Array=[]
var observed:Dictionary={}
var last_position:=Vector3.ZERO
var next_sample:=0.0

func observe(delta:float)->void:
	if observed.is_empty():return
	observed.max_step=maxf(observed.max_step,app.torso.position.distance_to(last_position))
	last_position=app.torso.position
	if app.controller.assisted_motion_owned:
		observed.no_old_force=observed.no_old_force and app.controller.telemetry().get("total_force",0)==0 and app.ground_motor.applied_force.length()<.0001 and app.controller._attached_ids().is_empty()
	if app.controller.simulation_time>=next_sample:
		next_sample=app.controller.simulation_time+.05
		observed.samples.append({"time":app.controller.simulation_time,"position":app.torso.position,"velocity":app.torso.linear_velocity,"hybrid":app.hybrid_mantle.data.duplicate(true),"hands":app.controller.hands.map(func(hand):return {"state":hand.state,"contact":hand.anchor_world,"force":hand.force}),"ground":app.ground_motor.grounded})

func transfer(id:int,point:Vector3)->bool:
	button(id,false)
	aim(point)
	button(id,true)
	for frame in int(hz*1.5):
		await ticks(1.0/hz)
		if app.controller.get_hand_state(id)=="ATTACHED":return true
	return false

func ascent(scenario:int)->Dictionary:
	await fresh(0,false)
	app._open_hybrid_mantle(scenario)
	app.won=false
	await ticks(.4)
	observed={"scenario":"F1_LOW" if scenario==0 else "F2_HIGH","samples":[],"max_step":0.0,"no_old_force":true,"approach":"Actual ordinary spawn on approach floor; no body writes, pad removal or staged transport"}
	last_position=app.torso.position
	next_sample=0
	app.controller.sample_ready.connect(observe)
	check(not app.controller.physics_mantle_v08_enabled and not app.controller.palm_compression_enabled and not app.torso.has_meta("adaptive_legs"),"hybrid independent of v08 palm/leg experiment")
	var left:bool=await grip(0,app.level.transfer_points[0])
	var right:bool=await grip(1,app.level.transfer_points[1])
	check(left and right,"ordinary approach earns two actual finite grips")
	Input.action_press("contract")
	if scenario==1:
		for index in 10:
			await ticks(.8)
			if app.hybrid_mantle.commits>0:break
			var id:int=index%2
			# Ordinary deliberate intermediate wall grips; retain the other real
			# support and do not release it while its replacement remains pending.
			if app.controller.get_hand_state(1-id)!="ATTACHED":continue
			var shoulder:Vector3=app.controller.get_shoulder_world(id)
			var selected:=Vector3(clampf(shoulder.x,-.7,.7),minf(app.level.top_y-.05,shoulder.y+.50),0)
			await transfer(id,selected)
	else:
		for frame in 5*hz:
			await ticks(1.0/hz)
			if app.hybrid_mantle.commits>0:break
	observed.committed=app.hybrid_mantle.commits>0
	check(observed.committed,"ledge-specific W commits from real geometry and actual hanging grip")
	# The committed action no longer depends on holding grip buttons or W.
	for id in 2:button(id,false)
	Input.action_release("contract")
	for frame in 4*hz:
		await ticks(1.0/hz)
		if app.hybrid_mantle.state in ["DYNAMIC_GROUNDED","BLOCKED_RECOVERY"]:break
	observed.after_animation=app.hybrid_mantle.data.duplicate(true)
	check(app.hybrid_mantle.state=="DYNAMIC_GROUNDED" and not app.torso.freeze and app.ground_motor.support_body==app.level.platform,"actual top ground restores dynamic body and walking authority")
	if app.hybrid_mantle.state=="DYNAMIC_GROUNDED":
		Input.action_press("contract")
		for frame in hz:
			await ticks(1.0/hz)
			if app.hybrid_mantle.completed:break
		Input.action_release("contract")
	check(app.hybrid_mantle.completed and app.hybrid_mantle.walk_distance>=.30,"FULL static top-out then30cm ordinary ground walk")
	check(observed.no_old_force,"no old hand/foot/ground force while assisted authority owns body")
	check(app.hybrid_mantle.commits==1 and app.hybrid_mantle.restores==1,"commit and restore occur exactly once")
	observed.final=app.hybrid_mantle.data.duplicate(true)
	observed.events=app.hybrid_mantle.events.duplicate(true)
	var row:=observed.duplicate(true)
	observed={}
	for id in 2:button(id,false)
	return row

func run()->void:
	trials.append(await ascent(0))
	trials.append(await ascent(1))
	report={"physics_hz":hz,"checks":checks,"failures":failures,"trials":trials,"functional_gate_met":trials.all(func(row):return row.final.mantle_complete),"provenance":"In-app player input from ordinary approach; automated, not human feel"}
	FileAccess.open("res://builds/hybrid_mantle_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	app.queue_free()
	await ticks(.03)
	print("HYBRID MANTLE RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
