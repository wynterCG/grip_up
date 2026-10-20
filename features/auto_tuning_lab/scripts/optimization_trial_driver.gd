extends Node
## Reusable explicit benchmark driver. Instantiate in an isolated test scene.
## All locomotion uses ordinary actions/pointer buttons and existing controllers.
signal finished(result:Dictionary)
const Loader=preload("res://features/auto_tuning_lab/scripts/optimization_override_loader.gd")
const TrialLab=preload("res://features/auto_tuning_lab/scripts/optimization_trial_lab.gd")
const Metrics=preload("res://features/locomotion_test_suite/scripts/movement_metrics.gd")
const Recorder=preload("res://features/locomotion_test_suite/scripts/session_recorder.gd")
const Course=preload("res://features/locomotion_test_suite/scripts/mastery_course.gd")
const Response=preload("res://features/auto_tuning_lab/scripts/response_metrics.gd")
const FirstAscent=preload("res://features/auto_tuning_lab/scripts/first_ascent_trial_exercise.gd")
const Canary=preload("res://features/auto_tuning_lab/scripts/optimization_canary_fixture.gd")
const TRAIN="res://features/auto_tuning_lab/resources/train_scenarios.json"
var app
var candidate:Dictionary={}
var loader=Loader.new()
var hz:=120
var active:=false
var running:=false
var cancelled:=false
var metrics=Metrics.new()
var response=Response.new()
var violations:Dictionary={}
var capture:Dictionary={}
var contacts:Dictionary={}
var peaks:Dictionary={}
var trace:Array[Dictionary]=[]
var last_row:Dictionary={}
var _keys:Array=[]
var _epoch:=0.0
var _clock_start:=0
var _work_goal:="NEUTRAL"
var _swing_positive:=0.0
var _swing_negative:=0.0
var _swing_matched:=0.0
var _swing_total:=0.0
var _supported_ticks:=0
var _measurement_ticks:=0
var _retention_requirement:=.6
var _baseline_profile_ok:=true
var _all_installs_pre_step:=true
var _phase_work:Dictionary={}
var _course:Node
var _target_capture:Dictionary={}
var _pendulum_min:=INF
var _pendulum_max:=-INF
var _phase_angles:Dictionary={}
var _measurement_initial:Dictionary={}
var _initial_anchors:Dictionary={}
var _source_anchor_intact:=true
var _ground_seen:=false
var _ungrounded_supported_samples:=0
var _ground_time:=0.0
var _ground_motor_work:=0.0
var _ground_torque_work:=0.0
var _native_ground_force_peak:=0.0
var _native_ground_moment_peak:=0.0
var _hybrid_window_closed:=false

func _frozen_parameters_valid()->bool:
	var t:Resource=app.controller.tuning
	for key in candidate.parameter_overrides:
		if not is_equal_approx(float(t.get(key)),float(candidate.parameter_overrides[key])):return false
	for key in loader.space.frozen:
		var value:Variant=null
		if key=="body_mass":value=app.torso.mass
		elif key=="foot_total_force_budget":value=app.controller.feet_solver.tuning.total_force_budget
		elif key=="foot_max_force_per_foot":value=app.controller.feet_solver.tuning.max_force_per_foot
		else:value=t.get(key)
		if not Loader.numeric(value) or absf(float(value)-float(loader.space.frozen[key]))>.00001:return false
	return true

func _reset_episode()->void:
	violations={"force_budget_violation":false,"unphysical_grip":false,"direct_body_transform_mutation":false,"solver_nonfinite":false,"pending_support_force":false,"unauthorized_air_actuation":false,"authority_conflict":false,"protected_parameter_changed":false}
	capture={"selected_requests":0,"contacts":0,"retained":0,"missed_replay_targets":0,"failure_reasons":[]}
	contacts.clear();trace.clear();last_row.clear()
	peaks={"hand_force_n":0.0,"foot_force_n":0.0,"assist_nm":0.0,"combined_moment_nm":0.0,"body_acceleration_proxy_m_s2":0.0,"foot_load_n":0.0}
	_swing_positive=0;_swing_negative=0;_swing_matched=0;_swing_total=0;_supported_ticks=0;_measurement_ticks=0
	active=false;_work_goal="NEUTRAL"
	_hybrid_window_closed=false
	_pendulum_min=INF;_pendulum_max=-INF;_phase_angles.clear();_measurement_initial.clear();_initial_anchors.clear();_source_anchor_intact=true;_ground_seen=false;_ungrounded_supported_samples=0;_ground_time=0;_ground_motor_work=0;_ground_torque_work=0;_native_ground_force_peak=0;_native_ground_moment_peak=0
	_phase_work={"DRIVE":{"positive_j":0.0,"negative_j":0.0,"duration_s":0.0},"COUNTER":{"positive_j":0.0,"negative_j":0.0,"duration_s":0.0},"NEUTRAL":{"positive_j":0.0,"negative_j":0.0,"duration_s":0.0}}
	_target_capture={"selected":false,"contact":false,"retained":false,"destination_alone":false}

func _hard_failed()->bool:return violations.values().any(func(value):return bool(value))

func _set_keys(keys:Array)->void:
	for action in ["contract","extend","bias_left","bias_right"]:
		if not InputMap.has_action(action):continue
		if action in keys:Input.action_press(action)
		else:Input.action_release(action)
	_keys=keys.duplicate()

func _release_all()->void:
	_set_keys([])
	for action in ["grip_left","grip_right","launch"]:
		if InputMap.has_action(action):Input.action_release(action)
	if is_instance_valid(app):
		for id in 2:app._release_hand_input(id,"input_released")

func _tick(seconds:float)->void:
	for frame in maxi(1,int(round(seconds*hz))):
		await get_tree().physics_frame
		if cancelled or _hard_failed():break
		if float(Time.get_ticks_msec()-_clock_start)/1000.0>float(candidate.timeout_seconds):cancelled=true;break

func _aim(point:Vector3)->void:
	var event:=InputEventMouseMotion.new()
	event.position=app.camera.unproject_position(point)
	event.relative=event.position-app.pointer;event.screen_relative=event.relative
	Input.parse_input_event(event.xformed_by(get_tree().root.get_final_transform()))
	Input.flush_buffered_events()

func _button(id:int,down:bool)->void:
	var event:=InputEventMouseButton.new()
	event.position=app.pointer;event.button_index=MOUSE_BUTTON_LEFT if id==0 else MOUSE_BUTTON_RIGHT;event.pressed=down
	Input.parse_input_event(event.xformed_by(get_tree().root.get_final_transform()))
	Input.flush_buffered_events()

func _grip(id:int,point:Vector3,timeout:float=1.5)->bool:
	capture.selected_requests+=1
	var requested_shoulder:Vector3=app.controller.get_shoulder_world(id)
	_aim(point);_button(id,true)
	var request_result:Dictionary={"shoulder":requested_shoulder,"distance":requested_shoulder.distance_to(point),"last_rejection":app.controller.last_rejection,"attempt":app.controller.transfer_diagnostics().last_by_hand.get(id,{}).duplicate(true)}
	for frame in int(timeout*hz):
		await _tick(1.0/hz)
		if _hard_failed() or cancelled:return false
		if app.controller.get_hand_state(id)=="ATTACHED":return true
	capture.missed_replay_targets+=1
	capture.failure_reasons.append({"id":id,"reason":app.controller.hands[id].reason,"requested_point":point,"physical_state":app.controller.get_hand_state(id),"request_result":request_result})
	return false

func _transfer(event:Dictionary)->void:
	var id:int=int(event.get("hand",-1))
	var code:String=str(event.get("code",""))
	var type:String={"ATTEMPT_STARTED":"attempt","SUCCESS":"contact","GRIP_SLIP":"slip","RELEASED":"release","CANCELLED":"release"}.get(code,"diagnostic")
	if active:metrics.record_event({"type":type,"time":float(event.time),"tick":int(event.step),"hand_id":id,"attempt_id":"%s:%s"%[event.get("session",0),event.get("attempt_id",0)]})
	if code=="SUCCESS" and id in [0,1]:
		capture.contacts+=1
		var hand:Dictionary=app.controller.hands[id]
		if hand.anchor!=null:contacts[id]={"anchor":hand.anchor.get_instance_id(),"time":float(event.time),"retained":false}

func _sample(delta:float)->void:
	if not is_instance_valid(app):return
	violations.protected_parameter_changed=violations.protected_parameter_changed or not _frozen_parameters_valid()
	var state:Dictionary=app.controller.telemetry()
	if state.is_empty():return
	var moment:Vector3=state.get("combined_ground_climb_torque",Vector3(state.torque)+app.ground_motor.applied_torque)
	var assist:Vector3=state.get("assist_torque",Vector3.ZERO)
	peaks.hand_force_n=maxf(peaks.hand_force_n,float(state.total_force));peaks.foot_force_n=maxf(peaks.foot_force_n,float(state.leg_force))
	peaks.assist_nm=maxf(peaks.assist_nm,assist.length());peaks.combined_moment_nm=maxf(peaks.combined_moment_nm,moment.length())
	violations.force_budget_violation=violations.force_budget_violation or state.total_force>360.001 or state.leg_force>180.001 or assist.length()>20.001 or moment.length()>150.001
	violations.solver_nonfinite=violations.solver_nonfinite or not app.torso.global_position.is_finite() or not app.torso.linear_velocity.is_finite() or not app.torso.angular_velocity.is_finite() or not moment.is_finite() or not assist.is_finite()
	for id in 2:
		var hand:Dictionary=app.controller.hands[id]
		var force:Vector3=app.controller.get_arm_force(id)
		violations.solver_nonfinite=violations.solver_nonfinite or not force.is_finite() or not app.controller.get_hand_world(id).is_finite()
		if hand.state=="REACHING" and force.length()>.0001:violations.pending_support_force=true
		if hand.state in ["ATTACHED","SLIPPING"]:
			var legal:bool=hand.anchor!=null and hand.anchor.is_valid()
			if legal:legal=app.controller.get_shoulder_world(id).distance_to(hand.anchor.world_point())<=app.controller.tuning.max_arm_length+app.controller.tuning.max_elastic_extension+.002
			violations.unphysical_grip=violations.unphysical_grip or not legal
		if contacts.has(id):
			var valid:bool=hand.state=="ATTACHED" and hand.anchor!=null and hand.anchor.get_instance_id()==contacts[id].anchor
			if not valid:contacts.erase(id)
			elif not contacts[id].retained and app.controller.simulation_time-float(contacts[id].time)>=_retention_requirement:
				contacts[id].retained=true;capture.retained+=1
	if app.controller.feet_solver!=null:
		for foot:Dictionary in app.controller.feet_solver.feet:
			var f:Vector3=foot.force
			peaks.foot_load_n=maxf(peaks.foot_load_n,f.length())
			violations.force_budget_violation=violations.force_budget_violation or f.length()>120.001
			if foot.state not in ["SUPPORTING","SLIDING"] and f.length()>.0001:violations.unphysical_grip=true
			var normal:Vector3=foot.normal
			var compression:float=f.dot(normal)
			var mu:float=app.controller.feet_solver.tuning.foot_friction
			if is_instance_valid(foot.support) and foot.support.physics_material_override!=null:mu=minf(mu,foot.support.physics_material_override.friction)
			if compression<-.0001 or (f-normal*compression).length()>mu*compression+.0001:violations.unphysical_grip=true
	if app.controller._attached_ids().is_empty() and state.leg_force<.0001 and not app.ground_motor.grounded:
		violations.unauthorized_air_actuation=violations.unauthorized_air_actuation or state.total_force>.0001 or assist.length()>.0001 or app.ground_motor.applied_force.length()>.0001
	if app.controller.assisted_motion_owned and (state.total_force>.0001 or state.leg_force>.0001):violations.authority_conflict=true
	last_row=app.controller.locomotion_observer.data.duplicate(true)
	if last_row.is_empty():return
	last_row["accepted_input"]=app.controller.intent_locomotion.requested
	last_row["accepted_input_time"]=app.controller.intent_locomotion.data.get("input_timestamp",null)
	last_row["target_accelerations"]=app.controller.intent_locomotion.data.get("target_accelerations",{}).duplicate(true)
	var anchor_ids:Dictionary={}
	for id in 2:
		var anchor=app.controller.hands[id].anchor
		if anchor!=null and app.controller.hands[id].state in ["ATTACHED","SLIPPING"]:anchor_ids[id]=anchor.get_instance_id()
	last_row["target_anchor_ids"]=anchor_ids
	peaks.body_acceleration_proxy_m_s2=maxf(peaks.body_acceleration_proxy_m_s2,Vector3(last_row.acceleration).length())
	if active:
		metrics.push(last_row)
		response.push(last_row)
		_measurement_ticks+=1
		for id in _initial_anchors:
			var hand:Dictionary=app.controller.hands[id]
			if hand.state!="ATTACHED" or hand.anchor==null or hand.anchor.get_instance_id()!=_initial_anchors[id]:_source_anchor_intact=false
		_ground_seen=_ground_seen or app.ground_motor.grounded
		if app.ground_motor.grounded:_ground_time+=delta
		_native_ground_force_peak=maxf(_native_ground_force_peak,app.ground_motor.applied_force.length())
		_native_ground_moment_peak=maxf(_native_ground_moment_peak,app.ground_motor.applied_torque.length())
		_ground_motor_work+=app.ground_motor.applied_force.dot(app.torso.linear_velocity)*delta
		_ground_torque_work+=app.ground_motor.applied_torque.dot(app.torso.angular_velocity)*delta
		var qualified_swing:bool=not app.ground_motor.grounded and not app.controller._attached_ids().is_empty()
		if qualified_swing:_ungrounded_supported_samples+=1
		var angle:Variant=last_row.get("pendulum_angle_rad")
		if qualified_swing and Loader.numeric(angle):
			_pendulum_min=minf(_pendulum_min,float(angle));_pendulum_max=maxf(_pendulum_max,float(angle))
			if not _phase_angles.has(_work_goal):_phase_angles[_work_goal]={"min_rad":float(angle),"max_rad":float(angle),"samples":0}
			_phase_angles[_work_goal].min_rad=minf(_phase_angles[_work_goal].min_rad,float(angle));_phase_angles[_work_goal].max_rad=maxf(_phase_angles[_work_goal].max_rad,float(angle));_phase_angles[_work_goal].samples+=1
		if not app.controller._attached_ids().is_empty():_supported_ticks+=1
		var motion:Dictionary=app.controller.transfer_diagnostics().motion
		var power:Variant=motion.get("swing_power",null)
		if qualified_swing and (power is float or power is int):
			_swing_positive+=maxf(0,float(power))*delta;_swing_negative+=minf(0,float(power))*delta
			_phase_work[_work_goal].positive_j+=maxf(0,float(power))*delta
			_phase_work[_work_goal].negative_j+=minf(0,float(power))*delta
			_phase_work[_work_goal].duration_s+=delta
			if _work_goal in ["DRIVE","COUNTER"]:
				_swing_total+=absf(float(power))*delta
				if (_work_goal=="DRIVE" and power>0) or (_work_goal=="COUNTER" and power<0):_swing_matched+=absf(float(power))*delta
		if trace.is_empty() or app.controller._step%maxi(1,hz/10)==0:
			trace.append({"time":last_row.time,"tick":last_row.tick,"com":last_row.get("com_position"),"position":last_row.body_position,"intent":last_row.movement_intent_world,"forces":[state.total_force,state.leg_force],"moment":moment,"hands":last_row.hands,"grounded":last_row.grounded,"swing_power":power})
			if trace.size()>1024:trace.pop_front()

func _implementation(definition:Dictionary)->String:
	return str(definition.get("implementation_id",definition.id))

func _contact_point(definition:Dictionary,id:int)->Vector3:
	var point:Vector3
	if definition.has("contact_points"):
		var data:Array=definition.contact_points[id];point=Vector3(data[0],data[1],data[2])
	else:
		var index:int=int(definition.get("contact_indices",{}).get(str(id),id))
		point=app.level.transfer_points[index]
	if definition.has("contact_y_offsets"):point.y+=float(definition.contact_y_offsets[id])
	if definition.has("near_reach_margin_m"):
		var shoulder:Vector3=app.controller.get_shoulder_world(id)
		var radius:float=app.controller.get_max_reach()-float(definition.near_reach_margin_m)
		point=Vector3(shoulder.x,shoulder.y+sqrt(maxf(0,radius*radius-shoulder.z*shoulder.z)),0)
	return point

func _fresh(definition:Dictionary)->void:
	_release_all()
	if is_instance_valid(app):
		loader.restore();app.queue_free();app=null
		await get_tree().physics_frame
	if is_instance_valid(_course):_course.queue_free();_course=null
	_reset_episode()
	app=TrialLab.new();app.override_loader=loader;app.trial_candidate=candidate
	get_tree().root.add_child(app);get_tree().current_scene=app
	_baseline_profile_ok=_baseline_profile_ok and app.input_profile==2
	app._open_intent_arena(int(definition.arena),true)
	if definition.get("fixture","")=="existing_mastery_segment":
		_course=Course.new();add_child(_course)
		_course.apply_segment(app,int(definition.segment),bool(definition.get("mirrored",false))) # Explicit setup, before any simulation tick.
	if definition.has("initial_position_offset"):
		var offset:Array=definition.initial_position_offset
		app.torso.position+=Vector3(offset[0],offset[1],offset[2]) # Explicit fixture initialization BEFORE first physics tick.
	if definition.has("initial_velocity"):
		var speed:Array=definition.initial_velocity
		app.torso.linear_velocity=Vector3(speed[0],speed[1],speed[2]) # Authored unseen initial state, never live actuation.
	if definition.has("camera_yaw"):
		app.camera.yaw=float(definition.camera_yaw);app.camera._update_camera(1.0)
	app._set_physical_feet(bool(definition.get("physical_feet",true)))
	app._set_movement_allocation(0);app._set_intent_aware_feet(false);app._set_distant_targeting(bool(definition.get("policy",{}).get("persistent_target",false)))
	app._set_locomotion_diagnostics(true);app.transfer_diagnostics_enabled=true;app._apply_independent_settings()
	if definition.has("control_profile_override"):app._set_input_profile(int(definition.control_profile_override))
	app.won=true;app.settings.hide()
	app.controller.sample_ready.connect(_sample);app.controller.transfer_event.connect(_transfer)
	for entry:Dictionary in app.installs:_all_installs_pre_step=_all_installs_pre_step and entry.before_first_step
	await _tick(float(definition.get("warmup_s",.45)))

func _begin(direction:Vector3,goal:float)->bool:
	if last_row.is_empty():return false
	_measurement_initial={"body_pose":app.torso.global_transform,"com":last_row.get("com_position"),"velocity":app.torso.linear_velocity,"angular_velocity":app.torso.angular_velocity,"grounded":app.ground_motor.grounded,"camera_pose":app.camera.global_transform,"camera_fov":app.camera.fov,"viewport_size":get_viewport().get_visible_rect().size,"contact_snapshot":last_row.get("contacts",[]).duplicate(true),"hands":last_row.get("hands",[]).duplicate(true),"input_bindings":{},"observed_configuration":{"input_profile":app.input_profile,"controller_profile":app.controller.control_profile,"movement_allocation":app.controller.intent_locomotion.movement_allocation,"physical_feet":app.controller.tuning.physical_feet,"intent_aware_feet":app.controller.intent_aware_feet_enabled,"predictive_grip":app.controller.tuning.predictive_grip,"persistent_targets":app.controller.tuning.allow_out_of_reach_grip_targets,"hybrid_owned":app.controller.assisted_motion_owned}}
	for action in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:
		_measurement_initial.input_bindings[action]=InputMap.action_get_events(action).map(func(event):return event.as_text())
	for id in 2:
		var hand:Dictionary=app.controller.hands[id]
		if hand.state=="ATTACHED" and hand.anchor!=null:_initial_anchors[id]=hand.anchor.get_instance_id()
	var ok:bool=metrics.start(last_row,direction,{"physics_hz":hz,"target_progress_m":goal,"response_velocity_m_s":.02,"response_persistence_s":.05})
	response.start(last_row,direction)
	if last_row.accepted_input.length_squared()>.000001 and last_row.accepted_input_time!=null:metrics.record_event({"type":"command_onset","time":float(last_row.accepted_input_time),"tick":int(last_row.tick)-int(round((float(last_row.time)-float(last_row.accepted_input_time))*hz)),"velocity":last_row.velocity})
	_epoch=app.controller.simulation_time;active=ok
	return ok

func _fixed_tape(definition:Dictionary)->void:
	var total:float=float(definition.duration_s)+float(definition.settle_s)
	var index:=0
	for frame in int(round(total*hz)):
		var t:float=float(frame)/hz
		while index<definition.commands.size() and t+.000001>=float(definition.commands[index].time):
			var command:Dictionary=definition.commands[index]
			_set_keys(command["keys"]);_work_goal=command.get("work_goal","NEUTRAL");index+=1
		await _tick(1.0/hz)
		if cancelled or _hard_failed():break
	_set_keys([]);_work_goal="NEUTRAL"

func _run_scenario(definition:Dictionary)->Dictionary:
	var implementation:String=_implementation(definition)
	if implementation=="first_ascent":return await _first_ascent(definition)
	if implementation=="allocation_canary":return await _canary(definition)
	await _fresh(definition)
	var reason:=""
	if not app.override_error.is_empty():reason=app.override_error
	var ids:Array=definition.hands
	for id in ids:
		var point:Vector3=_contact_point(definition,int(id))
		if not await _grip(int(id),point):reason="MISSED_REPLAY_TARGET";break
	if definition.has("preparation_w_s"):
		_set_keys(["contract"]);await _tick(float(definition.preparation_w_s));_set_keys([]);await _tick(.15)
	if implementation=="swing_catch_train":
		_set_keys(["contract"]);await _tick(float(definition.policy.preload_w_s));await _tick(.1)
	else:await _tick(float(definition.get("pre_measurement_s",.15)))
	if definition.get("require_ungrounded",false) or implementation=="swing_catch_train":
		if app.ground_motor.grounded or app.controller._attached_ids().is_empty() or float(app.controller.telemetry().total_force)<1:reason="INVALID_START_NOT_LOADED_HANG"
	var direction:=Vector3(definition.direction[0],definition.direction[1],definition.direction[2])
	if not _begin(direction,float(definition.goal_progress_m)):reason="MISSING_ACTUAL_COM"
	if reason.is_empty():
		if implementation=="swing_catch_train":reason=await _catch(definition)
		elif implementation=="ground_grip_transition_train":
			_set_keys(["bias_right"]);await _tick(float(definition.walk_before_reach_s));_set_keys([])
			for id in 2:
				if id==1:
					_set_keys(definition.contact_policy.wait_input)
					var wait_started:float=app.controller.simulation_time
					for frame in int(float(definition.contact_policy.wait_before_second_max_s)*hz):
						var shoulder:Vector3=app.controller.get_shoulder_world(1)
						var intended:=Vector3(shoulder.x,float(definition.contact_policy.y),float(definition.contact_policy.z))
						if shoulder.distance_to(intended)<=app.controller.get_max_reach()-float(definition.contact_policy.reach_margin_m):break
						await _tick(1.0/hz)
					capture["second_reach_wait_s"]=app.controller.simulation_time-wait_started
				var selected:=Vector3(app.controller.get_shoulder_world(id).x,float(definition.contact_policy.y),float(definition.contact_policy.z))
				if not await _grip(id,selected):reason="MISSED_REPLAY_TARGET";break
			_set_keys(["contract"]);await _tick(float(definition.duration_s));_set_keys([]);await _tick(float(definition.settle_s))
		elif implementation=="two_stage_transfer":reason=await _two_stage(definition)
		elif implementation=="dynamic_support":reason=await _dynamic_support(definition)
		elif implementation=="persistent_pending":reason=await _pending_safety(definition)
		else:await _fixed_tape(definition)
	var measured:Dictionary=metrics.finish()
	var useful:Variant=measured.movement.useful_progress_m
	var completed:bool=reason.is_empty() and useful!=null and float(useful)>=float(definition.goal_progress_m) and not app.controller._attached_ids().is_empty()
	if implementation=="swing_catch_train":completed=reason.is_empty() and _target_capture.retained and _target_capture.destination_alone
	elif implementation=="one_hand_hang_train":
		completed=reason.is_empty() and not app.ground_motor.grounded and not _ground_seen and _source_anchor_intact and _pendulum_max-_pendulum_min>=float(definition.minimum_pendulum_band_rad) and float(_phase_work.DRIVE.positive_j)>float(definition.minimum_phase_signed_work_j) and -float(_phase_work.COUNTER.negative_j)>float(definition.minimum_phase_signed_work_j)
	if definition.get("forbid_ground_during_measurement",false) and (_ground_seen or _native_ground_force_peak>.0001 or _native_ground_moment_peak>.0001):
		completed=false;reason="NATIVE_GROUND_CONTAMINATED"
	if implementation in ["two_stage_transfer","dynamic_support","persistent_pending"]:completed=reason.is_empty()
	if implementation=="unsupported_intent":completed=reason.is_empty() and app.controller._attached_ids().is_empty() and not app.ground_motor.grounded and peaks.hand_force_n==0 and peaks.foot_force_n==0
	if not bool(definition.get("physical_feet",true)):completed=completed and peaks.foot_load_n==0
	if definition.has("require_foot_load_n"):completed=completed and peaks.foot_load_n>=float(definition.require_foot_load_n)
	if not completed and reason.is_empty():reason="GOAL_NOT_REACHED"
	var swing_control:Variant=null
	var drive_work:float=_phase_work.DRIVE.positive_j-_phase_work.DRIVE.negative_j
	var counter_work:float=_phase_work.COUNTER.positive_j-_phase_work.COUNTER.negative_j
	if implementation=="one_hand_hang_train" and drive_work>.000001 and counter_work>.000001:swing_control=_swing_matched/_swing_total*float(_supported_ticks)/maxi(1,_measurement_ticks)
	var row:Dictionary={"id":definition.id,"revision":int(definition.revision),"status":"completed" if completed else "failed_task","completed":completed,"reason":reason,"scope":definition.scope,"driver":definition.driver,"capture":capture.duplicate(true),"invariants":violations.duplicate(true),"peaks":peaks.duplicate(true),"measurement":measured,"applied_parameters":candidate.parameter_overrides.duplicate(true),"metrics":{"useful_displacement_m":useful,"movement_latency_s":measured.response.latency_s,"directional_efficiency":measured.movement.directional_efficiency,"overshoot_m":measured.movement.overshoot_m,"reversal_latency_s":null,"unwanted_twist_rms_rad":measured.rotation.twist_rms_rad,"grip_retention_rate":float(capture.retained)/float(capture.contacts) if capture.contacts>0 else null,"controllable_swing":swing_control,"positive_swing_work_j":_swing_positive,"negative_swing_work_j":_swing_negative,"foot_loaded_time_fraction":measured.support.foot_loaded_time_fraction,"partial_actuator_work_j":measured.support.partial_actuator_work_j,"max_acceleration_proxy_m_s2":peaks.body_acceleration_proxy_m_s2,"stop_distance_m":null,"metric_reasons":{"reversal_latency_s":"NOT_YET_INSTRUMENTED","stop_distance_m":"NOT_YET_INSTRUMENTED","controllable_swing":"signed-work phase match only in declared one-hand DRIVE/COUNTER tape; not human skill","acceleration":"includes gravity/contact impulses; collision attribution unavailable","work":"applied contact forces only; ground and torque excluded"}},"trace":trace.duplicate(true)}
	active=false;_release_all()
	row["implementation_id"]=implementation
	row["initial_conditions"]=_measurement_initial.duplicate(true)
	row["installations"]=app.installs.duplicate(true)
	row["swing_phase_work"]= _phase_work.duplicate(true)
	row["swing_phase_angles"]=_phase_angles.duplicate(true)
	row["source_anchor_intact"]=_source_anchor_intact
	row["ground_contact_during_measurement"]=_ground_seen
	row["native_ground_authority_observed"]=_native_ground_force_peak>.0001 or _native_ground_moment_peak>.0001
	row["native_ground_force_peak_n"]=_native_ground_force_peak
	row["native_ground_moment_peak_nm"]=_native_ground_moment_peak
	row["ground_measurement"]={"time_s":_ground_time,"motor_body_work_j":_ground_motor_work,"torque_body_work_j":_ground_torque_work,"scope":"actual central motor force dot body velocity plus actual torque dot angular velocity; work on support excluded"}
	row["ungrounded_supported_samples"]=_ungrounded_supported_samples
	row["pendulum_band_rad"]=null
	if is_finite(_pendulum_min) and is_finite(_pendulum_max):row.pendulum_band_rad=_pendulum_max-_pendulum_min
	row["target_capture"]=_target_capture.duplicate(true)
	var response_data:Dictionary=response.finish()
	row["measurement_response"]=response_data
	for key in ["stop_distance_m","reversal_latency_s","target_jerk_rms_m_s3","target_jerk_peak_m_s3"]:row.metrics[key]=response_data.get(key,null)
	row.metrics.metric_reasons.erase("reversal_latency_s");row.metrics.metric_reasons.erase("stop_distance_m")
	row.metrics.metric_reasons["response"]={"stops":response_data.stops.map(func(event):return event.reason),"reversals":response_data.reversals.map(func(event):return event.reason),"missing_events":"No accepted stop/reverse event leaves the corresponding scalar null"}
	if implementation=="swing_catch_train":row.metrics.grip_retention_rate=1.0 if _target_capture.retained else 0.0
	if reason=="NATIVE_GROUND_CONTAMINATED":
		row.metrics.useful_displacement_m=null;row.metrics.metric_reasons["useful_displacement_m"]="NATIVE_GROUND_CONTAMINATED; raw signed displacement retained under measurement.movement"
	row["swing_proxy_scope"]="Actual incremental torque work; requires both DRIVE and COUNTER observed work. Null if either phase is unmeasured/zero; no all-roll penalty."
	return row

func _catch(definition:Dictionary)->String:
	var target:Vector3=app.level.transfer_points[1];target.x+=float(definition.policy.target_x_offset)
	var free_shoulder:Vector3=app.controller.get_shoulder_world(1)
	var original_distance:float=free_shoulder.distance_to(target)
	capture["pre_swing_free_shoulder"]=free_shoulder;capture["selected_target"]=target;capture["selected_pre_swing_distance"]=original_distance
	if original_distance<=app.controller.get_max_reach()+.02:return "INITIAL_TARGET_NOT_OUTSIDE_STATIC_REACH"
	_aim(target);_button(1,true);capture.selected_requests+=1;_target_capture.selected=true
	await _tick(.05)
	if app.controller.get_hand_state(1)=="REACHING" and app.controller.get_arm_force(1).length()>.0001:violations.pending_support_force=true;return "PRECONTACT_TARGET_FORCE"
	var caught:=false
	for frame in int(float(definition.policy.max_swing_s)*hz):
		var lever:Vector3=app.controller.get_shoulder_world(0)-app.torso.global_position
		var axis:Vector3=Vector3.RIGHT.cross(lever.normalized()).normalized()
		var speed:float=app.torso.angular_velocity.dot(axis)
		_set_keys(["contract","bias_right" if speed>=float(definition.policy.angular_phase_threshold) else "bias_left"])
		await _tick(1.0/hz)
		if _hard_failed() or cancelled:return "INTERRUPTED"
		if app.controller.get_hand_state(1)=="ATTACHED":caught=true;break
	if not caught:return "NO_REAL_CATCH"
	_target_capture.contact=true
	var anchor=app.controller.hands[1].anchor
	var anchor_id:int=anchor.get_instance_id()
	var actual_point:Vector3=anchor.world_point()
	var actual_pre_distance:float=free_shoulder.distance_to(actual_point)
	capture["actual_anchor_pre_swing_distance"]=actual_pre_distance
	if actual_pre_distance<=app.controller.get_max_reach()+.02:return "CATCH_WAS_NOT_BEYOND_STATIC_REACH"
	var brake:String="bias_left" if app.torso.linear_velocity.x>0 else "bias_right"
	_set_keys(["contract",brake]);await _tick(float(definition.policy.post_catch_brake_s))
	_button(0,false);await _tick(float(definition.policy.post_source_release_brake_s));_set_keys(["contract"])
	for frame in int(.6*hz):
		await _tick(1.0/hz)
		var hand:Dictionary=app.controller.hands[1]
		if hand.state!="ATTACHED" or hand.anchor==null or hand.anchor.get_instance_id()!=anchor_id:return "CATCH_NOT_RETAINED"
	_target_capture.retained=true;_target_capture.destination_alone=app.controller.get_hand_state(0)!="ATTACHED"
	return ""

func _two_stage(definition:Dictionary)->String:
	_set_keys(["contract"]);await _tick(float(definition.policy.initial_w_s))
	var policy:Dictionary=definition.policy
	for number in 2:
		var hand_id:int=int(policy.first_hand if number==0 else policy.second_hand)
		var index:int=int(policy.first_point_index if number==0 else policy.second_point_index)
		var previous=app.controller.hands[1-hand_id].anchor
		_button(hand_id,false)
		if previous==null or app.controller.hands[1-hand_id].anchor!=previous:return "TRANSFER_SUPPORT_LOST"
		_aim(app.level.transfer_points[index]);_button(hand_id,true);capture.selected_requests+=1
		for frame in int(float(policy.transfer_timeout_s)*hz):
			_set_keys(["contract",policy.second_lateral_action] if number==1 and float(frame)/hz<float(policy.second_lateral_s) else ["contract"])
			await _tick(1.0/hz)
			if app.controller._attached_ids().is_empty():return "TRANSFER_SUPPORT_LOST"
			if app.controller.get_hand_state(hand_id)=="ATTACHED":break
		if app.controller.get_hand_state(hand_id)!="ATTACHED":return "MISSED_REPLAY_TARGET"
		await _tick(float(policy.settle_s))
	_set_keys([]);await _tick(float(definition.settle_s))
	return ""

func _dynamic_support(definition:Dictionary)->String:
	var beam:RigidBody3D=app.level.beam
	var initial:Transform3D=beam.global_transform
	var local:Array=definition.policy.local_point
	if not await _grip(int(definition.policy.hand),beam.to_global(Vector3(local[0],local[1],local[2]))):return "MISSED_REPLAY_TARGET"
	_set_keys(["contract"]);await _tick(float(definition.policy.w_s));_set_keys([]);await _tick(float(definition.policy.settle_s))
	var rotated:float=(beam.global_basis*initial.basis.inverse()).get_rotation_quaternion().get_angle()
	capture["dynamic_support"]={"initial_pose":initial,"final_pose":beam.global_transform,"angular_velocity":beam.angular_velocity,"linear_velocity":beam.linear_velocity,"rotation_rad":rotated,"scope":"actual hinged support, pair momentum includes external hinge/gravity; not an isolated conservation proof"}
	if app.controller.get_hand_state(int(definition.policy.hand))!="ATTACHED":return "DYNAMIC_SUPPORT_NOT_RETAINED"
	if rotated<float(definition.policy.minimum_rotation_rad) or peaks.hand_force_n<1:return "DYNAMIC_SUPPORT_NOT_LOADED"
	return ""

func _pending_safety(definition:Dictionary)->String:
	var original=app.controller.hands[0].anchor
	var p:Array=definition.policy.point
	_aim(Vector3(p[0],p[1],p[2]));_button(1,true);capture.selected_requests+=1
	await _tick(float(definition.policy.pending_s))
	capture["pending_observed"]={"state":app.controller.get_hand_state(1),"force":app.controller.get_arm_force(1),"diagnostics":app.controller.pending_diagnostics(1),"source_preserved":app.controller.hands[0].anchor==original}
	var valid:bool=app.controller.get_hand_state(1)=="REACHING" and app.controller.get_arm_force(1)==Vector3.ZERO and app.controller.hands[0].anchor==original
	_button(1,false);await _tick(.05)
	capture["pending_cancelled"]=app.controller.get_hand_state(1) in ["FREE","RELEASED"]
	if not valid or not capture.pending_cancelled:return "PENDING_SAFETY_FAILED"
	return ""

func _first_ascent_cancelled()->bool:
	# The exercise owns its tick loop, so it must latch the same deadline state
	# used by run_trial's final status rather than only returning an abort hint.
	if float(Time.get_ticks_msec()-_clock_start)/1000.0>float(candidate.timeout_seconds):cancelled=true
	return cancelled or _hard_failed()

func _first_ascent(definition:Dictionary)->Dictionary:
	_release_all();loader.restore()
	if is_instance_valid(app):app.queue_free();app=null;await get_tree().physics_frame
	_reset_episode()
	var exercise=FirstAscent.new();add_child(exercise);exercise.hz=hz
	exercise.cancel_check=_first_ascent_cancelled
	exercise.physics_controller_ready.connect(func(lab,controller):
		app=lab
		controller.transfer_event.connect(_transfer))
	exercise.observed.connect(func(lab,delta):
		app=lab
		if lab.controller.assisted_motion_owned:active=false;_hybrid_window_closed=true
		_sample(delta)
		if not active and not _hybrid_window_closed and lab.level.get("scenario")=="FIRST_ASCENT" and not last_row.is_empty():_begin(Vector3.UP,0.0))
	var report:Dictionary=await exercise.run_candidate(candidate,loader)
	_baseline_profile_ok=_baseline_profile_ok and bool(report.get("startup_profile_preserved",false))
	for entry:Dictionary in app.installs:_all_installs_pre_step=_all_installs_pre_step and bool(entry.before_first_step)
	active=false
	var measured:Dictionary=metrics.finish()
	var row:Dictionary={"id":definition.id,"revision":int(definition.revision),"implementation_id":"first_ascent","scope":definition.scope,"driver":"existing_first_ascent_exercise_feedback_policy","completed":report.get("completed",false),"status":"completed" if report.get("completed",false) else "failed_task","reason":"" if report.get("completed",false) else "FIRST_ASCENT_NOT_COMPLETED","capture":capture.duplicate(true),"invariants":violations.duplicate(true),"metrics":{"useful_displacement_m":null,"movement_latency_s":null,"unwanted_twist_rms_rad":null,"controllable_swing":null,"grip_retention_rate":float(capture.retained)/maxi(1,int(capture.contacts)),"partial_actuator_work_j":null,"metric_reasons":{"work":"full route includes assisted hybrid phase; no combined physical work/progress ranking claim; measurement stops on first assistance, actual phase COM paths in exercise.phase_summary"}},"measurement":measured,"measurement_scope":"pre-assistance dynamic window only; never bridges cached hybrid observer poses","initial_conditions":_measurement_initial.duplicate(true),"peaks":peaks.duplicate(true),"exercise":report,"applied_parameters":candidate.parameter_overrides.duplicate(true),"trace":trace.duplicate(true)}
	exercise.queue_free()
	return row

func _canary(definition:Dictionary)->Dictionary:
	_release_all();loader.restore()
	if is_instance_valid(app):app.queue_free();app=null;await get_tree().physics_frame
	_reset_episode()
	var fixture=Canary.new();add_child(fixture)
	var row:Dictionary=await fixture.run_case(definition,candidate,loader,hz)
	violations=row.invariants.duplicate(true)
	fixture.queue_free()
	return row

func run_trial(manifest:Dictionary)->Dictionary:
	if running:return {"status":"failed_runtime","reason":"DRIVER_ALREADY_RUNNING"}
	running=true;candidate=manifest.duplicate(true);_clock_start=Time.get_ticks_msec()
	var checked:Dictionary=loader.validate(candidate)
	if not checked.ok:running=false;return {"schema_version":"1.0","trial_id":candidate.get("trial_id",""),"candidate_id":candidate.get("candidate_id",""),"status":"invalid_candidate","reason":checked.reason,"validation":checked}
	var previous_hz:int=Engine.physics_ticks_per_second
	hz=int(candidate.requested_physics_hz)
	var scenario_path:String=TRAIN
	if candidate.evaluation_split=="holdout":scenario_path="res://features/auto_tuning_lab/holdout/scenarios.json"
	elif candidate.evaluation_split=="safety":scenario_path="res://features/auto_tuning_lab/resources/safety_scenarios.json"
	if not FileAccess.file_exists(scenario_path):running=false;return {"status":"unsupported_scenario","reason":"SPLIT_NOT_IMPLEMENTED"}
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(scenario_path))
	if candidate.input_trace_id!=catalog.get("input_trace_id",""):
		running=false;return {"status":"invalid_candidate","reason":"INPUT_TRACE_ID_MISMATCH"}
	var actual_hash:String=str(Engine.get_version_info().hash)
	if FileAccess.get_sha256(OS.get_executable_path())!=candidate.engine_identity.sha256 or not str(candidate.engine_identity.version).contains(actual_hash.substr(0,9)):
		running=false;return {"status":"invalid_candidate","reason":"ENGINE_IDENTITY_MISMATCH"}
	var supported:Array=["vertical_pull_train","asymmetric_pull_train","lateral_traverse_train","one_hand_hang_train","swing_catch_train","foot_supported_step_train","ground_grip_transition_train","two_stage_transfer","dynamic_support","allocation_canary","first_ascent","unsupported_intent","persistent_pending"]
	for item:Dictionary in catalog.scenarios:
		if _implementation(item) not in supported:
			running=false;return {"status":"unsupported_scenario","reason":"UNKNOWN_IMPLEMENTATION:"+_implementation(item)}
	for id in candidate.scenarios:
		if not catalog.scenarios.any(func(item):return item.id==id):
			running=false;return {"status":"unsupported_scenario","reason":"UNKNOWN_SCENARIO:"+str(id)}
	Engine.physics_ticks_per_second=hz
	var definitions:Dictionary={}
	for item:Dictionary in catalog.scenarios:definitions[item.id]=item
	var results:Array=[]
	var overall:Dictionary={}
	var status:="completed"
	for id in candidate.scenarios:
		if not definitions.has(id):status="unsupported_scenario";break
		var row:Dictionary=await _run_scenario(definitions[id])
		results.append(row)
		for key in row.invariants:overall[key]=overall.get(key,false) or row.invariants[key]
		if _hard_failed():status="failed_invariant";break
		if cancelled:status="timed_out";break
	var restore:Dictionary=loader.restore()
	_release_all()
	if is_instance_valid(app):
		app._set_input_profile(2)
		_baseline_profile_ok=_baseline_profile_ok and app.input_profile==2
		app.queue_free();app=null
	var final_sources:Dictionary=loader.validate(candidate)
	var result:Dictionary={"schema_version":"1.0","trial_id":candidate.trial_id,"candidate_id":candidate.candidate_id,"status":status,"parameter_overrides":candidate.parameter_overrides.duplicate(true),"environment":{"repository_commit":candidate.repository_commit,"repository_identity_scope":"parent-observed Git revision; every listed source hash independently checked in Godot","source_hashes":checked.source_hashes,"sources_after":final_sources.get("source_hashes",{}),"engine_version":Engine.get_version_info().hash,"engine_release":Engine.get_version_info().string,"engine_binary_sha256":FileAccess.get_sha256(OS.get_executable_path()),"physics_backend":ProjectSettings.get_setting("physics/3d/physics_engine"),"physics_hz":hz,"scenario_hash":FileAccess.get_sha256(scenario_path),"input_trace_id":catalog.input_trace_id,"evaluation_split":candidate.evaluation_split,"run_seed":candidate.run_seed},"invariants":overall,"enforcement_scope":{"direct_body_transform_mutation":"static audited evaluator/whitelist/source identity, not a runtime body-write detector","runtime":"post-budget force/moment, pending force, support legality, nonfinite, airborne actuation and hybrid ownership observed"},"restoration":{"resources":restore,"startup_profile_restored":_baseline_profile_ok,"all_overrides_before_first_physics_step":_all_installs_pre_step},"scenarios":results,"metrics":{},"artifacts":{"trace_storage":"bounded per-scenario numeric trace embedded in result; not a recording of human input"},"elapsed_wall_seconds":float(Time.get_ticks_msec()-_clock_start)/1000.0}
	if not restore.originals_preserved or not final_sources.ok or not _all_installs_pre_step:result.status="failed_invariant";result.reason="RESTORE_SOURCE_OR_INSTALL_GUARD"
	Engine.physics_ticks_per_second=previous_hz
	result.restoration["physics_hz_restored"]=Engine.physics_ticks_per_second==previous_hz
	running=false;finished.emit(result)
	return result
