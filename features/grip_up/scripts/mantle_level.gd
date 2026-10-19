extends "res://features/grip_up/scripts/climb_test_level.gd"
## M6 capability experiment: one ordinary solid platform, no hidden supports.
var platform:PhysicsBody3D
var transfer_points:Array[Vector3]=[]
@export var top_y:=2.10

func _ready() -> void:
	title="THE LEDGE / EXPERIMENT"
	objective="Hold the platform edge with LMB / RMB and request upward travel with W.\nThe body stays physical. This experiment may expose limits of the current limbs."
	spawn=Vector3(0,1.17,.40)
	box("Safe base",Vector3(0,.1,.5),Vector3(5,.3,5),Color("526a72"),false)
	platform=box("Ledge platform",Vector3(0,(top_y+.25)*.5,-.80),Vector3(2,top_y-.25,1.6),steel)
	holds.append(platform)
	for side in [-1.0,1.0]:
		footholds.append(box("Low foot lip",Vector3(side*.31,.59,.015),Vector3(.20,.12,.19),Color("8bb88c")))
	transfer_points=[Vector3(-.20,top_y-.05,0),Vector3(.20,top_y-.05,0),Vector3(-.20,top_y,-.08),Vector3(.20,top_y,-.08)]
	finish_point=transfer_points[-1]
	label3("REAL EDGE / W TO TRY",Vector3(0,top_y+.3,.04),cyan,24)
	label3("TOP / WALK AWAY",Vector3(0,top_y+.04,-1.1),gold,20)
