extends "res://features/evaluator_virtual_cursor/scripts/benchmark_driver.gd"
## V134 is opt-in and has new scenario/tape identities. No gameplay overrides.
const FCATALOG="res://features/evaluator_virtual_cursor/resources/fixture_feasibility_v134.json"
const FinalFixture=preload("res://features/evaluator_virtual_cursor/scripts/feasibility_fixture.gd")

func _additional_qualification_scenarios()->Array:
	return JSON.parse_string(FileAccess.get_file_as_string(FCATALOG)).scenarios

func _virtual_benchmark(value:Dictionary)->String:
	return "benchmark_eval_virtual_cursor_v1" if value.scenario_ids==["swing_catch_train"] else "fixture_feasibility_v134"

func _virtual_scope(value:Dictionary)->String:
	if not OS.get_cmdline_user_args().has("--fixture-feasibility") or not OS.get_cmdline_user_args().has("--benchmark-qualification"):return "FEASIBILITY_OPT_IN_REQUIRED"
	if value.get("campaign_id")!="fixture_feasibility_v134_r1" or value.get("pick_contract_version")!="1.3.4":return "FEASIBILITY_CAMPAIGN_CONTRACT_REQUIRED"
	if value.get("fixture_catalog_sha256")!=FileAccess.get_sha256(FCATALOG):return "FEASIBILITY_CATALOG_HASH"
	if value.scenario_ids.size()!=1:return "FEASIBILITY_SINGLE_WORLD_REQUIRED"
	var ids:Array=["swing_catch_train"]
	for d:Dictionary in _additional_qualification_scenarios():ids.append(d.id)
	if value.scenario_ids[0] not in ids:return "UNKNOWN_FEASIBILITY_SCENARIO"
	backing_initialization=Backing.initialize(get_window(),value.get("projection_config"))
	return "" if backing_initialization.reason.is_empty() else "ENVIRONMENT_NOT_COMPARABLE:"+str(backing_initialization.reason)

func _configure_virtual_fixture(definition:Dictionary)->void:
	if definition.id=="swing_catch_train":super._configure_virtual_fixture(definition);return
	fixture_receipt=FinalFixture.apply(app,definition)
	fixture_receipt["feasibility_revision"]=definition.fixture_revision
	fixture_receipt["feasibility_catalog_sha256"]=FileAccess.get_sha256(FCATALOG)
	fixture_receipt["original_geometry_unchanged"]=false
	if not fixture_receipt.get("ok",false):_trace_integrity_reason="FIXTURE_CONSTRUCTION_FAILED:"+str(fixture_receipt.get("reason"))
	previous_observed_pose=app.torso.global_transform

func _benchmark_prepare(definition:Dictionary)->String:
	for hand in definition.acquisition_order:
		var point:Array=definition.entry_contacts[int(hand)]
		if not await _grip(int(hand),Vector3(point[0],point[1],point[2])):return "ENTRY_ACQUISITION_FAILED"
	_set_keys(["contract"]);await _tick(float(definition.entry_pull_s));_set_keys([])
	# Move each real hand using normal release/request/reach/contact callbacks.
	for hand in definition.acquisition_order:
		_button(int(hand),false);await _tick(1.0/hz)
		var point:Array=definition.contact_points[int(hand)]
		if not await _grip(int(hand),Vector3(point[0],point[1],point[2])):return "HIGHER_REGRIP_ACQUISITION_FAILED"
	preparation_log.append({"code":"REAL_HIGHER_REGRIPS_COMPLETED","tick":_scenario_tick,"snapshot":latest.duplicate(true),"controller_state_writes":false})
	if not await _quiet_benchmark(definition):return "QUIET_ONSET_NOT_REACHED"
	if definition.kind=="release_stop":
		_set_keys(["bias_right"])
		var motion:=false
		for frame in int(2*hz):
			await _tick(1.0/hz)
			if _valid_benchmark_support() and _motion_velocity_eligible(_relative_velocity(latest).dot(Vector3.RIGHT),false):motion=true;break
		if not motion:return "DIRECTED_SPEED_ONSET_NOT_REACHED"
	_set_keys(definition.command);await _tick(1.0/hz)
	if not _accepted_onset_valid(definition) or not _raw_quiet_before(_scenario_tick,definition):return "ACCEPTED_ONSET_PRECONDITION_NOT_MET"
	onset_certificate={"onset_tick":_scenario_tick,"end_tick":null,"reason_code":"CERTIFIED_ACCEPTED_POST","certificate":virtual_rows[_scenario_tick-1].duplicate(true),"preparation_log":preparation_log.duplicate(true)}
	await _tick(float(definition.observe_s));_set_keys([])
	return ""

func start(value:Dictionary)->Dictionary:
	var result:Dictionary=await super.start(value)
	result["feasibility_catalog_sha256"]=FileAccess.get_sha256(FCATALOG)
	result["score_eligible"]=false
	return result
