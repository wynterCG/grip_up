extends SceneTree
## Real cursor rays and grip API, choosing wall points outside all coloured holds.
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

func run() -> void:
	app = Lab.new()
	app.input_profile = 0 # Explicitly exercise the preserved legacy control profile.
	root.add_child(app)
	current_scene = app
	await ticks(hz)
	var wall: PhysicsBody3D = app.level.get_node("Wall")
	check(wall.get_meta("grippable",false),"ordinary wall surface is grippable")
	Input.action_press("contract")
	for step in 14:
		var hand: int = step%2
		if app.controller.get_hand_state(hand)=="ATTACHED":
			app.controller.release_grip(hand)
		var shoulder: Vector3 = app.controller.get_shoulder_world(hand)
		var point := Vector3(clampf(shoulder.x,-0.16,0.16),shoulder.y+0.32,0)
		app.camera._update_camera(1.0)
		app.pointer = app.camera.unproject_position(point)
		var hit: Dictionary = app.targeting.candidate(app.camera,app.pointer,app.torso)
		check(not hit.is_empty() and hit.collider==wall and hit.position.distance_to(point)<0.005,"cursor selects an arbitrary wall point, without snapping to a hold")
		var requested: bool = app.request_hand(hand)
		await ticks(int(0.65*hz))
		check(requested and app.controller.get_hand_state(hand)=="ATTACHED" and app.controller.hands[hand].support==wall,"hand reaches and attaches to the chosen wall material point")
		if app.controller.get_hand_state(hand)!="ATTACHED":
			print("FREE CLIMB REJECT ",app.controller.last_rejection," reason=",app.controller.hands[hand].reason," torso=",app.torso.position)
			break
		await ticks(hz)
		print("FREE CLIMB STEP ",step," point=",point," torso=",app.torso.position)
		if app.won:
			break
	check(app.won and app.torso.position.y>2.2,"free wall route can finish without touching a designated coloured hold")
	check(app.trial.falls==0 and app.trial.large_step_events==0,"free surface climbing preserves continuous physical motion")
	Input.action_release("contract")
	app.load_test(0)
	await ticks(3)
	var blocked: PhysicsBody3D = app.level.box("Blocked",Vector3(0,1.8,0.2),Vector3(0.4,0.2,0.1),Color.WHITE,false)
	check(not app.controller.request_grip(0,blocked,Vector3(0,1.8,0.25),Vector3.BACK) and app.controller.last_rejection=="surface_not_grippable","explicit non-grippable geometry still opts out")
	print("FREE CLIMB RESULTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
