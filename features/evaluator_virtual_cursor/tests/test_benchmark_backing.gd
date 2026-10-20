extends SceneTree
const Driver=preload("res://features/evaluator_virtual_cursor/scripts/benchmark_driver.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var output:=""
	var args:=OS.get_cmdline_user_args()
	for i in args.size()-1:
		if args[i]=="--output":output=args[i+1]
	var parsed:Array=JSON.parse_string("[1024,576]")
	var old_array_comparison:bool=parsed==[1024,576]
	check(not old_array_comparison,"Pinned JSON array-type reproduction changed")
	var driver:=Driver.new();root.add_child(driver)
	var cases:Array=[{"size":[1024,576],"accept":true},{"size":[1024.0,576.0],"accept":true},{"size":parsed,"accept":true},{"size":[1024.0,576],"accept":true},{"size":[1024,576.0],"accept":true},{"size":[1024.00001,576],"accept":false},{"size":[1024,576.00001],"accept":false},{"size":[1440,810],"accept":false},{"size":[576,1024],"accept":false},{"size":[1024],"accept":false},{"size":[],"accept":false},{"size":null,"accept":false},{"size":["1024",576],"accept":false}]
	for entry:Dictionary in cases:
		var size:Variant=entry.size
		var value:Dictionary={"scenario_ids":["swing_catch_train"],"campaign_id":"benchmark_v133_r2_diagnostic","projection_config":{"window_size":size}}
		var result:String=driver._virtual_scope(value)
		check(result.is_empty() if entry.accept else result=="ENVIRONMENT_NOT_COMPARABLE:CANONICAL_BACKING","Projection config admission: "+str(size))
	check(root.size==Vector2i(1024,576),"Actual backing after valid startup")
	check(root.get_visible_rect().size==Vector2(1920,1080),"Actual logical viewport")
	var record:Dictionary={"checks":checks,"failures":failures,"old_array_comparison":old_array_comparison,"json_numeric_type":typeof(parsed[0]),"gameplay_bodies_created":0,"scope":"PURE_ADMISSION_CONTRACT_NOT_QUALIFICATION"}
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(record));file.close()
	print("RESULTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
