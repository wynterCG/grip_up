extends Node
## Third-person ground drive for the SAME RigidBody used by climbing.
## Only active with feet on a walkable surface and both hands free.
var torso: RigidBody3D
var controller: Node
var camera: Camera3D
var tuning: Resource
var move_intent := Vector2.ZERO
var enabled := true
var grounded := false
var ground_normal := Vector3.UP
var applied_force := Vector3.ZERO
var applied_torque := Vector3.ZERO
var walking := false
var support_body: PhysicsBody3D
var desired_facing := Vector3.FORWARD

func configure(body: RigidBody3D, grip_controller: Node, view: Camera3D) -> void:
	torso = body
	controller = grip_controller
	tuning = controller.tuning
	camera = view
	desired_facing = (-body.global_basis.z).slide(Vector3.UP).normalized()

func has_climbing_intent() -> bool:
	for hand in 2:
		if controller.tuning.allow_out_of_reach_grip_targets and controller.get_hand_state(hand)=="REACHING" and controller.pending_diagnostics(hand).get("active",false):continue
		if controller.get_hand_state(hand) in ["REACHING","ATTACHED","SLIPPING"]:
			return true
	if controller.tuning.physical_feet and controller.feet_solver!=null and not grounded:
		return controller.feet_solver.feet.any(func(foot):return foot.state in ["SUPPORTING","SLIDING"])
	return false

func _physics_process(_delta: float) -> void:
	applied_force = Vector3.ZERO
	applied_torque = Vector3.ZERO
	walking = false
	grounded = false
	support_body = null
	if not is_instance_valid(torso):
		return
	var sole: Vector3 = torso.to_global(tuning.foot_base_offset)
	var query := PhysicsRayQueryParameters3D.create(sole + Vector3.UP*0.12,sole-Vector3.UP*0.30,3,[torso.get_rid()])
	var hit := torso.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.normal.dot(Vector3.UP)>0.65 and torso.global_basis.y.dot(Vector3.UP)>0.6:
		var half: Vector3 = tuning.foot_base_size*0.5
		var extent: float = absf(hit.normal.dot(torso.global_basis.x))*half.x + absf(hit.normal.dot(torso.global_basis.y))*half.y + absf(hit.normal.dot(torso.global_basis.z))*half.z
		var gap: float = hit.normal.dot(sole-hit.position)-extent
		if gap<=0.018 and gap>=-0.04:
			grounded = true
			ground_normal = hit.normal
			support_body = hit.collider
	controller.grounded_for_walking = grounded
	if not grounded or has_climbing_intent():
		return
	var forward := -camera.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var input := move_intent.limit_length(1.0) if enabled else Vector2.ZERO
	var direction := right*input.x-forward*input.y
	var desired_velocity: Vector3 = direction*tuning.walk_speed
	var support_velocity := Vector3.ZERO
	if support_body is RigidBody3D:
		var support_center: Vector3 = support_body.global_transform*support_body.center_of_mass
		var state := PhysicsServer3D.body_get_direct_state(support_body.get_rid())
		if state != null:
			support_center = support_body.global_position+state.center_of_mass
		support_velocity = support_body.linear_velocity+support_body.angular_velocity.cross(hit.position-support_center)
	elif support_body is StaticBody3D:
		support_velocity = support_body.constant_linear_velocity+support_body.constant_angular_velocity.cross(hit.position-support_body.global_position)
	var horizontal_velocity := (torso.linear_velocity-support_velocity).slide(ground_normal)
	# A finite motor force, never an assigned transform/velocity. Brake on ground.
	var acceleration: float = tuning.walk_acceleration if direction.length_squared()>0.001 else tuning.walk_braking
	applied_force = ((desired_velocity-horizontal_velocity)*torso.mass*tuning.walk_response).limit_length(torso.mass*acceleration).slide(ground_normal)
	torso.apply_central_force(applied_force)
	var upright: Vector3 = torso.global_basis.y.cross(ground_normal)*tuning.walk_upright_stiffness
	var support_spin: Vector3 = support_body.angular_velocity if support_body is RigidBody3D else support_body.constant_angular_velocity if support_body is StaticBody3D else Vector3.ZERO
	var relative_spin: Vector3 = torso.angular_velocity-support_spin
	var damping: Vector3 = -relative_spin.slide(Vector3.UP)*tuning.walk_angular_damping
	if direction.length_squared()>0.01:
		desired_facing = direction.normalized()
		walking = true
	var facing := (-torso.global_basis.z).slide(Vector3.UP).normalized()
	var error := facing.signed_angle_to(desired_facing,Vector3.UP)
	var turn_speed: float = clampf(error*tuning.walk_turn_response,-tuning.walk_max_turn_speed,tuning.walk_max_turn_speed)
	var yaw: float = (turn_speed-relative_spin.y)*tuning.walk_turn_damping
	applied_torque = (upright+damping+Vector3.UP*yaw).limit_length(tuning.walk_max_torque)
	torso.apply_torque(applied_torque)
	if support_body is RigidBody3D:
		var player_center: Vector3 = torso.global_transform*torso.center_of_mass
		support_body.apply_force(-applied_force,hit.position-support_body.global_position)
		support_body.apply_torque(-applied_torque-(player_center-hit.position).cross(applied_force))
