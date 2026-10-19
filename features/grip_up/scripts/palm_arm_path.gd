extends RefCounted
## Current geometric witness: measured total arm chain with a declared two-link
## split, plus finite palm length. These are virtual links, not limb rigidbodies.
## Does not move a hand or authorize force/contact on its own.
const UPPER_LENGTH:=.27000
const LOWER_LENGTH:=.27708
const PALM_LENGTH:=.11000
const ARM_RADIUS:=.020

func _segment_clear(controller:Node,a:Vector3,b:Vector3)->bool:
	var offset:=b-a
	if offset.length()<.00001:return false
	var y:=offset.normalized()
	var x:=y.cross(Vector3.UP).normalized()
	if x.length_squared()<.5:x=y.cross(Vector3.RIGHT).normalized()
	var shape:=CapsuleShape3D.new()
	shape.radius=ARM_RADIUS
	shape.height=offset.length()+2*ARM_RADIUS
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform=Transform3D(Basis(x,y,x.cross(y)),(a+b)*.5)
	query.collision_mask=controller.tuning.allowed_grip_surface_mask
	query.exclude=[controller.torso.get_rid()]
	query.margin=0
	return controller.torso.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func evaluate(controller:Node,shoulder:Vector3,palm:Vector3,normal:Vector3,material:PhysicsBody3D)->Dictionary:
	var result:Dictionary={"valid":false,"reason":"BENT_ARM_UNAVAILABLE"}
	if not is_instance_valid(material) or normal.dot(Vector3.UP)<.85:return result
	if shoulder.distance_to(palm)>controller.get_max_reach()+.00005:
		result.reason="BENT_ARM_PALM_OUT_OF_REACH"
		return result
	var outward:Vector3=(shoulder-palm).slide(normal).normalized()
	if outward.length_squared()<.5:outward=controller.torso.global_basis.z.slide(normal).normalized()
	if outward.length_squared()<.5:return result
	var surface:String=controller.palm_solver.check_surface(controller,material,palm,normal,controller.torso.global_basis.x.slide(normal).normalized())
	if surface!="":
		result.reason=surface
		return result
	# Palm points into the platform, wrist remains above and toward free space.
	# This is a finite 110 mm hand segment, not extra shoulder-to-wrist anatomy.
	var wrist:Vector3=palm+outward*sqrt(PALM_LENGTH*PALM_LENGTH-.025*.025)+normal*.025
	var offset:Vector3=wrist-shoulder
	var distance:float=offset.length()
	if distance>UPPER_LENGTH+LOWER_LENGTH or distance<absf(UPPER_LENGTH-LOWER_LENGTH)+.0001:
		result.reason="BENT_ARM_WRIST_OUT_OF_CHAIN"
		return result
	var axis:Vector3=offset/distance
	var along:float=(UPPER_LENGTH*UPPER_LENGTH-LOWER_LENGTH*LOWER_LENGTH+distance*distance)/(2*distance)
	var radius:float=sqrt(maxf(0.0,UPPER_LENGTH*UPPER_LENGTH-along*along))
	var center:Vector3=shoulder+axis*along
	var right:Vector3=normal.cross(outward).normalized()
	for lateral in [0.0,-.65,.65,-1.3,1.3]:
		var pole:Vector3=(outward+normal*.65+right*lateral).slide(axis).normalized()
		if pole.length_squared()<.5:continue
		var elbow:Vector3=center+pole*radius
		if not _segment_clear(controller,shoulder,elbow) or not _segment_clear(controller,elbow,wrist):continue
		var query:=PhysicsRayQueryParameters3D.create(wrist,palm+(palm-wrist).normalized()*.002,controller.tuning.allowed_grip_surface_mask,[controller.torso.get_rid()])
		query.hit_from_inside=true
		var hit:Dictionary=controller.torso.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider!=material or Vector3(hit.position).distance_to(palm)>.003:continue
		var waypoint:Vector3=palm+outward*.18+normal*.12
		return {"valid":true,"reason":"CURRENT_TWO_SEGMENT_ARM_AND_PALM_CLEAR","shoulder":shoulder,"elbow":elbow,"wrist":wrist,"palm":palm,"hand_waypoint":waypoint,"upper_length":UPPER_LENGTH,"lower_length":LOWER_LENGTH,"palm_length":PALM_LENGTH,"arm_radius":ARM_RADIUS,"support_id":material.get_instance_id()}
	result.reason="BENT_ARM_SEGMENT_OBSTRUCTED"
	return result
