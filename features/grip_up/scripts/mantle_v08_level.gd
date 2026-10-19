extends "res://features/grip_up/scripts/climb_test_level.gd"
## Separate low/high ledges. The launch pad is not part of a hanging gate.
@export var top_y:=1.25
var platform:PhysicsBody3D
var start_pad:PhysicsBody3D
var transfer_points:Array[Vector3]=[]

func _ready()->void:
	title="MANTLE v0.8 / %.2f m"%top_y
	objective="Hold an edge, then release one hand and aim onto the top to place a palm.\nW requests effort. Release both hands only when your feet really support you."
	spawn=Vector3(0,1.17,.40)
	start_pad=box("Approach pad",Vector3(0,.1,.9),Vector3(2.4,.3,1.8),Color("526a72"),false)
	platform=box("Mantle platform",Vector3(0,(top_y+.25)*.5,-1),Vector3(2.4,top_y-.25,2),steel)
	holds.append(platform)
	transfer_points=[Vector3(-.20,top_y-.05,0),Vector3(.20,top_y-.05,0),Vector3(-.20,top_y,-.12),Vector3(.20,top_y,-.12)]
	finish_point=transfer_points[-1]
	label3("EDGE / CHOOSE EACH HAND",Vector3(0,top_y+.3,.03),cyan,23)
	label3("TOP / PALM SUPPORT",Vector3(0,top_y+.08,-.8),gold,21)
