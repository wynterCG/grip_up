extends SceneTree
const Driver=preload("res://features/evaluator_virtual_cursor/scripts/feasibility_driver.gd")
const Writer=preload("res://features/evaluator_reliability/scripts/reliability_trace.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	var args:Array=OS.get_cmdline_user_args();var source:="";var destination:=""
	for i in args.size()-1:
		if args[i]=="--manifest":source=args[i+1]
		if args[i]=="--result":destination=args[i+1]
	if source.is_empty() or destination.is_empty():quit(2);return
	var manifest:Variant=JSON.parse_string(FileAccess.get_file_as_string(source))
	var result:Dictionary={"status":"BLOCKED_SETUP","reason":"INVALID_MANIFEST"}
	if manifest is Dictionary:
		var driver=Driver.new();root.add_child(driver);result=await driver.start(manifest)
	result["manifest_file_sha256"]=FileAccess.get_sha256(source)
	if not Writer.atomic_json(destination,result):quit(2);return
	print("FEASIBILITY RESULT: ",result.status)
	quit(0 if result.status=="completed" else 1)
