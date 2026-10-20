extends SceneTree
## Exercises the REAL FirstAscent wrapper's pre-tick cancellation hook and the
## REAL trial status/cleanup pipeline, without running withheld route outcomes.
const Driver=preload("res://features/auto_tuning_lab/scripts/optimization_trial_driver.gd")
const Exercise=preload("res://features/auto_tuning_lab/scripts/first_ascent_trial_exercise.gd")
const Loader=preload("res://features/auto_tuning_lab/scripts/optimization_override_loader.gd")
class TimeoutTrial:
	extends "res://features/auto_tuning_lab/scripts/optimization_trial_driver.gd"
	var wrapper_aborted:=false
	var physics_frames_advanced:=0
	func _run_scenario(definition:Dictionary)->Dictionary:
		# Expire the observed wall clock, not a body/route state. This test must
		# not evaluate private route performance just to test failure taxonomy.
		_clock_start=Time.get_ticks_msec()-2000
		var wrapper=Exercise.new();add_child(wrapper)
		wrapper.hz=hz;wrapper.cancel_check=_first_ascent_cancelled
		var frame_before:int=Engine.get_physics_frames()
		await wrapper.ticks(.20)
		physics_frames_advanced=Engine.get_physics_frames()-frame_before
		wrapper_aborted=wrapper._aborted
		wrapper.queue_free()
		return {"id":definition.id,"revision":int(definition.revision),"status":"failed_task","completed":false,"reason":"ABORTED","invariants":{},"metrics":{},"capture":{},"scope":"FirstAscent timeout callback contract only; no physical route outcome"}
var checks:=0
var failures:=0
var hz:=120
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func manifest()->Dictionary:
	var loader=Loader.new();var values:Dictionary={}
	for knob:Dictionary in loader.space.parameters:values[knob.id]=knob.baseline
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Driver.TRAIN))
	return {"schema_version":"1.0","trial_id":"timeout-contract","candidate_id":loader.canonical(values).sha256_text(),"profile":"BASE-A0-B1","parameter_overrides":values,"scenarios":[catalog.scenarios[0].id],"requested_physics_hz":hz,"input_trace_id":catalog.input_trace_id,"run_seed":101,"repository_commit":"0".repeat(40),"timeout_seconds":1,"source_hashes":{"features/auto_tuning_lab/resources/parameter_space.json":FileAccess.get_sha256(Loader.SPACE_PATH)},"engine_identity":{"version":"4.7.2.stable.steam."+str(Engine.get_version_info().hash).substr(0,9),"sha256":FileAccess.get_sha256(OS.get_executable_path())},"evaluation_split":"train"}
func _initialize()->void:
	if OS.get_cmdline_user_args().has("--60hz"):hz=60
	Engine.physics_ticks_per_second=hz
	run.call_deferred()
func run()->void:
	var driver=Driver.new();root.add_child(driver)
	driver.candidate={"timeout_seconds":1};driver._clock_start=Time.get_ticks_msec()
	check(not driver._first_ascent_cancelled() and not driver.cancelled,"unexpired wall clock neither cancels nor changes state")
	driver.violations={"force_budget_violation":true}
	check(driver._first_ascent_cancelled() and not driver.cancelled,"hard invariant abort remains distinct from wall timeout")
	driver.violations.clear();driver.cancelled=true
	check(driver._first_ascent_cancelled(),"existing cancellation remains latched")
	driver.cancelled=false;driver._clock_start=Time.get_ticks_msec()-2000
	check(driver._first_ascent_cancelled() and driver.cancelled,"expired FirstAscent deadline latches the trial cancellation state")
	driver.queue_free()
	var trial=TimeoutTrial.new();root.add_child(trial)
	var hz_before:int=Engine.physics_ticks_per_second
	var result:Dictionary=await trial.run_trial(manifest())
	check(trial.wrapper_aborted,"real FirstAscent wrapper observes the shared cancellation hook")
	check(trial.physics_frames_advanced==0 and trial.app==null,"expired pre-tick hook does not simulate a route or construct a Lab/body")
	check(result.status=="timed_out","real run_trial classifies the FirstAscent abort as timed_out, never completed")
	check(result.scenarios.size()==1 and result.scenarios[0].reason=="ABORTED" and not result.scenarios[0].completed,"aborted scenario remains explicit unsuccessful evidence")
	check(result.restoration.resources.originals_preserved and trial.loader.bindings.is_empty(),"timeout cleanup leaves no Resource binding or saved-resource mutation")
	check(result.restoration.physics_hz_restored and Engine.physics_ticks_per_second==hz_before,"timeout restores physics frequency through normal cleanup")
	check(result.environment.sources_after==result.environment.source_hashes,"timeout result retains independently verified unchanged source provenance")
	trial.queue_free()
	var receipt:Dictionary={"physics_hz":hz,"checks":checks,"failures":failures,"status":result.status,"wrapper_aborted":trial.wrapper_aborted,"physics_frames_advanced":trial.physics_frames_advanced,"scope":"actual wrapper cancellation and trial status pipeline; no heldout performance evaluated"}
	FileAccess.open("res://builds/auto_tuning_smoke/timeout_contract_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	print("TRIAL TIMEOUT RESULTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
