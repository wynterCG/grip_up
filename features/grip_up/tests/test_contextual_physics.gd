extends "res://features/grip_up/tests/test_drag_swing_physics.gd"
## New contextual profile tests. Existing profile0/1 suites remain unchanged.

func contextual_ticks(count: int, effort := Vector2.ZERO) -> void:
	for frame in count:
		controller.set_contextual_effort(effort,Vector3.RIGHT)
		await tick()

func pull_and_retain(dual: bool) -> void:
	await setup(dual,Vector3.ZERO,false,2)
	var initial:=body.position.y
	var start: float=controller.hands[0].rest_length
	await contextual_ticks(hz,Vector2(0,1))
	var high:=body.position.y
	var contracted: float=controller.hands[0].rest_length
	print("CONTEXT PULL dual=",dual," rise=",high-initial," target=",contracted," actual=",controller.hands[0].actual_length)
	check(controller.get_hand_state(0)=="ATTACHED" and high>initial+.15 and contracted<start-.15,"transient positive effort produces actual bounded ascent; dual=%s" % dual)
	await contextual_ticks(hz)
	var held_height:=body.position.y
	var held_target: float=controller.hands[0].rest_length
	check(held_height>initial+.13 and absf(held_target-contracted)<.035,"achieved contracted posture persists after gesture ends; dual=%s" % dual)
	await contextual_ticks(hz,Vector2(0,-1))
	print("CONTEXT RETAIN dual=",dual," high=",high," held=",held_height," reverse=",body.position.y," target_delta=",controller.hands[0].rest_length-held_target)
	check(controller.hands[0].rest_length>held_target+.15 and body.position.y<held_height-.15 and controller.get_hand_state(0)=="ATTACHED","negative contextual effort actively extends and physically lowers; dual=%s" % dual)
	var lowered:=body.position.y
	var extended: float=controller.hands[0].rest_length
	await contextual_ticks(hz)
	print("CONTEXT EXTENDED SETTLE dual=",dual," dy=",body.position.y-lowered," target_delta=",controller.hands[0].rest_length-extended," state=",controller.get_hand_state(0))
	check(absf(body.position.y-lowered)<.05 and absf(controller.hands[0].rest_length-extended)<.035,"achieved extended posture persists after gesture ends; dual=%s" % dual)
	var quiet_target: float=controller.hands[0].rest_length
	var quiet_height:=body.position.y
	await contextual_ticks(hz*2)
	check(absf(controller.hands[0].rest_length-quiet_target)<.003 and absf(body.position.y-quiet_height)<.05 and controller.get_hand_state(0)=="ATTACHED","extended suspension retains target for2s without passive drift; dual=%s" % dual)
	controller.set_swing_intent(Vector3.ZERO,Vector3.FORWARD)
	for frame in hz/2:
		controller.set_contextual_effort(Vector2.ZERO,Vector3.FORWARD)
		await tick()
	check(absf(controller.hands[0].rest_length-quiet_target)<.003,"camera-only reference change preserves extended posture; dual=%s" % dual)
	await contextual_ticks(hz,Vector2(0,-1))
	await contextual_ticks(hz)
	check(controller.get_hand_state(0)=="ATTACHED" and controller.hands[0].rest_length>.58 and controller.hands[0].actual_length<=.6601,"full contextual extension remains inside anatomical cap; dual=%s" % dual)
	check(not controller.queue_arm_length_delta(0,.4),"contextual profile refuses old pixel/displacement arm API")
	await clear()

func zero_and_reverse() -> void:
	await setup(true,Vector3.ZERO,false,2)
	var left: float=controller.hands[0].rest_length
	var right: float=controller.hands[1].rest_length
	var height:=body.position.y
	await contextual_ticks(hz,Vector2(0,-1))
	check(controller.hands[0].rest_length>left+.05 and controller.hands[1].rest_length>right+.05 and body.position.y<height-.05,"negative vertical effort extends both real arm targets and lowers torso")
	await contextual_ticks(hz)
	left=controller.hands[0].rest_length
	await contextual_ticks(hz/2)
	check(absf(controller.hands[0].rest_length-left)<.00001,"no gesture holds actuator target rather than tracking passive motion")
	controller.set_contextual_effort(Vector2(NAN,1),Vector3.RIGHT)
	await tick()
	check(controller.telemetry().contextual_requested==Vector2.ZERO,"nonfinite contextual request is rejected")
	var pose:=body.global_transform
	var velocity:=body.linear_velocity
	var spin:=body.angular_velocity
	controller.set_contextual_effort(Vector2.ONE,Vector3.RIGHT)
	check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"effort setter never writes body pose or momentum")
	await contextual_ticks(int(.25*hz),Vector2(1,0))
	controller.set_contextual_effort(Vector2.ZERO,Vector3.FORWARD)
	await tick()
	check(Vector3(controller.telemetry().contextual_world_effort).dot(Vector3.RIGHT)>.5 and absf(Vector3(controller.telemetry().contextual_world_effort).z)<.00001,"camera rotation cannot redirect the decaying effort of a completed gesture")
	await clear()

func blocked_extension_no_windup() -> void:
	await setup(true,Vector3.ZERO,false,2)
	var initial:=body.position.y
	var rest: float=controller.hands[0].rest_length
	var floor_body:=StaticBody3D.new()
	floor_body.position=body.position-Vector3(0,.905,0)
	floor_body.collision_layer=1
	floor_body.collision_mask=4
	var shape:=BoxShape3D.new()
	shape.size=Vector3(3,.1,3)
	var collision:=CollisionShape3D.new()
	collision.shape=shape
	floor_body.add_child(collision)
	world.add_child(floor_body)
	# A floor alone still allows real lateral swing, which legitimately changes
	# arm geometry. Narrow physical side walls isolate an actually blocked pose.
	for offset in [Vector3(.26,0,0),Vector3(-.26,0,0),Vector3(0,0,.26),Vector3(0,0,-.26)]:
		var wall:=StaticBody3D.new()
		wall.position=body.position+offset
		wall.collision_layer=1
		wall.collision_mask=4
		var wall_shape:=BoxShape3D.new()
		wall_shape.size=Vector3(.1,1.8,1) if absf(offset.x)>0 else Vector3(1,1.8,.1)
		var wall_collision:=CollisionShape3D.new()
		wall_collision.shape=wall_shape
		wall.add_child(wall_collision)
		world.add_child(wall)
	await contextual_ticks(hz,Vector2(0,-1))
	var early: float=controller.hands[0].rest_length
	await contextual_ticks(hz,Vector2(0,-1))
	var late: float=controller.hands[0].rest_length
	check(absf(body.position.y-initial)<.04 and absf(late-early)<.025,"real floor blocks lowering while extension target remains geometry bounded")
	await contextual_ticks(hz)
	print("CONTEXT BLOCKED EXTEND initialrest=",rest," late=",late," held=",controller.hands[0].rest_length," actual=",controller.hands[0].actual_length," dy=",body.position.y-initial)
	check(controller.hands[0].rest_length<late-.03 and controller.hands[0].rest_length<rest+.04,"unachieved extension is not stored as a future drop")
	await clear()

func free_hand_aim() -> void:
	await setup(false,Vector3.ZERO,false,2)
	controller.release_grip(0)
	body.gravity_scale=0
	await tick()
	check(not controller.set_free_hand_target(8,Vector3.ZERO) and not controller.set_free_hand_target(0,Vector3(INF,0,0)),"invalid free hand targets rejected")
	var finite:=true
	for frame in hz/2:
		var shoulder: Vector3=controller.get_shoulder_world(0)
		var before: Vector3=controller.get_hand_world(0)
		controller.set_free_hand_target(0,shoulder+Vector3(-.2,.10,-.25))
		controller.set_contextual_effort(Vector2.ONE,Vector3.RIGHT)
		await tick()
		finite=finite and before.distance_to(controller.get_hand_world(0))<=4.0/hz+.0001
	check(finite and controller.get_hand_world(0).distance_to(controller.get_shoulder_world(0))<=controller.get_max_reach()+.0001,"virtual FREE endpoint follows anatomical target at finite4m/s")
	check(controller.telemetry().total_force==0 and controller.telemetry().assist_torque.length()==0 and controller.telemetry().contextual_filtered==Vector2.ZERO,"free-hand aim and effort supply no air force or stored effort")
	var shoulder: Vector3=controller.get_shoulder_world(0)
	var target: Vector3=shoulder+Vector3(0,0,-1.5)
	controller.set_free_hand_target(0,target)
	await contextual_ticks(hz/2)
	check(controller.get_hand_world(0).distance_to(controller.get_shoulder_world(0))<=controller.get_max_reach()+.0001,"distant free-hand request clamps to existing anatomical reach")
	controller.clear_free_hand_targets()
	await ticks(hz/2)
	var wall:=StaticBody3D.new()
	wall.position=controller.get_shoulder_world(0)+Vector3(0,0,-.25)
	wall.collision_layer=1
	var shape:=BoxShape3D.new()
	shape.size=Vector3(2,2,.05)
	var collision:=CollisionShape3D.new()
	collision.shape=shape
	wall.add_child(collision)
	world.add_child(wall)
	await tick()
	for frame in hz/2:
		controller.set_free_hand_target(0,controller.get_shoulder_world(0)+Vector3(0,0,-.6))
		await tick()
	check(controller.get_hand_world(0).z>wall.position.z+.025,"FREE target cannot drive endpoint through a wall")
	controller.reset_state()
	check(controller._free_hand_targets.is_empty() and controller.telemetry().is_empty(),"reset clears virtual targets and contextual telemetry")
	await clear()

func contextual_direction(effort: Vector2, swing: Vector3, dynamic:=false) -> Dictionary:
	await setup(false,Vector3.ZERO,dynamic,2)
	var start:=body.linear_velocity
	for frame in int(.45*hz):
		controller.set_contextual_effort(effort,Vector3.RIGHT)
		controller.set_swing_intent(swing,Vector3.RIGHT)
		await tick()
	var result: Dictionary={"dv":body.linear_velocity-start,"retained":controller.get_hand_state(0)=="ATTACHED"}
	await clear()
	return result

func lateral_and_wasd() -> void:
	var neutral: Dictionary=await contextual_direction(Vector2.ZERO,Vector3.ZERO)
	var right: Dictionary=await contextual_direction(Vector2(1,0),Vector3.ZERO)
	var left: Dictionary=await contextual_direction(Vector2(-1,0),Vector3.ZERO)
	var depth: Dictionary=await contextual_direction(Vector2.ZERO,Vector3.FORWARD)
	check(right.retained and Vector3(right.dv).x>Vector3(neutral.dv).x+.05,"contextual lateral effort gives bounded supported rightward momentum")
	check(left.retained and Vector3(left.dv).x<Vector3(neutral.dv).x-.05,"contextual effort can reverse supported lateral direction")
	check(depth.retained and Vector3(depth.dv).z<Vector3(neutral.dv).z-.05,"existing WASD depth swing remains active in contextual profile")
	await setup(true,Vector3.ZERO,true,2,true)
	var before:=momentum()
	await contextual_ticks(int(.4*hz),Vector2(.5,.8))
	var after:=momentum()
	check(Vector3(after.linear).distance_to(before.linear)<.001 and Vector3(after.angular).distance_to(before.angular)<.01,"contextual pull and swing retain exact opposite dynamic beam reactions")
	await clear()

func blocked_no_windup() -> void:
	await setup(true,Vector3.ZERO,false,2)
	var actual: float=controller.hands[0].actual_length
	var ceiling:=StaticBody3D.new()
	ceiling.position=body.position+Vector3(0,.905,0)
	ceiling.collision_layer=1
	ceiling.collision_mask=4
	var shape:=BoxShape3D.new()
	shape.size=Vector3(.25,.1,.45)
	var collision:=CollisionShape3D.new()
	collision.shape=shape
	ceiling.add_child(collision)
	world.add_child(ceiling)
	var initial:=body.position.y
	await contextual_ticks(hz,Vector2(0,1))
	var early: float=controller.hands[0].rest_length
	await contextual_ticks(hz,Vector2(0,1))
	var target: float=controller.hands[0].rest_length
	print("CONTEXT BLOCKED rise=",body.position.y-initial," initial_actual=",actual," early=",early," late=",target," actual=",controller.hands[0].actual_length)
	check(body.position.y<initial+.06 and target>actual-.14 and absf(target-early)<.025,"real ceiling prevents progression and effort does not wind target toward minimum")
	await contextual_ticks(hz)
	check(controller.hands[0].rest_length>target+.03,"unachieved blocked pull request relaxes instead of becoming stored contraction")
	await clear()

func free_target_and_transfer() -> void:
	await setup(false,Vector3.ZERO,false,2)
	var shoulder: Vector3=controller.get_shoulder_world(1)
	check(controller.set_free_hand_target(1,shoulder+Vector3(.25,0,.1)),"unattached second hand accepts virtual aim")
	var point: Vector3=shoulder+Vector3(0,.43,-.08)
	var support:=StaticBody3D.new()
	support.position=point+Vector3(0,.025,0)
	support.collision_layer=2
	var shape:=BoxShape3D.new()
	shape.size=Vector3(.08,.05,.08)
	var collision:=CollisionShape3D.new()
	collision.shape=shape
	support.add_child(collision)
	world.add_child(support)
	await tick()
	check(controller.request_grip(1,support,point,Vector3.DOWN),"virtual free hand can begin real surface reach")
	check(not controller.set_free_hand_target(1,point+Vector3.RIGHT*.2) and not controller._free_hand_targets.has(1),"REACHING locks its selected surface and clears free aim override")
	var pose:=body.global_transform
	var velocity:=body.linear_velocity
	var spin:=body.angular_velocity
	controller.set_contextual_effort(Vector2(0,1),Vector3.RIGHT)
	check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"new grip and effort request add no instantaneous catch impulse")
	for frame in hz:
		controller.set_contextual_effort(Vector2(0,.4),Vector3.RIGHT)
		await tick()
		if controller.get_hand_state(1)=="ATTACHED":
			break
	check(controller.get_hand_state(1)=="ATTACHED" and controller.get_hand_state(0)=="ATTACHED","contextual supporting effort continues through finite second-hand capture")
	controller.release_grip(0)
	var retained: float=controller.hands[1].rest_length
	await contextual_ticks(hz/2)
	check(controller.get_hand_state(1)=="ATTACHED" and controller.hands[1].rest_length<retained+.035,"surviving hand retains its physically reached posture after transfer")
	await clear()

func rounded_surface_departure() -> void:
	await setup(false,Vector3.ZERO,false,2)
	var shoulder: Vector3=controller.get_shoulder_world(1)
	var support:=StaticBody3D.new()
	support.position=shoulder+Vector3(.049,.334,-.145)
	support.collision_layer=2
	var mesh:=SphereMesh.new()
	mesh.radius=.09
	mesh.height=.12
	mesh.radial_segments=16
	mesh.rings=8
	var vertices:=PackedVector3Array()
	for vertex in mesh.get_mesh_arrays()[Mesh.ARRAY_VERTEX]:
		vertices.append(vertex*Vector3(1,1,.55))
	var shape:=ConvexPolygonShape3D.new()
	shape.points=vertices
	var collision:=CollisionShape3D.new()
	collision.shape=shape
	support.add_child(collision)
	world.add_child(support)
	var free_point: Vector3=shoulder+Vector3(-.046,.294,-.166)
	for frame in int(.3*hz):
		controller.set_free_hand_target(1,free_point)
		await tick()
	var query:=PhysicsRayQueryParameters3D.create(support.position+Vector3(0,0,.2),support.position)
	query.exclude=[body.get_rid()]
	var contact: Dictionary=body.get_world_3d().direct_space_state.intersect_ray(query)
	check(not contact.is_empty() and contact.collider==support,"rounded transfer fixture uses an actual queried front surface")
	var approach: Vector3=contact.position+contact.normal*controller.tuning.hand_surface_approach_distance
	var direct:=PhysicsRayQueryParameters3D.create(controller.get_hand_world(1),approach)
	direct.exclude=[body.get_rid()]
	direct.hit_from_inside=true
	var obstruction: Dictionary=body.get_world_3d().direct_space_state.intersect_ray(direct)
	check(not obstruction.is_empty() and obstruction.collider==support,"original FREE-to-front diagonal genuinely intersects rounded flank")
	var accepted: bool=controller.request_grip(1,support,contact.position,contact.normal)
	check(accepted and controller.hands[1].departing_surface and controller.hands[1].strict_departure_sweep,"contextual transfer selects a strictly swept folded-arm clearance leg")
	var bounded:=true
	var retained_left:=true
	for frame in int(.6*hz):
		var previous: Vector3=controller.get_hand_world(1)
		await tick()
		bounded=bounded and previous.distance_to(controller.get_hand_world(1))<=4.0/hz+.0001
		retained_left=retained_left and controller.get_hand_state(0)=="ATTACHED"
		if controller.get_hand_state(1)=="ATTACHED":
			break
	check(controller.get_hand_state(1)=="ATTACHED" and bounded and retained_left,"finite swept rounded-surface transfer catches while supporting arm remains attached")
	await clear()

func run() -> void:
	world=Node3D.new()
	root.add_child(world)
	await pull_and_retain(false)
	await pull_and_retain(true)
	await zero_and_reverse()
	await free_hand_aim()
	await lateral_and_wasd()
	await blocked_no_windup()
	await blocked_extension_no_windup()
	await free_target_and_transfer()
	await rounded_surface_departure()
	check(budgets,"all contextual trials obey360N hands20Nm assist150Nm combined")
	check(finite_reach,"contextual catches keep existing finite hand speed")
	print("CONTEXTUAL PHYSICS RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
