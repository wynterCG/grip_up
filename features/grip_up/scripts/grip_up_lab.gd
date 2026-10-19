extends Node3D

const Controller = preload("res://features/grip_up/scripts/climbing_controller.gd")
const CameraRig = preload("res://features/grip_up/scripts/climbing_camera.gd")
const Targeting = preload("res://features/grip_up/scripts/grip_targeting.gd")
const InputRouter = preload("res://features/grip_up/scripts/climbing_input_router.gd")
const BipedProfile = preload("res://features/grip_up/resources/biped_tuning.gd")
const BipedVisual = preload("res://features/grip_up/scripts/biped_visual.gd")
const GroundLocomotion = preload("res://features/grip_up/scripts/ground_locomotion.gd")
const CaptureTrace = preload("res://features/grip_up/scripts/capture_trace.gd")
const GripIntentBuffer = preload("res://features/grip_up/scripts/grip_intent_buffer.gd")
const CaptureDebugDraw = preload("res://features/grip_up/scripts/capture_debug_draw.gd")
const GripFeedback = preload("res://features/grip_up/scripts/grip_feedback.gd")
const ContextualInput = preload("res://features/grip_up/scripts/contextual_arm_input.gd")
const LEVELS = [preload("res://features/grip_up/scenes/static_climb.tscn"), preload("res://features/grip_up/scenes/swing_and_catch.tscn"), preload("res://features/grip_up/scenes/reactive_structure.tscn"), preload("res://features/grip_up/scenes/foot_support.tscn")]
const COLORS = [Color("65dfcc"), Color("f0b85c")]
var torso: RigidBody3D
var controller: Node
var camera: Camera3D
var level: Node3D
var world: Node3D
var level_id := 0
var fixed_beam := false
var checkpoint_active := false
var hold_mode := true
var biped: Node3D
var ground_motor: Node
var debug_visible := false
var orbiting := false
var pointer := Vector2.ZERO
var candidate: Dictionary = {}
var router = InputRouter.new()
var targeting = Targeting.new()
var hand_meshes: Array[MeshInstance3D] = []
var target_marker: MeshInstance3D
var hud: Control
var title_label: Label
var objective_label: Label
var status_label: Label
var controls_label: Label
var hand_labels: Array[Label] = []
var debug_label: Label
var beam_button: Button
var checkpoint_label: Label
var settings: PanelContainer
var rating_panel: PanelContainer
var binding_action := ""
var binding_buttons: Dictionary = {}
var binding_status: Label
var trial: Dictionary = {}
var previous_states := ["FREE", "FREE"]
var previous_position := Vector3.ZERO
var stable_goal := 0.0
var won := false
var session_ticks := 0
var hint := ""
var hint_time := 0.0
var mode_buttons: Array[Button] = []
var capture_trace = CaptureTrace.new()
var grip_intents = GripIntentBuffer.new()
var predictive_grip_enabled := false
var physical_feet_enabled := false
var input_profile := 2
var contextual = ContextualInput.new()
var contextual_paused := false
var contextual_owner := "GAME"
var contextual_rebase := false
var aim_labels: Array[Label] = []
var experimental_launch_enabled := false
var profile_choice: OptionButton
var hold_toggle: CheckButton
var launch_toggle: CheckButton
var arm_drag_sensitivity := 0.0015
var arm_target_rate := 0.6
var sound_feedback_enabled := true
var grip_feedback: Node
var capture_predictions: Array[Dictionary] = [{},{}]
var prediction_clock := 0.0
var prediction_label: Label
var predictive_toggle: CheckButton
var feet_toggle: CheckButton
var feet_label: Label
var feet_panel: PanelContainer
var capture_debug: MeshInstance3D
var prediction_support_id := 0
var prediction_point := Vector3.INF

func _ready() -> void:
	router.setup()
	get_window().min_size = Vector2i(1024,576)
	_setup_lighting()
	camera = CameraRig.new()
	add_child(camera)
	_setup_ui()
	grip_feedback = GripFeedback.new()
	add_child(grip_feedback)
	load_test(0)
	_set_input_profile(input_profile)
	get_window().mouse_exited.connect(func():
		if input_profile==1:
			router.set_owner("BOUNDARY")
			controller.clear_drag_requests()
	)
	get_window().mouse_entered.connect(func():
		if input_profile==1:
			router.set_owner("GAME")
			router.rebase_next_motion = true
	)
	get_window().focus_entered.connect(func():
		if input_profile==2:
			contextual.clear_motion()
			contextual_rebase=true
			message("Click to resume. Escape / Controls.")
		if input_profile==1:
			router.reset_control_input()
			router.rebase_next_motion = true
			controller.clear_drag_requests()
	)
	get_window().size_changed.connect(func():
		contextual.clear_motion()
		contextual_rebase=true
		if input_profile==1:
			router.clear_motion()
			controller.clear_drag_requests()
	)
	get_window().focus_exited.connect(func():
		if input_profile==2:
			contextual_paused=true
			contextual.clear_motion()
			controller.clear_free_hand_targets()
			_refresh_pointer_capture()
		orbiting = false
		router.reset_control_input("FOCUS")
		controller.clear_drag_requests()
		grip_intents.clear(controller)
		controller.cancel_launch()
		for action in ["contract", "extend", "bias_left", "bias_right", "launch"]:
			Input.action_release(action)
		if hold_mode and is_instance_valid(controller):
			for hand in 2:
				controller.release_grip(hand, "input_focus_lost")
				Input.action_release("grip_left" if hand == 0 else "grip_right")
	)

func _setup_lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c1720")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bed5df")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38,-28,0)
	light.light_color = Color("f4e9d3")
	light.light_energy = 1.7
	light.shadow_enabled = true
	add_child(light)

func _material(color: Color, emission := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.5
	return mat

func _mesh(parent: Node3D, geometry: Mesh, color: Color, at := Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = geometry
	mesh.position = at
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	return mesh

func load_test(index: int, use_checkpoint := false) -> void:
	contextual.reset()
	contextual_owner="GAME"
	capture_trace.close()
	router.reset_control_input()
	orbiting = false
	grip_intents = GripIntentBuffer.new()
	capture_predictions = [{},{}]
	prediction_clock = 0.0
	prediction_support_id = 0
	prediction_point = Vector3.INF
	for action in ["contract","extend","bias_left","bias_right","launch"]:
		Input.action_release(action)
	if not trial.is_empty():
		_save_trial("restart" if index == level_id else "change_test")
	if is_instance_valid(controller):
		controller.reset_state()
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	level_id = index
	checkpoint_active = checkpoint_active and use_checkpoint and index == 0
	world = Node3D.new()
	world.name = "TrialWorld"
	add_child(world)
	level = LEVELS[index].instantiate()
	level.fixed_beam = fixed_beam
	world.add_child(level)
	if checkpoint_active:
		level.box("Checkpoint landing",level.checkpoint-Vector3(0,1.042,0),Vector3(1.1,0.25,1.5),Color("527e72"))
	var floor_body = level.box("Safety floor",Vector3(0,-3.0,0),Vector3(50,0.3,25),Color("182c36"))
	floor_body.set_meta("grippable",false)
	for i in range(-10,11):
		var stripe := BoxMesh.new()
		stripe.size = Vector3(0.012,0.005,22)
		_mesh(world,stripe,Color("29404a"),Vector3(i*1.5,-2.843,0))
	torso = RigidBody3D.new()
	var profile := BipedProfile.new()
	profile.predictive_grip = predictive_grip_enabled
	profile.physical_feet = physical_feet_enabled
	profile.arm_drag_sensitivity_m_per_px = arm_drag_sensitivity
	profile.arm_target_max_rate_m_s = arm_target_rate
	torso.name = "BipedTorso"
	torso.mass = profile.body_mass
	torso.continuous_cd = true
	torso.can_sleep = false
	torso.linear_damp = 0.08
	torso.angular_damp = 0.35
	torso.collision_layer = 4
	torso.collision_mask = 3
	torso.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	torso.center_of_mass = profile.body_center_of_mass
	var body_material := PhysicsMaterial.new()
	body_material.friction = profile.body_friction
	body_material.rough = false
	torso.physics_material_override = body_material
	torso.position = level.checkpoint if checkpoint_active else level.spawn
	for segment in [Vector3(profile.torso_capsule_radius,profile.torso_capsule_height,profile.torso_capsule_center_y), Vector3(profile.leg_capsule_radius,profile.leg_capsule_height,profile.leg_capsule_center_y)]:
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = segment.x
		capsule.height = segment.y
		collision.shape = capsule
		collision.position.y = segment.z
		torso.add_child(collision)
	var head_collision := CollisionShape3D.new()
	var head_shape := SphereShape3D.new()
	head_shape.radius = profile.head_radius
	head_collision.shape = head_shape
	head_collision.position.y = profile.head_center_y
	torso.add_child(head_collision)
	# A flat sole provides a support polygon while idle. Still the same single
	# rigid body: no balance motor, position correction or leg propulsion.
	var foot_collision := CollisionShape3D.new()
	foot_collision.name = "FootBase"
	var foot_shape := BoxShape3D.new()
	foot_shape.size = profile.foot_base_size
	foot_collision.shape = foot_shape
	foot_collision.position = profile.foot_base_offset
	torso.add_child(foot_collision)
	world.add_child(torso)
	torso.reset_physics_interpolation()
	controller = Controller.new()
	controller.name = "ClimbingController"
	world.add_child(controller)
	controller.configure(torso,profile)
	controller.set_control_profile(input_profile)
	controller.experimental_launch_enabled = experimental_launch_enabled
	controller.sample_ready.connect(_record_capture)
	ground_motor = GroundLocomotion.new()
	ground_motor.name = "GroundLocomotion"
	world.add_child(ground_motor)
	ground_motor.configure(torso,controller,camera)
	biped = BipedVisual.new()
	biped.name = "BipedVisual"
	world.add_child(biped)
	biped.configure(torso,controller)
	biped.ground_motor = ground_motor
	hand_meshes.clear()
	for i in 2:
		var grip := SphereMesh.new()
		grip.radius = 0.032
		grip.height = 0.064
		hand_meshes.append(_mesh(world,grip,COLORS[i]))
		hand_meshes[i].physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var target := SphereMesh.new()
	target.radius = 0.09
	target.height = 0.18
	target_marker = _mesh(world,target,Color.WHITE)
	target_marker.visible = false
	capture_debug = CaptureDebugDraw.new()
	world.add_child(capture_debug)
	camera.reset(torso,controller)
	trial = {"test":index,"control_profile":input_profile,"character":"biped","grip_mode":"hold" if hold_mode else "toggle","fixed_beam":fixed_beam,"elapsed":0.0,"first_grab_seconds":-1.0,"goal_seconds":-1.0,"attempts":0,"misses":0,"slips":0,"falls":0,"transfers":0,"inputs":0,"large_step_events":0,"max_speed":0.0,"max_spin":0.0,"max_force_used":0.0,"ratings":{}}
	session_ticks = 0
	previous_position = torso.position
	previous_states = ["FREE","FREE"]
	stable_goal = 0
	won = false
	rating_panel.hide()
	title_label.text = level.title
	_update_objective()
	beam_button.visible = index == 2
	beam_button.text = "F  /  " + ("FIXED BEAM" if fixed_beam else "HINGED BEAM")
	for i in mode_buttons.size():
		mode_buttons[i].button_pressed = i == index
	message("WASD to walk. Hold LMB / RMB over a hold to climb. Release the button to let go.")

func message(text: String) -> void:
	hint = text
	hint_time = 4.0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("controls_menu") and not event.is_echo() and binding_action=="":
		contextual_paused=false
		settings.visible=not settings.visible
		_refresh_pointer_capture()
		get_viewport().set_input_as_handled()
		return
	if input_profile==1 and event is InputEventMouseMotion:
		pointer = event.position
		var next_owner := _control_owner()
		if next_owner!="GAME":
			router.set_owner(next_owner)
			controller.clear_drag_requests()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_MIDDLE and not event.pressed:
		orbiting = false
		router.set_owner(_control_owner())
		router.clear_motion()
		controller.clear_drag_requests()
	if event.is_action_released("launch") and is_instance_valid(controller):
		if settings.visible or binding_action!="" or not _launch_allowed():
			controller.cancel_launch()
		else:
			controller.request_launch_charge(false)
	if binding_action != "" and event.is_pressed() and (event is InputEventKey or event is InputEventMouseButton):
		if event is InputEventKey and event.keycode == KEY_ESCAPE:
			binding_action = ""
			binding_status.text = "Cancelled"
		else:
			var error: String = router.bind(binding_action,event)
			binding_status.text = "Saved" if error.is_empty() else error
			if error.is_empty():
				binding_buttons[binding_action].text = router.prompt(binding_action)
				controls_label.text = _controls_hint()
				binding_action = ""
		get_viewport().set_input_as_handled()
	if hold_mode and not event.is_pressed() and is_instance_valid(controller):
		for hand in 2:
			if event.is_action_released("grip_left" if hand==0 else "grip_right"):
				router.clear_motion(hand)
				controller.clear_drag_requests(hand)
				grip_intents.release(controller,hand)
				controller.release_grip(hand)

func _unhandled_input(event: InputEvent) -> void:
	if input_profile==2 and contextual_paused and event is InputEventMouseButton and event.pressed:
		contextual_paused=false
		_refresh_pointer_capture()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("launch") and not event.is_echo() and not settings.visible:
		if not _launch_allowed():
			message("Space launch is an optional comparison in Controls.")
		elif not controller.request_launch_charge(true):
			message("Grip a surface first, then hold %s to prepare a launch." % router.prompt("launch"))
	if event is InputEventMouseMotion:
		if input_profile!=2:pointer = event.position
		if orbiting:
			camera.orbit(event.relative)
		if input_profile==1:
			router.set_owner(_control_owner())
			router.capture_motion(event.screen_relative,controller,_held_grips())
		elif input_profile==2:
			var next_owner := _control_owner()
			if next_owner!=contextual_owner:
				contextual.clear_motion()
				contextual_owner=next_owner
			if next_owner=="GAME":
				if contextual_rebase:
					contextual_rebase=false
				else:
					contextual.capture_motion(event.screen_relative,controller,camera)
	if event is InputEventMouseButton:
		pointer = event.position
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			orbiting = event.pressed
			router.set_owner(_control_owner())
			router.clear_motion()
			controller.clear_drag_requests()
			contextual.clear_motion()
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera.dolly(-0.65 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.65)
	for hand in 2:
		if event.is_action_pressed("grip_left" if hand==0 else "grip_right"):
			request_hand(hand)
	if event.is_action_pressed("restart"):
		load_test(level_id,true)
	if event.is_action_pressed("debug_overlay"):
		debug_visible = not debug_visible
	if event.is_action_pressed("fixed_beam") and level_id == 2:
		toggle_beam()
	if event is InputEventKey and event.pressed and not event.echo:
		trial.inputs += 1

func request_hand(hand: int) -> bool:
	trial.inputs += 1
	var state: String = controller.get_hand_state(hand)
	if state in ["ATTACHED","SLIPPING","REACHING"]:
		if hold_mode:
			return true
		controller.release_grip(hand)
		message(("Left" if hand==0 else "Right") + " hand released")
		return true
	trial.attempts += 1
	var hit: Dictionary = contextual.candidate(hand,controller,camera) if input_profile==2 else targeting.candidate(camera,pointer,torso)
	if hit.is_empty():
		trial.misses += 1
		message("Aim at a solid surface within arm's reach. Hold LMB / RMB to grip that exact point.")
		return false
	var ok: bool = grip_intents.press(controller,hand,hit.collider,hit.position,hit.normal) if predictive_grip_enabled and hold_mode else controller.request_grip(hand,hit.collider,hit.position,hit.normal)
	if not ok:
		trial.misses += 1
		message(_capture_reason(controller.last_rejection))
	return ok

func toggle_beam() -> void:
	fixed_beam = not fixed_beam
	load_test(2)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller):
		return
	session_ticks += 1
	trial.elapsed += delta
	var blocked := settings.visible or binding_action != "" or (input_profile==2 and (contextual_paused or rating_panel.visible))
	if blocked:
		controller.cancel_launch()
		grip_intents.clear(controller)
		router.reset_control_input("UI")
		controller.clear_drag_requests()
		contextual.clear_motion()
	if predictive_grip_enabled:
		for hand in 2:
			if not Input.is_action_pressed("grip_left" if hand==0 else "grip_right"):
				grip_intents.release(controller,hand)
		grip_intents.update(controller)
	ground_motor.enabled = not blocked
	ground_motor.move_intent = Input.get_vector("bias_left","bias_right","contract","extend")
	if input_profile==0:
		controller.set_climb_intent(0.0 if blocked else Input.get_action_strength("contract"),0.0 if blocked else Input.get_action_strength("extend"),0.0 if blocked else Input.get_axis("bias_left","bias_right"),camera.global_basis.x)
	elif input_profile==1:
		controller.set_climb_intent(0,0,0,camera.global_basis.x)
		var direction := Vector3.ZERO if blocked else router.swing_direction(camera.global_basis.x)
		controller.set_swing_intent(direction,camera.global_basis.x)
		var displacements: Array[float] = router.consume_drag(controller,_held_grips())
		for id in 2:
			controller.queue_arm_length_delta(id,displacements[id])
	else:
		controller.set_climb_intent(0,0,0,camera.global_basis.x)
		controller.set_swing_intent(Vector3.ZERO if blocked else router.swing_direction(camera.global_basis.x),camera.global_basis.x)
		var input_owner := _control_owner()
		if input_owner!="GAME":contextual.clear_motion()
		controller.set_contextual_effort(contextual.consume_effort(delta),camera.global_basis.x)
		contextual.synchronize(controller,camera)
		controller.clear_free_hand_targets()
		if not blocked:
			for id in 2:
				var hit: Dictionary=contextual.candidate(id,controller,camera)
				controller.set_free_hand_target(id,hit.position if not hit.is_empty() else contextual.target(id,controller,camera))
	trial.max_speed = maxf(trial.max_speed,torso.linear_velocity.length())
	trial.max_spin = maxf(trial.max_spin,torso.angular_velocity.length())
	if session_ticks > 3 and torso.position.distance_to(previous_position) > 0.8:
		trial.large_step_events += 1
	previous_position = torso.position
	var attached := 0
	var total_force := 0.0
	for i in 2:
		var state: String = controller.get_hand_state(i)
		if input_profile>=1 and sound_feedback_enabled:
			if state=="ATTACHED" and previous_states[i]=="REACHING":grip_feedback.cue(i,true)
			elif state=="RELEASED" and previous_states[i] in ["ATTACHED","SLIPPING"]:grip_feedback.cue(i,false)
		if state in ["ATTACHED","SLIPPING"]:
			attached += 1
			if trial.first_grab_seconds < 0:
				trial.first_grab_seconds = trial.elapsed
		if state == "SLIPPING" and previous_states[i] != state:
			trial.slips += 1
		if state == "RELEASED" and previous_states[i] in ["ATTACHED","SLIPPING"] and controller.get_hand_state(1-i) in ["ATTACHED","SLIPPING"]:
			trial.transfers += 1
		previous_states[i] = state
		total_force += controller.get_arm_force(i).length()
	trial.max_force_used = maxf(trial.max_force_used,total_force)
	if torso.position.y < -1.8:
		trial.falls += 1
		load_test(level_id,true)
		message("Quick retry. Keep one hand attached before releasing the other.")
		return
	if level_id == 0 and not checkpoint_active and torso.position.y > level.checkpoint.y - 0.25 and torso.linear_velocity.length() < 1.2 and controller.hands.any(func(hand): return hand.state == "ATTACHED"):
		checkpoint_active = true
		message("Checkpoint saved on the rest ledge. R returns here.")
	var finish_support = level.holds[-1]
	var on_final_hold := false
	for hand in controller.hands:
		if hand.state in ["ATTACHED","SLIPPING"] and hand.support == finish_support:
			on_final_hold = true
	var wall_top: bool = level_id==0 and torso.position.y>level.holds[-1].position.y-1.0
	var goal: bool = level_id!=3 and (on_final_hold or wall_top) and attached > 0 and torso.linear_velocity.length() < 3.0
	if level_id == 0:
		goal = goal and torso.position.y > level.holds[-1].position.y - 1.0
	elif level_id == 1:
		goal = goal and torso.position.x > 0.0
	else:
		goal = goal and torso.position.x > 0.4
	stable_goal = stable_goal + delta if goal else 0.0
	if stable_goal > 0.5 and not won:
		won = true
		trial.goal_seconds = trial.elapsed
		_save_trial("goal")
		rating_panel.show()
		message("Test complete. Rate the feel, retry, or select another test.")

func _process(delta: float) -> void:
	if not is_instance_valid(controller):
		return
	hint_time = maxf(0,hint_time-delta)
	if input_profile==2:
		candidate={}
		for id in 2:
			var free: bool=controller.get_hand_state(id) in ["FREE","RELEASED"]
			var hit: Dictionary=contextual.candidate(id,controller,camera)
			aim_labels[id].visible=free and not settings.visible and not contextual_paused
			aim_labels[id].position=camera.unproject_position(hit.position if not hit.is_empty() else contextual.target(id,controller,camera))-Vector2(15,16)
			aim_labels[id].modulate=COLORS[id] if not hit.is_empty() else Color("8b9297")
			if candidate.is_empty() and free:candidate=hit
	else:
		candidate = targeting.candidate(camera,pointer,torso)
		for label in aim_labels:label.hide()
	prediction_clock -= delta
	if not candidate.is_empty() and (candidate.collider.get_instance_id()!=prediction_support_id or Vector3(candidate.position).distance_to(prediction_point)>0.02):
		prediction_clock = 0.0
	if predictive_grip_enabled and not candidate.is_empty() and prediction_clock<=0.0:
		for id in 2:
			var prediction_hit: Dictionary=contextual.candidate(id,controller,camera) if input_profile==2 else candidate
			capture_predictions[id] = controller.capture_predictor.evaluate(controller,id,prediction_hit.collider,prediction_hit.position,prediction_hit.normal) if not prediction_hit.is_empty() else {}
		prediction_clock = 0.05
		prediction_support_id = candidate.collider.get_instance_id()
		prediction_point = candidate.position
	if candidate.is_empty():
		capture_predictions = [{},{}]
	capture_debug.update_state(controller,capture_predictions,debug_visible)
	prediction_label.visible = predictive_grip_enabled and not settings.visible and not candidate.is_empty()
	target_marker.visible = not candidate.is_empty() and not settings.visible
	if target_marker.visible:
		target_marker.global_position = candidate.position + candidate.normal * 0.025
		var reachable := false
		for i in 2:
			if controller.get_shoulder_world(i).distance_to(candidate.position) <= controller.get_max_reach():
				reachable = true
			target_marker.material_override.albedo_color = Color("b1f5d8") if reachable else Color("e66d68")
		if predictive_grip_enabled:
			var status := "UNAVAILABLE"
			var eta := -1.0
			for forecast in capture_predictions:
				if forecast.get("status")=="NOW":
					status = "NOW"
					break
				if forecast.get("status")=="SOON":
					status = "SOON"
					eta = forecast.get("predicted_entry_time",-1.0)
			target_marker.material_override.albedo_color = Color("b1f5d8") if status=="NOW" else Color("f0b85c") if status=="SOON" else Color("e66d68")
			prediction_label.text = "TARGET / "+status+("  %.2f s" % eta if eta>=0 and status=="SOON" else "")
	for i in 2:
		var end: Vector3 = biped.palms[i]
		hand_meshes[i].global_position = end
		var hand: Dictionary = controller.hands[i]
		var warning: String = " / " + str(hand.reason) if hand.state in ["SLIPPING","RELEASED"] else ""
		if predictive_grip_enabled and hand.get("capture",{}).get("failure_reason","")!="" and hand.state in ["FREE","RELEASED"]:
			warning = "\n"+_capture_reason(hand.capture.failure_reason)
		if hand.state == "ATTACHED" and controller.get_arm_force(i).length() > hand.grip_limit * 0.75:
			warning = " / STRAINED"
		hand_labels[i].text = ("LEFT / CYAN" if i==0 else "RIGHT / AMBER") + "\n" + hand.state + warning
		if hand.state in ["ATTACHED","SLIPPING"]:
			hand_labels[i].text += "\n%.2f m  /  %.0f N" % [hand.actual_length,controller.get_arm_force(i).length()]
			if input_profile>=1:
				hand_labels[i].text += "\nTarget / %.2f m" % hand.rest_length
	status_label.text = hint if hint_time > 0 else ("WASD / Walk relative to camera. MMB / Orbit. Hold LMB / RMB on any surface to climb." if ground_motor.grounded and not ground_motor.has_climbing_intent() else "Grip anywhere within reach. W / Pull. S / Lower. Keep the other hand attached while transferring.")
	if input_profile==1 and hint_time<=0 and ground_motor.has_climbing_intent():
		status_label.text = "Hold each grip. Drag up / pull; down / lower, also while aiming. WASD / supported 3D swing."
	if input_profile==2 and hint_time<=0:
		var count: int=controller._attached_ids().size()
		status_label.text=["Move mouse / aim free hands. Hold LMB or RMB / grip. WASD / walk.","ONE GRIP / Aim the free hand. Mouse down / pull; up / extend with supported effort.","TWO GRIPS / Mouse down / pull; up / extend; sideways / posture. WASD / 3D swing."][count]
		if contextual_paused:status_label.text="Click to resume. Escape / Controls."
	feet_panel.visible = physical_feet_enabled and controller.feet_solver!=null
	if feet_panel.visible:
		feet_label.text = "FEET / AUTOMATIC"
		for i in 2:
			var foot: Dictionary = controller.feet_solver.feet[i]
			feet_label.text += "\n%s / %s  %.0f N" % ["L" if i==0 else "R",foot.state,Vector3(foot.force).length()]
	var launch: Dictionary = controller.telemetry()
	if launch.get("launch_state")=="CHARGING":
		status_label.text = "LAUNCH / %d%% — release %s to pull and let go." % [int(launch.get("launch_charge",0.0)*100.0),router.prompt("launch")]
	elif launch.get("launch_state")=="PULLING":
		status_label.text = "LAUNCH / reach for your next grip."
	checkpoint_label.text = "CHECKPOINT ACTIVE" if checkpoint_active else "R / QUICK RESET"
	debug_label.visible = debug_visible
	if debug_visible:
		debug_label.text = "PHYSICS / %d Hz  |  step %d  |  %.2f ms  |  %d fps\nBody %s  |  rotation %s\nv %s  /  spin %s" % [Engine.physics_ticks_per_second,session_ticks,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,Engine.get_frames_per_second(),str(torso.position),str(torso.rotation),str(torso.linear_velocity),str(torso.angular_velocity)]
		for i in 2:
			var hand: Dictionary = controller.hands[i]
			debug_label.text += "\n\n%s / %s\nAnchor: %s %s\nLength %.2f / target %.2f m  |  force %.1f / limit %.1f N\nReason: %s" % ["LEFT" if i==0 else "RIGHT",hand.state,str(hand.support),str(hand.anchor_world),hand.actual_length,hand.rest_length,controller.get_arm_force(i).length(),hand.grip_limit,hand.reason]
		debug_label.text += "\n\nTotal %.1f / %.1f N | Torque %s\nAttempts %d / misses %d / transfers %d / slips %d\nTrial logs: user://trials.jsonl" % [trial.max_force_used,controller.tuning.total_pull_force_budget,str(controller.telemetry().get("torque",Vector3.ZERO)),trial.attempts,trial.misses,trial.transfers,trial.slips]
		if controller.feet_solver!=null and physical_feet_enabled:
			debug_label.text += "\nLegs %.1f / %.1f N | combined torque %.1f / %.1f Nm" % [launch.get("leg_force",0),launch.get("leg_force_budget",0),Vector3(launch.get("torque",Vector3.ZERO)).length(),controller.tuning.max_total_torque]
			for foot in controller.feet_solver.feet:
				debug_label.text += "\nFoot %s / N %.1f / T %.1f / %s" % [foot.state,foot.normal_force,Vector3(foot.tangent_force).length(),foot.reason]
		if input_profile==1:
			debug_label.text += "\n\nPROFILE 1 / HOLD + DRAG | Input %s\nSwing request %s | torque %s\nCamera right %s | forward %s\nLast arm requests %s | acquisitions %d" % [router.owner,str(launch.get("swing_requested",Vector3.ZERO)),str(launch.get("swing_torque",Vector3.ZERO)),str(camera.global_basis.x),str(Vector3.UP.cross(camera.global_basis.x).normalized()),str(router.last_displacements),controller.metrics.attaches]
		elif input_profile==2:
			debug_label.text += "\n\nCONTEXTUAL / %s | effort %s\nVirtual hand offsets %s\nActual mouse mode %s" % [_control_owner(),str(contextual.effort),str(contextual.offsets),str(Input.mouse_mode)]

func _save_trial(outcome: String) -> void:
	if trial.is_empty():
		return
	var row := trial.duplicate(true)
	row.outcome = outcome
	row.timestamp = Time.get_datetime_string_from_system(true)
	row.physics_hz = Engine.physics_ticks_per_second
	row.control_profile = input_profile
	row.space_comparison = experimental_launch_enabled
	row.session_input_metrics = router.diagnostics()
	var file := FileAccess.open("user://trials.jsonl",FileAccess.READ_WRITE if FileAccess.file_exists("user://trials.jsonl") else FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(JSON.stringify(row))

func _record_capture(delta: float) -> void:
	if not capture_trace.enabled:
		return
	var contextual_data: Dictionary=controller.telemetry()
	var filtered: Vector2=contextual_data.get("contextual_filtered",Vector2.ZERO)
	var actuation: Vector2=contextual_data.get("contextual_actuation",Vector2.ZERO)
	capture_trace.sample(delta,controller,{"scene":level_id,"launch_state":controller.telemetry().get("launch_state","IDLE"),
		"control_profile":input_profile,"space_comparison":experimental_launch_enabled,"input_control":router.diagnostics(),
		"contextual_input":contextual.diagnostics() if input_profile==2 else {},
		"contextual_filtered":[filtered.x,filtered.y],"contextual_actuation_m_s":[actuation.x,actuation.y],
		"camera_right":capture_trace.vector(camera.global_basis.x),"camera_forward":capture_trace.vector(Vector3.UP.cross(camera.global_basis.x).normalized()),
		"swing_requested":capture_trace.vector(controller.telemetry().get("swing_requested",Vector3.ZERO)),
		"swing_torque":capture_trace.vector(controller.telemetry().get("swing_torque",Vector3.ZERO)),
		"grip_buttons":[Input.is_action_pressed("grip_left"),Input.is_action_pressed("grip_right")],"capture_predictions":capture_predictions,
		"anomalous_displacements":trial.get("large_step_events",0),
		"grounded":ground_motor.grounded if is_instance_valid(ground_motor) else false,
		"beam_angle":level.beam.rotation.z if is_instance_valid(level) and is_instance_valid(level.beam) else 0.0})

func _capture_reason(reason: String) -> String:
	return {"out_of_reach":"Point outside arm reach.","outside_buffer_window":"Point will arrive too late; try closer to the catch.",
		"surface_obstructed":"The surface is blocked.","hand_path_obstructed":"Hand path blocked.","surface_contact_missing":"The hand missed the surface.",
		"capture_window_expired":"The point did not enter reach in time.","target_left_reach":"The point left arm reach before contact.",
		"hand_path_left_reach":"The body moved beyond the reaching arm.","excessive_relative_speed":"Too much speed to hold this catch.",
		"candidate_timeout_or_obstructed":"Contact timed out or became blocked.","support_invalidated":"The support disappeared.",
		"arm_extension_limit":"The arm reached its physical limit.","grip_overload":"Grip load exceeded its limit."}.get(reason,reason.replace("_"," "))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		capture_trace.close()
		_save_trial("closed")

func _label(text: String, size: int, parent: Node, color := Color("d5e5e2")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func _button(text: String, callback: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0,48)
	button.pressed.connect(callback)
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button

func _panel(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.075,0.1,0.94)
	style.border_color = Color("2c4853")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	return panel

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	var theme := Theme.new()
	theme.default_font_size = 19
	hud.theme = theme
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left",36)
	top.add_theme_constant_override("margin_right",36)
	top.add_theme_constant_override("margin_top",24)
	hud.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	top.add_child(row)
	var branding := VBoxContainer.new()
	branding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(branding)
	_label("GRIP UP",36,branding,Color("edf4e9"))
	_label("PHYSICS CLIMBING LAB  /  CONTEXTUAL ARMS",15,branding,COLORS[0])
	for i in LEVELS.size():
		var index := i
		var button := _button(["01  STATIC CLIMB","02  SWING & CATCH","03  REACTIVE STRUCTURE","04  FOOT SUPPORT"][i],func():load_test(index),row)
		button.toggle_mode = true
		mode_buttons.append(button)
	_button("Controls / Esc",func():settings.visible=not settings.visible,row)
	for id in 2:
		var aim := _label("+ L" if id==0 else "+ R",22,hud,COLORS[id])
		aim.mouse_filter=Control.MOUSE_FILTER_IGNORE
		aim.add_theme_color_override("font_outline_color",Color.BLACK)
		aim.add_theme_constant_override("outline_size",5)
		aim.hide()
		aim_labels.append(aim)
	var mission := VBoxContainer.new()
	mission.position = Vector2(40,132)
	mission.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(mission)
	title_label = _label("",23,mission,COLORS[0])
	objective_label = _label("",18,mission)
	checkpoint_label = _label("",15,mission,Color("91aab5"))
	prediction_label = _label("",16,mission,COLORS[1])
	prediction_label.hide()
	beam_button = _button("",toggle_beam,mission)
	var hands_panel := _panel(hud)
	hands_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	hands_panel.offset_left = -318
	hands_panel.offset_right = -32
	hands_panel.offset_top = -140
	hands_panel.offset_bottom = 140
	var hands_box := VBoxContainer.new()
	hands_box.add_theme_constant_override("separation",28)
	hands_panel.add_child(hands_box)
	for i in 2:
		hand_labels.append(_label("",19,hands_box,COLORS[i]))
	feet_panel = _panel(hud)
	feet_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	feet_panel.offset_left = -318
	feet_panel.offset_right = -32
	feet_panel.offset_top = 155
	feet_panel.offset_bottom = 280
	feet_label = _label("",17,feet_panel,Color("8bb88c"))
	feet_panel.hide()
	var bottom := _panel(hud)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 32
	bottom.offset_right = -32
	bottom.offset_top = -117
	bottom.offset_bottom = -24
	var lower := VBoxContainer.new()
	bottom.add_child(lower)
	status_label = _label("",21,lower,COLORS[0])
	controls_label = _label(_controls_hint(),16,lower,Color("a5bbc3"))
	debug_label = _label("",14,hud,Color("b8e3d8"))
	debug_label.position = Vector2(40,290)
	debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_label.hide()
	settings = _panel(hud)
	settings.anchor_left = 0.20
	settings.anchor_right = 0.80
	settings.anchor_top = 0.12
	settings.anchor_bottom = 0.88
	var settings_layout := VBoxContainer.new()
	settings.add_child(settings_layout)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	settings_layout.add_child(scroll)
	var settings_box := VBoxContainer.new()
	settings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(settings_box)
	_label("CONTROLS / click a binding to change it",23,settings_box,COLORS[0])
	profile_choice = OptionButton.new()
	profile_choice.add_item("0 / Baseline: W/S pull, A/D bias, Space launch")
	profile_choice.add_item("1 / Hold + arm drag + 3D swing (experimental)")
	profile_choice.add_item("2 / Contextual arms + virtual hand aim (experimental)")
	profile_choice.select(input_profile)
	profile_choice.item_selected.connect(_set_input_profile)
	settings_box.add_child(profile_choice)
	hold_toggle = CheckButton.new()
	hold_toggle.text = "Hold to grip / mandatory in experimental profiles"
	hold_toggle.button_pressed = hold_mode
	hold_toggle.toggled.connect(_set_hold_mode)
	settings_box.add_child(hold_toggle)
	launch_toggle = CheckButton.new()
	launch_toggle.text = "Enable Space launch / optional comparison"
	launch_toggle.disabled = input_profile==0
	launch_toggle.toggled.connect(_set_experimental_launch)
	settings_box.add_child(launch_toggle)
	var sounds := CheckButton.new()
	sounds.text = "Grip contact sounds"
	sounds.button_pressed = sound_feedback_enabled
	sounds.toggled.connect(func(on:bool):sound_feedback_enabled=on)
	settings_box.add_child(sounds)
	var sensitivity_row := HBoxContainer.new()
	settings_box.add_child(sensitivity_row)
	_label("Arm drag sensitivity / m per pixel",17,sensitivity_row)
	var sensitivity := SpinBox.new()
	sensitivity.min_value = 0.0001
	sensitivity.max_value = 0.005
	sensitivity.step = 0.0001
	sensitivity.value = arm_drag_sensitivity
	sensitivity.custom_minimum_size.x = 220
	sensitivity.value_changed.connect(func(value:float):
		arm_drag_sensitivity=value
		if is_instance_valid(controller):controller.tuning.arm_drag_sensitivity_m_per_px=value
	)
	sensitivity_row.add_child(sensitivity)
	var aim_sensitivity := SpinBox.new()
	_label("Virtual hand sensitivity / m per pixel",17,settings_box)
	aim_sensitivity.min_value=.0002
	aim_sensitivity.max_value=.006
	aim_sensitivity.step=.0002
	aim_sensitivity.value=contextual.sensitivity
	aim_sensitivity.value_changed.connect(func(value:float):contextual.sensitivity=value)
	settings_box.add_child(aim_sensitivity)
	var rate_row := HBoxContainer.new()
	settings_box.add_child(rate_row)
	_label("Arm target maximum speed / m per second",17,rate_row)
	var rate := SpinBox.new()
	rate.min_value = 0.1
	rate.max_value = 1.2
	rate.step = 0.05
	rate.value = arm_target_rate
	rate.custom_minimum_size.x = 180
	rate.value_changed.connect(func(value:float):
		arm_target_rate=value
		if is_instance_valid(controller):controller.tuning.arm_target_max_rate_m_s=value
	)
	rate_row.add_child(rate)
	predictive_toggle = CheckButton.new()
	predictive_toggle.text = "Predictive catches / prepare a near-future grip"
	predictive_toggle.button_pressed = predictive_grip_enabled
	predictive_toggle.toggled.connect(_set_predictive_grip)
	settings_box.add_child(predictive_toggle)
	feet_toggle = CheckButton.new()
	feet_toggle.text = "Automatic foot contacts / feet push on real supports"
	feet_toggle.button_pressed = physical_feet_enabled
	feet_toggle.toggled.connect(_set_physical_feet)
	settings_box.add_child(feet_toggle)
	var record := CheckButton.new()
	record.text = "Record capture diagnostics (JSONL)"
	record.toggled.connect(func(on:bool):
		capture_trace.enabled=on
		if not on:
			capture_trace.close()
	)
	settings_box.add_child(record)
	for action in router.DEFAULTS:
		var binding := str(action)
		var line := HBoxContainer.new()
		settings_box.add_child(line)
		var binding_names := {"contract":"forward","extend":"backward","bias_left":"left","bias_right":"right"}
		var name_label := _label(binding_names.get(binding,binding.replace("_"," ")),18,line)
		name_label.custom_minimum_size.x = 190
		binding_buttons[binding] = _button(router.prompt(binding),func():
			binding_action=binding
			binding_status.text="Press a key or mouse button. Escape cancels."
		,line)
	binding_status = _label("Middle mouse / orbit. Wheel / dolly.",16,settings_box)
	_button("Close",func():settings.hide();router.reset_control_input(),settings_layout)
	settings.hide()
	rating_panel = _panel(hud)
	rating_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var rating_box := VBoxContainer.new()
	rating_panel.add_child(rating_box)
	_label("TEST COMPLETE",27,rating_box,COLORS[0])
	_label("Optional feel ratings  /  1 low - 5 high",17,rating_box)
	for metric in ["precision","comfort","weight","fairness","retry"]:
		var key: String = metric
		var line := HBoxContainer.new()
		rating_box.add_child(line)
		var metric_label := _label(key,17,line)
		metric_label.custom_minimum_size.x = 120
		for value in range(1,6):
			var score := value
			_button(str(score),func():trial.ratings[key]=score,line)
	_button("Save ratings & continue",func():_save_trial("rated");rating_panel.hide(),rating_box)
	rating_panel.hide()
	settings.visibility_changed.connect(_refresh_pointer_capture)
	rating_panel.visibility_changed.connect(_refresh_pointer_capture)

func _set_hold_mode(on: bool) -> void:
	if input_profile>=1 and not on:
		hold_toggle.set_pressed_no_signal(true)
		return
	hold_mode = on
	if not trial.is_empty():
		trial.grip_mode = "hold" if on else "toggle"
	if on and is_instance_valid(controller):
		for hand in 2:
			if not Input.is_action_pressed("grip_left" if hand == 0 else "grip_right"):
				controller.release_grip(hand,"hold_mode_enabled")
	message("Hold each mouse button to grip; release it to let go." if on else "Toggle mode: click to grip, click again to let go.")

func _controls_hint() -> String:
	if input_profile==2:
		return "Mouse / Virtual hands + supported effort    Hold LMB / RMB / Grip    WASD / Swing or walk    MMB / Orbit    Esc / Controls"
	if input_profile==1:
		return "Hold LMB / RMB + drag up / Pull; down / Lower    WASD / 3D swing or walk    MMB / Orbit    Wheel / Dolly    R / Retry"
	return "WASD / Walk or climb    Hold LMB / RMB / Grip    %s / Hold to load, release to launch    MMB / Orbit    Wheel / Dolly" % router.prompt("launch")

func _held_grips() -> Array[bool]:
	return [Input.is_action_pressed("grip_left"),Input.is_action_pressed("grip_right")]

func _launch_allowed() -> bool:
	return input_profile==0 or experimental_launch_enabled

func _control_owner() -> String:
	if settings.visible or binding_action!="" or rating_panel.visible:
		return "UI"
	if orbiting:
		return "CAMERA"
	if input_profile==2:return "FOCUS" if contextual_paused else "GAME"
	if not get_viewport().get_visible_rect().has_point(pointer):
		return "BOUNDARY"
	var hovered := get_viewport().gui_get_hovered_control()
	return "UI" if hovered!=null else "GAME"

func _set_input_profile(profile: int) -> void:
	input_profile = clampi(profile,0,2)
	router.reset_control_input()
	contextual.reset()
	contextual_paused=false
	if is_instance_valid(profile_choice):
		profile_choice.select(input_profile)
	if input_profile>=1 and not hold_mode:
		_set_hold_mode(true)
	if is_instance_valid(hold_toggle):
		hold_toggle.disabled = input_profile>=1
		hold_toggle.set_pressed_no_signal(hold_mode)
	if is_instance_valid(launch_toggle):
		launch_toggle.disabled = input_profile==0
	if is_instance_valid(controller):
		controller.set_control_profile(input_profile)
		controller.experimental_launch_enabled = experimental_launch_enabled
	if not trial.is_empty():
		trial.control_profile = input_profile
	controls_label.text = _controls_hint()
	_update_objective()
	_refresh_pointer_capture()
	message("Hold to grip. Drag up to pull, down to lower. WASD swings through your grips." if input_profile==1 else "Baseline / W pulls, S lowers, A/D biases, Space charges a launch.")
	if input_profile==2:message("Relative mouse aims free hands and requests supported effort. Hold LMB / RMB. Escape / Controls.")

func _update_objective() -> void:
	objective_label.text = level.objective
	if input_profile==1:
		if level_id==1:
			objective_label.text = "Hold your grip and drag up to pull. WASD swings in 3D.\nBuild momentum, release and catch the next reachable surface."
		elif level_id==3:
			objective_label.text = "Hold the two targets and drag to change arm length.\nFoot contacts are optional; baseline profile 0 retains the W-driven feet comparison."
	elif input_profile==2:
		objective_label.text="Move the L / R virtual aims onto reachable surfaces. Hold that hand's button.\nMouse down / pull; up / extend through supported effort. WASD swings."

func _refresh_pointer_capture() -> void:
	if not is_instance_valid(settings) or not is_instance_valid(rating_panel):return
	var capture: bool=input_profile==2 and not contextual_paused and not settings.visible and not rating_panel.visible
	contextual.clear_motion()
	contextual_rebase=true
	if DisplayServer.get_name()!="headless":
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(controller) and input_profile==2:
		controller.set_contextual_effort(Vector2.ZERO,camera.global_basis.x)
		controller.clear_free_hand_targets()

func _exit_tree() -> void:
	if input_profile==2 and DisplayServer.get_name()!="headless":Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _set_experimental_launch(on: bool) -> void:
	experimental_launch_enabled = on
	if is_instance_valid(controller):
		controller.experimental_launch_enabled = on
		if not on and input_profile>=1:
			controller.cancel_launch()

func _set_predictive_grip(on: bool) -> void:
	predictive_grip_enabled = on
	if is_instance_valid(predictive_toggle):
		predictive_toggle.set_pressed_no_signal(on)
	prediction_clock = 0.0
	if is_instance_valid(controller):
		controller.tuning.predictive_grip = on
		if not on:
			for id in 2:
				if controller.get_hand_state(id)=="REACHING" and controller.hands[id].get("predictive_wait",false):
					grip_intents.release(controller,id)

func _set_physical_feet(on: bool) -> void:
	physical_feet_enabled = on
	if is_instance_valid(feet_toggle):
		feet_toggle.set_pressed_no_signal(on)
	if is_instance_valid(controller):
		controller.tuning.physical_feet = on
		if controller.feet_solver!=null:
			controller.feet_solver.reset()
