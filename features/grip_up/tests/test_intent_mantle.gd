extends "res://features/grip_up/tests/test_intent_integration.gd"
## M6 capability experiment. Completion is actual platform ground and free-hand
## walking, never the detector saying AVAILABLE or ATTEMPTING.
var observations:Array=[]

func trial(label:String,feet:bool,enabled:bool=true,adverse:String="")->Dictionary:
	await fresh(11,feet)
	app.won=false
	app.controller.intent_auto_mantle_enabled=enabled
	app._set_distant_targeting(true)
	var top_height:=2.10 if adverse=="high" else 1.25
	app.level.top_y=top_height
	app.level.platform.get_child(0).shape.size.y=top_height-.25
	app.level.platform.get_child(1).mesh.size.y=top_height-.25
	app.level.platform.position.y=(top_height+.25)*.5
	app.level.transfer_points[0].y=top_height-.05
	app.level.transfer_points[1].y=top_height-.05
	if adverse=="narrow":
		var platform=app.level.platform
		platform.get_child(0).shape.size.z=.12
		platform.get_child(1).mesh.size.z=.12
		platform.position.z=-.06
	if adverse=="ceiling":
		app.level.box("Overhead obstruction",Vector3(0,2.50,-.60),Vector3(2.1,.20,1.4),Color.DIM_GRAY,false)
	await ticks(.1)
	check(await grip(0,app.level.transfer_points[0]),label+" actual finite left contact")
	check(await grip(1,app.level.transfer_points[1]),label+" actual finite right contact")
	await ticks(.25)
	var before:Transform3D=app.torso.global_transform
	var velocity:Vector3=app.torso.linear_velocity
	var spin:Vector3=app.torso.angular_velocity
	app.controller.set_traversal_input(Vector2(0,1),Vector3.RIGHT)
	check(app.torso.global_transform==before and app.torso.linear_velocity==velocity and app.torso.angular_velocity==spin,label+" intent setter never writes body pose or velocity")
	var initial:Vector3=app.torso.global_position
	var peak_y:float=initial.y
	var peak_tilt:=0.0
	var peak_assist:=0.0
	var peak_leg:=0.0
	var peak_force:=0.0
	var peak_mantle:=0.0
	var saw_top:=false
	var attempted:=false
	var saw_ground:=false
	var walk_completed:=false
	var walk_start:=Vector3.ZERO
	var no_ghost:=true
	var sample_rows:Array=[]
	Input.action_press("contract")
	for frame in 6*hz:
		await ticks(1.0/hz)
		var data:Dictionary=app.controller.telemetry()
		var ledge:Dictionary=data.get("ledge_transfer",{})
		peak_y=maxf(peak_y,app.torso.global_position.y)
		peak_tilt=maxf(peak_tilt,acos(clampf(app.torso.global_basis.y.dot(Vector3.UP),-1,1)))
		peak_force=maxf(peak_force,data.total_force)
		peak_leg=maxf(peak_leg,data.leg_force)
		peak_assist=maxf(peak_assist,Vector3(data.assist_torque).length())
		peak_mantle=maxf(peak_mantle,Vector3(ledge.get("applied_torque",Vector3.ZERO)).length())
		saw_top=saw_top or ledge.get("support_id",0)==app.level.platform.get_instance_id()
		attempted=attempted or ledge.get("status","")=="ATTEMPTING"
		no_ghost=no_ghost and (not app.controller._attached_ids().is_empty() or Vector3(data.assist_torque).length()<.000001)
		if app.ground_motor.grounded and app.ground_motor.support_body==app.level.platform:
			if not saw_ground:
				saw_ground=true
				button(0,false)
				button(1,false)
				walk_start=app.torso.global_position
			walk_completed=walk_completed or app.torso.global_position.slide(Vector3.UP).distance_to(walk_start.slide(Vector3.UP))>=.30
		if frame%maxi(1,hz/10)==0:
			sample_rows.append({"time":frame/float(hz),"position":app.torso.global_position,"rotation":app.torso.global_rotation,"force":data.total_force,"leg_force":data.leg_force,"assist":data.assist_torque,"grounded":app.ground_motor.grounded,"ground_support":app.ground_motor.support_body.get_instance_id() if is_instance_valid(app.ground_motor.support_body) else 0,"ledge":ledge})
	Input.action_release("contract")
	await ticks(.5)
	var result:Dictionary={"label":label,"top_height":top_height,"feet":feet,"enabled":enabled,"adverse":adverse,"initial":initial,"final":app.torso.global_position,"peak_y":peak_y,"height_gain":peak_y-initial.y,"peak_tilt_rad":peak_tilt,"peak_hand_force":peak_force,"peak_leg_force":peak_leg,"peak_assist":peak_assist,"peak_mantle":peak_mantle,"top_identified":saw_top,"attempted":attempted,"actual_platform_ground":saw_ground,"actual_hands_free_walk_30cm":walk_completed,"physical_completion":saw_ground and walk_completed,"final_detector":app.controller.telemetry().get("ledge_transfer",{}),"samples":sample_rows}
	check(peak_force<=360.001 and peak_leg<=180.001 and peak_assist<=20.001 and peak_mantle<=8.001,label+" unchanged finite budgets incl shared reacted mantle request")
	check(no_ghost,label+" no torso attitude effort without actual attached support")
	if adverse in ["narrow","ceiling"]:check(not attempted,label+" rejects inadequate bearing top or occupied upright destination")
	if not enabled:check(peak_mantle==0,label+" featureOFF has zero mantle contribution")
	observations.append(result)
	print("MANTLE_CAPABILITY ",JSON.stringify({"label":label,"top":saw_top,"attempted":attempted,"ground":saw_ground,"walk":walk_completed,"peak_y":peak_y,"peak_tilt":peak_tilt}))
	return result

func dynamic_pair()->void:
	await fresh(11,false)
	app.controller.intent_auto_mantle_enabled=true
	app._set_distant_targeting(true)
	app.torso.gravity_scale=0
	app.torso.linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
	app.torso.angular_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
	app.torso.linear_damp=0
	app.torso.angular_damp=0
	var old=app.level.platform
	var platform:=RigidBody3D.new()
	platform.transform=old.transform
	platform.mass=30
	platform.gravity_scale=0
	platform.linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
	platform.angular_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
	platform.linear_damp=0
	platform.angular_damp=0
	platform.collision_layer=old.collision_layer
	platform.collision_mask=old.collision_mask
	platform.set_meta("grippable",true)
	platform.set_meta("grip_load_limit",460.0)
	for child in old.get_children():platform.add_child(child.duplicate())
	app.level.add_child(platform)
	app.level.platform=platform
	app.level.holds.clear()
	app.level.holds.append(platform)
	old.queue_free()
	app.level.get_node("Safe base").queue_free()
	for foot in app.level.footholds:foot.queue_free()
	app.level.footholds.clear()
	await ticks(.1)
	check(await grip(0,app.level.transfer_points[0]) and await grip(1,app.level.transfer_points[1]),"real free30kg dynamic ledge acquires two finite grips")
	await ticks(.15)
	var before:Vector3=app.torso.linear_velocity*app.torso.mass+platform.linear_velocity*platform.mass
	var peak_residual:=0.0
	var any_mantle:=false
	var moment_pair:=0.0
	Input.action_press("contract")
	for frame in int(.25*hz):
		await ticks(1.0/hz)
		var data:Dictionary=app.controller.telemetry()
		var residual:=Vector3.ZERO
		for id in 2:
			var hand:Dictionary=app.controller.hands[id]
			residual+=(app.controller.get_shoulder_world(id)-hand.anchor_world).cross(Vector3(hand.force))
		moment_pair=maxf(moment_pair,residual.length())
		any_mantle=any_mantle or Vector3(data.ledge_transfer.applied_torque).length()>.01
		peak_residual=maxf(peak_residual,(app.torso.linear_velocity*app.torso.mass+platform.linear_velocity*platform.mass-before).length())
	Input.action_release("contract")
	check(any_mantle and platform.angular_velocity.length()>.001,"finite mantle attitude produces actual dynamic support angular reaction")
	check(peak_residual<.001,"unforced free pair preserves total linear momentum with actual mantle effort")
	check(moment_pair<.001,"collinear hand force pairs have negligible net angular wrench; attitude reaction is paired by the existing allocator")
	observations.append({"label":"free_dynamic_pair","linear_momentum_residual":peak_residual,"hand_wrench_residual":moment_pair,"support_spin":platform.angular_velocity,"scope":"isolated zero-gravity zero-damping fixture; inertia-integration angular momentum not asserted"})
	app.controller.release_grip(0)
	app.controller.release_grip(1)
	await ticks(1.0/hz)
	check(Vector3(app.controller.telemetry().ledge_transfer.applied_torque)==Vector3.ZERO,"last actual support lost immediately removes all mantle torque")

func run()->void:
	await trial("hands_OFF",false,false)
	var hands:Dictionary=await trial("hands_ON",false,true)
	var feet:Dictionary=await trial("hands_feet_ON",true,true)
	check(hands.top_identified and hands.attempted and feet.top_identified and feet.attempted,"real wide top is identified and deliberately attempted with actual hand support")
	await trial("narrow_lip",true,true,"narrow")
	await trial("occupied_top",true,true,"ceiling")
	await trial("high_edge_hands",false,true,"high")
	await trial("high_edge_feet",true,true,"high")
	await dynamic_pair()
	check(budgets_ok,"all steps preserve hand/leg and same-tick common ground+climb moment caps")
	FileAccess.open("res://builds/intent_mantle_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify({"physics_hz":hz,"checks":checks,"failures":failures,"completion_gate":"actual platform ground, hands released, actual30cm walk","hands_only_completion":hands.physical_completion,"feet_completion":feet.physical_completion,"trials":observations},"\t"))
	app.queue_free()
	await ticks(.03)
	print("INTENT MANTLE RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
