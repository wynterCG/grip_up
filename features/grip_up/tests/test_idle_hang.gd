extends SceneTree
## Regression for stopping W while keeping the selected grip held.
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var checks := 0
var failures := 0
var hz := 120

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):
		hz = 60
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func ticks(count: int) -> void:
	for frame in count:
		await physics_frame

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ",label)

func acquire(support: PhysicsBody3D,hand: int) -> bool:
	for frame in 6*hz:
		if app.controller.get_hand_state(hand)=="ATTACHED":
			return true
		if app.controller.get_hand_state(hand)=="FREE" and frame%6==0:
			var query := PhysicsRayQueryParameters3D.create(app.controller.get_shoulder_world(hand),support.global_position,3,[app.torso.get_rid()])
			var hit: Dictionary = app.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider==support:
				app.controller.request_grip(hand,support,hit.position,hit.normal)
		await physics_frame
	return false

func trial(dual: bool,level_id: int) -> void:
	app.load_test(level_id)
	await ticks(hz/2)
	check(await acquire(app.level.holds[0],0),"idle hang first grip acquired")
	Input.action_press("contract")
	await ticks(int(1.2*hz))
	if dual:
		check(await acquire(app.level.holds[1],1),"idle hang second grip acquired")
		await ticks(int(1.2*hz))
	Input.action_release("contract")
	var rest: float = app.controller.hands[0].rest_length
	var start: Vector3 = app.torso.position
	var old_body = app.torso
	var detached := false
	var last_reason := ""
	var peak_arm := 0.0
	for frame in 10*hz:
		await physics_frame
		if app.torso != old_body:
			detached = true
			break
		peak_arm = maxf(peak_arm,app.controller.hands[0].actual_length)
		if app.controller.get_hand_state(0) not in ["ATTACHED","SLIPPING"]:
			detached = true
			last_reason = app.controller.hands[0].reason
	print("IDLE HANG dual=",dual," level=",level_id," start=",start," end=",app.torso.position," states=",app.controller.get_hand_state(0),"/",app.controller.get_hand_state(1)," rest=",rest," finalrest=",app.controller.hands[0].rest_length," peak=",peak_arm," reason=",last_reason," velocity=",app.torso.linear_velocity)
	check(not detached,"held grip remains attached for 10 seconds without W")
	check(absf(app.controller.hands[0].rest_length-rest)<0.001,"stopping W holds target arm length instead of auto extending")

func run() -> void:
	app = Lab.new()
	app.input_profile = 0 # Explicitly exercise the preserved legacy control profile.
	root.add_child(app)
	current_scene = app
	for index in 3:
		app.load_test(index)
		var spawn: Vector3 = app.torso.position
		var start_body = app.torso
		var peak_drift := 0.0
		for frame in 30*hz:
			await physics_frame
			peak_drift = maxf(peak_drift,app.torso.position.distance_to(spawn))
		print("IDLE STAND level=",index," position=",app.torso.position," rotation=",app.torso.rotation," falls=",app.trial.falls)
		check(app.torso==start_body and peak_drift<0.02 and app.torso.rotation.length()<0.03 and app.trial.falls==0,"idle biped stands 30 seconds before first grip in level %d without drift or toppling" % index)
	await trial(false,0)
	await trial(true,0)
	await trial(false,1)
	print("IDLE HANG RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
