extends SceneTree
const Metrics=preload("res://features/locomotion_test_suite/scripts/movement_metrics.gd")
var checks:=0
var failures:=0
var hz:=120
var rows:Array=[]

func _initialize()->void:
	if OS.get_cmdline_user_args().has("--60hz"):hz=60
	Engine.physics_ticks_per_second=hz
	run.call_deferred()

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)

func near(a:float,b:float,tolerance:float=.00001)->bool:return absf(a-b)<=tolerance

func point(tick:int,at:Vector3=Vector3.ZERO,intent:Vector3=Vector3.RIGHT)->Dictionary:
	return {"time":float(tick)/hz,"tick":tick,"com_position":at,"body_position":at+Vector3(0,.2,0),"velocity":Vector3.RIGHT,"movement_intent_world":intent,"twist_rad":.2,"saturated":false,"contacts":[]}

func linear(direction:Vector3,transform:Transform3D=Transform3D.IDENTITY)->Dictionary:
	var metrics=Metrics.new()
	var first:Dictionary=point(0,transform*Vector3.ZERO)
	first.movement_intent_world=transform.basis*Vector3.RIGHT
	metrics.start(first,direction,{"physics_hz":hz})
	for i in range(1,hz+1):
		var snapshot:Dictionary=point(i,transform*Vector3(float(i)/hz,.1*float(i)/hz,0))
		snapshot.velocity=transform.basis*Vector3(1,.1,0)
		snapshot.movement_intent_world=transform.basis*Vector3.RIGHT
		metrics.push(snapshot)
	return metrics.finish()

func basic()->void:
	var forward:Dictionary=linear(Vector3.RIGHT)
	var opposite:Dictionary=linear(Vector3.LEFT)
	check(near(forward.movement.useful_progress_m,1) and near(opposite.movement.useful_progress_m,-1),"METRIC_01 signed displacement preserves negative direction")
	check(near(forward.movement.directional_efficiency,1/sqrt(1.01)) and near(opposite.movement.directional_efficiency,-1/sqrt(1.01)),"METRIC_01 signed efficiency is projection divided by actual sampled path")
	var quiet=Metrics.new()
	quiet.start(point(0),Vector3.RIGHT)
	quiet.push(point(hz))
	check(quiet.finish().movement.directional_efficiency==null,"METRIC_02 stationary path is undefined, never 100 percent")
	var tiny=Metrics.new()
	tiny.start(point(0),Vector3.RIGHT)
	tiny.push(point(hz,Vector3(.005,0,0)))
	check(tiny.finish().movement.directional_efficiency==null,"METRIC_02 sub-centimetre path stays below documented epsilon")
	var pose:=Transform3D(Basis.from_euler(Vector3(.6,1.3,-.7)),Vector3(12,-3,7))
	var rotated:Dictionary=linear(pose.basis*Vector3.RIGHT,pose)
	check(near(rotated.movement.useful_progress_m,forward.movement.useful_progress_m) and near(rotated.movement.path_length_m,forward.movement.path_length_m),"METRIC_03 equivalent world rotation/translation preserves signed motion")
	check(near(rotated.rotation.twist_rms_rad,.2),"METRIC_03 provided axial twist scalar remains separate from world body roll")
	for window in ["0.25","0.5","1.0"]:
		check(forward.movement.windows.has(window) and near(forward.movement.windows[window].useful_progress_m,float(window)),"METRIC_05 fixed window %s seconds uses physics timestamp"%window)
	var reference=Metrics.new()
	var first:Dictionary=point(0)
	reference.start(first,Vector3.UP,{"reference":"body"})
	var next:Dictionary=point(hz)
	next.body_position=Vector3(0,.7,0)
	reference.push(next)
	check(reference.finish().reference=="body" and near(reference.finish().movement.useful_progress_m,.5),"named body reference never silently changes to COM")
	check(not reference.start({"time":0,"tick":0,"body_position":Vector3.ZERO},Vector3.UP,{"reference":"com"}),"missing COM fails explicitly instead of falling back to animation/body")
	rows.append({"case":"linear","result":forward})

func carry()->void:
	var m=Metrics.new()
	var first:Dictionary=point(0)
	first.support_point_world=Vector3(0,-1,0);first.support_id=42
	m.start(first,Vector3.RIGHT)
	var last:Dictionary=point(hz,Vector3(1,.2,0))
	last.support_point_world=Vector3(1,-1,0);last.support_id=42
	m.push(last)
	check(near(m.finish().movement.useful_progress_m,1) and near(m.finish().movement.support_relative_progress_m,0),"METRIC_04 material point translation excludes platform carry")
	check(near(m.finish().movement.windows["0.5"].support_relative_progress_m,0),"METRIC_04 support-relative window uses matching interpolated carry")
	var changed:Dictionary=point(2*hz,Vector3(2,.2,0))
	changed.support_point_world=Vector3(2,-1,0);changed.support_id=43
	m.push(changed)
	check(m.finish().movement.support_relative_progress_m==null and m.finish().quality.support_identity_changed,"METRIC_04 changing support identity invalidates material-relative claim")
	var rotated=Metrics.new()
	first=point(0,Vector3(1,0,0));first.support_displacement=Vector3.ZERO
	rotated.start(first,Vector3.LEFT)
	last=point(hz,Vector3(0,0,-1));last.support_displacement=Vector3(-1,0,-1)
	rotated.push(last)
	check(near(rotated.finish().movement.support_relative_progress_m,0),"METRIC_04 explicit material displacement also excludes rotational carry")
	var missing:Dictionary=linear(Vector3.RIGHT)
	check(missing.movement.support_relative_progress_m==null,"METRIC_04 absent material reference is null, not estimated by integrating speed")

func time_and_response()->void:
	var m=Metrics.new()
	var first:Dictionary=point(0,Vector3.ZERO,Vector3.ZERO)
	first.velocity=Vector3.ZERO
	m.start(first,Vector3.RIGHT,{"physics_hz":hz,"response_velocity_m_s":.1,"response_persistence_s":.05})
	for i in range(1,hz+1):
		var s:Dictionary=point(i,Vector3.ZERO,Vector3.ZERO if i<int(.2*hz) else Vector3.RIGHT)
		s.velocity=Vector3.RIGHT*(.2 if i>=int(.3*hz) else 0.0)
		m.push(s)
	var result:Dictionary=m.finish()
	check(near(result.response.onset.time,.2) and result.response.onset.tick==int(.2*hz),"METRIC_05 neutral prelude does not count as accepted input onset")
	check(near(result.response.latency_s,.1,1.0/hz+.00001),"sustained velocity response reports candidate start after persistence is verified")
	check(result.quality.time_tick_mismatch==0,"METRIC_05 supplied timestamps align with physics ticks")
	check(not m.push(point(hz)) and not m.push({"time":2.0,"tick":hz-1,"com_position":Vector3.ZERO}),"METRIC_05 duplicate or backwards physics samples are rejected")
	var bad:Dictionary=point(hz+1)
	bad.time=2.0
	m.push(bad)
	check(m.finish().quality.time_tick_mismatch==1,"METRIC_05 timestamp/tick mismatch is diagnosed without fabricating cadence")
	var transient=Metrics.new()
	first=point(0);first.velocity=Vector3.ZERO
	transient.start(first,Vector3.RIGHT,{"response_persistence_s":.05})
	for i in range(1,int(.3*hz)+1):
		var s:Dictionary=point(i)
		s.velocity=Vector3.RIGHT if i==2 else Vector3.ZERO
		transient.push(s)
	check(transient.finish().response.latency_s==null,"one-frame collision/velocity spike is not a sustained response")
	var reverse=Metrics.new()
	reverse.start(point(0),Vector3.RIGHT)
	reverse.push(point(1,Vector3.ZERO,Vector3.ZERO))
	reverse.push(point(2,Vector3.ZERO,Vector3.LEFT))
	reverse.push(point(3,Vector3.ZERO,Vector3.LEFT))
	check(reverse.finish().response.reversals==1 and reverse.finish().response.corrections==1,"explicit opposite input counts once through neutral; body oscillation does not")
	check(near(reverse.finish().direction_world.dot(Vector3.RIGHT),1),"direction remains frozen after command reversal, not reoriented to hide negative progress")
	var accelerated=Metrics.new()
	first=point(0);first.velocity=Vector3.ZERO
	accelerated.start(first,Vector3.RIGHT,{"response_mode":"acceleration","response_acceleration_m_s2":.5,"response_persistence_s":.05})
	for i in range(1,int(.2*hz)+1):
		var s:Dictionary=point(i)
		s.velocity=Vector3.RIGHT*float(i)/hz
		s.saturated=true
		accelerated.push(s)
	check(near(accelerated.finish().response.latency_s,1.0/hz),"configurable sustained acceleration response uses supplied physics velocity derivative")
	check(near(accelerated.finish().saturation.duration_s,.2) and near(accelerated.finish().saturation.fraction,1),"saturation integrates known applied-budget boolean duration")
	var accepted=Metrics.new()
	first=point(0,Vector3.ZERO,Vector3.ZERO);first.velocity=Vector3.ZERO
	accepted.start(first,Vector3.RIGHT,{"response_persistence_s":0.0})
	accepted.record_event({"type":"command_onset","time":.1,"tick":int(.1*hz),"velocity":Vector3.ZERO})
	var response:Dictionary=point(int(.2*hz),Vector3(.01,0,0));response.velocity=Vector3.RIGHT
	accepted.push(response)
	check(near(accepted.finish().response.latency_s,.1) and accepted.finish().response.onset.source=="explicit_accepted_input_event","explicit accepted-input event can precede filtered/sampled movement intent without hidden latency")
	var coincident=Metrics.new()
	coincident.start(point(0),Vector3.RIGHT,{"response_persistence_s":0.0})
	coincident.record_event({"type":"command_onset","time":0.0,"tick":0,"velocity":Vector3.ZERO})
	coincident.push(point(int(.2*hz),Vector3(.1,0,0)))
	check(coincident.finish().response.onset.source=="explicit_accepted_input_event" and near(coincident.finish().response.latency_s,.2),"explicit coincident accepted onset replaces first observed onset and its velocity baseline")
	var preheld=Metrics.new()
	preheld.start(point(int(.2*hz)),Vector3.RIGHT,{"response_persistence_s":0.0})
	preheld.record_event({"type":"command_onset","time":.1,"tick":int(.1*hz),"velocity":Vector3.ZERO})
	preheld.push(point(int(.3*hz),Vector3(.1,0,0)))
	check(preheld.finish().response.latency_s==null and preheld.finish().response.latency_reason=="PREHELD_INPUT","input already held before measurement has unknown latency rather than manufactured zero")

func contact(kind:String,state:String,force:Vector3,velocity:Variant=Vector3.UP)->Dictionary:
	return {"kind":kind,"state":state,"force":force,"point_velocity":velocity,"support_velocity":Vector3.ZERO,"normal":Vector3.UP,"applied":true}

func loads_and_work()->void:
	var m=Metrics.new()
	m.start(point(0),Vector3.UP)
	var s:Dictionary=point(hz)
	s.contacts=[contact("foot","PLANTING",Vector3.UP*50)]
	m.push(s)
	check(m.finish().support.foot_loaded_time_fraction==0 and m.finish().support.partial_actuator_work_j==0,"FEET_01 PLANTING is neither loaded nor actuator work even with invalid cached force")
	check(m.finish().quality.invalid_unloaded_force_samples==1,"FEET_01 impossible unloaded force is diagnosed")
	s=point(2*hz)
	s.contacts=[contact("foot","SUPPORTING",Vector3.UP*40),contact("hand","ATTACHED",Vector3.UP*60)]
	m.push(s)
	check(near(m.finish().support.foot_loaded_time_fraction,.5) and near(m.finish().support.foot_upward_load_fraction,.4),"FEET_01 load duration and positive upward load fraction use real applied contacts")
	check(near(m.finish().support.partial_actuator_work_j,100),"signed actual point force power integrates work in joules")
	var braking=Metrics.new()
	braking.start(point(0),Vector3.UP)
	s=point(hz);s.contacts=[contact("hand","ATTACHED",Vector3.DOWN*30)]
	braking.push(s)
	check(near(braking.finish().support.partial_actuator_work_j,-30),"SWING_02 negative force dot velocity remains negative braking work")
	s=point(2*hz);s.contacts=[contact("hand","ATTACHED",Vector3.UP*30,null)]
	braking.push(s)
	check(braking.finish().support.partial_actuator_work_j==null and near(braking.finish().support.observed_partial_work_j,-30),"missing application point velocity returns unknown full work with separately labelled observed subtotal")
	var moving=Metrics.new()
	moving.start(point(0),Vector3.UP)
	s=point(hz);s.contacts=[contact("foot","SLIDING",Vector3.UP*20,Vector3.UP*2)]
	s.contacts[0].support_velocity=Vector3.UP
	moving.push(s)
	check(near(moving.finish().support.partial_actuator_work_j,40) and near(moving.finish().support.relative_actuator_work_j,20),"absolute and support-relative work are separate actual point velocities")
	check(moving.finish().support.foot_loaded_time_fraction==1,"loaded SLIDING foot counts as physical support")
	var hybrid=Metrics.new()
	hybrid.start(point(0),Vector3.UP)
	s=point(hz);s.assisted=true;s.contacts=[contact("hand","ATTACHED",Vector3.UP*100)]
	hybrid.push(s)
	check(hybrid.finish().support.partial_actuator_work_j==null and hybrid.finish().quality.hybrid_cached_force_samples==1,"hybrid cached hand force is flagged and never credited as applied work")
	var absent=Metrics.new()
	absent.start(point(0),Vector3.UP)
	s=point(hz);s.erase("contacts");absent.push(s)
	check(absent.finish().support.foot_loaded_time_fraction==null and absent.finish().support.partial_actuator_work_j==null,"absent contacts/load/work remain null")
	var unconfirmed=Metrics.new()
	unconfirmed.start(point(0),Vector3.UP)
	s=point(hz);s.contacts=[contact("hand","ATTACHED",Vector3.UP*100)];s.contacts[0].erase("applied")
	unconfirmed.push(s)
	check(unconfirmed.finish().support.partial_actuator_work_j==null,"requested or unconfirmed forces cannot become applied work implicitly")
	s=point(3*hz);s.erase("contacts");m.push(s)
	check(m.finish().support.partial_actuator_work_j==null and near(m.finish().support.observed_partial_work_j,100),"missing later contact sample invalidates complete work instead of filling missing interval with zero")
	rows.append({"case":"loads","result":m.finish()})

func events_and_bounds()->void:
	var m=Metrics.new()
	var snapshot:Dictionary=point(0)
	var saved:Dictionary=snapshot.duplicate(true)
	m.start(snapshot,Vector3.RIGHT,{"max_samples":4,"max_events":3,"physics_hz":hz})
	m.record_event({"type":"attempt","hand_id":0,"attempt_id":4,"time":0.0,"tick":0})
	m.record_event({"type":"contact","hand_id":0,"attempt_id":4,"time":.1,"tick":int(.1*hz)})
	check(m.finish().capture.contacts==1 and m.finish().capture.retained==0,"CAPTURE_01 actual contact does not imply retained grip")
	m.record_event({"type":"retained","hand_id":0,"attempt_id":4,"time":.6,"tick":int(.6*hz)})
	m.record_event({"type":"retained","hand_id":0,"attempt_id":4,"time":.7,"tick":int(.7*hz)})
	check(m.finish().capture.contacts==1 and m.finish().capture.retained==1,"CAPTURE_01 retention is explicit and not duplicated per frame")
	check(not m.record_event({"type":"retained","hand_id":1,"attempt_id":99,"time":.7,"tick":int(.7*hz)}),"CAPTURE_01 retention cannot be fabricated for an attempt with no contact event")
	m.record_event({"type":"event","time":.8,"tick":2})
	check(m.finish().quality.event_time_tick_mismatch==1,"METRIC_05 event timestamps carry same physics tick validation as samples")
	for i in range(1,10*hz+1):
		m.push(point(i,Vector3(float(i)/hz,0,0)))
		m.record_event({"type":"sample_event","time":float(i)/hz,"tick":i})
	check(m.recent_samples().size()==4 and m.recent_events().size()==3 and m.finish().quality.evicted_samples>0,"OBSERVER_03 sample/event buffers are bounded without losing accumulated progress")
	check(near(m.finish().movement.useful_progress_m,10) and near(m.finish().movement.path_length_m,10),"bounded ring eviction does not reset aggregate metrics")
	var copy:Array=m.recent_samples();copy[0].position=Vector3(999,0,0)
	check(m.recent_samples()[0].position.x<999 and snapshot==saved,"analysis retains independent numeric snapshots and never mutates caller transforms")
	check(m.finish().buffers.max_samples==4 and m.finish().buffers.max_events==3,"configured retention limits are included in summary")
	m.reset()
	check(m.recent_samples().is_empty() and m.finish().capture.contacts==0,"reset clears aggregate and bounded capture history")

func target_settling()->void:
	var m=Metrics.new()
	m.start(point(0),Vector3.RIGHT,{"target_progress_m":1.0,"target_corridor_m":.02,"settle_linear_m_s":.1,"settle_angular_rad_s":.2,"settle_hold_s":.2})
	var s:Dictionary=point(int(.25*hz),Vector3(1.1,0,0));s.angular_velocity=Vector3.ZERO
	m.push(s)
	check(near(m.finish().movement.overshoot_m,.08),"target overshoot measures excess beyond configured goal corridor, preserving real displacement")
	s=point(int(.5*hz),Vector3(1,0,0));s.velocity=Vector3.ZERO;s.angular_velocity=Vector3.ZERO;m.push(s)
	s=point(int(.6*hz),Vector3(1,0,0));s.velocity=Vector3(.3,0,0);s.angular_velocity=Vector3.ZERO;m.push(s)
	check(m.finish().settling.time_s==null,"isolated low-speed/contact frame is not sustained settling")
	s=point(int(.7*hz),Vector3(1,0,0));s.velocity=Vector3.ZERO;s.angular_velocity=Vector3.ZERO;m.push(s)
	s=point(int(.85*hz),Vector3(1,0,0));s.velocity=Vector3.ZERO;s.angular_velocity=Vector3.ZERO;m.push(s)
	check(not m.finish().settling.currently_settled,"interrupted stability restarts the continuous persistence window")
	s=point(int(.95*hz),Vector3(1,0,0));s.velocity=Vector3.ZERO;s.angular_velocity=Vector3.ZERO;m.push(s)
	check(m.finish().settling.currently_settled and near(m.finish().settling.time_s,.2),"settling reports beginning of final continuous stable interval relative to first target entry")
	s=point(hz,Vector3(1,0,0));s.erase("velocity");s.angular_velocity=Vector3.ZERO;m.push(s)
	check(m.finish().settling.time_s==null and m.finish().settling.reason=="MISSING_VELOCITY","missing measured velocity makes current settling unknown, not a fabricated zero speed")
	var missing=Metrics.new();missing.start(point(0),Vector3.RIGHT);missing.push(point(hz))
	check(missing.finish().movement.overshoot_m==null and missing.finish().movement.overshoot_reason=="NO_TARGET","overshoot stays null with NO_TARGET when task has no spatial target")

func run()->void:
	basic();carry();time_and_response();loads_and_work();events_and_bounds();target_settling()
	var report:Dictionary={"physics_hz":hz,"checks":checks,"failures":failures,"source":"synthetic_numeric_unit_tests","cases":rows}
	FileAccess.open("res://builds/measurement_metrics_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MEASUREMENT METRICS RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
