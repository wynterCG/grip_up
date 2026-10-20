extends "res://features/auto_tuning_lab/scripts/optimization_trial_driver.gd"
## One interpreter for headless and rendered. Input is emitted at priority -100;
## observations/continuations occur at +100, never in the render callback.
signal post_completed
const Probe=preload("res://features/evaluator_reliability/scripts/tick_probe.gd")
const Reader=preload("res://features/evaluator_reliability/scripts/physics_snapshot.gd")
const TraceWriter=preload("res://features/evaluator_reliability/scripts/reliability_trace.gd")
const BaselineLab=preload("res://features/evaluator_reliability/scripts/baseline_lab.gd")
const CATALOG="res://features/evaluator_reliability/resources/benchmark_eval_v131.json"
var manifest:Dictionary={}
var writer=TraceWriter.new()
var reader=Reader.new()
var pre_probe:Node
var post_probe:Node
var current_definition:Dictionary={}
var measurement_active:=false
var latest:Dictionary={}
var initial_states:Dictionary={}
var _scenario_tick:=0
var _global_tick:=0
var _scenario_enabled:=false
var _desired_keys:Array=[]
var _pending_pointer:Variant=null
var _emissions:Array[Dictionary]=[]
var _previous_hands:Array=[]
var _retained:Dictionary={}
var _event_serial:=0
var _last_command:Dictionary={}
var _latest_ray:Dictionary={}
var _decisions:Dictionary={}
var _sample_cost_usec:=0
var _sample_calls:=0
var _measurement_ground_seen:=false
var _measurement_support_lost:=false
var _observer_on:=true
var _tick_events:Array[Dictionary]=[]
var _phase_context:="outside_tick"
var _accepted_previous:Variant=null
var _pending_transition:Dictionary={}
var _actual_delta:=0.0
var _trace_integrity_reason:=""
var _measured_anchors:Dictionary={}

func _ready()->void:
	pre_probe=Probe.new();pre_probe.process_physics_priority=-100;add_child(pre_probe);pre_probe.tick.connect(_pre_tick)
	post_probe=Probe.new();post_probe.process_physics_priority=100;add_child(post_probe);post_probe.tick.connect(_post_tick)

func _metadata(phase:String)->Dictionary:
	return {"schema_version":"1.3.1","run_id":manifest.get("run_id",""),"scenario_id":current_definition.get("id","SETUP"),"scenario_revision":current_definition.get("revision",1),"engine_mode":manifest.get("engine_mode","headless"),"physics_hz":hz,"tick":_scenario_tick,"episode_tick":_scenario_tick,"run_tick":_global_tick,"physics_time_s":float(_scenario_tick)/hz,"delta_s":_actual_delta,"requested_delta_s":1.0/hz,"sample_phase":phase}

func _event(code:String,extra:Dictionary={})->void:
	_event_serial+=1
	var value:Dictionary=_metadata(_phase_context)
	value.merge({"event_id":_event_serial,"code":code,"event_code":code},true);value.merge(extra,true)
	writer.event(value)
	_tick_events.append(value.duplicate(true))

func _set_keys(keys:Array)->void:
	_desired_keys=keys.duplicate()
	_decisions={"policy_version":"shared_physics_tick_v1","keys":keys.duplicate(),"requested_after_tick":_scenario_tick}
	if is_instance_valid(app):_decisions.merge({"observed_body_velocity":app.torso.linear_velocity,"observed_spin":app.torso.angular_velocity,"controller_step":app.controller._step},true)

func _aim(point:Vector3)->void:_pending_pointer=point
func _button(id:int,down:bool)->void:
	_emissions.append({"hand":id,"pressed":down,"point":_pending_pointer,"requested_after_tick":_scenario_tick})

func _pre_tick(delta:float)->void:
	_global_tick+=1
	if not _scenario_enabled or not is_instance_valid(app):return
	_actual_delta=delta
	if absf(delta-1.0/hz)>.0000001:_trace_integrity_reason="ACTUAL_DELTA_MISMATCH"
	_phase_context="pre_control";_tick_events.clear()
	_scenario_tick+=1
	var before:Dictionary=_snapshot("pre_control")
	if not initial_states.has(current_definition.id):initial_states[current_definition.id]=before.duplicate(true)
	writer.sample(before)
	super._set_keys(_desired_keys)
	for gesture:Dictionary in _emissions:
		if gesture.point is Vector3:super._aim(gesture.point)
		_latest_ray={"pointer":app.pointer,"camera_pose":app.camera.global_transform,"origin_m":app.camera.project_ray_origin(app.pointer),"direction":app.camera.project_ray_normal(app.pointer),"intended_world_point_m":gesture.point,"hand":gesture.hand,"pressed":gesture.pressed}
		var hit:Dictionary=app.targeting.candidate(app.camera,app.pointer,app.torso)
		_latest_ray["ray_hit"]={"collider":Reader.identity(hit.collider),"point_m":hit.position,"normal":hit.normal,"shape":hit.get("shape",null)} if not hit.is_empty() else {}
		if not hit.is_empty():
			_latest_ray["collider_key"]=Reader.identity(hit.collider).key
			_latest_ray["collider_runtime_id"]=hit.collider.get_instance_id()
			_latest_ray["material_local_point_m"]=hit.collider.to_local(hit.position)
			_latest_ray["material_local_normal"]=hit.collider.global_basis.inverse()*Vector3(hit.normal)
		super._button(int(gesture.hand),bool(gesture.pressed))
		_latest_ray["last_rejection"]=app.controller.last_rejection
		_event("REQUEST_SELECTED" if gesture.pressed else "INPUT_RELEASE",{"gesture":gesture.duplicate(true),"ray":_latest_ray.duplicate(true),"emitted_tick":_scenario_tick,"sample_phase":"pre_control"})
	_emissions.clear()
	var command:Dictionary={"keys":_desired_keys.duplicate(),"hand_held":[Input.is_action_pressed("grip_left"),Input.is_action_pressed("grip_right")]}
	if command!=_last_command:_event("COMMAND_EMITTED",{"command_requested":command.duplicate(true),"sample_phase":"pre_control","decision":_decisions.duplicate(true)})
	_last_command=command
	_phase_context="control_callbacks"

func _snapshot(phase:String)->Dictionary:
	var result:Dictionary=_metadata(phase)
	result.merge(reader.read(app),true)
	result["command_requested"]={"keys":_desired_keys.duplicate(),"decision":_decisions.duplicate(true),"hand_held":[Input.is_action_pressed("grip_left"),Input.is_action_pressed("grip_right")]}
	result["target"]=_latest_ray.duplicate(true)
	result["measurement_active"]=measurement_active
	result["contact_events"]=_tick_events.duplicate(true)
	return result

func _post_tick(delta:float)->void:
	if _scenario_enabled and is_instance_valid(app):
		_actual_delta=delta
		if absf(delta-1.0/hz)>.0000001:_trace_integrity_reason="ACTUAL_DELTA_MISMATCH"
		_phase_context="post_control"
		var start_usec:int=Time.get_ticks_usec()
		latest=_snapshot("post_control")
		if _scenario_tick==1:_event("INITIAL_STATE",{"state":initial_states[current_definition.id].duplicate(true)})
		var accepted:Vector2=latest.command_accepted.accepted_input
		if _accepted_previous==null or accepted!=_accepted_previous:_event("COMMAND_ACCEPTED",{"command_accepted":latest.command_accepted.duplicate(true)})
		_accepted_previous=accepted
		if not _pending_transition.is_empty() and not _pending_transition.has("accepted_tick") and accepted==_pending_transition.expected_input:
			_pending_transition["accepted_tick"]=_scenario_tick
			_pending_transition["accepted_time_s"]=float(_scenario_tick)/hz
			_pending_transition["accepted_snapshot"]=latest.duplicate(true)
			_measured_anchors.clear()
			for hand:Dictionary in latest.hands:
				if hand.state=="ATTACHED":_measured_anchors[int(hand.id)]=hand.anchor_runtime_id
			measurement_active=true
			_event("ACCEPTED_TRANSITION",{"transition":_pending_transition.duplicate(true)})
		_chain(latest)
		latest["contact_events"]=_tick_events.duplicate(true)
		latest["measurement_active"]=measurement_active
		writer.sample(latest)
		if not _observer_on and measurement_active:
			last_row=_metric_row(latest);metrics.push(last_row);response.push(last_row)
		if measurement_active:
			_measurement_ground_seen=_measurement_ground_seen or latest.support.grounded or Vector3(latest.force_budget.ground_force_n).length()>.0001 or Vector3(latest.force_budget.ground_torque_nm).length()>.0001
			_measurement_support_lost=_measurement_support_lost or not latest.support.valid
			if current_definition.get("reliability_kind","")=="control":
				for id in _measured_anchors:
					var hand:Dictionary=latest.hands[int(id)]
					_measurement_support_lost=_measurement_support_lost or hand.state!="ATTACHED" or hand.anchor_runtime_id!=_measured_anchors[id]
		_sample_cost_usec+=Time.get_ticks_usec()-start_usec;_sample_calls+=1
	post_completed.emit()

func _chain(row:Dictionary)->void:
	for id in 2:
		var hand:Dictionary=row.hands[id]
		var previous:Dictionary=_previous_hands[id] if _previous_hands.size()==2 else {}
		var pending:Dictionary=hand.pending
		var old_pending:Dictionary=previous.get("pending",{})
		if pending.get("active",false) and pending.get("target_selection_id")!=old_pending.get("target_selection_id"):_event("TARGET_LOCKED",{"hand":id,"target":pending.duplicate(true)})
		var new_contact:bool=hand.state=="ATTACHED" and (previous.get("state","")!="ATTACHED" or hand.anchor_runtime_id!=previous.get("anchor_runtime_id",0))
		if hand.state!=previous.get("state","") or new_contact:
			if hand.state=="ATTACHED":_event("CONTACT_VALIDATED",{"hand":id,"actual":hand.duplicate(true)})
			_event(str(hand.state),{"hand":id,"actual":hand.duplicate(true)})
		if pending.get("physical_in_reach",false) and not old_pending.get("physical_in_reach",false):_event("ENTER_REACH_WINDOW",{"hand":id,"target":pending.duplicate(true)})
		if not pending.get("physical_in_reach",false) and old_pending.get("physical_in_reach",false):_event("EXIT_REACH_WINDOW",{"hand":id,"target":pending.duplicate(true)})
		if pending.get("blocked",false)!=old_pending.get("blocked",false):_event("PATH_BLOCKED" if pending.get("blocked",false) else "PATH_CLEAR",{"hand":id,"target":pending.duplicate(true)})
		elif pending.get("active",false) and not old_pending.get("active",false) and not pending.get("blocked",false):_event("PATH_CLEAR",{"hand":id,"target":pending.duplicate(true),"scope":"current finite-path diagnostic, not future contact authorization"})
		if new_contact:
			_retained[id]={"anchor":hand.anchor_runtime_id,"start_tick":_scenario_tick,"loaded":false,"retained":false}
		if _retained.has(id):
			var record:Dictionary=_retained[id]
			if hand.state!="ATTACHED" or hand.anchor_runtime_id!=record.anchor:_retained.erase(id)
			else:
				if Vector3(hand.force_n).length()>1 and not record.loaded:record.loaded=true;_event("LOAD_ADMITTED",{"hand":id,"force_n":hand.force_n,"anchor_runtime_id":hand.anchor_runtime_id})
				if _scenario_tick-int(record.start_tick)>=int(round(.6*hz)) and not record.retained:record.retained=true;_event("RETAINED",{"hand":id,"anchor_runtime_id":hand.anchor_runtime_id,"duration_s":float(_scenario_tick-int(record.start_tick))/hz})
	_previous_hands=row.hands.duplicate(true)

func _transfer(value:Dictionary)->void:
	super._transfer(value)
	_event("TRANSFER_DIAGNOSTIC",{"actual_event":value.duplicate(true)})

func _tick(seconds:float)->void:
	for frame in maxi(1,int(round(seconds*hz))):
		await post_completed
		if cancelled or _hard_failed() or not _trace_integrity_reason.is_empty():break
		if float(Time.get_ticks_msec()-_clock_start)/1000.0>float(manifest.get("timeout_s",manifest.get("timeout_seconds",600))):
			cancelled=true;break

func _fresh(definition:Dictionary)->void:
	_scenario_enabled=false;measurement_active=false
	# Cleanup is deliberately immediate and outside the measured/recorded phase.
	super._release_all();_desired_keys.clear();_emissions.clear();_pending_pointer=null
	if is_instance_valid(app):loader.restore();app.queue_free();app=null;await get_tree().physics_frame
	if is_instance_valid(_course):_course.queue_free();_course=null
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
	_scenario_enabled=true
	await _tick(float(definition.get("warmup_s",.45)))

func _begin(direction:Vector3,goal:float)->bool:
	measurement_active=true
	_event("MEASUREMENT_BEGIN",{"direction_world":direction,"snapshot":latest.duplicate(true)})
	if not _observer_on:
		last_row=_metric_row(latest);_epoch=app.controller.simulation_time
		response.start(last_row,direction)
		return metrics.start(last_row,direction,{"physics_hz":hz,"target_progress_m":goal})
	return super._begin(direction,goal)

func _metric_row(row:Dictionary)->Dictionary:
	return {"time":float(row.controller_time_s),"tick":int(row.controller_step),"com_position":row.body.com_m,"body_position":row.body.pose.origin,"velocity":row.body.linear_velocity_m_s,"linear_velocity":row.body.linear_velocity_m_s,"angular_velocity":row.body.angular_velocity_rad_s,"movement_intent_world":row.command_accepted.intent_world,"accepted_input":row.command_accepted.accepted_input,"accepted_input_time":row.command_accepted.accepted_input_time,"frame":row.frame,"grounded":row.support.grounded,"assisted":row.support.hybrid_owned}

func _run_scenario(definition:Dictionary)->Dictionary:
	var row:Dictionary
	if definition.get("reliability_kind","")=="control":row=await _control_case(definition)
	else:row=await super._run_scenario(definition)
	row["reliability"]={"sample_phase":"post_control","input_driver":"shared_physics_tick_v1","measurement_ground_seen":_measurement_ground_seen,"measurement_support_lost":_measurement_support_lost,"last_snapshot":latest.duplicate(true),"controller_observer_enabled":_observer_on}
	row["initial_state"]=initial_states.get(definition.id,{}).duplicate(true)
	row["initial_state_sha256"]=JSON.stringify(TraceWriter.Serializer.serializable(Reader.stable_initial(row.initial_state)),"",true,true).sha256_text()
	if not _observer_on and row.has("metrics"):
		row.metrics["max_acceleration_proxy_m_s2"]=null
		row["legacy_metrics_scope"]="Existing observer disabled; capture outcome and new direct-state trace remain authoritative; cached legacy scalar metrics are not used for parity"
	_event("SCENARIO_END",{"result_status":row.get("status"),"reason":row.get("reason",""),"goal_completed":row.get("completed",false)})
	measurement_active=false;_scenario_enabled=false
	return row

func _relative_velocity(row:Dictionary)->Vector3:
	var velocity:Vector3=row.body.get("linear_velocity_m_s",Vector3.ZERO)
	if row.support.get("point_velocity_m_s") is Vector3:velocity-=Vector3(row.support.point_velocity_m_s)
	return velocity

func _valid_support(required:int)->bool:
	if latest.is_empty() or latest.support.grounded or latest.support.hybrid_owned:return false
	var count:=0
	var effort:=0.0
	for hand:Dictionary in latest.hands:
		if hand.state=="ATTACHED":count+=1;effort+=Vector3(hand.force_n).length()
	return count>=required and effort>1 and Vector3(latest.force_budget.ground_force_n).length()<.0001 and Vector3(latest.force_budget.ground_torque_nm).length()<.0001

static func _quiet_velocity_eligible(velocity:Vector3,spin:Vector3,axis:Vector3,full_speed:bool=false)->bool:
	# Low-energy controls must not hide vertical/depth motion behind a quiet lateral component.
	var speed:float=velocity.length() if full_speed else absf(velocity.dot(axis))
	return speed<=.1 and spin.length()<=.2

static func _motion_velocity_eligible(speed:float,opposite:bool)->bool:
	# Rev 2: stop/brake/reverse preparation starts outside the .10 m/s settling band.
	return speed>=-.5 and speed<=-.02 if opposite else speed>=.15 and speed<=.5

func _settled(required:int,axis:Vector3,full_speed:bool=false)->bool:
	var sustained:=0
	for frame in int(5*hz):
		await _tick(1.0/hz)
		var valid:bool=_valid_support(required) and _quiet_velocity_eligible(_relative_velocity(latest),Vector3(latest.body.angular_velocity_rad_s),axis,full_speed)
		sustained=sustained+1 if valid else 0
		if sustained>=int(round(.25*hz)):return true
		if cancelled or _hard_failed():return false
	return false

func _control_case(definition:Dictionary)->Dictionary:
	await _fresh(definition)
	if not app.override_error.is_empty():
		return {"id":definition.id,"revision":definition.revision,"status":"BLOCKED_SETUP","completed":false,"reason":app.override_error,"scope":"Original baseline Resource verification failed; no acquisition or preparation attempted"}
	var required:int=int(definition.hand_count)
	var task:String=definition.task
	var reason:=""
	for id in required:
		if not await _grip(id,app.level.transfer_points[id]):reason="PREPARATION_ACQUISITION_FAILED";break
	_set_keys(["contract"]);await _tick(1.5);_set_keys([]);await _tick(.15)
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
			if cancelled or _hard_failed():break
		if _pending_transition.has("accepted_tick"):
			transition.tick=_pending_transition.accepted_tick;transition.physics_time_s=_pending_transition.accepted_time_s
			transition["requested_tick"]=_pending_transition.requested_tick
			preparation=_pending_transition.accepted_snapshot.duplicate(true)
		else:reason="INPUT_NOT_ACCEPTED"
	_set_keys([])
	var valid:bool=reason.is_empty()
	if valid and _measurement_ground_seen:reason="INVALID_SUPPORT_STATE";valid=false
	if valid and _measurement_support_lost:reason="SUPPORT_LOST";valid=false
	var displacement:Variant=null
	if preparation.get("body",{}).get("com_m") is Vector3 and latest.get("body",{}).get("com_m") is Vector3:displacement=(Vector3(latest.body.com_m)-Vector3(preparation.body.com_m)).dot(axis)
	return {"id":definition.id,"revision":definition.revision,"status":"valid_observation" if valid else "precondition_not_met" if reason.begins_with("PRE") else "interrupted","completed":valid,"reason":reason,"scope":"measurement validity separate from positive performance; natural attachments and B1 foot contributions","invariants":violations.duplicate(true),"metrics":{"useful_displacement_m":displacement},"capture":capture.duplicate(true),"precondition_snapshot":preparation,"transition":transition,"direction_world":axis,"observation_s":definition.observe_s,"eligible_hand_count":required}

func start(value:Dictionary)->Dictionary:
	if running:return {"schema_version":"1.3.1","status":"BLOCKED_SETUP","reason":"DRIVER_ALREADY_RUNNING"}
	manifest=value.duplicate(true);candidate=manifest.get("baseline_candidate",{}).duplicate(true)
	var checked:Dictionary=loader.validate(candidate)
	if not checked.ok:return {"schema_version":"1.3.1","status":"BLOCKED_SETUP","reason":checked.reason}
	if FileAccess.get_sha256(OS.get_executable_path())!=candidate.engine_identity.sha256 or not str(candidate.engine_identity.version).contains(str(Engine.get_version_info().hash).substr(0,9)):return {"status":"BLOCKED_SETUP","reason":"ENGINE_IDENTITY_MISMATCH"}
	for knob:Dictionary in loader.space.parameters:
		if float(candidate.parameter_overrides[knob.id])!=float(knob.baseline):return {"status":"BLOCKED_SETUP","reason":"BASELINE_ONLY_NO_OVERRIDES"}
	for path in manifest.expected_source_hashes:
		if FileAccess.get_sha256("res://"+path)!=manifest.expected_source_hashes[path]:return {"status":"BLOCKED_SETUP","reason":"SOURCE_HASH_MISMATCH:"+path}
	hz=int(manifest.physics_hz)
	if hz not in [60,120]:return {"status":"BLOCKED_SETUP","reason":"PHYSICS_HZ"}
	_observer_on=bool(manifest.get("existing_observer_enabled",true))
	if not _observer_on and (manifest.scenario_ids.size()!=1 or manifest.scenario_ids[0] not in ["swing_catch_train","catch_isolated_v1"]):return {"status":"BLOCKED_SETUP","reason":"FULL_OBSERVER_OFF_REFERENCE_IS_CATCH_ONLY"}
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var definitions:Dictionary={}
	for item:Dictionary in catalog.scenarios:definitions[item.id]=item
	var old_catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(TRAIN))
	for item:Dictionary in old_catalog.scenarios:definitions[item.id]=item
	var isolated:Dictionary=definitions.swing_catch_train.duplicate(true);isolated.id="catch_isolated_v1";isolated.implementation_id="swing_catch_train";isolated.revision=1
	definitions[isolated.id]=isolated
	for id in manifest.scenario_ids:
		if not definitions.has(id):return {"status":"BLOCKED_SETUP","reason":"UNKNOWN_SCENARIO:"+str(id)}
	if not writer.open_at(str(manifest.output_dir),bool(manifest.recorder_enabled)):return {"status":"BLOCKED_TRACE","reason":writer.error}
	var previous_hz:int=Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second=hz;_clock_start=Time.get_ticks_msec();running=true
	var results:Array=[]
	for id in manifest.scenario_ids:
		results.append(await _run_scenario(definitions[id]))
		if cancelled or _hard_failed() or not _trace_integrity_reason.is_empty():break
	_scenario_enabled=false;measurement_active=false;super._release_all()
	var restoration:Dictionary=loader.restore()
	if is_instance_valid(app):app._set_input_profile(2);app.queue_free();app=null
	Engine.physics_ticks_per_second=previous_hz
	var sources_ok:=true
	for path in manifest.expected_source_hashes:sources_ok=sources_ok and FileAccess.get_sha256("res://"+path)==manifest.expected_source_hashes[path]
	var trace_result:Dictionary=writer.close()
	TraceWriter.atomic_json(str(manifest.output_dir).path_join("initial_state.json"),initial_states)
	running=false
	return {"schema_version":"1.3.1","run_id":manifest.run_id,"status":"BLOCKED_TRACE" if not trace_result.error.is_empty() or not sources_ok or not _trace_integrity_reason.is_empty() else "timed_out" if cancelled else "failed_invariant" if _hard_failed() else "completed","reason":_trace_integrity_reason,"data_kind":"automated_headless" if manifest.engine_mode=="headless" else "automated_rendered_scripted","engine_mode":manifest.engine_mode,"physics_hz":hz,"scenarios":results,"restoration":{"resources":restoration,"physics_hz_restored":Engine.physics_ticks_per_second==previous_hz,"startup_profile_preserved":_baseline_profile_ok,"installs_pre_step":_all_installs_pre_step,"sources_after_unchanged":sources_ok},"trace":trace_result,"instrumentation":{"cost_usec":_sample_cost_usec,"sample_calls":_sample_calls,"cost_scope":"post-probe snapshot, event derivation and JSON serialization only; excludes pre-probe, input emission, original observers and engine. External process timing needed for total overhead.","recorder_enabled":writer.enabled,"existing_observer_enabled":_observer_on,"observer_off_scope":"recorder OFF is not full gameplay-observer OFF"},"environment":{"engine":Engine.get_version_info(),"engine_binary_sha256":FileAccess.get_sha256(OS.get_executable_path()),"physics_backend":ProjectSettings.get_setting("physics/3d/physics_engine"),"max_physics_steps_per_frame":Engine.max_physics_steps_per_frame,"time_scale":Engine.time_scale,"physics_interpolation":ProjectSettings.get_setting("physics/common/physics_interpolation"),"render_max_fps":Engine.max_fps,"code_commit":manifest.get("code_commit"),"dirty_tree":manifest.get("dirty_tree"),"expected_source_hashes":manifest.expected_source_hashes,"catalog_sha256":FileAccess.get_sha256(CATALOG)}}
