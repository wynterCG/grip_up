extends "res://features/grip_up/scripts/climb_test_level.gd"
## Small repeatable locomotion arenas; original labs remain untouched.
@export_enum("Step","Hang","Traverse","Corner") var arena:=0
var transfer_points:Array[Vector3]=[]

func _ready() -> void:
	if arena==1:
		title="v0.7 / THE HANG"
		objective="Choose a bar contact. Hold one hand, request movement, then reverse to brake.\nYou still choose when and where the other hand catches."
		spawn=Vector3(-.55,1.17,.4)
		box("Start",Vector3(-.8,.1,.55),Vector3(1,.3,2),Color("526a72"))
		hold(Vector3(-.55,2.2,.15),"START",cyan)
		hold(Vector3(.35,2.2,.15),"TRANSFER",gold)
		transfer_points=[holds[0].position+Vector3(0,-.051,0),holds[1].position+Vector3(0,-.051,0)]
		finish_point=transfer_points[-1]
		return
	var wall:=box("Intent wall",Vector3(0,2.3,-.2),Vector3(4.2,5.4,.4),steel)
	holds.append(wall)
	box("Start",Vector3(0,.1,1),Vector3(5,.3,5),Color("526a72"))
	if arena==0:
		title="v0.7 / THE STEP"
		objective="Hold the low contacts. W / move up; S / lower.\nChoose the higher contact with the free hand; keep the other hand held."
		# Keep the lip behind the compound calf collider; feet reach it by IK/contact.
		var foot:=box("Broad real foothold",Vector3(0,.51,0),Vector3(.95,.16,.22),Color("8bb88c"))
		footholds.append(foot)
		transfer_points=[Vector3(-.24,2.10,0),Vector3(.24,2.10,0),Vector3(-.24,2.43,0),Vector3(.24,2.64,0)]
	else:
		title="v0.7 / THE CORNER" if arena==3 else "v0.7 / THE TRAVERSE"
		objective="A / D requests side travel. Pick each contact and keep one hand supporting.\nOrbit while holding a direction: the command keeps its world axis."
		for index in 4:
			var x:float=-.45+index*.30
			var foot:=box("Traverse foothold %d" % index,Vector3(x,.51,0),Vector3(.24,.16,.22),Color("8bb88c"))
			footholds.append(foot)
		transfer_points=[Vector3(-.24,2.10,0),Vector3(.24,2.10,0),Vector3(.60,2.16,0),Vector3(.95,2.18,0)]
		if arena==3:
			box("Corner return wall",Vector3(1.35,2.3,.65),Vector3(.4,5.4,1.3),steel)
			transfer_points.append(Vector3(1.15,2.18,.55))
	for index in transfer_points.size():
		var point:=transfer_points[index]
		var marker:=SphereMesh.new()
		marker.radius=.028
		marker.height=.056
		var mesh:=MeshInstance3D.new()
		mesh.mesh=marker
		mesh.position=point+Vector3(0,0,.007)
		mesh.scale=Vector3(1,1,.1)
		mesh.material_override=material(cyan if index%2==0 else gold)
		add_child(mesh)
		label3("%02d" % index,point+Vector3(.10,.06,.03),cyan if index%2==0 else gold,20)
	finish_point=transfer_points[-1]
