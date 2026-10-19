extends Node3D

const Controller = preload("res://features/grip_up/scripts/climbing_controller.gd")
const CameraRig = preload("res://features/grip_up/scripts/climbing_camera.gd")
const Targeting = preload("res://features/grip_up/scripts/grip_targeting.gd")
const InputRouter = preload("res://features/grip_up/scripts/climbing_input_router.gd")
const BipedProfile = preload("res://features/grip_up/resources/biped_tuning.gd")
const BipedVisual = preload("res://features/grip_up/scripts/biped_visual.gd")
const GroundLocomotion = preload("res://features/grip_up/scripts/ground_locomotion.gd")
const LEVELS = [preload("res://features/grip_up/scenes/static_climb.tscn"), preload("res://features/grip_up/scenes/swing_and_catch.tscn"), preload("res://features/grip_up/scenes/reactive_structure.tscn")]
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

func _ready() -> void:
	router.setup()
	get_window().min_size = Vector2i(1024,576)
	_setup_lighting()
	camera = CameraRig.new()
	add_child(camera)
	_setup_ui()
	load_test(0)
	get_window().focus_exited.connect(func():
		orbiting = false
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
	camera.reset(torso,controller)
	trial = {"test":index,"character":"biped","grip_mode":"hold" if hold_mode else "toggle","fixed_beam":fixed_beam,"elapsed":0.0,"first_grab_seconds":-1.0,"goal_seconds":-1.0,"attempts":0,"misses":0,"slips":0,"falls":0,"transfers":0,"inputs":0,"large_step_events":0,"max_speed":0.0,"max_spin":0.0,"max_force_used":0.0,"ratings":{}}
	session_ticks = 0
	previous_position = torso.position
	previous_states = ["FREE","FREE"]
	stable_goal = 0
	won = false
	rating_panel.hide()
	title_label.text = level.title
	objective_label.text = level.objective
	beam_button.visible = index == 2
	beam_button.text = "F  /  " + ("FIXED BEAM" if fixed_beam else "HINGED BEAM")
	for i in mode_buttons.size():
		mode_buttons[i].button_pressed = i == index
	message("WASD to walk. Hold LMB / RMB over a hold to climb. Release the button to let go.")

func message(text: String) -> void:
	hint = text
	hint_time = 4.0

func _input(event: InputEvent) -> void:
	if event.is_action_released("launch") and is_instance_valid(controller):
		if settings.visible or binding_action!="":
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
				controller.release_grip(hand)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("launch") and not event.is_echo() and not settings.visible:
		if not controller.request_launch_charge(true):
			message("Grip a surface first, then hold %s to prepare a launch." % router.prompt("launch"))
	if event is InputEventMouseMotion:
		pointer = event.position
		if orbiting:
			camera.orbit(event.relative)
	if event is InputEventMouseButton:
		pointer = event.position
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			orbiting = event.pressed
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
	var hit: Dictionary = targeting.candidate(camera,pointer,torso)
	if hit.is_empty():
		trial.misses += 1
		message("Aim at a solid surface within arm's reach. Hold LMB / RMB to grip that exact point.")
		return false
	var ok: bool = controller.request_grip(hand,hit.collider,hit.position,hit.normal)
	if not ok:
		trial.misses += 1
		message("Hold out of reach or blocked. Move closer with your attached arm.")
	return ok

func toggle_beam() -> void:
	fixed_beam = not fixed_beam
	load_test(2)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller):
		return
	session_ticks += 1
	trial.elapsed += delta
	var blocked := settings.visible or binding_action != ""
	if blocked:
		controller.cancel_launch()
	ground_motor.enabled = not blocked
	ground_motor.move_intent = Input.get_vector("bias_left","bias_right","contract","extend")
	controller.set_climb_intent(0.0 if blocked else Input.get_action_strength("contract"),0.0 if blocked else Input.get_action_strength("extend"),0.0 if blocked else Input.get_axis("bias_left","bias_right"),camera.global_basis.x)
	trial.max_speed = maxf(trial.max_speed,torso.linear_velocity.length())
	trial.max_spin = maxf(trial.max_spin,torso.angular_velocity.length())
	if session_ticks > 3 and torso.position.distance_to(previous_position) > 0.8:
		trial.large_step_events += 1
	previous_position = torso.position
	var attached := 0
	var total_force := 0.0
	for i in 2:
		var state: String = controller.get_hand_state(i)
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
	var goal: bool = (on_final_hold or wall_top) and attached > 0 and torso.linear_velocity.length() < 3.0
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
	candidate = targeting.candidate(camera,pointer,torso)
	target_marker.visible = not candidate.is_empty() and not settings.visible
	if target_marker.visible:
		target_marker.global_position = candidate.position + candidate.normal * 0.025
		var reachable := false
		for i in 2:
			if controller.get_shoulder_world(i).distance_to(candidate.position) <= controller.get_max_reach():
				reachable = true
			target_marker.material_override.albedo_color = Color("b1f5d8") if reachable else Color("e66d68")
	for i in 2:
		var end: Vector3 = biped.palms[i]
		hand_meshes[i].global_position = end
		var hand: Dictionary = controller.hands[i]
		var warning: String = " / " + str(hand.reason) if hand.state in ["SLIPPING","RELEASED"] else ""
		if hand.state == "ATTACHED" and controller.get_arm_force(i).length() > hand.grip_limit * 0.75:
			warning = " / STRAINED"
		hand_labels[i].text = ("LEFT / CYAN" if i==0 else "RIGHT / AMBER") + "\n" + hand.state + warning
		if hand.state in ["ATTACHED","SLIPPING"]:
			hand_labels[i].text += "\n%.2f m  /  %.0f N" % [hand.actual_length,controller.get_arm_force(i).length()]
	status_label.text = hint if hint_time > 0 else ("WASD / Walk relative to camera. MMB / Orbit. Hold LMB / RMB on any surface to climb." if ground_motor.grounded and not ground_motor.has_climbing_intent() else "Grip anywhere within reach. W / Pull. S / Lower. Keep the other hand attached while transferring.")
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

func _save_trial(outcome: String) -> void:
	if trial.is_empty():
		return
	var row := trial.duplicate(true)
	row.outcome = outcome
	row.timestamp = Time.get_datetime_string_from_system(true)
	row.physics_hz = Engine.physics_ticks_per_second
	var file := FileAccess.open("user://trials.jsonl",FileAccess.READ_WRITE if FileAccess.file_exists("user://trials.jsonl") else FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(JSON.stringify(row))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
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
	_label("PHYSICS CLIMBING LAB  /  0.1",15,branding,COLORS[0])
	for i in 3:
		var index := i
		var button := _button(["01  STATIC CLIMB","02  SWING & CATCH","03  REACTIVE STRUCTURE"][i],func():load_test(index),row)
		button.toggle_mode = true
		mode_buttons.append(button)
	_button("Controls",func():settings.visible=not settings.visible,row)
	var mission := VBoxContainer.new()
	mission.position = Vector2(40,132)
	mission.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(mission)
	title_label = _label("",23,mission,COLORS[0])
	objective_label = _label("",18,mission)
	checkpoint_label = _label("",15,mission,Color("91aab5"))
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
	settings.position = Vector2(420,150)
	var settings_box := VBoxContainer.new()
	settings.add_child(settings_box)
	_label("CONTROLS / click a binding to change it",23,settings_box,COLORS[0])
	var hold := CheckButton.new()
	hold.text = "Hold to grip (default) / disable for toggle"
	hold.button_pressed = hold_mode
	hold.toggled.connect(_set_hold_mode)
	settings_box.add_child(hold)
	for action in router.DEFAULTS:
		var binding := str(action)
		var line := HBoxContainer.new()
		settings_box.add_child(line)
		var binding_names := {"contract":"forward / pull","extend":"backward / lower","bias_left":"left / bias left","bias_right":"right / bias right"}
		var name_label := _label(binding_names.get(binding,binding.replace("_"," ")),18,line)
		name_label.custom_minimum_size.x = 190
		binding_buttons[binding] = _button(router.prompt(binding),func():
			binding_action=binding
			binding_status.text="Press a key or mouse button. Escape cancels."
		,line)
	binding_status = _label("Middle mouse / orbit. Wheel / dolly.",16,settings_box)
	_button("Close",func():settings.hide(),settings_box)
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

func _set_hold_mode(on: bool) -> void:
	hold_mode = on
	if not trial.is_empty():
		trial.grip_mode = "hold" if on else "toggle"
	if on and is_instance_valid(controller):
		for hand in 2:
			if not Input.is_action_pressed("grip_left" if hand == 0 else "grip_right"):
				controller.release_grip(hand,"hold_mode_enabled")
	message("Hold each mouse button to grip; release it to let go." if on else "Toggle mode: click to grip, click again to let go.")

func _controls_hint() -> String:
	return "WASD / Walk or climb    Hold LMB / RMB / Grip    %s / Hold to load, release to launch    MMB / Orbit    Wheel / Dolly" % router.prompt("launch")
