extends "res://features/grip_up/scripts/climb_test_level.gd"
## Feasible basic transfers and a separately authored swing gate. Markers are paint.
@export var swing_route := false
@export_range(.08,.16,.01) var vertical_spacing := .12
@export var lateral_asymmetry := .035
var transfer_points: Array[Vector3]=[]

func _ready() -> void:
	if swing_route:
		title="06 / SWING REACH LAB"
		objective="The far surface is outside static reach. Pump, brake and time the catch."
		spawn=Vector3(-.55,1.17,.40)
		box("Start",Vector3(-.8,.1,.55),Vector3(1,.3,2),Color("526a72"))
		box("Overhead frame",Vector3(0,3.1,-.3),Vector3(3.5,.14,.2),steel)
		hold(Vector3(-.55,2.2,.15),"START",cyan)
		hold(Vector3(.35,2.2,.15),"SWING",gold)
		finish_point=holds[-1].position
		transfer_points=[holds[0].position,holds[1].position]
		label3("SWING REQUIRED",Vector3(.35,2.65,.15),gold,26)
		return
	title="05 / TEN TRANSFER LAB"
	objective="Ten alternating transfers. Painted guides are optional; grip any wall surface."
	var wall: PhysicsBody3D=box("Transfer wall",Vector3(0,2.3,-.2),Vector3(3.6,5.4,.4),steel)
	box("Start",Vector3(0,.1,1),Vector3(5,.3,5),Color("526a72"))
	holds.append(wall)
	for index in 11:
		var side: float=-1 if index%2==0 else 1
		var offset: float=lateral_asymmetry*side if index in [4,5,6,7] else 0.0
		var point:=Vector3(side*.1919+offset,2.05+vertical_spacing*index,0)
		transfer_points.append(point)
		var marker:=MeshInstance3D.new()
		var disc:=SphereMesh.new()
		disc.radius=.032
		disc.height=.064
		marker.mesh=disc
		marker.scale.z=.08
		marker.position=point+Vector3(0,0,.006)
		marker.material_override=material(cyan if side<0 else gold)
		add_child(marker)
		label3("%02d" % index,point+Vector3(side*.10,.015,.01),cyan if side<0 else gold,17)
	finish_point=transfer_points[-1]
	label3("10 TRANSFERS",Vector3(0,finish_point.y+.35,.01),cyan,26)
