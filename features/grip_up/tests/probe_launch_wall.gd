extends SceneTree
## Diagnostic only: actual authored wall, original spawn and finite grip paths.
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var hz := 120
var checks := 0
var failures := 0

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):
		hz = 60
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func ticks(count: int) -> void:
	for frame in count:
		await physics_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ",label)

func grip(hand: int, point: Vector3) -> bool:
	var wall: PhysicsBody3D = app.level.get_node("Wall")
	if app.controller.get_hand_state(hand)=="ATTACHED":
		app.controller.release_grip(hand)
	var ok: bool = app.controller.request_grip(hand,wall,point,Vector3.BACK)
	await ticks(int(0.65*hz))
	if not ok or app.controller.get_hand_state(hand)!="ATTACHED":
		print("WALL LAUNCH REACH ",app.controller.last_rejection," ",app.controller.hands[hand].reason," point=",point)
	return ok and app.controller.get_hand_state(hand)=="ATTACHED"

func setup(midwall: bool, mid_steps: int = 5) -> void:
	await physics_frame
	app = Lab.new()
	app.input_profile = 0 # Preserve this older baseline probe.
	root.add_child(app)
	current_scene = app
	app.torso.contact_monitor = true
	app.torso.max_contacts_reported = 16
	await ticks(int(0.5*hz))
	Input.action_press("contract")
	check(await grip(0,Vector3(-0.16,2.01,0)),"native first wall point attaches")
	await ticks(int(0.85*hz))
	check(await grip(1,Vector3(0.12,2.01,0)),"native second wall point attaches")
	await ticks(int(0.85*hz))
	if midwall:
		for index in mid_steps:
			var hand: int = index%2
			var shoulder: Vector3 = app.controller.get_shoulder_world(hand)
			check(await grip(hand,Vector3(clampf(shoulder.x,-0.16,0.16),shoulder.y+0.32,0)),"midwall point advances through actual arm forces")
			await ticks(hz)
	Input.action_release("contract")

func trial(midwall: bool, duration: float, cut_peak: bool = false, attempt_catch: bool = false, mid_steps: int = 5, reach_speed: float = 0.0, charge_speed: float = 0.75, target_offset: float = 0.82) -> void:
	await setup(midwall,mid_steps)
	app.controller.tuning.launch_duration = duration
	app.controller.tuning.launch_charge_extension_speed = charge_speed
	if reach_speed>0:
		app.controller.tuning.hand_reach_speed = reach_speed
	var before: Vector3 = app.torso.position
	var target := Vector3(-0.12,app.controller.get_shoulder_world(0).y+target_offset,0)
	var initial_reach: float = app.controller.get_shoulder_world(0).distance_to(target)
	check(app.controller.request_launch_charge(true),"native wall preload starts")
	await ticks(int(0.48*hz))
	var charged: Vector3 = app.torso.position
	print("WALL CHARGE ",{"steps":mid_steps,"speed":charge_speed,"hands":app.controller.hands.map(func(hand):return {"state":hand.state,"length":hand.actual_length,"rest":hand.rest_length,"reason":hand.reason})})
	check(app.controller.request_launch_charge(false),"native wall pull starts")
	var samples: Array[Dictionary] = []
	var peak_y: float = charged.y
	var precatch_peak_y: float = charged.y
	var peak_vy := 0.0
	var peak_force := 0.0
	var detach_time := -1.0
	var detach_vy := 0.0
	var target_min_distance := INF
	var reached_target_window := 0.0
	var capped := true
	var catch_requested := false
	var caught := false
	var catch_reason := ""
	var catch_time := -1.0
	var retained := true
	var retained_half_second := false
	var retained_one_second := false
	for frame in 2*hz:
		await ticks(1)
		var time := float(frame+1)/hz
		peak_y = maxf(peak_y,app.torso.position.y)
		if catch_time<0:
			precatch_peak_y = maxf(precatch_peak_y,app.torso.position.y)
		peak_vy = maxf(peak_vy,app.torso.linear_velocity.y)
		var data: Dictionary = app.controller.telemetry()
		peak_force = maxf(peak_force,data.total_force)
		capped = capped and data.total_force<=360.001 and data.torque.length()<=150.001
		var distance: float = app.controller.get_shoulder_world(0).distance_to(target)
		target_min_distance = minf(target_min_distance,distance)
		if distance<=app.controller.get_max_reach():
			reached_target_window += 1.0/hz
		if attempt_catch and app.controller.get_hand_state(0)=="FREE" and distance<app.controller.get_max_reach()-0.005:
			catch_requested = app.controller.request_grip(0,app.level.get_node("Wall"),target,Vector3.BACK) or catch_requested
		if attempt_catch and catch_requested and app.controller.get_hand_state(0)=="ATTACHED":
			caught = true
			if catch_time<0:
				catch_time = time
				Input.action_press("contract")
		if catch_time>=0:
			retained = retained and app.controller.get_hand_state(0)=="ATTACHED"
			if time-catch_time>=0.5:
				retained_half_second = retained
			if time-catch_time>=1.0:
				retained_one_second = retained
		if catch_requested:
			catch_reason = app.controller.hands[0].reason
		if cut_peak and time>0.08 and peak_vy>0.5 and app.torso.linear_velocity.y<peak_vy-0.03 and data.launch_state=="PULLING":
			app.controller.release_grip(0)
			app.controller.release_grip(1)
			app.controller.cancel_launch()
		if detach_time<0 and not app.controller.get_hand_state(0) in ["ATTACHED","SLIPPING"] and not app.controller.get_hand_state(1) in ["ATTACHED","SLIPPING"]:
			detach_time = time
			detach_vy = app.torso.linear_velocity.y
		if frame%maxi(1,int(0.05*hz))==0 and time<0.65:
			samples.append({"t":time,"y":app.torso.position.y,"vy":app.torso.linear_velocity.y,"F":data.total_force,"phase":data.launch_state,"length":app.controller.hands[0].actual_length,"rest":app.controller.hands[0].rest_length,"contacts":str(app.torso.get_colliding_bodies())})
	print("WALL LAUNCH ",JSON.stringify({"midwall":midwall,"mid_steps":mid_steps,"reach_speed":app.controller.tuning.hand_reach_speed,"charge_speed":charge_speed,"duration":duration,"peak_release":cut_peak,"precharge":before,"charged":charged,"peak_y":peak_y,"gain_precharge":peak_y-before.y,"gain_before_catch":precatch_peak_y-before.y,"gain_charged":peak_y-charged.y,"peak_vy":peak_vy,"detach_time":detach_time,"detach_vy":detach_vy,"peak_force":peak_force,"initial_target_distance":initial_reach,"target_min_distance":target_min_distance,"target_window":reached_target_window,"attempt_catch":attempt_catch,"catch_requested":catch_requested,"caught":caught,"catch_reason":catch_reason,"catch_time":catch_time,"retained_0_5":retained_half_second,"retained_1_0":retained_one_second,"final_position":app.torso.position,"samples":samples}))
	check(capped and detach_time>0,"native wall launch remains finite and detaches inside shared force limits")
	if attempt_catch and reach_speed>=6.0:
		check(initial_reach>app.controller.get_max_reach() and caught and retained_one_second,"finite faster hand catches and retains the unchanged previously unreachable wall point")
	Input.action_release("contract")
	app.queue_free()
	await ticks(4)
	app = null

func run() -> void:
	if OS.get_cmdline_user_args().has("--focused"):
		var speed := 1.0 if OS.get_cmdline_user_args().has("--full-stroke") else 0.75
		var practical := OS.get_cmdline_user_args().has("--practical")
		for steps in [5,6]:
			await trial(true,0.30,false,true,steps,4.0 if practical else 6.0,speed,0.72 if practical else 0.82)
		print("WALL LAUNCH RESULTS: %d checks, %d failures" % [checks,failures])
		quit(0 if failures==0 else 1)
		return
	for midwall in [false,true]:
		for duration in [0.24,0.30,0.36]:
			await trial(midwall,duration)
		await trial(midwall,0.36,true)
	await trial(true,0.30,false,true)
	await trial(true,0.30,false,true,5,6.0)
	for speed in [4.0,6.0,8.0]:
		await trial(true,0.30,false,true,6,speed)
	print("WALL LAUNCH RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
