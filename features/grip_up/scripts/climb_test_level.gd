extends Node3D

@export_range(0,3) var test_id := 0
var spawn := Vector3(0, 1.17, 0.40)
var holds: Array[PhysicsBody3D] = []
var checkpoint := Vector3(-0.17, 1.81, 0.30)
var checkpoint_enabled := false
var beam: RigidBody3D
var fixed_beam := false
var footholds: Array[PhysicsBody3D] = []
var finish_point := Vector3.ZERO
var title := ""
var objective := ""
var gold := Color("e6ae58")
var cyan := Color("65dfcc")
var steel := Color("314955")

func _ready() -> void:
	if test_id == 0:
		_static_climb()
	elif test_id == 1:
		_swing()
	elif test_id == 2:
		_reactive()
	else:
		_foot_support()

func _foot_support() -> void:
	title = "04 / FOOT SUPPORT"
	objective = "Hold the two fixed targets. W pushes through planted feet.\nControls / Automatic foot contacts compares the same footholds ON / OFF."
	box("Wall",Vector3(0,2.1,-0.20),Vector3(4,5,0.4),steel)
	box("Start",Vector3(0,0.1,1.0),Vector3(6,0.3,5),Color("526a72"))
	wall_hold(Vector3(-0.24,2.10,0.10),"L",cyan)
	wall_hold(Vector3(0.24,2.10,0.10),"R",gold)
	for side in [-1.0,1.0]:
		var foot := box("Left foothold" if side<0 else "Right foothold",Vector3(side*0.31,0.51,0.12),Vector3(0.20,0.16,0.40),Color("8bb88c"))
		footholds.append(foot)
	label3("FEET PUSH / HANDS HOLD",Vector3(0,2.7,0.40),Color("8bb88c"),28)
	label3("W / EXTEND LEGS    S / LOWER",Vector3(0,0.18,0.65),Color("8bb88c"),19)
	finish_point = Vector3(0,2.1,0.10)

func material(color: Color, metal := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.58
	return mat

func box(label: String, at: Vector3, size: Vector3, color: Color, grippable := true, dynamic := false) -> PhysicsBody3D:
	var body: PhysicsBody3D
	if dynamic:
		body = RigidBody3D.new()
	else:
		body = StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = 2 if grippable else 1
	body.collision_mask = 7
	body.set_meta("grippable", grippable)
	body.set_meta("grip_load_limit", 460.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.material_override = material(color, 0.45 if dynamic else 0.1)
	body.add_child(mesh)
	if dynamic:
		body.mass = 18.0
		body.continuous_cd = true
		body.linear_damp = 0.1
		body.angular_damp = 0.35
	add_child(body)
	return body

func label3(text: String, at: Vector3, color := Color("c9ddd9"), size := 40) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = size
	label.pixel_size = 0.006
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	add_child(label)
	return label

func hold(at: Vector3, text: String, color: Color) -> PhysicsBody3D:
	var body := box("Hold_" + text, at, Vector3(0.30,0.10,0.18), color, true)
	holds.append(body)
	var label := label3(text, at + Vector3(0,0.28,0.32), color, 34)
	label.name = "HoldLabel" + text
	return body

func wall_hold(at: Vector3, text: String, color: Color) -> PhysicsBody3D:
	var body := StaticBody3D.new()
	body.name = "Hold_" + text
	body.position = at
	body.collision_layer = 2
	body.collision_mask = 7
	body.set_meta("grippable",true)
	body.set_meta("wall_hold",true)
	body.set_meta("grip_load_limit",460.0)
	var rock := SphereMesh.new()
	rock.radius = 0.09
	rock.height = 0.12
	rock.radial_segments = 16
	rock.rings = 8
	var visual := MeshInstance3D.new()
	visual.mesh = rock
	visual.scale.z = 0.55
	visual.material_override = material(color)
	body.add_child(visual)
	# Bake the shallow rounded profile into the collider, matching the visible
	# hold without scaling a physics shape or leaving a box shelf underneath.
	var points := PackedVector3Array()
	for vertex in rock.get_mesh_arrays()[Mesh.ARRAY_VERTEX]:
		points.append(vertex * Vector3(1,1,0.55))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	holds.append(body)
	var label := label3(text,at + Vector3(0,0.23,0.12),color,30)
	label.name = "HoldLabel" + text
	return body

func _static_climb() -> void:
	title = "01 / STATIC CLIMB"
	objective = "Grip anywhere on the wall and choose your route.\nKeep one hand attached while moving the other; reach finish height."
	box("Wall", Vector3(0,2.2,-0.20), Vector3(4.0,5.5,0.4), steel)
	box("Start", Vector3(0,0.1,1.0), Vector3(6,0.3,5.0), Color("526a72"))
	for i in 6:
		var x := -0.34 if i % 2 == 0 else 0.34
		wall_hold(Vector3(x,2.15 + i*0.22,0.10), "%02d" % (i+1), cyan if i%2==0 else gold)
	# Checkpoint landing is created only on retry, clear of the initial ascent.
	label3("CHECKPOINT",Vector3(-1.2,2.5,0.1),cyan,23)
	box("Destination", Vector3(1.3,2.65,-0.2), Vector3(0.8,0.2,1.0), Color("527e72"))
	finish_point = holds[-1].position
	label3("FINISH HEIGHT", finish_point + Vector3(0,0.55,0.1), cyan, 32)

func _swing() -> void:
	title = "02 / SWING & CATCH"
	objective = "A / D swings left / right relative to the camera. Pull with W + D.\nCatch the underside of 02, then release 01 and keep W."
	spawn = Vector3(-0.55,1.17,0.40)
	box("Start",Vector3(-0.8,0.1,0.55),Vector3(1.0,0.3,2.0),Color("526a72"))
	box("Overhead frame",Vector3(0,3.1,-0.3),Vector3(3.5,0.14,0.2),steel)
	box("Left frame",Vector3(-1.55,1.45,-0.3),Vector3(0.14,3.3,0.25),steel)
	hold(Vector3(-0.55,2.2,0.15),"01",cyan)
	hold(Vector3(0.45,2.2,0.15),"02",gold)
	box("Destination",Vector3(1.25,0.1,0.5),Vector3(1.0,0.3,2.0),Color("527e72"))
	finish_point = holds[-1].position
	label3("CATCH 02",Vector3(0.45,2.65,0.15),gold,32)
	label3("GAP",Vector3(0.2,-0.2,0.55),Color("607783"),28)

func _reactive() -> void:
	title = "03 / REACTIVE STRUCTURE"
	objective = "Grip the beam and shift your load along it.\nRotate the tip downward, then catch EXIT. F compares fixed / hinged."
	spawn = Vector3(-0.15,1.17,0.40)
	box("Start",Vector3(-0.4,0.1,0.55),Vector3(1.0,0.3,2.0),Color("526a72"))
	var frame := box("Frame",Vector3(-1.15,1.2,-0.3),Vector3(0.2,2.8,0.4),steel)
	box("Frame top",Vector3(-0.95,2.5,-0.3),Vector3(0.65,0.2,0.5),steel)
	beam = box("Hinged_Beam",Vector3(0.1,2.05,0),Vector3(1.8,0.16,0.26),gold,true,true)
	beam.mass = 15.0
	beam.freeze = fixed_beam
	holds.append(beam)
	var hinge := HingeJoint3D.new()
	hinge.name = "BeamHinge"
	hinge.position = Vector3(-0.8,2.05,0)
	add_child(hinge)
	hinge.node_a = hinge.get_path_to(frame)
	hinge.node_b = hinge.get_path_to(beam)
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -0.6)
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, 0.2)
	# Counteracts the unloaded beam's own moment only; added player load rotates it.
	beam.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	beam.center_of_mass = Vector3(-0.9,0,0)
	var ballast := MeshInstance3D.new()
	var ballast_mesh := BoxMesh.new()
	ballast_mesh.size = Vector3(0.3,0.32,0.4)
	ballast.mesh = ballast_mesh
	ballast.material_override = material(steel,0.5)
	ballast.position = Vector3(-0.9,-0.05,0)
	beam.add_child(ballast)
	var ballast_collision := CollisionShape3D.new()
	var ballast_shape := BoxShape3D.new()
	ballast_shape.size = ballast_mesh.size
	ballast_collision.shape = ballast_shape
	ballast_collision.position = ballast.position
	beam.add_child(ballast_collision)
	box("Exit",Vector3(1.5,-0.15,0.55),Vector3(0.8,0.3,2.0),Color("527e72"))
	hold(Vector3(1.15,1.8,0.15),"EXIT",cyan)
	finish_point = holds[-1].position
	label3("HINGE",Vector3(-0.8,2.4,0),gold,24)
	label3("FINISH",Vector3(1.15,2.3,0),cyan,32)
	var pivot_visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	pivot_visual.mesh = sphere
	pivot_visual.material_override = material(cyan)
	pivot_visual.position = Vector3(-0.8,2.05,0.22)
	add_child(pivot_visual)
