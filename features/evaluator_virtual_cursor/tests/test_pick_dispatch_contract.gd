extends SceneTree
const Contract=preload("res://features/evaluator_virtual_cursor/scripts/pick_dispatch_contract.gd")
const CASES="res://features/evaluator_virtual_cursor/tests/pick_contract_cases_v134.json"
var passed:=0
var failed:=0

func check(value:bool,label:String)->void:
	if value:passed+=1
	else:failed+=1;push_error("FAIL "+label)

func _initialize()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(CASES))
	if not fixture is Dictionary:
		check(false,"fixture JSON parsed");quit(1);return
	var sample:Dictionary=fixture.cases[0].input.sidecars[0].rays[0]
	var endpoint:Vector3=Vector3(sample.origin[0],sample.origin[1],sample.origin[2])+Vector3(sample.world_normal_used[0],sample.world_normal_used[1],sample.world_normal_used[2])*70.0
	var native_recorded:=Vector3(sample.query_to[0],sample.query_to[1],sample.query_to[2])
	var diagnostic:Dictionary={"raw_parsed_query_to":sample.query_to,"reconstructed_native_endpoint":[endpoint.x,endpoint.y,endpoint.z],"native_recorded_endpoint":[native_recorded.x,native_recorded.y,native_recorded.z],"native_equal":endpoint==native_recorded}
	diagnostic["scalar_bits"]=preload("res://features/evaluator_virtual_cursor/scripts/projection_probe.gd").number_bits(diagnostic,"",{})
	print(JSON.stringify({"endpoint_transport_diagnostic":diagnostic},"",true,true))
	for index in fixture.cases.size():
		var case:Dictionary=fixture.cases[index]
		var path:String="user://pick_dispatch_contract_case_%d.json"%index
		var file:=FileAccess.open(path,FileAccess.WRITE)
		if file==null:check(false,"roundtrip file open");continue
		file.store_string(JSON.stringify(case.input,"",true,true));file.close()
		var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		var before:Dictionary=data.duplicate(true)
		var view:Dictionary=Contract.build_view(data.ticks,data.sidecars,data.session_id,data.completed,int(data.expected_tick_count),bool(data.get("strict_new",false)))
		check(view.reason==case.expected_reason,str(case.name)+" typed reason: "+str(view.reason))
		check(data==before,str(case.name)+" input immutable")
		if case.expected_reason.is_empty():
			check(view.status=="PASS",str(case.name)+" pass")
			if view.status=="PASS":
				check(Contract.same_numbers([view.logical_count,view.dispatch_count,view.ray_count,view.suppressed_count],case.expected_counts),str(case.name)+" counts")
				var ids:Dictionary={}
				for dispatch:Dictionary in view.dispatches:ids[dispatch.dispatch_id]=true
				check(ids.size()==view.dispatch_count,str(case.name)+" unique dispatch IDs")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite":"pick_dispatch_contract_v134","cases":fixture.cases.size(),"passed":passed,"failed":failed,"physical_bodies_created":0}))
	quit(1 if failed else 0)
