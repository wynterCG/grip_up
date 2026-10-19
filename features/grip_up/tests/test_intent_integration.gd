extends SceneTree
## Real input through the playable v0.7 lab, with explicit baseline comparisons.
const Lab=preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var hz:=120
var checks:=0
var failures:=0
var report:={"runs":[]}
var budgets_ok:=true

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):hz=60
	Engine.physics_ticks_per_second=hz
	run.call_deferred()

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func ticks(seconds:float) -> void:
	for frame in int(seconds*hz):
		await physics_frame
		if is_instance_valid(app) and not app.controller.telemetry().is_empty():
			var data:Dictionary=app.controller.telemetry()
			budgets_ok=budgets_ok and data.total_force<=360.001 and data.leg_force<=180.001
			budgets_ok=budgets_ok and (Vector3(data.torque)+app.ground_motor.applied_torque).length()<=150.001

func aim(point:Vector3) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=app.camera.unproject_position(point)
	event.relative=event.position-app.pointer
	event.screen_relative=event.relative
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()

func button(id:int,down:bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=app.pointer
	event.button_index=MOUSE_BUTTON_LEFT if id==0 else MOUSE_BUTTON_RIGHT
	event.pressed=down
	Input.parse_input_event(event.xformed_by(root.get_final_transform()))
	Input.flush_buffered_events()

func fresh(index:int,feet:bool=false) -> void:
	for action in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:
		if InputMap.has_action(action):Input.action_release(action)
	if is_instance_valid(app):app.queue_free();await ticks(.03)
	app=Lab.new()
	root.add_child(app)
	current_scene=app
	app._open_intent_arena(index,feet)
	app.won=true
	await ticks(.45)

func grip(id:int,point:Vector3) -> bool:
	aim(point)
	button(id,true)
	for frame in hz:
		await physics_frame
		if app.controller.get_hand_state(id)=="ATTACHED":return true
	return false

func run() -> void:
	app=Lab.new()
	root.add_child(app)
	current_scene=app
	await ticks(.1)
	check(app.input_profile==2 and not app.intent_climb_enabled,"v0.7 leaves the real startup profile and opt-in flag unchanged")
	await fresh(6)
	check(app.input_profile==4 and app.intent_climb_enabled and app.controller.control_profile==4,"explicit Step button selects experimental profile4")
	check(app.hold_mode and app.hold_toggle.disabled and not app.experimental_launch_enabled,"hold-to-grip mandatory and Space initially OFF")
	check(not app.physical_feet_enabled and app.posture_variant==0,"hands-only Step starts P0 without silently enabling feet")
	check(app.level.footholds.size()==1 and app.level.transfer_points.size()==4,"Step has a broad real foothold and separate higher free-surface targets")
	check(await grip(0,app.level.transfer_points[0]),"real LMB finite contact starts the Step")
	check(await grip(1,app.level.transfer_points[1]),"independent RMB adds a real second support")
	await ticks(.35)
	var initial_y:float=app.torso.position.y
	var lengths:Array=[app.controller.hands[0].rest_length,app.controller.hands[1].rest_length]
	aim(Vector3(.7,2.7,0))
	await ticks(.12)
	check(absf(app.controller.hands[0].rest_length-lengths[0])<.003 and absf(app.controller.hands[1].rest_length-lengths[1])<.003,"aiming alone never changes supporting arm targets")
	Input.action_press("contract")
	await ticks(1.8)
	Input.action_release("contract")
	var raised:float=app.torso.position.y-initial_y
	check(raised>.05,"W produces useful measured COM rise through existing attached arms within1.8s")
	report.runs.append({"arena":"Step","feet":false,"rise":raised,"intent":app.controller.telemetry().get("intent_locomotion",{}),"position":str(app.torso.position)})
	await ticks(.3)
	Input.action_press("bias_right")
	await ticks(.15)
	var direction:Vector3=app.controller.telemetry().intent_locomotion.movement_intent_world
	app.orbiting=true
	app.camera.orbit(Vector2(180,0))
	await ticks(.3)
	var after:Vector3=app.controller.telemetry().intent_locomotion.movement_intent_world
	check(direction.normalized().dot(after.normalized())>.999,"camera orbit while D remains held preserves world movement axis")
	app.orbiting=false
	Input.action_release("bias_right")
	await ticks(.15)
	app.settings.show()
	Input.action_press("contract")
	await ticks(.2)
	check(app.controller.telemetry().intent_locomotion.movement_intent_world.length()<.001,"open Controls removes traversal input")
	Input.action_release("contract")
	app.settings.hide()
	button(0,false)
	check(app.controller.get_hand_state(0) in ["RELEASED","FREE"] and app.controller.get_hand_state(1)=="ATTACHED","mouse-up releases only its hand in new profile")
	app._set_input_profile(3)
	check(not app.intent_climb_enabled and app.controller.control_profile==3,"old independent baseline remains switchable")
	await fresh(6)
	app._set_distant_targeting(true)
	aim(Vector3(-.7,3.4,0))
	button(1,true)
	await ticks(.2)
	check(app.controller.pending_diagnostics(1).get("active",false) and app.controller.get_arm_force(1)==Vector3.ZERO,"profile4 reuses persistent distant selection with zero force")
	var z:float=app.torso.position.z
	Input.action_press("extend")
	await ticks(.35)
	Input.action_release("extend")
	check(app.ground_motor.grounded and app.torso.position.z>z+.1,"pending-only target keeps real ground walking active")
	check(app.controller.telemetry().intent_locomotion.actual_hand_ids.is_empty(),"pending hand never enables climb authority")
	app.get_window().focus_exited.emit()
	await ticks(.05)
	check(not app.controller.pending_diagnostics(1).get("active",false),"focus loss cancels persistent request in new profile")
	await fresh(7)
	app.level.get_node("Start").queue_free()
	await ticks(.2)
	Input.action_press("contract")
	Input.action_press("bias_right")
	await ticks(.2)
	var data:Dictionary=app.controller.telemetry()
	check(data.total_force==0 and Vector3(data.torque)==Vector3.ZERO and app.ground_motor.applied_force==Vector3.ZERO,"W+D in actual unsupported flight produces no climb or walk actuation")
	Input.action_release("contract")
	Input.action_release("bias_right")
	check(budgets_ok,"new integrated path respects hand/feet and same-tick combined ground+climb moment caps")
	report.physics_hz=hz
	report.checks=checks
	report.failures=failures
	FileAccess.open("res://builds/intent_integration_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	app.queue_free()
	await ticks(.03)
	print("INTENT INTEGRATION RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
