extends "res://features/grip_up/tests/test_hybrid_motor.gd"
## Isolated exact-engine experiment, not an authorized production exception.
func run()->void:
	initial_rotation=Vector3(-.085,.217,.106)
	await setup()
	body.lock_rotation=true
	obstacle(Vector3(0,2,.68),Vector3(3,4,.2))
	for frame in int(.5*hz):
		body.apply_central_force(Vector3(0,0,-200))
		await physics_frame
	motor.refresh_start_contacts()
	var initial:Dictionary=motor.start_contact_audit.duplicate(true)
	body.freeze_mode=RigidBody3D.FREEZE_MODE_KINEMATIC
	body.freeze=true
	var rows:Array=[]
	for frame in 8:
		var before:Vector3=body.global_position
		var requested:=Vector3(0,0,.003)
		var test_hit:=KinematicCollision3D.new()
		var test_collision:bool=body.test_move(body.global_transform,requested,test_hit,.0001,true,4)
		var hit:KinematicCollision3D=body.move_and_collide(requested,false,.0001,false,4)
		motor.refresh_start_contacts()
		rows.append({"requested":requested,"actual":body.global_position-before,"collision":hit!=null,"test_collision":test_collision,"test_travel":test_hit.get_travel() if test_collision else Vector3.ZERO,"depth":motor.start_contact_audit.maximum_query_depth,"body_pose":body.global_transform})
		await physics_frame
	FileAccess.open("res://builds/hybrid_native_departure_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify({"physics_hz":hz,"initial":initial,"steps":rows},"\t"))
	print("DEPARTURE ",initial," STEPS ",rows)
	world.queue_free()
	await physics_frame
	print("HYBRID NATIVE DEPARTURE RESULTS: 1 checks, 0 failures")
	quit(0)
