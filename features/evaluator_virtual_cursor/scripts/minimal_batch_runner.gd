extends SceneTree
## Finalist-only packing: separate driver/world/tape/clock for every episode.
const Driver=preload("res://features/evaluator_virtual_cursor/scripts/minimal_driver.gd")
const Writer=preload("res://features/evaluator_reliability/scripts/reliability_trace.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	var args:Array=OS.get_cmdline_user_args();var path:=""
	for i in args.size()-1:
		if args[i]=="--batch-manifest":path=args[i+1]
	var batch:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not batch is Dictionary or batch.get("episodes",[]).size()!=2 or not args.has("--validate-shortlist"):quit(2);return
	var receipts:Array=[]
	for item:Dictionary in batch.episodes:
		var manifest:Variant=JSON.parse_string(FileAccess.get_file_as_string(item.manifest))
		if not manifest is Dictionary or manifest.get("phase")!="finalist":quit(2);return
		var before:int=Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
		var driver=Driver.new();root.add_child(driver)
		var result:Dictionary=await driver.start(manifest)
		result["manifest_file_sha256"]=FileAccess.get_sha256(item.manifest)
		var no_body:=root.find_children("*","PhysicsBody3D",true,false).is_empty()
		driver.free()
		await physics_frame
		await physics_frame
		var after:int=Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
		var clean:=no_body and root.find_children("*","PhysicsBody3D",true,false).is_empty() and before==after
		result["batch_boundary"]={"fresh_driver":true,"subtrees_absent":no_body,"active_bodies_before":before,"active_bodies_after":after,"cleanup_pass":clean,"two_cleanup_callbacks":true}
		if not Writer.atomic_json(item.result,result):quit(2);return
		receipts.append({"manifest":item.manifest,"result":item.result,"cleanup_pass":clean})
		if not clean or result.status!="completed":Writer.atomic_json(batch.receipt,{"status":"STOPPED","episodes":receipts});quit(1);return
	Writer.atomic_json(batch.receipt,{"status":"PASS","episodes":receipts});quit(0)
