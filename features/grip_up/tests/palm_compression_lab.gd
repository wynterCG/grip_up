extends Node3D
## Independent M1 fixture. Setup pose is assigned before adding the body only.
const Profile=preload("res://features/grip_up/resources/biped_tuning.gd")
const Controller=preload("res://features/grip_up/scripts/climbing_controller.gd")
var body:RigidBody3D
var controller:Node
var support:PhysicsBody3D
var points:Array[Vector3]=[]
var definition:Dictionary={}
var press:=0.0

func _ready()->void:
	body=RigidBody3D.new()
	body.position=Vector3(0,2.70,.55)
	# Mechanically favorable isolated posture, initialized before simulation.
	# A handstand fixture puts the existing shoulders below COM so an axial
	# vertical press lifts the body instead of spending its work tipping it.
	# This is NOT a demonstrated hanging/ordinary mantle starting posture.
	var balance_shoulder:=Vector3(0,.5241,.0153) if definition.get("two",false) else Vector3(-.1919,.5241,.0153)
	body.quaternion=Quaternion(balance_shoulder.normalized(),Vector3.DOWN)
	body.mass=12
	body.gravity_scale=0
	body.center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass=Vector3.ZERO
	body.linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp=0
	body.angular_damp=0
	body.collision_layer=4
	body.collision_mask=3
	var shape:=CapsuleShape3D.new()
	shape.height=1.7
	shape.radius=.15
	var collider:=CollisionShape3D.new()
	collider.shape=shape
	body.add_child(collider)
	add_child(body)
	var settings:=Profile.new()
	settings.allow_out_of_reach_grip_targets=true
	controller=Controller.new()
	add_child(controller)
	controller.configure(body,settings)
	controller.set_control_profile(4)
	controller.intent_climb_enabled=true
	controller.physics_mantle_v08_enabled=definition.get("master",true)
	controller.palm_compression_enabled=definition.get("enabled",true)
	var left_shoulder:Vector3=controller.get_shoulder_world(0)
	var right_shoulder:Vector3=controller.get_shoulder_world(1)
	var top:float=left_shoulder.y-.42
	support=RigidBody3D.new() if definition.get("moving",false) else StaticBody3D.new()
	support.position=Vector3(0,top-.1,0)
	support.collision_layer=2
	support.collision_mask=7
	support.set_meta("grippable",true)
	support.set_meta("grip_load_limit",10000.0)
	support.set_meta("palm_load_limit",definition.get("capacity",10000.0))
	var material:=PhysicsMaterial.new()
	material.friction=definition.get("friction",.85)
	support.physics_material_override=material
	if support is RigidBody3D:
		support.mass=30
		support.gravity_scale=0
		support.linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
		support.angular_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
		support.linear_damp=0
		support.angular_damp=0
		support.center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		support.center_of_mass=Vector3.ZERO
	var box:=BoxShape3D.new()
	box.size=Vector3(2,.20,1.50)
	var solid:=CollisionShape3D.new()
	solid.shape=box
	support.add_child(solid)
	add_child(support)
	points=[Vector3(left_shoulder.x,top,left_shoulder.z),Vector3(right_shoulder.x,top,right_shoulder.z)]
	points[0].z+=float(definition.get("offset_z",0.0))
	if definition.get("corner",false):points[0].z=.74
	if definition.get("air",false):points[0].y+=.03

func request(id:int)->bool:
	return controller.request_held_grip(id,support,points[id],Vector3.UP)

func _physics_process(_delta:float)->void:
	controller.set_traversal_input(Vector2(0,press),Vector3.RIGHT)
