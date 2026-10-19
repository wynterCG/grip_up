extends "res://features/grip_up/tests/test_intent_integration.gd"
## Functional acceptance, deliberately FAILS if the full hanging-to-walk gate fails.
var rows:Array=[]
var acquisition:Dictionary={}
var measured:Dictionary={}
var sample_time:=0.0
var next_sample:=0.0

func measure(delta:float)->void:
	if measured.is_empty():return
	sample_time+=delta
	for hand in app.controller.hands:
		if hand.get("contact_mode","") in ["PALM_CONTACT","PALM_SLIPPING"]:
			measured.max_palm_force=maxf(measured.max_palm_force,Vector3(hand.force).length())
			measured.palm_load_seen=measured.palm_load_seen or Vector3(hand.force).length()>1
	measured.max_speed=maxf(measured.max_speed,app.torso.linear_velocity.length())
	if sample_time>=next_sample:
		next_sample=sample_time+.1
		var collision:Dictionary=app.mantle_v08.legs.clearance_diagnostics()
		measured.max_penetration_estimate=maxf(measured.max_penetration_estimate,collision.max_penetration_estimate_m)
		measured.samples.append({"time":sample_time,"position":app.torso.global_position,"velocity":app.torso.linear_velocity,"hands":app.controller.hands.map(func(hand):return {"state":hand.state,"reason":hand.reason,"mode":hand.get("contact_mode",""),"force":hand.force,"palm":hand.get("palm",{})}),"support":app.mantle_v08.data.duplicate(true),"collision":collision})

func acquire(id:int,point:Vector3,seconds:float=2.0)->bool:
	aim(point)
	button(id,true)
	for frame in int(seconds*hz):
		await ticks(1.0/hz)
		if app.controller.get_hand_state(id)=="ATTACHED":
			acquisition={"state":"ATTACHED","mode":app.controller.hands[id].get("contact_mode",""),"contact":app.controller.hands[id].anchor_world,"shoulder":app.controller.get_shoulder_world(id)}
			return true
	acquisition={"state":app.controller.get_hand_state(id),"reason":app.controller.hands[id].reason,"pending":app.controller.pending_diagnostics(id),"shoulder":app.controller.get_shoulder_world(id),"requested":point}
	return false

func sequence(index:int)->Dictionary:
	await fresh(index,true)
	app.mantle_hanging_fixture_start=true
	app._open_mantle_v08(index)
	app.won=false
	await ticks(.35)
	app.camera.orbit(Vector2(0,160))
	app.camera._update_camera(1.0)
	var row:={"platform_top":app.level.top_y,"samples":[],"left_edge":false,"right_edge":false,"left_palm_contact":false,"right_palm_contact":false,"palm_load_seen":false,"body_write_policy":"setup position only; no body writes after simulation begins","max_palm_force":0.0,"max_speed":0.0,"max_penetration_estimate":0.0}
	row.fixture_start="Body initialized below edge before simulation. Pad removed only after two finite grips. Not ordinary approach/human evidence."
	measured=row
	sample_time=0
	next_sample=0
	app.controller.sample_ready.connect(measure)
	row.left_edge=await acquire(0,app.level.transfer_points[0])
	row.right_edge=await acquire(1,app.level.transfer_points[1])
	check(row.left_edge and row.right_edge,"T%02d initial finite edge contacts"%(index-11))
	# Removing a fixture launch pad creates a genuinely hanging start. It supplies
	# no subsequent support, hidden boost or temporary collision-mask bypass.
	app.level.start_pad.queue_free()
	for frame in 2*hz:
		await ticks(1.0/hz)
		if app.mantle_v08.had_hanging_start:break
	row.valid_hanging_start=app.mantle_v08.had_hanging_start
	check(row.valid_hanging_start,"T%02d actual loaded suspension before mantle effort"%(index-11))
	Input.action_press("contract")
	await ticks(.7)
	var counterbalance:bool=OS.get_cmdline_user_args().has("--counterbalance")
	row.counterbalance_variant=counterbalance
	if counterbalance:
		Input.action_press("bias_left")
		await ticks(.35)
	button(0,false)
	row.left_palm_contact=await acquire(0,app.level.transfer_points[2])
	row.left_palm_acquisition=acquisition.duplicate(true)
	if counterbalance:
		await ticks(.2)
		Input.action_release("bias_left")
		await ticks(.3)
	else:await ticks(.5)
	row.left_after_settle={"state":app.controller.hands[0].state,"reason":app.controller.hands[0].reason,"witness":app.controller._palm_arm_witness(app.controller.get_shoulder_world(0),app.level.transfer_points[2],Vector3.UP,app.level.platform)}
	if row.left_palm_contact and app.controller.get_arm_force(0).length()>1:
		button(1,false)
		row.right_palm_contact=await acquire(1,app.level.transfer_points[3])
		row.right_palm_acquisition=acquisition.duplicate(true)
	for frame in 8*hz:
		await ticks(1.0/hz)
		if app.ground_motor.grounded and app.ground_motor.support_body==app.level.platform:
			for id in 2:button(id,false)
	Input.action_release("contract")
	row.functional_completion=app.mantle_v08.completed
	row.final=app.mantle_v08.data.duplicate(true)
	row.final_position=app.torso.global_position
	check(row.functional_completion,"T%02d FULL TOP-OUT from hang, standing collider restored, hands released, stable actual top ground and30cm walk"%(index-11))
	check(budgets_ok,"T%02d unchanged shared force and moment limits"%(index-11))
	for id in 2:button(id,false)
	measured={}
	return row

func run()->void:
	rows.append(await sequence(12))
	rows.append(await sequence(13))
	report={"physics_hz":hz,"checks":checks,"failures":failures,"milestone":"M4 strict functional gate","trials":rows,"functional_gate_met":rows.all(func(row):return row.functional_completion)}
	FileAccess.open("res://builds/mantle_full_sequence_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	app.queue_free()
	await ticks(.03)
	print("MANTLE FULL SEQUENCE RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
