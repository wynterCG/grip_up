extends RefCounted
## Pure sampled response analysis. Accepted input is raw coordinator intent,
## never ramped movement. No world access or authority over simulation.
var _direction:=Vector3.UP
var _previous:Dictionary={}
var _raw:=Vector2.ZERO
var _last_nonzero:=Vector2.ZERO
var _stops:Array[Dictionary]=[]
var _reversals:Array[Dictionary]=[]
var _stop:Dictionary={}
var _reverse:Dictionary={}
var _target_previous:Dictionary={}
var _jerk_square_time:=0.0
var _jerk_time:=0.0
var _jerk_peak:=0.0
var _rejected:=0
var _evicted:=0
const MAX_EVENTS=32

func _valid(row:Dictionary)->bool:
	return row.get("time") is float or row.get("time") is int

func _axis(raw:Vector2,row:Dictionary)->Vector3:
	var frame:Dictionary=row.get("frame",{})
	if frame.get("right") is Vector3 and frame.get("up") is Vector3:
		var value:Vector3=frame.right*raw.x+frame.up*raw.y
		if value.is_finite() and value.length_squared()>.00001:return value.normalized()
	return Vector3.ZERO

func start(row:Dictionary,direction:Vector3,_unused_options:Dictionary={})->bool:
	_previous.clear();_stops.clear();_reversals.clear();_stop.clear();_reverse.clear();_target_previous.clear()
	_jerk_square_time=0;_jerk_time=0;_jerk_peak=0;_rejected=0;_evicted=0
	_direction=direction.normalized() if direction.is_finite() else Vector3.ZERO
	_raw=Vector2.ZERO;_last_nonzero=Vector2.ZERO
	return push(row)

func _append(ring:Array[Dictionary],row:Dictionary)->void:
	ring.append(row.duplicate(true))
	if ring.size()>MAX_EVENTS:ring.pop_front();_evicted+=1

func _close_stop(reason:String)->void:
	if _stop.is_empty():return
	if not _stop.get("settled",false):_stop.reason=reason
	_append(_stops,_stop);_stop={}

func _close_reverse(reason:String)->void:
	if _reverse.is_empty():return
	if _reverse.latency_s==null:_reverse.reason=reason
	_append(_reversals,_reverse);_reverse={}

func push(row:Dictionary)->bool:
	if not _valid(row) or not is_finite(float(row.time)) or not row.get("tick") is int or not row.get("com_position") is Vector3 or not row.com_position.is_finite() or not row.get("velocity") is Vector3 or not row.velocity.is_finite() or not row.get("angular_velocity") is Vector3 or not row.angular_velocity.is_finite() or not row.get("accepted_input") is Vector2 or not row.accepted_input.is_finite():
		_rejected+=1;return false
	if not _previous.is_empty() and (float(row.time)<=float(_previous.time) or int(row.tick)<=int(_previous.tick)):
		_rejected+=1;return false
	var raw:Vector2=row.accepted_input
	var dt:float=0 if _previous.is_empty() else float(row.time)-float(_previous.time)
	var changed:bool=raw.distance_to(_raw)>.00001
	if _previous.is_empty():
		_raw=raw
		if raw.length_squared()>.00001:_last_nonzero=raw
	elif changed:
		_close_reverse("INTERRUPTED_BY_NEW_COMMAND")
		var onset:Variant=row.get("accepted_input_time")
		var onset_valid:bool=(onset is int or onset is float) and is_finite(float(onset)) and float(onset)>=float(_previous.time)-.00001 and float(onset)<=float(row.time)+.00001
		if raw.length_squared()<.00001 and _raw.length_squared()>.00001:
			_close_stop("NEXT_STOP")
			_stop={"time":onset if onset_valid else null,"point":row.com_position,"axis":_axis(_raw,_previous),"path_m":0.0,"max_forward_drift_m":0.0,"stop_distance_m":null,"candidate":null,"settled":false,"reason":"OBSERVING" if onset_valid else "MISSING_ACCEPTED_TIMESTAMP"}
		else:
			_close_stop("INTERRUPTED_BY_NEW_COMMAND")
			if raw.length_squared()>.00001 and _last_nonzero.length_squared()>.00001 and raw.normalized().dot(_last_nonzero.normalized())<-.5:
				_close_reverse("NEXT_REVERSAL")
				_reverse={"time":onset if onset_valid else null,"axis":_axis(raw,row),"candidate":null,"latency_s":null,"reason":"OBSERVING" if onset_valid else "MISSING_ACCEPTED_TIMESTAMP"}
			if raw.length_squared()>.00001:_last_nonzero=raw
		_raw=raw
	if not _stop.is_empty() and dt>0 and not _stop.settled:
		if not changed:_stop.path_m+=Vector3(row.com_position).distance_to(Vector3(_previous.com_position))
		_stop.max_forward_drift_m=maxf(float(_stop.max_forward_drift_m),(Vector3(row.com_position)-Vector3(_stop.point)).dot(_stop.axis))
		var slow:bool=row.velocity.length()<=.1 and row.angular_velocity.length()<=.2
		if slow:
			if _stop.candidate==null:_stop.candidate={"time":row.time,"distance_m":_stop.max_forward_drift_m}
			if float(row.time)-float(_stop.candidate.time)>=.25-.000000001 and _stop.time!=null and Vector3(_stop.axis).length_squared()>.00001:
				_stop.settled=true;_stop.reason="CONTINUOUS_STABLE_INTERVAL";_stop.stop_distance_m=_stop.candidate.distance_m
		else:_stop.candidate=null
	if not _reverse.is_empty() and _reverse.latency_s==null and _reverse.time!=null and Vector3(_reverse.axis).length_squared()>.00001:
		if Vector3(row.velocity).dot(_reverse.axis)>=.02:
			if _reverse.candidate==null:_reverse.candidate=float(row.time)
			if float(row.time)-float(_reverse.candidate)>=.05-.000000001:
				_reverse.latency_s=float(_reverse.candidate)-float(_reverse.time);_reverse.reason="SUSTAINED_OPPOSITE_VELOCITY"
		else:_reverse.candidate=null
	var accelerations:Dictionary=row.get("target_accelerations",{})
	var anchors:Dictionary=row.get("target_anchor_ids",{})
	var next_targets:Dictionary={}
	for id in accelerations:
		var value:Variant=accelerations[id]
		if not (value is int or value is float) or not is_finite(float(value)) or not anchors.has(id):continue
		if dt>0 and _target_previous.has(id) and _target_previous[id].anchor==anchors[id]:
			var jerk:float=(float(value)-float(_target_previous[id].acceleration))/dt
			_jerk_square_time+=jerk*jerk*dt;_jerk_time+=dt;_jerk_peak=maxf(_jerk_peak,absf(jerk))
		next_targets[id]={"acceleration":float(value),"anchor":anchors[id]}
	_target_previous=next_targets
	_previous={"time":row.time,"tick":row.tick,"com_position":row.com_position,"frame":row.get("frame",{}).duplicate(true)}
	return true

func finish()->Dictionary:
	var stops:Array[Dictionary]=_stops.duplicate(true)
	var reversals:Array[Dictionary]=_reversals.duplicate(true)
	if not _stop.is_empty():
		var last:Dictionary=_stop.duplicate(true)
		if not last.settled and last.reason=="OBSERVING":last.reason="RIGHT_CENSORED_NOT_SETTLED"
		stops.append(last)
	if not _reverse.is_empty():
		var last:Dictionary=_reverse.duplicate(true)
		if last.latency_s==null and last.reason=="OBSERVING":last.reason="NO_SUSTAINED_OPPOSITE_VELOCITY"
		reversals.append(last)
	var stop_distance:Variant=null
	var reversal_latency:Variant=null
	if not stops.is_empty():stop_distance=stops[0].stop_distance_m
	if not reversals.is_empty():reversal_latency=reversals[0].latency_s
	var jerk_rms:Variant=null
	if _jerk_time>0:jerk_rms=sqrt(_jerk_square_time/_jerk_time)
	return {"stop_distance_m":stop_distance,"reversal_latency_s":reversal_latency,"stops":stops,"reversals":reversals,"target_jerk_rms_m_s3":jerk_rms,"target_jerk_peak_m_s3":_jerk_peak if _jerk_time>0 else null,"target_derivative_coverage_actuator_s":_jerk_time,"quality":{"rejected_samples":_rejected,"evicted_events":_evicted},"scope":"First accepted stop/reversal, not best observed. Stop distance is nonnegative forward COM drift until onset of a .25s continuously slow interval (.1m/s,.2rad/s). Interrupted/unsettled stops and absent reversals stay null. Physics-tick sampling; no hardware latency. Target jerk uses existing target acceleration differences only across the same real anchor; body/contact jerk attribution is not inferred."}
