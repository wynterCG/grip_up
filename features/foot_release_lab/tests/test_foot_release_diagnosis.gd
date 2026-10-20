extends SceneTree
## One fresh condition per process. Root schedules the four F0 episodes.
const Exercise=preload("res://features/foot_release_lab/tests/foot_release_repro.gd")
var _original_hz:=120

func _initialize()->void:
	_original_hz=Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second=60 if OS.get_cmdline_user_args().has("--60hz") else 120
	run.call_deferred()

func run()->void:
	var args:PackedStringArray=OS.get_cmdline_user_args()
	var index:int=args.find("--output")
	if index<0 or index+1>=args.size() or not args[index+1].is_absolute_path():
		push_error("F0 requires --output ABSOLUTE_UNIQUE_DIRECTORY; optional --feet-off and --60hz")
		Engine.physics_ticks_per_second=_original_hz
		quit(2)
		return
	var destination:String=args[index+1].replace("\\","/")
	if FileAccess.file_exists(destination.path_join("physics.jsonl")) or FileAccess.file_exists(destination.path_join("attempt_report.json")):
		push_error("F0 refuses to overwrite an existing attempt: "+destination)
		Engine.physics_ticks_per_second=_original_hz
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(destination)!=OK:
		push_error("Cannot create F0 output directory: "+destination)
		Engine.physics_ticks_per_second=_original_hz
		quit(2)
		return
	var exercise:Node=Exercise.new()
	root.add_child(exercise)
	exercise.hz=Engine.physics_ticks_per_second
	var result:Dictionary=await exercise.run_condition(not args.has("--feet-off"),destination)
	print("FOOT RELEASE F0: %s | %s | %d Hz | hotspot=%s | %s"%[result.status,result.condition,result.physics_hz,result.reached_localized_cross_window,destination])
	Engine.physics_ticks_per_second=_original_hz
	# A diagnostic preparation failure is retained evidence, not a passing
	# desticking claim. The process exits nonzero so it cannot silently qualify.
	quit(0 if result.status=="DIAGNOSTIC_COMPLETE" else 1)
