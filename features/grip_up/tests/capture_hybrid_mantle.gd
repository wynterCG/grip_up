extends "res://features/grip_up/tests/capture_intent_candidate.gd"
## Visible MCP evidence from normal approach; not human usability acceptance.
var current_row:Dictionary={}
var sample_after:=0.0
var shots_done:Array[String]=[]
var saving_shot:=false
var collision_overlay_enabled:=false
var contextual_vault_experiment:=false
var comparison_orbit:=Vector2.ZERO

func evidence_prefix()->String:
	return "v10" if contextual_vault_experiment else "v09"

func observe(_delta:float)->void:
	if current_row.is_empty():return
	if app.controller.assisted_motion_owned:
		current_row.old_forces_zero=current_row.old_forces_zero and app.controller.telemetry().get("total_force",0)==0 and app.ground_motor.applied_force.length()<.0001
	if app.controller.simulation_time>=sample_after:
		sample_after=app.controller.simulation_time+.05
		current_row.samples.append(app.hybrid_mantle.data.duplicate(true))

func _process(delta:float)->void:
	super._process(delta)
	if collision_overlay_enabled and is_instance_valid(app.mantle_overlay):app.mantle_overlay.visible=true
	if current_row.is_empty() or saving_shot:return
	for threshold in ([.15,.27,.34,.60,.90] if contextual_vault_experiment else [.30,.60,.90]):
		var key:="%s_%.2f"%[current_row.scenario,threshold]
		if app.hybrid_mantle.active() and app.hybrid_mantle.progress>=threshold and not shots_done.has(key):
			shots_done.append(key)
			saving_shot=true
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/%s_%dhz_%s.png"%[evidence_prefix(),hz,key])
			saving_shot=false
			break

func image_evidence(label:String)->void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/%s_%dhz_%s.png"%[evidence_prefix(),hz,label])

func select_again(id:int,point:Vector3)->bool:
	button(MOUSE_BUTTON_LEFT if id==0 else MOUSE_BUTTON_RIGHT,false)
	return await catch_hand(id,point)

func run()->void:
	report.physics_hz=hz
	report.contextual_vault_v10_enabled=contextual_vault_experiment
	report.comparison_camera_orbit=str(comparison_orbit)
	report.window_screen=get_window().current_screen
	report.engine=Engine.get_version_info()
	report.jolt_penetration_slop=ProjectSettings.get_setting("physics/jolt_physics_3d/simulation/penetration_slop",-1)
	report.provenance="Godot MCP Pro visible real-time in-app held mouse/actions, normal approach, no staged character transport; not human acceptance"
	report.trials=[]
	for scenario in [0,1]:
		for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
		for action in ["contract","extend","bias_left","bias_right"]:Input.action_release(action)
		app._open_hybrid_mantle(scenario,contextual_vault_experiment)
		if comparison_orbit!=Vector2.ZERO:app.camera.orbit(comparison_orbit)
		app.won=false
		app.controller.sample_ready.connect(audit)
		app.controller.sample_ready.connect(observe)
		await ticks(.4)
		current_row={"scenario":"LOW" if scenario==0 else "HIGH","samples":[],"old_forces_zero":true}
		sample_after=0
		await image_evidence(current_row.scenario+"_approach")
		check(await catch_hand(0,app.level.transfer_points[0]),"native actual first left grip")
		check(await catch_hand(1,app.level.transfer_points[1]),"native actual first right grip")
		Input.action_press("contract")
		if scenario==1:
			for index in 10:
				await ticks(.8)
				if app.hybrid_mantle.commits>0:break
				var id:int=index%2
				if app.controller.get_hand_state(1-id)!="ATTACHED":continue
				var shoulder:Vector3=app.controller.get_shoulder_world(id)
				await select_again(id,Vector3(clampf(shoulder.x,-.7,.7),minf(app.level.top_y-.05,shoulder.y+.50),0))
		else:
			for frame in 5*hz:
				await ticks(1.0/hz)
				if app.hybrid_mantle.commits>0:break
		check(app.hybrid_mantle.commits==1,"native legitimate hanging grip and W commit once")
		for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
		Input.action_release("contract")
		for frame in 4*hz:
			await ticks(1.0/hz)
			if app.hybrid_mantle.state in ["DYNAMIC_GROUNDED","BLOCKED_RECOVERY"]:break
		check(app.hybrid_mantle.state=="DYNAMIC_GROUNDED" and app.hybrid_mantle.data.top_ground_valid,"native actual upper support and restored dynamic authority")
		await image_evidence(current_row.scenario+"_standing")
		Input.action_press("contract")
		for frame in hz:
			await ticks(1.0/hz)
			if app.hybrid_mantle.completed:break
		Input.action_release("contract")
		check(app.hybrid_mantle.completed and app.hybrid_mantle.walk_distance>=.30,"native FULL top-out plus30cm ordinary walking")
		check(current_row.old_forces_zero,"native no old actuator authority during authored traversal")
		current_row.final=app.hybrid_mantle.data.duplicate(true)
		current_row.events=app.hybrid_mantle.events.duplicate(true)
		await image_evidence(current_row.scenario+"_walked")
		report.trials.append(current_row)
		current_row={}
		await ticks(.5)
	check(caps_ok,"native original dynamic hand/foot/torque limits preserved")
	report.functional_gate_met=report.trials.all(func(row):return row.final.mantle_complete)
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/%s_native_%dhz.json"%["vault" if contextual_vault_experiment else "hybrid",hz],FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	Engine.physics_ticks_per_second=120
	app._open_hybrid_mantle(0,contextual_vault_experiment)
	app.hint_time=0
	queue_free()
