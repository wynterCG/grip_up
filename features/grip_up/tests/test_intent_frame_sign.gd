extends "res://features/grip_up/tests/test_drag_swing_physics.gd"
const SupportFrame = preload("res://features/grip_up/scripts/locomotion_support_frame.gd")

func signs() -> void:
	var material := StaticBody3D.new()
	world.add_child(material)
	for normal in [Vector3.UP,Vector3.DOWN]:
		for yaw in [0.0,PI*.5,PI]:
			var frame = SupportFrame.new()
			var camera: Vector3 = Basis(Vector3.UP,yaw)*Vector3.RIGHT
			var contacts: Array[Dictionary] = [{"id":material.get_instance_id(),"support":material,"normal":normal,"weight":1.0,"kind":"hand"}]
			var data: Dictionary = frame.update(contacts,camera,1.0/hz)
			check(Vector3(data.right).dot(camera)>.9999 and Basis(data.right,data.up,data.normal).determinant()>.9999,"first horizontal normal%s yaw%.2f gives camera-right A/D with valid handedness" % [normal,yaw])
			var fixed: Vector3 = data.right
			var stable := true
			for index in 24:
				data = frame.update(contacts,Basis(Vector3.UP,index*TAU/24.0)*camera,1.0/hz)
				stable = stable and Vector3(data.right).distance_to(fixed)<.00001
			check(stable,"established horizontal frame ignores camera-only orbit normal%s yaw%.2f" % [normal,yaw])
	material.queue_free()
	await ticks(2)

func horizontal_trial(command: float) -> Dictionary:
	await setup(false,Vector3.ZERO,false,4,true)
	controller.intent_climb_enabled = true
	var start := body.global_position
	controller.set_traversal_input(Vector2(command,0),Vector3.RIGHT)
	await ticks(int(.4*hz))
	var result := {"command":command,"dx":body.global_position.x-start.x,"retained":controller.get_hand_state(0)=="ATTACHED","right":controller.telemetry().intent_locomotion.frame.right}
	check(result.retained and budgets,"first horizontal-grip command%s retains real grip and force/moment limits" % command)
	await clear()
	return result

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	await signs()
	var neutral: Dictionary = await horizontal_trial(0.0)
	var right: Dictionary = await horizontal_trial(1.0)
	check(Vector3(right.right).dot(Vector3.RIGHT)>.99 and right.dx>neutral.dx+.01,"D on actual first underside grip moves body right relative to the matched neutral trajectory")
	FileAccess.open("res://builds/intent_frame_sign_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify({"hz":hz,"checks":checks,"failures":failures,"neutral":neutral,"right":right},"\t"))
	print("FRAME_SIGN_MEASURE ",JSON.stringify({"hz":hz,"neutral":neutral,"right":right}))
	print("INTENT FRAME SIGN RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
