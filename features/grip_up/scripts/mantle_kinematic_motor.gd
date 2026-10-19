extends RefCounted
## Scoped v0.9 assistance. Same gameplay RigidBody, no second collision owner.
## All mutating calls belong in _physics_process, never _integrate_forces.
const POINT_STEP:=.003
const SKIN:=.0001
const NATIVE_TOUCH:=.002
const MAX_NATIVE_RECOVERY:=.020
const MAX_SUBSTEPS:=4096
var body:RigidBody3D
var active:=false
var flex:=0.0
var reason:="UNCONFIGURED"
var last:Dictionary={}
var measured_velocity:=Vector3.ZERO
var _baseline:Array[Dictionary]=[]
var _lower:CollisionShape3D
var _sole:CollisionShape3D
var _shin:CollisionShape3D
var _segment:CapsuleShape3D
var _length:=.27
var _radius:=.15
var _hip:=Vector3.ZERO
var _ankle_to_sole:=Vector3.ZERO
var _sole_basis:=Basis.IDENTITY
var _body_radius_bound:=0.0
var _saved:Dictionary={}
var _initial_contacts:Dictionary={}
var _native_departures:Dictionary={}
var _begins:=0
var _ends:=0
var start_contact_audit:Dictionary={}

func configure(target:RigidBody3D)->bool:
	if active or not is_instance_valid(target) or not target.is_inside_tree():return false
	body=target
	_baseline.clear()
	_lower=null
	_sole=null
	for node in body.get_children():
		if not node is CollisionShape3D or node.disabled:continue
		if not node.shape is CapsuleShape3D and not node.shape is SphereShape3D and not node.shape is BoxShape3D:
			reason="UNSUPPORTED_SHAPE"
			return false
		if not node.transform.basis.get_scale().is_equal_approx(Vector3.ONE):
			reason="SCALED_COLLIDER_UNSUPPORTED"
			return false
		_baseline.append({"node":node,"shape":node.shape,"query_shape":node.shape.duplicate(true),"pose":node.transform,"name":str(node.name),"disabled":node.disabled})
		if node.name=="LowerCapsule":_lower=node
		if node.name=="FootBase":_sole=node
	if _lower==null or _sole==null or not _lower.shape is CapsuleShape3D:
		reason="MISSING_BASELINE_LOWER_SHAPES"
		return false
	_radius=_lower.shape.radius
	_length=(_lower.shape.height-2*_radius)*.5
	_hip=_lower.position+Vector3.UP*_length
	_ankle_to_sole=_sole.position-(_lower.position-Vector3.UP*_length)
	_sole_basis=_sole.transform.basis
	_body_radius_bound=0
	for entry in _baseline:_body_radius_bound=maxf(_body_radius_bound,Vector3(entry.pose.origin).length()+_shape_radius(entry.query_shape))
	_segment=CapsuleShape3D.new()
	_segment.radius=_radius
	_segment.height=_length+2*_radius
	if not refresh_start_contacts():return false
	flex=0
	reason="CONFIGURED"
	return true

func refresh_start_contacts()->bool:
	if active or not is_instance_valid(body):return false
	_initial_contacts.clear()
	_native_departures.clear()
	var contacts:Array=[]
	var state:=PhysicsServer3D.body_get_direct_state(body.get_rid())
	var solved_pose:Transform3D=body.global_transform
	if state!=null:
		solved_pose=state.transform
		for i in state.get_contact_count():contacts.append({"shape_index":state.get_contact_local_shape(i),"collider_id":state.get_contact_collider_id(i),"position_api":state.get_contact_local_position(i),"normal_api":state.get_contact_local_normal(i),"impulse":state.get_contact_impulse(i)})
	start_contact_audit={"body_pose":body.global_transform,"physics_server_pose":solved_pose,"pose_origin_delta":solved_pose.origin.distance_to(body.global_position),"native_contacts":contacts,"probes":[],"maximum_query_depth":0.0,"touch_policy":"2mm ordinary touch; native-proven existing overlap<=20mm permits certified monotonic outward frozen recovery only","clear":true}
	for probe in _probes(0):
		var query:=_query(probe.shape,body.global_transform*probe.pose)
		var hits:Array[Dictionary]=body.get_world_3d().direct_space_state.intersect_shape(query,16)
		if hits.is_empty():continue
		var pairs:PackedVector3Array=body.get_world_3d().direct_space_state.collide_shape(query,32)
		var depth:float=_depth(pairs)
		var probe_audit:Dictionary={"shape":probe.name,"depth":depth,"world_pose":query.transform,"collider_ids":hits.map(func(hit):return hit.collider_id),"pair_points":pairs}
		start_contact_audit.probes.append(probe_audit)
		start_contact_audit.maximum_query_depth=maxf(start_contact_audit.maximum_query_depth,depth)
		if depth>NATIVE_TOUCH:
			var evidenced:bool=depth<=MAX_NATIVE_RECOVERY+.000001 and hits.size()==1 and hits[0].collider is StaticBody3D and not hits[0].collider is AnimatableBody3D and hits[0].collider.constant_linear_velocity==Vector3.ZERO and hits[0].collider.constant_angular_velocity==Vector3.ZERO
			var matched:=false
			if evidenced and state!=null:
				for contact in contacts:
					var owner_id:int=body.shape_find_owner(contact.shape_index)
					var owner:Object=body.shape_owner_get_owner(owner_id)
					if owner!=probe.owner_node or contact.collider_id!=hits[0].collider_id:continue
					for i in range(0,pairs.size()-1,2):
						var normal:Vector3=(pairs[i+1]-pairs[i]).normalized()
						if Vector3(contact.normal_api).dot(normal)>.9 and Vector3(contact.position_api).distance_to(pairs[i])<.03:matched=true
			if evidenced and matched:
				var key:String=probe.name+":"+str(hits[0].collider_id)
				_native_departures[key]={"depth":depth,"normal":Vector3(pairs[1]-pairs[0]).normalized(),"collider_id":hits[0].collider_id,"shape":probe.name}
				probe_audit["native_recovery_proven"]=true
				continue
			reason="START_PENETRATING"
			start_contact_audit.clear=false
			last={"clear":false,"reason":reason,"shape":probe.name,"depth":depth,"blocked_collider":hits[0].collider_id,"blocker_id":hits[0].collider_id,"body_pose":body.global_transform,"attempted_motion":Vector3.ZERO,"allowed_motion":Vector3.ZERO}
			return false
		for hit in hits:
			if hit.collider is StaticBody3D and hit.collider.constant_linear_velocity==Vector3.ZERO and hit.collider.constant_angular_velocity==Vector3.ZERO:_initial_contacts[hit.collider_id]=true
	return true

func _segment_pose(a:Vector3,b:Vector3)->Transform3D:
	var y:Vector3=(a-b).normalized()
	return Transform3D(Basis(Vector3.RIGHT,y,Vector3.RIGHT.cross(y)),(a+b)*.5)

func pose_for(value:float)->Dictionary:
	var amount:float=clampf(value,0,1)
	var knee:Vector3=_hip+Vector3.DOWN*_length
	var angle:float=deg_to_rad(150)*amount
	var ankle:Vector3=knee+Vector3(0,-cos(angle),sin(angle))*_length
	return {"hip":_hip,"knee":knee,"ankle":ankle,"thigh":_segment_pose(_hip,knee),"shin":_segment_pose(knee,ankle),"sole":Transform3D(_sole_basis,ankle+_ankle_to_sole),"flex":amount,"pose_mode":"HEEL_BACK"}

func _probes(value:float)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	var pose:=pose_for(value)
	for entry in _baseline:
		if entry.node==_lower:
			result.append({"name":"thigh","shape":_segment,"pose":pose.thigh,"morph_bound":0.0,"owner_node":_lower})
			result.append({"name":"shin","shape":_segment,"pose":pose.shin,"morph_bound":(_length+_radius)*deg_to_rad(150),"owner_node":_lower})
		elif entry.node==_sole:result.append({"name":entry.name,"shape":entry.query_shape,"pose":pose.sole,"morph_bound":_length*deg_to_rad(150),"owner_node":entry.node})
		else:result.append({"name":entry.name,"shape":entry.query_shape,"pose":entry.pose,"morph_bound":0.0,"owner_node":entry.node})
	return result

func _shape_radius(shape:Shape3D)->float:
	if shape is CapsuleShape3D:return shape.height*.5
	if shape is SphereShape3D:return shape.radius
	if shape is BoxShape3D:return shape.size.length()*.5
	return INF

func _inflate(shape:Shape3D,padding:float)->Shape3D:
	var copy:Shape3D=shape.duplicate(true)
	if copy is CapsuleShape3D:
		copy.radius+=padding
		copy.height+=2*padding
	elif copy is SphereShape3D:copy.radius+=padding
	elif copy is BoxShape3D:copy.size+=Vector3.ONE*(2*padding)
	return copy

func _query(shape:Shape3D,pose:Transform3D)->PhysicsShapeQueryParameters3D:
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform=pose
	query.collision_mask=body.collision_mask
	query.exclude=[body.get_rid()]
	query.margin=0
	return query

func _depth(pairs:PackedVector3Array)->float:
	var maximum:=0.0
	for i in range(0,pairs.size()-1,2):maximum=maxf(maximum,pairs[i].distance_to(pairs[i+1]))
	return maximum

func _audit(pose:Transform3D,value:float,padding:float=0.0,outward_motion:Vector3=Vector3.ZERO,eligible_departures:Dictionary={})->Dictionary:
	var space:=body.get_world_3d().direct_space_state
	for probe in _probes(value):
		var query:=_query(_inflate(probe.shape,padding),pose*probe.pose)
		var hits:Array[Dictionary]=space.intersect_shape(query,16)
		if hits.is_empty():continue
		var allow_touch:bool=outward_motion.length_squared()>.000000000001 and hits.all(func(hit):return _initial_contacts.has(hit.collider_id))
		if not allow_touch and outward_motion.length_squared()>.000000000001 and hits.size()==1:
			var key:String=probe.name+":"+str(hits[0].collider_id)
			if _native_departures.has(key) and eligible_departures.has(key):
				var known:Dictionary=_native_departures[key]
				var pairs:PackedVector3Array=space.collide_shape(query,32)
				allow_touch=_depth(pairs)<=minf(known.depth,eligible_departures[key])+padding+.000001 and Vector3(known.normal).dot(outward_motion.normalized())>.1
				for i in range(0,pairs.size()-1,2):
					if (pairs[i+1]-pairs[i]).normalized().dot(outward_motion.normalized())<.1:allow_touch=false
				# The ordinary shallow-touch test below must not replace this
				# independently proven native recovery's measured depth budget.
				if allow_touch:continue
		if allow_touch:
			var pairs:PackedVector3Array=space.collide_shape(query,32)
			allow_touch=_depth(pairs)<=NATIVE_TOUCH+padding
			for i in range(0,pairs.size()-1,2):
				var normal:Vector3=(pairs[i+1]-pairs[i]).normalized()
				if normal.dot(outward_motion.normalized())<.1:allow_touch=false
		if not allow_touch:return {"clear":false,"reason":"PATH_BLOCKED","shape":probe.name,"blocker_id":hits[0].collider_id,"blocked_collider":hits[0].collider_id,"body_pose":pose,"flex":value,"padding":padding}
	return {"clear":true,"reason":"CLEAR","body_pose":pose,"flex":value}

func _departure_depths(pose:Transform3D,value:float)->Dictionary:
	var depths:Dictionary={}
	if _native_departures.is_empty():return depths
	for probe in _probes(value):
		var query:=_query(probe.shape,pose*probe.pose)
		var space:=body.get_world_3d().direct_space_state
		var hits:Array[Dictionary]=space.intersect_shape(query,16)
		for hit in hits:
			var key:String=probe.name+":"+str(hit.collider_id)
			if _native_departures.has(key):depths[key]=_depth(space.collide_shape(query,32))
	return depths

func _rotation(from_pose:Transform3D,to_pose:Transform3D)->float:
	return from_pose.basis.get_rotation_quaternion().angle_to(to_pose.basis.get_rotation_quaternion())

func _valid_pose(pose:Transform3D)->bool:
	return pose.origin.is_finite() and pose.basis.x.is_finite() and pose.basis.y.is_finite() and pose.basis.z.is_finite() and pose.basis.is_equal_approx(pose.basis.orthonormalized()) and absf(pose.basis.determinant()-1)<.001

func validate_segment(from_pose:Transform3D,to_pose:Transform3D,from_flex:float,to_flex:float)->Dictionary:
	if not is_instance_valid(body) or not _valid_pose(from_pose) or not _valid_pose(to_pose) or not is_finite(from_flex) or not is_finite(to_flex) or minf(from_flex,to_flex)<0 or maxf(from_flex,to_flex)>1:return {"clear":false,"reason":"INVALID_SEGMENT"}
	# Configuration can precede a long dynamic climb. Only the actual live
	# initial pose may refresh the native-touch exemption, never a future path
	# sample, so preflight cannot launder a new collision into an allowed one.
	if not active and from_flex==0 and from_pose.is_equal_approx(body.global_transform) and not refresh_start_contacts():
		var failure:Dictionary=last.duplicate(true)
		failure["start_contact_audit"]=start_contact_audit.duplicate(true)
		return failure
	var translation:float=from_pose.origin.distance_to(to_pose.origin)
	var angle:=_rotation(from_pose,to_pose)
	# HEEL_BACK's knee is fixed, and its ankle/sole follow an arc whose
	# maximum distance from body origin occurs in the original standing pose.
	# Use this immutable whole-profile radius, not a midpoint radius which
	# could underestimate rotational travel while unfolding.
	var radius:=_body_radius_bound
	var morph:=0.0
	for probe in _probes(.5*(from_flex+to_flex)):
		radius=maxf(radius,Vector3(probe.pose.origin).length()+_shape_radius(probe.shape))
		morph=maxf(morph,probe.morph_bound)
	var bound:float=translation+radius*angle+morph*absf(to_flex-from_flex)
	var count:int=maxi(1,ceili(bound/POINT_STEP))
	if count>MAX_SUBSTEPS:return {"clear":false,"reason":"QUERY_RESOLUTION_EXCEEDED","substeps":count}
	var padding:float=SKIN+bound/(2*count)
	var outward:Vector3=to_pose.origin-from_pose.origin if angle<.000001 and absf(to_flex-from_flex)<.000001 else Vector3.ZERO
	var previous_depths:Dictionary=_departure_depths(from_pose,from_flex)
	for index in count:
		var t:float=(index+.5)/float(count)
		var sample_result:=_audit(from_pose.interpolate_with(to_pose,t),lerpf(from_flex,to_flex,t),padding,outward,previous_depths)
		if not sample_result.clear:
			sample_result.merge({"substeps":count,"blocked_segment":index,"attempted_motion":to_pose.origin-from_pose.origin,"allowed_motion":Vector3.ZERO},true)
			return sample_result
		if not previous_depths.is_empty():
			var next_depths:Dictionary=_departure_depths(from_pose.interpolate_with(to_pose,(index+1)/float(count)),lerpf(from_flex,to_flex,(index+1)/float(count)))
			for key in next_depths:
				if next_depths[key]>previous_depths.get(key,0.0)+.000001:return {"clear":false,"reason":"NATIVE_RECOVERY_NOT_MONOTONIC","blocked_collider":_native_departures[key].collider_id}
			previous_depths=next_depths
	var result:=_audit(to_pose,to_flex,SKIN,outward,previous_depths)
	result.merge({"substeps":count,"point_motion_bound":bound,"query_padding":padding},true)
	return result

func begin()->bool:
	if active:return true
	if not is_instance_valid(body) or _baseline.is_empty() or body.freeze:
		reason="INVALID_AUTHORITY"
		return false
	if not refresh_start_contacts():return false
	_saved={"freeze":body.freeze,"freeze_mode":body.freeze_mode,"layer":body.collision_layer,"mask":body.collision_mask,"gravity":body.gravity_scale,"inertia":body.inertia,"linear_velocity":body.linear_velocity,"angular_velocity":body.angular_velocity}
	body.freeze_mode=RigidBody3D.FREEZE_MODE_KINEMATIC
	body.freeze=true
	_shin=CollisionShape3D.new()
	_shin.name="MantleKinematicShin"
	_shin.shape=_segment
	body.add_child(_shin)
	_apply_profile(0)
	active=true
	_begins+=1
	reason="ASSISTED"
	return true

func _apply_profile(value:float)->void:
	var pose:=pose_for(value)
	_lower.shape=_segment
	_lower.transform=pose.thigh
	_shin.transform=pose.shin
	_sole.transform=pose.sole
	flex=value

func move_step(target:Transform3D,target_flex:float,delta:float)->Dictionary:
	if not active or not body.freeze or delta<=0:return {"moved":false,"clear":false,"reason":"MOTOR_NOT_AUTHORITATIVE"}
	if body.collision_layer!=_saved.layer or body.collision_mask!=_saved.mask:return {"moved":false,"clear":false,"reason":"COLLISION_AUTHORITY_CHANGED","attempted_motion":target.origin-body.global_position,"allowed_motion":Vector3.ZERO,"blocked_collider":0}
	var start:Transform3D=body.global_transform
	last=validate_segment(start,target,flex,target_flex)
	if not last.clear:
		last.moved=false
		reason=last.reason
		return last.duplicate(true)
	var count:int=last.substeps
	var from_flex:=flex
	var manual_recovery_steps:=0
	for index in count:
		var t:float=(index+1)/float(count)
		var pose:Transform3D=start.interpolate_with(target,t)
		var motion:Vector3=pose.origin-body.global_position
		var hit:KinematicCollision3D
		if not _departure_depths(body.global_transform,flex).is_empty():
			# Native move_and_collide silently adds a large depenetration here.
			# Only this evidenced, strictly outward, monotonic segment is moved
			# by its EXACT certified frozen translation instead. No rotation,
			# morph or new overlap can qualify for this recovery branch.
			body.global_position+=motion
			manual_recovery_steps+=1
		else:hit=body.move_and_collide(motion,false,.0001,false,4)
		if hit!=null:
			last={"moved":false,"clear":false,"reason":"NATIVE_MOTION_BLOCKED","blocker_id":hit.get_collider_id(),"blocked_collider":hit.get_collider_id(),"attempted_motion":target.origin-start.origin,"allowed_motion":body.global_position-start.origin,"body_pose":body.global_transform,"flex":flex}
			reason=last.reason
			return last.duplicate(true)
		# Translation already used the native sweep. Arbitrary rotation/profile
		# has an independent conservative occupied-volume certificate above.
		body.global_basis=pose.basis
		_apply_profile(lerpf(from_flex,target_flex,t))
		if not _native_departures.is_empty() and _departure_depths(body.global_transform,flex).is_empty():_native_departures.clear()
	measured_velocity=(body.global_position-start.origin)/delta
	last.merge({"moved":true,"body_pose":body.global_transform,"flex":flex,"attempted_motion":target.origin-start.origin,"allowed_motion":body.global_position-start.origin,"blocked_collider":0,"measured_velocity":measured_velocity,"native_overlap_recovery_steps":manual_recovery_steps},true)
	reason="MOVED"
	return last.duplicate(true)

func standing_clear(pose:Transform3D)->Dictionary:
	return _audit(pose,0,SKIN)

func lowest_point(value:float)->float:
	var lowest:=INF
	for probe in _probes(value):
		var shape:Shape3D=probe.shape
		var pose:Transform3D=probe.pose
		var extent:=0.0
		if shape is CapsuleShape3D:extent=shape.radius+absf(pose.basis.y.y)*(shape.height*.5-shape.radius)
		elif shape is SphereShape3D:extent=shape.radius
		elif shape is BoxShape3D:extent=absf(pose.basis.x.y)*shape.size.x*.5+absf(pose.basis.y.y)*shape.size.y*.5+absf(pose.basis.z.y)*shape.size.z*.5
		lowest=minf(lowest,pose.origin.y-extent)
	return lowest

func standing_snapshot()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for entry in _baseline:
		result.append({"name":entry.name,"pose":entry.pose,"shape_type":entry.query_shape.get_class(),"bounds_radius":_shape_radius(entry.query_shape)})
	return result

func end_dynamic(velocity:Vector3=Vector3.ZERO)->bool:
	if not active:return true
	if not is_instance_valid(body):
		active=false
		reason="BODY_REMOVED"
		return true
	if absf(flex)>.000001:
		reason="NORMAL_PROFILE_NOT_RESTORED"
		return false
	if not velocity.is_finite() or not standing_clear(body.global_transform).clear:
		reason="STANDING_RESTORE_BLOCKED"
		return false
	var restore:=validate_segment(body.global_transform,body.global_transform,flex,0)
	if not restore.clear:
		reason="STANDING_RESTORE_PATH_BLOCKED"
		return false
	for entry in _baseline:
		entry.node.shape=entry.shape
		entry.node.transform=entry.pose
		entry.node.disabled=entry.disabled
	body.remove_child(_shin)
	_shin.free()
	_shin=null
	flex=0
	body.freeze_mode=_saved.freeze_mode
	body.inertia=_saved.inertia
	body.linear_velocity=velocity.limit_length(3.0)
	body.angular_velocity=Vector3.ZERO
	body.freeze=_saved.freeze
	body.sleeping=false
	active=false
	_ends+=1
	reason="DYNAMIC_RESTORED"
	return true

func diagnostics()->Dictionary:
	return {"active":active,"flex":flex,"reason":reason,"last":last.duplicate(true),"begins":_begins,"ends":_ends,"same_body":true,"profile":"HEEL_BACK","point_step":POINT_STEP,"query_skin":SKIN,"native_touch_tolerance":NATIVE_TOUCH,"lowest_point":lowest_point(flex),"measured_velocity":measured_velocity,"start_contact_audit":start_contact_audit.duplicate(true)}
