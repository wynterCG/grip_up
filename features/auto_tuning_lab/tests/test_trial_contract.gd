extends SceneTree
## Transport/catalog checks only. Does not execute withheld outcomes.
const Driver=preload("res://features/auto_tuning_lab/scripts/optimization_trial_driver.gd")
const Loader=preload("res://features/auto_tuning_lab/scripts/optimization_override_loader.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func manifest()->Dictionary:
	var loader=Loader.new();var values:Dictionary={}
	for knob:Dictionary in loader.space.parameters:values[knob.id]=knob.baseline
	return {"schema_version":"1.0","trial_id":"contract-unit","candidate_id":loader.canonical(values).sha256_text(),"profile":"BASE-A0-B1","parameter_overrides":values,"scenarios":["vertical_pull_train"],"requested_physics_hz":60,"input_trace_id":"wrong_trace","run_seed":101,"repository_commit":"0".repeat(40),"timeout_seconds":90,"source_hashes":{"features/auto_tuning_lab/resources/parameter_space.json":FileAccess.get_sha256(Loader.SPACE_PATH)},"engine_identity":{"version":"4.7.2.stable.steam."+str(Engine.get_version_info().hash).substr(0,9),"sha256":FileAccess.get_sha256(OS.get_executable_path())},"evaluation_split":"train"}

func _initialize()->void:run.call_deferred()
func run()->void:
	var ids:Dictionary={}
	for path in ["res://features/auto_tuning_lab/resources/train_scenarios.json","res://features/auto_tuning_lab/resources/safety_scenarios.json","res://features/auto_tuning_lab/holdout/scenarios.json"]:
		var catalog:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		check(catalog is Dictionary and catalog.schema_version=="1.0" and catalog.revision>=1 and catalog.input_trace_id is String,"versioned catalog parses: "+path)
		var unique:=true
		for definition:Dictionary in catalog.scenarios:
			unique=unique and not ids.has(definition.id) and definition.revision>=1 and definition.has("scope")
			ids[definition.id]=true
		check(unique,"scenario IDs unique across splits, revision and scope explicit")
	check(ids.size()==20,"seven train plus four safety plus nine withheld definitions exist; no outcome evaluated")
	var driver=Driver.new();root.add_child(driver)
	var previous_hz:int=Engine.physics_ticks_per_second
	var candidate:Dictionary=manifest()
	var response:Dictionary=await driver.run_trial(candidate)
	check(response.status=="invalid_candidate" and response.reason=="INPUT_TRACE_ID_MISMATCH","trace mismatch rejected before scene or physics configuration")
	check(driver.app==null and Engine.physics_ticks_per_second==previous_hz,"rejected trace creates no Lab and leaves Hz unchanged")
	candidate=manifest();candidate.input_trace_id=JSON.parse_string(FileAccess.get_file_as_string("res://features/auto_tuning_lab/resources/train_scenarios.json")).input_trace_id;candidate.engine_identity.sha256="0".repeat(64)
	response=await driver.run_trial(candidate)
	check(response.status=="invalid_candidate" and response.reason=="ENGINE_IDENTITY_MISMATCH","actual engine executable hash enforced before actuation")
	check(driver.app==null and Engine.physics_ticks_per_second==previous_hz,"engine rejection has no world or settings residue")
	candidate=manifest();candidate.input_trace_id=JSON.parse_string(FileAccess.get_file_as_string("res://features/auto_tuning_lab/resources/train_scenarios.json")).input_trace_id;candidate.scenarios=["not_a_real_scenario"]
	response=await driver.run_trial(candidate)
	check(response.status=="unsupported_scenario" and response.reason.begins_with("UNKNOWN_SCENARIO"),"unknown scenario is rejected, never scored as zero effort success")
	check(driver.app==null,"unknown scenario cannot allocate a physical scene")
	driver.queue_free()
	print("TRIAL CONTRACT RESULTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
