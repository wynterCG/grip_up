extends Node
## Root launches this explicit diagnostic scene on the non-primary monitor.
const Driver=preload("res://features/evaluator_reliability/scripts/reliability_driver.gd")
const Writer=preload("res://features/evaluator_reliability/scripts/reliability_trace.gd")
const REQUEST="res://builds/evaluator_reliability/native_request.json"
var driver:Node
var completed:=false
var _output_dir:=""
var _capture_pending:=false
var _seen:Dictionary={}
var _screenshots:Array[Dictionary]=[]
const MAX_SCREENSHOTS=12
func _ready()->void:
	get_window().current_screen=0
	_run.call_deferred()
func _run()->void:
	if not FileAccess.file_exists(REQUEST):push_error("Explicit reliability request missing");return
	var request:Variant=JSON.parse_string(FileAccess.get_file_as_string(REQUEST))
	if not request is Dictionary or not request.get("manifest_path") is String or not request.get("result_path") is String:push_error("Invalid reliability request");return
	if FileAccess.get_sha256(request.manifest_path)!=request.get("manifest_sha256",""):push_error("Reliability manifest identity mismatch");return
	var manifest:Variant=JSON.parse_string(FileAccess.get_file_as_string(request.manifest_path))
	if not manifest is Dictionary or manifest.get("engine_mode")!="rendered_scripted":push_error("Explicit rendered reliability mode required");return
	if FileAccess.file_exists(request.result_path):push_error("Result already exists");return
	driver=Driver.new();add_child(driver)
	_output_dir=str(manifest.output_dir)
	var result:Dictionary=await driver.start(manifest)
	for frame in 4:
		if not _capture_pending:break
		await RenderingServer.frame_post_draw
	result["manifest_file_sha256"]=FileAccess.get_sha256(request.manifest_path)
	result["native_review"]={"data_kind":"automated_rendered_scripted","monitor_index":get_window().current_screen,"human_ratings":null,"screenshots":_screenshots.size(),"screenshot_phase":"frame_post_draw; interpolated rendering, indexed by latest preceding post_control observation, never claimed post-solver"}
	Writer.atomic_json(_output_dir.path_join("screenshot_index.json"),{"schema_version":"1.3.1","frames":_screenshots})
	Writer.atomic_json(request.result_path,result);completed=true

func _process(_delta:float)->void:
	if completed or _capture_pending or _screenshots.size()>=MAX_SCREENSHOTS or not is_instance_valid(driver):return
	if not driver.measurement_active or driver.latest.is_empty():return
	var snapshot:Dictionary=driver.latest
	var id:String=str(snapshot.scenario_id)
	var key:String=id+":onset"
	if _seen.has(key):
		if snapshot.hands[1].state!="ATTACHED":return
		key=id+":right_contact"
		if _seen.has(key):return
	_seen[key]=true;_capture_pending=true
	_capture(snapshot.duplicate(true))

func _capture(observed:Dictionary)->void:
	await RenderingServer.frame_post_draw
	if is_inside_tree():
		var path:String=_output_dir.path_join("screenshots")
		DirAccess.make_dir_recursive_absolute(path)
		var filename:String="frame_%02d.png"%(_screenshots.size()+1)
		var start_usec:int=Time.get_ticks_usec()
		var error:int=get_viewport().get_texture().get_image().save_png(path.path_join(filename))
		_screenshots.append({"file":"screenshots/"+filename,"scenario_id":observed.scenario_id,"observed_tick":observed.tick,"physics_time_s":observed.physics_time_s,"sample_phase":observed.sample_phase,"render_frame":Engine.get_process_frames(),"image_phase":"frame_post_draw; latest preceding observed tick, not post-solver","observed_com_m":observed.body.get("com_m"),"observed_hand_states":observed.hands.map(func(hand):return hand.state),"save_error":error,"readback_and_save_usec":Time.get_ticks_usec()-start_usec})
	_capture_pending=false
