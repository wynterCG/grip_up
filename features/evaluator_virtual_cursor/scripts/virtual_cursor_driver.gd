extends "res://features/evaluator_qualification/scripts/qualification_driver.gd"
const Provider=preload("res://features/evaluator_virtual_cursor/scripts/replay_input_provider.gd")
const InputFrame=preload("res://features/grip_up/scripts/grip_input_frame.gd")
var virtual_tape:Dictionary={}
var virtual_rows:Array[Dictionary]=[]
var virtual_frames:Array[Dictionary]=[]
var requested_frame:Dictionary={}
var held:=[false,false]
var virtual_aim:=Vector2.ZERO
var aim_valid:=false
var provider
var session_environment:Dictionary={}
var cleanup_receipt:Dictionary={}
var last_wall_usec:=0
var maximum_gap_usec:=0
var negative_checks:Array[Dictionary]=[]
var projection_probe
var projection_setup:Dictionary={}

func _negative_check(value:bool,label:String,extra:Dictionary={})->void:
	negative_checks.append({"pass":value,"label":label,"evidence":extra})

func _invalidate_input(reason:String)->void:
	_trace_integrity_reason=reason
	if provider!=null:provider.invalidate(reason)
	# The invalid tick is never qualified; existing actuator callbacks may consume
	# prior intent until normal cleanup at POST. No solver timing is rewritten.

func _metadata(phase:String)->Dictionary:
	var row:Dictionary=super._metadata(phase)
	row.schema_version="1.3.2a";row.lane="V0_ISOLATED_POINTER";return row

func _virtual_scope(value:Dictionary)->String:
	if value.has("projection_config") and (not OS.get_cmdline_user_args().has("--projection-qualification") or not str(value.get("campaign_id","")).begins_with("projection_v132b_")):return "PROJECTION_FLAG_CAMPAIGN_REQUIRED"
	return "" if value.get("scenario_ids",[])==["swing_catch_train"] else "UNSUPPORTED_REPLAY_CASE"

func _virtual_benchmark(_value:Dictionary)->String:return "benchmark_eval_virtual_cursor_v1"
func _virtual_tick_limit()->int:return 2048
func _prepare_projection_size(requested_size:Array)->String:
	get_window().size=Vector2i(int(requested_size[0]),int(requested_size[1]))
	return ""
func _configure_virtual_fixture(definition:Dictionary)->void:
	_course=Course.new();add_child(_course);_course.apply_segment(app,int(definition.segment))

func start(value:Dictionary)->Dictionary:
	if not OS.get_cmdline_user_args().has("--virtual-cursor-evaluator"):return {"status":"BLOCKED_SETUP","reason":"TEST_FLAG_REQUIRED"}
	var scope_error:String=_virtual_scope(value)
	if not scope_error.is_empty():return {"status":"BLOCKED_SETUP","reason":scope_error}
	if value.get("virtual_mode","")=="REPLAY":
		var path:String=str(value.get("virtual_tape_path",""))
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=value.get("virtual_tape_sha256",""):return {"status":"BLOCKED_SETUP","reason":"TAPE_HASH"}
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary or parsed.get("schema","")!="grip_virtual_replay_v1":return {"status":"BLOCKED_SETUP","reason":"LEGACY_POINTER_AMBIGUOUS"}
		virtual_tape=parsed
		if virtual_tape.get("diagnostic_only",false) and value.get("negative_case","").is_empty():return {"status":"BLOCKED_SETUP","reason":"DIAGNOSTIC_TAPE_NOT_QUALIFICATION"}
		if virtual_tape.get("engine_identity",{})!=value.engine_identity or virtual_tape.get("benchmark","")!=_virtual_benchmark(value) or virtual_tape.get("camera_mode","")!="V0_PHYSICS_FOLLOW":return {"status":"BLOCKED_SETUP","reason":"TAPE_ENGINE_CAMERA_BENCHMARK"}
		if virtual_tape.get("source_hashes",{})!=value.get("projection_capture_source_hashes",value.expected_source_hashes) or int(virtual_tape.get("physics_hz",0))!=int(value.physics_hz):return {"status":"BLOCKED_SETUP","reason":"TAPE_SOURCE_HZ"}
		if not virtual_tape.get("frames") is Array or virtual_tape.frames.is_empty() or virtual_tape.frames.size()>_virtual_tick_limit():return {"status":"BLOCKED_SETUP","reason":"TAPE_TICK_COUNT"}
		if not virtual_tape.get("reference_ticks") is Array or virtual_tape.reference_ticks.size()!=virtual_tape.frames.size():return {"status":"BLOCKED_SETUP","reason":"MISSING_TICK:REFERENCE"}
		var previous:Dictionary={}
		for row:Dictionary in virtual_tape.frames:
			var checked:String=InputFrame.validate(row,previous)
			if not checked.is_empty():return {"status":"BLOCKED_SETUP","reason":checked}
			previous=row
	var result:Dictionary=await super.start(value)
	result.schema_version="1.3.2a";result["benchmark"]=_virtual_benchmark(value)
	result["virtual_input"]={"environment":session_environment,"cleanup":cleanup_receipt,"maximum_tick_wall_gap_usec":maximum_gap_usec,"provider_lifecycle":provider.lifecycle if provider!=null else [],"rejected_hardware_events":provider.rejected if provider!=null else [],"rejected_hardware_event_count":provider.rejected_count if provider!=null else 0,"rejection_counts":provider.rejection_counts if provider!=null else {},"focus_events":provider.focus_events if provider!=null else []}
	result["negative_checks"]=negative_checks.duplicate(true)
	if value.has("projection_config"):
		result["projection_setup"]=projection_setup
		result["projection_probe"]=projection_probe.write(str(value.output_dir).path_join("projection_picks.jsonl")) if projection_probe!=null else {"status":"CONTROL_WITH_PROBE_DISABLED"}
	if value.get("pick_contract_version","")=="1.3.4" and (result.get("status")=="completed" or not virtual_rows.is_empty()):
		var PickContract=preload("res://features/evaluator_virtual_cursor/scripts/pick_dispatch_contract.gd")
		var ProbeEncoder=preload("res://features/evaluator_virtual_cursor/scripts/projection_probe.gd")
		var pick_view:Dictionary=PickContract.build_view(ProbeEncoder.encode(virtual_rows),projection_probe.records if projection_probe!=null else [],str(value.run_id),result.get("status")=="completed" and _trace_integrity_reason.is_empty(),virtual_frames.size(),true)
		var pick_path:String=str(value.output_dir).path_join("pick_dispatch_contract.json")
		if not TraceWriter.atomic_json(pick_path,pick_view):pick_view={"status":"INVALID","reason":"PICK_CONTRACT_WRITE_FAILED"}
		result["pick_contract"]={"status":pick_view.status,"reason":pick_view.reason,"path":pick_path,"sha256":FileAccess.get_sha256(pick_path)}
		if pick_view.status!="PASS":result.status="invalid";result.reason="PICK_CONTRACT_FAILURE:"+str(pick_view.reason)
	TraceWriter.atomic_json(str(value.output_dir).path_join("virtual_audit.json"),{"schema":"grip_virtual_audit_v1","environment":session_environment,"frames":virtual_frames,"ticks":virtual_rows})
	return result

func _make_virtual_lab():return BaselineLab.new()
func _seal_virtual_lab()->String:return ""

func _fresh(definition:Dictionary)->void:
	var lead_in:float=float(manifest.get("human_lead_in_s",0))
	if lead_in>0:
		var notice:=Label.new();notice.text="GRIP UP replay / "+str(manifest.get("condition",""))+" / begins in %ds"%int(lead_in)
		notice.position=Vector2(40,40);notice.add_theme_font_size_override("font_size",32);notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(notice)
		await _tick(lead_in)
		notice.queue_free()
	if manifest.has("projection_config"):
		var requested_size:Array=manifest.projection_config.window_size
		var size_error:String=_prepare_projection_size(requested_size)
		if not size_error.is_empty():_trace_integrity_reason=size_error;return
		await post_completed
		await post_completed
		projection_setup={"requested_size":requested_size,"actual_size":[get_window().size.x,get_window().size.y],"before_world":not is_instance_valid(app),"clock_delta":_post_delta}
		if get_window().size!=Vector2i(int(requested_size[0]),int(requested_size[1])):_trace_integrity_reason="ENVIRONMENT_NOT_COMPARABLE:REQUESTED_WINDOW_SIZE";return
	await post_completed
	_world_creation={"run_tick":_global_tick,"sample_phase":_phase_context,"actual_delta_s":_post_delta,"requested_delta_s":1.0/hz,"boundary":"post_completed_before_lab_construction","retired_worlds":_retired_worlds.duplicate(true),"old_subtrees_absent":true}
	_reset_episode()
	current_definition=definition.duplicate(true);_scenario_tick=0;_previous_hands.clear();_retained.clear();_last_command.clear();_latest_ray.clear();latest.clear()
	app=_make_virtual_lab();app.override_loader=loader;app.trial_candidate=candidate;app.virtual_input_arming=true
	get_tree().root.add_child(app);get_tree().current_scene=app
	_baseline_profile_ok=_baseline_profile_ok and app.input_profile==2
	app._open_intent_arena(int(definition.arena),true)
	_configure_virtual_fixture(definition)
	app._set_movement_allocation(0);app._set_intent_aware_feet(false);app._set_physical_feet(true)
	app._set_distant_targeting(true);app._set_locomotion_diagnostics(_observer_on);app.transfer_diagnostics_enabled=true;app._apply_independent_settings()
	var seal_error:String=_seal_virtual_lab()
	if not seal_error.is_empty():_trace_integrity_reason=seal_error;return
	app.won=true;app.settings.hide()
	app.controller.sample_ready.connect(_sample);app.controller.transfer_event.connect(_transfer)
	for entry:Dictionary in app.installs:_all_installs_pre_step=_all_installs_pre_step and bool(entry.before_first_step)
	if manifest.has("projection_config"):
		var Probe=load("res://features/evaluator_virtual_cursor/scripts/projection_probe.gd")
		projection_setup["after_world_environment"]=Probe.environment(app)
		if get_window().size!=Vector2i(int(manifest.projection_config.window_size[0]),int(manifest.projection_config.window_size[1])):_trace_integrity_reason="ENVIRONMENT_NOT_COMPARABLE:WORLD_WINDOW_SIZE";return
		if manifest.projection_config.probe_enabled:
			projection_probe=Probe.new();projection_probe.manifest=manifest
			app.targeting.projection_probe=projection_probe
	provider=Provider.new()
	var checked:String=app.begin_virtual_input(provider,{"benchmark":_virtual_benchmark(manifest),"camera_mode":"V0_PHYSICS_FOLLOW"})
	if not checked.is_empty():_trace_integrity_reason=checked;return
	provider.focus_changed(app.get_window().has_focus())
	var vp:Viewport=app.get_viewport()
	var rect:Rect2=vp.get_visible_rect()
	var canvas:Transform2D=vp.get_canvas_transform();var final:Transform2D=vp.get_final_transform()
	session_environment={"viewport_runtime_id":vp.get_instance_id(),"viewport_id":"GAME_ROOT","visible_rect":{"position":rect.position,"size":rect.size},"canvas_transform":[canvas.x,canvas.y,canvas.origin],"final_transform":[final.x,final.y,final.origin],"window_size":app.get_window().size,"window_mode":app.get_window().mode,"display_server":DisplayServer.get_name(),"screen":app.get_window().current_screen,"screen_dpi":DisplayServer.screen_get_dpi(app.get_window().current_screen) if DisplayServer.get_name()!="headless" else null,"screen_scale":DisplayServer.screen_get_scale(app.get_window().current_screen) if DisplayServer.get_name()!="headless" else null,"camera_mode":"V0_PHYSICS_FOLLOW","initial_camera":app.camera.global_transform,"initial_pointer":{"valid":false,"position":[0,0]},"bindings":{},"phase_order":["provider_pre_-100","ground_-10_previous_intent","lab_0","controller_existing","post_+100_before_next_integration"]}
	for action in app.router.DEFAULTS:session_environment.bindings[action]=InputMap.action_get_events(action).map(func(event):return event.as_text())
	_scenario_enabled=true
	await _tick(float(definition.get("warmup_s",.45)))

func _pre_tick(delta:float)->void:
	_global_tick+=1
	if not _scenario_enabled or not is_instance_valid(app):return
	_actual_delta=delta;_phase_context="pre_control";_tick_events.clear();_scenario_tick+=1
	if absf(delta-1.0/hz)>.0000001:_invalidate_input("ENVIRONMENT_NOT_COMPARABLE:ACTUAL_DELTA");return
	var now:int=Time.get_ticks_usec()
	if last_wall_usec>0:
		maximum_gap_usec=maxi(maximum_gap_usec,now-last_wall_usec)
		if now-last_wall_usec>250000:_invalidate_input("RUNTIME_SUSPENDED:TICK_GAP");return
	last_wall_usec=now
	if not initial_states.has(current_definition.id):initial_states[current_definition.id]=_snapshot("pre_control")
	writer.sample(_snapshot("pre_control"))
	if manifest.get("virtual_mode","")=="REPLAY":
		if _scenario_tick>virtual_tape.frames.size():_invalidate_input("MISSING_TICK:TAPE_EXHAUSTED");return
		requested_frame=virtual_tape.frames[_scenario_tick-1].duplicate(true)
		_desired_keys.clear()
		for action in ["contract","extend","bias_left","bias_right"]:
			if float(requested_frame.strengths[action])>0:_desired_keys.append(action)
	else:
		var edges:Array=[]
		for gesture:Dictionary in _emissions:
			if gesture.point is Vector3:
				virtual_aim=app.camera.unproject_position(gesture.point);aim_valid=true
			held[int(gesture.hand)]=bool(gesture.pressed)
			edges.append({"hand":int(gesture.hand),"pressed":bool(gesture.pressed)})
		var strengths:Dictionary={}
		for action in ["contract","extend","bias_left","bias_right"]:strengths[action]=1.0 if action in _desired_keys else 0.0
		strengths.grip_left=1.0 if held[0] else 0.0;strengths.grip_right=1.0 if held[1] else 0.0
		var size:Vector2=app.get_viewport().get_visible_rect().size
		requested_frame={"schema_version":InputFrame.SCHEMA,"session_id":str(manifest.run_id),"tape_sha256":"CAPTURE_SOURCE_IDENTITY","tick_index":_scenario_tick,"physics_hz":hz,"source_kind":"VIRTUAL_REPLAY","viewport_id":"GAME_ROOT","viewport_size_px":[size.x,size.y],"aim_valid":aim_valid,"aim_position_viewport_px":[virtual_aim.x,virtual_aim.y],"pointer_motion_valid":not _emissions.is_empty(),"camera_orbit_delta":[0.0,0.0],"camera_zoom_steps":[],"strengths":strengths,"button_edges":edges,"action_edges":[],"focus_policy_state":"ACTIVE","input_source_sequence":_scenario_tick}
	_emissions.clear();_keys=_desired_keys.duplicate()
	if manifest.get("negative_case","")=="N1" and _scenario_tick in [1,2,3,4]:
		requested_frame.aim_valid=_scenario_tick>=3;requested_frame.aim_position_viewport_px=[0.0,0.0]
		requested_frame.strengths.grip_left=1.0 if _scenario_tick in [1,3] else 0.0
		requested_frame.button_edges=[{"hand":0,"pressed":_scenario_tick in [1,3]}]
	if manifest.get("negative_case","")=="N2" and _scenario_tick==10:
		requested_frame.camera_orbit_delta=[20.0,-10.0];requested_frame.camera_zoom_steps=[1,-1,1]
	var old_yaw:float=app.camera.yaw;var old_elevation:float=app.camera.elevation;var old_distance:float=app.camera.distance
	if projection_probe!=null:
		projection_probe.requested=requested_frame.duplicate(true);projection_probe.actual_delta=delta
	var checked:String=app.commit_virtual_input(requested_frame,delta)
	if projection_probe!=null and not projection_probe.error.is_empty():_invalidate_input(projection_probe.error);return
	if not checked.is_empty():_trace_integrity_reason=checked;return
	if manifest.get("negative_case","")=="N1" and _scenario_tick==3:
		_negative_check(app.pointer==Vector2.ZERO and not app.input_picks.is_empty() and app.input_picks[0].has("audit"),"explicit_valid_top_left_uses_real_targeting",{"picks":app.input_picks.duplicate(true)})
	if manifest.get("negative_case","")=="N2" and _scenario_tick==10:
		_negative_check(is_equal_approx(app.camera.yaw,old_yaw-.08) and is_equal_approx(app.camera.elevation,old_elevation-.03) and is_equal_approx(app.camera.distance,old_distance+.65),"normal_orbit_and_ordered_wheel",{"yaw_before":old_yaw,"yaw_after":app.camera.yaw,"elevation_before":old_elevation,"elevation_after":app.camera.elevation,"distance_before":old_distance,"distance_after":app.camera.distance})
	if manifest.get("negative_case","")=="N3" and _scenario_tick in [13,55,143]:_synthetic_hardware_negative()
	if manifest.get("negative_case","")=="N1" and _scenario_tick==1:_guard_negatives()
	virtual_frames.append(requested_frame.duplicate(true))
	_latest_ray={"picks":app.input_picks.duplicate(true),"camera_pose":app.camera.global_transform,"aim_valid":requested_frame.aim_valid,"effective_aim":requested_frame.aim_position_viewport_px}
	_last_command={"keys":_desired_keys.duplicate(),"hand_held":app._held_grips()}
	_phase_context="control_callbacks"

func _snapshot(phase:String)->Dictionary:
	var row:Dictionary=_metadata(phase)
	row.merge(reader.read(app),true)
	row.command_accepted.hand_held=app._held_grips()
	row["command_requested"]={"keys":_desired_keys.duplicate(),"hand_held":app._held_grips()}
	row["target"]=_latest_ray.duplicate(true)
	if row.target.has("picks"):
		for pick:Dictionary in row.target.picks:
			if pick.get("camera_projection") is Projection:
				var projection:Projection=pick.camera_projection
				pick.camera_projection=[projection.x,projection.y,projection.z,projection.w].map(func(v):return [v.x,v.y,v.z,v.w])
	row.camera["source_body_pose"]=app.camera.virtual_source_pose
	row.camera["sampling_phase"]="V0_PHYSICS_FOLLOW_PRE_CONTROL"
	row["measurement_active"]=measurement_active;row["contact_events"]=_tick_events.duplicate(true)
	row["canonical_input"]={"requested":requested_frame.duplicate(true),"effective":app.input_frame.data() if app.input_frame!=null else {},"external_focus":provider.external_focus if provider!=null else "NOT_ARMED","hardware_aim_px":app.get_viewport().get_mouse_position(),"virtual_aim_px":requested_frame.get("aim_position_viewport_px"),"effective_aim_px":app.pointer,"source_kind":"VIRTUAL_REPLAY"}
	if phase=="post_control" and _scenario_enabled:
		virtual_rows.append(row.duplicate(true))
	return row

func _run_scenario(definition:Dictionary)->Dictionary:
	var outcome:Dictionary
	if manifest.get("virtual_mode","")=="REPLAY":
		if not _retire_previous_world():return {"status":"BLOCKED_SETUP","reason":"OLD_WORLD_NOT_RETIRED"}
		await _fresh(definition)
		while _scenario_tick<virtual_tape.frames.size() and not cancelled and not _hard_failed() and _trace_integrity_reason.is_empty():
			await _tick(1.0/hz)
			if manifest.get("negative_case","")=="N4" and _scenario_tick>=int(round(1.4*hz)):
				_negative_check(app._held_grips().has(true) and app.controller._attached_ids().size()>0,"abort_occurs_with_real_held_support",{"tick":_scenario_tick,"held":app._held_grips(),"states":[app.controller.get_hand_state(0),app.controller.get_hand_state(1)]})
				_invalidate_input("TEST_ABORT_WHILE_HELD");break
		var catch_result:Dictionary=_catch_outcome()
		outcome={"id":definition.id,"status":"valid_observation" if catch_result.retained else "task_failed","completed":catch_result.retained,"invariants":violations.duplicate(true),"catch_native":catch_result}
	else:outcome=await super._run_scenario(definition)
	outcome["catch_native"]=_catch_outcome()
	_scenario_enabled=false;measurement_active=false
	if is_instance_valid(app) and app.replay_input_provider!=null:
		if manifest.get("negative_case","")=="N2":_silhouette_negative()
		app.finish_virtual_input();app.finish_virtual_input()
		cleanup_receipt={"provider_disabled":provider.state=="DISABLED","lab_provider_removed":app.replay_input_provider==null,"camera_live":not app.camera.virtual_physics_follow,"router_frame_removed":app.router.input_frame==null,"hand_held":app._held_grips(),"hands":[app.controller.get_hand_state(0),app.controller.get_hand_state(1)],"orbiting":app.orbiting}
		if manifest.get("negative_case","")=="N4":
			_negative_check(cleanup_receipt.provider_disabled and cleanup_receipt.lab_provider_removed and cleanup_receipt.hand_held==[false,false] and cleanup_receipt.camera_live,"abort_held_cleanup_idempotent",cleanup_receipt)
			Input.action_press("grip_left");Input.action_press("contract")
			app.get_window().focus_exited.emit()
			_negative_check(not Input.is_action_pressed("grip_left") and not Input.is_action_pressed("contract"),"live_focus_release_preserved",{"synthetic_focus_signal":true,"held_after":app._held_grips()})
	return outcome

func _synthetic_hardware_negative()->void:
	var before:Dictionary={"frame":app.input_frame.data(),"pointer":app.pointer,"yaw":app.camera.yaw,"elevation":app.camera.elevation,"distance":app.camera.distance,"world_id":app.world.get_instance_id(),"settings":app.settings.visible,"profile":app.input_profile}
	var motion:=InputEventMouseMotion.new();motion.position=Vector2(500,400);motion.relative=Vector2(300,-200);motion.screen_relative=motion.relative
	Input.parse_input_event(motion)
	for button in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		for pressed in [true,false]:
			var event:=InputEventMouseButton.new();event.position=Vector2(20,20);event.button_index=button;event.pressed=pressed;Input.parse_input_event(event)
	for key in [KEY_W,KEY_S,KEY_A,KEY_D,KEY_R,KEY_ESCAPE,KEY_TAB,KEY_SPACE]:
		for pressed in [true,false]:
			var event:=InputEventKey.new();event.keycode=key;event.physical_keycode=key;event.pressed=pressed;Input.parse_input_event(event)
	Input.flush_buffered_events()
	app.get_window().focus_exited.emit();app.get_window().focus_entered.emit()
	var after:Dictionary={"frame":app.input_frame.data(),"pointer":app.pointer,"yaw":app.camera.yaw,"elevation":app.camera.elevation,"distance":app.camera.distance,"world_id":app.world.get_instance_id(),"settings":app.settings.visible,"profile":app.input_profile}
	_negative_check(before==after,"synthetic_OS_events_do_not_change_authority",{"tick":_scenario_tick,"synthetic_events_not_human":true,"rejections":provider.rejected_count,"before":before,"after":after})

func _guard_negatives()->void:
	# Provider-only probes use the real lab environment, without dispatching actions.
	for kind in ["source","viewport","camera","duplicate","missing"]:
		var shadow=Provider.new();shadow.arm(app,{})
		var value:Dictionary=requested_frame.duplicate(true)
		var checked:=""
		if kind=="source":value.source_kind="LIVE";checked=shadow.commit(value,app)
		elif kind=="viewport":value.viewport_size_px=[100.0,100.0];checked=shadow.commit(value,app)
		elif kind=="camera":
			var original:float=app.camera.fov;app.camera.fov=57;checked=shadow.commit(value,app);app.camera.fov=original
		elif kind=="duplicate":
			shadow.commit(value,app);value.tick_index=2;value.input_source_sequence=2;checked=shadow.commit(value,app)
		else:value.tick_index=2;checked=shadow.commit(value,app)
		_negative_check(not checked.is_empty(),"reject_"+kind,{"reason":checked});shadow.finish()
	var invalid:Dictionary=requested_frame.duplicate(true)
	invalid.aim_valid=false;invalid.strengths.grip_left=1.0;invalid.button_edges=[{"hand":0,"pressed":true}]
	_negative_check(InputFrame.validate(invalid)=="","explicit_invalid_aim_can_preserve_held_semantics")
	_negative_check(app.input_picks.size()==1 and app.input_picks[0].get("reason","")=="INVALID_AIM_NO_NEW_TARGET" and app.controller.get_hand_state(0) in ["FREE","RELEASED"],"initial_absent_cursor_did_not_pick",{"picks":app.input_picks.duplicate(true)})
	var top_left:Dictionary=requested_frame.duplicate(true);top_left.aim_valid=true;top_left.aim_position_viewport_px=[0.0,0.0]
	_negative_check(InputFrame.validate(top_left)=="","explicit_valid_top_left_not_ambiguous")

func _silhouette_negative()->void:
	var center:Vector2=app.camera.unproject_position(app.level.transfer_points[0])
	var found:Dictionary={};var queries:=0
	# Existing geometry only. Keep the actual winning offset and normal from each ray.
	for x in range(-80,81,4):
		if not found.is_empty():break
		var previous:Dictionary={}
		for y in range(-30,31):
			var point:Vector2=center+Vector2(x,y)
			app.targeting.candidate(app.camera,point,app.torso);queries+=1
			var audit:Dictionary=app.targeting.last_audit.duplicate(true)
			var winner:Variant=audit.get("winner")
			if winner is Dictionary and not previous.is_empty() and previous.winner is Dictionary:
				if winner.collider_key==previous.winner.collider_key and winner.local_normal!=previous.winner.local_normal:
					found={"first":previous,"second":audit,"delta_px":point-Vector2(previous.pointer),"queries":queries};break
			previous=audit
	_negative_check(not found.is_empty(),"real_one_pixel_adjacent_face_switch",found if not found.is_empty() else {"queries":queries,"status":"INCOMPLETE_COVERAGE"})

func _catch_outcome()->Dictionary:
	var contact:Variant=null;var source_free:Variant=null;var retained:Variant=null
	var request_distance:Variant=null;var request_reach:Variant=null;var selected_normal:Variant=null;var selected_key:=""
	var anchor:=0;var start_tick:=0;var loaded:=false;var retained_at_end:=false
	for row:Dictionary in virtual_rows:
		var destination:Dictionary=row.hands[1]
		for edge:Dictionary in row.canonical_input.requested.get("button_edges",[]):
			if int(edge.hand)==1 and edge.pressed and request_distance==null:
				request_distance=destination.get("shoulder_distance_m");request_reach=destination.reach_m
				for pick:Dictionary in row.target.get("picks",[]):
					if int(pick.hand)==1 and pick.get("audit",{}).get("winner") is Dictionary:
						selected_normal=pick.audit.winner.local_normal;selected_key=pick.audit.winner.collider_key
		if destination.state=="ATTACHED" and destination.support.key=="catch":
			if contact==null:contact=row.tick
			if row.hands[0].state=="FREE":
				if source_free==null:source_free=row.tick
				if anchor!=int(destination.anchor_runtime_id):
					anchor=int(destination.anchor_runtime_id);start_tick=int(row.tick);loaded=false;retained_at_end=false
				loaded=loaded or Vector3(destination.force_n).length()>1
				if float(int(row.tick)-start_tick)/hz>=.6 and loaded:
					if retained==null:retained=row.tick
					retained_at_end=true
			else:anchor=0;loaded=false;retained_at_end=false
		else:anchor=0;loaded=false;retained_at_end=false
	return {"real_contact":contact!=null,"retained":retained_at_end,"retained_at_end":retained_at_end,"contact_tick":contact,"source_free_tick":source_free,"retained_tick":retained,"loaded":loaded,"request_distance_m":request_distance,"request_reach_m":request_reach,"beyond_static_reach":request_distance!=null and request_reach!=null and float(request_distance)>float(request_reach)+.02,"selected_destination_key":selected_key,"selected_local_normal":selected_normal,"known_underside_selected":selected_key=="catch" and selected_normal is Vector3 and Vector3(selected_normal)==Vector3.DOWN,"scope":"actual contacts and same runtime material anchor, B1 and ground contributions retained; original beyond-static .02m policy margin"}
