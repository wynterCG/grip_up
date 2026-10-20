extends RefCounted
## Final test-world revision; construction only before the actor's first step.
const Original=preload("res://features/evaluator_qualification/fixtures/qualification_fixture.gd")

static func apply(app:Node,definition:Dictionary)->Dictionary:
	var receipt:Dictionary=Original.apply(app,{"fixture":"qualification_mirror_v1"})
	if not receipt.get("ok",false):return receipt
	if app.controller._step!=0 or app.controller.simulation_time!=0.0:return {"ok":false,"reason":"LATE_FIXTURE_REVISION"}
	var level:Node=app.level
	var before:Array=receipt.geometry.parts.duplicate(true)
	var pad:StaticBody3D=level.get_node("EQ132SpawnPad")
	pad.position.z=.595
	pad.name="V134SpawnPadR2";pad.set_meta("mastery_surface","V134SpawnPadR2")
	for child:Node in pad.get_children():
		if child is CollisionShape3D:(child.shape as BoxShape3D).size.z=.41
		if child is MeshInstance3D:(child.mesh as BoxMesh).size.z=.41
	var parts:Array=before.duplicate(true)
	for part:Dictionary in parts:
		if part.id=="EQ132SpawnPad":
			part.id="V134SpawnPadR2";part.position_m[2]=.595;part.size_m[2]=.41
	if definition.domain_id=="foot_supported_step":
		for foot:PhysicsBody3D in level.footholds:
			level.remove_child(foot);foot.queue_free()
		level.footholds.clear()
		parts=parts.filter(func(part:Dictionary)->bool:return part.role!="foothold")
		var lip:PhysicsBody3D=level.box("V134FootLipR2",Vector3(0,.57,-.01),Vector3(.95,.16,.22),Color("8bb88c"),true)
		lip.set_meta("mastery_surface","V134FootLipR2");lip.set_meta("qualification_role","foothold")
		level.footholds.append(lip)
		parts.append({"id":"V134FootLipR2","role":"foothold","position_m":[0,.57,-.01],"size_m":[.95,.16,.22],"grippable":true,"color":"8bb88c"})
	receipt["before_geometry_parts"]=before
	receipt.geometry.parts=parts
	var actual:Array=[]
	for part:Node in level.get_children():
		if not part is PhysicsBody3D:continue
		for child:Node in part.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				actual.append({"key":part.get_meta("mastery_surface",part.name),"body_transform":part.global_transform,"shape_transform":child.transform,"size_m":child.shape.size,"collision_layer":part.collision_layer,"collision_mask":part.collision_mask,"grippable":part.get_meta("grippable",false)})
	receipt.geometry["actual_static_parts"]=actual
	receipt["original_geometry_id"]=receipt.geometry_id
	receipt.geometry_id=definition.fixture_revision
	receipt["fixture_revision"]=definition.fixture_revision
	receipt["construction_only_before_first_step"]=true
	receipt["actor_pose_velocity_or_solver_changes"]=false
	return receipt
