extends "res://features/grip_up/scripts/climb_test_level.gd"
## Short authored M5 course. Painted regions guide; every solid face is grippable.
var transfer_points:Array[Vector3]=[]
var route_zones:Array[Dictionary]=[]

func _ready() -> void:
	title="THE FIRST ROUTE"
	objective="Climb the wall, cross right, then transfer along the hanging bars.\nHold each hand to grip. The coloured areas are broad goals, not exact handholds."
	spawn=Vector3(0,1.17,.40)
	var wall:=box("Route wall",Vector3(.25,2.05,-.2),Vector3(2,3.6,.4),steel)
	holds.append(wall)
	box("Safe base",Vector3(.65,.1,.75),Vector3(4.8,.3,3.6),Color("526a72"),false)
	footholds.append(box("Lower lip",Vector3(0,.51,0),Vector3(.95,.16,.22),Color("8bb88c")))
	footholds.append(box("Traverse lip",Vector3(.62,.73,0),Vector3(.60,.16,.22),Color("8bb88c")))
	var first:=box("First hanging bar",Vector3(1.20,2.66,.08),Vector3(.65,.12,.24),gold)
	var last:=box("Finish hanging bar",Vector3(1.75,2.70,-.04),Vector3(.45,.12,.24),cyan)
	holds.append(first)
	holds.append(last)
	transfer_points=[Vector3(-.24,2.10,0),Vector3(.24,2.10,0),Vector3(-.24,2.43,0),Vector3(.24,2.64,0),Vector3(.45,2.55,0),Vector3(.90,2.60,0),Vector3(.95,2.63,.20),Vector3(1.45,2.65,.20),Vector3(1.20,2.63,.20),Vector3(1.75,2.68,.08)]
	finish_point=transfer_points[-1]
	route_zones=[
		{"label":"CLIMB","hint":"CLIMB / Hold both hands and use W. Reach into the cyan area; the hand stops at its real limit.","bounds":AABB(Vector3(-.60,2.35,-.10),Vector3(1.05,.50,.45)),"min_body_y":1.38},
		{"label":"TRAVERSE","hint":"TRAVERSE / Keep one hand held, aim farther right and transfer. W + D moves up and across.","bounds":AABB(Vector3(.50,2.50,-.10),Vector3(.62,.45,.45)),"min_body_y":1.55},
		{"label":"SUSPENSION","hint":"SUSPENSION / Move each hand along the first bar, then reach the turquoise finish. Keep one real grip.","bounds":AABB(Vector3(1.40,2.55,-.10),Vector3(.55,.40,.45)),"min_body_y":1.60,"suspended":true,"support":last}
	]
	paint(Vector3(-.075,2.60,.008),Vector2(1.05,.50),cyan)
	paint(Vector3(.81,2.725,.008),Vector2(.62,.45),gold)
	label3("1 / CLIMB",Vector3(-.25,3.05,.20),cyan,24)
	label3("2 / CROSS",Vector3(.85,3.18,.20),gold,24)
	label3("3 / HANG",Vector3(1.65,3.26,.35),cyan,24)
	label3("START",Vector3(-.18,.45,.9),cyan,22)

func paint(at:Vector3,size:Vector2,color:Color) -> void:
	var mesh:=MeshInstance3D.new()
	var rectangle:=QuadMesh.new()
	rectangle.size=size
	mesh.mesh=rectangle
	mesh.position=at
	var mat:=material(Color(color,.28))
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override=mat
	add_child(mesh)
