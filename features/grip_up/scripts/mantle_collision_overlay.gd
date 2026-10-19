extends Node3D
## Render-only collision proxies beside the IK skeleton; no physics authority.
var body:RigidBody3D
var shapes:Dictionary={}

func _process(_delta:float)->void:
	if not is_instance_valid(body):return
	for shape in body.get_children():
		if not shape is CollisionShape3D or shape.disabled:continue
		if not shapes.has(shape.get_instance_id()):
			var mesh:=MeshInstance3D.new()
			var material:=StandardMaterial3D.new()
			material.albedo_color=Color(.15,.85,1,.25)
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			material.no_depth_test=true
			mesh.material_override=material
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mesh)
			shapes[shape.get_instance_id()]={"node":weakref(shape),"mesh":mesh,"resource":null}
		var item:Dictionary=shapes[shape.get_instance_id()]
		if item.resource!=shape.shape:
			item.resource=shape.shape
			if shape.shape is CapsuleShape3D:
				var mesh:=CapsuleMesh.new()
				mesh.radius=shape.shape.radius
				mesh.height=shape.shape.height
				item.mesh.mesh=mesh
			elif shape.shape is SphereShape3D:
				var mesh:=SphereMesh.new()
				mesh.radius=shape.shape.radius
				mesh.height=shape.shape.radius*2
				item.mesh.mesh=mesh
			elif shape.shape is BoxShape3D:
				var mesh:=BoxMesh.new()
				mesh.size=shape.shape.size
				item.mesh.mesh=mesh
		item.mesh.global_transform=body.get_global_transform_interpolated()*shape.transform
	for key in shapes.keys():
		if not is_instance_valid(shapes[key].node.get_ref()):
			shapes[key].mesh.queue_free()
			shapes.erase(key)
