extends RefCounted
## Pure numerical snapshot analysis. No node, input, server or world access.
## Time is seconds; tick is supplied physics tick, never renderer frame.
var _config:Dictionary={}
var _samples:Array[Dictionary]=[]
var _events:Array[Dictionary]=[]
var _attempts:Dictionary={}
var _running:=false
var _direction:=Vector3.ZERO
var _reference:="com"
var _initial:Dictionary={}
var _previous:Dictionary={}
var _windows:Dictionary={}
var _path:=0.0
var _twist_square_time:=0.0
var _twist_time:=0.0
var _twist_peak:=0.0
var _saturated_time:=0.0
var _saturation_known_time:=0.0
var _foot_loaded_time:=0.0
var _contact_known_time:=0.0
var _foot_load_integral:=0.0
var _support_load_integral:=0.0
var _work:=0.0
var _relative_work:=0.0
var _work_known_time:=0.0
var _relative_work_known_time:=0.0
var _work_missing_time:=0.0
var _last_intent:=Vector3.ZERO
var _corrections:=0
var _reversals:=0
var _onset:Dictionary={}
var _response_candidate:Variant=null
var _latency:Variant=null
var _counts:Dictionary={}
var _quality:Dictionary={}
var _max_overshoot:=0.0
var _settle_start:Variant=null
var _stop_time:Variant=null
var _settle_candidate:Variant=null
var _settle_first_confirmed:Variant=null
var _settled:=false
var _settle_missing:=false

func configure(options:Dictionary={})->void:
	_config={"reference":"com","max_samples":512,"max_events":128,"path_epsilon_m":.01,"response_velocity_m_s":.05,"response_acceleration_m_s2":.5,"response_mode":"velocity","response_persistence_s":.05,"loaded_force_n":1.0,"intent_epsilon":.001,"correction_angle_rad":deg_to_rad(20.0),"reversal_dot":-.2,"contacts_are_applied":false,"gravity_up":Vector3.UP,"target_progress_m":null,"target_corridor_m":.02,"settle_linear_m_s":.1,"settle_angular_rad_s":.2,"settle_hold_s":.25}
	_config.merge(options,true)
	_config.max_samples=clampi(int(_config.max_samples),2,8192)
	_config.max_events=clampi(int(_config.max_events),1,1024)
	_config.path_epsilon_m=maxf(.000001,float(_config.path_epsilon_m))
	_config.response_persistence_s=maxf(0.0,float(_config.response_persistence_s))
	reset()

func reset()->void:
	_samples.clear();_events.clear();_attempts.clear();_initial.clear();_previous.clear();_windows.clear();_onset.clear()
	_running=false;_direction=Vector3.ZERO;_last_intent=Vector3.ZERO
	_path=0;_twist_square_time=0;_twist_time=0;_twist_peak=0;_saturated_time=0;_saturation_known_time=0
	_foot_loaded_time=0;_contact_known_time=0;_foot_load_integral=0;_support_load_integral=0
	_work=0;_relative_work=0;_work_known_time=0;_relative_work_known_time=0;_work_missing_time=0
	_corrections=0;_reversals=0;_response_candidate=null;_latency=null
	_max_overshoot=0;_settle_start=null;_stop_time=null;_settle_candidate=null;_settle_first_confirmed=null;_settled=false;_settle_missing=false
	_counts={"attempts":0,"contacts":0,"retained":0,"releases":0,"slips":0}
	_quality={"accepted_samples":0,"rejected_samples":0,"evicted_samples":0,"evicted_events":0,"invalid_unloaded_force_samples":0,"hybrid_cached_force_samples":0,"tick_gaps":0,"time_tick_mismatch":0,"event_time_tick_mismatch":0,"retention_without_contact":0,"support_identity_changed":false}

func start(snapshot:Dictionary,direction:Vector3,config:Dictionary={})->bool:
	if _config.is_empty():configure(config)
	else:
		var settings:Dictionary=_config.duplicate(true)
		settings.merge(config,true)
		configure(settings)
	_reference=str(_config.reference)
	if _reference not in ["com","body"] or not direction.is_finite():return false
	_direction=direction.normalized() if direction.length_squared()>.00000001 else Vector3.ZERO
	_running=true
	if not push(snapshot):
		_running=false
		return false
	return true

func _vector(snapshot:Dictionary,key:String,alias:String="")->Variant:
	var value:Variant=null
	if snapshot.has(key):value=snapshot[key]
	elif alias!="":value=snapshot.get(alias)
	if value is Vector3 and value.is_finite():return value
	return null

func _numeric(value:Variant)->bool:
	return (value is float or value is int) and is_finite(float(value))

func _sample(snapshot:Dictionary)->Dictionary:
	var timestamp:Variant=snapshot.get("time",snapshot.get("time_s",null))
	var tick:Variant=snapshot.get("tick",snapshot.get("physics_tick",null))
	var position:Variant=_vector(snapshot,"com_position") if _reference=="com" else _vector(snapshot,"body_position","position")
	if not _numeric(timestamp) or not tick is int or position==null:return {}
	var twist:Variant=snapshot.get("twist_rad",snapshot.get("twist",null))
	var intent:Variant=_vector(snapshot,"movement_intent_world","intent_world")
	var measured_twist:Variant=null
	if _numeric(twist):measured_twist=float(twist)
	return {"time":float(timestamp),"tick":int(tick),"position":position,"body_position":_vector(snapshot,"body_position","position"),"com_position":_vector(snapshot,"com_position"),"velocity":_vector(snapshot,"velocity","linear_velocity"),"angular_velocity":_vector(snapshot,"angular_velocity"),"intent":intent if intent!=null else Vector3.ZERO,"support_displacement":_vector(snapshot,"support_displacement"),"support_point":_vector(snapshot,"support_point_world"),"support_id":snapshot.get("support_id",null),"twist":measured_twist,"saturated":snapshot.get("saturated",null),"assisted":bool(snapshot.get("assisted",false))}

func _target_and_settling(sample:Dictionary)->void:
	var progress:Variant=_progress(sample)
	var has_target:bool=_numeric(_config.target_progress_m) and progress!=null
	var inside:=true
	if has_target:
		var corridor:float=maxf(0.0,float(_config.target_corridor_m))
		_max_overshoot=maxf(_max_overshoot,float(progress)-float(_config.target_progress_m)-corridor)
		inside=absf(float(progress)-float(_config.target_progress_m))<=corridor
	if not _previous.is_empty() and Vector3(_previous.intent).length()>float(_config.intent_epsilon) and Vector3(sample.intent).length()<=float(_config.intent_epsilon):_stop_time=sample.time
	if _stop_time!=null and _settle_start==null:_settle_start=_stop_time
	if has_target and inside and _settle_start==null:_settle_start=sample.time
	if _settle_start==null:return
	_settle_missing=sample.velocity==null or sample.angular_velocity==null
	var stable:=false
	if not _settle_missing:stable=Vector3(sample.velocity).length()<=float(_config.settle_linear_m_s) and Vector3(sample.angular_velocity).length()<=float(_config.settle_angular_rad_s) and inside
	if not stable:
		_settle_candidate=null;_settled=false
		return
	if _settle_candidate==null:_settle_candidate=sample.time
	_settled=float(sample.time)-float(_settle_candidate)+.000000001>=maxf(0.0,float(_config.settle_hold_s))
	if _settled and _settle_first_confirmed==null:_settle_first_confirmed=sample.time

func _progress(sample:Dictionary)->Variant:
	if _direction!=Vector3.ZERO:return (Vector3(sample.position)-Vector3(_initial.position)).dot(_direction)
	return null

func _carry(sample:Dictionary)->Variant:
	if sample.support_displacement!=null and _initial.support_displacement!=null:
		return Vector3(sample.support_displacement)-Vector3(_initial.support_displacement)
	if sample.support_point!=null and _initial.support_point!=null and sample.support_id!=null and sample.support_id==_initial.support_id:
		return Vector3(sample.support_point)-Vector3(_initial.support_point)
	return null

func _response(sample:Dictionary,dt:float)->void:
	var intent:Vector3=sample.intent
	if intent.length()>float(_config.intent_epsilon):
		var unit:Vector3=intent.normalized()
		if _onset.is_empty():_onset={"time":sample.time,"tick":sample.tick,"velocity":sample.velocity,"source":"first_observed_nonzero_intent"}
		if _last_intent!=Vector3.ZERO:
			var dot_value:float=unit.dot(_last_intent)
			if dot_value<cos(float(_config.correction_angle_rad)):_corrections+=1
			if dot_value<float(_config.reversal_dot):_reversals+=1
		_last_intent=unit
	if _onset.is_empty() or _onset.get("source","")=="PREHELD_INPUT" or _latency!=null or sample.velocity==null or _direction==Vector3.ZERO:return
	var qualifies:=false
	if _config.response_mode=="acceleration":
		if dt>0 and not _previous.is_empty() and _previous.velocity!=null:
			qualifies=((Vector3(sample.velocity)-Vector3(_previous.velocity))/dt).dot(_direction)>=float(_config.response_acceleration_m_s2)
	elif _onset.velocity!=null:
		qualifies=(Vector3(sample.velocity)-Vector3(_onset.velocity)).dot(_direction)>=float(_config.response_velocity_m_s)
	if qualifies:
		if _response_candidate==null:_response_candidate=sample.time
		if float(sample.time)-float(_response_candidate)+.000000001>=float(_config.response_persistence_s):_latency=float(_response_candidate)-float(_onset.time)
	else:_response_candidate=null

func _contacts(snapshot:Dictionary,dt:float)->void:
	if dt<=0:return
	if not snapshot.has("contacts") or not snapshot.contacts is Array:
		_work_missing_time+=dt
		return
	var up:Vector3=_config.gravity_up
	up=up.normalized() if up.is_finite() and up.length_squared()>.000001 else Vector3.UP
	var foot_loaded:=false
	var foot_load:=0.0
	var total_load:=0.0
	var known:=true
	var power:=0.0
	var relative_power:=0.0
	var power_known:=true
	var relative_known:=true
	for value in snapshot.contacts:
		if not value is Dictionary:
			known=false;power_known=false;relative_known=false
			continue
		var contact:Dictionary=value
		var force:Variant=_vector(contact,"force")
		var kind:String=str(contact.get("kind","unknown"))
		var state:String=str(contact.get("state",""))
		var admitted:bool=bool(contact.get("applied",_config.contacts_are_applied))
		if not admitted:
			if not contact.has("applied") and not _config.contacts_are_applied:known=false;power_known=false;relative_known=false
			continue
		if force==null:
			known=false;power_known=false;relative_known=false
			continue
		if bool(snapshot.get("assisted",false)) and kind in ["hand","foot"] and Vector3(force).length()>.000001:
			_quality.hybrid_cached_force_samples+=1
			known=false;power_known=false;relative_known=false
			continue
		var valid_state:bool=(kind=="foot" and state in ["SUPPORTING","SLIDING"]) or (kind=="hand" and state in ["ATTACHED","SLIPPING"]) or kind=="ground"
		if not valid_state:
			if Vector3(force).length()>.000001:_quality.invalid_unloaded_force_samples+=1
			continue
		var current_load:float=maxf(0.0,Vector3(force).dot(up))
		total_load+=current_load
		if kind=="foot":
			foot_loaded=foot_loaded or Vector3(force).length()>float(_config.loaded_force_n)
			foot_load+=current_load
		if Vector3(force).length()<=.000001:continue
		var point_velocity:Variant=_vector(contact,"point_velocity")
		var support_velocity:Variant=_vector(contact,"support_velocity")
		if point_velocity==null:power_known=false;relative_known=false
		else:
			power+=Vector3(force).dot(Vector3(point_velocity))
			if support_velocity==null:relative_known=false
			else:relative_power+=Vector3(force).dot(Vector3(point_velocity)-Vector3(support_velocity))
	if known:
		_contact_known_time+=dt
		if foot_loaded:_foot_loaded_time+=dt
		_foot_load_integral+=foot_load*dt;_support_load_integral+=total_load*dt
	if power_known:_work+=power*dt;_work_known_time+=dt
	else:_work_missing_time+=dt
	if relative_known:_relative_work+=relative_power*dt;_relative_work_known_time+=dt

func push(snapshot:Dictionary)->bool:
	if not _running:return false
	var sample:Dictionary=_sample(snapshot)
	if sample.is_empty():_quality.rejected_samples+=1;return false
	if not _previous.is_empty() and (sample.time<=_previous.time or sample.tick<=_previous.tick):_quality.rejected_samples+=1;return false
	var dt:float=0.0 if _previous.is_empty() else sample.time-_previous.time
	if _initial.is_empty():_initial=sample.duplicate(true)
	if dt>0:
		var segment:float=Vector3(sample.position).distance_to(Vector3(_previous.position))
		var old_path:float=_path
		_path+=segment
		if sample.tick-_previous.tick>1:_quality.tick_gaps+=1
		if _config.has("physics_hz") and absf(dt-float(sample.tick-_previous.tick)/float(_config.physics_hz))>.00001:_quality.time_tick_mismatch+=1
		for window in [.25,.5,1.0]:
			var key:String=str(window)
			if not _windows.has(key) and sample.time-_initial.time>=window:
				var fraction:float=clampf((_initial.time+window-_previous.time)/dt,0.0,1.0)
				var at:Dictionary=sample.duplicate(true)
				at.position=Vector3(_previous.position).lerp(Vector3(sample.position),fraction)
				if _carry(_previous)!=null and _carry(sample)!=null:at.support_displacement=Vector3(_carry(_previous)).lerp(Vector3(_carry(sample)),fraction);at.support_point=null
				var relative:Variant=null
				if _carry(_previous)!=null and _carry(sample)!=null and _direction!=Vector3.ZERO:relative=(Vector3(at.position)-Vector3(_initial.position)-Vector3(_carry(_previous)).lerp(Vector3(_carry(sample)),fraction)).dot(_direction)
				_windows[key]={"time_s":window,"useful_progress_m":_progress(at),"support_relative_progress_m":relative,"path_length_m":old_path+segment*fraction,"interpolated_between_ticks":[_previous.tick,sample.tick]}
		if sample.twist!=null:_twist_square_time+=float(sample.twist)*float(sample.twist)*dt;_twist_time+=dt
		if sample.saturated is bool:
			_saturation_known_time+=dt
			if sample.saturated:_saturated_time+=dt
		_contacts(snapshot,dt)
	if sample.twist!=null:_twist_peak=maxf(_twist_peak,absf(float(sample.twist)))
	if _initial.support_id!=null and sample.support_id!=_initial.support_id:_quality.support_identity_changed=true
	_response(sample,dt)
	_target_and_settling(sample)
	sample["useful_progress_m"]=_progress(sample)
	sample["path_length_m"]=_path
	_samples.append(sample.duplicate(true))
	if _samples.size()>int(_config.max_samples):_samples.pop_front();_quality.evicted_samples+=1
	_previous=sample
	_quality.accepted_samples+=1
	return true

func record_event(event:Dictionary)->bool:
	if not _running:return false
	var timestamp:Variant=event.get("time",event.get("time_s",null))
	var tick:Variant=event.get("tick",event.get("physics_tick",null))
	if not _numeric(timestamp) or not tick is int:return false
	var kind:String=str(event.get("type",""))
	var explicit_priority:bool=_onset.is_empty() or (_onset.get("source","")=="first_observed_nonzero_intent" and float(timestamp)<=float(_onset.time)+.000000001)
	if kind=="command_onset" and explicit_priority:
		_onset={"time":float(timestamp),"tick":int(tick),"velocity":_vector(event,"velocity","linear_velocity") if event.has("velocity") or event.has("linear_velocity") else _previous.get("velocity",null),"source":"explicit_accepted_input_event"}
		if not _initial.is_empty() and float(timestamp)<float(_initial.time)-.00001:_onset.source="PREHELD_INPUT"
		_response_candidate=null;_latency=null
	if kind=="stop_command":_stop_time=float(timestamp)
	var id:String="%s:%s"%[str(event.get("hand_id",-1)),str(event.get("attempt_id","unknown"))]
	var stages:Dictionary=_attempts.get(id,{})
	if kind=="retained" and not stages.has("contact"):
		_quality.retention_without_contact+=1
		return false
	if _config.has("physics_hz") and not _initial.is_empty() and absf(float(timestamp)-float(_initial.time)-float(int(tick)-int(_initial.tick))/float(_config.physics_hz))>.00001:_quality.event_time_tick_mismatch+=1
	if kind in ["attempt","contact","retained"] and not stages.has(kind):
		_counts[{"attempt":"attempts","contact":"contacts","retained":"retained"}[kind]]+=1
		stages[kind]=true
		_attempts[id]=stages
		if _attempts.size()>int(_config.max_events):_attempts.erase(_attempts.keys()[0])
	elif kind=="release":_counts.releases+=1
	elif kind=="slip":_counts.slips+=1
	# Store selected numeric/string metadata, never caller object references.
	_events.append({"time":float(timestamp),"tick":int(tick),"type":kind,"hand_id":event.get("hand_id",-1),"attempt_id":str(event.get("attempt_id","unknown")),"reason":str(event.get("reason",""))})
	if _events.size()>int(_config.max_events):_events.pop_front();_quality.evicted_events+=1
	return true

func recent_samples()->Array[Dictionary]:return _samples.duplicate(true)
func recent_events()->Array[Dictionary]:return _events.duplicate(true)

func finish()->Dictionary:
	var duration:float=0.0 if _previous.is_empty() else float(_previous.time)-float(_initial.time)
	var progress:Variant=null if _previous.is_empty() else _progress(_previous)
	var carry:Variant=null if _previous.is_empty() else _carry(_previous)
	var relative:Variant=null
	if carry!=null and progress!=null and not _quality.support_identity_changed:relative=float(progress)-Vector3(carry).dot(_direction)
	var movement:Dictionary={"useful_progress_m":progress,"path_length_m":_path,"directional_efficiency":null,"efficiency_reason":"NO_MOVEMENT_OR_NO_DIRECTION","support_relative_progress_m":relative,"support_relative_reason":"MISSING_OR_CHANGED_MATERIAL_REFERENCE","windows":_windows.duplicate(true),"overshoot_m":null,"overshoot_reason":"NO_TARGET","target_progress_m":_config.get("target_progress_m"),"target_corridor_m":_config.get("target_corridor_m")}
	if progress!=null and _path>=float(_config.path_epsilon_m):
		movement.directional_efficiency=float(progress)/_path;movement.efficiency_reason="DEFINED"
	if relative!=null:movement.support_relative_reason="DEFINED"
	if _numeric(_config.get("target_progress_m")) and progress!=null:movement.overshoot_m=_max_overshoot;movement.overshoot_reason="DEFINED"
	var support:Dictionary={"foot_loaded_duration_s":null,"foot_loaded_time_fraction":null,"foot_upward_load_fraction":null,"contact_coverage_s":_contact_known_time,"partial_actuator_work_j":null,"observed_partial_work_j":null,"work_coverage_s":_work_known_time,"relative_actuator_work_j":null,"relative_work_coverage_s":_relative_work_known_time,"work_scope":"signed F dot actual application point velocity; not whole-system energy"}
	if _contact_known_time>0:support.foot_loaded_duration_s=_foot_loaded_time;support.foot_loaded_time_fraction=_foot_loaded_time/_contact_known_time
	if _support_load_integral>.000001:support.foot_upward_load_fraction=_foot_load_integral/_support_load_integral
	if _work_known_time>0:
		support.observed_partial_work_j=_work
		if _work_missing_time<.000001:support.partial_actuator_work_j=_work
	if _relative_work_known_time>=duration-.000001 and duration>0:support.relative_actuator_work_j=_relative_work
	var rotation:Dictionary={"twist_rms_rad":null,"twist_peak_rad":null,"twist_coverage_s":_twist_time,"axis_scope":"support-relative scalar supplied by snapshot; not inferred roll"}
	if _twist_time>0:rotation.twist_rms_rad=sqrt(_twist_square_time/_twist_time);rotation.twist_peak_rad=_twist_peak
	var saturation:Dictionary={"duration_s":null,"fraction":null}
	if _saturation_known_time>0:saturation.duration_s=_saturated_time;saturation.fraction=_saturated_time/_saturation_known_time
	var settling:Dictionary={"time_s":null,"currently_settled":_settled,"first_confirmed_at_s":null,"continuous_interval_s":0.0,"reason":"NO_STOP_OR_TARGET","linear_threshold_m_s":_config.get("settle_linear_m_s"),"angular_threshold_rad_s":_config.get("settle_angular_rad_s"),"persistence_s":_config.get("settle_hold_s")}
	if _settle_first_confirmed!=null:settling.first_confirmed_at_s=float(_settle_first_confirmed)-float(_initial.time)
	if _settle_start!=null:
		settling.reason="STABLE_INTERVAL_NOT_REACHED"
		if _settle_missing:settling.reason="MISSING_VELOCITY"
	if _settle_candidate!=null and not _previous.is_empty():settling.continuous_interval_s=float(_previous.time)-float(_settle_candidate)
	if _settled:
		settling.time_s=float(_settle_candidate)-float(_settle_start);settling.reason="CONTINUOUS_STABLE_INTERVAL"
	var latency_reason:="NO_SUSTAINED_RESPONSE_OR_VELOCITY_MISSING"
	if _onset.is_empty():latency_reason="NO_ACCEPTED_INPUT"
	elif _onset.get("source","")=="PREHELD_INPUT":latency_reason="PREHELD_INPUT"
	elif _latency!=null:latency_reason="SUSTAINED_RESPONSE"
	return {"schema_version":"movement_metrics_v12_1","reference":_reference,"direction_world":_direction,"direction_frame":"fixed_at_start","duration_s":duration,"movement":movement,"response":{"onset":_onset.duplicate(true),"latency_s":_latency,"latency_reason":latency_reason,"mode":_config.get("response_mode"),"persistence_s":_config.get("response_persistence_s"),"velocity_threshold_m_s":_config.get("response_velocity_m_s"),"acceleration_threshold_m_s2":_config.get("response_acceleration_m_s2"),"corrections":_corrections,"reversals":_reversals},"support":support,"rotation":rotation,"saturation":saturation,"settling":settling,"capture":_counts.duplicate(true),"quality":_quality.duplicate(true),"buffers":{"samples":_samples.size(),"events":_events.size(),"max_samples":_config.get("max_samples"),"max_events":_config.get("max_events")}}
