extends SceneTree
## Reproducible keyframe authoring for the existing Quaternius rig, no root travel.
const Model=preload("res://features/grip_up/assets/characters/quaternius_mannequin/mannequin.glb")
const OUTPUT="res://features/grip_up/resources/mantle_authored.tres"
var rig:Skeleton3D
var model:Node3D

func _initialize()->void:
	run.call_deferred()

func aim(bone_name:String,child_name:String,direction:Vector3)->void:
	var index:=rig.find_bone(bone_name)
	var child:=rig.find_bone(child_name)
	var pose:=rig.get_bone_global_pose(index)
	var old_direction:Vector3=(rig.get_bone_global_pose(child).origin-pose.origin).normalized()
	var desired:Vector3=(rig.global_basis.inverse()*direction).normalized()
	var wanted:=Basis(Quaternion(old_direction,desired))*pose.basis
	var parent:=rig.get_bone_parent(index)
	var parent_basis:=rig.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
	rig.set_bone_pose_rotation(index,(parent_basis.inverse()*wanted).get_rotation_quaternion())

func bend(bone_name:String,x_degrees:float)->void:
	var index:=rig.find_bone(bone_name)
	rig.set_bone_pose_rotation(index,rig.get_bone_rest(index).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,deg_to_rad(x_degrees)))

func run()->void:
	model=Model.instantiate()
	model.rotation.y=PI
	root.add_child(model)
	rig=model.find_children("*","Skeleton3D",true,false)[0]
	var imported:AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
	print("IMPORTED_ANIMATION_AUDIT ",imported.get_animation_list())
	imported.stop()
	var clip:=Animation.new()
	clip.resource_name="GRIP_UP_Authored_Hybrid_Mantle"
	clip.length=1.05
	clip.loop_mode=Animation.LOOP_NONE
	var bones=["pelvis","spine_01","spine_02","spine_03","neck_01","upperarm_l","lowerarm_l","hand_l","upperarm_r","lowerarm_r","hand_r","thigh_l","calf_l","foot_l","thigh_r","calf_r","foot_r"]
	for bone_name in bones:
		var track:=clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,NodePath(".:"+bone_name))
		clip.track_set_interpolation_type(track,Animation.INTERPOLATION_LINEAR)
	# normalized time, torso lean, arm elevation, elbow bend, knee flex.
	var keys=[
		[0.0,4.0,65.0,12.0,0.0],
		[0.15,9.0,55.0,38.0,12.0],
		[0.35,18.0,15.0,78.0,95.0],
		[0.55,25.0,-12.0,90.0,150.0],
		[0.72,20.0,-28.0,72.0,150.0],
		[0.86,9.0,-65.0,28.0,75.0],
		[1.0,0.0,-88.0,5.0,0.0]]
	for key in keys:
		rig.reset_bone_poses()
		bend("pelvis",-float(key[1])*.25)
		bend("spine_01",float(key[1])*.35)
		bend("spine_02",float(key[1])*.35)
		bend("spine_03",float(key[1])*.30)
		bend("neck_01",-float(key[1])*.50)
		for side in ["l","r"]:
			var sign_side:float=-1.0 if side=="l" else 1.0
			var elevation:=deg_to_rad(float(key[2]))
			var forearm:=elevation-deg_to_rad(float(key[3]))
			aim("upperarm_"+side,"lowerarm_"+side,Vector3(sign_side*.18,sin(elevation),-cos(elevation)))
			aim("lowerarm_"+side,"hand_"+side,Vector3(-sign_side*.06,sin(forearm),-cos(forearm)))
			# Heel-back fold: hips remain almost vertical, knees fold away from wall.
			aim("thigh_"+side,"calf_"+side,Vector3(sign_side*.03,-1,0))
			var knee:=deg_to_rad(float(key[4]))
			aim("calf_"+side,"foot_"+side,Vector3(0,-cos(knee),sin(knee)))
			var foot:=rig.find_bone("foot_"+side)
			var parent:=rig.get_bone_parent(foot)
			var wanted:=rig.get_bone_global_rest(foot).basis
			rig.set_bone_pose_rotation(foot,(rig.get_bone_global_pose(parent).basis.inverse()*wanted).get_rotation_quaternion())
		for index in bones.size():
			clip.rotation_track_insert_key(index,float(key[0])*clip.length,rig.get_bone_pose_rotation(rig.find_bone(bones[index])))
	var result:=ResourceSaver.save(clip,OUTPUT)
	print("AUTHORED_CLIP ",OUTPUT," tracks=",clip.get_track_count()," duration=",clip.length," save=",result)
	quit(result)
