extends RefCounted
## P2: a feasible support-loaded tilt preference, never a next-hold target.
## The controller crossfades this request with the old v0.4 tilt request under
## the same shared torque cap and the same paired grip-moment reaction path.
var blend := 0.0
var target_up := Vector3.UP
var target_rate := Vector3.ZERO
var _initialized := false
var _authority := 0.0
var _diagnostics: Dictionary = {}

func reset() -> void:
	blend = 0.0
	target_up = Vector3.UP
	target_rate = Vector3.ZERO
	_initialized = false
	_authority = 0.0
	_diagnostics.clear()

func evaluate(controller: Node, attached: Array[int], center: Vector3, moments: Vector3, force_sum: float, delta: float, enabled: bool, reference_right: Vector3) -> Vector3:
	if attached.is_empty():
		reset()
		return Vector3.ZERO
	if not enabled and blend==0.0:
		reset()
		return Vector3.ZERO
	blend = move_toward(blend,1.0 if enabled else 0.0,delta/maxf(.001,controller.tuning.transfer_posture_blend_time))
	if not _initialized:
		target_up = controller.torso.global_basis.y.normalized()
		target_rate = Vector3.ZERO
		_initialized = true
	var preferred_up := Vector3.UP
	var state := PhysicsServer3D.body_get_direct_state(controller.torso.get_rid())
	if state!=null and state.total_gravity.length_squared()>.001:
		preferred_up = -state.total_gravity.normalized()
	var right := reference_right.slide(preferred_up)
	if right.length_squared()<.000001:
		right = controller.torso.global_basis.x.slide(preferred_up)
	var feasible := right.length_squared()>.000001
	var basis := Basis.IDENTITY
	if feasible:
		right = right.normalized()
		basis = Basis(right,preferred_up,right.cross(preferred_up).normalized())
	var minimum_margin := INF
	var engaged := 0.0
	var allocation := 0.0
	var slipping := false
	for id in attached:
		var hand: Dictionary = controller.hands[id]
		slipping = slipping or hand.state=="SLIPPING"
		var local: Vector3 = controller.tuning.shoulder_left if id==0 else controller.tuning.shoulder_right
		var shoulder: Vector3 = center+basis*(local-controller.torso.center_of_mass)
		var offset: Vector3 = hand.anchor.world_point()-shoulder
		var length := offset.length()
		var margin: float = controller.tuning.max_arm_length+controller.tuning.max_elastic_extension-length
		minimum_margin = minf(minimum_margin,margin)
		feasible = feasible and margin>=0.0 and length>=controller.tuning.min_arm_length-.03 and offset.dot(preferred_up)>.025
		var weight: float = maxf(0.0,hand.allocation)
		allocation += weight
		engaged += weight*smoothstep(0.0,maxf(.001,controller.tuning.grip_blend_duration),hand.blend_elapsed)
	var previous: Dictionary = controller.telemetry()
	var saturated: bool = float(previous.get("budget_scale",1.0))<.95 or force_sum>controller.tuning.total_pull_force_budget*.92
	var reason := "support_loaded_preferred_tilt"
	if not feasible:
		reason = "infeasible_current_shoulder_geometry"
	elif slipping:
		reason = "grip_slipping"
	elif saturated:
		reason = "effort_saturated"
	var advance: bool = enabled and feasible and not slipping and not saturated
	var axis := target_up.cross(preferred_up)
	var angle := target_up.angle_to(preferred_up)
	var desired_rate := Vector3.ZERO
	if advance and axis.length_squared()>.000001:
		var stop_speed: float = maxf(0.0,sqrt(maxf(0.0,2.0*controller.tuning.transfer_posture_max_acceleration*angle))-controller.tuning.transfer_posture_max_acceleration*delta)
		desired_rate = axis.normalized()*minf(controller.tuning.transfer_posture_max_rate,stop_speed)
	var prior_rate := target_rate
	target_rate = target_rate.move_toward(desired_rate,maxf(0.0,controller.tuning.transfer_posture_max_acceleration)*delta)
	var actual_step := 0.0
	if axis.length_squared()>.000001:
		actual_step = minf(angle,maxf(0.0,target_rate.dot(axis.normalized()))*delta)
		if actual_step>0.0:
			target_up = target_up.rotated(axis.normalized(),actual_step).normalized()
	var body_weight: float = controller.torso.mass*9.8
	var load_authority := clampf(force_sum/maxf(1.0,body_weight),0.0,1.0)
	var desired_authority: float = load_authority if advance else 0.0
	_authority = move_toward(_authority,desired_authority,delta/.10)
	var manual: float = 1.0-.8*minf(1.0,controller._swing_requested.length())
	var error: Vector3 = controller.torso.global_basis.y.normalized().cross(target_up)
	var spin: Vector3 = controller.torso.angular_velocity.slide(target_up)
	var request: Vector3 = (error*controller.tuning.posture_tilt_stiffness-spin*controller.tuning.posture_tilt_damping-moments.slide(preferred_up)*controller.tuning.posture_gravity_moment_compensation)*(_authority*manual*engaged/maxf(.000001,allocation))
	_diagnostics = {"blend":blend,"active":enabled,"advance":advance,"reason":reason,"feasible":feasible,
		"preferred_up":preferred_up,"target_up":target_up,"target_rate":target_rate,"target_acceleration":(target_rate-prior_rate)/maxf(.000001,delta),
		"actual_target_step":actual_step,"geometry_margin":minimum_margin,"authority":_authority,"manual_authority":manual,
		"load_authority":load_authority,"requested_torque":request,"tilt_error":error.length(),"slipping":slipping,"saturated":saturated,
		"source":"current_material_anchors_load_COM_and_anatomical_shoulders_only"}
	return request

func diagnostics() -> Dictionary:
	return _diagnostics.duplicate(true)
