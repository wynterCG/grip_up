extends SceneTree
const Response=preload("res://features/auto_tuning_lab/scripts/response_metrics.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func row(time:float,raw:Vector2=Vector2.ZERO,velocity:Vector3=Vector3.ZERO,point:Vector3=Vector3.ZERO)->Dictionary:
	return {"time":time,"tick":int(round(time*1000)),"com_position":point,"velocity":velocity,"angular_velocity":Vector3.ZERO,"accepted_input":raw,"accepted_input_time":time,"frame":{"right":Vector3.RIGHT,"up":Vector3.UP},"target_accelerations":{0:0.0},"target_anchor_ids":{0:7}}
func _initialize()->void:
	var r=Response.new()
	check(r.start(row(1,Vector2.RIGHT,Vector3.RIGHT),Vector3.RIGHT),"preheld start admitted without inventing latency")
	check(r.finish().reversal_latency_s==null and r.finish().stop_distance_m==null,"missing commands stay unknown")
	r.push(row(1.1,Vector2.ZERO,Vector3.RIGHT,Vector3(.1,0,0)))
	r.push(row(1.2,Vector2.ZERO,Vector3.RIGHT,Vector3(.2,0,0)))
	r.push(row(1.3,Vector2.ZERO,Vector3.ZERO,Vector3(.25,0,0)))
	check(r.finish().stop_distance_m==null,"slow single sample is not settled")
	r.push(row(1.55,Vector2.ZERO,Vector3.ZERO,Vector3(.25,0,0)))
	check(is_equal_approx(float(r.finish().stop_distance_m),.15),"continuous .25second stable interval confirms forward stop distance")
	check(r.finish()==r.finish(),"finish is pure and repeatable")
	r.push(row(1.6,Vector2.LEFT,Vector3.RIGHT,Vector3(.25,0,0)))
	r.push(row(1.7,Vector2.LEFT,-Vector3.RIGHT,Vector3(.15,0,0)))
	check(r.finish().reversal_latency_s==null,"opposite velocity must persist")
	r.push(row(1.75,Vector2.LEFT,-Vector3.RIGHT,Vector3(.1,0,0)))
	check(is_equal_approx(float(r.finish().reversal_latency_s),.1),"reversal latency uses raw accepted command and sustained actual velocity")
	check(not r.push(row(1.75)),"duplicate time/tick rejected")
	var bad:Dictionary=row(2);bad.com_position=Vector3(INF,0,0)
	check(not r.push(bad),"nonfinite COM rejected")
	r.start(row(1,Vector2.RIGHT),Vector3.RIGHT)
	r.push(row(1.1,Vector2.ZERO,Vector3.RIGHT))
	r.push(row(1.2,Vector2.LEFT,Vector3.RIGHT))
	check(r.finish().stop_distance_m==null and r.finish().stops[0].reason=="INTERRUPTED_BY_NEW_COMMAND","interrupted stop retains unknown distance")
	check(r.finish().reversal_latency_s==null,"unfinished reversal is censored")
	r.start(row(1),Vector3.RIGHT)
	var next:Dictionary=row(1.1);next.target_accelerations[0]=1.0
	r.push(next)
	check(is_equal_approx(float(r.finish().target_jerk_rms_m_s3),10.0),"target jerk measured in SI units")
	next=row(1.2);next.target_accelerations[0]=100.0;next.target_anchor_ids[0]=8
	r.push(next)
	check(is_equal_approx(float(r.finish().target_jerk_peak_m_s3),10.0),"changed anchor excludes derivative discontinuity")
	r.start(row(1,Vector2.RIGHT),Vector3.RIGHT)
	next=row(1.1,Vector2.LEFT,-Vector3.RIGHT);next.accepted_input_time=null
	r.push(next);r.push(row(1.2,Vector2.LEFT,-Vector3.RIGHT))
	check(r.finish().reversal_latency_s==null,"missing accepted timestamp never becomes zero latency")
	r.start(row(1,Vector2.RIGHT),Vector3.RIGHT)
	r.push(row(1.1,Vector2.LEFT,-Vector3.RIGHT))
	r.push(row(1.11,Vector2.ZERO,-Vector3.RIGHT))
	r.push(row(1.2,Vector2.ZERO,-Vector3.RIGHT))
	check(r.finish().reversal_latency_s==null and r.finish().reversals[0].reason=="INTERRUPTED_BY_NEW_COMMAND","released reversal cannot earn later passive motion credit")
	r.start(row(1,Vector2.RIGHT),Vector3.RIGHT)
	next=row(1.1,Vector2.LEFT,-Vector3.RIGHT);next.frame={}
	r.push(next);next=row(1.2,Vector2.LEFT,-Vector3.RIGHT);next.frame={};r.push(next)
	check(r.finish().reversal_latency_s==null,"missing input frame cannot invent a world response axis")
	for n in 100:r.push(row(2+n*.01,Vector2.RIGHT if n%2==0 else Vector2.LEFT))
	check(r.finish().reversals.size()<=33 and r.finish().quality.evicted_events>0,"event history bounded with current pending observation")
	print("RESPONSE METRICS RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
