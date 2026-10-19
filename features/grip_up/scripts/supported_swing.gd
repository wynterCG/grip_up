extends RefCounted
## A bounded grip-reaction couple, not a force at the center of mass. Its opposite
## moment is transmitted to the currently gripped supports by the controller.
var intent := Vector3.ZERO

func reset() -> void:
	intent = Vector3.ZERO

func evaluate(delta: float, requested: Vector3, lever: Vector3, relative_spin: Vector3, engagement: float, tuning: Resource) -> Vector3:
	var response: float = 1.0-exp(-delta/maxf(0.001,tuning.swing_input_ramp_s))
	intent = intent.lerp(requested.limit_length(1.0),response)
	if lever.length_squared()<0.000001:
		return Vector3.ZERO
	# Rotation of the shoulder opposite the desired travel makes the supported
	# torso move in that direction. The true lever preserves this sign under roll.
	var drive := intent.cross(lever.normalized())
	var strength := drive.length()
	if strength<0.000001:
		return Vector3.ZERO
	var axis := drive/strength
	# A speed-dependent torque falls to zero at the finite target speed and
	# reverses above it. Opposite input therefore brakes existing momentum.
	var governor: float = clampf(1.0-relative_spin.dot(axis)/maxf(0.1,tuning.swing_max_relative_speed),-1.0,1.0)
	return axis*(tuning.swing_max_support_torque*strength*governor*clampf(engagement,0.0,1.0))
