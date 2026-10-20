extends SceneTree
const Driver=preload("res://features/evaluator_virtual_cursor/scripts/virtual_cursor_driver.gd")
const Writer=preload("res://features/evaluator_reliability/scripts/reliability_trace.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	var arguments:Array=OS.get_cmdline_user_args()
	var source:="";var destination:=""
	for index in arguments.size()-1:
		if arguments[index]=="--manifest":source=arguments[index+1]
		if arguments[index]=="--result":destination=arguments[index+1]
	if source.is_empty() or destination.is_empty():quit(2);return
	var manifest:Variant=JSON.parse_string(FileAccess.get_file_as_string(source))
	var result:Dictionary={"status":"BLOCKED_SETUP","reason":"INVALID_MANIFEST"}
	if manifest is Dictionary:
		var driver=Driver.new();root.add_child(driver);result=await driver.start(manifest)
	result["manifest_file_sha256"]=FileAccess.get_sha256(source)
	if not Writer.atomic_json(destination,result):quit(2);return
	print("VIRTUAL CURSOR RESULT: ",result.status," / ",destination)
	quit(0 if result.status=="completed" else 1)
