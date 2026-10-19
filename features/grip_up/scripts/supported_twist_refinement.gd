extends RefCounted
## P1 changes only the existing axial twist objective. The controller retains
## the original gains, common torque cap, forces, and opposite support moments.
var blend := 0.0
var reference_right := Vector3.RIGHT
var support_spin := Vector3.ZERO
var _target_right := Vector3.RIGHT
var _support_bases: Dictionary = {}
var _has_frame := false
var _observed_rotation_total := 0.0
var _diagnostics: Dictionary = {}

func reset() -> void:
	blend = 0.0
	reference_right = Vector3.RIGHT
	support_spin = Vector3.ZERO
	_target_right = Vector3.RIGHT
	_support_bases.clear()
	_has_frame = false
	_observed_rotation_total = 0.0
	_diagnostics.clear()

func update(controller: Node, attached: Array[int], delta: float, enabled: bool) -> void:
	if attached.is_empty():
		reset()
		return
	if not enabled and blend==0.0:
		reset()
		return # Never-enabled P0 performs no alternative attitude calculation.
	blend = move_toward(blend,1.0 if enabled else 0.0,delta/maxf(.001,controller.tuning.transfer_twist_blend_time))
	if not _has_frame:
		reference_right = controller._view_right.normalized()
		_target_right = reference_right
		_has_frame = true
	var weights: Dictionary = {}
	var bodies: Dictionary = {}
	var total := 0.0
	for id in attached:
		var hand: Dictionary = controller.hands[id]
		var support: PhysicsBody3D = hand.anchor.support_body()
		var key: int = support.get_instance_id()
		var weight: float = maxf(0.0,hand.allocation)*smoothstep(0.0,maxf(.001,controller.tuning.grip_blend_duration),hand.blend_elapsed)
		weights[key] = float(weights.get(key,0.0))+weight
		bodies[key] = support
		total += weight
	var rotation := Vector3.ZERO
	support_spin = Vector3.ZERO
	var next_bases: Dictionary = {}
	for key in bodies:
		var support: PhysicsBody3D = bodies[key]
		var basis: Basis = support.global_basis.orthonormalized()
		var weight: float = float(weights[key])/maxf(.000001,total)
		if _support_bases.has(key):
			var change: Quaternion = (basis*Basis(_support_bases[key]).transposed()).get_rotation_quaternion().normalized()
			# Use the shortest observed material-frame increment, not predicted
			# integration of spin or a fresh heading reset on hand acquisition.
			if change.w<0.0:
				change = -change
			# Resolve small increments explicitly: normalizing the vector part
			# avoids a near-identity axis losing magnitude at120 Hz.
			var vector := Vector3(change.x,change.y,change.z)
			var sine := vector.length()
			if sine>.00000001:
				rotation += vector/sine*(2.0*atan2(sine,change.w))*weight
		var spin: Vector3 = support.angular_velocity if support is RigidBody3D else support.constant_angular_velocity if support is StaticBody3D else Vector3.ZERO
		support_spin += spin*weight
		next_bases[key] = basis
	_support_bases = next_bases
	_observed_rotation_total += rotation.length()
	if rotation.length_squared()>.000000000001:
		_target_right = _target_right.rotated(rotation.normalized(),rotation.length()).normalized()
	var axis := reference_right.cross(_target_right)
	var angle := reference_right.angle_to(_target_right)
	if axis.length_squared()>.000000000001 and angle>.0000001:
		var response: float = 1.0-exp(-delta/maxf(.001,controller.tuning.transfer_twist_frame_response))
		var step: float = minf(angle*response,maxf(0.0,controller.tuning.transfer_twist_frame_max_rate)*delta)
		reference_right = reference_right.rotated(axis.normalized(),step).normalized()
	_diagnostics = {"blend":blend,"active":enabled,"transitioning":blend>0.0 and blend<1.0,
		"reference_right":reference_right,"material_target_right":_target_right,"support_spin":support_spin,
		"frame_tracking_error":reference_right.angle_to(_target_right),"observed_rotation_total":_observed_rotation_total,"last_material_rotation":rotation,"source":"bounded_material_frame_and_support_relative_axial_rate"}

func correction(axis: Vector3, current_right: Vector3, baseline_twist: Vector3, spin: Vector3, engagement: float, tuning: Resource) -> Vector3:
	if blend<=0.0:
		return Vector3.ZERO
	var target := reference_right.slide(axis)
	var authority := current_right.length_squared()*target.length_squared()
	var refined := Vector3.ZERO
	var error := 0.0
	if authority>.000001:
		error = current_right.normalized().signed_angle_to(target.normalized(),axis)
		var moment: float = error*tuning.twist_stiffness-(spin-support_spin).dot(axis)*tuning.twist_damping
		refined = axis*(moment*authority*engagement)
	var result := (refined-baseline_twist)*blend
	_diagnostics.merge({"axial_error":error,"axial_relative_speed":(spin-support_spin).dot(axis),
		"authority":authority,"baseline_twist":baseline_twist,"refined_twist":refined,"requested_correction":result},true)
	return result

func diagnostics() -> Dictionary:
	return _diagnostics.duplicate(true)
