extends "res://features/grip_up/tests/first_ascent_exercise.gd"
## Explicit visible MCP validation; no OS input or body-state writes.
var harness:Node
var soak_started:=0
var phase:=""
var phases:Dictionary={}
var memory_samples:Array=[]
var last_memory:=0
var soak_enabled:=true

func _ready()->void:
	app=get_parent()
	hz=Engine.physics_ticks_per_second
	run.call_deferred()

func _process(delta:float)->void:
	if phase.is_empty():return
	if not phases.has(phase):phases[phase]={"frames":0,"wall_delta_s":0.0,"process_ms_sum":0.0,"physics_monitor_ms_sum":0.0,"max_frame_delta_s":0.0}
	var row:Dictionary=phases[phase]
	row.frames+=1;row.wall_delta_s+=delta
	row.process_ms_sum+=Performance.get_monitor(Performance.TIME_PROCESS)*1000
	row.physics_monitor_ms_sum+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
	row.max_frame_delta_s=maxf(row.max_frame_delta_s,delta)
	if phase=="soak" and Time.get_ticks_usec()-last_memory>=5_000_000:
		last_memory=Time.get_ticks_usec()
		memory_samples.append({"monotonic_s":float(last_memory-soak_started)/1e6,"physics_s":app.controller.simulation_time,"static_bytes":OS.get_static_memory_usage(),"buffer_samples":harness.recorder.metrics.recent_samples().size(),"observer_windows":app.controller.locomotion_observer.windows.size(),"observer_pending":app.controller.locomotion_observer.pending.size()})

func wall_seconds(duration:float)->void:
	var until:int=Time.get_ticks_usec()+int(duration*1e6)
	while Time.get_ticks_usec()<until:await get_tree().process_frame

func screenshot(label:String)->void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/v12_%dhz_%s.png"%[hz,label])

func run()->void:
	app._open_locomotion_tests()
	harness=app.get_node("LocomotionTestSuite")
	harness.prepare(0,0)
	await ticks(.45)
	check(harness.arm("scripted","practice"),"visible harness arms an explicitly scripted trial")
	check(await grip(0,app.level.transfer_points[0]),"visible trial acquires a real finite left contact")
	check(await grip(1,app.level.transfer_points[1]),"visible trial acquires the independent right contact")
	Input.action_press("contract")
	await ticks(1.8)
	Input.action_release("contract")
	if harness.recorder.active:harness.finish(false,"FIXED_WINDOW_END")
	var trial:Dictionary=harness.last_summary
	check(not trial.is_empty() and trial.source=="scripted" and trial.reference=="com" and trial.movement.useful_progress_m>0,"visible trial records real signed COM progress without claiming a human session")
	await screenshot("measured_task")
	app.settings.show()
	var scroll:ScrollContainer=app.settings.find_children("*","ScrollContainer",true,false)[0]
	scroll.ensure_control_visible(harness.task_choice)
	await get_tree().process_frame
	await screenshot("test_ui")
	app.settings.hide()
	for action in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:Input.action_release(action)
	harness.prepare(7,0,"walk_reach")
	await ticks(.8)
	if hz==120 and soak_enabled:
		phase="observer_off"
		await wall_seconds(15)
		phase=""
		harness.task={"id":"SOAK_10MIN","name":"Bounded capture soak","revision":"1","ready_hands":0,"direction":[0,1,0],"goal":{"kind":"stress_only"}}
		harness.definitions.thresholds.max_duration_s=660
		check(harness.arm("scripted","practice"),"explicit ten-minute capture soak arms")
		await ticks(.1)
		phase="observer_on_capture"
		await wall_seconds(15)
		soak_started=Time.get_ticks_usec();last_memory=0
		phase="soak"
		await wall_seconds(600)
		phase=""
		var soak:Dictionary=harness.finish(false,"SOAK_COMPLETED_NOT_A_MOVEMENT_GOAL")
		check(not soak.is_empty() and soak.recording.written_samples<soak.recording.max_rows and soak.buffers.samples<=512 and soak.buffers.events<=128,"ten-minute real-time session keeps capture rings and disk row count bounded")
		FileAccess.open("C:/Users/Wynter/grip_up/builds/v12_soak.json",FileAccess.WRITE).store_string(JSON.stringify({"real_wall_soak_s":float(Time.get_ticks_usec()-soak_started)/1e6,"phases":phases,"memory_samples":memory_samples,"session_path":harness.recorder.directory,"summary":RecorderSafe(soak),"source":"scripted idle soak; not human mastery","physics_hz":hz,"complete":true},"\t"))
	FileAccess.open("C:/Users/Wynter/grip_up/builds/v12_native_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"physics_hz":hz,"screen":get_window().current_screen,"source":"scripted","trial":RecorderSafe(trial),"complete":true},"\t"))
	print("V12 VISIBLE RESULTS: %d checks, %d failures"%[checks,failures])
	harness.prepare(0,0)
	queue_free()

func RecorderSafe(value:Variant)->Variant:
	return load("res://features/locomotion_test_suite/scripts/session_recorder.gd").serializable(value)
