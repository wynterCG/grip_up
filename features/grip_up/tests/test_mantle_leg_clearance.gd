extends SceneTree
## Independent M2 fixture. Initial placements only; no simulated body pose,
## velocity, force or impulse is assigned by the adaptive collision module.
const Adaptive=preload("res://features/grip_up/scripts/adaptive_leg_collision.gd")
const Tuning=preload("res://features/grip_up/resources/biped_tuning.gd")
var hz:=120
var passed:=0
var failed:=0
var world:Node3D
var body:RigidBody3D
var leg:CollisionShape3D
var sole:CollisionShape3D
var adaptive:RefCounted
var report:Dictionary={"stage":"M2_ISOLATED_COLLIDER_CLEARANCE","functional_mantle":false,"samples":[],"experiments":{}}

func _initialize()->void:
	if "--60hz" in OS.get_cmdline_user_args():hz=60
	Engine.physics_ticks_per_second=hz
	call_deferred("run")

func check(condition:bool,label:String)->void:
	if condition:passed+=1
	else:failed+=1
	print("PASS " if condition else "FAIL ",label)

func box(parent:Node3D,where:Vector3,size:Vector3,dynamic:bool=false)->PhysicsBody3D:
	var result:PhysicsBody3D=RigidBody3D.new() if dynamic else StaticBody3D.new()
	result.position=where
	result.collision_layer=1
	result.collision_mask=4
	if dynamic:
		result.mass=15
		result.gravity_scale=0
		result.can_sleep=false
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	result.add_child(collision)
	parent.add_child(result)
	return result

func fresh()->void:
	if is_instance_valid(world):
		world.queue_free()
		await process_frame
	world=Node3D.new()
	root.add_child(world)
	body=RigidBody3D.new()
	body.name="M2Same12kgBody"
	body.mass=12
	body.gravity_scale=0
	body.can_sleep=false
	body.continuous_cd=true
	body.max_contacts_reported=16
	body.contact_monitor=true
	body.collision_layer=4
	body.collision_mask=3
	body.center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass=Vector3.ZERO
	var tuning:=Tuning.new()
	for index in 2:
		var shape:=CapsuleShape3D.new()
		shape.height=tuning.torso_capsule_height if index==0 else tuning.leg_capsule_height
		shape.radius=tuning.torso_capsule_radius if index==0 else tuning.leg_capsule_radius
		var collision:=CollisionShape3D.new()
		collision.name="Torso" if index==0 else "LegacyLeg"
		collision.position.y=tuning.torso_capsule_center_y if index==0 else tuning.leg_capsule_center_y
		collision.shape=shape
		body.add_child(collision)
		if index==1:leg=collision
	var head:=CollisionShape3D.new()
	head.name="Head"
	var sphere:=SphereShape3D.new()
	sphere.radius=tuning.head_radius
	head.shape=sphere
	head.position.y=tuning.head_center_y
	body.add_child(head)
	sole=CollisionShape3D.new()
	sole.name="Sole"
	var foot:=BoxShape3D.new()
	foot.size=tuning.foot_base_size
	sole.shape=foot
	sole.position=tuning.foot_base_offset
	body.add_child(sole)
	world.add_child(body)
	adaptive=Adaptive.new()
	adaptive.configure(body,leg,sole,tuning)
	await physics_frame
	await physics_frame

func advance(seconds:float,enabled:bool=true,load:float=0.0)->Dictionary:
	var peak_speed:=0.0
	var peak_impulse:=0.0
	var peak_penetration:=0.0
	for index in int(ceil(seconds*hz)):
		await physics_frame
		var data:Dictionary=adaptive.step(1.0/hz,enabled,load)
		peak_speed=maxf(peak_speed,body.linear_velocity.length())
		peak_impulse=maxf(peak_impulse,data.contacts.get("peak_impulse_ns",0.0))
		var clearance:Dictionary=adaptive.clearance_diagnostics()
		peak_penetration=maxf(peak_penetration,clearance.max_penetration_estimate_m)
		if index%maxi(1,hz/10)==0:
			report.samples.append({"time":index/float(hz),"flex":adaptive.achieved_flex,"reason":adaptive.reason,"body":body.position,"foot":sole.position,"speed":body.linear_velocity.length(),"contacts":data.contacts,"clearance":clearance})
	return {"peak_speed":peak_speed,"peak_impulse_ns":peak_impulse,"peak_penetration_estimate_m":peak_penetration,"flex":adaptive.achieved_flex,"reason":adaptive.reason,"body":body.position,"telemetry":adaptive.telemetry(),"clearance":adaptive.clearance_diagnostics()}

func run()->void:
	await fresh()
	var original:Shape3D=leg.shape
	var original_count:int=body.get_child_count()
	adaptive.request_flex(1)
	await advance(.2,false)
	check(leg.shape==original and body.get_child_count()==original_count and sole.position.is_equal_approx(Vector3(0,-.8767,-.035)),"T05 flagOFF exact collider resources and transforms unchanged")
	check(body.mass==12 and body.inertia==Vector3.ZERO,"flagOFF mass and automatic inertia unchanged")
	# C0 records whole-body clearance without mutating production colliders.
	var c0:Array=[]
	for index in 11:c0.append(adaptive.audit_pose(index/10.0))
	report.experiments.c0_clearance=c0
	check(c0.all(func(item):return item.clear) and leg.shape==original,"C0 whole-body diagnostic poses clear without collider mutations")
	var initial_body:Transform3D=body.transform
	var initial_velocity:Vector3=body.linear_velocity
	var clear:Dictionary=await advance(1.7)
	report.experiments.clear_fold=clear
	check(adaptive.achieved_flex>.999,"C01 continuous physical proxies reach declared75deg hip150deg knee")
	check(sole.position.y-(-.8767)>.399 and sole.position.y-(-.8767)<.402,"C01 actual sole gains400mm clearance with full-size shin thigh and sole")
	check(body.transform.is_equal_approx(initial_body) and body.linear_velocity.is_equal_approx(initial_velocity),"clear-space collider motion writes no body pose or velocity and creates no drift")
	check(clear.peak_speed<.001 and clear.peak_impulse_ns<.001,"clear-space fold has no uncommanded impulse or speed spike")
	check(adaptive.fixed_inertia.min_axis_index()>=0 and body.inertia.is_equal_approx(adaptive.fixed_inertia),"single-body inertia remains pinned to solved standing approximation")
	check(not leg.disabled and not sole.disabled and is_instance_valid(adaptive.shin) and not adaptive.shin.disabled,"all three lower proxies retain physical collision")
	var restored:Dictionary=await advance(1.7,false)
	report.experiments.clear_restore=restored
	check(not adaptive.active and leg.shape==original and body.get_child_count()==original_count and body.inertia==Vector3.ZERO,"safe disabled restoration returns exact original standing capsule sole and inertia")
	await fresh()
	# Upper wall touches torso only. It must not inherit the knee-sweep
	# inflation; native shallow torso contact is not leg-path obstruction.
	box(world,Vector3(0,.4,-.2699),Vector3(2,.5,.1))
	await physics_frame
	adaptive.request_flex(1)
	var wall_contact:Dictionary=await advance(1.7)
	report.experiments.stationary_torso_contact=wall_contact
	check(adaptive.achieved_flex>.999 and wall_contact.peak_penetration_estimate_m<.002,"stationary shallow torso wall contact does not veto clear leg flex")
	await fresh()
	adaptive.request_flex(1)
	var loaded:Dictionary=await advance(.5,true,25)
	report.experiments.loaded_guard=loaded
	check(adaptive.achieved_flex==0 and adaptive.reason=="LOAD_TRANSFER_REQUIRED","C04 real loaded foot blocks retraction until load transferred")
	await advance(1.7,true,0)
	check(adaptive.achieved_flex>.999,"C04 unloaded foot permits guarded fold")
	await fresh()
	# A tiny lip lies in the intermediate knee sweep; endpoints both clear.
	var lip:PhysicsBody3D=box(world,Vector3(0,-.505,-.30),Vector3(.12,.012,.012))
	await physics_frame
	await physics_frame
	var start_clear:Dictionary=adaptive.audit_pose(0)
	var end_clear:Dictionary=adaptive.audit_pose(1)
	var path:Dictionary=adaptive.audit_path(0,1)
	report.experiments.swept_lip={"start":start_clear,"end":end_clear,"path":path}
	check(start_clear.clear and end_clear.clear and not path.clear,"C02 clear endpoints do not hide thin lip in continuous swept knee path")
	adaptive.request_flex(1)
	var blocked_fold:Dictionary=await advance(1.8)
	report.experiments.blocked_fold=blocked_fold
	check(adaptive.blocked and adaptive.achieved_flex<.95 and adaptive.achieved_flex>0,"C02 fold stops at last admitted pose instead of tunneling through lip")
	check(adaptive.audit_pose(adaptive.achieved_flex,0).clear,"C02 achieved physical shape remains outside blocker")
	check(blocked_fold.peak_speed<.03 and blocked_fold.peak_impulse_ns<.1,"C02 blocked fold avoids uncommanded collision impulse spikes")
	lip.queue_free()
	await physics_frame
	await advance(1.8)
	check(adaptive.achieved_flex>.999,"C02 flex resumes only after real obstruction removed")
	# A lower overhead/under-platform obstruction intersects extended soles,
	# while the crouched configuration remains clear. No teleport setup occurs
	# after this fixture's first solved body placement; only new static geometry.
	box(world,Vector3(0,-.78,-.035),Vector3(.6,.10,.50))
	await physics_frame
	var current_clear:Dictionary=adaptive.audit_pose(1)
	var extended_clear:Dictionary=adaptive.audit_pose(0)
	adaptive.request_flex(0)
	var denied:Dictionary=await advance(1.8,false)
	report.experiments.blocked_expansion={"crouched":current_clear,"extended":extended_clear,"run":denied}
	check(current_clear.clear and not extended_clear.clear and adaptive.achieved_flex>.01 and adaptive.active,"C03 abort restoration stays crouched when expansion blocked by platform volume")
	check(adaptive.audit_pose(adaptive.achieved_flex,0).clear and not sole.disabled,"C03 blocked restoration keeps collision-valid full sole active")
	await fresh()
	adaptive.request_flex(1)
	await advance(1.7)
	box(world,Vector3(0,-.945,-.035),Vector3(2,.05,2))
	await physics_frame
	var platform_restore:Dictionary=await advance(1.7,false)
	body.gravity_scale=1
	var standing:Dictionary=await advance(1.0,false,117.6)
	report.experiments.standing_platform={"restore":platform_restore,"settled":standing}
	check(not adaptive.active and absf(body.position.y)<.015 and body.global_basis.y.dot(Vector3.UP)>.995,"C01 platform restoration recovers stable native standing collider under gravity")
	check(standing.peak_penetration_estimate_m<.004 and body.linear_velocity.length()<.03,"restored standing supports weight without sustained deep penetration or drift")
	await fresh()
	# Free dynamic block, physically moving under native integration, approaches
	# the same sweep. Its motion is initial fixture velocity, not player motion.
	var moving:RigidBody3D=box(world,Vector3(0,-.505,-.35),Vector3(.12,.012,.012),true)
	moving.linear_velocity=Vector3(0,0,.025)
	await physics_frame
	adaptive.request_flex(1)
	var dynamic_result:Dictionary=await advance(1.6)
	report.experiments.moving_support=dynamic_result
	check(moving.position.z>-.35 and moving.mass==15,"C05 moving support evolves dynamically during collider flex queries")
	# Incoming block has reduced mass6.67kg at.025m/s: expected normal
	# impulse scale.167Ns. Allow.25Ns including contact geometry/solver effects;
	# actual shallow native contact is valid, unlike penetration through the lip.
	check(dynamic_result.peak_speed<.03 and dynamic_result.peak_impulse_ns<.25 and dynamic_result.peak_penetration_estimate_m<.004,"C05 moving support has bounded native impact and no deep leg penetration")
	check(body.mass==12 and body.collision_layer==4 and body.collision_mask==3 and not body.freeze,"same dynamic12kg body collision masks preserved across all flex tests")
	report["physics_hz"]=hz
	report["passed"]=passed
	report["failed"]=failed
	report["engine"]=Engine.get_version_info()
	var file:=FileAccess.open("res://builds/mantle_leg_clearance_%dhz.json"%hz,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("RESULTS: ",passed," passed, ",failed," failed")
	quit(1 if failed else 0)
