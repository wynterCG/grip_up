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
const TransferProgress = preload("res://features/grip_up/scripts/transfer_route_progress.gd")
const ClimbingRouteProgress = preload("res://features/grip_up/scripts/climbing_route_progress.gd")
const ReachAssessment = preload("res://features/grip_up/scripts/reach_assessment.gd")
const ContextualInput = preload("res://features/grip_up/scripts/contextual_arm_input.gd")
const MantleV08=preload("res://features/grip_up/scripts/mantle_support_coordinator.gd")
const HybridMantle=preload("res://features/grip_up/scripts/hybrid_mantle_controller.gd")
const HybridLevel=preload("res://features/grip_up/scripts/hybrid_mantle_level.gd")
const HYBRID_SCENARIOS=["LOW","HIGH","NARROW","CEILING","OCCUPIED","DYNAMIC","DOUBLE"]
const V08_LEVELS=[preload("res://features/grip_up/scenes/mantle_v08_low.tscn"),preload("res://features/grip_up/scenes/mantle_v08_high.tscn")]
const LEVELS = [preload("res://features/grip_up/scenes/static_climb.tscn"), preload("res://features/grip_up/scenes/swing_and_catch.tscn"), preload("res://features/grip_up/scenes/reactive_structure.tscn"), preload("res://features/grip_up/scenes/foot_support.tscn"),preload("res://features/grip_up/scenes/transfer_lab.tscn"),preload("res://features/grip_up/scenes/swing_reach_lab.tscn"),preload("res://features/grip_up/scenes/intent_step.tscn"),preload("res://features/grip_up/scenes/intent_hang.tscn"),preload("res://features/grip_up/scenes/intent_traverse.tscn"),preload("res://features/grip_up/scenes/intent_corner.tscn"),preload("res://features/grip_up/scenes/climbing_route.tscn"),preload("res://features/grip_up/scenes/mantle.tscn")]
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
var reach_prediction_enabled := false
var catch_buffer_enabled := false
var catch_buffer_duration := .12
var allow_out_of_reach_grip_targets := false
var pending_grip_feedback_enabled := true
var distant_target_toggle: CheckButton
var pending_markers: Array[MeshInstance3D]=[]
var reach_assessor = ReachAssessment.new()
var reach_advice: Array[Dictionary] = [{},{}]
var attempt_assessments: Array[Dictionary] = [{},{}]
var physical_feet_enabled := false
var input_profile := 2
var intent_climb_enabled := false
var contextual = ContextualInput.new()
var contextual_paused := false
var contextual_owner := "GAME"
var contextual_rebase := false
var aim_labels: Array[Label] = []
var posture_policy := 1
var posture_assist_enabled := true
var posture_tilt_assist_enabled := true
var supported_wasd_swing_enabled := true
var transfer_assist_enabled := false
var posture_variant := 0
var posture_variant_choice: OptionButton
var transfer_diagnostics_enabled := false
var transfer_route_spacing := .12
var transfer_session_id := ""
var transfer_progress = TransferProgress.new()
var climbing_route = ClimbingRouteProgress.new()
var mantle_standing:=false
var mantle_stable:=0.0
var mantle_walk_origin:=Vector3.ZERO
var mantle_completed:=false
var mantle_attempted:=false
var physics_mantle_v08_enabled:=false
var palm_compression_enabled:=false
var palm_wrist_support_enabled:=false
var adaptive_leg_collision_enabled:=false
var mantle_support_handoff_enabled:=false
var mantle_hanging_fixture_start:=false
var mantle_v08:Node
var mantle_overlay:Node3D
var hybrid_mantle_v09_enabled:=false
var contextual_vault_v10_enabled:=false
var hybrid_mantle:Node
var transfer_diagnostics_toggle: CheckButton
var posture_choice: OptionButton
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
		if is_instance_valid(hybrid_mantle):hybrid_mantle.focus_lost()
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
				_release_hand_input(hand,"input_focus_lost")
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
	reach_advice = [{},{}]
	attempt_assessments = [{},{}]
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
	transfer_session_id="%s_%d_%d" % [Time.get_datetime_string_from_system(true).replace(":","-"),OS.get_process_id(),Time.get_ticks_usec()]
	transfer_progress=TransferProgress.new()
	climbing_route=ClimbingRouteProgress.new()
	mantle_standing=false
	mantle_stable=0.0
	mantle_completed=false
	mantle_attempted=false
	checkpoint_active = checkpoint_active and use_checkpoint and index == 0
	world = Node3D.new()
	world.name = "TrialWorld"
	add_child(world)
	mantle_v08=null
	mantle_overlay=null
	hybrid_mantle=null
	if index>=14:
		level=HybridLevel.new()
		level.scenario=HYBRID_SCENARIOS[index-14]
	else:
		level = (LEVELS[index] if index<LEVELS.size() else V08_LEVELS[index-LEVELS.size()]).instantiate()
	if index in [12,13]:level.hanging_fixture_start=mantle_hanging_fixture_start
	level.fixed_beam = fixed_beam
	if index==4:level.vertical_spacing=transfer_route_spacing
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
	profile.predictive_grip = _capture_buffer_active()
	profile.allow_out_of_reach_grip_targets=_distant_targeting_active()
	if input_profile in [3,4] and catch_buffer_enabled:profile.capture_intent_buffer_duration=catch_buffer_duration
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
	if index>=14:torso.max_contacts_reported=16
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
		collision.name="TorsoCapsule" if segment.z>0 else "LowerCapsule"
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
	controller.intent_auto_mantle_enabled=index==11
	controller.physics_mantle_v08_enabled=index in [12,13] and physics_mantle_v08_enabled
	controller.palm_compression_enabled=controller.physics_mantle_v08_enabled and palm_compression_enabled
	controller.palm_wrist_support_enabled=controller.physics_mantle_v08_enabled and palm_wrist_support_enabled
	controller.transfer_event.connect(_on_transfer_event)
	controller.set_control_profile(input_profile)
	_apply_independent_settings()
	controller.experimental_launch_enabled = experimental_launch_enabled
	controller.sample_ready.connect(_record_capture)
	ground_motor = GroundLocomotion.new()
	ground_motor.name = "GroundLocomotion"
	world.add_child(ground_motor)
	ground_motor.configure(torso,controller,camera)
	ground_motor.process_physics_priority=-10 if input_profile==4 else 0
	biped = BipedVisual.new()
	biped.name = "BipedVisual"
	world.add_child(biped)
	biped.configure(torso,controller)
	biped.ground_motor = ground_motor
	if index in [12,13]:
		mantle_v08=MantleV08.new()
		world.add_child(mantle_v08)
		mantle_v08.configure(controller,ground_motor,level,torso.get_node("LowerCapsule"),foot_collision)
		mantle_v08.adaptive_enabled=adaptive_leg_collision_enabled
		mantle_v08.handoff_enabled=mantle_support_handoff_enabled
		mantle_overlay=load("res://features/grip_up/scripts/mantle_collision_overlay.gd").new()
		world.add_child(mantle_overlay)
		mantle_overlay.body=torso
	if index>=14:
		hybrid_mantle=HybridMantle.new()
		world.add_child(hybrid_mantle)
		hybrid_mantle.contextual_vault_v10_enabled=contextual_vault_v10_enabled
		hybrid_mantle.configure(controller,ground_motor,biped,camera)
		hybrid_mantle.enabled=hybrid_mantle_v09_enabled and input_profile==4
		ground_motor.require_native_support=hybrid_mantle.enabled
		mantle_overlay=load("res://features/grip_up/scripts/mantle_collision_overlay.gd").new()
		world.add_child(mantle_overlay)
		mantle_overlay.body=torso
	hand_meshes.clear()
	pending_markers.clear()
	for i in 2:
		var grip := SphereMesh.new()
		grip.radius = 0.032
		grip.height = 0.064
		hand_meshes.append(_mesh(world,grip,COLORS[i]))
		hand_meshes[i].physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		var ring:=TorusMesh.new()
		ring.inner_radius=.022
		ring.outer_radius=.031
		ring.rings=16
		ring.ring_segments=8
		var marker:=_mesh(world,ring,COLORS[i])
		marker.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		marker.hide()
		pending_markers.append(marker)
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
	title_label.text = "CLIMB UP / "+level.scenario if level_id>=14 and contextual_vault_v10_enabled else level.title
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
	if input_profile in [1,3,4] and event is InputEventMouseMotion:
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
				_release_hand_input(hand)

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
	if is_instance_valid(hybrid_mantle) and not hybrid_mantle.allows_grip(hand):return false
	trial.inputs += 1
	var state: String = controller.get_hand_state(hand)
	if state in ["ATTACHED","SLIPPING","REACHING"]:
		if hold_mode:
			return true
		controller.release_grip(hand)
		message(("Left" if hand==0 else "Right") + " hand released")
		return true
	trial.attempts += 1
	attempt_assessments[hand]={}
	var hit: Dictionary = contextual.candidate(hand,controller,camera) if input_profile==2 else targeting.candidate(camera,pointer,torso)
	if hit.is_empty():
		controller.record_unselected_attempt(hand,"no_surface")
		trial.misses += 1
		message("Aim at a visible grabbable surface. Hold LMB / RMB to remember that exact point." if _distant_targeting_active() else "Aim at a solid surface within arm's reach. Hold LMB / RMB to grip that exact point.")
		return false
	if input_profile in [3,4] and (reach_prediction_enabled or catch_buffer_enabled):
		attempt_assessments[hand]=reach_assessor.evaluate(controller,hand,hit.collider,hit.position,hit.normal).duplicate(true)
	var ok: bool
	if _distant_targeting_active() and hold_mode:
		ok=controller.request_held_grip(hand,hit.collider,hit.position,hit.normal)
	else:
		ok=grip_intents.press(controller,hand,hit.collider,hit.position,hit.normal) if _capture_buffer_active() and hold_mode else controller.request_grip(hand,hit.collider,hit.position,hit.normal)
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
	var blocked := settings.visible or binding_action != "" or (input_profile==2 and contextual_paused) or (input_profile in [2,3,4] and rating_panel.visible)
	if blocked:
		controller.cancel_launch()
		grip_intents.clear(controller)
		router.reset_control_input("UI")
		controller.clear_drag_requests()
		contextual.clear_motion()
	if _capture_buffer_active():
		for hand in 2:
			if not Input.is_action_pressed("grip_left" if hand==0 else "grip_right"):
				grip_intents.release(controller,hand)
		grip_intents.update(controller)
	if _distant_targeting_active():
		for hand in 2:
			var pressed:bool=Input.is_action_pressed("grip_left" if hand==0 else "grip_right")
			if controller.get_hand_state(hand)=="REACHING" and controller.pending_diagnostics(hand).get("active",false):
				controller.set_hand_held(hand,pressed and not blocked,"ui_blocked" if blocked else "input_released")
			elif not pressed:controller.set_hand_held(hand,false)
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
	elif input_profile==2:
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
	elif input_profile==3:
		# Independent aim never calls either mouse-effort or arm-drag APIs.
		controller.set_climb_intent(0,0,0,camera.global_basis.x)
		controller.set_swing_intent(Vector3.ZERO if blocked or not supported_wasd_swing_enabled else router.swing_direction(camera.global_basis.x),camera.global_basis.x)
	else:
		controller.set_climb_intent(0,0,0,camera.global_basis.x)
		controller.set_swing_intent(Vector3.ZERO,camera.global_basis.x)
		router.set_owner("UI" if blocked else "GAME")
		controller.set_traversal_input(Vector2.ZERO if blocked else router.traversal_input(),camera.global_basis.x)
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
	if level_id==4:
		transfer_progress.update(controller,level.transfer_points,trial.elapsed)
	if level_id==10:
		climbing_route.update(controller,ground_motor.grounded,level.route_zones,trial.elapsed,delta)
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
	elif level_id==4:
		goal=transfer_progress.transfers>=10 and attached>0
	elif level_id==5:
		goal=goal and torso.position.x>-.15
	else:
		goal = goal and torso.position.x > 0.4
	if level_id>=6:
		goal=controller.hands.any(func(hand):return hand.state=="ATTACHED" and Vector3(hand.anchor_world).distance_to(level.finish_point)<.12) and torso.linear_velocity.length()<1.0
	if level_id==10:goal=climbing_route.completed
	if level_id==11:
		# A grip on the edge is not a top-out. Only real top ground may qualify.
		var top_ground:bool=ground_motor.grounded and ground_motor.support_body==level.platform
		var hands_free:bool=controller._attached_ids().is_empty() and not ground_motor.has_climbing_intent()
		mantle_attempted=mantle_attempted or controller.hands.any(func(hand):return hand.state=="ATTACHED" and hand.support==level.platform and hand.anchor_world.y<=level.top_y+.03)
		if not top_ground and not mantle_completed:mantle_standing=false
		mantle_stable=mantle_stable+delta if top_ground and hands_free and mantle_attempted else 0.0
		if mantle_stable>=.3 and not mantle_standing:
			mantle_standing=true
			mantle_walk_origin=torso.global_position
		if top_ground and hands_free and mantle_standing and ground_motor.walking:
			mantle_completed=mantle_completed or torso.global_position.slide(Vector3.UP).distance_to(mantle_walk_origin.slide(Vector3.UP))>=.30
		goal=mantle_completed
	if level_id in [12,13]:goal=mantle_v08.completed
	if level_id>=14:goal=hybrid_mantle.completed and (level.scenario!="DOUBLE" or hybrid_mantle.commits>=2)
	stable_goal = stable_goal + delta if goal else 0.0
	if stable_goal > 0.5 and not won:
		won = true
		trial.goal_seconds = trial.elapsed
		_save_trial("goal")
		if level_id>=10:
			if level_id!=10:message("TOP-OUT COMPLETE / Actual support restored. R to retry.")
			else:
				message("ROUTE COMPLETE / R to try again. You kept control through the whole climb.")
		else:
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
	if (predictive_grip_enabled or (input_profile in [3,4] and reach_prediction_enabled)) and not candidate.is_empty() and prediction_clock<=0.0:
		for id in 2:
			var prediction_hit: Dictionary=contextual.candidate(id,controller,camera) if input_profile==2 else candidate
			capture_predictions[id] = controller.capture_predictor.evaluate(controller,id,prediction_hit.collider,prediction_hit.position,prediction_hit.normal) if not prediction_hit.is_empty() else {}
			reach_advice[id]=reach_assessor.evaluate(controller,id,prediction_hit.collider,prediction_hit.position,prediction_hit.normal) if input_profile in [3,4] and reach_prediction_enabled and not prediction_hit.is_empty() else {}
		prediction_clock = 0.05
		prediction_support_id = candidate.collider.get_instance_id()
		prediction_point = candidate.position
	if candidate.is_empty():
		capture_predictions = [{},{}]
		reach_advice = [{},{}]
	capture_debug.update_state(controller,reach_advice if input_profile in [3,4] and reach_prediction_enabled else capture_predictions,debug_visible)
	prediction_label.visible = predictive_grip_enabled and not _distant_targeting_active() and not settings.visible and not candidate.is_empty()
	target_marker.visible = not candidate.is_empty() and not settings.visible
	if target_marker.visible:
		target_marker.global_position = candidate.position + candidate.normal * 0.025
		var reachable := false
		var selectable_hands:=0
		for i in 2:
			if input_profile in [3,4] and controller.get_hand_state(i) not in ["FREE","RELEASED"]:continue
			selectable_hands+=1
			if controller.get_shoulder_world(i).distance_to(candidate.position) <= controller.get_max_reach():
				reachable = true
		target_marker.material_override.albedo_color = Color("8b9297") if input_profile in [3,4] and selectable_hands==0 else Color("b1f5d8") if reachable else Color("e66d68")
		if _distant_targeting_active() and selectable_hands>0 and not reachable:target_marker.material_override.albedo_color=Color("f0b85c")
		if predictive_grip_enabled and not _distant_targeting_active():
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
	if input_profile in [3,4] and transfer_diagnostics_enabled and debug_visible and not candidate.is_empty() and not settings.visible:
		prediction_label.visible=true
		var hints: Array[String]=[]
		for id in 2:
			if controller.get_hand_state(id) in ["FREE","RELEASED"]:
				var distance: float=controller.get_shoulder_world(id).distance_to(candidate.position)
				hints.append(("L" if id==0 else "R")+" / "+("IN RANGE" if distance<=controller.get_max_reach() else "NEEDS SWING")+" %.3f m" % distance)
		prediction_label.text="GEOMETRY ONLY / "+" | ".join(hints)
	if input_profile in [3,4] and reach_prediction_enabled and not candidate.is_empty() and not settings.visible:
		prediction_label.visible=true
		var advice_hints: Array[String]=[]
		for id in 2:
			if controller.get_hand_state(id) not in ["FREE","RELEASED"]:continue
			var advice: Dictionary=reach_advice[id]
			var category: String=advice.get("classification","UNAVAILABLE")
			if category=="UNSAFE CATCH":category+=" (estimate)"
			advice_hints.append(("L" if id==0 else "R")+" / "+category)
		prediction_label.text="ADVISORY / "+" | ".join(advice_hints)
	for i in 2:
		var end: Vector3 = biped.palms[i]
		hand_meshes[i].global_position = end
		var hand: Dictionary = controller.hands[i]
		var warning: String = " / " + str(hand.reason) if hand.state in ["SLIPPING","RELEASED"] else ""
		if predictive_grip_enabled and hand.get("capture",{}).get("failure_reason","")!="" and hand.state in ["FREE","RELEASED"]:
			warning = "\n"+_capture_reason(hand.capture.failure_reason)
		if hand.state == "ATTACHED" and controller.get_arm_force(i).length() > hand.grip_limit * 0.75:
			warning = " / STRAINED"
		if input_profile==4 and hand.state=="ATTACHED" and hand.actual_length>controller.get_max_reach()-.035:
			warning=" / EXTENDED" if warning.is_empty() else warning+" / EXTENDED"
		hand_labels[i].text = ("LEFT / CYAN" if i==0 else "RIGHT / AMBER") + "\n" + hand.state + warning
		if is_instance_valid(hybrid_mantle) and hybrid_mantle.active():hand_labels[i].text=("LEFT / CYAN" if i==0 else "RIGHT / AMBER")+"\nMANTLING"
		if controller.physics_mantle_v08_enabled and hand.get("contact_mode","") in ["PALM_CONTACT","PALM_SLIPPING"]:
			hand_labels[i].text=("LEFT / CYAN" if i==0 else "RIGHT / AMBER")+"\n"+("PALM / SUPPORTING" if Vector3(hand.force).length()>1 else "PALM / UNLOADED")+warning
		var pending:Dictionary=controller.pending_diagnostics(i)
		var committed:bool=_distant_targeting_active() and pending.get("active",false) and hand.state=="REACHING"
		pending_markers[i].visible=committed and pending_grip_feedback_enabled
		if committed:
			var presentation:String="TARGET PENDING\nPATH BLOCKED" if pending.get("blocked",false) else "TARGET PENDING\nOUT OF REACH" if pending.get("substate","")=="PENDING_OUT_OF_REACH" else "REACHING"
			hand_labels[i].text=("LEFT / CYAN" if i==0 else "RIGHT / AMBER")+"\n"+presentation
			var contact_normal:Vector3=pending.get("normal_world",Vector3.FORWARD)
			var render_target:Vector3=pending.get("target_world",hand.target_world)
			if hand.anchor!=null and hand.anchor.is_valid():
				var support_pose:Transform3D=hand.anchor.support_body().get_global_transform_interpolated()
				render_target=support_pose*hand.anchor.local_point
				contact_normal=(support_pose.basis.inverse().transposed()*hand.anchor.local_normal).normalized()
			pending_markers[i].global_position=render_target+contact_normal*.012
			pending_markers[i].global_basis=Basis(Quaternion(Vector3.UP,contact_normal.normalized()))
			pending_markers[i].scale=Vector3.ONE*(1.25 if pending.get("substate","")=="PENDING_OUT_OF_REACH" else .85)
			pending_markers[i].material_override.albedo_color=COLORS[i].lerp(Color("8b9297"),.55) if pending.get("blocked",false) else COLORS[i]
		if hand.state in ["ATTACHED","SLIPPING"] and input_profile!=4:
			hand_labels[i].text += "\n%.2f m  /  %.0f N" % [hand.actual_length,controller.get_arm_force(i).length()]
			if input_profile>=1:
				hand_labels[i].text += "\nTarget / %.2f m" % hand.rest_length
			if input_profile in [3,4]:
				var planned: Dictionary=controller.telemetry().get("posture",{})
				hand_labels[i].text += "\nPlan / %.2f m" % planned.get("planned_lengths",{}).get(i,hand.rest_length)
	status_label.text = hint if hint_time > 0 else ("WASD / Walk relative to camera. MMB / Orbit. Hold LMB / RMB on any surface to climb." if ground_motor.grounded and not ground_motor.has_climbing_intent() else "Grip anywhere within reach. W / Pull. S / Lower. Keep the other hand attached while transferring.")
	if input_profile==1 and hint_time<=0 and ground_motor.has_climbing_intent():
		status_label.text = "Hold each grip. Drag up / pull; down / lower, also while aiming. WASD / supported 3D swing."
	if input_profile==2 and hint_time<=0:
		var count: int=controller._attached_ids().size()
		status_label.text=["Move mouse / aim free hands. Hold LMB or RMB / grip. WASD / walk.","ONE GRIP / Aim the free hand. Mouse down / pull; up / extend with supported effort.","TWO GRIPS / Mouse down / pull; up / extend; sideways / posture. WASD / 3D swing."][count]
		if contextual_paused:status_label.text="Click to resume. Escape / Controls."
	elif input_profile in [3,4] and hint_time<=0:
		status_label.text="AIM ONLY / Pick the next surface freely. Hold LMB / RMB. Supports drive bounded posture; WASD swings."
	if input_profile in [3,4] and level_id==4 and hint_time<=0:
		status_label.text=("TEN TRANSFERS COMPLETE / R retries; Controls compares variants." if transfer_progress.transfers>=10 else "TRANSFER %d / 10 | Next painted guide %02d | Recoveries %d | Tab / diagnosis" % [transfer_progress.transfers,transfer_progress.next_contact,transfer_progress.recoveries])
	if input_profile==4 and hint_time<=0:
		status_label.text="CHOOSE YOUR SUPPORTS / Hold LMB or RMB. W/S up-down; A/D across. Release a hand to choose its next contact."
	feet_panel.visible = physical_feet_enabled and controller.feet_solver!=null
	if feet_panel.visible:
		feet_label.text = "FEET / AUTOMATIC"
		for i in 2:
			var foot: Dictionary = controller.feet_solver.feet[i]
			if input_profile==4:
				feet_label.text += "\n%s / %s" % ["L" if i==0 else "R","PLANTED" if foot.state=="SUPPORTING" and Vector3(foot.force).length()>1 else "SLIPPING" if foot.state=="SLIDING" else "REACHING" if foot.state=="PLANTING" else "FREE"]
			else:feet_label.text += "\n%s / %s  %.0f N" % ["L" if i==0 else "R",foot.state,Vector3(foot.force).length()]
	var launch: Dictionary = controller.telemetry()
	if launch.get("launch_state")=="CHARGING":
		status_label.text = "LAUNCH / %d%% — release %s to pull and let go." % [int(launch.get("launch_charge",0.0)*100.0),router.prompt("launch")]
	elif launch.get("launch_state")=="PULLING":
		status_label.text = "LAUNCH / reach for your next grip."
	checkpoint_label.text = "CHECKPOINT ACTIVE" if checkpoint_active else "R / QUICK RESET"
	if level_id==10:
		checkpoint_label.text="ROUTE COMPLETE / R to retry" if climbing_route.completed else "ROUTE / %d OF %d  |  R / retry" % [climbing_route.stage+1,level.route_zones.size()]
		if not climbing_route.completed:
			var zone:Dictionary=level.route_zones[climbing_route.stage]
			status_label.text=zone.hint if input_profile==4 else "COMPARE / Choose grips with the mouse. Existing posture policy moves the body; WASD requests supported swing."
	debug_label.visible = debug_visible
	if level_id==11:
		checkpoint_label.text="TOP-OUT COMPLETE / R to retry" if mantle_completed else "LEDGE EXPERIMENT / R to retry"
		status_label.text="Release the hands and walk across the top." if mantle_standing else "Hold the edge and press W to try. Physical limits can stop this experiment."
	if level_id in [12,13]:
		checkpoint_label.text="v0.8 / %s  |  R / retry"%mantle_v08.phase
		status_label.text="H0 / Release one hand and aim onto the top. Hold W to request effort; keep a real support."
		mantle_overlay.visible=debug_visible
	if level_id>=14:
		checkpoint_label.text="W / mantle" if hybrid_mantle.candidate.get("eligible",false) and hybrid_mantle.state in ["DYNAMIC","PREPARE"] else ""
		status_label.text="Climbing onto the ledge..." if hybrid_mantle.active() else "Walk forward on top." if hybrid_mantle.state=="DYNAMIC_GROUNDED" else "Grip near the upper edge, then hold W."
		if hybrid_mantle.state=="BLOCKED_RECOVERY":status_label.text="Path blocked. R / retry."
		elif hybrid_mantle.state=="DYNAMIC":
			var refusal:String=hybrid_mantle.candidate.get("eligibility_reason","")
			if refusal=="TOO_NARROW":status_label.text="There is not enough room to stand on this ledge."
			elif refusal=="TARGET_OCCUPIED":status_label.text="The landing space is blocked."
			elif refusal=="UNSUPPORTED_DYNAMIC_PLATFORM":status_label.text="This ledge moves. Keep climbing normally here."
		mantle_overlay.visible=debug_visible
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
		elif input_profile in [3,4]:
			var plan: Dictionary=launch.get("posture",{})
			debug_label.text += "\n\nINDEPENDENT AIM / %s | mouse never commands length\n%s / %s | event %s\nBody error %s | target rates %s\nTarget acceleration %s | load shares %s" % [["A","B","C"][posture_policy],plan.get("state","IDLE"),plan.get("reason","none"),str(plan.get("event",0)),str(plan.get("body_error",Vector3.ZERO)),str(plan.get("rates",{})),str(plan.get("accelerations",{})),str(plan.get("allocations",{}))]
		if input_profile in [3,4] and transfer_diagnostics_enabled:
			debug_label.text=_transfer_debug_text(launch)
		if input_profile==4:
			var movement:Dictionary=launch.get("intent_locomotion",{})
			debug_label.text="INTENT-DRIVEN / %s | %s\nRequest %s | desired v %s\nActual v %s | position %s\nGround authority %s | targets %s\nFrame %s" % [movement.get("support_mode","PENDING"),movement.get("movement_block_reason",""),str(movement.get("movement_intent_world",Vector3.ZERO)),str(movement.get("desired_com_velocity",Vector3.ZERO)),str(movement.get("actual_relative_velocity",torso.linear_velocity)),str(torso.global_position),str(ground_motor.motor_authority),str(movement.get("planned_arm_rest_lengths",{})),str(movement.get("frame",{}))]
			debug_label.text+="\nHands %.1f /360 N | feet %.1f /180 N\nCombined moment %s /150 Nm" % [launch.get("total_force",0),launch.get("leg_force",0),str(launch.get("combined_ground_climb_torque",launch.get("torque",Vector3.ZERO)))]
			if level_id==11:
				var ledge:Dictionary=launch.get("ledge_transfer",{})
				debug_label.text+="\nLedge / %s | %s\nDestination free %s | top ground %s | walked away %s"%[ledge.get("status",""),ledge.get("reason",""),str(ledge.get("destination_clear",false)),str(ground_motor.grounded and ground_motor.support_body==level.platform),str(mantle_completed)]
			if level_id in [12,13]:
				debug_label.text+="\nv0.8 / %s | flex %.2f | %s\nGround %s | walk %.3f /0.30 m"%[mantle_v08.phase,mantle_v08.legs.achieved_flex,mantle_v08.legs.reason,str(mantle_v08.data.get("actual_top_ground",false)),mantle_v08.ground_distance]
			if level_id>=14:
				debug_label.text+="\nv0.9 / %s | %.2f | %s\nAuthority %s | walk %.3f /0.30 m"%[hybrid_mantle.state,hybrid_mantle.progress,hybrid_mantle.reason,hybrid_mantle.data.get("motor_ownership","DYNAMIC"),hybrid_mantle.walk_distance]

func _transfer_debug_text(data: Dictionary) -> String:
	var out: String="TRANSFER DIAGNOSTICS / %d Hz | aim never changes length\nBody v %s | spin %s" % [Engine.physics_ticks_per_second,str(torso.linear_velocity),str(torso.angular_velocity)]
	var diagnostic: Dictionary=controller.transfer_diagnostics()
	for id in 2:
		var hand: Dictionary=controller.hands[id]
		var last: Dictionary=diagnostic.get("last_by_hand",{}).get(id,{})
		var pending:Dictionary=controller.pending_diagnostics(id)
		var shown_length:float=controller.get_shoulder_world(id).distance_to(controller.get_hand_world(id)) if pending.get("active",false) and hand.state=="REACHING" else hand.actual_length
		out+="\n\n%s / %s | %s / %s\nShoulder %s | anchor %s\nActual %.3f / requested %.3f / planned %.3f m\nAttempt %s | distance %s | travel %s" % ["LEFT" if id==0 else "RIGHT",hand.state,last.get("stage","none"),last.get("code","none"),str(controller.get_shoulder_world(id)),str(hand.anchor_world),shown_length,hand.rest_length,hand.get("planned_length",hand.rest_length),str(last.get("attempt_id","none")),"%.3f m" % last.anatomical_distance if last.has("anatomical_distance") else "unknown","%.2f s" % last.get("elapsed",0)]
		if pending.get("active",false):
			out+="\n%s | held %s | target %.3f m | margin %.3f m | pending %.2f s\nGesture %.2f /4 m/s | transport %.2f | world %.2f | blocker %s" % [pending.get("substate","PENDING"),pending.get("held",false),pending.get("distance",0),pending.get("reach_margin",0),pending.get("pending_time",0),pending.get("gesture_speed",0),pending.get("transport_speed",0),pending.get("world_speed",0),str(pending.get("blocker_id",0))]
	var refinement: Dictionary=data.get("transfer_posture",{})
	var twist: Dictionary=refinement.get("twist",{})
	out+="\nAttitude %s | blend %.2f | relative axial error %s" % [refinement.get("status","P0"),twist.get("blend",0),"%.3f rad" % twist.axial_error if twist.has("axial_error") else "P0 reference"]
	var motion: Dictionary=diagnostic.get("motion",{})
	out+="\n\nHands %.1f /360 N | torque %.1f /150 Nm\nPendulum %.2f rad / %.2f rad/s | trunk twist %.2f / tilt %.2f rad\nEstimated arm/moment power %.1f / %.1f W | work %.1f / %.1f J\nRelative body energy %.2f linear / %.2f angular J" % [data.get("total_force",0),Vector3(data.get("torque",Vector3.ZERO)).length(),motion.get("pendulum_angle",0),motion.get("pendulum_angular_speed",0),motion.get("trunk_twist",0),motion.get("trunk_tilt",0),motion.get("arm_power",0),motion.get("grip_moment_power",0),motion.get("estimated_arm_work",0),motion.get("estimated_grip_moment_work",0),motion.get("relative_translation_energy",0),motion.get("relative_rotation_energy",0)]
	if level_id==4:out+="\nTransfers %d /10 | next %02d | recoveries %d" % [transfer_progress.transfers,transfer_progress.next_contact,transfer_progress.recoveries]
	out+="\nSwing %s | incremental %.2f W / %.2f J" % [motion.get("swing_phase","NEUTRAL"),motion.get("swing_power",0),motion.get("estimated_swing_work",0)]
	return out

func _open_transfer_lab(index: int) -> void:
	_set_input_profile(3)
	transfer_diagnostics_enabled=true
	transfer_diagnostics_toggle.set_pressed_no_signal(true)
	settings.hide()
	load_test(index)
	message("Transfer study / hold LMB and RMB. Tab shows reach and per-attempt diagnoses.")

func _open_distant_lab(index:int) -> void:
	_open_transfer_lab(index)
	_set_distant_targeting(true)
	_update_objective()
	message("Early target study / hold a visible destination; the free hand waits for real reach and contact.")

func _open_intent_arena(index:int,feet_on:bool=false) -> void:
	_set_input_profile(4)
	_set_physical_feet(feet_on)
	_set_experimental_launch(false)
	transfer_assist_enabled=false
	_set_posture_variant(0)
	_set_posture_policy(1)
	transfer_diagnostics_enabled=true
	transfer_diagnostics_toggle.set_pressed_no_signal(true)
	settings.hide()
	load_test(index)
	message("Choose a grip and hold its button. W/S asks to go up/down; A/D asks to cross. Physics decides what the supports can do.")

func _open_mantle_v08(index:int,adaptive:bool=true,palms:bool=true,wrist:bool=true)->void:
	physics_mantle_v08_enabled=true
	palm_compression_enabled=palms
	palm_wrist_support_enabled=wrist
	adaptive_leg_collision_enabled=adaptive
	mantle_support_handoff_enabled=true
	_open_intent_arena(index,true)
	_set_distant_targeting(true)

func _open_hybrid_mantle(scenario:int=0,use_vault_presentation:bool=false)->void:
	hybrid_mantle_v09_enabled=true
	contextual_vault_v10_enabled=use_vault_presentation
	physics_mantle_v08_enabled=false
	palm_compression_enabled=false
	palm_wrist_support_enabled=false
	adaptive_leg_collision_enabled=false
	mantle_support_handoff_enabled=false
	mantle_hanging_fixture_start=false
	_open_intent_arena(14+scenario,false)
	_set_distant_targeting(true)
	message("Grip near the top edge and hold W to climb up. Release the mouse buttons after you begin; walking resumes on top.")

func _on_transfer_event(event: Dictionary) -> void:
	var row: Dictionary=event.duplicate(true)
	row.session_id=transfer_session_id
	row.scene=level_id
	row.intent_climb_enabled=intent_climb_enabled and input_profile==4
	row.intent_locomotion=controller.telemetry().get("intent_locomotion",{})
	row.posture_policy=posture_policy
	row.posture_variant=posture_variant
	row.transfer_assist_enabled=transfer_assist_enabled
	row.transfer_posture=controller.telemetry().get("transfer_posture",{})
	row.reach_prediction_enabled=reach_prediction_enabled
	row.catch_buffer_enabled=catch_buffer_enabled
	row.catch_buffer_duration=catch_buffer_duration
	row.allow_out_of_reach_grip_targets=allow_out_of_reach_grip_targets
	row.out_of_reach_targeting_active=_distant_targeting_active()
	row.pending_targets=_pending_target_snapshots()
	var event_hand: int=int(event.get("hand",-1))
	row.attempt_assessment=attempt_assessments[event_hand].duplicate(true) if event_hand in [0,1] else {}
	row.route=transfer_progress.diagnostics() if level_id==4 else {}
	row.climbing_route=climbing_route.diagnostics() if level_id==10 else {}
	row.ledge_transfer=controller.telemetry().get("ledge_transfer",{})
	row.mantle_v08=mantle_v08.data if is_instance_valid(mantle_v08) else {}
	row.hybrid_mantle=hybrid_mantle.data if is_instance_valid(hybrid_mantle) else {}
	DirAccess.make_dir_recursive_absolute("user://transfer_sessions")
	var path: String="user://transfer_sessions/%s.jsonl" % transfer_session_id
	var file:=FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(JSON.stringify(row))

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
	row.transfer_session=transfer_session_id
	row.transfer_diagnostics_enabled=transfer_diagnostics_enabled
	row.transfer_route=transfer_progress.diagnostics() if level_id==4 else {}
	row.climbing_route=climbing_route.diagnostics() if level_id==10 else {}
	row.ledge_transfer=controller.telemetry().get("ledge_transfer",{})
	row.mantle_v08=mantle_v08.data if is_instance_valid(mantle_v08) else {}
	row.mantle_gate={"standing":mantle_standing,"completed":mantle_completed} if level_id==11 else {}
	row.hybrid_mantle=hybrid_mantle.data if is_instance_valid(hybrid_mantle) else {}
	row.intent_climb_enabled=intent_climb_enabled and input_profile==4
	row.intent_locomotion=controller.telemetry().get("intent_locomotion",{})
	row.posture_policy=posture_policy
	row.posture_variant=posture_variant
	row.transfer_assist_enabled=transfer_assist_enabled
	row.transfer_posture=controller.telemetry().get("transfer_posture",{})
	row.reach_prediction_enabled=reach_prediction_enabled
	row.catch_buffer_enabled=catch_buffer_enabled
	row.catch_buffer_duration=catch_buffer_duration
	row.allow_out_of_reach_grip_targets=allow_out_of_reach_grip_targets
	row.out_of_reach_targeting_active=_distant_targeting_active()
	row.pending_targets=_pending_target_snapshots()
	var summary_path: String="user://trials.jsonl"
	if input_profile in [3,4] and transfer_diagnostics_enabled:
		DirAccess.make_dir_recursive_absolute("user://transfer_sessions")
		summary_path="user://transfer_sessions/%s_summary.jsonl" % transfer_session_id
	var file := FileAccess.open(summary_path,FileAccess.READ_WRITE if FileAccess.file_exists(summary_path) else FileAccess.WRITE)
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
		"aim_input_does_not_change_length":input_profile in [3,4],
		"intent_climb_enabled":intent_climb_enabled and input_profile==4,"intent_locomotion":controller.telemetry().get("intent_locomotion",{}),
		"transfer_posture":contextual_data.get("transfer_posture",{}),"transfer_assist_enabled":transfer_assist_enabled,"posture_variant":posture_variant,"transfer_session":transfer_session_id,"transfer_diagnostics":controller.transfer_diagnostics(),"transfer_route":transfer_progress.diagnostics() if level_id==4 else {},
		"climbing_route":climbing_route.diagnostics() if level_id==10 else {},
		"ledge_transfer":contextual_data.get("ledge_transfer",{}),"mantle_gate":{"standing":mantle_standing,"completed":mantle_completed} if level_id==11 else {},
		"mantle_v08":mantle_v08.data if is_instance_valid(mantle_v08) else {},
		"hybrid_mantle":hybrid_mantle.data if is_instance_valid(hybrid_mantle) else {},
		"physical_foot_visual_error_m":biped.physical_foot_mismatch if is_instance_valid(mantle_v08) else [],
		"posture_policy":posture_policy if input_profile in [3,4] else -1,"posture":contextual_data.get("posture",{}),
		"contextual_filtered":[filtered.x,filtered.y],"contextual_actuation_m_s":[actuation.x,actuation.y],
		"camera_right":capture_trace.vector(camera.global_basis.x),"camera_forward":capture_trace.vector(Vector3.UP.cross(camera.global_basis.x).normalized()),
		"swing_requested":capture_trace.vector(controller.telemetry().get("swing_requested",Vector3.ZERO)),
		"swing_torque":capture_trace.vector(controller.telemetry().get("swing_torque",Vector3.ZERO)),
		"grip_buttons":[Input.is_action_pressed("grip_left"),Input.is_action_pressed("grip_right")],"capture_predictions":capture_predictions,
		"reach_prediction_enabled":reach_prediction_enabled,"catch_buffer_enabled":catch_buffer_enabled,"catch_buffer_duration":catch_buffer_duration,"reach_advice":reach_advice,"attempt_assessments":attempt_assessments,
		"allow_out_of_reach_grip_targets":allow_out_of_reach_grip_targets,"out_of_reach_targeting_active":_distant_targeting_active(),"pending_targets":_pending_target_snapshots(),
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
	_label("PHYSICS CLIMBING LAB  /  GRIP UP",15,branding,COLORS[0])
	for i in 4:
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
	profile_choice.add_item("3 / v0.4 Independent aim + physical posture (opt-in)")
	profile_choice.add_item("4 / v0.7 Intent-driven climb (opt-in)")
	profile_choice.select(input_profile)
	profile_choice.item_selected.connect(_set_input_profile)
	settings_box.add_child(profile_choice)
	_label("v0.5 transfer study / diagnostics before assistance",18,settings_box,COLORS[0])
	var route_row:=HBoxContainer.new()
	settings_box.add_child(route_row)
	var spacing_row:=HBoxContainer.new()
	settings_box.add_child(spacing_row)
	_label("Basic route spacing / m (applies on retry)",16,spacing_row)
	var spacing_spin:=SpinBox.new()
	spacing_spin.min_value=.08
	spacing_spin.max_value=.16
	spacing_spin.step=.01
	spacing_spin.value=transfer_route_spacing
	spacing_spin.value_changed.connect(func(value:float):transfer_route_spacing=value)
	spacing_row.add_child(spacing_spin)
	_button("05 / Ten transfers",func():_open_transfer_lab(4),route_row)
	_button("06 / Swing-required route",func():_open_transfer_lab(5),route_row)
	var distant_row:=HBoxContainer.new()
	settings_box.add_child(distant_row)
	_button("v0.6 / Early targets: swing",func():_open_distant_lab(5),distant_row)
	_button("v0.6 / Early targets: moving beam",func():_open_distant_lab(2),distant_row)
	_label("v0.7 / Choose grips, request body travel",18,settings_box,COLORS[0])
	var step_row:=HBoxContainer.new()
	settings_box.add_child(step_row)
	_button("The Step / hands only",func():_open_intent_arena(6,false),step_row)
	_button("The Step / physical feet ON",func():_open_intent_arena(6,true),step_row)
	_button("The Step / max reach + feet",func():_open_intent_arena(6,true);_set_distant_targeting(true),step_row)
	var intent_row:=HBoxContainer.new()
	settings_box.add_child(intent_row)
	_button("The Hang",func():_open_intent_arena(7,false),intent_row)
	_button("The Traverse",func():_open_intent_arena(8,false),intent_row)
	_button("The Corner",func():_open_intent_arena(9,false),intent_row)
	_button("PLAY / The first route",func():_open_intent_arena(10,true);_set_distant_targeting(true),settings_box)
	var ledge_row:=HBoxContainer.new()
	settings_box.add_child(ledge_row)
	_button("Ledge experiment / hands",func():_open_intent_arena(11,false);_set_distant_targeting(true),ledge_row)
	_button("Ledge experiment / hands + feet",func():_open_intent_arena(11,true);_set_distant_targeting(true),ledge_row)
	_label("v0.8 / Physical palms and leg clearance / H0",18,settings_box,COLORS[0])
	var hybrid_row:=HBoxContainer.new()
	settings_box.add_child(hybrid_row)
	_button("v0.9 / Mantle 1.25 m",func():_open_hybrid_mantle(0),hybrid_row)
	_button("v0.9 / Mantle 2.10 m",func():_open_hybrid_mantle(1),hybrid_row)
	_button("v0.9 / Two ledges",func():_open_hybrid_mantle(6),hybrid_row)
	var vault_row:=HBoxContainer.new()
	settings_box.add_child(vault_row)
	_button("v1.0 / Climb Up 1.25 m",func():_open_hybrid_mantle(0,true),vault_row)
	_button("v1.0 / Climb Up 2.10 m",func():_open_hybrid_mantle(1,true),vault_row)
	_button("v1.0 / Two ledges",func():_open_hybrid_mantle(6,true),vault_row)
	var hybrid_adverse:=HBoxContainer.new()
	settings_box.add_child(hybrid_adverse)
	_button("v0.9 / Narrow",func():_open_hybrid_mantle(2),hybrid_adverse)
	_button("v0.9 / Ceiling",func():_open_hybrid_mantle(3),hybrid_adverse)
	_button("v0.9 / Occupied",func():_open_hybrid_mantle(4),hybrid_adverse)
	_button("v0.9 / Moving",func():_open_hybrid_mantle(5),hybrid_adverse)
	var mantle_row:=HBoxContainer.new()
	settings_box.add_child(mantle_row)
	_button("v0.8 / Low ledge 1.25 m",func():_open_mantle_v08(12),mantle_row)
	_button("v0.8 / High ledge 2.10 m",func():_open_mantle_v08(13),mantle_row)
	var mantle_compare:=HBoxContainer.new()
	settings_box.add_child(mantle_compare)
	_button("v0.8 / Low, legs fixed",func():_open_mantle_v08(12,false,true),mantle_compare)
	_button("v0.8 / Low, palms OFF",func():_open_mantle_v08(12,true,false),mantle_compare)
	_button("v0.8 / Low, axial palms",func():_open_mantle_v08(12,true,true,false),mantle_compare)
	var intent_compare_row:=HBoxContainer.new()
	settings_box.add_child(intent_compare_row)
	_button("v0.7 / Beam",func():_open_intent_arena(2,false),intent_compare_row)
	_button("v0.7 / Ten transfers",func():_open_intent_arena(4,false),intent_compare_row)
	_button("Compare v0.6 / current arena",func():_set_input_profile(3);load_test(level_id);settings.hide(),settings_box)
	transfer_diagnostics_toggle=CheckButton.new()
	transfer_diagnostics_toggle.text="v0.5 diagnostics + per-attempt JSONL / no added strength"
	transfer_diagnostics_toggle.button_pressed=transfer_diagnostics_enabled
	transfer_diagnostics_toggle.toggled.connect(func(on:bool):transfer_diagnostics_enabled=on;_apply_independent_settings())
	settings_box.add_child(transfer_diagnostics_toggle)
	var transfer_assist_toggle:=CheckButton.new()
	transfer_assist_toggle.text="v0.5 limited trunk refinement / opt-in, same 20 Nm budget"
	transfer_assist_toggle.button_pressed=transfer_assist_enabled
	transfer_assist_toggle.toggled.connect(func(on:bool):transfer_assist_enabled=on;_apply_independent_settings())
	settings_box.add_child(transfer_assist_toggle)
	posture_variant_choice=OptionButton.new()
	posture_variant_choice.add_item("P0 / v0.4 suspension unchanged")
	posture_variant_choice.add_item("P1 / Support-relative axial twist refinement")
	posture_variant_choice.add_item("P2 / Tilt study (REJECT as default / opt-in)")
	posture_variant_choice.set_item_disabled(2,false)
	posture_variant_choice.select(posture_variant)
	posture_variant_choice.item_selected.connect(_set_posture_variant)
	settings_box.add_child(posture_variant_choice)
	_button("Rate current session / also after a failed attempt",func():settings.hide();rating_panel.show(),settings_box)
	_label("v0.4 posture comparison / same strength",18,settings_box,COLORS[0])
	posture_choice=OptionButton.new()
	posture_choice.add_item("A / Hold current length")
	posture_choice.add_item("B / Bounded supported auto-pull")
	posture_choice.add_item("C / Load-aware supported auto-pull")
	posture_choice.select(posture_policy)
	posture_choice.item_selected.connect(_set_posture_policy)
	settings_box.add_child(posture_choice)
	var posture_toggle := CheckButton.new()
	posture_toggle.text="Enable v0.4 bounded posture assistance"
	posture_toggle.button_pressed=posture_assist_enabled
	posture_toggle.toggled.connect(func(on:bool):posture_assist_enabled=on;_apply_independent_settings())
	settings_box.add_child(posture_toggle)
	var tilt_toggle := CheckButton.new()
	tilt_toggle.text="Enable v0.4 limited posture tilt assistance / 20 Nm budget"
	tilt_toggle.button_pressed=posture_tilt_assist_enabled
	tilt_toggle.toggled.connect(func(on:bool):posture_tilt_assist_enabled=on;_apply_independent_settings())
	settings_box.add_child(tilt_toggle)
	var swing_toggle := CheckButton.new()
	swing_toggle.text="Enable v0.4 supported WASD swing"
	swing_toggle.button_pressed=supported_wasd_swing_enabled
	swing_toggle.toggled.connect(func(on:bool):supported_wasd_swing_enabled=on;_apply_independent_settings())
	settings_box.add_child(swing_toggle)
	_label("v0.4 targets / 0.25 m/s, 1 m/s? | hands / 360 N total",16,settings_box,COLORS[0])
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
	_label("Profile 1 drag sensitivity / m per pixel",17,sensitivity_row)
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
	_label("Profile 2 virtual hand sensitivity / m per pixel",17,settings_box)
	aim_sensitivity.min_value=.0002
	aim_sensitivity.max_value=.006
	aim_sensitivity.step=.0002
	aim_sensitivity.value=contextual.sensitivity
	aim_sensitivity.value_changed.connect(func(value:float):contextual.sensitivity=value)
	settings_box.add_child(aim_sensitivity)
	var rate_row := HBoxContainer.new()
	settings_box.add_child(rate_row)
	_label("Profile 1 target maximum speed / m per second",17,rate_row)
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
	var advice_toggle:=CheckButton.new()
	advice_toggle.text="v0.5 reach advisory / estimates only, no automatic grip"
	advice_toggle.button_pressed=reach_prediction_enabled
	advice_toggle.toggled.connect(func(on:bool):reach_prediction_enabled=on;reach_advice=[{},{}];prediction_clock=0)
	settings_box.add_child(advice_toggle)
	var buffer_toggle:=CheckButton.new()
	buffer_toggle.text="v0.5 held catch buffer / independent aim only, opt-in"
	buffer_toggle.button_pressed=catch_buffer_enabled
	buffer_toggle.toggled.connect(_set_catch_buffer)
	settings_box.add_child(buffer_toggle)
	distant_target_toggle=CheckButton.new()
	distant_target_toggle.text="v0.6 select distant targets / hold until real contact (opt-in)"
	distant_target_toggle.button_pressed=allow_out_of_reach_grip_targets
	distant_target_toggle.toggled.connect(_set_distant_targeting)
	settings_box.add_child(distant_target_toggle)
	var pending_feedback_toggle:=CheckButton.new()
	pending_feedback_toggle.text="v0.6 show selected pending target outlines"
	pending_feedback_toggle.button_pressed=pending_grip_feedback_enabled
	pending_feedback_toggle.toggled.connect(func(on:bool):pending_grip_feedback_enabled=on)
	settings_box.add_child(pending_feedback_toggle)
	var buffer_row:=HBoxContainer.new()
	settings_box.add_child(buffer_row)
	_label("Held intent duration / seconds",17,buffer_row)
	var buffer_duration:=SpinBox.new()
	buffer_duration.min_value=.10
	buffer_duration.max_value=.15
	buffer_duration.step=.01
	buffer_duration.value=catch_buffer_duration
	buffer_duration.value_changed.connect(func(value:float):catch_buffer_duration=clampf(value,.10,.15);_apply_capture_settings())
	buffer_row.add_child(buffer_duration)
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
	for metric in ["precision","comfort","weight","fairness","retry","agency","recovery","readability","control","physical_credibility","clarity","skill_expression","would_play_another_level"]:
		var key: String = metric
		var line := HBoxContainer.new()
		rating_box.add_child(line)
		var metric_label := _label(key,17,line)
		metric_label.custom_minimum_size.x = 120
		for value in range(1,6):
			var score := value
			_button(str(score),func():trial.ratings[key]=score,line)
	_button("Save ratings & continue",func():_save_trial("rated");rating_panel.hide(),rating_box)
	var experience:=LineEdit.new()
	experience.placeholder_text="What did you feel you were controlling?"
	experience.text_changed.connect(func(value:String):trial["felt_in_control_of"]=value)
	rating_box.add_child(experience)
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
	if input_profile==4:
		return "Mouse / Choose grips    Hold LMB / RMB / Grip    W/S / Up-down    A/D / Traverse    MMB / Orbit    Esc / Controls"
	if input_profile==3:
		return "Mouse / Aim only    Hold LMB / RMB / Grip    WASD / Supported swing or walk    MMB / Orbit    Wheel / Dolly    Esc / Controls"
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
	input_profile = clampi(profile,0,4)
	intent_climb_enabled = input_profile==4
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
		_apply_independent_settings()
	if not trial.is_empty():
		trial.control_profile = input_profile
	controls_label.text = _controls_hint()
	_update_objective()
	_refresh_pointer_capture()
	message(["Baseline / W pulls, S lowers, A/D biases, Space charges a launch.","Hold to grip. Drag up to pull, down to lower. WASD swings through your grips.","Contextual arms / relative mouse aims and requests supported effort.","Independent aim / mouse selects contacts only. Hold LMB / RMB; WASD swings.","Intent-driven / Choose grips. W/S up/down; A/D traverse through real supports."][input_profile])
	if input_profile==2:message("Relative mouse aims free hands and requests supported effort. Hold LMB / RMB. Escape / Controls.")
	if input_profile==3:message("v0.4 / Mouse aims only. Acquire supports to test bounded posture. WASD / supported swing. Space comparison is OFF by default.")
	if input_profile==4:message("Choose your grips. W/S requests up/down; A/D requests traverse. Aiming never pulls the body.")

func _update_objective() -> void:
	objective_label.text = level.objective
	if input_profile==1:
		if level_id==1:
			objective_label.text = "Hold your grip and drag up to pull. WASD swings in 3D.\nBuild momentum, release and catch the next reachable surface."
		elif level_id==3:
			objective_label.text = "Hold the two targets and drag to change arm length.\nFoot contacts are optional; baseline profile 0 retains the W-driven feet comparison."
	elif input_profile==2:
		objective_label.text="Move the L / R virtual aims onto reachable surfaces. Hold that hand's button.\nMouse down / pull; up / extend through supported effort. WASD swings."
	elif input_profile in [3,4]:
		objective_label.text="Aim at any reachable surface. Hold LMB / RMB, then choose the next contact.\nAiming never commands arm length; compare posture policies A / B / C in Controls."
	if input_profile in [3,4] and level_id==4:
		objective_label.text="Start with left hand on guide 00, then right on 01; alternate up to 10.\nWait for a reachable shoulder position. Tab shows reach; all wall surfaces remain grippable."
	elif input_profile in [3,4] and level_id==5:
		objective_label.text="The far contact is outside static reach. Use supported A/D or W/S swing.\nTime the catch and release deliberately; Tab separates reach, transit and grip load."
	if _distant_targeting_active():
		objective_label.text="Hold LMB / RMB on a visible destination, even beyond reach.\nMove or swing into real contact; mouse-up cancels. The selected point stays fixed on its surface."
	if input_profile==4:
		objective_label.text=level.objective if level_id>=6 else "Choose and hold real contacts. W/S requests up/down; A/D requests traverse.\nMovement needs support; pointing at a new grip never pulls you toward it."

func _apply_independent_settings() -> void:
	if not is_instance_valid(controller):return
	controller.intent_climb_enabled=intent_climb_enabled and input_profile==4
	if is_instance_valid(ground_motor):ground_motor.process_physics_priority=-10 if input_profile==4 else 0
	controller.independent_aim_enabled=input_profile in [3,4]
	controller.transfer_diagnostics_enabled=transfer_diagnostics_enabled and input_profile in [3,4]
	controller.transfer_assist_enabled=transfer_assist_enabled and input_profile in [3,4]
	controller.set_posture_variant(posture_variant)
	controller.posture_assist_enabled=posture_assist_enabled
	controller.posture_tilt_assist_enabled=posture_tilt_assist_enabled
	controller.supported_wasd_swing_enabled=supported_wasd_swing_enabled
	controller.set_posture_policy(posture_policy)
	_apply_capture_settings()
	_apply_pending_settings()

func _distant_targeting_active() -> bool:
	return input_profile in [3,4] and allow_out_of_reach_grip_targets

func _pending_target_snapshots() -> Array:
	return [controller.pending_diagnostics(0),controller.pending_diagnostics(1)]

func _release_hand_input(hand:int,reason:String="input_released") -> void:
	if controller.pending_diagnostics(hand).get("active",false):controller.set_hand_held(hand,false,reason)
	else:controller.release_grip(hand,"manual" if reason=="input_released" else reason)

func _set_distant_targeting(on:bool) -> void:
	allow_out_of_reach_grip_targets=on
	if is_instance_valid(distant_target_toggle):distant_target_toggle.set_pressed_no_signal(on)
	if on and is_instance_valid(controller):grip_intents.clear(controller)
	_apply_pending_settings()
	if is_instance_valid(level):_update_objective()

func _apply_pending_settings() -> void:
	if not is_instance_valid(controller):return
	if not _distant_targeting_active():
		for hand in 2:
			if controller.get_hand_state(hand)=="REACHING" and controller.pending_diagnostics(hand).get("active",false):controller.set_hand_held(hand,false,"feature_disabled")
	controller.tuning.allow_out_of_reach_grip_targets=_distant_targeting_active()

func _set_posture_variant(variant: int) -> void:
	posture_variant=clampi(variant,0,2)
	if is_instance_valid(posture_variant_choice):posture_variant_choice.select(posture_variant)
	_apply_independent_settings()

func _set_posture_policy(policy: int) -> void:
	posture_policy=clampi(policy,0,2)
	if is_instance_valid(posture_choice):posture_choice.select(posture_policy)
	_apply_independent_settings()

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
	_apply_capture_settings()

func _capture_buffer_active() -> bool:
	return predictive_grip_enabled or (input_profile in [3,4] and catch_buffer_enabled)

func _set_catch_buffer(on: bool) -> void:
	catch_buffer_enabled=on
	_apply_capture_settings()

func _apply_capture_settings() -> void:
	if is_instance_valid(controller):
		controller.tuning.predictive_grip = _capture_buffer_active()
		controller.tuning.capture_intent_buffer_duration=catch_buffer_duration if input_profile in [3,4] and catch_buffer_enabled else .15
		if not _capture_buffer_active():
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
