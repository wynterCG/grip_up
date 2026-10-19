extends "res://features/grip_up/scripts/climbing_route_level.gd"
## Continuous greybox extension. Broad paint guides; all surfaces remain free.
var scenario:="FIRST_ASCENT"
var top_y:=3.25
var platform:StaticBody3D

func _ready()->void:
	super._ready()
	title="THE FIRST ASCENT"
	objective="Climb the wall, cross the bars and reach the upper deck.\nKeep a real hand held; choose your own contacts. W climbs up at the final edge."
	route_zones[2].hint="SWING & REACH / Keep one real hand on the bars. A/D builds lateral motion; reach across to the broad final wall."
	for child in get_children():
		if not child is Label3D:continue
		if child.text.begins_with("1 /") or child.text.begins_with("2 /") or child.text.begins_with("3 /"):
			child.pixel_size=.0045
		if child.text=="3 / HANG":child.position=Vector3(1.70,3.40,.35)
	# Native-ground entry removes the old ray-floor margin. Give the teaching
	# transfer real arm slack instead of requiring a near-limit timed catch.
	var first_bar:PhysicsBody3D=holds[1]
	first_bar.position=Vector3(1.10,2.56,.08)
	var bar_size:=Vector3(.85,.12,.24)
	(first_bar.get_child(0) as CollisionShape3D).shape.size=bar_size
	(first_bar.get_child(1) as MeshInstance3D).mesh.size=bar_size
	transfer_points[5]=Vector3(.60,2.60,0)
	transfer_points[6]=Vector3(.90,2.53,.20)
	transfer_points[7]=Vector3(1.25,2.55,.20)
	transfer_points[8]=Vector3(1.15,2.53,.20)
	# Coplanar teaching surfaces avoid a hidden backwards step for the hand.
	holds[2].position=Vector3(1.75,2.55,.08)
	transfer_points[9]=Vector3(1.75,2.53,.20)
	route_zones[2].bounds=AABB(Vector3(1.40,2.42,-.10),Vector3(.55,.40,.45))
	route_zones[2].min_body_y=1.50
	platform=box("Upper deck",Vector3(3.15,1.425,-1.20),Vector3(2.4,3.65,2.8),steel)
	holds.append(platform)
	# Representative QA selections only; gameplay has no sockets or exact targets.
	transfer_points.append_array([Vector3(1.80,2.53,.20),Vector3(2.03,2.65,.20),Vector3(2.30,2.85,.20),Vector3(2.60,3.20,.20)])
	finish_point=Vector3(2.75,top_y,-1.2)
	paint(Vector3(2.72,2.99,.209),Vector2(1.02,.48),cyan)
	label3("4 / CLIMB UP",Vector3(2.8,3.90,.32),cyan,22).pixel_size=.0045
	label3("FINISH",Vector3(3.30,top_y+.12,-1.80),gold,20)
