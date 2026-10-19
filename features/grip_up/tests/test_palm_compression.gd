extends SceneTree
const Fixture=preload("res://features/grip_up/tests/palm_compression_lab.gd")
var hz:=120
var checks:=0
var failures:=0
var fixture:Node3D
var trials:Array=[]
var caps:=true
var no_early_force:=true

func _initialize()->void:
	if OS.get_cmdline_user_args().has("--60hz"):hz=60
	Engine.physics_ticks_per_second=hz
	run.call_deferred()

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func tick()->void:
	await physics_frame
	if is_instance_valid(fixture):
		var data:Dictionary=fixture.controller.telemetry()
		if not data.is_empty():
			caps=caps and data.total_force<=360.001 and Vector3(data.assist_torque).length()<=20.001 and Vector3(data.torque).length()<=150.001
			for hand in fixture.controller.hands:
				if hand.state not in ["ATTACHED","SLIPPING"]:no_early_force=no_early_force and Vector3(hand.force).length()<.000001

func ticks(seconds:float)->void:
	for frame in maxi(1,int(seconds*hz)):await tick()

func setup(definition:Dictionary={})->void:
	if is_instance_valid(fixture):fixture.queue_free();await physics_frame;await physics_frame
	fixture=Fixture.new()
	fixture.definition=definition
	root.add_child(fixture)
	await ticks(.05)

func acquire(id:int)->bool:
	if not fixture.request(id):return false
	for frame in hz:
		await tick()
		if fixture.controller.get_hand_state(id)=="ATTACHED":return true
	return false

func physical_press(two:bool=false,moving:bool=false)->Dictionary:
	await setup({"moving":moving,"two":two})
	var pose:Transform3D=fixture.body.global_transform
	var velocity:Vector3=fixture.body.linear_velocity
	check(fixture.request(0),"real top surface starts finite H0 hand reach")
	check(fixture.controller.get_hand_state(0)=="REACHING" and fixture.controller.get_arm_force(0)==Vector3.ZERO,"pending top hand is not already a palm support")
	check(fixture.body.global_transform==pose and fixture.body.linear_velocity==velocity,"palm request never teleports or impulses body")
	for frame in hz:
		await tick()
		if fixture.controller.get_hand_state(0)=="ATTACHED":break
	check(fixture.controller.get_hand_state(0)=="ATTACHED" and fixture.controller.hands[0].get("contact_mode","")=="PALM_CONTACT","finite arrival and full footprint establish exactly one palm mode")
	if two:check(await acquire(1),"second independent finite palm arrives")
	await ticks(.12)
	var start:Vector3=fixture.body.global_position
	var start_support:Vector3=fixture.support.global_position
	if not moving:fixture.body.gravity_scale=1
	fixture.press=1
	var peak_y:float=start.y
	var peak_force:=0.0
	var minimum_normal:=0.0
	var friction_ok:=true
	var pair_residual:=0.0
	var momentum:Vector3=fixture.body.linear_velocity*12
	if moving:momentum+=fixture.support.linear_velocity*30
	var momentum_error:=0.0
	var rows:Array=[]
	for frame in int(.65*hz):
		await tick()
		peak_y=maxf(peak_y,fixture.body.global_position.y)
		var data:Dictionary=fixture.controller.telemetry()
		peak_force=maxf(peak_force,data.total_force)
		for hand in fixture.controller.hands:
			if hand.has("palm"):
				var palm:Dictionary=hand.palm
				minimum_normal=minf(minimum_normal,palm.get("applied_normal",0))
				friction_ok=friction_ok and Vector3(palm.get("applied_tangent",Vector3.ZERO)).length()<=palm.get("friction",.85)*palm.get("applied_normal",0)+.0001
				pair_residual=maxf(pair_residual,Vector3(palm.get("pair_wrench_residual",Vector3.ZERO)).length())
		if moving:momentum_error=maxf(momentum_error,(fixture.body.linear_velocity*12+fixture.support.linear_velocity*30-momentum).length())
		if frame%maxi(1,hz/20)==0:rows.append({"time":frame/float(hz),"position":fixture.body.global_position,"velocity":fixture.body.linear_velocity,"support":fixture.support.global_position,"force":data.total_force,"palm":fixture.controller.palm_solver.diagnostics()})
	check(peak_y>start.y+.015,"actual finite palm force raises body above its pre-press pose")
	check(peak_force>5 and peak_force<=360.001 and minimum_normal>=0 and friction_ok,"compressive normal is unilateral and admitted axial tangent stays within friction cone")
	check(pair_residual<.0001,"shoulder force and material-point reaction conserve complete paired wrench")
	if moving:
		check(fixture.support.global_position.y<start_support.y-.001,"free dynamic platform receives actual downward reaction")
		check(momentum_error<.002,"isolated body+platform preserve total linear momentum")
		check(Vector3(fixture.controller.telemetry().assist_torque)==Vector3.ZERO,"pure palm has no unmodelled adhesive attitude motor")
	var result:Dictionary={"two":two,"moving":moving,"rise":peak_y-start.y,"peak_force":peak_force,"wrench_residual":pair_residual,"momentum_error":momentum_error,"support_displacement":fixture.support.global_position-start_support,"samples":rows}
	trials.append(result)
	fixture.controller.release_grip(0)
	if two:fixture.controller.release_grip(1)
	await tick()
	check(fixture.controller.telemetry().total_force==0 and fixture.controller.palm_solver.records.is_empty(),"explicit release clears palm force and old material record immediately")
	return result

func invalid_contacts()->void:
	await setup({"air":true})
	fixture.press=1
	fixture.request(0)
	await ticks(.4)
	check(fixture.controller.get_arm_force(0)==Vector3.ZERO and not fixture.controller.is_palm_hand(0),"hand suspended3cm above surface has no palm reaction")
	await setup({"corner":true})
	fixture.request(0)
	await ticks(.4)
	check(fixture.controller.get_arm_force(0)==Vector3.ZERO and fixture.controller.get_hand_state(0)!="ATTACHED","corner point cannot substitute for full finite palm footprint")
	await setup({"friction":.05,"offset_z":-.08})
	check(await acquire(0),"slippery material can receive an actual hand contact")
	fixture.press=1
	await ticks(.3)
	check(fixture.controller.get_arm_force(0)==Vector3.ZERO and fixture.controller.get_hand_state(0) in ["FREE","RELEASED"],"axial request outside friction cone slips/releases without nonaxial rescue force")
	await setup()
	check(await acquire(0),"support-loss fixture obtains finite palm")
	fixture.support.queue_free()
	fixture.press=1
	await ticks(.05)
	check(fixture.controller.get_arm_force(0)==Vector3.ZERO and fixture.controller.palm_solver.records.is_empty(),"destroyed support cannot retain palm or torque authority")
	check(Vector3(fixture.controller.hands[0].palm.applied_force)==Vector3.ZERO,"released palm telemetry never retains stale applied load")

func ownership_and_targets()->void:
	await setup()
	check(await acquire(0),"unloaded palm fixture acquires current contact")
	await ticks(.15)
	check(fixture.controller.get_arm_force(0).length()<.00001,"valid unloaded palm produces zero reaction without adhesive preload")
	var before:Transform3D=fixture.body.global_transform
	fixture.controller.palm_solver.prepare(fixture.controller,1.0/hz,true)
	check(fixture.body.global_transform==before,"contact and press planning never transform the torso")
	var blocker:=StaticBody3D.new()
	blocker.collision_layer=2
	blocker.position=(fixture.points[0]+fixture.controller.get_shoulder_world(0))*.5
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(.12,.03,.12)
	shape.shape=box
	blocker.add_child(shape)
	fixture.add_child(blocker)
	fixture.press=1
	await ticks(.05)
	check(fixture.controller.get_arm_force(0)==Vector3.ZERO and not fixture.controller.is_palm_hand(0),"new actual shoulder-path obstruction immediately removes all palm authority")
	await setup({"two":true})
	check(await acquire(0) and await acquire(1),"blocked press fixture obtains both real palms")
	await ticks(.2)
	var ceiling:=StaticBody3D.new()
	ceiling.position=Vector3(0,3.66,.55)
	ceiling.collision_layer=1
	var solid:=CollisionShape3D.new()
	var plate:=BoxShape3D.new()
	plate.size=Vector3(2,.2,2)
	solid.shape=plate
	ceiling.add_child(solid)
	fixture.add_child(ceiling)
	fixture.press=1
	var maximum_error:=0.0
	var max_rate:=0.0
	var max_accel:=0.0
	for frame in 3*hz:
		await tick()
		for record in fixture.controller.palm_solver.records.values():
			maximum_error=maxf(maximum_error,absf(float(record.goal)-float(record.length)))
			max_rate=maxf(max_rate,absf(record.target_rate))
			max_accel=maxf(max_accel,absf(record.target_acceleration))
	check(maximum_error<=.0551 and max_rate<=.2401 and max_accel<=.9001,"blocked continuous press preserves55mm geometry envelope and finite target rate/acceleration")
	fixture.press=0
	await ticks(1)
	var rest:Array=[]
	for hand in fixture.controller.hands:rest.append(hand.rest_length)
	await ticks(.5)
	check(absf(fixture.controller.hands[0].rest_length-rest[0])<.003 and absf(fixture.controller.hands[1].rest_length-rest[1])<.003,"neutral freezes achieved press target after bounded release settling")
	var rows:Array=[]
	for master in [false,true]:
		await setup({"master":master,"enabled":false})
		check(await acquire(0),"legacy top grip remains reachable with palm flagOFF")
		fixture.press=1
		var trial:Array=[]
		for frame in int(.3*hz):
			await tick()
			trial.append([fixture.body.global_transform,fixture.body.linear_velocity,fixture.controller.get_arm_force(0)])
		rows.append(trial)
	check(rows[0]==rows[1],"master flag alone with palmOFF preserves exact legacy physical trajectory")

func mixed_support()->void:
	await setup()
	check(await acquire(0),"mixed fixture establishes one real palm")
	var wall:=StaticBody3D.new()
	var point:Vector3=fixture.controller.get_shoulder_world(1)+Vector3(0,.25,-.25)
	wall.position=point-Vector3.BACK*.05
	wall.collision_layer=2
	wall.set_meta("grippable",true)
	wall.set_meta("grip_load_limit",10000.0)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(.4,.6,.1)
	shape.shape=box
	wall.add_child(shape)
	fixture.add_child(wall)
	await ticks(.03)
	check(fixture.controller.request_held_grip(1,wall,point,Vector3.BACK),"other hand independently requests existing traction support")
	for frame in hz:
		await tick()
		if fixture.controller.get_hand_state(1)=="ATTACHED":break
	fixture.press=1
	var simultaneous:=false
	var counted:=true
	for frame in int(.35*hz):
		await tick()
		var f0:float=fixture.controller.get_arm_force(0).length()
		var f1:float=fixture.controller.get_arm_force(1).length()
		simultaneous=simultaneous or f0>.01 and f1>.01
		counted=counted and absf(fixture.controller.telemetry().total_force-f0-f1)<.001
	check(simultaneous and counted,"one traction plus one palm share the same summed hand force admission, never duplicate a hand")

func run()->void:
	var one:Dictionary=await physical_press()
	var two:Dictionary=await physical_press(true)
	await physical_press(false,true)
	await invalid_contacts()
	await ownership_and_targets()
	await mixed_support()
	check(no_early_force and caps,"all physics ticks preserve zero pending force and existing shared caps")
	FileAccess.open("res://builds/palm_compression_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify({"physics_hz":hz,"checks":checks,"failures":failures,"one_palm_rise":one.rise,"two_palm_rise":two.rise,"trials":trials},"\t"))
	fixture.queue_free()
	await physics_frame
	print("PALM COMPRESSION RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
