extends SceneTree
const Driver=preload("res://features/evaluator_virtual_cursor/scripts/minimal_driver.gd")
const Backing=preload("res://features/evaluator_virtual_cursor/scripts/benchmark_backing.gd")
const Frame=preload("res://features/grip_up/scripts/grip_input_frame.gd")
var checks:=0
var failures:=0
var rows:Array=[]
var worlds:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var args:=OS.get_cmdline_user_args();var suite_path:="";var output:=""
	for i in args.size()-1:
		if args[i]=="--suite":suite_path=args[i+1]
		if args[i]=="--output":output=args[i+1]
	if not FileAccess.file_exists(suite_path) or output.is_empty():quit(2);return
	var suite:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(suite_path))
	for entry:Dictionary in suite.cases:
		var bytes:String=FileAccess.get_file_as_string(entry.manifest)
		var value:Dictionary=JSON.parse_string(bytes)
		if entry.has("synthetic"):
			value.projection_config[entry.synthetic.field][0]=NAN if entry.synthetic.special=="NAN" else INF
		var old_scale:Vector2i=root.content_scale_size
		if entry.get("wrong_actual_viewport",false):root.content_scale_size=Vector2i(1280,720)
		var driver:=Driver.new();root.add_child(driver)
		var result:Dictionary={}
		if entry.get("full_start",false):result=await driver.start(value)
		else:
			var reason:String=driver._virtual_scope(value)
			result={"status":"ADMISSION_ACCEPTED" if reason.is_empty() else "BLOCKED_SETUP","reason":reason}
		var accepted:bool=result.status=="ADMISSION_ACCEPTED"
		check(accepted==entry.accept,"Real JSON admission "+entry.id+": "+str(result.get("reason")))
		if entry.has("expected_reason"):check(str(result.get("reason","")).begins_with(entry.expected_reason),"Typed reason "+entry.id)
		check(not is_instance_valid(driver.app),"No gameplay body in transport contract "+entry.id)
		check(driver._world_creation.is_empty(),"No gameplay world ever created "+entry.id)
		if not driver._world_creation.is_empty():worlds+=1
		var schema:Dictionary=driver.backing_initialization.get("projection_schema",{})
		rows.append({"id":entry.id,"manifest_sha256":FileAccess.get_sha256(entry.manifest),"expected_accept":entry.accept,"accepted":accepted,"reason":result.get("reason"),"parsed_projection_config":Backing.safe_value(value.get("projection_config")),"schema":schema,"world_creation":driver._world_creation.duplicate(true),"gameplay_bodies_created":0})
		driver.free()
		root.content_scale_size=old_scale
	var resize_driver:=Driver.new();root.add_child(resize_driver)
	root.size=Vector2i(1440,810)
	check(not resize_driver._prepare_projection_size([1024,576]).is_empty() and root.size==Vector2i(1440,810),"Changed window is rejected without repair")
	root.size=Vector2i(1024,576);resize_driver.free()
	var config:Dictionary={"window_size":[1024,576],"logical_viewport_size":[1920,1080],"probe_enabled":true}
	check(Backing.initialize(root,config).reason.is_empty() and Backing.initialize(root,config).reason.is_empty() and root.size==Vector2i(1024,576),"Headless initialization idempotent before world")
	# Negative clock checks exercise the actual driver handshake without a world.
	var clock_driver:=Driver.new();root.add_child(clock_driver);clock_driver.hz=60
	clock_driver._begin_clock_handshake();clock_driver._record_clock_sample(1.0/60.0,0.0)
	check(clock_driver._clock_status!="READY","One callback cannot certify clock")
	clock_driver._record_clock_sample(1.0/120.0,0.0)
	check(clock_driver._clock_status!="READY" and clock_driver._clock_streak==0,"Stale rate resets confirmation")
	clock_driver._record_clock_sample(1.0/60.0,0.0);clock_driver._record_clock_sample(1.0/60.0,0.0)
	check(clock_driver._clock_status=="READY","Two actual handshake samples qualify unit clock")
	var clock_record:Dictionary=clock_driver._clock_receipt.duplicate(true)
	clock_driver.free()
	var tape:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(suite.tape))
	var first:Dictionary=tape.frames[0];var previous:Dictionary=first.duplicate(true)
	check(Frame.validate(first,{}).is_empty(),"Real JSON frame admitted")
	check(not Frame.validate(first,previous).is_empty(),"Duplicate JSON frame rejected")
	var missing:Dictionary=tape.frames[1].duplicate(true);missing.tick_index=3
	check(not Frame.validate(missing,previous).is_empty(),"Missing JSON frame rejected")
	var late:Dictionary=tape.frames[1].duplicate(true);late.tick_index=0
	check(not Frame.validate(late,previous).is_empty(),"Out-of-order JSON frame rejected")
	var result:Dictionary={"status":"CONTRACT_PASS" if failures==0 else "CONTRACT_FAIL","checks":checks,"failures":failures,"rows":rows,"clock_unit_contract":clock_record,"gameplay_bodies_created":worlds,"scope":"FILE_JSON_TRANSPORT_CONTRACT; physical replay certified separately"}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"",true,true));file.close()
	print("RESULTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
