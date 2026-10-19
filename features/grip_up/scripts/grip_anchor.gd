extends RefCounted
## The same material-local anchor convention as the proven object grabber.
var _support_ref: WeakRef
var local_point: Vector3
var local_normal: Vector3
## Opt-in only for v0.6 held-target anchors. Legacy expressions stay unchanged.
var use_actual_center_of_mass: bool = false

func _init(support: PhysicsBody3D, contact_world: Vector3, normal: Vector3) -> void:
	_support_ref = weakref(support)
	local_point = support.to_local(contact_world)
	local_normal = (support.global_basis.transposed() * normal).normalized()

func support_body() -> PhysicsBody3D:
	return _support_ref.get_ref() as PhysicsBody3D if _support_ref != null else null

func is_valid() -> bool:
	var support := support_body()
	return is_instance_valid(support) and support.is_inside_tree()

func world_point() -> Vector3:
	var support := support_body()
	return support.to_global(local_point) if is_instance_valid(support) else Vector3.ZERO

func world_normal() -> Vector3:
	var support := support_body()
	return (support.global_basis.inverse().transposed() * local_normal).normalized() if is_instance_valid(support) else Vector3.ZERO

func point_velocity() -> Vector3:
	var support := support_body()
	if support is RigidBody3D:
		var center: Vector3 = support.global_transform * support.center_of_mass
		if use_actual_center_of_mass:
			var state := PhysicsServer3D.body_get_direct_state(support.get_rid())
			if state!=null:center = support.global_position+state.center_of_mass
		return support.linear_velocity + support.angular_velocity.cross(world_point() - center)
	if support is StaticBody3D:
		return support.constant_linear_velocity + support.constant_angular_velocity.cross(world_point() - support.global_position)
	return Vector3.ZERO
