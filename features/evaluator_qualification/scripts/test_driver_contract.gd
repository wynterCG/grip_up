extends SceneTree
const Driver=preload("res://features/evaluator_qualification/scripts/qualification_driver.gd")
const Metrics=preload("res://features/evaluator_qualification/scripts/qualification_metrics.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
	check(Driver.replay_sequence_supported(["swing_catch_train"],"isolated"),"R0 catch supported")
	check(Driver.replay_sequence_supported(["stop_release_v1","swing_catch_train"],"sequence"),"explicit A_CONTEXT before R0 catch supported")
	check(not Driver.replay_sequence_supported(["eq132_stop_release_one_hand_left_r1"],"isolated"),"unsupported R0 control cannot fall back to A")
	check(not Driver.replay_sequence_supported(["stop_release_v1","swing_catch_train"],"isolated"),"prior episode requires explicit context")
	check(not Driver.replay_sequence_supported(["swing_catch_train","stop_release_v1"],"sequence"),"reordered context rejected")
	for hz:int in [60,120]:
		var rows:Array=[]
		for tick:int in hz+1:
			rows.append({"physics_tick":tick,"body":{"com_m":Vector3(float(tick)/hz*.01,0,0),"linear_velocity_m_s":Vector3(.05 if tick>=hz/4 else .2,0,0),"angular_velocity_rad_s":Vector3.ZERO},"support":{"valid":true,"hybrid_owned":false,"frame_id":"COMMON_STATIC_WORLD"},"grounded":false,"force_budget":{"ground_force_n":Vector3.ZERO,"ground_torque_nm":Vector3.ZERO},"effective":[{"state":"ATTACHED","anchor_runtime_id":1},{"state":"FREE","anchor_runtime_id":0}],"accepted":{"intent_world":Vector3.ZERO}})
		var result:Dictionary=Metrics.analyze(rows,{"kind":"release","tick":0},Vector3.RIGHT,hz,false)
		check(result.settling_time_s.status=="MEASURED" and absf(float(result.settling_time_s.value)-.25)<.000001,"elapsed settling reports stable interval start at %d Hz" % hz)
		for row:Dictionary in rows:row.body.linear_velocity_m_s.y=.3
		result=Metrics.analyze(rows,{"kind":"release","tick":0},Vector3.RIGHT,hz,false)
		check(result.settling_time_s.status=="CENSORED_TIMEOUT","vertical speed cannot hide behind quiet lateral component at %d Hz" % hz)
	print("QUALIFICATION DRIVER CONTRACT RESULTS: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
