extends "res://features/grip_up/tests/capture_independent.gd"
var invariant_ok:=true

func prepare(index:int) -> void:
	for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
	app._open_distant_lab(index)
	app.won=true
	app.debug_visible=false
	await ticks(.45)
	app.controller.sample_ready.connect(audit)

func audit(_delta:float) -> void:
	var data:Dictionary=app.controller.telemetry()
	invariant_ok=invariant_ok and data.total_force<=360.001 and Vector3(data.torque).length()<=150.001
	for id in 2:
		if app.controller.get_hand_state(id)=="REACHING" and app.controller.pending_diagnostics(id).get("active",false):
			invariant_ok=invariant_ok and app.controller.get_arm_force(id)==Vector3.ZERO and app.controller.hands[id].allocation==0
			invariant_ok=invariant_ok and app.controller.get_shoulder_world(id).distance_to(app.controller.get_hand_world(id))<=app.controller.get_max_reach()+.0001

func wait_catch(id:int,seconds:float) -> bool:
	for frame in int(seconds*hz):
		await get_tree().physics_frame
		if app.controller.get_hand_state(id)=="ATTACHED":return true
		if app.controller.get_hand_state(id) in ["FREE","RELEASED"]:return false
	return app.controller.get_hand_state(id)=="ATTACHED"

func run() -> void:
	record_folder="C:/Users/Wynter/grip_up/builds/v06_final_frames"
	DirAccess.make_dir_recursive_absolute(record_folder)
	report.physics_hz=hz
	report.provenance="Godot MCP Pro scripted input, not human flow/comfort validation"
	app._set_predictive_grip(false)
	app._set_catch_buffer(false)
	app.reach_prediction_enabled=false
	app.transfer_assist_enabled=false
	app._set_posture_variant(0)
	app._set_posture_policy(1)
	app.capture_trace.path="user://v06_final_native_%dhz.jsonl" % hz
	FileAccess.open(app.capture_trace.path,FileAccess.WRITE).close()
	app.capture_trace.enabled=true
	await prepare(4)
	recording=hz==120
	aim(app.level.transfer_points[0])
	button(MOUSE_BUTTON_LEFT,true)
	check(await wait_catch(0,1),"native new-mode left hand requires finite real contact")
	# Keep this static fixture outside reach even after policy B settles the support.
	var point:Vector3=app.level.transfer_points[0]+Vector3(0,1.6,0)
	aim(point)
	button(MOUSE_BUTTON_RIGHT,true)
	var selected:Dictionary=app.controller.pending_diagnostics(1).duplicate(true)
	check(selected.get("active",false) and selected.get("reach_margin",0)<0,"native visible distant point selected before movement")
	motion(Vector2(50,50))
	await ticks(2)
	check(app.controller.get_hand_state(1)=="REACHING" and app.controller.pending_diagnostics(1).active,"native no-input static distant target cannot attach beyond anatomy")
	app.debug_visible=true
	await shot("v06_pending")
	app.debug_visible=false
	button(MOUSE_BUTTON_RIGHT,false)
	check(not app.controller.pending_diagnostics(1).active and app.controller.get_hand_state(0)=="ATTACHED","native pending cancellation preserves supporting hand")
	await ticks(.2)
	check(app.controller.get_hand_state(1)=="FREE","native cancelled target cannot ghost attach")
	# A fresh authored swing fixture matches the timed headless comparison.
	await prepare(5)
	aim(app.level.transfer_points[0])
	button(MOUSE_BUTTON_LEFT,true)
	await ticks(.5)
	check(app.controller.get_hand_state(0)=="ATTACHED","native swing fixture begins with actual supporting contact")
	point=app.level.transfer_points[1]+Vector3(0,-.051,0)
	aim(point)
	button(MOUSE_BUTTON_RIGHT,true)
	report.swing_selection=app.controller.pending_diagnostics(1).duplicate(true)
	check(report.swing_selection.get("reach_margin",0)<0,"native swing destination selected outside actual reach")
	var action:=""
	for frame in 8*hz:
		var speed:float=app.torso.linear_velocity.dot(app.camera.global_basis.x)
		var next_action:String="bias_right" if speed>=-.04 else "bias_left"
		if next_action!=action:
			if action!="":Input.action_release(action)
			action=next_action
			Input.action_press(action)
		await get_tree().physics_frame
		if app.controller.get_hand_state(1)=="ATTACHED":break
	if action!="":Input.action_release(action)
	var caught:bool=app.controller.get_hand_state(1)=="ATTACHED"
	check(caught,"native supported swing brings the original queued point into actual contact without re-click")
	report.swing_contact=app.controller.pending_diagnostics(1)
	if caught:
		await get_tree().physics_frame
		button(MOUSE_BUTTON_LEFT,false)
		await ticks(.6)
		check(app.controller.get_hand_state(1)=="ATTACHED","native new support retains incoming load after old hand release")
	else:check(false,"retention requires an actual right catch")
	await shot("v06_swing")
	await prepare(4)
	report.route_session=app.transfer_session_id
	report.contacts=[]
	var previous:=-1
	var early:=0
	for index in 11:
		var id:int=index%2
		aim(app.level.transfer_points[index])
		button(MOUSE_BUTTON_LEFT if id==0 else MOUSE_BUTTON_RIGHT,true)
		var initial:Dictionary=app.controller.pending_diagnostics(id).duplicate(true)
		if initial.get("reach_margin",0)<0:early+=1
		var success:bool=await wait_catch(id,3)
		report.contacts.append({"index":index,"initial":initial,"caught":success,"contact":app.controller.pending_diagnostics(id)})
		check(success,"native finite early-target contact %02d" % index)
		if not success:break
		await ticks(.35)
		if previous>=0:button(MOUSE_BUTTON_LEFT if previous==0 else MOUSE_BUTTON_RIGHT,false)
		previous=id
		await ticks(1.1)
	report.route=app.transfer_progress.diagnostics()
	report.early_selections=early
	check(app.transfer_progress.transfers==10 and app.transfer_progress.recoveries==0,"native ten alternating transfers remain continuously supported")
	check(early>0,"native reference route actually includes initially out-of-reach selections")
	check(invariant_ok,"native pending never bears load or overreaches, common budgets unchanged")
	app.debug_visible=true
	await shot("v06_ten")
	recording=false
	report.demo_frames=frame_number
	for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
	app.capture_trace.enabled=false
	app.capture_trace.close()
	app.debug_visible=false
	app.settings.show()
	await ticks(.1)
	await shot("v06_controls")
	app.settings.hide()
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/distant_final_native_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	queue_free()
