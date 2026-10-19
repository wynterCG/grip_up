extends Node3D
## Visible C0/C1 isolation only. Gravity-zero12kg dynamic fixture; no climb,
## support force, body movement command or functional mantle is demonstrated.
const Adaptive=preload("res://features/grip_up/scripts/adaptive_leg_collision.gd")
const Tuning=preload("res://features/grip_up/resources/biped_tuning.gd")
const Controller=preload("res://features/grip_up/scripts/climbing_controller.gd")
const Visual=preload("res://features/grip_up/scripts/biped_visual.gd")
const Overlay=preload("res://features/grip_up/scripts/mantle_collision_overlay.gd")
var body:RigidBody3D
var leg:CollisionShape3D
var sole:CollisionShape3D
var controller:Node
var visual:Node3D
var legs=Adaptive.new()
var blocker:StaticBody3D
var blocker_mode:="NONE"
var placement_reason:=""
var enabled:=true
var desired:=0.0
var keyboard_controlled:=false
var loaded_force_n:=0.0
var data:Dictionary={}
var samples:Array=[]
var elapsed:=0.0
var peak_impulse_ns:=0.0
var label:Label
var camera:Camera3D
var start_pose:Transform3D

func _ready()->void:
	process_physics_priority=-20
	var tuning:=Tuning.new()
	body=RigidBody3D.new()
	body.name="Dynamic12kgGravityZeroIsolation"
	body.mass=tuning.body_mass
	body.gravity_scale=0
	body.can_sleep=false
	body.continuous_cd=true
	body.contact_monitor=true
	body.max_contacts_reported=16
	body.collision_layer=4
	body.collision_mask=3
	body.center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass=Vector3.ZERO
	for index in 2:
		var collision:=CollisionShape3D.new()
		collision.name="Torso" if index==0 else "LowerCapsule"
		var capsule:=CapsuleShape3D.new()
		capsule.radius=tuning.torso_capsule_radius if index==0 else tuning.leg_capsule_radius
		capsule.height=tuning.torso_capsule_height if index==0 else tuning.leg_capsule_height
		collision.position.y=tuning.torso_capsule_center_y if index==0 else tuning.leg_capsule_center_y
		collision.shape=capsule
		body.add_child(collision)
		if index==1:leg=collision
	var head:=CollisionShape3D.new()
	head.name="Head"
	var sphere:=SphereShape3D.new()
	sphere.radius=tuning.head_radius
	head.shape=sphere
	head.position.y=tuning.head_center_y
	body.add_child(head)
	sole=CollisionShape3D.new()
	sole.name="Sole"
	var foot:=BoxShape3D.new()
	foot.size=tuning.foot_base_size
	sole.shape=foot
	sole.position=tuning.foot_base_offset
	body.add_child(sole)
	add_child(body)
	start_pose=body.global_transform
	legs.configure(body,leg,sole,tuning)
	body.set_meta("adaptive_legs",legs)
	controller=Controller.new()
	add_child(controller)
	controller.configure(body,tuning)
	controller.set_physics_process(false)
	visual=Visual.new()
	visual.name="VisibleIKBiped"
	add_child(visual)
	visual.configure(body,controller)
	var overlay:=Overlay.new()
	overlay.body=body
	add_child(overlay)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-35,0)
	sun.light_energy=1.5
	add_child(sun)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("15212c")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("b8c7dc")
	environment.environment.ambient_light_energy=.6
	add_child(environment)
	camera=Camera3D.new()
	camera.position=Vector3(2.1,.9,2.4)
	add_child(camera)
	camera.look_at(Vector3(0,-.03,0))
	camera.current=true
	_build_ui()

func _build_ui()->void:
	var canvas:=CanvasLayer.new()
	add_child(canvas)
	var panel:=PanelContainer.new()
	panel.position=Vector2(18,18)
	canvas.add_child(panel)
	var column:=VBoxContainer.new()
	panel.add_child(column)
	label=Label.new()
	label.add_theme_font_size_override("font_size",20)
	column.add_child(label)
	var row:=HBoxContainer.new()
	column.add_child(row)
	for mode in ["NONE","LIP","EXPANSION"]:
		var button:=Button.new()
		button.text="Clear" if mode=="NONE" else "Thin lip" if mode=="LIP" else "Expansion blocker"
		button.pressed.connect(func():set_blocker(mode))
		row.add_child(button)
	var load_button:=CheckButton.new()
	load_button.text="Simulate declared foot load25N (guard only; no force)"
	load_button.toggled.connect(func(value):loaded_force_n=25.0 if value else 0.0)
	column.add_child(load_button)
	var enabled_button:=CheckButton.new()
	enabled_button.text="Enable C1; OFF safely requests original standing collider"
	enabled_button.button_pressed=true
	enabled_button.toggled.connect(func(value):enabled=value)
	column.add_child(enabled_button)

func request_flex(value:float)->void:
	desired=clampf(value,0,1)
	keyboard_controlled=false

func set_blocker(mode:String)->bool:
	if mode not in ["NONE","LIP","EXPANSION"]:return false
	if mode=="NONE":
		if is_instance_valid(blocker):blocker.queue_free()
		blocker=null
		blocker_mode=mode
		placement_reason=""
		return true
	var size:=Vector3(.12,.012,.012) if mode=="LIP" else Vector3(.6,.10,.50)
	var point:=Vector3(0,-.505,-.30) if mode=="LIP" else Vector3(0,-.78,-.035)
	var shape:=BoxShape3D.new()
	shape.size=size
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform=Transform3D(Basis.IDENTITY,point)
	query.collision_mask=4
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		placement_reason="Blocker placement denied: would overlap current body. Fold first."
		return false
	if is_instance_valid(blocker):blocker.queue_free()
	blocker=StaticBody3D.new()
	blocker.name="RealCollisionBlocker"
	blocker.position=point
	blocker.collision_layer=1
	blocker.collision_mask=4
	var collision:=CollisionShape3D.new()
	collision.shape=shape
	blocker.add_child(collision)
	var mesh:=MeshInstance3D.new()
	var box:=BoxMesh.new()
	box.size=size
	mesh.mesh=box
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("ee8b37")
	mesh.material_override=material
	blocker.add_child(mesh)
	add_child(blocker)
	blocker_mode=mode
	placement_reason=""
	return true

func _physics_process(delta:float)->void:
	if not is_instance_valid(body):return
	if Input.is_physical_key_pressed(KEY_W):
		desired=1.0
		keyboard_controlled=true
	elif Input.is_physical_key_pressed(KEY_S):
		desired=0.0
		keyboard_controlled=true
	elif keyboard_controlled:
		desired=legs.achieved_flex
		keyboard_controlled=false
	legs.request_flex(desired)
	var state:Dictionary=legs.step(delta,enabled,loaded_force_n)
	var clearance:Dictionary=legs.clearance_diagnostics()
	elapsed+=delta
	peak_impulse_ns=maxf(peak_impulse_ns,state.contacts.get("peak_impulse_ns",0.0))
	data={"isolation":"12kg dynamic body; gravityZERO; controller forcesOFF; NOT mantle or load-bearing proof","physics_hz":Engine.physics_ticks_per_second,"elapsed":elapsed,"requested_flex":desired,"actual_flex":legs.achieved_flex,"reason":legs.reason,"enabled":enabled,"blocker":blocker_mode,"placement_reason":placement_reason,"loaded_guard_n":loaded_force_n,"leg_collision":state,"clearance":clearance,"peak_impulse_ns":peak_impulse_ns,"body_translation":body.global_position-start_pose.origin,"body_speed":body.linear_velocity.length(),"anatomy":"Hip75deg knee150deg; unchanged0.15m capsule radius/full sole"}
	if samples.is_empty() or elapsed-float(samples[-1].time)>=.1:samples.append({"time":elapsed,"flex":legs.achieved_flex,"reason":legs.reason,"clearance":clearance,"body":body.global_transform,"impulse_ns":state.contacts.get("peak_impulse_ns",0.0)})
	if is_instance_valid(label):
		label.text="M2 / COLLIDER CLEARANCE ISOLATION\n12kg dynamic body | gravityZERO | forcesOFF | not a mantle\nHold W / fold, S / unfold. Mouse selects blockers.\nFlex %.3f / %.3f | %s\nBlocker %s | penetration estimate %.3fmm\nNative peak impulse %.4fNs | body speed %.5fm/s\n%s"%[legs.achieved_flex,desired,legs.reason,blocker_mode,clearance.max_penetration_estimate_m*1000,peak_impulse_ns,body.linear_velocity.length(),placement_reason]
