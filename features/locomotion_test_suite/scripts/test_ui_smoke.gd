extends Node
## Explicit --locomotion-tests-smoke only. Checks packaged UI, never drives physics.
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func _ready()->void:run.call_deferred()
func run()->void:
	var app=get_parent()
	for index in 4:await get_tree().process_frame
	check(app.input_profile==2 and not app.locomotion_diagnostics_enabled,"export preserves normal startup and diagnostics OFF")
	var suite=app.get_node("LocomotionTestSuite")
	check(suite.definitions.tasks.size()==10 and suite.task_choice.item_count==13,"embedded Windows build loads T01-T10 and three mastery choices")
	check(FileAccess.file_exists("res://features/locomotion_test_suite/resources/build_identity.json"),"embedded build carries its generated exact source identity")
	check(not suite.recorder.active and not suite.waiting,"export test UI creates no recording or physical authority")
	check(get_tree().root.get_node_or_null("MCPGameInspector")==null,"export excludes the local licensed editor plugin")
	var scroll:ScrollContainer=app.settings.find_children("*","ScrollContainer",true,false)[0]
	scroll.ensure_control_visible(suite.task_choice)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="):path=argument.trim_prefix("--evidence=")
	if not path.is_empty():
		get_viewport().get_texture().get_image().save_png(path+"/windows_test_ui.png")
		FileAccess.open(path+"/windows_ui_result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"resources":"embedded executable with explicit packaged read-only smoke flag","profile":app.input_profile,"tasks":suite.definitions.tasks.size(),"choices":suite.task_choice.item_count,"screen":get_window().current_screen,"engine":Engine.get_version_info()},"\t"))
	print("EXPORT TEST UI RESULTS: %d checks, %d failures"%[checks,failures])
	get_tree().quit(1 if failures else 0)
