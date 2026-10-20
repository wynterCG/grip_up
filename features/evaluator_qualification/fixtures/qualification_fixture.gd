extends RefCounted
## Test-scene construction and read-only swept-ground audit. No run-time body
## correction, force, velocity write, collider disabling or authority changes.
const Level=preload("res://features/evaluator_qualification/fixtures/qualification_level.gd")
const REGISTRY="res://features/evaluator_qualification/resources/fixture_registry_v132_r1.json"
const MAX_SWEEP_STEPS=128
const TRANSLATION_STEP_M=.02
const ROTATION_STEP_RAD=PI/90.0

static func apply(app:Node,definition:Dictionary)->Dictionary:
	if not is_instance_valid(app) or not is_instance_valid(app.controller) or not is_instance_valid(app.torso):return _failure("NO_LAB")
	if app.controller._step!=0 or app.controller.simulation_time!=0.0:return _failure("FIXTURE_REQUIRES_PRE_FIRST_STEP")
	if app.controller.assisted_motion_owned or app.torso.freeze:return _failure("UNEXPECTED_AUTHORITY")
	if app.torso.linear_velocity!=Vector3.ZERO or app.torso.angular_velocity!=Vector3.ZERO:return _failure("BODY_ALREADY_ADVANCED")
	for hand:int in 2:
		if app.controller.get_hand_state(hand)!="FREE":return _failure("HAND_ALREADY_ACTIVE")
	var registry:Variant=JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	if not registry is Dictionary or registry.get("revision")!=1:return _failure("FIXTURE_REGISTRY_INVALID")
	var id:String=str(definition.get("fixture",""))
	if not registry.fixtures.has(id):return _failure("UNKNOWN_QUALIFICATION_FIXTURE")
	var spec:Dictionary=registry.fixtures[id]
	var geometry:Dictionary=registry.geometries[spec.geometry_id].duplicate(true)
	var requested_spawn:=Vector3(float(geometry.spawn_m[0]),float(geometry.spawn_m[1]),float(geometry.spawn_m[2]))
	if app.torso.position!=requested_spawn:return _failure("INITIAL_SPAWN_MISMATCH_USE_ARENA_8")
	var old_level:Node=app.level
	var old_name:String=str(old_level.name)
	if old_level.get_parent()!=null:old_level.get_parent().remove_child(old_level)
	var old_absent:bool=not old_level.is_inside_tree()
	old_level.queue_free()
	if not old_absent:return _failure("OLD_LEVEL_STILL_IN_TREE")
	var level=Level.new();level.geometry=geometry;level.fixture_id=id
	app.level=level;app.world.add_child(level)
	# Arena 8 already has the declared spawn. Keep all physical/visual caches
	# coherent without even an initialization-only body position assignment.
	var old_spawn:Vector3=app.torso.position
	app.camera.reset(app.torso,app.controller)
	app.camera.yaw=float(geometry.camera.yaw_rad)
	app.camera.elevation=float(geometry.camera.elevation_rad)
	app.camera.distance=float(geometry.camera.distance_m)
	app.camera._update_camera(1.0)
	return {"ok":true,"fixture_id":id,"revision":1,"geometry_id":spec.geometry_id,"registry_sha256":FileAccess.get_sha256(REGISTRY),"controller_step":app.controller._step,"old_level":old_name,"old_level_absent":old_absent,"initial_spawn_before_m":old_spawn,"initial_spawn_after_m":level.spawn,"initialization_only_body_position_write":false,"body_runtime_id":app.torso.get_instance_id(),"tuning_runtime_id":app.controller.tuning.get_instance_id(),"mass_kg":app.torso.mass,"linear_velocity_m_s":app.torso.linear_velocity,"angular_velocity_rad_s":app.torso.angular_velocity,"max_contacts_reported":app.torso.max_contacts_reported,"camera_initial":geometry.camera.duplicate(true),"camera_behavior":"original render-follow behavior retained after explicit symmetric fixture initialization","geometry":level.construction_report.duplicate(true),"clearance_status":"NOT_YET_NATIVE_AUDITED","clearance_reason":"Construction is not a flushed native-space or contact measurement. Call audit_clearance after an actual physics callback and across measured pose segments."}

static func audit_clearance(app:Node,from_pose:Transform3D)->Dictionary:
	if not is_instance_valid(app) or not is_instance_valid(app.torso):return _failure("NO_BODY")
	var body:RigidBody3D=app.torso
	var state:PhysicsDirectBodyState3D=PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state==null:return _failure("NO_DIRECT_STATE")
	var to_pose:Transform3D=state.transform
	var distance:float=from_pose.origin.distance_to(to_pose.origin)
	var angle:float=from_pose.basis.get_rotation_quaternion().angle_to(to_pose.basis.get_rotation_quaternion())
	var steps:int=maxi(1,maxi(int(ceil(distance/TRANSLATION_STEP_M)),int(ceil(angle/ROTATION_STEP_RAD))))
	if steps>MAX_SWEEP_STEPS:return _failure("SWEEP_BOUND_EXCEEDED")
	var space:PhysicsDirectSpaceState3D=body.get_world_3d().direct_space_state
	var hits:Array[Dictionary]=[]
	var shape_count:=0
	for child:Node in body.get_children():
		if not child is CollisionShape3D or child.disabled or child.shape==null:continue
		shape_count+=1
		var radius:float=_shape_radius(child.shape)
		if radius<0:return _failure("UNSUPPORTED_BODY_PROXY")
		if not child.transform.basis.get_scale().is_equal_approx(Vector3.ONE):return _failure("SCALED_BODY_PROXY")
		for index:int in steps:
			var a:Transform3D=from_pose.interpolate_with(to_pose,float(index)/steps)
			var b:Transform3D=from_pose.interpolate_with(to_pose,float(index+1)/steps)
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=child.shape;query.transform=a*child.transform
			query.motion=b.origin-a.origin
			query.collision_mask=body.collision_mask&1;query.exclude=[body.get_rid()]
			# The physical shapes are not changed. Query-only inflation bounds the
			# rotation arc of every proxy point about the body origin within this
			# translation substep; possible hits are conservative, never clearance.
			query.margin=(child.transform.origin.length()+radius)*angle/steps
			var overlaps:Array[Dictionary]=space.intersect_shape(query,16)
			if not overlaps.is_empty():
				hits.append({"kind":"OVERLAP_OR_ROTATION_BOUND","shape":str(child.name),"segment":index,"colliders":_colliders(overlaps),"query_margin_m":query.margin})
			var fraction:PackedFloat32Array=space.cast_motion(query)
			if fraction.size()!=2:return _failure("INCOMPLETE_NATIVE_SWEEP_RESULT")
			if fraction[0]<1.0:hits.append({"kind":"SWEPT_GROUND_INTERSECTION","shape":str(child.name),"segment":index,"safe_fraction":fraction[0],"unsafe_fraction":fraction[1],"collider_id":null,"query_margin_m":query.margin})
		# cast_motion does not certify a starting overlap; also test the true end.
		var end_query:=PhysicsShapeQueryParameters3D.new()
		end_query.shape=child.shape;end_query.transform=to_pose*child.transform
		end_query.collision_mask=body.collision_mask&1;end_query.exclude=[body.get_rid()]
		var end_hits:Array[Dictionary]=space.intersect_shape(end_query,16)
		if not end_hits.is_empty():hits.append({"kind":"END_OVERLAP","shape":str(child.name),"colliders":_colliders(end_hits)})
	var native_ground_contacts:Array[Dictionary]=[]
	if shape_count==0:return _failure("NO_BODY_PROXIES")
	for index:int in state.get_contact_count():
		var collider:Object=state.get_contact_collider_object(index)
		if collider is PhysicsBody3D and (collider.collision_layer&1)!=0:native_ground_contacts.append({"runtime_id":collider.get_instance_id(),"key":str(collider.get_meta("mastery_surface",collider.name)),"local_shape":state.get_contact_local_shape(index),"collider_shape":state.get_contact_collider_shape(index)})
	return {"ok":true,"status":"CLEAR_QUERIED_SEGMENT" if hits.is_empty() else "POSSIBLE_GROUND_INTERSECTION","scope":"Real body proxies versus nongrippable ground/startpad layer1 only. Wall/foothold collisions remain native and are not disabled or declared clear.","from_pose":from_pose,"to_pose":to_pose,"steps":steps,"body_proxy_count":shape_count,"query_translation_step_m":TRANSLATION_STEP_M,"query_rotation_step_rad":ROTATION_STEP_RAD,"hits":hits,"native_ground_contacts":native_ground_contacts,"native_contact_count":state.get_contact_count(),"native_contact_reporting_enabled":body.max_contacts_reported>0,"native_contact_buffer_saturated":body.max_contacts_reported>0 and state.get_contact_count()>=body.max_contacts_reported,"native_contact_limit":body.max_contacts_reported,"ground_motor_grounded":app.ground_motor.grounded,"ground_motor_force_n":app.ground_motor.applied_force,"ground_motor_torque_nm":app.ground_motor.applied_torque,"authority_note":"Queries are observations only; a potential intersection or real ground authority invalidates a climbing-only window, not a request to correct the body. Unreported contacts do not prove absence."}

static func _colliders(hits:Array[Dictionary])->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for hit:Dictionary in hits:
		var collider:Object=hit.get("collider")
		result.append({"runtime_id":int(hit.get("collider_id",0)),"key":str(collider.get_meta("mastery_surface",collider.name)) if collider is PhysicsBody3D else "UNKNOWN"})
	return result

static func _shape_radius(shape:Shape3D)->float:
	if shape is CapsuleShape3D:return maxf(shape.height*.5,shape.radius)
	if shape is SphereShape3D:return shape.radius
	if shape is BoxShape3D:return shape.size.length()*.5
	return -1.0

static func _failure(reason:String)->Dictionary:return {"ok":false,"reason":reason,"status":"NOT_AUDITED"}
