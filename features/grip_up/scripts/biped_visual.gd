extends Node3D
## Render-only rig. Targets come from the physical controller, never the mouse.
const Model = preload("res://features/grip_up/assets/characters/quaternius_mannequin/mannequin.glb")
const LegMotion = preload("res://features/grip_up/scripts/biped_leg_motion.gd")
var torso: RigidBody3D
var controller: Node
var skeleton: Skeleton3D
var character: Node3D
var targets: Array[Node3D] = []
var poles: Array[Node3D] = []
var hand_directions: Array[Vector3] = [Vector3.UP, Vector3.UP]
var palms: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var ground_motor: Node
var step_phase := 0.0
var gait_weight := 0.0
var leg_motion = LegMotion.new()
var foot_clearance: Array[float] = []
var toe_offsets: Array[Vector2] = []
var ik: TwoBoneIK3D
var free_aim_ik: TwoBoneIK3D
var hand_pose: SkeletonModifier3D
var animation: AnimationPlayer
var animation_clip := "A_TPose"

func configure(body: RigidBody3D, physical_controller: Node) -> void:
	torso = body
	controller = physical_controller
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_priority = -50
	character = Model.instantiate()
	character.position = controller.tuning.model_visual_offset
	character.rotation.y = controller.tuning.model_y_rotation
	add_child(character)
	skeleton = character.find_children("*", "Skeleton3D", true, false)[0]
	animation = character.find_children("*", "AnimationPlayer", true, false)[0]
	animation.play("A_TPose")
	animation.advance(0.0)
	var rest_hips: Array[Vector3] = []
	var rest_feet: Array[Vector3] = []
	var lengths: Array[float] = []
	var skeleton_to_body := global_transform.affine_inverse()*skeleton.global_transform
	for suffix in ["l","r"]:
		var hip: Vector3 = skeleton_to_body*skeleton.get_bone_global_rest(skeleton.find_bone("thigh_"+suffix)).origin
		var knee: Vector3 = skeleton_to_body*skeleton.get_bone_global_rest(skeleton.find_bone("calf_"+suffix)).origin
		var foot: Vector3 = skeleton_to_body*skeleton.get_bone_global_rest(skeleton.find_bone("foot_"+suffix)).origin
		var toe: Vector3 = skeleton_to_body*skeleton.get_bone_global_rest(skeleton.find_bone("ball_leaf_"+suffix)).origin
		rest_hips.append(hip)
		rest_feet.append(foot)
		lengths.append(hip.distance_to(knee)+knee.distance_to(foot))
		foot_clearance.append(foot.y-(controller.tuning.foot_base_offset.y-controller.tuning.foot_base_size.y*0.5))
		toe_offsets.append(Vector2(absf(toe.z-foot.z),foot.y-toe.y))
	leg_motion.configure(rest_hips,rest_feet,lengths)
	controller.configure_feet(rest_hips,rest_feet,lengths,foot_clearance)
	leg_motion.reset(torso.global_transform,torso.linear_velocity,torso.angular_velocity)
	for i in 4:
		var target := Node3D.new()
		target.name = "LimbTarget%d" % i
		add_child(target)
		targets.append(target)
		var pole := Node3D.new()
		pole.name = "LimbPole%d" % i
		add_child(pole)
		poles.append(pole)
	_update_targets()
	ik = TwoBoneIK3D.new()
	ik.name = "PhysicalLimbIK"
	skeleton.add_child(ik)
	ik.setting_count = 4
	for i in 4:
		var side := "l" if i % 2 == 0 else "r"
		ik.set_root_bone_name(i, ("upperarm_" if i < 2 else "thigh_") + side)
		ik.set_middle_bone_name(i, ("lowerarm_" if i < 2 else "calf_") + side)
		ik.set_end_bone_name(i, ("hand_" if i < 2 else "foot_") + side)
		ik.set_target_node(i, ik.get_path_to(targets[i]))
		ik.set_pole_node(i, ik.get_path_to(poles[i]))
		ik.set_extend_end_bone(i, false)
	# Ground locomotion keeps its authored legs while contextual hands can aim.
	free_aim_ik = TwoBoneIK3D.new()
	free_aim_ik.name = "ContextualGroundArms"
	free_aim_ik.influence = 0.0
	skeleton.add_child(free_aim_ik)
	free_aim_ik.setting_count = 2
	for i in 2:
		var side := "l" if i==0 else "r"
		free_aim_ik.set_root_bone_name(i,"upperarm_"+side)
		free_aim_ik.set_middle_bone_name(i,"lowerarm_"+side)
		free_aim_ik.set_end_bone_name(i,"hand_"+side)
		free_aim_ik.set_target_node(i,free_aim_ik.get_path_to(targets[i]))
		free_aim_ik.set_pole_node(i,free_aim_ik.get_path_to(poles[i]))
		free_aim_ik.set_extend_end_bone(i,false)
	var Pose = load("res://features/grip_up/scripts/biped_hand_pose.gd")
	hand_pose = Pose.new()
	hand_pose.name = "PalmAlignment"
	hand_pose.visual = self
	skeleton.add_child(hand_pose)

func _process(delta: float) -> void:
	if is_instance_valid(torso):
		_update_ground_animation(delta)
		_update_targets(delta)

func _update_ground_animation(delta: float) -> void:
	var on_ground: bool = is_instance_valid(ground_motor) and ground_motor.grounded and not ground_motor.has_climbing_intent()
	if torso.has_meta("adaptive_legs") and torso.get_meta("adaptive_legs").achieved_flex>.001:on_ground=false
	var speed: float = torso.linear_velocity.slide(Vector3.UP).length()
	var clip := ("Walk" if speed>0.12 else "Idle") if on_ground else "A_TPose"
	if clip!=animation_clip:
		animation_clip = clip
		animation.play(clip,0.16)
	animation.speed_scale = clampf(speed/controller.tuning.walk_speed,0.25,1.5) if clip=="Walk" else 1.0
	# The ground gait is authored. Physical endpoint IK takes over when reaching;
	# no animation track drives the RigidBody or changes its grip targets.
	var weight := 0.0 if on_ground else 1.0
	ik.influence = lerpf(ik.influence,weight,1.0-exp(-24.0*delta))
	if absf(ik.influence-weight)<0.001:
		ik.influence = weight
	var reaching: bool = controller.control_profile in [3,4] and controller.hands.any(func(hand):return hand.state=="REACHING")
	var aim_weight := 1.0 if on_ground and (controller.control_profile==2 or reaching) else 0.0
	free_aim_ik.influence=lerpf(free_aim_ik.influence,aim_weight,1.0-exp(-24.0*delta))
	hand_pose.influence = maxf(ik.influence,free_aim_ik.influence)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(torso):
		return
	var grounded: bool = is_instance_valid(ground_motor) and ground_motor.grounded
	var speed: float = clampf(torso.linear_velocity.slide(Vector3.UP).length()/controller.tuning.walk_speed,0,1)
	gait_weight = lerpf(gait_weight,speed if grounded else 0.0,1.0-exp(-delta/0.12))
	if grounded:
		step_phase += torso.linear_velocity.slide(Vector3.UP).length()*TAU/0.65*delta
	var contacts: Array[Vector3] = [Vector3.INF,Vector3.INF]
	var has_foot_support := false
	for i in 2:
		var foot: Vector3 = torso.global_transform*leg_motion.rest_feet[i] if grounded else leg_motion.get_foot_world(i)
		var lift := 0.0
		if gait_weight>0.001:
			var phase := step_phase+(PI if i==1 else 0.0)
			foot += torso.global_basis.z*cos(phase)*0.16*gait_weight
			lift = maxf(0,sin(phase))*0.10*gait_weight
		var floor_query := PhysicsRayQueryParameters3D.create(foot+Vector3.UP*0.18,foot-Vector3.UP*(foot_clearance[i]+0.025),3,[torso.get_rid()])
		var floor_hit := get_world_3d().direct_space_state.intersect_ray(floor_query)
		if not floor_hit.is_empty() and floor_hit.normal.y>0.6:
			foot.y = floor_hit.position.y+foot_clearance[i]+lift
			var hip: Vector3 = torso.global_transform*leg_motion.hips[i]
			if hip.distance_to(foot)<=leg_motion.leg_lengths[i]+0.005:
				contacts[i] = foot
				has_foot_support = true
	leg_motion.step(delta,torso.global_transform,torso.linear_velocity,torso.angular_velocity,has_foot_support,contacts)
	for i in 2:
		var hip: Vector3 = torso.global_transform*leg_motion.hips[i]
		var endpoint: Vector3 = leg_motion.get_foot_world(i)
		var query := PhysicsRayQueryParameters3D.create(hip,endpoint-Vector3.UP*foot_clearance[i],3,[torso.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			leg_motion.constrain_foot(i,hit.position+hit.normal*foot_clearance[i],hit.normal)
		var direction: Vector3 = leg_motion.directions[i]
		var forward := (-torso.global_basis.z).slide(direction)
		if forward.length_squared()<0.001:
			forward = torso.global_basis.x.cross(direction)
		var toe_offset: Vector3 = forward.normalized()*toe_offsets[i].x+direction*toe_offsets[i].y
		endpoint = leg_motion.get_foot_world(i)
		var toe_query := PhysicsRayQueryParameters3D.create(endpoint,endpoint+toe_offset,3,[torso.get_rid()])
		var toe_hit := get_world_3d().direct_space_state.intersect_ray(toe_query)
		if not toe_hit.is_empty():
			leg_motion.constrain_foot(i,toe_hit.position+toe_hit.normal*0.015-toe_offset,toe_hit.normal)
	if controller.tuning.physical_feet and controller.feet_solver!=null:
		for i in 2:
			if controller.feet_solver.feet[i].state in ["PLANTING","SUPPORTING","SLIDING"]:
				leg_motion.constrain_foot(i,controller.feet_solver.get_foot_world(i),Vector3.ZERO)
				var hip: Vector3 = torso.global_transform*leg_motion.hips[i]
				var direction: Vector3 = leg_motion.directions[i]
				var forward: Vector3 = (-torso.global_basis.z).slide(direction)
				if forward.length_squared()<0.001:
					forward = torso.global_basis.x.cross(direction)
				var pole: Vector3 = hip+direction*leg_motion.current_lengths[i]*0.5+forward.normalized()*0.48
				leg_motion.poles[i] = leg_motion.poles[i].lerp(pole,1.0-exp(-12.0*delta))
	if torso.has_meta("adaptive_legs"):
		var physical_legs=torso.get_meta("adaptive_legs")
		if physical_legs.active:
			var pose:Dictionary=physical_legs.pose_for(physical_legs.achieved_flex)
			var shift:Vector3=pose.sole.origin-controller.tuning.foot_base_offset
			for i in 2:
				var endpoint:Vector3=torso.global_transform*(leg_motion.rest_feet[i]+shift)
				if controller.feet_solver!=null:
					var foot:Dictionary=controller.feet_solver.feet[i]
					var mismatch:Vector3=foot.ankle-endpoint
					if foot.state in ["SUPPORTING","SLIDING"] and absf(mismatch.dot(foot.normal))<=.005 and mismatch.slide(foot.normal).length()<=.08:endpoint=foot.ankle
				leg_motion.constrain_foot(i,endpoint,Vector3.ZERO)
				leg_motion.poles[i]=torso.global_transform*(pose.knee+Vector3((-1.0 if i==0 else 1.0)*.1,0,-.1))
	controller.free_foot_positions = leg_motion.feet.duplicate()

func _update_targets(delta: float = 1.0) -> void:
	global_transform = torso.get_global_transform_interpolated()
	var render_correction := global_transform * torso.global_transform.affine_inverse()
	for i in 2:
		var shoulder: Vector3 = render_correction * controller.get_shoulder_world(i)
		var palm: Vector3 = render_correction * controller.get_hand_world(i)
		var hand: Dictionary = controller.hands[i]
		var pending:Dictionary=controller.pending_diagnostics(i)
		if not pending.get("endpoint_valid",true):
			# An impossible swept-workspace conflict cancels the attempt. Show a
			# passive pose, never the invalid historical endpoint as a real hand.
			var passive_offset:Vector3=controller.tuning.free_hand_rest_left if i==0 else controller.tuning.free_hand_rest_right
			palm=shoulder+(global_basis*passive_offset).limit_length(controller.get_max_reach())
		if hand.state in ["ATTACHED","SLIPPING"] and hand.anchor != null and hand.anchor.is_valid():
			var support: PhysicsBody3D = hand.anchor.support_body()
			palm = support.get_global_transform_interpolated() * hand.anchor.local_point
		palms[i] = palm
		var direction := (palm - shoulder).normalized()
		if direction.length_squared() < 0.5:
			direction = -global_basis.y
		hand_directions[i] = direction
		targets[i].global_position = palm - direction * controller.tuning.palm_contact_offset
		var side := -1.0 if i == 0 else 1.0
		var pole_offset := Vector3(side * 0.10,-0.50,0.20) if hand.state in ["FREE","RELEASED"] else Vector3(side * 0.48,-0.15,0.36)
		# Ease the elbow plane when attaching; avoid an abrupt visual flip.
		poles[i].global_position = poles[i].global_position.lerp(shoulder + global_basis * pole_offset,1.0-exp(-14.0*delta))
		var alpha := Engine.get_physics_interpolation_fraction()
		targets[i+2].global_position = leg_motion.previous_feet[i].lerp(leg_motion.feet[i],alpha)
		poles[i+2].global_position = leg_motion.previous_poles[i].lerp(leg_motion.poles[i],alpha)
