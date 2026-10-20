extends SceneTree
const Driver=preload("res://features/auto_tuning_lab/scripts/optimization_trial_driver.gd")
const Serializer=preload("res://features/locomotion_test_suite/scripts/session_recorder.gd")

func _initialize()->void:run.call_deferred()
func run()->void:
	var args:Array=OS.get_cmdline_user_args()
	var source:="";var destination:=""
	for index in args.size()-1:
		if args[index]=="--candidate":source=args[index+1]
		if args[index]=="--result":destination=args[index+1]
	if source.is_empty() or destination.is_empty():push_error("Expected --candidate ABS --result ABS");quit(2);return
	var raw:Variant=JSON.parse_string(FileAccess.get_file_as_string(source))
	var result:Dictionary={"schema_version":"1.0","status":"invalid_candidate","reason":"JSON_ROOT"}
	if raw is Dictionary:
		var driver=Driver.new();root.add_child(driver)
		result=await driver.run_trial(raw)
		result["trial_id"]=raw.get("trial_id","");result["candidate_id"]=raw.get("candidate_id","")
		result["parameter_overrides"]=raw.get("parameter_overrides",{})
		if not result.has("environment"):
			result["environment"]={"repository_commit":raw.get("repository_commit",null),"repository_identity_scope":"caller provenance; no physics evaluation on invalid request","source_hashes":result.get("validation",{}).get("source_hashes",{}),"engine_version":Engine.get_version_info().hash,"engine_release":Engine.get_version_info().string,"engine_binary_sha256":FileAccess.get_sha256(OS.get_executable_path()),"physics_backend":ProjectSettings.get_setting("physics/3d/physics_engine"),"physics_hz":raw.get("requested_physics_hz",null),"actual_engine_physics_hz":Engine.physics_ticks_per_second,"evaluation_split":raw.get("evaluation_split",null)}
		if not result.has("scenarios"):result["scenarios"]=[]
		if not result.has("metrics"):result["metrics"]={}
		if not result.has("invariants"):result["invariants"]={}
	result["candidate_file_sha256"]=FileAccess.get_sha256(source)
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var temporary:String=destination+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:push_error("RESULT_WRITE_FAILED");quit(2);return
	file.store_string(JSON.stringify(Serializer.serializable(result),"\t"));file.close()
	var error:int=DirAccess.rename_absolute(temporary,destination)
	if error!=OK:push_error("RESULT_RENAME_FAILED");quit(2);return
	print("OPTIMIZATION TRIAL RESULT: ",result.status," / ",destination)
	quit(0 if result.status=="completed" else 1)
