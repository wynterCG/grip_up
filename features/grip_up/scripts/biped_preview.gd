extends Node3D

const Model = preload("res://features/grip_up/assets/characters/quaternius_mannequin/mannequin.glb")
var character: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var camera: Camera3D
var yaw := 0.3
var distance := 4.1
var orbiting := false
var selection: OptionButton

func _ready() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101c25")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c9e0e8")
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-25,0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	add_child(light)
	character = Model.instantiate()
	add_child(character)
	skeleton = character.find_children("*","Skeleton3D",true,false)[0]
	player = character.find_children("*","AnimationPlayer",true,false)[0]
	var floor_mesh := MeshInstance3D.new()
	var plane := CylinderMesh.new()
	plane.top_radius = 1.45
	plane.bottom_radius = 1.45
	plane.height = 0.08
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.045
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("29444d")
	floor_mesh.material_override = material
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 45
	camera.near = 0.05
	add_child(camera)
	camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(40,35)
	panel.add_theme_constant_override("separation",12)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "GRIP UP / BIPED CANDIDATE"
	title.add_theme_font_size_override("font_size",30)
	panel.add_child(title)
	var description := Label.new()
	description.text = "Quaternius mannequin  /  CC0\n65 bones  /  arms, hands, fingers, legs and feet\nMiddle mouse: orbit   |   Wheel: zoom"
	description.add_theme_font_size_override("font_size",19)
	panel.add_child(description)
	selection = OptionButton.new()
	selection.custom_minimum_size = Vector2(320,48)
	panel.add_child(selection)
	for animation in player.get_animation_list():
		if animation != "RESET":
			selection.add_item(animation)
	selection.item_selected.connect(func(index:int):play_pose(selection.get_item_text(index)))
	for i in selection.item_count:
		if selection.get_item_text(i)==animation_name("Idle_Loop"):
			selection.select(i)
	play_pose("Idle_Loop")
	_update_camera()

func play_pose(clip: String) -> void:
	player.play(animation_name(clip))
	player.advance(0.0)

func animation_name(clip: String) -> String:
	# Godot marks _Loop clips as looping and removes that suffix on import.
	return clip if player.has_animation(clip) else clip.trim_suffix("_Loop")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			orbiting = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			distance = clampf(distance+(-0.35 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.35),2.2,7.5)
	if event is InputEventMouseMotion and orbiting:
		yaw -= event.relative.x*0.006
	_update_camera()

func _update_camera() -> void:
	camera.position = Vector3(sin(yaw)*distance,1.25,cos(yaw)*distance)
	camera.look_at(Vector3(0,0.95,0),Vector3.UP)
