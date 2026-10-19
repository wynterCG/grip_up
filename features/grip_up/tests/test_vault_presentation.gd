extends SceneTree
## Isolated render fixtures, not physical support or human feel evidence.
const Lab=preload("res://features/grip_up/scripts/grip_up_lab.gd")
const Driver=preload("res://features/grip_up/scripts/mantle_animation_driver.gd")
const BaselineClip=preload("res://features/grip_up/resources/mantle_authored.tres")
const VaultClip=preload("res://features/grip_up/resources/mantle_vault_v10.tres")
var checks:=0
var failures:=0
var hz:=120
var rows:Array=[]

func _initialize()->void:
	if OS.get_cmdline_user_args().has("--60hz"):hz=60
	Engine.physics_ticks_per_second=hz
	run.call_deferred()

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func run()->void:
	var app=Lab.new()
	root.add_child(app)
	current_scene=app
	for frame in 60:await physics_frame
	check(not app.contextual_vault_v10_enabled and app.input_profile==2,"v1.0 remains opt-in at ordinary startup")
	app.biped.set_process(false)
	app.biped.set_physics_process(false)
	app.controller.set_physics_process(false)
	app.ground_motor.set_physics_process(false)
	app.torso.freeze=true
	var driver=Driver.new()
	driver.contextual_vault_v10_enabled=true
	app.add_child(driver)
	driver.configure(app.biped,app.torso)
	var initial:Transform3D=app.torso.global_transform
	var linear:Vector3=app.torso.linear_velocity
	var angular:Vector3=app.torso.angular_velocity
	var support:=StaticBody3D.new()
	app.world.add_child(support)
	support.global_position=Vector3(2,1,-2)
	var contacts:Array[Vector3]=[]
	for id in 2:contacts.append(app.controller.get_shoulder_world(id)+Vector3(0,.10,-.25))
	for ids in [[0],[1],[0,1]]:
		var selected:Array[Vector3]=[]
		for id in ids:selected.append(contacts[id])
		driver.begin({"source_hands":ids,"hand_anchors_world":selected,"support_id":support.get_instance_id(),"support":support})
		for id in 2:
			check(driver.anchors[id].is_equal_approx(contacts[id]) if ids.has(id) else not driver.anchors[id].is_finite(),"contact fixture%s maps hand%d by identity"%[ids,id])
			check(driver.anchor_support_ids[id]==support.get_instance_id() and driver.anchor_local_points[id].is_equal_approx(support.to_local(contacts[id])) if ids.has(id) else driver.anchor_support_ids[id]==0,"contact fixture%s remembers actual material point for hand%d"%[ids,id])
			check(driver.hand_ik[id].influence>0 if ids.has(id) else driver.hand_ik[id].influence==0,"contact fixture%s IK belongs only to real source hand%d"%[ids,id])
			check(driver.palm_pose.hand_weights[id]>0 if ids.has(id) else driver.palm_pose.hand_weights[id]==0,"contact fixture%s never aligns unheld palm%d"%[ids,id])
		driver.set_progress(.2)
		var animation_time:float=driver.player.current_animation_position
		driver.update_visual(.5)
		check(driver.progress==.2 and is_equal_approx(driver.player.current_animation_position,animation_time),"render time cannot outrun approved progress")
		var previous:Array[float]=[driver.hand_ik[0].influence,driver.hand_ik[1].influence]
		var monotonic:=true
		for p in [.25,.28,.30,.34,.40,.60,1.0]:
			driver.set_progress(p)
			driver.update_visual(1.0/hz)
			for id in 2:
				monotonic=monotonic and driver.hand_ik[id].influence<=previous[id]+.00001
				previous[id]=driver.hand_ik[id].influence
		check(monotonic and previous==[0.0,0.0],"release is bounded and never reattaches after contact ends")
		rows.append({"source_hands":ids,"final":driver.telemetry()})
		driver.finish()
		driver.update_visual(.20)
	check(app.torso.global_transform==initial and app.torso.linear_velocity==linear and app.torso.angular_velocity==angular,"presentation never drives body pose or velocities")
	driver.begin({"source_hands":[1],"hand_anchors_world":[contacts[1]+Vector3.UP*4],"support_id":support.get_instance_id(),"support":support})
	driver.set_progress(.1)
	check(driver.hand_ik[1].influence==0 and driver.palm_pose.hand_weights[1]==0,"impossible rendered arm target releases instead of pinning wrist")
	driver.finish()
	driver.update_visual(.2)
	app.ground_motor.grounded=true
	app.torso.linear_velocity=Vector3(1,0,0)
	driver.begin({"source_hands":[],"hand_anchors_world":[]})
	driver.set_progress(1.0)
	driver.finish()
	driver.update_visual(.01)
	check(app.biped.animation_clip=="Walk","restored moving body selects Walk immediately during exit blend")
	driver.update_visual(.20)
	check(not driver.is_driving() and driver.leg_ik.influence==0,"exit removes foot IK and hands ordinary locomotion back")
	var rotational:=true
	var changed:=false
	for track in VaultClip.get_track_count():
		rotational=rotational and VaultClip.track_get_type(track)==Animation.TYPE_ROTATION_3D
		if track<BaselineClip.get_track_count():
			changed=changed or not VaultClip.rotation_track_interpolate(track,VaultClip.length*.6).is_equal_approx(BaselineClip.rotation_track_interpolate(track,BaselineClip.length*.6))
	check(rotational and VaultClip.get_track_count()==17,"refined real skeleton clip contains only bone rotations")
	check(changed,"refined authored poses actually differ from baseline clip")
	var same_legs:=true
	for track in range(11,17):
		same_legs=same_legs and VaultClip.track_get_path(track)==BaselineClip.track_get_path(track) and VaultClip.track_get_key_count(track)==BaselineClip.track_get_key_count(track)
		for key in VaultClip.track_get_key_count(track):
			same_legs=same_legs and VaultClip.track_get_key_time(track,key)==BaselineClip.track_get_key_time(track,key) and VaultClip.track_get_key_value(track,key)==BaselineClip.track_get_key_value(track,key)
	check(same_legs,"presentation retains all original authored leg keys for the certified proxy route")
	check(app.torso.mass==12,"presentation retains original 12kg gameplay body")
	app._open_hybrid_mantle(0,true)
	check(app.contextual_vault_v10_enabled and app.hybrid_mantle.contextual_vault_v10_enabled,"explicit A/B v1.0 selection enables experiment")
	app._open_hybrid_mantle(0)
	check(not app.contextual_vault_v10_enabled and not app.hybrid_mantle.animation_driver.contextual_vault_v10_enabled,"explicit A/B v0.9 selection restores baseline")
	FileAccess.open("res://builds/vault_presentation_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify({"physics_hz":hz,"checks":checks,"failures":failures,"fixtures":rows,"provenance":"Isolated authored presentation fixtures; no physical support or human acceptance claim"},"\t"))
	print("VAULT PRESENTATION RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
