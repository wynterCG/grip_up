extends "res://features/grip_up/tests/capture_first_ascent.gd"
## The same finite ordinary-input course, with explicit v1.1 flags and evidence.
func save_frame(label:String)->void:
	saving=true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/v11_%dhz_%s.png"%[hz,label])
	saving=false

func run()->void:
	var variant:int=app.movement_allocation
	var foot_policy:bool=app.intent_aware_feet_enabled
	report=await exercise_first_ascent()
	await ticks(.6)
	check(app.won and app.climbing_route.completed and app.hybrid_mantle.completed,"rendered v1.1 course wins after actual support and walking")
	await save_frame("finish")
	report.checks=checks
	report.failures=failures
	report.complete=true
	report.rendered=true
	report.window_screen=get_window().current_screen
	report.allocation_variant=variant
	report.intent_aware_feet=foot_policy
	report.swing_phase_feedback=app.swing_phase_feedback_enabled
	report.observer_windows=app.controller.locomotion_observer.transition_windows()
	report.last_observation=app.controller.locomotion_observer.data.duplicate(true)
	report.foot_selection=app.controller.feet_solver.candidate_selection() if app.controller.feet_solver!=null else {}
	report.provenance="Visible Godot MCP Pro; ordinary in-application inputs; not a human session or feel rating"
	FileAccess.open("C:/Users/Wynter/grip_up/builds/locomotion_refinement_native_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	for action in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:Input.action_release(action)
	print("LOCOMOTION REFINEMENT NATIVE RESULTS: %d checks, %d failures"%[checks,failures])
	Engine.physics_ticks_per_second=120
	app._open_first_ascent()
	queue_free()
