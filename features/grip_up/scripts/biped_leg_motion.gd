extends RefCounted
## Passive, render-only leg pendulums. They never apply forces to the torso.
var gravity := Vector3.DOWN*9.8
var coordination_stiffness := 6.0
var coordination_damping := 2.2
var hips: Array[Vector3] = []
var rest_feet: Array[Vector3] = []
var leg_lengths: Array[float] = []
var feet: Array[Vector3] = []
var previous_feet: Array[Vector3] = []
var poles: Array[Vector3] = []
var previous_poles: Array[Vector3] = []
var directions: Array[Vector3] = []
var angular_velocities: Array[Vector3] = []
var hip_velocities: Array[Vector3] = []
var filtered_accelerations: Array[Vector3] = []
var current_lengths: Array[float] = []
var _pose := Transform3D.IDENTITY

func configure(hip_points: Array[Vector3], foot_points: Array[Vector3], lengths: Array[float]) -> void:
	hips = hip_points.duplicate()
	rest_feet = foot_points.duplicate()
	leg_lengths = lengths.duplicate()

func reset(pose: Transform3D, velocity := Vector3.ZERO, spin := Vector3.ZERO) -> void:
	_pose = pose
	feet.clear()
	previous_feet.clear()
	poles.clear()
	previous_poles.clear()
	directions.clear()
	angular_velocities.clear()
	hip_velocities.clear()
	filtered_accelerations.clear()
	current_lengths.clear()
	for i in hips.size():
		var hip := pose*hips[i]
		var offset := pose.basis*(rest_feet[i]-hips[i])
		directions.append(offset.normalized())
		current_lengths.append(minf(offset.length(),leg_lengths[i]*0.999))
		feet.append(hip+directions[i]*current_lengths[i])
		previous_feet.append(feet[i])
		poles.append(hip+pose.basis*Vector3(0,-0.3,-0.55))
		previous_poles.append(poles[i])
		angular_velocities.append(Vector3.ZERO)
		hip_velocities.append(velocity+spin.cross(pose.basis*hips[i]))
		filtered_accelerations.append(Vector3.ZERO)

func step(delta: float, pose: Transform3D, velocity: Vector3, spin: Vector3, grounded: bool, ground_targets: Array[Vector3]) -> void:
	if delta<=0:
		return
	_pose = pose
	var substeps := maxi(1,ceili(delta*120.0))
	var dt := delta/float(substeps)
	# Symmetric soft coupling damps only disagreement between the legs. Their
	# common swing remains free; a planted foot keeps its independent target.
	var shared_direction := Vector3.ZERO
	var shared_spin := Vector3.ZERO
	if not grounded and directions.size()==2:
		shared_direction = (directions[0]+directions[1]).normalized()
		shared_spin = (angular_velocities[0]+angular_velocities[1])*0.5
	for i in hips.size():
		previous_feet[i] = feet[i]
		previous_poles[i] = poles[i]
		var hip := pose*hips[i]
		var hip_velocity := velocity+spin.cross(pose.basis*hips[i])
		var acceleration := ((hip_velocity-hip_velocities[i])/delta).limit_length(35.0)
		filtered_accelerations[i] = filtered_accelerations[i].lerp(acceleration,1.0-exp(-18.0*delta))
		hip_velocities[i] = hip_velocity
		if grounded and i<ground_targets.size() and ground_targets[i].is_finite():
			var target := feet[i].move_toward(ground_targets[i],minf(4.0*delta,feet[i].distance_to(ground_targets[i])*(1.0-exp(-22.0*delta))))
			_set_foot(i,target)
			var relative_velocity := (feet[i]-previous_feet[i])/delta-hip_velocity
			angular_velocities[i] = directions[i].cross(relative_velocity/maxf(current_lengths[i],0.05)).limit_length(6.0)
		else:
			var coordination := Vector3.ZERO
			if shared_direction.length_squared()>0.5:
				coordination = directions[i].cross(shared_direction)*coordination_stiffness+(shared_spin-angular_velocities[i])*coordination_damping
			for substep in substeps:
				var effective_gravity := gravity-filtered_accelerations[i]
				var rest_axis := (pose.basis*(rest_feet[i]-hips[i])).normalized()
				var angular_acceleration := directions[i].cross(effective_gravity)/maxf(current_lengths[i],0.2)+directions[i].cross(rest_axis)*1.2
				angular_acceleration += coordination
				angular_velocities[i] = (angular_velocities[i]*exp(-0.85*dt)+angular_acceleration*dt).limit_length(6.0)
				angular_velocities[i] = angular_velocities[i].slide(directions[i])
				var speed := angular_velocities[i].length()
				if speed>0.00001:
					directions[i] = (Basis(angular_velocities[i]/speed,speed*dt)*directions[i]).normalized()
				# Fully suspended legs extend; only a real surface target bends them.
				var extended := leg_lengths[i]*0.999
				current_lengths[i] = move_toward(current_lengths[i],extended,minf(0.85*dt,(extended-current_lengths[i])*(1.0-exp(-22.0*dt))))
				_limit_hip(i,pose)
			feet[i] = hip+directions[i]*current_lengths[i]
		var forward := (-pose.basis.z).slide(directions[i])
		if forward.length_squared()<0.001:
			forward = pose.basis.x.cross(directions[i])
		var pole_target := hip+directions[i]*current_lengths[i]*0.5+forward.normalized()*0.48
		poles[i] = poles[i].lerp(pole_target,1.0-exp(-12.0*delta))

func _limit_hip(i: int, pose: Transform3D) -> void:
	var down := -pose.basis.y
	var angle := down.angle_to(directions[i])
	if angle>1.92:
		var axis := down.cross(directions[i])
		if axis.length_squared()<0.001:
			axis = pose.basis.x
		directions[i] = Basis(axis.normalized(),1.92)*down
		angular_velocities[i] *= 0.5

func _set_foot(i: int, point: Vector3) -> void:
	var hip := _pose*hips[i]
	var offset := point-hip
	current_lengths[i] = clampf(offset.length(),leg_lengths[i]*0.18,leg_lengths[i]*0.999)
	if offset.length_squared()>0.0001:
		directions[i] = offset.normalized()
	feet[i] = hip+directions[i]*current_lengths[i]

func constrain_foot(i: int, point: Vector3, normal: Vector3) -> void:
	_set_foot(i,point)
	var foot_velocity := hip_velocities[i]+angular_velocities[i].cross(directions[i])*current_lengths[i]
	if foot_velocity.dot(normal)<0:
		foot_velocity = foot_velocity.slide(normal)
	angular_velocities[i] = directions[i].cross((foot_velocity-hip_velocities[i])/maxf(current_lengths[i],0.05)).limit_length(6.0)

func get_foot_world(i: int) -> Vector3:
	return feet[i]

func get_knee_pole_world(i: int) -> Vector3:
	return poles[i]
