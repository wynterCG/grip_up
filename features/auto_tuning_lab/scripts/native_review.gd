extends Node
## Explicit MCP-only scene: a new world, no overlap with the normal play scene.
## Python already validates the candidate; Godot independently validates again.
const Driver=preload("res://features/auto_tuning_lab/scripts/optimization_trial_driver.gd")
const Serializer=preload("res://features/locomotion_test_suite/scripts/session_recorder.gd")
const REQUEST="res://builds/auto_tuning/native_review_request.json"
var driver:Node
var output_dir:=""
var completed:=false
var _seen:Dictionary={}
var _capture_pending:=false
var _screenshots:=0
var _label:Label

func _ready()->void:
	get_window().current_screen=0
	var hud:=CanvasLayer.new();hud.layer=30;add_child(hud)
	_label=Label.new();_label.position=Vector2(24,190);_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size",20);hud.add_child(_label)
	_label.text="Offline tuning lab / scripted native review"
	_run.call_deferred()

func _fail(reason:String)->void:
	_label.text="Native review stopped: "+reason
	completed=true
	push_error(reason)

func _run()->void:
	if not FileAccess.file_exists(REQUEST):_fail("Explicit research request missing");return
	var request:Variant=JSON.parse_string(FileAccess.get_file_as_string(REQUEST))
	if not request is Dictionary or not request.get("candidate_path") is String or not request.get("output_dir") is String or not request.get("candidate_sha256") is String:_fail("Invalid review request");return
	if FileAccess.get_sha256(request.candidate_path)!=request.candidate_sha256:_fail("Candidate file identity mismatch");return
	var candidate:Variant=JSON.parse_string(FileAccess.get_file_as_string(request.candidate_path))
	if not candidate is Dictionary:_fail("Invalid candidate JSON");return
	if candidate.get("evaluation_split")!="train":_fail("MCP review accepts public training trials only; withheld replay requires the Python freeze guard");return
	output_dir=request.output_dir
	if FileAccess.file_exists(output_dir+"/result.json"):_fail("Review output already exists");return
	if DirAccess.make_dir_recursive_absolute(output_dir)!=OK:_fail("Cannot create review output");return
	driver=Driver.new();add_child(driver)
	var result:Dictionary=await driver.run_trial(candidate)
	result["native_review"]={"source":"scripted","monitor_index":get_window().current_screen,"screenshots":_screenshots,"rendering":"real time; no fixed-fps CLI acceleration","human_ratings":null,"candidate_file_sha256":request.candidate_sha256}
	var temporary:String=output_dir+"/result.json.tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:_fail("Review result write failed");return
	file.store_string(JSON.stringify(Serializer.serializable(result),"\t"));file.close()
	if DirAccess.rename_absolute(temporary,output_dir+"/result.json")!=OK:_fail("Review result publish failed");return
	completed=true
	_label.text="Scripted review finished: %s / normal A0 defaults preserved"%result.get("status","unknown")
	print("NATIVE TUNING REVIEW ",result.get("status")," / ",output_dir)

func _process(_delta:float)->void:
	if completed or not is_instance_valid(driver) or not is_instance_valid(driver.app):return
	if not driver.active:return
	var id:int=driver.app.level.get_instance_id()
	if not _seen.has(id):_seen[id]={"since":Time.get_ticks_msec(),"captured":false}
	if not _seen[id].captured and not _capture_pending and _screenshots<12 and Time.get_ticks_msec()-int(_seen[id].since)>650:
		_seen[id].captured=true;_capture_pending=true;_capture()
	_label.text="Scripted native review / %d Hz / recording technical evidence\nNo human preference or default promotion"%driver.hz

func _capture()->void:
	await RenderingServer.frame_post_draw
	if is_inside_tree():
		_screenshots+=1
		get_viewport().get_texture().get_image().save_png(output_dir+"/frame_%02d.png"%_screenshots)
	_capture_pending=false
