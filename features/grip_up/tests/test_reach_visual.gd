extends "res://features/grip_up/tests/test_biped_visual.gd"
## A grounded pending hand must visibly extend while legs retain their gait.
var hz:=120
var observations:Array=[]

func run() -> void:
	hz=Engine.physics_ticks_per_second
	for profile in [3,4]:
		app=Lab.new()
		root.add_child(app)
		current_scene=app
		app._open_intent_arena(6,false)
		app._set_input_profile(profile)
		app._set_distant_targeting(true)
		app.biped.hand_pose.modification_processed.connect(sample)
		app.won=true
		await ticks(int(.5*hz))
		var shoulder:Vector3=app.controller.get_shoulder_world(0)
		var wall:=StaticBody3D.new()
		wall.position=shoulder+Vector3(0,0,1.5)
		wall.collision_layer=2
		var collision:=CollisionShape3D.new()
		var box:=BoxShape3D.new()
		box.size=Vector3(4,4,.1)
		collision.shape=box
		wall.add_child(collision)
		app.add_child(wall)
		# Even the nearest surface is beyond R, so neither mode can acquire it.
		var point:Vector3=wall.global_position+Vector3(0,0,-.05)
		Input.action_press("grip_left")
		check(app.controller.request_held_grip(0,wall,point,Vector3.FORWARD),"profile%d accepts an unreachable real surface as a finite reach request" % profile)
		await ticks(int(.6*hz))
		app.biped._update_ground_animation(.1)
		app.biped._update_targets()
		app.biped.skeleton.advance(.1)
		var endpoint:Vector3=app.controller.get_hand_world(0)
		var physical_shoulder:Vector3=app.controller.get_shoulder_world(0)
		var distance:float=physical_shoulder.distance_to(endpoint)
		check(app.ground_motor.grounded and app.controller.get_hand_state(0)=="REACHING" and app.controller.get_arm_force(0)==Vector3.ZERO,"profile%d keeps grounded pending hand unladen" % profile)
		check(absf(distance-app.controller.get_max_reach())<.001,"profile%d hand reaches its complete anatomical extension" % profile)
		check(app.biped.ik.influence<.001 and app.biped.free_aim_ik.influence>.999,"profile%d grounded leg gait and reaching arm IK coexist" % profile)
		var wrist_world:Vector3=measured[0].wrist
		var wrist_error:float=wrist_world.distance_to(app.biped.targets[0].global_position)
		var visual_radius:float=Vector3(measured[0].shoulder).distance_to(wrist_world)
		var visual_length:float=measured[0].upper+measured[0].lower
		var direction:Vector3=(wrist_world-Vector3(measured[0].shoulder)).normalized()
		var desired:Vector3=(app.biped.targets[0].global_position-Vector3(measured[0].shoulder)).normalized()
		check(absf(visual_radius-visual_length)<.002 and direction.dot(desired)>.999,"profile%d rendered arm fully extends toward the request without stretching its bones" % profile)
		var row:={"profile":profile,"hand_radius":distance,"reach":app.controller.get_max_reach(),"visual_radius":visual_radius,"bone_length":visual_length,"wrist_error":wrist_error}
		observations.append(row)
		print("REACH_VISUAL_MEASURE ",JSON.stringify(row))
		app.controller.set_hand_held(0,false)
		Input.action_release("grip_left")
		await ticks(int(.4*hz))
		app.biped._update_ground_animation(.1)
		check(app.biped.free_aim_ik.influence<.001,"profile%d mouse-up restores ordinary grounded arms" % profile)
		app.queue_free()
		await ticks(3)
	FileAccess.open("res://builds/reach_visual_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify({"physics_hz":hz,"checks":checks,"failures":failures,"trials":observations},"\t"))
	print("REACH VISUAL RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
