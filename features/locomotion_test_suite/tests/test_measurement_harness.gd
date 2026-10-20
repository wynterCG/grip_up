extends "res://features/grip_up/tests/test_intent_integration.gd"
const Session=preload("res://features/locomotion_test_suite/scripts/session_recorder.gd")
var harness:Node

func pure_files()->void:
	var recorder=Session.new()
	var start:Dictionary={"time":0.0,"tick":0,"com_position":Vector3.ZERO,"movement_intent_world":Vector3.RIGHT,"velocity":Vector3.ZERO}
	check(not recorder.begin({"source":"fiction"},start,Vector3.RIGHT),"recorder rejects an invented recording source")
	var info:Dictionary={"source":"scripted","scenario":"FILE_SELF_CHECK","variant":{"id":"V0"},"physics_hz":hz,"build_identity":{"purpose":"explicit unit fixture, not a real run"}}
	check(recorder.begin(info,start,Vector3.RIGHT,{"max_samples":8,"max_events":4,"sample_hz":10}),"explicit unit capture opens streaming files")
	for index in range(1,hz+1):
		var row:Dictionary={"time":float(index)/hz,"tick":index,"com_position":Vector3.RIGHT*float(index)/hz,"movement_intent_world":Vector3.RIGHT,"velocity":Vector3.RIGHT,"vector":Vector3(1,2,3)}
		recorder.push(row)
	var summary:Dictionary=recorder.finish(true,"UNIT_COMPLETE")
	check(summary.movement.useful_progress_m>.999 and summary.buffers.samples==8,"bounded file capture retains cumulative movement outside its ring")
	check(summary.source=="scripted" and summary.assessment.human_ratings==null,"scripted output cannot acquire fabricated human ratings")
	var file:=FileAccess.open(recorder.directory+"/samples.jsonl",FileAccess.READ)
	var count:=0
	var vectors_ok:=true
	while file.get_position()<file.get_length():
		var row:Variant=JSON.parse_string(file.get_line())
		if row is Dictionary:
			count+=1
			if row.has("vector"):vectors_ok=vectors_ok and row.vector is Array and row.vector.size()==3
	check(count>=10 and count<=11 and vectors_ok,"JSONL sampling cadence and numeric vector schema remain analyzable")
	check(not recorder.active and not recorder.push(start),"closed capture performs no further file or metric writes")
	check(Session.serializable(NAN)==null and Session.serializable(Vector3.ONE)==[1.0,1.0,1.0],"serialization keeps missing/invalid numbers null and vectors numeric")
	check(Session.serializable(Vector2i(1440,810))==[1440,810],"actual window resolution stays numeric in exported provenance")

func run()->void:
	pure_files()
	app=Lab.new();root.add_child(app);current_scene=app
	await ticks(.15)
	check(app.input_profile==2 and not app.locomotion_diagnostics_enabled and app.get_node_or_null("LocomotionTestSuite")==null,"ordinary startup allocates no test harness and preserves profile2/observerOFF")
	var pose:Transform3D=app.torso.global_transform
	var velocity:Vector3=app.torso.linear_velocity
	app._open_locomotion_tests()
	harness=app.get_node("LocomotionTestSuite")
	check(app.torso.global_transform==pose and app.torso.linear_velocity==velocity and not harness.recorder.active and not app.locomotion_diagnostics_enabled,"opening inspection controls does not prepare, record, or actuate a body")
	check(harness.definitions.tasks.size()==10 and harness.definitions.variants.size()==5,"data-driven T01-T10 and five isolated variants are available")
	for index in 5:
		harness.prepare(0,index)
		var variant:Dictionary=harness.definitions.variants[index]
		check(app.input_profile==4 and app.movement_allocation==variant.allocation and app.physical_feet_enabled==variant.physical_feet and app.intent_aware_feet_enabled==variant.intent_feet and app.swing_phase_feedback_enabled==variant.feedback,"V%d applies only its declared independent configuration"%index)
	harness.prepare(0,0)
	await ticks(.4)
	check(harness.arm("scripted","practice"),"explicit scripted attempt arms without inventing human participation")
	await ticks(.1)
	check(harness.waiting and not harness.recorder.active,"T01 does not score before two actual contacts and accepted intent")
	check(await grip(0,app.level.transfer_points[0]),"T01 uses actual finite LMB capture")
	check(await grip(1,app.level.transfer_points[1]),"T01 uses actual finite independent RMB capture")
	Input.action_press("contract")
	await ticks(1.8)
	Input.action_release("contract")
	if harness.recorder.active:harness.finish(false,"FIXED_WINDOW_END")
	var result:Dictionary=harness.last_summary
	check(not result.is_empty() and result.source=="scripted" and result.scenario=="T01","real integrated capture stores source and task identity")
	check(not result.is_empty() and result.movement.useful_progress_m>0 and result.reference=="com","integrated movement uses positive physical direct-state COM progress")
	check(not result.is_empty() and result.initial_state.com_reference.contains("direct-state") and result.initial_state.contacts.size()>=2,"initial snapshot distinguishes actual COM, body origin and applied contact points")
	check(not app.locomotion_diagnostics_enabled,"finishing capture restores original observer OFF")
	harness.prepare(0,0)
	check(harness.arm("scripted","practice"),"next session can arm independently")
	app._set_intent_aware_feet(true)
	await ticks(.1)
	check(not harness.waiting and not harness.recorder.active and not app.locomotion_diagnostics_enabled,"changing variant aborts without mixing measurements or leaking observer authority")
	harness.prepare(0,0)
	harness.arm("scripted","practice")
	app.load_test(6)
	await ticks(.15)
	check(not harness.waiting and not app.locomotion_diagnostics_enabled,"scene replacement restores global observation flags on the new controller")
	harness.prepare(8,0)
	harness.arm("scripted","practice")
	await ticks(.15)
	check(harness.recorder.active,"T09 can record aiming from the ordinary floor without inventing supports")
	var wall:PhysicsBody3D=app.level.holds[0]
	var shape:BoxShape3D=wall.get_child(0).shape
	var target:Vector3=wall.to_global(Vector3(0,minf(.7,shape.size.y*.3),shape.size.z*.5))
	app.controller.request_held_grip(0,wall,target,Vector3.BACK)
	await ticks(.2)
	var aim_result:Dictionary=harness.finish(false,"VISIBILITY_PROBE_END")
	check(not aim_result.is_empty() and aim_result.camera.known_pending_target_s>0,"T09 visibility duration uses an actually selected pending material point")
	check(not aim_result.is_empty() and aim_result.camera.visibility_sample_hz==20 and aim_result.camera.occluded_target_time_s!=null,"known visibility is sampled read-only, with missing and zero distinguished")
	var fake:Dictionary=Session.serializable(harness.last_summary)
	check(not fake.is_empty() and fake.assessment.human_ratings==null,"session export remains JSON-safe with missing human evidence")
	check(budgets_ok,"instrumented real inputs preserve physical force and moment limits")
	FileAccess.open("res://builds/measurement_harness_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify({"physics_hz":hz,"checks":checks,"failures":failures,"last_trial":Session.serializable(result),"provenance":"Automated harness test, no human session"},"\t"))
	app.queue_free();await ticks(.04)
	print("MEASUREMENT HARNESS RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
