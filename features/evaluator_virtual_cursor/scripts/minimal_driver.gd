extends "res://features/evaluator_virtual_cursor/scripts/feasibility_driver.gd"
const MCATALOG="res://features/evaluator_virtual_cursor/resources/benchmark_minimal_v135_r1.json"
const TCATALOG="res://features/evaluator_virtual_cursor/resources/minimal_transfer_v135.json"
const MinimalLoader=preload("res://features/evaluator_virtual_cursor/scripts/minimal_override_loader.gd")
const MinimalLab=preload("res://features/evaluator_virtual_cursor/scripts/minimal_lab.gd")
const ADMITTED_CAMPAIGNS=["minimal_v135_r4","minimal_v135a_r1"]

func _init()->void:loader=MinimalLoader.new()
func _make_virtual_lab():return MinimalLab.new()
func _seal_virtual_lab()->String:
	return loader.seal_pre_step(app.controller,{"physical_feet":true,"allow_out_of_reach_grip_targets":true},"MEASURED_WORLD_PRE_STEP")
func _candidate_policy_error()->String:
	return "" if manifest.get("campaign_id") in ADMITTED_CAMPAIGNS and OS.get_cmdline_user_args().has("--minimal-tuning") else "MINIMAL_OPT_IN_REQUIRED"
func _frozen_parameters_valid()->bool:
	return super._frozen_parameters_valid() and loader.exact_effective_valid(app.controller)
func _additional_qualification_scenarios()->Array:
	var definitions:Array=JSON.parse_string(FileAccess.get_file_as_string(MCATALOG)).scenarios
	definitions.append_array(JSON.parse_string(FileAccess.get_file_as_string(TCATALOG)).scenarios)
	return definitions
func _virtual_benchmark(value:Dictionary)->String:
	if value.scenario_ids==["swing_catch_train"]:return "benchmark_eval_virtual_cursor_v1"
	return "fixture_feasibility_v134" if value.get("historical_feasibility_tape",false) else "benchmark_minimal_v135_r1"
func _virtual_scope(value:Dictionary)->String:
	if not OS.get_cmdline_user_args().has("--minimal-tuning") or not OS.get_cmdline_user_args().has("--benchmark-qualification"):return "MINIMAL_OPT_IN_REQUIRED"
	if value.get("campaign_id") not in ADMITTED_CAMPAIGNS or value.get("pick_contract_version")!="1.3.4":return "MINIMAL_CAMPAIGN_CONTRACT_REQUIRED"
	if value.get("minimal_catalog_sha256")!=FileAccess.get_sha256(MCATALOG) or value.get("transfer_catalog_sha256")!=FileAccess.get_sha256(TCATALOG):return "MINIMAL_CATALOG_HASH"
	if value.scenario_ids.size()!=1:return "MINIMAL_SINGLE_WORLD_REQUIRED"
	var ids:Array=["swing_catch_train"]
	for definition:Dictionary in _additional_qualification_scenarios():ids.append(definition.id)
	if value.scenario_ids[0] not in ids:return "UNKNOWN_MINIMAL_SCENARIO"
	if value.get("historical_feasibility_tape",false) and (value.get("phase")!="finalist_protected" or value.scenario_ids[0] not in ["two_hand_release_stop_v134_r2","asymmetric_pull_clean_v134_r2","lateral_clean_left_v134_r2"]):return "HISTORICAL_TAPE_NOT_PROTECTED_CAPABILITY"
	if value.get("phase") in ["sensitivity","random","tpe"] and value.scenario_ids[0] not in ["vertical_pull_clean_v134_r2","lateral_clean_right_v134_r2"]:return "NONTRAINING_TASK_IN_SEARCH"
	backing_initialization=Backing.initialize(get_window(),value.get("projection_config"))
	return "" if backing_initialization.reason.is_empty() else "ENVIRONMENT_NOT_COMPARABLE:"+str(backing_initialization.reason)
func start(value:Dictionary)->Dictionary:
	var result:Dictionary=await super.start(value)
	result["benchmark_version"]="benchmark_minimal_v135_r1"
	result["minimal_catalog_sha256"]=FileAccess.get_sha256(MCATALOG)
	result["parameter_installs"]=loader.receipts.duplicate(true)
	if loader.restoration_failed:result.status="failed_invariant";result.reason="EXACT_RESOURCE_RESTORE_FAILED"
	return result
