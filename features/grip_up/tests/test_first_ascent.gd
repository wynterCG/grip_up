extends SceneTree
const Exercise=preload("res://features/grip_up/tests/first_ascent_exercise.gd")
func _initialize()->void:
	Engine.physics_ticks_per_second=60 if OS.get_cmdline_user_args().has("--60hz") else 120
	run.call_deferred()
func run()->void:
	var exercise=Exercise.new()
	root.add_child(exercise)
	exercise.hz=Engine.physics_ticks_per_second
	var report:Dictionary=await exercise.exercise_first_ascent()
	FileAccess.open("res://builds/first_ascent_%dhz.json"%exercise.hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FIRST ASCENT RESULTS: %d checks, %d failures"%[exercise.checks,exercise.failures])
	quit(1 if exercise.failures else 0)
