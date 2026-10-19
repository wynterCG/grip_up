extends "res://features/grip_up/tests/test_hybrid_mantle.gd"
var sequence_rows:Array=[]

func wait_ground()->bool:
	for frame in 4*hz:
		await ticks(1.0/hz)
		if app.hybrid_mantle.state in ["DYNAMIC_GROUNDED","BLOCKED_RECOVERY"]:break
	return app.hybrid_mantle.state=="DYNAMIC_GROUNDED"

func walk_until_complete()->void:
	Input.action_press("contract")
	for frame in hz:
		await ticks(1.0/hz)
		if app.hybrid_mantle.completed:break
	Input.action_release("contract")

func varied(offset:int)->void:
	await fresh(0,false)
	app._open_hybrid_mantle(0)
	await ticks(.4)
	# Create a different real approach with the ordinary ground motor.
	Input.action_press("bias_left" if offset<0 else "bias_right")
	await ticks(.10)
	Input.action_release("bias_left" if offset<0 else "bias_right")
	Input.action_press("contract")
	await ticks(.06)
	Input.action_release("contract")
	await ticks(.20)
	var start:Transform3D=app.torso.global_transform
	check(await grip(0,app.level.transfer_points[0]) and await grip(1,app.level.transfer_points[1]),"F3 varied actual ground approach acquires valid hands")
	Input.action_press("contract")
	for frame in 5*hz:
		await ticks(1.0/hz)
		if app.hybrid_mantle.commits>0:break
	for id in 2:button(id,false)
	Input.action_release("contract")
	check(await wait_ground(),"F3 varied start reaches actual dynamic top ground")
	await walk_until_complete()
	check(app.hybrid_mantle.completed and app.hybrid_mantle.data.standing_collision_clear,"F3 varied start completes standing and30cm walking")
	sequence_rows.append({"case":"VARIED_LEFT" if offset<0 else "VARIED_RIGHT","start":start,"final":app.hybrid_mantle.data.duplicate(true)})

func two_ledges()->void:
	await fresh(0,false)
	app._open_hybrid_mantle(6)
	await ticks(.4)
	check(await grip(0,app.level.transfer_points[0]) and await grip(1,app.level.transfer_points[1]),"F9 first ledge earns initial real grips")
	Input.action_press("contract")
	for frame in 5*hz:
		await ticks(1.0/hz)
		if app.hybrid_mantle.commits>0:break
	for id in 2:button(id,false)
	Input.action_release("contract")
	check(await wait_ground(),"F9 first top-out restores actual dynamic support")
	await walk_until_complete()
	check(app.hybrid_mantle.completed,"F9 first30cm normal walk completed")
	var first:Dictionary=app.hybrid_mantle.data.duplicate(true)
	# Walk across the first real deck; no restart or body initialization.
	Input.action_press("contract")
	for frame in 2*hz:
		await ticks(1.0/hz)
		if app.torso.position.z< -2.33:break
	Input.action_release("contract")
	await ticks(.15)
	var left_target:=Vector3(app.controller.get_shoulder_world(0).x,app.level.transfer_points[4].y,-2.8)
	var left:bool=await transfer(0,left_target)
	var right_target:=Vector3(app.controller.get_shoulder_world(1).x,app.level.transfer_points[5].y,-2.8)
	check(left and await transfer(1,right_target),"F9 second ledge reached with fresh physical hand contacts")
	Input.action_press("contract")
	for frame in 5*hz:
		await ticks(1.0/hz)
		if app.hybrid_mantle.commits>=2:break
	for id in 2:button(id,false)
	Input.action_release("contract")
	check(await wait_ground(),"F9 second top-out restores dynamic support without resetting body")
	await walk_until_complete()
	check(app.hybrid_mantle.commits==2 and app.hybrid_mantle.restores==2 and app.hybrid_mantle.completed,"F9 two consecutive full top-outs with normal walking between")
	sequence_rows.append({"case":"TWO_CONSECUTIVE","first":first,"final":app.hybrid_mantle.data.duplicate(true),"events":app.hybrid_mantle.events.duplicate(true)})

func run()->void:
	await varied(-1)
	await varied(1)
	await two_ledges()
	FileAccess.open("res://builds/hybrid_sequence_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"physics_hz":hz,"runs":sequence_rows,"provenance":"Ordinary input including actual ground approaches and consecutive decks, not human evaluation"},"\t"))
	app.queue_free()
	await ticks(.03)
	print("HYBRID SEQUENCE RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
