extends SceneTree
## Fixture-only initialization writes poses. Production control is entirely force based.
const Controller = preload("res://features/grip_up/scripts/climbing_controller.gd")
const Profile = preload("res://features/grip_up/resources/biped_tuning.gd")
const Swing = preload("res://features/grip_up/scripts/supported_swing.gd")
var world: Node3D
var body: RigidBody3D
var controller: Node
var supports: Array[PhysicsBody3D] = []
var hz := 120
var checks := 0
var failures := 0
var budgets := true
var finite_reach := true

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):
		hz = 60
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ",label)

func tick() -> void:
	var previous: Array[Vector3] = []
	var states: Array[String] = []
	if is_instance_valid(controller):
		for hand in controller.hands:
			previous.append(hand.hand_world)
			states.append(hand.state)
	await physics_frame
	if not is_instance_valid(controller):
		return
	var data: Dictionary = controller.telemetry()
	if not data.is_empty():
		budgets = budgets and data.total_force<=360.001 and data.torque.length()<=150.001 and data.assist_torque.length()<=20.001
	for id in previous.size():
		if states[id]=="REACHING" and (controller.hands[id].state=="REACHING" or (controller.control_profile==1 and controller.hands[id].state=="ATTACHED")):
			finite_reach = finite_reach and previous[id].distance_to(controller.get_hand_world(id))<=4.0/hz+.0001

func ticks(count: int) -> void:
	for frame in count:
		await tick()

func clear() -> void:
	controller=null
	for child in world.get_children():
		child.queue_free()
	supports.clear()
	await physics_frame
	await physics_frame

func setup(dual := false, rotation := Vector3.ZERO, dynamic := false, profile_id := 1, shared := false) -> void:
	await physics_frame
	body=RigidBody3D.new()
	body.position=Vector3(0,3,0)
	body.rotation=rotation
	body.mass=12
	body.can_sleep=false
	body.gravity_scale=0
	body.center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass=Vector3.ZERO
	body.collision_layer=4
	body.collision_mask=1
	body.linear_damp=.08
	body.angular_damp=.35
	if dynamic:
		# Isotropic inertia isolates actuator wrench conservation from Jolt's
		# finite-step gyroscopic integration on a rotating anisotropic capsule.
		body.inertia=Vector3.ONE*3
		body.linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
		body.angular_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
		body.linear_damp=0
		body.angular_damp=0
	var capsule:=CapsuleShape3D.new()
	capsule.height=1.7
	capsule.radius=.20
	var collision:=CollisionShape3D.new()
	collision.shape=capsule
	body.add_child(collision)
	world.add_child(body)
	controller=Controller.new()
	world.add_child(controller)
	controller.configure(body,Profile.new())
	controller.set_control_profile(profile_id)
	controller.set_swing_intent(Vector3.ZERO,Vector3.RIGHT)
	await ticks(3)
	for id in (2 if dual else 1):
		var displacement:=Vector3(0,.48,-.08)
		var point: Vector3=controller.get_shoulder_world(id)+displacement
		var support: PhysicsBody3D
		if shared and id==1:
			support=supports[0]
		else:
			support=RigidBody3D.new() if dynamic else StaticBody3D.new()
			support.position=Vector3(0,point.y+.025,point.z) if shared else point+displacement.normalized()*.025
			support.collision_layer=2
			support.collision_mask=0
			support.set_meta("grip_load_limit",10000)
			var shape: Shape3D
			if shared:
				shape=BoxShape3D.new()
				shape.size=Vector3(.7,.05,.2)
			else:
				shape=SphereShape3D.new()
				shape.radius=.025
			var col:=CollisionShape3D.new()
			col.shape=shape
			support.add_child(col)
			if dynamic:
				support.mass=200
				support.gravity_scale=0
				support.inertia=Vector3.ONE*20
				support.can_sleep=false
				support.linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
				support.angular_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
				support.linear_damp=0
				support.angular_damp=0
			world.add_child(support)
			supports.append(support)
		var requested: bool=controller.request_grip(id,support,point,Vector3.DOWN if shared else -displacement.normalized())
		for frame in hz:
			await tick()
			if controller.get_hand_state(id)=="ATTACHED":
				break
		check(requested and controller.get_hand_state(id)=="ATTACHED","finite physical grip establishes test anchor")
	await ticks(int(.2*hz))
	if not dynamic:
		body.gravity_scale=1
		await ticks(hz)

func target_control() -> void:
	await setup(true)
	var before: Array[float]=[controller.hands[0].rest_length,controller.hands[1].rest_length]
	var pose:=body.global_transform
	var velocity:=body.linear_velocity
	var spin:=body.angular_velocity
	check(controller.queue_arm_length_delta(0,-10) and controller.queue_arm_length_delta(1,-10),"both attached arms accept independent drag requests")
	check(body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin,"queuing drag preserves instantaneous pose and momentum")
	await tick()
	check(absf(controller.hands[0].rest_length-before[0]+.6/hz)<.00001 and absf(controller.hands[1].rest_length-before[1]+.6/hz)<.00001,"fast shared drag clamps each target to .6m/s once per step")
	var held: float=controller.hands[0].rest_length
	await ticks(3)
	check(absf(controller.hands[0].rest_length-held)<.00001,"discarded excess never winds up or executes on later frames")
	controller.queue_arm_length_delta(0,.001)
	controller.queue_arm_length_delta(0,.001)
	await tick()
	check(absf(controller.hands[0].rest_length-held-.002)<.00001,"multiple event deltas sum exactly once")
	controller.queue_arm_length_delta(0,-.1)
	controller.queue_arm_length_delta(1,-.1)
	controller.clear_drag_requests(0)
	var prior0: float=controller.hands[0].rest_length
	var prior1: float=controller.hands[1].rest_length
	await tick()
	check(absf(controller.hands[0].rest_length-prior0)<.00001 and controller.hands[1].rest_length<prior1,"per-hand clear preserves real pending motion of the other arm")
	controller.queue_arm_length_delta(1,-.1)
	var stable0: float=controller.hands[0].rest_length
	controller.release_grip(1)
	check(not controller.queue_arm_length_delta(1,-.1),"released hand refuses drag")
	await tick()
	check(absf(controller.hands[0].rest_length-stable0)<.00001 and controller._arm_deltas.is_empty(),"release discards anchor-specific queued motion without changing survivor")
	controller.set_climb_intent(1,1,1,Vector3.FORWARD)
	await ticks(int(.2*hz))
	check(absf(controller.hands[0].rest_length-stable0)<.00001,"experimental WASD never contracts or extends arm targets")
	check(not controller.request_launch_charge(true),"experimental charged launch requires explicit opt-in")
	check(not controller.queue_arm_length_delta(0,NAN),"nonfinite drag is rejected")
	await clear()

func direction_trial(direction: Vector3,dual: bool,rotation:=Vector3.ZERO) -> Dictionary:
	await setup(dual,rotation)
	var start:=body.position
	var initial_v:=body.linear_velocity
	controller.set_swing_intent(direction,Vector3.RIGHT)
	await ticks(int(.45*hz))
	var result: Dictionary={"position":body.position-start,"velocity":body.linear_velocity-initial_v,"state":controller.get_hand_state(0),"torque":controller.telemetry().swing_torque}
	print("SWING DIRECTION ",JSON.stringify({"dual":dual,"input":direction,"rotation":rotation,"dx":result.position,"dv":result.velocity,"state":result.state}))
	await clear()
	return result

func directions() -> void:
	for dual in [false,true]:
		var baseline: Dictionary=await direction_trial(Vector3.ZERO,dual)
		for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK,Vector3(1,0,-1).normalized()]:
			var driven: Dictionary=await direction_trial(direction,dual)
			var gain: float=(Vector3(driven.velocity)-Vector3(baseline.velocity)).dot(direction)
			check(driven.state=="ATTACHED" and gain>.03,"supported 3D direction creates actual matching momentum; dual=%s dir=%s gain=%.3f" % [dual,direction,gain])
	for rotation in [Vector3(0,PI/2,0),Vector3(0,PI,0),Vector3(0,0,.6),Vector3(0,0,-.6)]:
		var baseline: Dictionary=await direction_trial(Vector3.ZERO,false,rotation)
		var driven: Dictionary=await direction_trial(Vector3.RIGHT,false,rotation)
		check((Vector3(driven.velocity)-Vector3(baseline.velocity)).x>.03,"world lateral input remains physical under rotated torso %s" % rotation)

func governor_and_camera() -> void:
	var model=Swing.new()
	var settings=Profile.new()
	var torque:=Vector3.ZERO
	for frame in hz:
		torque=model.evaluate(1.0/hz,Vector3.RIGHT,Vector3.UP,Vector3(0,0,settings.swing_max_relative_speed),1,settings)
	check(torque.length()<.00001,"supported torque governor reaches zero at target relative angular speed")
	check(model.evaluate(1.0/hz,Vector3.RIGHT,Vector3.UP,Vector3(0,0,settings.swing_max_relative_speed*2),1,settings).z<0,"excessive same-direction angular speed produces bounded braking")
	await setup(false)
	var rest: float=controller.hands[0].rest_length
	var reference: Vector3=controller.telemetry().control_right
	controller.set_swing_intent(Vector3.ZERO,Vector3.FORWARD)
	controller.set_climb_intent(0,0,0,Vector3.FORWARD)
	await tick()
	check(controller.telemetry().control_right==reference and controller.hands[0].rest_length==rest,"camera-only frame changes cannot retarget attached twist or arm length")
	controller.set_swing_intent(Vector3.RIGHT,Vector3.RIGHT)
	await ticks(int(.5*hz))
	var warm_torque: Vector3=controller.telemetry().swing_torque
	controller.set_swing_intent(Vector3.RIGHT,Vector3.FORWARD)
	await tick()
	check(controller.telemetry().swing_intent.dot(Vector3.RIGHT)>.99,"cached world gesture is independent of camera reference changes")
	controller.release_grip(0)
	await tick()
	check(controller.telemetry().assist_torque.length()==0 and controller.telemetry().total_force==0,"last grip release removes all supported effort immediately")
	var air_v:=body.linear_velocity
	for frame in int(.25*hz):
		controller.set_swing_intent(Vector3.RIGHT,Vector3.FORWARD)
		await tick()
	check(absf(body.linear_velocity.x)<=absf(air_v.x)+.0001,"held input with no anchors provides no air propulsion")
	await clear()

func phase_trial(mode: String) -> Dictionary:
	await setup(false)
	var pivot: Vector3=controller.hands[0].anchor_world
	var maximum:=0.0
	var speed:=0.0
	var speed_squared:=0.0
	var samples:=0
	var retained:=true
	for frame in hz*5:
		var direction:=Vector3.ZERO
		if mode=="pump":
			direction=Vector3.RIGHT*signf(body.linear_velocity.x)
		elif mode=="brake":
			direction=Vector3.LEFT*signf(body.linear_velocity.x)
		controller.set_swing_intent(direction,Vector3.RIGHT)
		await tick()
		if frame>hz*3:
			maximum=maxf(maximum,absf(body.position.x-pivot.x))
			speed=maxf(speed,absf(body.linear_velocity.x))
			speed_squared+=body.linear_velocity.x*body.linear_velocity.x
			samples+=1
		retained=retained and controller.get_hand_state(0)=="ATTACHED"
	var result: Dictionary={"amplitude":maximum,"speed":speed,"rms":sqrt(speed_squared/maxi(1,samples)),"retained":retained}
	print("SWING PHASE ",mode," ",JSON.stringify(result))
	await clear()
	return result

func pump_brake_and_long_hold() -> void:
	var passive: Dictionary=await phase_trial("passive")
	var pumped: Dictionary=await phase_trial("pump")
	check(pumped.retained and pumped.amplitude>passive.amplitude*1.15,"timed supported effort measurably increases physical swing amplitude")
	var coast: Dictionary=await brake_pulse(false)
	var braked: Dictionary=await brake_pulse(true)
	check(braked.speed<coast.speed-.03,"opposite supported effort brakes actual existing momentum versus coasting")
	for dual in [false,true]:
		await setup(dual)
		var peak:=0.0
		var late_peak:=0.0
		var retained:=true
		for frame in hz*12:
			controller.set_swing_intent(Vector3.FORWARD,Vector3.RIGHT)
			await tick()
			peak=maxf(peak,body.linear_velocity.length())
			if frame>hz*9:
				late_peak=maxf(late_peak,body.linear_velocity.length())
			retained=retained and controller.get_hand_state(0)=="ATTACHED" and (not dual or controller.get_hand_state(1)=="ATTACHED")
		print("SWING LONG HOLD dual=",dual," peak=",peak," late=",late_peak," spin=",body.angular_velocity.length())
		check(retained and body.position.is_finite() and peak<3 and late_peak<1,"12s held input bounded and settles; dual=%s" % dual)
		await clear()

func brake_pulse(brake: bool) -> Dictionary:
	await setup(false)
	controller.set_swing_intent(Vector3.RIGHT,Vector3.RIGHT)
	await ticks(int(.45*hz))
	var initial:=body.linear_velocity.x
	controller.set_swing_intent(Vector3.LEFT if brake else Vector3.ZERO,Vector3.RIGHT)
	await ticks(int(.45*hz))
	var result: Dictionary={"initial":initial,"speed":body.linear_velocity.x}
	print("SWING BRAKE brake=",brake," ",JSON.stringify(result))
	await clear()
	return result

func momentum() -> Dictionary:
	var linear:=Vector3.ZERO
	var angular:=Vector3.ZERO
	var bodies: Array[RigidBody3D]=[body]
	for support in supports:
		bodies.append(support)
	for target in bodies:
		var p: Vector3=target.linear_velocity*target.mass
		linear+=p
		angular+=target.global_position.cross(p)+target.get_inverse_inertia_tensor().inverse()*target.angular_velocity
	return {"linear":linear,"angular":angular}

func reaction_pairs() -> void:
	for dual in [false,true]:
		await setup(dual,Vector3.ZERO,true,1,dual)
		var before:=momentum()
		var support_spin: Vector3=supports[0].angular_velocity
		controller.set_swing_intent(Vector3(1,0,-1).normalized(),Vector3.RIGHT)
		await ticks(int(.4*hz))
		var after:=momentum()
		var dp: float=Vector3(after.linear).distance_to(before.linear)
		var dl: float=Vector3(after.angular).distance_to(before.angular)
		print("SWING REACTION dual=",dual," dp=",dp," dL=",dl)
		check(supports[0].angular_velocity.distance_to(support_spin)>.001,"dynamic gripped support receives real swing reaction torque; dual=%s" % dual)
		check(dp<.001 and dl<.01,"complete dynamic hand/swing pair conserves momentum; dual=%s" % dual)
		if dual:
			check(supports.size()==1 and controller.telemetry().assist_torque.length()<=20.001,"two anchors on same beam share one attitude cap")
		await clear()

func continuous_drag_and_reach() -> void:
	for id in 2:
		await setup(true)
		controller.release_grip(1-id)
		await ticks(int(.3*hz))
		var start:=body.position.y
		var rest: float=controller.hands[id].rest_length
		for frame in hz/2:
			controller.queue_arm_length_delta(id,-.30/hz)
			await tick()
		check(controller.get_hand_state(id)=="ATTACHED" and absf(controller.hands[id].rest_length-rest+.15)<.0001 and body.position.y>start+.05,"continuous drag physically raises single-hand body; id=%d" % id)
		var high:=body.position.y
		for frame in hz/2:
			controller.queue_arm_length_delta(id,.30/hz)
			await tick()
		check(absf(controller.hands[id].rest_length-rest)<.0001 and body.position.y<high-.03,"reverse drag physically lowers without downward thruster; id=%d" % id)
		await clear()
	await setup(true)
	controller.release_grip(1)
	await tick()
	var point: Vector3=controller.get_shoulder_world(1)+Vector3(0,.44,-.08)
	var support:=StaticBody3D.new()
	support.position=point+Vector3(0,.025,0)
	support.collision_layer=2
	support.collision_mask=0
	var shape:=BoxShape3D.new()
	shape.size=Vector3(.08,.05,.08)
	var collision:=CollisionShape3D.new()
	collision.shape=shape
	support.add_child(collision)
	world.add_child(support)
	await tick()
	var accepted: bool=controller.request_grip(1,support,point,Vector3.DOWN)
	check(accepted and not controller.queue_arm_length_delta(1,-.1),"REACHING hand refuses buffered target motion")
	var left: float=controller.hands[0].rest_length
	var count:=0
	var right_rest:=0.0
	for frame in hz:
		controller.queue_arm_length_delta(0,-.10/hz)
		count+=1
		await tick()
		if controller.get_hand_state(1)=="ATTACHED":
			right_rest=controller.hands[1].rest_length
			break
	check(controller.get_hand_state(1)=="ATTACHED" and absf(controller.hands[0].rest_length-left+.10*count/hz)<.0001,"supporting arm continuously consumes drag throughout other hand reach")
	await tick()
	check(absf(controller.hands[1].rest_length-right_rest)<.0001,"new attachment never consumes drag rejected during REACHING")
	await clear()

func legacy_snapshot(explicit_profile: bool) -> Dictionary:
	await setup(true,Vector3.ZERO,false,0)
	if explicit_profile:
		controller.set_control_profile(0)
	controller.set_swing_intent(Vector3.FORWARD,Vector3.FORWARD)
	check(not controller.queue_arm_length_delta(0,-1),"legacy profile rejects experimental arm drag")
	controller.set_climb_intent(.4,0,.3)
	await ticks(hz)
	var result: Dictionary={"position":body.position,"velocity":body.linear_velocity,"spin":body.angular_velocity,"left":controller.hands[0].rest_length,"force":controller.telemetry().total_force}
	await clear()
	return result

func legacy_identity() -> void:
	var first: Dictionary=await legacy_snapshot(false)
	var second: Dictionary=await legacy_snapshot(true)
	check(first==second,"default legacy and explicit profile0 repeat exactly despite experimental API calls")

func run() -> void:
	world=Node3D.new()
	root.add_child(world)
	await target_control()
	await directions()
	await governor_and_camera()
	await pump_brake_and_long_hold()
	await reaction_pairs()
	await continuous_drag_and_reach()
	await legacy_identity()
	check(budgets,"all trials obey shared360N, attitude20Nm and global150Nm")
	check(finite_reach,"all measured reaches retain finite4m/s gesture")
	print("DRAG SWING PHYSICS RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
