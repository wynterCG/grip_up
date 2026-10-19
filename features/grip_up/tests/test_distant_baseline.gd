extends SceneTree
const Lab=preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var hz:=120
var checks:=0
var failures:=0
func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):hz=60
	Engine.physics_ticks_per_second=hz
	run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func ticks(seconds:float) -> void:
	for frame in int(seconds*hz):await physics_frame
func click(hand:int,down:bool,point:Vector3) -> void:
	app.pointer=app.camera.unproject_position(point)
	var event:=InputEventMouseButton.new()
	event.position=app.pointer
	event.button_index=MOUSE_BUTTON_LEFT if hand==0 else MOUSE_BUTTON_RIGHT
	event.pressed=down
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()
func run() -> void:
	app=Lab.new()
	root.add_child(app)
	current_scene=app
	app._open_transfer_lab(5)
	app.won=true
	await ticks(.45)
	click(0,true,app.level.transfer_points[0])
	await ticks(.5)
	check(app.controller.get_hand_state(0)=="ATTACHED","baseline actual left support acquired")
	var point:Vector3=app.level.transfer_points[1]+Vector3(0,-.051,0)
	var hit:Dictionary=app.targeting.candidate(app.camera,app.camera.unproject_position(point),app.torso)
	check(not hit.is_empty() and app.controller.get_shoulder_world(1).distance_to(hit.position)>app.controller.get_max_reach(),"camera selects real visible distant surface outside shoulder reach")
	var pose:Transform3D=app.torso.global_transform
	var velocity:Vector3=app.torso.linear_velocity
	var left:float=app.controller.hands[0].rest_length
	click(1,true,point)
	var result:Dictionary=app.controller.transfer_diagnostics().last_by_hand.get(1,{})
	check(app.controller.get_hand_state(1)=="FREE" and result.get("code")=="POSE_UNREACHABLE","v0.5 OFF rejects distant press immediately instead of remembering target")
	check(app.torso.global_transform==pose and app.torso.linear_velocity==velocity and app.controller.hands[0].rest_length==left and app.controller.get_arm_force(1)==Vector3.ZERO,"rejected selection does not move body or alter supporting arm")
	FileAccess.open("res://builds/distant_baseline_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify({"hz":hz,"baseline":"dac5f6d","event":result,"hit":str(hit.position),"distance":app.controller.get_shoulder_world(1).distance_to(hit.position),"reach":app.controller.get_max_reach(),"checks":checks,"failures":failures},"\t"))
	click(1,false,point)
	click(0,false,point)
	app.queue_free()
	await ticks(.05)
	print("DISTANT BASELINE RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
