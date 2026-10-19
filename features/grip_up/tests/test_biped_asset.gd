extends SceneTree
const Preview = preload("res://features/grip_up/scripts/biped_preview.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ",label)

func run() -> void:
	var preview = Preview.new()
	root.add_child(preview)
	current_scene = preview
	await process_frame
	var skeleton: Skeleton3D = preview.skeleton
	check(skeleton.get_bone_count()==65,"Godot imports the complete 65-bone skeleton")
	for side in ["l","r"]:
		var upper := skeleton.find_bone("upperarm_"+side)
		var elbow := skeleton.find_bone("lowerarm_"+side)
		var hand := skeleton.find_bone("hand_"+side)
		check(upper>=0 and skeleton.get_bone_parent(elbow)==upper and skeleton.get_bone_parent(hand)==elbow,"arm hierarchy supports shoulder-elbow-hand IK: "+side)
		var thigh := skeleton.find_bone("thigh_"+side)
		var knee := skeleton.find_bone("calf_"+side)
		var foot := skeleton.find_bone("foot_"+side)
		check(thigh>=0 and skeleton.get_bone_parent(knee)==thigh and skeleton.get_bone_parent(foot)==knee,"leg hierarchy supports hip-knee-foot IK: "+side)
	check(preview.character.find_children("*","MeshInstance3D",true,false).size()>0,"Godot imports the skinned character mesh")
	print("ANIMATIONS ",preview.player.get_animation_list())
	check(preview.player.has_animation(preview.animation_name("Idle_Loop")) and preview.player.has_animation("A_TPose"),"idle and reference pose are available")
	for clip in ["Idle_Loop","A_TPose","Push_Loop","Jump_Loop"]:
		preview.play_pose(clip)
		preview.player.advance(0.4)
		var finite := true
		for i in skeleton.get_bone_count():
			finite = finite and skeleton.get_bone_global_pose(i).origin.is_finite()
		check(finite,"bone transforms remain finite in "+clip)
	var hand: int = skeleton.find_bone("hand_l")
	preview.play_pose("A_TPose")
	await process_frame
	var old: Vector3 = skeleton.get_bone_global_pose(hand).origin
	preview.play_pose("Push_Loop")
	preview.player.advance(0.4)
	await process_frame
	check(old.distance_to(skeleton.get_bone_global_pose(hand).origin)>0.1,"animation actually articulates the hand")
	print("BIPED ASSET RESULTS: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
