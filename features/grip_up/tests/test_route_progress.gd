extends SceneTree
const Progress=preload("res://features/grip_up/scripts/climbing_route_progress.gd")
class Contact:
	extends RefCounted
	var point:=Vector3.ZERO
	var valid:=true
	var material:Node
	func is_valid() -> bool:return valid
	func world_point() -> Vector3:return point
	func support_body() -> Node:return material
class Rig:
	extends Node
	var torso:=Node3D.new()
	var hands:Array=[]
	var feet_solver:RefCounted
class Feet:
	extends RefCounted
	var feet:Array=[]
var checks:=0
var failures:=0
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures+=1
	print("PASS " if value else "FAIL ",label)
func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):Engine.physics_ticks_per_second=60
	run.call_deferred()
func run() -> void:
	var rig:=Rig.new()
	root.add_child(rig)
	rig.add_child(rig.torso)
	rig.torso.position=Vector3(0,1.5,0)
	var contact:=Contact.new()
	var final_material:=Node.new()
	rig.add_child(final_material)
	var other_material:=Node.new()
	rig.add_child(other_material)
	contact.material=other_material
	contact.point=Vector3(.3,2.5,0)
	rig.hands=[{"state":"REACHING","anchor":contact}]
	var zones:Array[Dictionary]=[{"label":"Climb","bounds":AABB(Vector3(-1,2,-.2),Vector3(2,1,.4)),"min_body_y":1.4},{"label":"Hang","bounds":AABB(Vector3(-1,2,-.2),Vector3(2,1,.4)),"min_body_y":1.4,"suspended":true}]
	zones[1]["support"]=final_material
	var progress=Progress.new()
	progress.update(rig,false,zones,0,1)
	check(progress.stage==0 and not progress.started,"pending target inside goal region cannot start or score the route")
	rig.hands[0].state="ATTACHED"
	progress.update(rig,false,zones,1,.1)
	check(progress.stage==0,"brief contact alone cannot complete a region")
	progress.update(rig,false,zones,1.1,.1)
	check(progress.stage==1 and progress.started,"real contact inside a broad region scores after a stable interval")
	progress.update(rig,true,zones,1.2,1)
	check(not progress.completed,"grounded contact cannot claim suspended section")
	rig.feet_solver=Feet.new()
	rig.feet_solver.feet=[{"state":"SUPPORTING","force":Vector3(0,50,0)}]
	progress.update(rig,false,zones,1.3,1)
	check(not progress.completed,"genuine loaded feet cannot claim arms-only suspension")
	rig.feet_solver.feet[0].state="SLIDING"
	progress.update(rig,false,zones,1.35,1)
	check(not progress.completed,"sliding feet which still transmit load cannot claim arms-only suspension")
	rig.feet_solver.feet[0].force=Vector3.ZERO
	contact.valid=false
	progress.update(rig,false,zones,1.4,.3)
	check(progress.stage==0 and progress.recoveries==1,"invalidated real support interrupts progress instead of completing a target")
	contact.valid=true
	progress.update(rig,false,zones,2,.3)
	contact.point=Vector3(4,2.5,0)
	progress.update(rig,false,zones,2.3,.3)
	check(not progress.completed,"contact outside current region cannot skip the route")
	contact.point=Vector3(.3,2.5,0)
	rig.torso.position.y=1.0
	progress.update(rig,false,zones,2.6,.3)
	check(not progress.completed,"a ground-level body cannot bypass required climbing height")
	rig.torso.position.y=1.5
	progress.update(rig,false,zones,2.9,.3)
	check(not progress.completed,"a different material overlapping the goal region cannot claim the finish")
	contact.material=final_material
	progress.update(rig,false,zones,3.0,.3)
	check(progress.completed and progress.stage==2 and progress.finished_at==3.0,"genuine unloaded-feet suspension on the final material completes route in order")
	var before:Transform3D=rig.torso.transform
	progress.update(rig,false,zones,3.2,1)
	check(rig.torso.transform==before and progress.events.size()==4,"read-only scorer cannot move the body or repeat completion")
	FileAccess.open("res://builds/route_progress_%dhz.json" % Engine.physics_ticks_per_second,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"route":progress.diagnostics()},"\t"))
	print("ROUTE PROGRESS RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
