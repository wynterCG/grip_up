extends Camera3D

var torso: RigidBody3D
var yaw := 0.24
var elevation := -0.06
var distance := 6.0
var focus := Vector3.ZERO
var controller: Node
var initialized := false

func _ready() -> void:
	fov = 56
	near = 0.08
	current = true
	process_priority = 50
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

func reset(body: RigidBody3D, grip_controller: Node) -> void:
	torso = body
	controller = grip_controller
	focus = body.global_position + Vector3(0, 0.6, 0)
	yaw = 0.24
	elevation = -0.06
	distance = 6.0
	initialized = true
	_update_camera(1.0)

func orbit(relative: Vector2) -> void:
	yaw = clampf(yaw - relative.x * 0.004, -1.25, 1.25)
	elevation = clampf(elevation + relative.y * 0.003, -0.45, 0.85)

func dolly(amount: float) -> void:
	distance = clampf(distance + amount, 3.0, 17.0)

func _process(delta: float) -> void:
	if initialized and is_instance_valid(torso):
		_update_camera(delta)

func _update_camera(delta: float) -> void:
	var body_pose: Transform3D = torso.get_global_transform_interpolated()
	var desired: Vector3 = body_pose.origin + Vector3(0, 0.6, 0)
	desired += torso.linear_velocity.limit_length(3.0) * 0.12
	focus = focus.lerp(desired, 1.0 - exp(-4.5 * delta))
	var extra: float = minf(2.0, torso.linear_velocity.length() * 0.15)
	var offset := Vector3(sin(yaw) * cos(elevation), sin(elevation), cos(yaw) * cos(elevation)) * (distance + extra)
	var target := focus + offset
	var query := PhysicsRayQueryParameters3D.create(focus, target, 3, [torso.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		target = hit.position + hit.normal * 0.25
	global_position = global_position.lerp(target, 1.0 - exp(-10.0 * delta)) if delta < 0.5 else target
	look_at(focus, Vector3.UP)
