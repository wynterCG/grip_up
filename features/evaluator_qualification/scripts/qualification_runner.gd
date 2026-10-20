extends SceneTree
const Driver=preload("res://features/evaluator_qualification/scripts/qualification_driver.gd")
const Writer=preload("res://features/evaluator_reliability/scripts/reliability_trace.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	var arguments:Array=OS.get_cmdline_user_args()
	var source:="";var destination:=""
	for index in arguments.size()-1:
		if arguments[index]=="--manifest":source=arguments[index+1]
		if arguments[index]=="--result":destination=arguments[index+1]
	if source.is_empty() or destination.is_empty():push_error("Expected manifest and result");quit(2);return
	var manifest:Variant=JSON.parse_string(FileAccess.get_file_as_string(source))
	var result:Dictionary={"schema_version":"1.3.2","status":"BLOCKED_SETUP","reason":"INVALID_MANIFEST"}
	if manifest is Dictionary:
		var driver=Driver.new();root.add_child(driver)
		result=await driver.start(manifest)
	result["manifest_file_sha256"]=FileAccess.get_sha256(source)
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if not Writer.atomic_json(destination,result):push_error("RESULT_WRITE_FAILED");quit(2);return
	print("QUALIFICATION RESULT: ",result.status," / ",destination)
	quit(0 if result.status=="completed" else 1)
