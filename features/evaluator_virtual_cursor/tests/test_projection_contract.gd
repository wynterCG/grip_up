extends SceneTree
const Probe=preload("res://features/evaluator_virtual_cursor/scripts/projection_probe.gd")
var passed:=0
var failed:=0
func check(value:bool,label:String)->void:
	if value:passed+=1
	else:failed+=1;push_error(label)
func _initialize()->void:
	var v:=Vector3(.000000154318774,1.0,-0.0)
	var encoded:Variant=Probe.encode(v)
	var text:String=JSON.stringify(encoded,"",true,true)
	var parsed:Variant=JSON.parse_string(text)
	print(JSON.stringify({"encoded":encoded,"text":text,"parsed":parsed,"original_bits":Probe.number_bits(encoded,"",{}),"parsed_bits":Probe.number_bits(parsed,"",{})},"",true,true))
	check(Vector3(parsed[0],parsed[1],parsed[2]).x==v.x,"JSON retains float32 vector value after Godot reader rounding")
	check(Probe.number_bits(encoded,"",{})["/0"]!=Probe.number_bits(parsed,"",{})["/0"],"pinned JSON reader scalar rounding documented")
	var negative_zero:float=PackedByteArray([0,0,0,0,0,0,0,128]).decode_double(0)
	var zero_bits:Dictionary=Probe.number_bits([0.0,negative_zero],"",{})
	check(zero_bits["/0"]!=zero_bits["/1"],"signed zero bits")
	check(not Probe.finite([NAN]),"NaN rejected")
	check(not Probe.finite({"bad":INF}),"Inf rejected")
	check(Probe.finite(encoded),"finite vector")
	check(Probe.encode(Projection()).size()==4,"projection encoding")
	check(Probe.encode(Transform3D()).size()==4,"transform encoding")
	var rect:Dictionary=Probe.encode(Rect2(1,2,3,4))
	check(rect["size"][0]==3 and rect["size"][1]==4,"rect encoding")
	var camera:=Camera3D.new()
	for method in ["project_local_ray_normal","project_ray_normal","project_ray_origin","get_camera_transform","get_camera_projection"]:check(camera.has_method(method),"public camera "+method)
	check(not root.has_method("get_camera_rect_size"),"internal camera rect not public")
	check(not root.has_method("get_camera_coords"),"internal camera coords not public")
	check(root.has_method("get_stretch_transform"),"public stretch")
	check(root.has_method("get_size"),"root window size")
	print(JSON.stringify({"passed":passed,"failed":failed,"engine":Engine.get_version_info(),"vector_16777217":Vector3(16777217.0,0,0).x},"",true,true))
	camera.free();quit(1 if failed else 0)
