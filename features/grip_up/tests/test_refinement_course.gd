extends SceneTree
const Exercise=preload("res://features/grip_up/tests/first_ascent_exercise.gd")
const Lab=preload("res://features/grip_up/scripts/grip_up_lab.gd")

func _initialize()->void:
	Engine.physics_ticks_per_second=60 if OS.get_cmdline_user_args().has("--60hz") else 120
	run.call_deferred()

func run()->void:
	var exercise=Exercise.new()
	root.add_child(exercise)
	exercise.hz=Engine.physics_ticks_per_second
	exercise.app=Lab.new()
	root.add_child(exercise.app)
	current_scene=exercise.app
	exercise.app._set_intent_aware_feet(true)
	exercise.app._set_locomotion_diagnostics(true)
	var report:Dictionary=await exercise.exercise_first_ascent()
	exercise.check(exercise.app.controller.intent_locomotion.movement_allocation==0 and exercise.app.controller.intent_aware_feet_enabled,"B2 complete course uses A0 allocation and explicit intent-aware feet")
	report.checks=exercise.checks
	report.failures=exercise.failures
	report.foot_selection=exercise.app.controller.feet_solver.candidate_selection()
	report.observer_windows=exercise.app.controller.locomotion_observer.transition_windows()
	report.scope="Same finite ordinary-input course as A0/B1, A0/B2 candidate; automated not human benefit"
	FileAccess.open("res://builds/refinement_course_%dhz.json"%exercise.hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("REFINEMENT COURSE RESULTS: %d checks, %d failures"%[exercise.checks,exercise.failures])
	quit(1 if exercise.failures else 0)
