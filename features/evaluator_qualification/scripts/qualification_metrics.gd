extends RefCounted
## Independent runtime implementation; Python recomputes from raw PRE/POST trace.
static func outcome(status:String,reason:String,value:Variant=null)->Dictionary:
	return {"status":status,"reason":reason,"value":value if status=="MEASURED" else null}
static func analyze(rows:Array,transition:Dictionary,axis:Vector3,hz:int,precondition:bool)->Dictionary:
	var result:Dictionary={"formula":"v132_full_norm_settle_directed_brake_v1","settling_time_s":outcome("NOT_APPLICABLE","NO_STOP_TRANSITION"),"stop_path_m":outcome("NOT_APPLICABLE","NO_STOP_TRANSITION"),"brake_50_time_s":outcome("NOT_APPLICABLE","NO_ACTIVE_BRAKE"),"brake_10_time_s":outcome("NOT_APPLICABLE","NO_ACTIVE_BRAKE")}
	var kind:String=str(transition.get("kind","none"))
	if kind not in ["release","brake"]:return result
	var status:String="PRECONDITION_NOT_MET" if precondition else "CENSORED_TIMEOUT"
	for key in ["settling_time_s","stop_path_m"]:result[key]=outcome(status,"ONSET_NOT_QUALIFIED" if precondition else "SETTLE_NOT_CONFIRMED")
	if kind=="brake":
		for key in ["brake_50_time_s","brake_10_time_s"]:result[key]=outcome(status,"ONSET_NOT_QUALIFIED" if precondition else "FRACTION_NOT_REACHED")
	if precondition:return result
	var selected:Array=[]
	for row:Dictionary in rows:
		if int(row.physics_tick)>=int(transition.tick):selected.append(row)
	if selected.is_empty():return result
	if selected[0].support.get("frame_id","")!="COMMON_STATIC_WORLD":
		for key in result:
			if result[key] is Dictionary and result[key].status!="NOT_APPLICABLE":result[key]=outcome("INVALID_MEASUREMENT","V132_FORMULA_REQUIRES_COMMON_STATIC_FRAME")
		return result
	var t0:int=int(selected[0].physics_tick)
	var v0:float=Vector3(selected[0].body.linear_velocity_m_s).dot(axis)
	var quiet_tick:=-1
	var quiet_path:=0.0
	var path:=0.0
	var previous:Variant=null
	var brake_active:=true
	var anchors:Array=[]
	for hand:Dictionary in selected[0].effective:anchors.append(int(hand.anchor_runtime_id) if hand.state=="ATTACHED" else 0)
	for row:Dictionary in selected:
		if float(int(row.physics_tick)-t0)/hz>float(transition.get("deadline_s",5.0))+.000001:break
		var clearance_unknown:bool=row.get("clearance_status","NOT_APPLICABLE") not in ["NOT_APPLICABLE","CLEAR_QUERIED_SEGMENT"]
		var interrupted:bool=row.grounded or not row.support.valid or row.support.hybrid_owned or Vector3(row.force_budget.ground_force_n).length()>.0001 or Vector3(row.force_budget.ground_torque_nm).length()>.0001 or clearance_unknown
		interrupted=interrupted or row.support.get("frame_id","")!="COMMON_STATIC_WORLD"
		interrupted=interrupted or (kind=="release" and Vector3(row.accepted.intent_world).length()>.000001)
		for id in 2:
			if anchors[id]!=0 and (row.effective[id].state!="ATTACHED" or int(row.effective[id].anchor_runtime_id)!=anchors[id]):interrupted=true
		if interrupted:
			for key in result:
				if result[key] is Dictionary and result[key].status=="CENSORED_TIMEOUT":result[key]=outcome("INTERRUPTED","CLEARANCE_NOT_CERTIFIED" if clearance_unknown else "ACTUAL_SUPPORT_INTERRUPTION")
			break
		var com:Vector3=row.body.com_m
		if previous is Vector3:path+=com.distance_to(previous)
		previous=com
		var velocity:Vector3=row.body.linear_velocity_m_s
		var spin:Vector3=row.body.angular_velocity_rad_s
		var tick:int=int(row.physics_tick)
		if velocity.length()<=.1 and spin.length()<=.2:
			if quiet_tick<0:quiet_tick=tick;quiet_path=path
			if float(tick-quiet_tick)/hz>=.25 and result.settling_time_s.status!="MEASURED":
				result.settling_time_s=outcome("MEASURED","FULL_NORM_CONFIRMED_025S",float(quiet_tick-t0)/hz)
				result.stop_path_m=outcome("MEASURED","3D_PATH_TO_CONFIRMED_STOP_START",quiet_path)
		else:quiet_tick=-1
		if kind=="brake":
			if Vector3(row.accepted.intent_world).dot(axis)>=-.000001:brake_active=false
			for pair:Array in [["brake_50_time_s",.5],["brake_10_time_s",.1]]:
				var key:String=pair[0]
				if result[key].status!="CENSORED_TIMEOUT":continue
				if v0<.15:result[key]=outcome("PRECONDITION_NOT_MET","DIRECTED_INITIAL_SPEED_BELOW_015")
				elif not brake_active:result[key]=outcome("INTERRUPTED","OPPOSITE_COMMAND_ENDED")
				elif velocity.dot(axis)<=v0*float(pair[1]):result[key]=outcome("MEASURED","DIRECTED_FRACTION_DURING_ACTIVE_OPPOSITE",float(tick-t0)/hz)
	return result
