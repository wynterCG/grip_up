extends SceneTree
const Motor=preload("res://features/grip_up/scripts/mantle_kinematic_motor.gd")
const Profile=preload("res://features/grip_up/resources/biped_tuning.gd")
var hz:=120
var checks:=0
var failures:=0
var world:Node3D
var body:RigidBody3D
var motor:RefCounted
var records:Array=[]
var initial_rotation:=Vector3.ZERO

func _initialize()->void:
	if OS.get_cmdline_user_args().has("--60hz"):hz=60
	Engine.physics_ticks_per_second=hz
	run.call_deferred()

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func setup()->void:
	if is_instance_valid(world):world.queue_free();await physics_frame;await physics_frame
	world=Node3D.new()
	root.add_child(world)
	body=RigidBody3D.new()
	body.mass=12
	body.gravity_scale=0
	body.contact_monitor=true
	body.max_contacts_reported=16
	body.collision_layer=4
	body.collision_mask=3
	body.position=Vector3(0,2,1)
	body.rotation=initial_rotation
	var profile:=Profile.new()
	for data in [["TorsoCapsule",profile.torso_capsule_height,profile.torso_capsule_radius,profile.torso_capsule_center_y],["LowerCapsule",profile.leg_capsule_height,profile.leg_capsule_radius,profile.leg_capsule_center_y]]:
		var node:=CollisionShape3D.new()
		var shape:=CapsuleShape3D.new()
		shape.height=data[1]
		shape.radius=data[2]
		node.shape=shape
		node.name=data[0]
		node.position.y=data[3]
		body.add_child(node)
	var head:=CollisionShape3D.new()
	var sphere:=SphereShape3D.new()
	sphere.radius=profile.head_radius
	head.shape=sphere
	head.position.y=profile.head_center_y
	body.add_child(head)
	var foot:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=profile.foot_base_size
	foot.name="FootBase"
	foot.shape=box
	foot.position=profile.foot_base_offset
	body.add_child(foot)
	world.add_child(body)
	await physics_frame
	await physics_frame
	motor=Motor.new()
	check(motor.configure(body),"motor snapshots unchanged existing compound rigid body")

func obstacle(at:Vector3,size:Vector3,dynamic:bool=false)->PhysicsBody3D:
	var result:PhysicsBody3D
	if dynamic:
		result=RigidBody3D.new()
		result.gravity_scale=0
	else:result=StaticBody3D.new()
	result.position=at
	result.collision_layer=1
	result.collision_mask=4
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	result.add_child(collision)
	world.add_child(result)
	return result

func run()->void:
	await setup()
	var original:=body.global_transform
	var originals:Array=[]
	for child in body.get_children():originals.append([child,child.shape,child.transform])
	var mass:float=body.mass
	var layers:=Vector2i(body.collision_layer,body.collision_mask)
	check(not body.freeze and body.get_child_count()==4,"configure changes neither authority nor real geometry")
	check(absf(motor.lowest_point(0)+.9167)<.00001 and absf(motor.lowest_point(1)+.6467)<.00001,"standing and heel-back bounds include actual knee and sole volumes")
	check(motor.begin() and motor.begin() and motor.diagnostics().begins==1,"commit is idempotent on same frozen-kinematic rigid body")
	check(body.freeze and body.freeze_mode==RigidBody3D.FREEZE_MODE_KINEMATIC and body.get_child_count()==5,"temporary real shin preserves exact standing capsule union")
	var target:=Transform3D(Basis(Vector3.UP,.4),original.origin+Vector3(.25,.4,-.25))
	var proof:Dictionary=motor.validate_segment(original,target,0,1)
	check(proof.clear and proof.substeps>100,"preflight subdivides translation rotation and shape morph conservatively")
	var outcome:Dictionary={}
	var tracking_error:=0.0
	var moving_clear:=true
	for frame in hz:
		var t:float=(frame+1)/float(hz)
		var next:Transform3D=original.interpolate_with(target,t)
		outcome=motor.move_step(next,t,1.0/hz)
		moving_clear=moving_clear and outcome.clear
		await physics_frame
		tracking_error=maxf(tracking_error,body.global_position.distance_to(next.origin))
	check(moving_clear and outcome.moved and body.global_transform.is_equal_approx(target) and tracking_error<.00001,"native movement tracks approved translation rotation and morph across real fixed ticks")
	check(body.mass==mass and Vector2i(body.collision_layer,body.collision_mask)==layers,"assisted route preserves mass and collision layers")
	check(motor.move_step(target,0,1.0).clear,"normal profile unfolds through a validated local geometry path")
	check(motor.end_dynamic(Vector3(.2,0,0)) and motor.end_dynamic() and motor.diagnostics().ends==1,"restore returns dynamic authority once with measured exit velocity")
	var exact:=body.get_child_count()==4
	for item in originals:exact=exact and item[0].shape==item[1] and item[0].transform==item[2]
	check(exact and not body.freeze and body.linear_velocity.distance_to(Vector3(.2,0,0))<.00001,"original shape resource identities/transforms restored and stale swing velocity discarded")
	await setup()
	var wall:=obstacle(Vector3(0,2,0),Vector3(3,4,.01))
	await physics_frame
	await physics_frame
	var start:Transform3D=body.global_transform
	var finish:=start
	finish.origin.z=-1
	check(not motor.validate_segment(start,finish,0,0).clear,"thin wall between free endpoints blocks continuous compound path")
	motor.begin()
	var before:Transform3D=body.global_transform
	check(not motor.move_step(finish,0,.1).clear and body.global_transform==before,"blocked preflight leaves body/profile at previous safe pose")
	records.append(motor.diagnostics())
	wall.queue_free()
	await physics_frame
	await physics_frame
	check(motor.move_step(finish,0,1).clear,"live recheck permits previously blocked corridor after obstacle removal")
	await setup()
	var small:=obstacle(Vector3(0,1.18,1),Vector3(.10,.10,.10))
	await physics_frame
	check(not motor.standing_clear(body.global_transform).clear,"standing validation includes foot volume below torso")
	small.queue_free()
	await physics_frame
	await physics_frame
	motor.begin()
	motor.move_step(body.global_transform,1,.5)
	var blocker:=obstacle(body.global_position+Vector3(0,-.84,0),Vector3(.5,.08,.5))
	await physics_frame
	await physics_frame
	check(not motor.standing_clear(body.global_transform).clear and not motor.end_dynamic(),"blocked full-height restore never unfreezes overlapping standing geometry")
	check(body.freeze and motor.active,"unrestorable state remains explicitly assisted pending safe recovery/reset")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	check(motor.move_step(body.global_transform,0,.5).clear and motor.end_dynamic(),"cleared restoration corridor safely unfolds and restores original dynamics")
	await setup()
	var dynamic_blocker:=obstacle(Vector3(.6,2,1),Vector3(.1,2,2),true)
	await physics_frame
	motor.begin()
	var moved:=body.global_transform
	moved.origin.x=1
	var blocker_pose:Transform3D=dynamic_blocker.global_transform
	check(not motor.move_step(moved,0,.2).clear and dynamic_blocker.global_transform==blocker_pose,"runtime dynamic object blocks assistance without an artificial push")
	await setup()
	obstacle(Vector3(0,2,.6805),Vector3(3,4,.2))
	await physics_frame
	await physics_frame
	check(motor.configure(body),"shallow existing static native wall touch is eligible without hiding collision")
	var escape:Transform3D=body.global_transform
	var into:=escape
	into.origin.z-=.03
	check(not motor.validate_segment(escape,into,0,0).clear,"initial shallow touch never permits deepening movement into the wall")
	escape.origin.z+=.03
	var retreat:Dictionary=motor.validate_segment(body.global_transform,escape,0,0)
	print("RETREAT PROOF ",retreat)
	check(retreat.clear,"existing shallow contact permits finite strictly outward clearance motion")
	motor.begin()
	var actual_retreat:Dictionary=motor.move_step(escape,0,.1)
	print("RETREAT MOTION ",actual_retreat)
	check(actual_retreat.clear,"native frozen-kinematic motion also accepts the certified outward retreat")
	await setup()
	obstacle(Vector3(.198,1.1233,.94),Vector3(.006,.03,.05))
	await physics_frame
	var rotated:Transform3D=body.global_transform
	rotated.basis=Basis(Vector3.UP,PI)
	check(motor.standing_clear(body.global_transform).clear and motor.standing_clear(rotated).clear,"rotation adversary has free starting and ending compound poses")
	check(not motor.validate_segment(body.global_transform,rotated,0,0).clear,"intermediate rotating foot corner cannot pass a thin obstacle despite free endpoints")
	await setup()
	obstacle(Vector3(0,1.3933,1.32),Vector3(.3,.03,.03))
	await physics_frame
	var still:Transform3D=body.global_transform
	check(motor.validate_segment(still,still,0,0).clear and motor.validate_segment(still,still,1,1).clear,"morph adversary has free normal and fully tucked endpoints")
	check(not motor.validate_segment(still,still,0,1).clear,"continuous knee/shin/sole morph catches obstruction between free profiles")
	await setup()
	var deck:=obstacle(Vector3(0,.975,1),Vector3(3,.2,3))
	await physics_frame
	motor.begin()
	check(motor.move_step(body.global_transform,1,.5).clear and not motor.end_dynamic(),"dynamic authority is explicitly refused until caller has restored flex zero")
	check(motor.move_step(body.global_transform,0,.5).clear and motor.end_dynamic(),"normal representation restores before gravity handoff")
	body.gravity_scale=1
	for frame in int(.4*hz):await physics_frame
	var state:=PhysicsServer3D.body_get_direct_state(body.get_rid())
	var native_support:=false
	if state!=null:
		for contact in state.get_contact_count():native_support=native_support or state.get_contact_collider_id(contact)==deck.get_instance_id()
	var settled_y:float=body.global_position.y
	check(native_support and body.linear_velocity.length()<.1 and absf(body.global_position.y-1.9917)<.004,"unfreeze settles onto real native deck support without stale launch impulse")
	await setup()
	body.apply_central_force(Vector3(500,0,0))
	body.apply_torque(Vector3(0,50,0))
	motor.begin()
	for frame in int(.2*hz):await physics_frame
	check(motor.end_dynamic(),"pending precommit force fixture restores dynamic mode normally")
	await physics_frame
	await physics_frame
	check(body.linear_velocity.length()<.00001 and body.angular_velocity.length()<.00001,"precommit accumulated forces do not replay as an impulse after frozen ticks")
	await setup()
	motor.begin()
	body.collision_mask=0
	var forbidden:Transform3D=body.global_transform
	forbidden.origin.x+=.1
	check(not motor.move_step(forbidden,0,.1).clear,"changing collision authority cannot turn assistance into a no-collision shortcut")
	body.collision_mask=3
	check(motor.end_dynamic(),"restoring unchanged collision ownership permits safe normal handoff")
	initial_rotation=Vector3(-.085,.217,.106)
	await setup()
	body.lock_rotation=true
	obstacle(Vector3(0,2,.68),Vector3(3,4,.2))
	for frame in int(.5*hz):
		body.apply_central_force(Vector3(0,0,-200))
		await physics_frame
	check(motor.refresh_start_contacts() and motor.start_contact_audit.maximum_query_depth>.005 and motor.start_contact_audit.maximum_query_depth<=.020001,"existing deep Jolt overlap is measured and matched to actual native shape/collider contact")
	var native_start:Transform3D=body.global_transform
	var recovery_target:=native_start
	recovery_target.origin.z+=.03
	var worsening:=native_start
	worsening.origin.z-=.01
	check(not motor.validate_segment(native_start,worsening,0,0).clear,"native recovery never permits worsening direction")
	var rotation_forbidden:=native_start
	rotation_forbidden.basis=Basis(Vector3.UP,.03)*native_start.basis
	check(not motor.validate_segment(native_start,rotation_forbidden,0,0).clear and not motor.validate_segment(native_start,native_start,0,.05).clear,"deep native recovery forbids rotation and profile morph before clearance")
	check(motor.validate_segment(native_start,recovery_target,0,0).clear and motor.begin(),"only strictly outward constant-profile path can commit evidenced native recovery")
	var new_blocker:=obstacle(body.global_position+Vector3(0,0,.226),Vector3(.6,1,.01))
	await physics_frame
	var before_denial:Transform3D=body.global_transform
	var denied:Dictionary=motor.move_step(recovery_target,0,.2)
	check(not denied.clear and body.global_transform==before_denial,"new collider during native recovery blocks motion and is never exempted")
	new_blocker.queue_free()
	await physics_frame
	await physics_frame
	var recovery_steps:Array=[]
	var monotonic:=true
	var exact_motion:=true
	var recovered_steps:=0
	var preceding_depth:float=motor.start_contact_audit.maximum_query_depth
	for frame in 10:
		var from_recovery:Transform3D=body.global_transform
		var next_recovery:=from_recovery
		next_recovery.origin.z+=.003
		var recovery:Dictionary=motor.move_step(next_recovery,0,1.0/hz)
		recovered_steps+=int(recovery.get("native_overlap_recovery_steps",0))
		var depths:Dictionary=motor._departure_depths(body.global_transform,0)
		var current_depth:=0.0
		for value in depths.values():current_depth=maxf(current_depth,value)
		monotonic=monotonic and current_depth<=preceding_depth+.000001
		exact_motion=exact_motion and recovery.clear and body.global_position.distance_to(next_recovery.origin)<.000001
		recovery_steps.append({"depth":current_depth,"actual_motion":body.global_position-from_recovery.origin,"recovery_steps":recovery.get("native_overlap_recovery_steps",0)})
		preceding_depth=current_depth
		await physics_frame
	check(monotonic and preceding_depth==0 and recovered_steps>0,"each certified frozen departure reduces native penetration until the original collider is clear")
	check(exact_motion,"3mm requested recovery steps stay3mm without native20mm extra depenetration")
	records.append({"case":"EXISTING_NATIVE_RECOVERY","initial":motor.start_contact_audit.duplicate(true),"steps":recovery_steps})
	check(motor.end_dynamic(),"fully cleared native recovery restores exact normal dynamics safely")
	initial_rotation=Vector3.ZERO
	await setup()
	var unknown_overlap:=obstacle(Vector3(0,2,.689),Vector3(3,4,.2))
	# No simulation tick: overlap exists geometrically but has no solved native
	# body contact. It cannot acquire a recovery exemption from a query alone.
	check(not motor.refresh_start_contacts(),"geometric overlap without actual native contact is rejected rather than laundered as recovery")
	unknown_overlap.queue_free()
	FileAccess.open("res://builds/hybrid_motor_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify({"physics_hz":hz,"checks":checks,"failures":failures,"engine":Engine.get_version_info(),"authority":"SAME_RIGIDBODY_FREEZE_KINEMATIC","fixed_tick_tracking_error_m":tracking_error,"combined_preflight":proof,"native_support_after_restore":native_support,"native_settled_body_y":settled_y,"standing_lowest_local":motor.lowest_point(0),"tucked_lowest_local":motor.lowest_point(1),"records":records},"\t"))
	world.queue_free()
	await physics_frame
	print("HYBRID MOTOR RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
