extends "res://features/evaluator_virtual_cursor/scripts/virtual_cursor_driver.gd"
## V133 extends the existing clock, virtual owner, ray audit and safety monitor.
const BCATALOG="res://features/evaluator_virtual_cursor/resources/benchmark_eval_v133.json"
var onset_certificate:Dictionary={}
var fixture_receipt:Dictionary={}
var preparation_log:Array=[]
var pre_driver_usec:=0
var enrichment_usec:=0
var previous_observed_pose:=Transform3D.IDENTITY
var benchmark_environment_guard:Dictionary={}

func _additional_qualification_scenarios()->Array:
	return JSON.parse_string(FileAccess.get_file_as_string(BCATALOG)).scenarios

func _virtual_benchmark(value:Dictionary)->String:
	return "benchmark_eval_virtual_cursor_v1" if value.scenario_ids==["swing_catch_train"] else "benchmark_eval_v133"
func _virtual_tick_limit()->int:return 3072
func _virtual_scope(value:Dictionary)->String:
	if not OS.get_cmdline_user_args().has("--benchmark-qualification") or not str(value.get("campaign_id","")).begins_with("benchmark_v133_"):return "BENCHMARK_FLAG_CAMPAIGN_REQUIRED"
	if value.scenario_ids.size()!=1:return "BENCHMARK_SINGLE_WORLD_REQUIRED"
	var ids:Array=["swing_catch_train"]
	for d:Dictionary in _additional_qualification_scenarios():ids.append(d.id)
	if str(value.scenario_ids[0]) not in ids:return "UNKNOWN_BENCHMARK_SCENARIO"
	# The CLI applies the requested initial setting; no correction is made here.
	if get_window().size!=Vector2i(1024,576):return "ENVIRONMENT_NOT_COMPARABLE:CANONICAL_BACKING"
	if get_viewport().get_visible_rect().size!=Vector2(1920,1080):return "ENVIRONMENT_NOT_COMPARABLE:LOGICAL_VIEWPORT"
	return ""

func _configure_virtual_fixture(definition:Dictionary)->void:
	if definition.id=="swing_catch_train":super._configure_virtual_fixture(definition);return
	if str(definition.get("fixture",""))=="qualification_mirror_v1":
		fixture_receipt=Fixture.apply(app,definition)
		if not fixture_receipt.get("ok",false):_trace_integrity_reason="FIXTURE_CONSTRUCTION_FAILED:"+str(fixture_receipt.get("reason"))
	else:fixture_receipt={"ok":true,"fixture":"original_step","new_body_state_writes":false}
	previous_observed_pose=app.torso.global_transform

func start(value:Dictionary)->Dictionary:
	get_window().size_changed.connect(_window_changed)
	var result:Dictionary=await super.start(value)
	var Probe=load("res://features/evaluator_virtual_cursor/scripts/projection_probe.gd")
	if not _precise_json(str(value.output_dir).path_join("benchmark_audit.json"),Probe.encode({"frames":virtual_frames,"ticks":virtual_rows})) or not _precise_json(str(value.output_dir).path_join("benchmark_runtime.json"),Probe.encode(result.get("scenarios",[]))):
		result.status="BLOCKED_TRACE";result.reason="PRECISE_AUDIT_WRITE_FAILED"
	result["benchmark_version"]="benchmark_eval_v133_r1"
	result["input_lane"]=value.get("input_lane")
	result["benchmark_source_catalog_sha256"]=FileAccess.get_sha256(BCATALOG)
	result["world_creation_record"]=_world_creation.duplicate(true)
	result["benchmark_performance"]={"pre_driver_usec":pre_driver_usec,"post_enrichment_usec":enrichment_usec,"render_cadence":_phase_costs.duplicate(true),"scope":"Pre driver includes input and projection probe; post enrichment is read/copy only; existing trace cost separate. Per-row Performance.TIME_PHYSICS_PROCESS is engine monitor of prior physics processing, not a stopwatch of this current solver tick."}
	return result

func _precise_json(path:String,value:Variant)->bool:
	var temporary:String=path+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(value,"",true,true));file.close()
	return DirAccess.rename_absolute(temporary,path)==OK

func _window_changed()->void:
	if _scenario_enabled:_invalidate_input("ENVIRONMENT_NOT_COMPARABLE:RESIZE_DURING_EPISODE")

func _pre_tick(delta:float)->void:
	var start_usec:int=Time.get_ticks_usec()
	if _scenario_enabled and is_instance_valid(app):
		var w:Window=app.get_window();var vp:Viewport=app.get_viewport()
		var env:Dictionary={"size":w.size,"mode":w.mode,"position":w.position,"screen":w.current_screen,"visible":vp.get_visible_rect(),"canvas":vp.get_canvas_transform(),"global_canvas":vp.global_canvas_transform,"final":vp.get_final_transform(),"active_camera":vp.get_camera_3d().get_instance_id() if vp.get_camera_3d()!=null else 0,"camera_id":app.camera.get_instance_id(),"fov":app.camera.fov,"near":app.camera.near,"far":app.camera.far,"keep_aspect":app.camera.keep_aspect}
		if benchmark_environment_guard.is_empty():benchmark_environment_guard=env
		elif benchmark_environment_guard!=env:_invalidate_input("ENVIRONMENT_NOT_COMPARABLE:BENCHMARK_ENVIRONMENT_CHANGED");return
	super._pre_tick(delta)
	pre_driver_usec+=Time.get_ticks_usec()-start_usec

func _snapshot(phase:String)->Dictionary:
	var row:Dictionary=super._snapshot(phase)
	var start_usec:int=Time.get_ticks_usec()
	var movement:Dictionary=app.controller.intent_locomotion.data
	var ground:Dictionary=app.ground_motor.support_snapshot.duplicate(true)
	var support:Variant=ground.get("support")
	ground["support"]=Reader.identity(support) if support is PhysicsBody3D else {"key":"NONE","runtime_id":0}
	var load:=0.0
	for foot:Dictionary in row.feet:
		if foot.state in ["SUPPORTING","SLIDING"] and foot.support.key!="NONE":load+=maxf(0.0,float(foot.normal_force_n))
	row["benchmark_extra"]={"requested_input":movement.get("requested_input"),"applied_input":movement.get("movement_intent_local"),"applied_world":movement.get("movement_intent_world"),"planned_arm_rest_lengths":movement.get("planned_arm_rest_lengths"),"target_rates":movement.get("target_rates"),"target_accelerations":movement.get("target_accelerations"),"movement_block_reason":movement.get("movement_block_reason"),"actuator_saturated":movement.get("actuator_saturated"),"input_frame_id":movement.get("input_frame_id"),"input_timestamp":movement.get("input_timestamp"),"ground_state":ground,"motor_authority":app.ground_motor.motor_authority,"native_ground_authority":app.ground_motor.grounded or app.ground_motor.applied_force.length()>.0001 or app.ground_motor.applied_torque.length()>.0001,"foot_compressive_load_n":load,"twist_frame_valid":false,"twist_rad":null,"native_contact_reporting_limit":app.torso.max_contacts_reported}
	row["benchmark_performance"]={"engine_physics_process_monitor_s":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)}
	if phase=="post_control" and current_definition.get("id")!="swing_catch_train":
		row["benchmark_clearance"]=Fixture.audit_clearance(app,previous_observed_pose)
		previous_observed_pose=row.body.pose
		row.benchmark_extra["ground_clearance_status"]=row.benchmark_clearance.get("status","NOT_AUDITED")
	else:row.benchmark_extra["ground_clearance_status"]="NOT_APPLICABLE_PRE_OR_CATCH_GROUND_ALLOWED"
	enrichment_usec+=Time.get_ticks_usec()-start_usec
	if phase=="post_control" and _scenario_enabled:virtual_rows[-1]=row.duplicate(true)
	return row

func _valid_benchmark_support()->bool:
	return _row_support_valid(latest)

func _row_support_valid(row:Dictionary)->bool:
	if row.is_empty() or not row.support.valid or row.support.grounded or row.support.hybrid_owned:return false
	if row.benchmark_extra.native_ground_authority:return false
	if row.benchmark_extra.get("ground_clearance_status")!="CLEAR_QUERIED_SEGMENT":return false
	var effort:=0.0
	for hand:Dictionary in row.hands:
		if hand.state!="ATTACHED" or hand.support.key=="NONE":return false
		effort+=Vector3(hand.force_n).length()
	return effort>1.0

func _quiet_benchmark(definition:Dictionary)->bool:
	var first_tick:=-1
	var axis:=Vector3(definition.direction_world[0],definition.direction_world[1],definition.direction_world[2])
	for frame in int(5*hz):
		await _tick(1.0/hz)
		var valid:bool=_valid_benchmark_support() and _quiet_velocity_eligible(_relative_velocity(latest),Vector3(latest.body.angular_velocity_rad_s),axis,false)
		if definition.get("require_foot_load",false):valid=valid and float(latest.benchmark_extra.foot_compressive_load_n)>1.0
		if valid:
			if first_tick<0:first_tick=_scenario_tick
		else:first_tick=-1
		if _quiet_window_confirmed(first_tick,_scenario_tick,hz):
			preparation_log.append({"code":"QUIET_CERTIFIED","first_tick":first_tick,"confirmation_tick":_scenario_tick,"delta":_actual_delta,"snapshot":latest.duplicate(true)})
			return true
		if _hard_failed() or cancelled or not _trace_integrity_reason.is_empty():return false
	return false

func _accepted_onset_valid(definition:Dictionary)->bool:
	return _row_onset_valid(latest,definition)

func _row_onset_valid(row:Dictionary,definition:Dictionary)->bool:
	if not _row_support_valid(row):return false
	var axis:=Vector3(definition.direction_world[0],definition.direction_world[1],definition.direction_world[2])
	if definition.kind=="release_stop":return Vector2(row.command_accepted.accepted_input)==Vector2.ZERO and _motion_velocity_eligible(_relative_velocity(row).dot(axis),false)
	if Vector3(row.command_accepted.intent_world).dot(axis)<=.000001:return false
	if definition.get("require_foot_load",false) and float(row.benchmark_extra.foot_compressive_load_n)<=1:return false
	return _quiet_velocity_eligible(_relative_velocity(row),Vector3(row.body.angular_velocity_rad_s),axis,false)

func _raw_quiet_before(tick:int,definition:Dictionary)->bool:
	if definition.kind=="release_stop":return true
	var first_index:int=tick-2-int(ceil(.25*hz))
	if first_index<0:return false
	var onset:Dictionary=virtual_rows[tick-1]
	var axis:=Vector3(definition.direction_world[0],definition.direction_world[1],definition.direction_world[2])
	for i in range(first_index,tick-1):
		var row:Dictionary=virtual_rows[i]
		if not _row_support_valid(row) or not _quiet_velocity_eligible(_relative_velocity(row),Vector3(row.body.angular_velocity_rad_s),axis,false):return false
		for h in 2:
			if row.hands[h].anchor_runtime_id!=onset.hands[h].anchor_runtime_id:return false
		if definition.get("require_foot_load",false) and float(row.benchmark_extra.foot_compressive_load_n)<=1:return false
	return true

func _benchmark_prepare(definition:Dictionary)->String:
	for id in definition.acquisition_order:
		var p:Array=definition.contact_points[int(id)]
		if not await _grip(int(id),Vector3(p[0],p[1],p[2])):return "PREPARATION_ACQUISITION_FAILED"
	_set_keys(["contract"]);await _tick(float(definition.preload_s));_set_keys([])
	if not await _quiet_benchmark(definition):return "QUIET_ONSET_NOT_REACHED"
	if definition.kind=="release_stop":
		_set_keys(["bias_right"])
		var motion:=false
		for frame in int(2*hz):
			await _tick(1.0/hz)
			if _valid_benchmark_support() and _motion_velocity_eligible(_relative_velocity(latest).dot(Vector3.RIGHT),false):motion=true;break
		if not motion:return "DIRECTED_SPEED_ONSET_NOT_REACHED"
	_set_keys(definition.command)
	await _tick(1.0/hz)
	if not _accepted_onset_valid(definition) or not _raw_quiet_before(_scenario_tick,definition):return "ACCEPTED_ONSET_PRECONDITION_NOT_MET"
	onset_certificate={"onset_tick":_scenario_tick,"end_tick":null,"reason_code":"CERTIFIED_ACCEPTED_POST","certificate":virtual_rows[_scenario_tick-1].duplicate(true),"preparation_log":preparation_log.duplicate(true)}
	await _tick(float(definition.observe_s))
	_set_keys([])
	return ""

func _derive_runtime_measurement(definition:Dictionary)->Dictionary:
	if onset_certificate.get("onset_tick")==null:return {"signed_progress_m":null,"path3d_onset_to_end":null,"status":"PRECONDITION_NOT_MET"}
	var index:int=int(onset_certificate.onset_tick)-1
	var first:Dictionary=virtual_rows[index]
	var axis:=Vector3(definition.direction_world[0],definition.direction_world[1],definition.direction_world[2])
	var origin:Vector3=first.body.com_m;var previous:Vector3=origin;var distance:=0.0;var end_tick:=int(first.tick)
	var final_tick:int=int(first.tick)+int(round(float(definition.observe_s)*hz))
	for i in range(index+1,virtual_rows.size()):
		var row:Dictionary=virtual_rows[i]
		if int(row.tick)>final_tick:break
		var interrupted:bool=row.benchmark_extra.native_ground_authority or row.support.hybrid_owned or not row.support.valid or row.support.grounded
		interrupted=interrupted or row.benchmark_extra.get("ground_clearance_status")!="CLEAR_QUERIED_SEGMENT"
		for h in 2:interrupted=interrupted or row.hands[h].state!="ATTACHED" or row.hands[h].anchor_runtime_id!=first.hands[h].anchor_runtime_id or row.hands[h].support.key!=first.hands[h].support.key
		if interrupted:break
		var dx:float=float(previous.x)-float(row.body.com_m.x)
		var dy:float=float(previous.y)-float(row.body.com_m.y)
		var dz:float=float(previous.z)-float(row.body.com_m.z)
		distance+=sqrt(dx*dx+dy*dy+dz*dz);previous=row.body.com_m;end_tick=int(row.tick)
	var progress:float=(float(previous.x)-float(origin.x))*float(axis.x)+(float(previous.y)-float(origin.y))*float(axis.y)+(float(previous.z)-float(origin.z))*float(axis.z)
	return {"signed_progress_m":progress,"path3d_onset_to_end":distance,"onset_tick":int(first.tick),"end_tick":end_tick,"status":"RAW_AUTHORIZED_INTERVAL_ONLY","arithmetic":"binary64 differences of observed float32 components; full-precision JSON; independent Python formula"}

func _run_scenario(definition:Dictionary)->Dictionary:
	if definition.id=="swing_catch_train":return await super._run_scenario(definition)
	if not _retire_previous_world():_trace_integrity_reason="OLD_WORLD_NOT_RETIRED";return {"status":"BLOCKED_SETUP"}
	await _fresh(definition)
	if not _trace_integrity_reason.is_empty() or cancelled or _hard_failed() or not is_instance_valid(app):
		_scenario_enabled=false
		return {"id":definition.id,"status":"BLOCKED_SETUP","reason":_trace_integrity_reason,"invariants":violations.duplicate(true)}
	if not app.override_error.is_empty():
		_trace_integrity_reason="BASELINE_RESOURCE_INVALID:"+app.override_error;_scenario_enabled=false
		return {"id":definition.id,"status":"BLOCKED_SETUP","reason":_trace_integrity_reason,"invariants":violations.duplicate(true)}
	var reason:=""
	if manifest.virtual_mode=="REPLAY":
		while _scenario_tick<virtual_tape.frames.size() and not cancelled and not _hard_failed() and _trace_integrity_reason.is_empty():await _tick(1.0/hz)
		var frozen:Dictionary=virtual_tape.get("onset_certificate",{})
		var tick:Variant=frozen.get("onset_tick")
		if tick!=null and int(tick)<=virtual_rows.size():
			var actual:Dictionary=virtual_rows[int(tick)-1]
			if _row_onset_valid(actual,definition) and _raw_quiet_before(int(tick),definition):
				onset_certificate={"onset_tick":int(tick),"end_tick":null,"reason_code":"FROZEN_ONSET_INDEPENDENTLY_RECERTIFIED","certificate":actual.duplicate(true),"preparation_log":frozen.get("preparation_log",[])}
			else:
				reason="FROZEN_ONSET_PRECONDITION_NOT_MET"
				onset_certificate={"onset_tick":null,"end_tick":null,"reason_code":reason,"certificate":{},"reobserved_frozen_tick":int(tick),"reobserved_snapshot":actual.duplicate(true)}
		else:reason="NO_VALID_ONSET_IN_CAPTURE"
	else:reason=await _benchmark_prepare(definition)
	if onset_certificate.is_empty():onset_certificate={"onset_tick":null,"end_tick":null,"reason_code":reason,"certificate":{}}
	var runtime:Dictionary=_derive_runtime_measurement(definition)
	var result:Dictionary={"id":definition.id,"revision":definition.revision,"status":"valid_observation" if onset_certificate.onset_tick!=null else "precondition_not_met","reason":reason,"completed":false,"task_completion_policy":"Python typed metrics independently check positive authorized progress; finite observation is not success","invariants":violations.duplicate(true),"onset_certificate":onset_certificate.duplicate(true),"runtime_measurement":runtime,"fixture_receipt":fixture_receipt.duplicate(true),"preparation_log":preparation_log.duplicate(true),"world_creation":_world_creation.duplicate(true),"last_preparation_snapshot":latest.duplicate(true)}
	_scenario_enabled=false;measurement_active=false
	if is_instance_valid(app) and app.replay_input_provider!=null:
		app.finish_virtual_input();app.finish_virtual_input()
		cleanup_receipt={"provider_disabled":provider.state=="DISABLED","lab_provider_removed":app.replay_input_provider==null,"camera_live":not app.camera.virtual_physics_follow,"router_frame_removed":app.router.input_frame==null,"hand_held":app._held_grips(),"hands":[app.controller.get_hand_state(0),app.controller.get_hand_state(1)],"orbiting":app.orbiting}
	return result
