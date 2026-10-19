extends "res://features/grip_up/scripts/climb_test_level.gd"
@export var scenario:="LOW"
var top_y:=1.25
var platform:PhysicsBody3D
var start_pad:PhysicsBody3D
var transfer_points:Array[Vector3]=[]

func _ready()->void:
	top_y=2.10 if scenario=="HIGH" else 1.25
	title="HYBRID MANTLE / "+scenario
	objective="Reach a real grip near the upper edge, then hold W to climb onto it.\nAfter the transition, release the grips and walk forward."
	spawn=Vector3(0,.37,.40)
	start_pad=box("Approach",Vector3(0,-.70,2),Vector3(5,.30,4),Color("526a72"),false)
	var depth:=.12 if scenario=="NARROW" else 2.8
	platform=box("Static ledge",Vector3(0,(top_y-.4)*.5,-depth*.5),Vector3(2.4,top_y+.4,depth),steel,true,scenario=="DYNAMIC")
	if platform is RigidBody3D:
		platform.mass=180
		platform.gravity_scale=0
	holds.append(platform)
	var first:float=minf(top_y-.05,1.35)
	transfer_points=[Vector3(-.20,first,0),Vector3(.20,first,0),Vector3(-.20,top_y-.05,0),Vector3(.20,top_y-.05,0)]
	finish_point=Vector3(0,top_y,-1.4)
	if scenario=="DOUBLE":
		var second:=box("Second static ledge",Vector3(0,(3.25-.4)*.5,-4.2),Vector3(2.4,3.65,2.8),steel)
		holds.append(second)
		transfer_points.append(Vector3(-.20,3.20,-2.8))
		transfer_points.append(Vector3(.20,3.20,-2.8))
	if scenario=="CEILING":box("Low ceiling",Vector3(0,top_y+1.35,.10),Vector3(3,.18,2.8),gold,false)
	if scenario=="OCCUPIED":box("Occupied landing",Vector3(0,top_y+.65,-.75),Vector3(1.4,1.3,.8),gold,false)
	label3("REACH THE EDGE / W",Vector3(0,top_y+.25,.03),cyan,23)
	label3("WALK ON TOP",Vector3(0,top_y+.10,-1.7),gold,22)
