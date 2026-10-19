extends Node
## Presentation only. Option B: root/motor owns all world displacement and time.
const Clip=preload("res://features/grip_up/resources/mantle_authored.tres")
const PalmPose=preload("res://features/grip_up/scripts/biped_hand_pose.gd")
const CLIP_NAME="HybridMantle"
var visual:Node3D
var body:RigidBody3D
var player:AnimationPlayer
var mode:="INACTIVE"
var progress:=0.0
var collision_flex:=0.0
var collision_pose:Dictionary={}
var entry_pose:Array[Quaternion]=[]
var exit_pose:Array[Quaternion]=[]
var anchors:Array[Vector3]=[Vector3.INF,Vector3.INF]
var hand_ik:Array[TwoBoneIK3D]=[]
var leg_ik:TwoBoneIK3D
var palm_pose:SkeletonModifier3D
var exit_elapsed:=0.0
var hand_contact_error:Array[float]=[-1.0,-1.0]
var physical_foot_error:Array[float]=[0.0,0.0]
var release_weight:=1.0
var started_count:=0
var finished_count:=0
var last_reason:="NOT_STARTED"
var measured_frames:=0
var release_start:=.48
var release_end:=.78
var ordinary_callback_mode:=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
var last_visual_target:=Transform3D.IDENTITY
var simulation_pose_at_visual_update:=Transform3D.IDENTITY
var visual_target_recorded:=false
var last_measurement:Dictionary={}

func configure(biped:Node3D,physical_body:RigidBody3D)->void:
	visual=biped
	body=physical_body
	visual.mantle_driver=self
	player=AnimationPlayer.new()
	player.name="AuthoredMantlePlayer"
	add_child(player)
	player.root_node=player.get_path_to(visual.skeleton)
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library:=AnimationLibrary.new()
	library.add_animation(CLIP_NAME,Clip)
	player.add_animation_library("",library)
	for id in 2:
		var solver:=TwoBoneIK3D.new()
		solver.name="MantleVisualHand%d"%id
		solver.influence=0.0
		visual.skeleton.add_child(solver)
		solver.setting_count=1
		var suffix:="l" if id==0 else "r"
		solver.set_root_bone_name(0,"upperarm_"+suffix)
		solver.set_middle_bone_name(0,"lowerarm_"+suffix)
		solver.set_end_bone_name(0,"hand_"+suffix)
		solver.set_target_node(0,solver.get_path_to(visual.targets[id]))
		solver.set_pole_node(0,solver.get_path_to(visual.poles[id]))
		solver.set_extend_end_bone(0,false)
		hand_ik.append(solver)
	leg_ik=TwoBoneIK3D.new()
	leg_ik.name="MantleCollisionCoherentLegs"
	leg_ik.influence=0.0
	visual.skeleton.add_child(leg_ik)
	leg_ik.setting_count=2
	for id in 2:
		var suffix:="l" if id==0 else "r"
		leg_ik.set_root_bone_name(id,"thigh_"+suffix)
		leg_ik.set_middle_bone_name(id,"calf_"+suffix)
		leg_ik.set_end_bone_name(id,"foot_"+suffix)
		leg_ik.set_target_node(id,leg_ik.get_path_to(visual.targets[id+2]))
		leg_ik.set_pole_node(id,leg_ik.get_path_to(visual.poles[id+2]))
		leg_ik.set_extend_end_bone(id,false)
	palm_pose=PalmPose.new()
	palm_pose.name="MantlePresentationPalmAlignment"
	palm_pose.visual=visual
	palm_pose.influence=0.0
	visual.skeleton.add_child(palm_pose)
	palm_pose.modification_processed.connect(_measure)

func is_driving()->bool:
	return mode in ["ASSISTED","EXIT_BLEND"]

func begin(candidate:Dictionary)->void:
	if mode=="ASSISTED":return
	if mode=="EXIT_BLEND":visual.animation.callback_mode_process=ordinary_callback_mode
	entry_pose.clear()
	for index in visual.skeleton.get_bone_count():
		entry_pose.append(visual.observed_pose_rotations[index] if visual.observed_pose_rotations.size()==visual.skeleton.get_bone_count() else visual.skeleton.get_bone_pose_rotation(index))
	anchors=[Vector3.INF,Vector3.INF]
	var supplied:Array=candidate.get("hand_anchors_world",[])
	for id in 2:
		if supplied.size()>id and supplied[id] is Vector3:
			anchors[id]=supplied[id]
		elif visual.controller.hands[id].state=="ATTACHED":
			anchors[id]=visual.controller.get_hand_world(id)
	mode="ASSISTED"
	release_start=clampf(float(candidate.get("hand_release_start",.48)),0.0,.95)
	release_end=clampf(float(candidate.get("hand_release_end",.78)),release_start+.01,1.0)
	progress=0.0
	collision_flex=0.0
	collision_pose={}
	started_count+=1
	last_reason="ACTIVE_PRESENTATION_ONLY"
	ordinary_callback_mode=visual.animation.callback_mode_process
	visual.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	visual.animation.pause()
	player.play(CLIP_NAME)
	set_progress(0.0)

func set_collision_pose(flex:float,pose:Dictionary={})->void:
	collision_flex=clampf(flex,0.0,1.0)
	collision_pose=pose.duplicate()

func set_progress(value:float,_dt:float=0.0)->void:
	if mode!="ASSISTED":return
	progress=clampf(value,0.0,1.0)
	_apply_authored_pose()
	_update_targets()

func _apply_authored_pose()->void:
	player.seek(progress*Clip.length,true)
	var blend:=smoothstep(0.0,.15,progress)
	for index in visual.skeleton.get_bone_count():
		var authored:Quaternion=visual.skeleton.get_bone_pose_rotation(index)
		visual.skeleton.set_bone_pose_rotation(index,entry_pose[index].slerp(authored,blend))
	visual.ik.influence=0.0
	visual.free_aim_ik.influence=0.0
	visual.hand_pose.influence=0.0

func update_visual(delta:float)->void:
	if mode=="ASSISTED":
		_apply_authored_pose()
		_update_targets()
	elif mode=="EXIT_BLEND":
		exit_elapsed+=delta
		visual.animation.advance(delta)
		var blend:=smoothstep(0.0,.18,exit_elapsed)
		for index in visual.skeleton.get_bone_count():
			var ordinary:Quaternion=visual.skeleton.get_bone_pose_rotation(index)
			visual.skeleton.set_bone_pose_rotation(index,exit_pose[index].slerp(ordinary,blend))
		for solver in hand_ik:solver.influence=0.0
		leg_ik.influence=1.0-blend
		palm_pose.influence=0.0
		visual.ik.influence=0.0
		visual.free_aim_ik.influence=0.0
		visual.hand_pose.influence=0.0
		_update_targets()
		if exit_elapsed>=.18:
			mode="INACTIVE"
			leg_ik.influence=0.0
			visual.animation.callback_mode_process=ordinary_callback_mode

func _update_targets()->void:
	simulation_pose_at_visual_update=body.global_transform
	visual.global_transform=body.get_global_transform_interpolated()
	last_visual_target=visual.global_transform
	visual_target_recorded=true
	var frame:Transform3D=visual.global_transform
	release_weight=1.0-smoothstep(release_start,release_end,progress) if mode=="ASSISTED" else 0.0
	for id in 2:
		var sign_side:float=-1.0 if id==0 else 1.0
		if anchors[id].is_finite():
			var shoulder_local:Vector3=visual.controller.tuning.shoulder_left if id==0 else visual.controller.tuning.shoulder_right
			var shoulder:Vector3=frame*shoulder_local
			var direction:Vector3=(anchors[id]-shoulder).normalized()
			visual.palms[id]=anchors[id]
			visual.hand_directions[id]=direction
			visual.targets[id].global_position=anchors[id]-direction*visual.controller.tuning.palm_contact_offset
			visual.poles[id].global_position=shoulder+frame.basis*Vector3(sign_side*.35,-.18,.25)
			hand_ik[id].influence=release_weight
		else:hand_ik[id].influence=0.0
		var sole:Transform3D=collision_pose.get("sole",Transform3D(Basis.IDENTITY,visual.controller.tuning.foot_base_offset))
		var shift:Vector3=sole.origin-visual.controller.tuning.foot_base_offset
		visual.targets[id+2].global_position=frame*(visual.leg_motion.rest_feet[id]+shift)
		var knee:Vector3=collision_pose.get("knee",Vector3(0,-.4967,0))
		visual.poles[id+2].global_position=frame*(knee+Vector3(sign_side*.10,0,-.12))
	if mode=="ASSISTED":leg_ik.influence=smoothstep(0.0,.15,progress)
	palm_pose.influence=release_weight

func finish()->void:
	if mode!="ASSISTED":return
	finished_count+=1
	_start_exit("FINISHED_PRESENTATION")

func cancel(reason:String="CANCELLED")->void:
	if mode!="ASSISTED":return
	_start_exit(reason)

func _exit_tree()->void:
	if not is_instance_valid(visual):return
	if visual.mantle_driver==self:visual.mantle_driver=null
	if is_driving() and is_instance_valid(visual.animation):
		visual.animation.callback_mode_process=ordinary_callback_mode
		visual.animation.play("Idle",.16)
	for solver in hand_ik:
		if is_instance_valid(solver):solver.queue_free()
	if is_instance_valid(leg_ik):leg_ik.queue_free()
	if is_instance_valid(palm_pose):palm_pose.queue_free()

func _start_exit(reason:String)->void:
	exit_pose.clear()
	for index in visual.skeleton.get_bone_count():exit_pose.append(visual.skeleton.get_bone_pose_rotation(index))
	anchors=[Vector3.INF,Vector3.INF]
	for solver in hand_ik:solver.influence=0.0
	palm_pose.influence=0.0
	release_weight=0.0
	player.pause()
	visual.animation_clip="Idle"
	visual.animation.play("Idle")
	visual.animation.advance(0.0)
	exit_elapsed=0.0
	mode="EXIT_BLEND"
	last_reason=reason

func _measure()->void:
	if not is_driving():return
	measured_frames+=1
	for id in 2:
		var suffix:="l" if id==0 else "r"
		var hand:int=visual.skeleton.find_bone("hand_"+suffix)
		var wrist:Vector3=visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(hand).origin
		var palm:Vector3=wrist+visual.hand_directions[id]*visual.controller.tuning.palm_contact_offset
		hand_contact_error[id]=palm.distance_to(anchors[id]) if anchors[id].is_finite() and release_weight>.01 else -1.0
		var foot:int=visual.skeleton.find_bone("foot_"+suffix)
		var ankle:Vector3=visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(foot).origin
		physical_foot_error[id]=ankle.distance_to(visual.targets[id+2].global_position)
	var anchored_errors:Array[float]=[-1.0,-1.0]
	var corrected_foot_errors:Array[float]=[-1.0,-1.0]
	for id in 2:
		# Raw errors above always remain available, including release/entry/gait.
		if mode=="ASSISTED" and hand_ik[id].influence>=.99:anchored_errors[id]=hand_contact_error[id]
		if mode=="ASSISTED" and leg_ik.influence>=.999:corrected_foot_errors[id]=physical_foot_error[id]
	last_measurement={"mode":mode,"progress":progress,"hand_ik_weights":[hand_ik[0].influence,hand_ik[1].influence],"leg_ik_weight":leg_ik.influence,"anchored_hand_error_threshold":.99,"anchored_hand_error_m":anchored_errors,"collision_corrected_foot_error_m":corrected_foot_errors,"frame":Engine.get_process_frames()}

func telemetry()->Dictionary:
	return {"mode":mode,"clip":CLIP_NAME,"duration_s":Clip.length,"progress":progress,"animation_time_s":player.current_animation_position if player.is_playing() else progress*Clip.length,"collision_flex":collision_flex,"visual_root_error":visual.global_position.distance_to(body.get_global_transform_interpolated().origin),"visual_target_recorded":visual_target_recorded,"visual_target_measurement_scope":mode if is_driving() else "STALE_OR_UNMEASURED","visual_vs_assigned_interpolated_target_error_m":visual.global_position.distance_to(last_visual_target.origin) if visual_target_recorded and is_driving() else -1.0,"body_interpolation_lag_at_visual_update_m":last_visual_target.origin.distance_to(simulation_pose_at_visual_update.origin) if visual_target_recorded else -1.0,"interpolated_target_change_since_visual_update_m":last_visual_target.origin.distance_to(body.get_global_transform_interpolated().origin) if visual_target_recorded and is_driving() else -1.0,"hand_contact_error":hand_contact_error.duplicate(),"physical_foot_error":physical_foot_error.duplicate(),"last_measurement":last_measurement.duplicate(true),"measured_frames":measured_frames,"hand_ik_weight":release_weight,"started_count":started_count,"finished_count":finished_count,"reason":last_reason,"root_motion":false,"body_authority":false}
