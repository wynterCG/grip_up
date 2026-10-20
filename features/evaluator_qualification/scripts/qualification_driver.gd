extends "res://features/evaluator_reliability/scripts/reliability_driver.gd"
## R0 and A share world lifecycle, clock, readers, contacts and safety monitor.
## R0 never projects a historical world target through the live camera.
const Fixture=preload("res://features/evaluator_qualification/fixtures/qualification_fixture.gd")
const QCATALOG="res://features/evaluator_qualification/resources/benchmark_eval_v132.json"
var _audit:Array[Dictionary]=[]
var _requested:Dictionary={}
var _tape:Dictionary={}
var _q_initial:Dictionary={}
var _phase_costs:Dictionary={"pre_usec":0,"pre_calls":0,"post_usec":0,"post_calls":0,"render_frames":0,"render_delta_max_s":0.0,"tick_wall_gap_max_usec":0}
var _last_wall_usec:=0
var _fixture_receipt:Dictionary={}
var _bindings:Dictionary={}
var _previous_pose:=Transform3D.IDENTITY
var _last_clearance:Dictionary={}
var _preparation_log:Array=[]
var _emitted_observed:Dictionary={}

static func replay_sequence_supported(ids:Array,context:String)->bool:
	return ids==["swing_catch_train"] or (context=="sequence" and ids==["stop_release_v1","swing_catch_train"])

func _process(delta:float)->void:
	_phase_costs.render_frames+=1
	_phase_costs.render_delta_max_s=maxf(float(_phase_costs.render_delta_max_s),delta)

func _metadata(phase:String)->Dictionary:
	var row:Dictionary=super._metadata(phase)
	row.schema_version="1.3.2";row["lane"]="A_CONTEXT" if manifest.get("lane","A")=="R0" and current_definition.get("id","")!="swing_catch_train" else manifest.get("lane","A")
	return row

func _motion_event(position:Vector2,relative:Vector2)->void:
	var event:=InputEventMouseMotion.new()
	event.position=position;event.relative=relative;event.screen_relative=relative
	Input.parse_input_event(event.xformed_by(get_tree().root.get_final_transform()))
	Input.flush_buffered_events()

func _button_event(hand:int,pressed:bool,position:Vector2)->void:
	var event:=InputEventMouseButton.new()
	event.position=position;event.button_index=MOUSE_BUTTON_LEFT if hand==0 else MOUSE_BUTTON_RIGHT;event.pressed=pressed
	Input.parse_input_event(event.xformed_by(get_tree().root.get_final_transform()))
	Input.flush_buffered_events()

func _pre_tick(delta:float)->void:
	_global_tick+=1
	if not _scenario_enabled or not is_instance_valid(app):return
	var cost_start:int=Time.get_ticks_usec()
	if _scenario_tick==0:
		_audit.clear();_requested.clear();_q_initial.clear();_bindings.clear()
		for action in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:
			_bindings[action]=InputMap.action_get_events(action).map(func(event):return event.as_text())
	_actual_delta=delta
	if absf(delta-1.0/hz)>.0000001:_trace_integrity_reason="ACTUAL_DELTA_MISMATCH"
	_phase_context="pre_control";_tick_events.clear();_scenario_tick+=1
	var before:Dictionary=_snapshot("pre_control")
	if not initial_states.has(current_definition.id):initial_states[current_definition.id]=before.duplicate(true)
	if _q_initial.is_empty():_q_initial=before.duplicate(true)
	writer.sample(before)
	var replay:bool=manifest.get("lane","A")=="R0" and current_definition.id=="swing_catch_train"
	var gestures:Array=[]
	var cursor_before:Vector2=app.pointer
	if replay:
		if _scenario_tick>_tape.ticks.size():_trace_integrity_reason="TAPE_EXHAUSTED";return
		_requested=_tape.ticks[_scenario_tick-1].requested.duplicate(true)
		_desired_keys=_requested.keys.duplicate()
		gestures=_requested.gestures.duplicate(true)
		# JSON numbers are parsed as float by Godot; hand IDs remain typed integers
		# in the emitted event chronology and its independent integrity audit.
		for gesture:Dictionary in gestures:gesture.hand=int(gesture.hand)
		_requested.gestures=gestures.duplicate(true)
	else:
		for gesture:Dictionary in _emissions:
			var position:Vector2=app.camera.unproject_position(gesture.point) if gesture.point is Vector3 else app.pointer
			gestures.append({"hand":gesture.hand,"pressed":gesture.pressed,"cursor_px":[position.x,position.y],"motion":gesture.point is Vector3,"relative_px":[position.x-app.pointer.x,position.y-app.pointer.y]})
		_requested={"keys":_desired_keys.duplicate(),"gestures":gestures.duplicate(true),"cursor_before_px":[cursor_before.x,cursor_before.y],"camera_input":{"orbit_dx":0.0,"orbit_dy":0.0,"dolly":0.0}}
	for action in ["contract","extend","bias_left","bias_right"]:
		if action in _desired_keys:Input.action_press(action)
		else:Input.action_release(action)
	for gesture:Dictionary in gestures:
		var position:=Vector2(float(gesture.cursor_px[0]),float(gesture.cursor_px[1]))
		if bool(gesture.motion):_motion_event(position,Vector2(float(gesture.relative_px[0]),float(gesture.relative_px[1])))
		_latest_ray={"pointer":app.pointer,"camera_pose":app.camera.global_transform,"origin_m":app.camera.project_ray_origin(app.pointer),"direction":app.camera.project_ray_normal(app.pointer),"hand":gesture.hand,"pressed":gesture.pressed}
		var hit:Dictionary=app.targeting.candidate(app.camera,app.pointer,app.torso)
		if not hit.is_empty():
			_latest_ray.merge({"collider_key":Reader.identity(hit.collider).key,"collider_runtime_id":hit.collider.get_instance_id(),"material_local_point_m":hit.collider.to_local(hit.position),"material_local_normal":hit.collider.global_basis.inverse()*Vector3(hit.normal)},true)
		_button_event(int(gesture.hand),bool(gesture.pressed),position)
		_latest_ray["last_rejection"]=app.controller.last_rejection
		_event("REQUEST_SELECTED" if gesture.pressed else "INPUT_RELEASE",{"gesture":gesture,"ray":_latest_ray.duplicate(true),"emitted_tick":_scenario_tick})
	_emissions.clear()
	_keys=_desired_keys.duplicate()
	_last_command={"keys":_desired_keys.duplicate(),"hand_held":[Input.is_action_pressed("grip_left"),Input.is_action_pressed("grip_right")]}
	var viewport:Vector2=app.get_viewport().get_visible_rect().size
	_emitted_observed={"hand_held":_last_command.hand_held.duplicate(),"cursor_after_px":[app.pointer.x,app.pointer.y],"cursor_normalized":[app.pointer.x/viewport.x,app.pointer.y/viewport.y]}
	if not replay:_requested.merge(_emitted_observed.duplicate(true),true)
	_phase_context="control_callbacks"
	_phase_costs.pre_usec+=Time.get_ticks_usec()-cost_start;_phase_costs.pre_calls+=1

func _snapshot(phase:String)->Dictionary:
	var row:Dictionary=super._snapshot(phase)
	if phase=="post_control" and _fixture_receipt.get("ok",false):
		_last_clearance=Fixture.audit_clearance(app,_previous_pose)
		_previous_pose=row.body.pose
		row["clearance"]=_last_clearance.duplicate(true)
	if phase=="pre_control" and _scenario_tick==1:
		row["fixture_identity"]=[]
		for node in app.world.find_children("*","PhysicsBody3D",true,false):
			if node==app.torso:continue
			row.fixture_identity.append({"identity":Reader.identity(node),"layer":node.collision_layer,"mask":node.collision_mask})
	row["replay_requested"]=_requested.duplicate(true)
	row["emitted_observed"]=_emitted_observed.duplicate(true)
	if phase=="post_control" and _scenario_enabled:
		var effective:Array=[]
		for hand:Dictionary in row.hands:
			effective.append({"id":hand.id,"state":hand.state,"reason":hand.reason,"support_key":hand.support.key,"support_runtime_id":hand.support.runtime_id,"material_local_point_m":hand.material_local_point_m,"anchor_runtime_id":hand.anchor_runtime_id,"pending_active":hand.pending.get("active",false),"pending_in_reach":hand.pending.get("physical_in_reach",false),"force_n":hand.force_n,"shoulder_distance_m":hand.get("shoulder_distance_m"),"reach_m":hand.reach_m})
		_audit.append({"physics_tick":_scenario_tick,"physics_time_s":float(_scenario_tick)/hz,"delta_s":_actual_delta,"sample_phase":phase,"requested":_requested.duplicate(true),"accepted":row.command_accepted.duplicate(true),"effective":effective,"camera":row.camera.duplicate(true),"target":row.target.duplicate(true),"grounded":row.support.grounded,"support":row.support.duplicate(true),"feet":row.feet.duplicate(true),"body":{"com_m":row.body.get("com_m"),"linear_velocity_m_s":row.body.get("linear_velocity_m_s"),"angular_velocity_rad_s":row.body.get("angular_velocity_rad_s")},"force_budget":row.force_budget.duplicate(true)})
		_audit[-1]["clearance_status"]=_last_clearance.get("status","NOT_APPLICABLE")
		_audit[-1]["emitted_observed"]=_emitted_observed.duplicate(true)
		if _audit.size()>10240:_trace_integrity_reason="AUDIT_OVERFLOW"
	return row

func _post_tick(delta:float)->void:
	var started:int=Time.get_ticks_usec()
	if _scenario_enabled:
		if _last_wall_usec>0:_phase_costs.tick_wall_gap_max_usec=maxi(int(_phase_costs.tick_wall_gap_max_usec),started-_last_wall_usec)
		_last_wall_usec=started
	# Parent performs invariant/contact checks and emits the shared continuation.
	# Costs measured by parent before that continuation exclude subsequent work.
	var old_cost:int=_sample_cost_usec
	super._post_tick(delta)
	_phase_costs.post_usec+=_sample_cost_usec-old_cost;_phase_costs.post_calls+=1

func _run_scenario(definition:Dictionary)->Dictionary:
	if definition.get("qualification_group","")=="controls" and int(definition.get("hand_count",2))==1:
		var selection_key:String="%s:%d:%d:%s" % [manifest.engine_mode,hz,int(definition.retained_hand),"quiet" if definition.task=="low_energy" else "motion"]
		var selected:Variant=manifest.get("preparation_selection",{}).get(selection_key)
		if selected is String:
			definition=definition.duplicate(true);definition.preparation_id=selected
	var replay:bool=manifest.get("lane","A")=="R0" and definition.id=="swing_catch_train"
	var outcome:Dictionary
	if replay:
		if not _retire_previous_world():return {"id":definition.id,"status":"BLOCKED_SETUP","reason":"OLD_WORLD_NOT_RETIRED","completed":false}
		await _fresh(definition)
		while _scenario_tick<_tape.ticks.size() and not cancelled and not _hard_failed() and _trace_integrity_reason.is_empty():await _tick(1.0/hz)
		var catch_result:Dictionary=_catch_outcome()
		outcome={"id":definition.id,"revision":definition.revision,"status":"valid_observation" if catch_result.retained else "task_failed","completed":catch_result.retained,"reason":"" if catch_result.retained else "DESTINATION_NOT_RETAINED","invariants":violations.duplicate(true),"initial_state":initial_states.get(definition.id,{}),"world_creation":_world_creation.duplicate(true),"catch_native":catch_result,"reliability":{"measurement_ground_seen":_measurement_ground_seen,"last_snapshot":latest.duplicate(true)}}
		_scenario_enabled=false;measurement_active=false
	else:outcome=await super._run_scenario(definition)
	if definition.get("reliability_kind","")=="control":
		if outcome.get("status")=="precondition_not_met":
			outcome["transition"]={"kind":"release" if definition.task in ["stop_release","low_energy"] else "brake" if definition.task=="brake_counter" else "reverse" if definition.task in ["counter","reverse_command"] else "none","accepted_onset":false}
		outcome.transition["deadline_s"]=float(definition.observe_s)
		outcome["runtime_metrics_v132"]=preload("res://features/evaluator_qualification/scripts/qualification_metrics.gd").analyze(_audit,outcome.get("transition",{}),Vector3.RIGHT*float(definition.sign),hz,outcome.get("status")=="precondition_not_met")
	if definition.id=="swing_catch_train":outcome["catch_native"]=_catch_outcome()
	outcome["lane"]="R0" if replay else "A_CONTEXT" if manifest.get("lane","A")=="R0" else "A"
	var audit_path:String=str(manifest.output_dir).path_join(str(definition.id)+"_audit.json")
	var payload:Dictionary={"schema":"grip_up_input_audit_v132","lane":outcome.lane,"scenario_id":definition.id,"physics_hz":hz,"bindings":_bindings.duplicate(true),"initial_state":_q_initial.duplicate(true),"fixture_receipt":_fixture_receipt.duplicate(true),"ticks":_audit.duplicate(true)}
	if not TraceWriter.atomic_json(audit_path,payload):_trace_integrity_reason="AUDIT_WRITE_FAILED"
	outcome["audit"]={"path":audit_path,"sha256":FileAccess.get_sha256(audit_path),"ticks":_audit.size(),"scope":"compact per-tick input, target, contact, safety and native motion audit; full PRE/POST recorder controlled separately"}
	return outcome

func _catch_outcome()->Dictionary:
	var contact_tick:Variant=null
	var source_free_tick:Variant=null
	var retained_tick:Variant=null
	var anchor:=0
	var retained_start:=-1
	var retained_anchor:=0
	var loaded_destination:=false
	var request_distance:Variant=null
	var request_reach:Variant=null
	var ground_ticks:=0
	var foot_ticks:=0
	for row:Dictionary in _audit:
		if row.grounded:ground_ticks+=1
		for foot:Dictionary in row.feet:
			if foot.loaded:foot_ticks+=1;break
		var target:Dictionary=row.effective[1]
		for gesture:Dictionary in row.requested.gestures:
			if int(gesture.hand)==1 and gesture.pressed and request_distance==null:
				request_distance=target.shoulder_distance_m;request_reach=target.reach_m
		if target.state=="ATTACHED" and target.support_key=="catch":
			if contact_tick==null:contact_tick=row.physics_tick
			if row.effective[0].state=="FREE":
				if source_free_tick==null:source_free_tick=row.physics_tick
				if anchor!=int(target.anchor_runtime_id):anchor=int(target.anchor_runtime_id);retained_start=int(row.physics_tick)
				loaded_destination=loaded_destination or Vector3(target.force_n).length()>1
				if retained_tick==null and float(int(row.physics_tick)-retained_start)/hz>=.6:retained_tick=row.physics_tick;retained_anchor=anchor
			else:retained_start=-1;anchor=0
		else:retained_start=-1;anchor=0
	var beyond:bool=request_distance!=null and request_reach!=null and float(request_distance)>float(request_reach)+.02
	var final_retained:bool=retained_tick!=null and anchor==retained_anchor and anchor!=0 and loaded_destination
	return {"real_contact":contact_tick!=null,"retained":final_retained and beyond,"retained_at_end":final_retained,"beyond_static_reach_at_request":beyond,"request_distance_m":request_distance,"request_reach_m":request_reach,"expected_destination_key":"catch","actual_destination_load_admitted":loaded_destination,"contact_tick":contact_tick,"source_free_tick":source_free_tick,"retained_tick":retained_tick,"retained_duration_required_s":.6,"ground_ticks_whole_episode":ground_ticks,"foot_loaded_ticks_whole_episode":foot_ticks,"scope":"actual destination ATTACHED with same runtime material anchor and source FREE; includes B1/ground contributions"}

func _fresh(definition:Dictionary)->void:
	# First and subsequent worlds are born at the same callback boundary, after
	# the old subtrees have synchronously exited the tree/physics space. No world is advanced
	# during the startup frequency handshake.
	await post_completed
	_world_creation={"run_tick":_global_tick,"sample_phase":_phase_context,"actual_delta_s":_post_delta,"requested_delta_s":1.0/hz,"boundary":"post_completed_before_lab_construction","retired_worlds":_retired_worlds.duplicate(true),"old_subtrees_absent":true}
	super._reset_episode()
	current_definition=definition.duplicate(true);_scenario_tick=0;_previous_hands.clear();_retained.clear();_last_command.clear();_latest_ray.clear();latest.clear()
	_measurement_ground_seen=false;_measurement_support_lost=false
	_accepted_previous=null;_pending_transition.clear();_tick_events.clear()
	_measured_anchors.clear()
	app=BaselineLab.new();app.override_loader=loader;app.trial_candidate=candidate
	get_tree().root.add_child(app);get_tree().current_scene=app
	_baseline_profile_ok=_baseline_profile_ok and app.input_profile==2
	app._open_intent_arena(int(definition.arena),true)
	if definition.get("fixture","")=="existing_mastery_segment":
		_course=Course.new();add_child(_course);_course.apply_segment(app,int(definition.segment))
	app._set_movement_allocation(0);app._set_intent_aware_feet(false)
	app._set_physical_feet(bool(definition.get("physical_feet",true)))
	app._set_distant_targeting(bool(definition.get("policy",{}).get("persistent_target",false)))
	app._set_locomotion_diagnostics(_observer_on);app.transfer_diagnostics_enabled=true;app._apply_independent_settings()
	app.won=true;app.settings.hide()
	app.controller.sample_ready.connect(_sample);app.controller.transfer_event.connect(_transfer)
	for entry:Dictionary in app.installs:_all_installs_pre_step=_all_installs_pre_step and bool(entry.before_first_step)
	_fixture_receipt={};_last_clearance.clear();_preparation_log.clear()
	if definition.get("fixture","") in ["qualification_mirror_v1","qualification_onehand_v1"]:
		_fixture_receipt=Fixture.apply(app,definition)
		if not _fixture_receipt.get("ok",false):_trace_integrity_reason="FIXTURE_CONSTRUCTION_FAILED:"+str(_fixture_receipt.get("reason","UNKNOWN"))
	_previous_pose=app.torso.global_transform
	_scenario_enabled=true
	await _tick(float(definition.get("warmup_s",.45)))

func start(value:Dictionary)->Dictionary:
	if running:return {"schema_version":"1.3.2","status":"BLOCKED_SETUP","reason":"DRIVER_ALREADY_RUNNING"}
	manifest=value.duplicate(true);candidate=manifest.get("baseline_candidate",{}).duplicate(true)
	var checked:Dictionary=loader.validate(candidate)
	if not checked.ok:return {"schema_version":"1.3.2","status":"BLOCKED_SETUP","reason":checked.reason}
	if FileAccess.get_sha256(OS.get_executable_path())!=candidate.engine_identity.sha256 or not str(candidate.engine_identity.version).contains(str(Engine.get_version_info().hash).substr(0,9)):return {"status":"BLOCKED_SETUP","reason":"ENGINE_IDENTITY_MISMATCH"}
	for knob:Dictionary in loader.space.parameters:
		if float(candidate.parameter_overrides[knob.id])!=float(knob.baseline):return {"status":"BLOCKED_SETUP","reason":"BASELINE_ONLY_NO_OVERRIDES"}
	for path in manifest.expected_source_hashes:
		if FileAccess.get_sha256("res://"+path)!=manifest.expected_source_hashes[path]:return {"status":"BLOCKED_SETUP","reason":"SOURCE_HASH_MISMATCH:"+path}
	var override_identity:String=FileAccess.get_sha256("res://override.cfg") if FileAccess.file_exists("res://override.cfg") else "ABSENT"
	if override_identity!=manifest.get("local_override_sha256",""):return {"status":"BLOCKED_SETUP","reason":"LOCAL_OVERRIDE_MISMATCH"}
	hz=int(manifest.physics_hz)
	if hz not in [60,120]:return {"status":"BLOCKED_SETUP","reason":"PHYSICS_HZ"}
	_observer_on=bool(manifest.get("existing_observer_enabled",true))
	if not _observer_on and (manifest.scenario_ids.size()!=1 or manifest.scenario_ids[0] not in ["swing_catch_train","catch_isolated_v1"]):return {"status":"BLOCKED_SETUP","reason":"FULL_OBSERVER_OFF_REFERENCE_IS_CATCH_ONLY"}
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(QCATALOG))
	var definitions:Dictionary={}
	for item:Dictionary in catalog.scenarios:definitions[item.id]=item
	var old_catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(TRAIN))
	for item:Dictionary in old_catalog.scenarios:definitions[item.id]=item
	var isolated:Dictionary=definitions.swing_catch_train.duplicate(true);isolated.id="catch_isolated_v1";isolated.implementation_id="swing_catch_train";isolated.revision=1
	definitions[isolated.id]=isolated
	for id in manifest.scenario_ids:
		if not definitions.has(id):return {"status":"BLOCKED_SETUP","reason":"UNKNOWN_SCENARIO:"+str(id)}
	if manifest.get("lane","A") not in ["A","R0"]:return {"status":"BLOCKED_SETUP","reason":"LANE"}
	if manifest.get("lane","A")=="R0":
		var valid_replay_sequence:bool=replay_sequence_supported(manifest.scenario_ids,str(manifest.get("context","")))
		if not valid_replay_sequence:return {"status":"BLOCKED_SETUP","reason":"UNSUPPORTED_R0_SCENARIO_CONTEXT"}
		var tape_path:String=str(manifest.get("tape_path",""))
		if FileAccess.get_sha256(tape_path)!=manifest.get("tape_file_sha256",""):return {"status":"BLOCKED_SETUP","reason":"TAPE_HASH"}
		var parsed_tape:Variant=JSON.parse_string(FileAccess.get_file_as_string(tape_path))
		if not parsed_tape is Dictionary:return {"status":"BLOCKED_SETUP","reason":"TAPE_JSON"}
		_tape=parsed_tape
		if _tape.get("schema","")!="grip_up_replay_v132" or int(_tape.get("physics_hz",0))!=hz:return {"status":"BLOCKED_SETUP","reason":"TAPE_SCHEMA_HZ"}
		if _tape.get("engine_build",{})!=manifest.engine_identity or _tape.get("source_hashes",{})!=manifest.expected_source_hashes:return {"status":"BLOCKED_SETUP","reason":"TAPE_SOURCE_ENGINE_IDENTITY"}
		if not _tape.get("ticks") is Array or _tape.ticks.is_empty() or _tape.ticks.size()>10240:return {"status":"BLOCKED_SETUP","reason":"TAPE_TICK_COUNT"}
		for index in _tape.ticks.size():
			var tick:Dictionary=_tape.ticks[index]
			if int(tick.get("physics_tick",-1))!=index+1 or tick.get("sample_phase","")!="post_control" or absf(float(tick.get("delta_s",0))-1.0/hz)>.0000001:return {"status":"BLOCKED_SETUP","reason":"TAPE_TICK_CLOCK_PHASE"}
			if tick.get("requested",{}).get("camera_input",{})!={"orbit_dx":0.0,"orbit_dy":0.0,"dolly":0.0}:return {"status":"BLOCKED_SETUP","reason":"UNSUPPORTED_TAPE_CAMERA_INPUT"}
	if not writer.open_at(str(manifest.output_dir),bool(manifest.recorder_enabled)):return {"status":"BLOCKED_TRACE","reason":writer.error}
	var previous_hz:int=Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second=hz;_clock_start=Time.get_ticks_msec();running=true
	if not await _settle_startup_clock():
		Engine.physics_ticks_per_second=previous_hz;running=false
		return {"schema_version":"1.3.2","run_id":manifest.run_id,"status":"BLOCKED_SETUP","reason":_clock_receipt.get("reason","CLOCK_NOT_SETTLED"),"clock_startup":_clock_receipt.duplicate(true),"restoration":{"physics_hz_restored":Engine.physics_ticks_per_second==previous_hz},"trace":writer.close()}
	var results:Array=[]
	for id in manifest.scenario_ids:
		results.append(await _run_scenario(definitions[id]))
		if cancelled or _hard_failed() or not _trace_integrity_reason.is_empty():break
	_scenario_enabled=false;measurement_active=false;super._release_all()
	var restoration:Dictionary=loader.restore()
	if is_instance_valid(app):app._set_input_profile(2);_retire_world_node(app);app=null
	if is_instance_valid(_course):_retire_world_node(_course);_course=null
	Engine.physics_ticks_per_second=previous_hz
	var sources_ok:=true
	for path in manifest.expected_source_hashes:sources_ok=sources_ok and FileAccess.get_sha256("res://"+path)==manifest.expected_source_hashes[path]
	var trace_result:Dictionary=writer.close()
	TraceWriter.atomic_json(str(manifest.output_dir).path_join("initial_state.json"),initial_states)
	running=false
	var clock_receipt:Dictionary=_clock_receipt.duplicate(true)
	var result:Dictionary={"schema_version":"1.3.2","run_id":manifest.run_id,"status":"BLOCKED_TRACE" if not trace_result.error.is_empty() or not sources_ok or not _trace_integrity_reason.is_empty() else "timed_out" if cancelled else "failed_invariant" if _hard_failed() else "completed","reason":_trace_integrity_reason,"data_kind":"automated_headless" if manifest.engine_mode=="headless" else "automated_rendered_scripted","engine_mode":manifest.engine_mode,"physics_hz":hz,"scenarios":results,"restoration":{"resources":restoration,"physics_hz_restored":Engine.physics_ticks_per_second==previous_hz,"startup_profile_preserved":_baseline_profile_ok,"installs_pre_step":_all_installs_pre_step,"sources_after_unchanged":sources_ok},"trace":trace_result,"clock_startup":clock_receipt,"instrumentation":{"cost_usec":_sample_cost_usec,"sample_calls":_sample_calls,"cost_scope":"post-probe snapshot, event derivation and JSON serialization only; excludes pre-probe, input emission, original observers and engine. External process timing needed for total overhead.","recorder_enabled":writer.enabled,"existing_observer_enabled":_observer_on,"observer_off_scope":"recorder OFF is not full gameplay-observer OFF"},"environment":{"engine":Engine.get_version_info(),"engine_binary_sha256":FileAccess.get_sha256(OS.get_executable_path()),"physics_backend":ProjectSettings.get_setting("physics/3d/physics_engine"),"max_physics_steps_per_frame":Engine.max_physics_steps_per_frame,"time_scale":Engine.time_scale,"physics_interpolation":ProjectSettings.get_setting("physics/common/physics_interpolation"),"render_max_fps":Engine.max_fps,"code_commit":manifest.get("code_commit"),"dirty_tree":manifest.get("dirty_tree"),"expected_source_hashes":manifest.expected_source_hashes,"catalog_sha256":FileAccess.get_sha256(QCATALOG)}}
	result["qualification_instrumentation"]=_phase_costs.duplicate(true)
	result.qualification_instrumentation.post_usec=_sample_cost_usec
	result.qualification_instrumentation.post_calls=_sample_calls
	result["lane"]=manifest.get("lane","A")
	result["tape_file_sha256"]=manifest.get("tape_file_sha256")
	result["backlog_scope"]="Pending physics-step backlog is not exposed by the runtime API used; actual delta, tick wall gaps and render cadence are measured separately."
	result["local_override_sha256"]=FileAccess.get_sha256("res://override.cfg") if FileAccess.file_exists("res://override.cfg") else "ABSENT"
	return result

func _valid_support(required:int)->bool:
	if not super._valid_support(required):return false
	if not _fixture_receipt.get("ok",false):return true
	if _last_clearance.get("status","")!="CLEAR_QUERIED_SEGMENT":return false
	if not _last_clearance.get("native_ground_contacts",[]).is_empty():return false
	if required==1:
		var other:int=1-int(current_definition.get("retained_hand",0))
		var hand:Dictionary=latest.hands[other]
		if hand.state!="FREE" or Vector3(hand.force_n).length()>.000001 or int(hand.anchor_runtime_id)!=0:return false
	return true

func _prepare_script(definition:Dictionary)->bool:
	var registry:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://features/evaluator_qualification/resources/preparation_registry_v132_r1.json"))
	var script:Dictionary=registry.two_hand_standard if definition.preparation_id=="TWO_HAND_STANDARD_R1" else {}
	for option:Dictionary in registry.scripts:
		if option.id==definition.preparation_id:script=option
	if script.is_empty():return false
	for step:Dictionary in script.steps:
		var hand:int=int(definition.get("retained_hand",0)) if step.get("hand","retained")=="retained" else 1-int(definition.get("retained_hand",0))
		var start_tick:int=_scenario_tick
		var success:=true
		if step.op=="acquire":success=await _grip(hand,app.level.transfer_points[hand])
		elif step.op=="hold_keys":_set_keys(step.keys);await _tick(float(step.duration_s))
		elif step.op=="release":
			if step.has("held_keys"):_set_keys(step.held_keys)
			_button(hand,false)
			success=false
			for frame in int(round(float(step.max_wait_s)*hz)):
				await _tick(1.0/hz)
				var actual:Dictionary=latest.hands[hand]
				if actual.state=="FREE" and int(actual.anchor_runtime_id)==0 and Vector3(actual.force_n).length()<=.000001:success=true;break
		else:success=false
		_preparation_log.append({"script_id":script.id,"step":step.duplicate(true),"resolved_hand":hand,"start_tick":start_tick,"end_tick":_scenario_tick,"success":success,"snapshot":latest.duplicate(true)})
		if not success or cancelled or _hard_failed():return false
	return true

func _control_case(definition:Dictionary)->Dictionary:
	if not definition.has("preparation_id"):return await super._control_case(definition)
	await _fresh(definition)
	if not app.override_error.is_empty():
		return {"id":definition.id,"revision":definition.revision,"status":"BLOCKED_SETUP","completed":false,"reason":app.override_error,"scope":"Original baseline Resource verification failed; no acquisition or preparation attempted"}
	var required:int=int(definition.hand_count)
	var task:String=definition.task
	var reason:=""
	var precondition_failure_detail:=""
	var clearance_interrupted_tick:Variant=null
	if not await _prepare_script(definition):reason="PREPARATION_ACQUISITION_OR_RELEASE_FAILED"
	var axis:=Vector3.RIGHT*float(definition.sign)
	if reason.is_empty() and not await _settled(required,axis,task=="low_energy"):reason="PRECONDITION_NOT_MET"
	var preparation:Dictionary=latest.duplicate(true)
	if reason.is_empty() and task in ["counter","stop_release","brake_counter","reverse_command"]:
		var opposite:bool=task=="counter"
		var drive_sign:float=-float(definition.sign) if opposite else float(definition.sign)
		_set_keys(["bias_right" if drive_sign>0 else "bias_left"])
		var ready:=false
		for frame in int(2*hz):
			await _tick(1.0/hz)
			var speed:float=_relative_velocity(latest).dot(axis)
			var eligible:bool=_motion_velocity_eligible(speed,opposite)
			if eligible and _valid_support(required):ready=true;break
			if cancelled or _hard_failed():break
		if not ready:reason="PRECONDITION_NOT_MET"
		preparation=latest.duplicate(true)
	var transition:Dictionary={"kind":"none","tick":_scenario_tick+1,"physics_time_s":float(_scenario_tick+1)/hz}
	if reason.is_empty():
		measurement_active=false;_measurement_ground_seen=false;_measurement_support_lost=false
		var command:Array=[]
		if task in ["clean","counter"]:command=["bias_right" if float(definition.sign)>0 else "bias_left"]
		elif task in ["brake_counter","reverse_command"]:command=["bias_left" if float(definition.sign)>0 else "bias_right"]
		transition.kind="release" if task in ["stop_release","low_energy"] else "brake" if task=="brake_counter" else "reverse" if task in ["counter","reverse_command"] else "none"
		var expected:=Vector2(float("bias_right" in command)-float("bias_left" in command),float("contract" in command)-float("extend" in command)).limit_length(1)
		_pending_transition={"kind":transition.kind,"requested_tick":_scenario_tick+1,"expected_input":expected}
		_set_keys(command);_event("MEASUREMENT_BEGIN",{"transition":transition,"direction_world":axis,"snapshot":preparation.duplicate(true)})
		var seconds:float=float(definition.observe_s)
		for frame in int(round(seconds*hz))+1:
			if task=="brake_counter" and frame==int(round(.5*hz)):_set_keys([])
			await _tick(1.0/hz)
			if _last_clearance.get("status","")!="CLEAR_QUERIED_SEGMENT" and clearance_interrupted_tick==null:clearance_interrupted_tick=_scenario_tick
			if cancelled or _hard_failed():break
		if _pending_transition.has("accepted_tick"):
			transition.tick=_pending_transition.accepted_tick;transition.physics_time_s=_pending_transition.accepted_time_s
			transition["requested_tick"]=_pending_transition.requested_tick
			preparation=_pending_transition.accepted_snapshot.duplicate(true)
			var attached_at_onset:=0
			var effort_at_onset:=0.0
			for hand:Dictionary in preparation.hands:
				if hand.state=="ATTACHED":attached_at_onset+=1;effort_at_onset+=Vector3(hand.force_n).length()
			if attached_at_onset!=required or effort_at_onset<=1:reason="PRECONDITION_NOT_MET";precondition_failure_detail="ACTUAL_HAND_SUPPORT_COUNT_OR_LOAD_INVALID_AT_ONSET"
			if preparation.support.grounded or not preparation.support.valid or preparation.support.hybrid_owned or Vector3(preparation.force_budget.ground_force_n).length()>.0001 or Vector3(preparation.force_budget.ground_torque_nm).length()>.0001 or preparation.get("clearance",{}).get("status","")!="CLEAR_QUERIED_SEGMENT":reason="PRECONDITION_NOT_MET";precondition_failure_detail="ACCEPTED_ONSET_SUPPORT_OR_CLEARANCE_INVALID"
			if required==1:
				var other:int=1-int(definition.retained_hand)
				if preparation.hands[other].state!="FREE" or int(preparation.hands[other].anchor_runtime_id)!=0 or Vector3(preparation.hands[other].force_n).length()>.000001:reason="PRECONDITION_NOT_MET";precondition_failure_detail="RELEASED_HAND_STILL_HAS_AUTHORITY"
			if task in ["stop_release","brake_counter","reverse_command"] and not _motion_velocity_eligible(_relative_velocity(preparation).dot(axis),false):reason="PRECONDITION_NOT_MET";precondition_failure_detail="DIRECTED_SPEED_OUTSIDE_BAND_AT_ACCEPTED_ONSET"
			if task=="counter" and not _motion_velocity_eligible(_relative_velocity(preparation).dot(axis),true):reason="PRECONDITION_NOT_MET";precondition_failure_detail="COUNTER_SPEED_OUTSIDE_BAND_AT_ACCEPTED_ONSET"
			if task=="clean" and not _quiet_velocity_eligible(_relative_velocity(preparation),Vector3(preparation.body.angular_velocity_rad_s),axis,false):reason="PRECONDITION_NOT_MET";precondition_failure_detail="CLEAN_ONSET_OUTSIDE_QUIET_BAND"
			if task=="low_energy" and not _quiet_velocity_eligible(_relative_velocity(preparation),Vector3(preparation.body.angular_velocity_rad_s),axis,true):
				reason="PRECONDITION_NOT_MET";precondition_failure_detail="LOW_ENERGY_ACCEPTED_STATE_OUTSIDE_BAND"
		else:reason="INPUT_NOT_ACCEPTED"
	_set_keys([])
	var valid:bool=reason.is_empty()
	if valid and _measurement_ground_seen:reason="INVALID_SUPPORT_STATE";valid=false
	if valid and _measurement_support_lost:reason="SUPPORT_LOST";valid=false
	if valid and clearance_interrupted_tick!=null:reason="CLEARANCE_NOT_CERTIFIED";valid=false
	var displacement:Variant=null
	if preparation.get("body",{}).get("com_m") is Vector3 and latest.get("body",{}).get("com_m") is Vector3:displacement=(Vector3(latest.body.com_m)-Vector3(preparation.body.com_m)).dot(axis)
	var result:Dictionary={"id":definition.id,"revision":definition.revision,"status":"valid_observation" if valid else "precondition_not_met" if reason.begins_with("PRE") else "interrupted","completed":valid,"reason":reason,"scope":"measurement validity separate from positive performance; natural attachments and B1 foot contributions","invariants":violations.duplicate(true),"metrics":{"useful_displacement_m":displacement},"capture":capture.duplicate(true),"precondition_snapshot":preparation,"transition":transition,"direction_world":axis,"observation_s":definition.observe_s,"eligible_hand_count":required,"precondition_failure_detail":precondition_failure_detail}
	result["preparation_script_id"]=definition.preparation_id
	result["preparation_log"]=_preparation_log.duplicate(true)
	result["fixture_receipt"]=_fixture_receipt.duplicate(true)
	result["clearance_last"]=_last_clearance.duplicate(true)
	result["clearance_interrupted_tick"]=clearance_interrupted_tick
	if definition.get("qualification_group","")=="preparation":
		# One bounded script attempt checks the quiet onset first, then the same
		# declared directional preparation used by stop/brake/reverse. No reset,
		# timing search, body correction or second acquisition attempt.
		measurement_active=false;_pending_transition.clear()
		result["screen_quiet_eligible"]=valid
		var motion_ready:=false
		var motion_reason:="DIRECTED_SPEED_NOT_REACHED"
		_set_keys(["bias_right" if float(definition.sign)>0 else "bias_left"])
		for frame in int(2*hz):
			await _tick(1.0/hz)
			if _motion_velocity_eligible(_relative_velocity(latest).dot(axis),false) and _valid_support(required):motion_ready=true;break
			if cancelled or _hard_failed():break
		if motion_ready:
			_set_keys([]);await _tick(1.0/hz)
			motion_ready=_motion_velocity_eligible(_relative_velocity(latest).dot(axis),false) and _valid_support(required) and Vector2(latest.command_accepted.accepted_input)==Vector2.ZERO
			motion_reason="" if motion_ready else "ACCEPTED_NEUTRAL_ONSET_NOT_ELIGIBLE"
		result["screen_motion_eligible"]=motion_ready
		if not valid:result.screen_motion_eligible=false;motion_reason="QUIET_PREPARATION_FAILED_BEFORE_MOTION_SUFFIX"
		result["screen_motion_reason"]=motion_reason
		result["screen_motion_snapshot"]=latest.duplicate(true)
		_set_keys([])
	return result
