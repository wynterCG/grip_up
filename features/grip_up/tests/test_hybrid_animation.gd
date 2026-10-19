extends SceneTree
const Lab=preload("res://features/grip_up/scripts/grip_up_lab.gd")
const Driver=preload("res://features/grip_up/scripts/mantle_animation_driver.gd")
const Clip=preload("res://features/grip_up/resources/mantle_authored.tres")
const Legs=preload("res://features/grip_up/scripts/adaptive_leg_collision.gd")
var checks:=0
var failures:=0
var samples:Array=[]

func _initialize()->void:
	if OS.get_cmdline_user_args().has("--60hz"):Engine.physics_ticks_per_second=60
	run.call_deferred()

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func run()->void:
	var app=Lab.new()
	root.add_child(app)
	current_scene=app
	for i in 90:await physics_frame
	check(app.biped.mantle_driver==null,"default biped has no mantle presentation owner")
	var imported:PackedStringArray=app.biped.animation.get_animation_list()
	print("IMPORTED_CLIPS ",imported)
	check(not imported.has("Mantle") and not imported.has("HybridMantle"),"imported library contains no invented mantle clip")
	check(Clip.length>=.75 and Clip.length<=1.2 and Clip.loop_mode==Animation.LOOP_NONE,"authored nonlooping clip has intentional 1.05 second timing")
	check(Clip.get_track_count()==17,"authored clip articulates torso head arms and both complete legs")
	var bones_valid:=true
	var no_displacement:=true
	var key_variation:=true
	for track in Clip.get_track_count():
		var path:NodePath=Clip.track_get_path(track)
		bones_valid=bones_valid and app.biped.skeleton.find_bone(String(path.get_subname(0)))>=0
		no_displacement=no_displacement and Clip.track_get_type(track)==Animation.TYPE_ROTATION_3D and String(path)!=".:root"
		key_variation=key_variation and Clip.track_get_key_count(track)>=7
	check(bones_valid,"all authored track names resolve on the actual 65 bone rig")
	check(no_displacement,"clip has no root position or world displacement tracks")
	check(key_variation,"every authored bone has seven phase keyframes")
	app.biped.set_process(false)
	app.biped.set_physics_process(false)
	app.controller.set_physics_process(false)
	app.ground_motor.set_physics_process(false)
	app.torso.freeze=true
	var driver=Driver.new()
	app.add_child(driver)
	driver.configure(app.biped,app.torso)
	var initial:Transform3D=app.torso.global_transform
	var linear:Vector3=app.torso.linear_velocity
	var angular:Vector3=app.torso.angular_velocity
	var anchors:Array[Vector3]=[app.controller.get_shoulder_world(0)+Vector3(0,.15,-.3),app.controller.get_shoulder_world(1)+Vector3(0,.15,-.3)]
	driver.begin({"hand_anchors_world":anchors})
	driver.begin({})
	check(driver.started_count==1,"commit presentation is idempotent")
	check(driver.anchors==anchors,"presentation remembers actual ledge anchors independently of real grip ownership")
	check(app.biped.ik.influence==0.0 and app.biped.free_aim_ik.influence==0.0,"ordinary climbing modifiers cannot fight mantle pose")
	var pose_before:Quaternion=app.biped.skeleton.get_bone_pose_rotation(app.biped.skeleton.find_bone("spine_02"))
	driver.update_visual(.5)
	check(driver.progress==0.0 and app.biped.skeleton.get_bone_pose_rotation(app.biped.skeleton.find_bone("spine_02")).is_equal_approx(pose_before),"render updates do not advance collision-owned progress")
	var legs=Legs.new()
	# pose_for does not require changing any physical shape.
	legs.original_sole_transform=Transform3D(Basis.IDENTITY,app.controller.tuning.foot_base_offset)
	legs.set_pose_mode("HEEL_BACK")
	for p in [0.0,.1,.25,.48,.60,.75,.90,1.0]:
		var flex:=smoothstep(.12,.48,p)*(1.0-smoothstep(.75,1.0,p))
		driver.set_collision_pose(flex,legs.pose_for(flex))
		driver.set_progress(p,1.0/Engine.physics_ticks_per_second)
		app.biped.skeleton.advance(1.0/Engine.physics_ticks_per_second)
		await process_frame
		await process_frame
		samples.append(driver.telemetry())
	check(driver.measured_frames>0,"telemetry samples actual post-IK modifier frames")
	var feet_coherent:=true
	var hands_coherent:=true
	for sample in samples:
		if sample.progress>=.25:
			for error in sample.physical_foot_error:feet_coherent=feet_coherent and error<.01
		if sample.progress<=.48:
			for error in sample.hand_contact_error:hands_coherent=hands_coherent and error>=0.0 and error<.01
	check(feet_coherent,"visible ankles agree with actual supplied proxy pose after entry blend")
	check(hands_coherent,"remembered contact phase keeps visible palms on their actual anchors")
	var diagnostics_scoped:=true
	for sample in samples:
		diagnostics_scoped=diagnostics_scoped and sample.last_measurement.mode=="ASSISTED" and sample.visual_vs_assigned_interpolated_target_error_m<.001
		for id in 2:
			var measured_weight:float=sample.last_measurement.hand_ik_weights[id]
			var error:float=sample.last_measurement.anchored_hand_error_m[id]
			diagnostics_scoped=diagnostics_scoped and (error==sample.hand_contact_error[id] if measured_weight>=.99 else error==-1.0)
	check(diagnostics_scoped,"diagnostics preserve raw errors while distinguishing anchored measurement and render target")
	check(driver.progress==1.0 and absf(driver.player.current_animation_position-Clip.length)<.0001,"animation seek stays synchronized with approved normalized progress")
	check(app.torso.global_transform==initial and app.torso.linear_velocity==linear and app.torso.angular_velocity==angular,"animation never edits gameplay body transform or velocities")
	check(driver.hand_ik[0].influence==0.0 and driver.hand_ik[1].influence==0.0,"authored release phase removes both temporary hand contacts")
	check(driver.telemetry().visual_root_error<.001,"skeleton parent follows actual collision body without root drift")
	var finite:=true
	for index in app.biped.skeleton.get_bone_count():finite=finite and app.biped.skeleton.get_bone_global_pose(index).origin.is_finite()
	check(finite,"complete authored pose and constrained limbs remain finite")
	driver.finish()
	driver.finish()
	check(driver.finished_count==1 and not driver.anchors[0].is_finite(),"finish retires presentation anchors exactly once")
	driver.update_visual(.20)
	check(not driver.is_driving() and driver.leg_ik.influence==0.0 and app.biped.animation_clip=="Idle","short exit blend returns animation and IK authority to ordinary locomotion")
	driver.begin({"hand_anchors_world":anchors})
	driver.cancel("TEST_INTERRUPTION")
	driver.cancel("DUPLICATE_CALLBACK")
	driver.update_visual(.20)
	check(not driver.is_driving() and not driver.anchors[1].is_finite() and driver.last_reason=="TEST_INTERRUPTION","interruption also clears anchors and returns ordinary pose ownership")
	var output:=FileAccess.open("res://builds/hybrid_animation_%dhz.json"%Engine.physics_ticks_per_second,FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"imported_clips":imported,"samples":samples,"human_feel":"NOT_TESTED"},"\t"))
	print("HYBRID ANIMATION RESULTS: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
