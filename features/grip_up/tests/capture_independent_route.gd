extends "res://features/grip_up/tests/capture_independent.gd"
## Rendered version of the T2 clear-wall route. Real walking, timed A/D, holds.
var center_lane := false

func run() -> void:
	record_folder="C:/Users/Wynter/grip_up/builds/"+("v05_baseline_failure_frames" if center_lane else "v04_route_frames")
	DirAccess.make_dir_recursive_absolute(record_folder)
	app._set_input_profile(3)
	app._set_predictive_grip(false)
	app._set_physical_feet(false)
	app._set_experimental_launch(false)
	app.capture_trace.path="user://v05_baseline_failure.jsonl" if center_lane else "user://v04_route_rendered.jsonl"
	app.capture_trace.enabled=true
	await reset_scene(0)
	app.won=true # Disable only the six-marker popup, preserving all colliders.
	recording=true
	if not center_lane:
		Input.action_press("bias_left")
		Input.action_press("contract")
		for frame in hz:
			await get_tree().physics_frame
			if app.torso.position.x<-.70:break
		Input.action_release("bias_left")
		Input.action_release("contract")
	await ticks(.4)
	var lane: float=app.torso.position.x
	var previous := -1
	var transfers := 0
	var extra_actions := 0
	var events: Array=[]
	for index in 11:
		var hand: int=index%2
		var point:=Vector3(lane+(-.1919 if hand==0 else .1919),2.05+.16*index,0)
		var hit: Dictionary=app.targeting.candidate(app.camera,app.camera.unproject_position(point),app.torso)
		var actual: Vector3=hit.get("position",point)
		if previous>=0 and app.controller.get_shoulder_world(hand).distance_to(actual)>app.controller.get_max_reach()-.015:
			var side: float=signf((actual-app.controller.get_shoulder_world(hand)).dot(app.camera.global_basis.x))
			var drive_action := ""
			for frame in 4*hz:
				var speed: float=app.torso.linear_velocity.dot(app.camera.global_basis.x)
				var drive: float=side if absf(speed)<.04 else signf(speed)
				var next_action: String="bias_right" if drive>=0 else "bias_left"
				if next_action!=drive_action:
					if drive_action!="":Input.action_release(drive_action)
					drive_action=next_action
					Input.action_press(drive_action)
					extra_actions+=1
				await get_tree().physics_frame
				hit=app.targeting.candidate(app.camera,app.camera.unproject_position(point),app.torso)
				actual=hit.get("position",point)
				if app.controller.get_shoulder_world(hand).distance_to(actual)<app.controller.get_max_reach()-.015:break
			if drive_action!="":Input.action_release(drive_action)
		aim(point)
		button(MOUSE_BUTTON_LEFT if hand==0 else MOUSE_BUTTON_RIGHT,true)
		var caught:=false
		for frame in int(.9*hz):
			await get_tree().physics_frame
			if app.controller.get_hand_state(hand)=="ATTACHED":
				caught=true
				break
			if app.controller.get_hand_state(hand) in ["FREE","RELEASED"]:break
		events.append({"index":index,"caught":caught,"position":str(app.torso.position),"rejection":app.controller.last_rejection,"posture":app.controller.telemetry().posture})
		if not caught:break
		await ticks(.35)
		if previous>=0:
			button(MOUSE_BUTTON_LEFT if previous==0 else MOUSE_BUTTON_RIGHT,false)
			transfers+=1
		previous=hand
		await ticks(1.1)
	await shot("rendered_route_end")
	recording=false
	app.capture_trace.enabled=false
	app.capture_trace.close()
	FileAccess.open("C:/Users/Wynter/grip_up/builds/"+("v05_baseline_failure.json" if center_lane else "independent_rendered_route.json"),FileAccess.WRITE).store_string(JSON.stringify({"complete":true,"transfers":transfers,"physics_hz":hz,"events":events,"swing_actions":extra_actions,"frames":frame_number,"elapsed":app.trial.elapsed},"  "))
	for id in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:button(id,false)
	app.load_test(0)
	queue_free()
