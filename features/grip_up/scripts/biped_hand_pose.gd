extends SkeletonModifier3D
## Keep the palm contact offset aligned after the arm solver. Render only.
var visual: Node3D

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if not is_instance_valid(visual) or not is_instance_valid(skeleton):
		return
	for i in 2:
		var suffix := "l" if i == 0 else "r"
		var hand := skeleton.find_bone("hand_" + suffix)
		var finger := skeleton.find_bone("middle_01_" + suffix)
		if finger < 0:
			finger = skeleton.find_bone("index_01_" + suffix)
		var pose := skeleton.get_bone_global_pose(hand)
		var local_axis: Vector3 = skeleton.get_bone_rest(finger).origin.normalized() if finger >= 0 else Vector3.RIGHT
		var old_direction := (pose.basis * local_axis).normalized()
		var direction: Vector3 = (skeleton.global_basis.inverse() * visual.hand_directions[i]).normalized()
		pose.basis = Basis(Quaternion(old_direction, direction)) * pose.basis
		skeleton.set_bone_global_pose(hand, pose)
