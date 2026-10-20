extends "res://features/grip_up/scripts/climb_test_level.gd"
## New public fixture only. Geometry is authored before the first physics tick.
var geometry:Dictionary={}
var fixture_id:=""
var transfer_points:Array[Vector3]=[]
var construction_report:Dictionary={}

func _ready()->void:
	title="Qualification / symmetric clearance r1"
	objective="Diagnostic fixture; no gameplay success or solver assistance."
	spawn=_vector(geometry.spawn_m)
	for part:Dictionary in geometry.parts:
		var body:PhysicsBody3D=box(str(part.id),_vector(part.position_m),_vector(part.size_m),Color(str(part.color)),bool(part.grippable))
		body.set_meta("mastery_surface",str(part.id))
		body.set_meta("qualification_fixture",fixture_id)
		body.set_meta("qualification_role",str(part.role))
		if part.role=="hand_surface":holds.append(body)
		elif part.role=="foothold":footholds.append(body)
	for point:Array in geometry.contact_points_m:transfer_points.append(_vector(point))
	finish_point=transfer_points[-1]
	construction_report={"fixture_id":fixture_id,"parts":geometry.parts.duplicate(true),"spawn_m":spawn,"contact_points_m":transfer_points.duplicate(),"construction_only":true}

static func _vector(value:Array)->Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))
