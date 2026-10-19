extends "res://tools/author_mantle_clip.gd"
## M1 visual-only fork. Retains v0.9 leg tracks and contains no root motion.
const Baseline=preload("res://features/grip_up/resources/mantle_authored.tres")

func run()->void:
	model=Model.instantiate()
	model.rotation.y=PI
	root.add_child(model)
	rig=model.find_children("*","Skeleton3D",true,false)[0]
	var imported:AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
	imported.stop()
	var clip:Animation=Baseline.duplicate(true)
	clip.resource_name="GRIP_UP_V10_Vault_Brace_Release"
	var bones=["pelvis","spine_01","spine_02","spine_03","neck_01","upperarm_l","lowerarm_l","hand_l","upperarm_r","lowerarm_r","hand_r"]
	for track in bones.size():
		while clip.track_get_key_count(track)>0:clip.track_remove_key(track,0)
	# Brace, anticipate, release, compact traverse, recover. Time is approved p.
	var keys=[
		[0.0,6.0,65.0,12.0],
		[0.15,12.0,55.0,40.0],
		[0.34,26.0,42.0,55.0],
		[0.55,38.0,18.0,95.0],
		[0.72,24.0,-20.0,100.0],
		[0.86,10.0,-65.0,32.0],
		[1.0,0.0,-88.0,5.0]]
	for key in keys:
		rig.reset_bone_poses()
		bend("pelvis",-float(key[1])*.15)
		bend("spine_01",float(key[1])*.35)
		bend("spine_02",float(key[1])*.35)
		bend("spine_03",float(key[1])*.30)
		bend("neck_01",-float(key[1])*.50)
		for side in ["l","r"]:
			var side_sign:float=-1.0 if side=="l" else 1.0
			var elevation:=deg_to_rad(float(key[2]))
			var forearm:=elevation-deg_to_rad(float(key[3]))
			aim("upperarm_"+side,"lowerarm_"+side,Vector3(side_sign*.22,sin(elevation),-cos(elevation)))
			aim("lowerarm_"+side,"hand_"+side,Vector3(-side_sign*.08,sin(forearm),-cos(forearm)))
		for track in bones.size():
			clip.rotation_track_insert_key(track,float(key[0])*clip.length,rig.get_bone_pose_rotation(rig.find_bone(bones[track])))
	var result:=ResourceSaver.save(clip,"res://features/grip_up/resources/mantle_vault_v10.tres")
	print("V10_AUTHORED_CLIP tracks=",clip.get_track_count()," duration=",clip.length," save=",result)
	quit(result)
