extends SceneTree
const Fixture=preload("res://features/grip_up/tests/palm_compression_lab.gd")
var hz:=120
var checks:=0
var failures:=0
var fixture:Node3D
var trials:Array=[]
var finite:=true
var pending_zero:=true

func _initialize()->void:
	if OS.get_cmdline_user_args().has("--60hz"):hz=60
	Engine.physics_ticks_per_second=hz
	run.call_deferred()

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func ticks(seconds:float)->void:
	for frame in maxi(1,int(seconds*hz)):await physics_frame

func setup(two:bool=false,moving:bool=false)->void:
	if is_instance_valid(fixture):fixture.queue_free();await physics_frame;await physics_frame
	fixture=Fixture.new()
	fixture.definition={"wrist":true,"two":two,"moving":moving}
	root.add_child(fixture)
	await ticks(.05)

func acquire(id:int)->bool:
	if not fixture.request(id):return false
	for frame in 2*hz:
		await physics_frame
		var pending:Dictionary=fixture.controller.pending_diagnostics(id)
		finite=finite and pending.get("gesture_speed",0.0)<=4.0002
		if fixture.controller.get_hand_state(id)=="REACHING":pending_zero=pending_zero and fixture.controller.get_arm_force(id).length()<.000001
		if fixture.controller.get_hand_state(id)=="ATTACHED":return true
	return false

func trial(two:bool=false,moving:bool=false)->void:
	await setup(two,moving)
	var c:Node=fixture.controller
	var witness:Dictionary=c._palm_arm_witness(c.get_shoulder_world(0),fixture.points[0],Vector3.UP,fixture.support)
	check(witness.valid,"current below-edge bent arm has two collision-free finite links and real palm surface")
	if witness.valid:
		check(absf(Vector3(witness.elbow).distance_to(witness.shoulder)-.27000)<.00001 and absf(Vector3(witness.wrist).distance_to(witness.elbow)-.27708)<.00001 and absf(Vector3(witness.palm).distance_to(witness.wrist)-.11)<.00001,"bent witness preserves declared upper/forearm lengths and finite hand length")
	check(await acquire(0),"H0 hand follows finite route above the lip and reaches actual top contact")
	if c.get_hand_state(0)!="ATTACHED":
		print("FAILED CONTACT ",c.hands[0]," PENDING ",c.pending_diagnostics(0))
		return
	if two:check(await acquire(1),"second H0 palm independently reaches real top contact")
	await ticks(.12)
	var start:Vector3=fixture.body.global_position
	var momentum:Vector3=fixture.body.linear_velocity*12
	if moving:momentum+=fixture.support.linear_velocity*30
	fixture.press=1
	var rise:=0.0
	var normal_peak:=0.0
	var moment_peak:=0.0
	var residual:=0.0
	var momentum_error:=0.0
	var caps:=true
	var rows:Array=[]
	for frame in int(.6*hz):
		await physics_frame
		var data:Dictionary=c.telemetry()
		rise=maxf(rise,fixture.body.global_position.y-start.y)
		var moment:=0.0
		for palm in c.palm_solver.records.values():
			normal_peak=maxf(normal_peak,palm.get("applied_normal",0.0))
			moment+=Vector3(palm.get("admitted_body_couple",Vector3.ZERO)).length()
			residual=maxf(residual,Vector3(palm.get("pair_wrench_residual",Vector3.ZERO)).length())
		moment_peak=maxf(moment_peak,moment)
		caps=caps and moment+Vector3(data.ledge_transfer.get("reacted_assist",Vector3.ZERO)).length()<=20.001 and data.total_force<=360.001 and Vector3(data.torque).length()<=150.001
		if moving:momentum_error=maxf(momentum_error,(fixture.body.linear_velocity*12+fixture.support.linear_velocity*30-momentum).length())
		if frame%maxi(1,int(hz/20.0))==0:rows.append({"time":frame/float(hz),"position":fixture.body.global_position,"velocity":fixture.body.linear_velocity,"palms":c.palm_solver.diagnostics(),"moment":moment})
	check(rise>.01 and normal_peak>(1.0 if moving else 5.0),"finite below-edge wrist press produces actual body lift")
	check(caps and moment_peak>0,"all palms together reserve at most the existing20Nm before other assist")
	check(residual<.0001,"normal force pair plus explicitly charged body couple conserves paired wrench")
	if moving:check(momentum_error<.002,"dynamic support receives opposite normal force with conserved linear momentum")
	trials.append({"two":two,"moving":moving,"rise":rise,"normal_peak":normal_peak,"moment_peak":moment_peak,"pair_wrench_residual":residual,"momentum_error":momentum_error,"samples":rows})
	c.release_grip(0)
	if two:c.release_grip(1)
	await ticks(.03)
	check(c.telemetry().total_force==0 and Vector3(c.telemetry().assist_torque)==Vector3.ZERO,"release leaves no wrist force or couple")

func loaded_and_invalid()->void:
	await setup(true)
	check(await acquire(0) and await acquire(1),"loaded fixture obtains two finite current palms")
	fixture.body.gravity_scale=1
	fixture.press=1
	var peak:=0.0
	var bounded:=true
	var rows:Array=[]
	for frame in int(.4*hz):
		await physics_frame
		var data:Dictionary=fixture.controller.telemetry()
		var sum_moment:=0.0
		var normals:=0.0
		for palm in fixture.controller.palm_solver.records.values():
			sum_moment+=Vector3(palm.get("admitted_body_couple",Vector3.ZERO)).length()
			normals+=palm.get("applied_normal",0.0)
		peak=maxf(peak,sum_moment)
		bounded=bounded and sum_moment<=20.001 and normals<=360.001 and Vector3(data.torque).length()<=150.001
		if frame%maxi(1,int(hz/20.0))==0:rows.append({"time":frame/float(hz),"position":fixture.body.global_position,"normal_sum":normals,"couple_sum":sum_moment})
	check(peak>19.9 and bounded,"gravity-loaded pair saturates the shared20Nm once without doubling wrist authority")
	trials.append({"gravity_loaded":true,"peak_wrist_sum":peak,"end_body":fixture.body.global_position,"samples":rows})
	await setup()
	check(await acquire(0),"invalidating fixture establishes real contact")
	fixture.press=1
	await ticks(.15)
	var blocker:=StaticBody3D.new()
	blocker.collision_layer=2
	blocker.position=Vector3(-.1919,fixture.points[0].y+.065,.45)
	var solid:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(.9,.05,.4)
	solid.shape=shape
	blocker.add_child(solid)
	fixture.add_child(blocker)
	await ticks(.04)
	check(fixture.controller.get_arm_force(0)==Vector3.ZERO and Vector3(fixture.controller.telemetry().assist_torque)==Vector3.ZERO and not fixture.controller.is_palm_hand(0),"new physical arm obstruction immediately removes both force and joint couple")
	await setup()
	fixture.support.set_meta("palm_load_limit",.05)
	check(await acquire(0),"low-capacity surface can receive unloaded actual palm")
	fixture.press=1
	await ticks(.6)
	check(fixture.controller.get_arm_force(0)==Vector3.ZERO and not fixture.controller.is_palm_hand(0),"material capacity uses actual admitted compression and releases overloaded palm")
	await setup()
	check(await acquire(0),"support-loss fixture obtains finite wrist palm")
	fixture.press=1
	await ticks(.15)
	fixture.support.queue_free()
	await ticks(.04)
	check(fixture.controller.get_arm_force(0)==Vector3.ZERO and Vector3(fixture.controller.telemetry().assist_torque)==Vector3.ZERO,"disappearing support cannot leave a body-only couple")
	await setup()
	fixture.request(0)
	await ticks(.04)
	fixture.controller.set_hand_held(0,false,"input_focus_lost")
	await ticks(.1)
	check(fixture.controller.get_arm_force(0)==Vector3.ZERO and not fixture.controller.is_palm_hand(0),"focus cancellation before contact has no wrist or compression authority")

func planning_bounds()->void:
	await setup()
	check(await acquire(0),"planning fixture begins from actual current palm contact")
	var c:Node=fixture.controller
	var record:Dictionary=c.palm_solver.records[0]
	var pose:Transform3D=fixture.body.global_transform
	var velocity:Vector3=fixture.body.linear_velocity
	var original_height:float=record.height
	# Coordinator uses positive traversal y for W, independent of screen axes.
	c.intent_locomotion.requested=Vector2(0,1)
	var envelope:=0.0
	var rate:=0.0
	var acceleration:=0.0
	for frame in 3*hz:
		c.palm_solver._prepare_wrist(c,0,record,1.0/hz)
		envelope=maxf(envelope,absf(float(record.height_target)-original_height))
		rate=maxf(rate,absf(record.target_rate))
		acceleration=maxf(acceleration,absf(record.target_acceleration))
	check(envelope<=.0551 and rate<=.2401 and acceleration<=.9001,"unachieved wrist request remains55mm/rate/acceleration bounded without accumulating3s of input")
	c.intent_locomotion.requested=Vector2.ZERO
	for frame in 2*hz:c.palm_solver._prepare_wrist(c,0,record,1.0/hz)
	var braking_deadband:float=.5*c.tuning.traversal_target_max_acceleration/(hz*hz)+.000001
	check(absf(float(record.height_target)-original_height)<=braking_deadband,"neutral relaxes unachieved wrist extension to its discrete acceleration-braking deadband")
	check(fixture.body.global_transform==pose and fixture.body.linear_velocity==velocity,"wrist planning writes neither body pose nor velocity")

func run()->void:
	await trial()
	await trial(true)
	await trial(false,true)
	await loaded_and_invalid()
	await planning_bounds()
	check(finite and pending_zero,"every H0 pending sample retains the4m/s relative gesture cap and zero effort")
	FileAccess.open("res://builds/palm_wrist_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify({"physics_hz":hz,"checks":checks,"failures":failures,"trials":trials},"\t"))
	fixture.queue_free()
	await physics_frame
	print("PALM WRIST RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
