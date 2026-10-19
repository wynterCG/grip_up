extends RefCounted
## Option B: a single ledge-aligned collision-body route. No animation root travel.
var start:=Transform3D.IDENTITY
var standing:=Transform3D.IDENTITY
var clear_pose:=Transform3D.IDENTITY
var outside:=Transform3D.IDENTITY
var crossed:=Transform3D.IDENTITY
var duration:=1.15
var candidate:Dictionary={}
var collision_motor:RefCounted

func configure(data:Dictionary,motor:RefCounted)->void:
	collision_motor=motor
	candidate=data
	start=data.start_pose_world
	standing=data.target_standing_pose_world
	var outward:Vector3=data.outward_world
	var facing:=Basis.looking_at(-outward,Vector3.UP)
	outside=Transform3D(start.basis,start.origin+outward*.10)
	var tucked_height:float=-motor.lowest_point(1.0)+.018
	clear_pose=Transform3D(facing,Vector3(outside.origin.x,data.top_reference_world.y+tucked_height,outside.origin.z))
	crossed=Transform3D(facing,standing.origin)
	crossed.origin.y=clear_pose.origin.y

func _ease(value:float)->float:
	return smoothstep(0.0,1.0,clampf(value,0,1))

func sample(progress:float)->Dictionary:
	var p:=clampf(progress,0,1)
	var pose:Transform3D
	var flex:float
	if p<.10:
		pose=start.interpolate_with(outside,_ease(p/.10))
		flex=0
	elif p<.20:
		pose=outside.interpolate_with(Transform3D(clear_pose.basis,outside.origin),_ease((p-.10)/.10))
		flex=0
	elif p<.50:
		var t:=_ease((p-.20)/.30)
		pose=Transform3D(clear_pose.basis,outside.origin).interpolate_with(clear_pose,t)
		flex=t
	elif p<.77:
		pose=clear_pose.interpolate_with(crossed,_ease((p-.50)/.27))
		flex=1
	else:
		var t:=_ease((p-.77)/.23)
		pose=crossed.interpolate_with(standing,t)
		flex=1-t
	# Unfolding is an arc, so linear pelvis rise alone does not clear the shin.
	if p>=.50:
		pose.origin.y=maxf(pose.origin.y,float(candidate.top_reference_world.y)-collision_motor.lowest_point(flex)+.0083)
	return {"pose":pose,"flex":flex,"progress":p}

func preflight(motor:RefCounted)->Dictionary:
	var previous:=sample(0)
	var samples:Array=[previous]
	for index in range(1,65):
		var next:=sample(float(index)/64)
		var clearance:Dictionary=motor.validate_segment(previous.pose,next.pose,previous.flex,next.flex)
		if not clearance.get("clear",false):
			return {"clear":false,"reason":"PATH_BLOCKED","segment":index,"detail":clearance,"samples":samples}
		samples.append(next)
		previous=next
	return {"clear":true,"reason":"CLEAR","samples":samples}
