extends SceneTree
## Pure Node/input/serialization tests. No RigidBody or climbing world created.
const Driver=preload("res://features/evaluator_reliability/scripts/reliability_driver.gd")
const Writer=preload("res://features/evaluator_reliability/scripts/reliability_trace.gd")
const Reader=preload("res://features/evaluator_reliability/scripts/physics_snapshot.gd")
const BaselineLab=preload("res://features/evaluator_reliability/scripts/baseline_lab.gd")
const Loader=preload("res://features/auto_tuning_lab/scripts/optimization_override_loader.gd")
const Profile=preload("res://features/grip_up/resources/biped_tuning.gd")
class FakeTorso extends RefCounted:
	var linear_velocity:=Vector3.ZERO
	var angular_velocity:=Vector3.ZERO
class FakeController extends RefCounted:
	var _step:=0
class TuningHolder extends Node:
	var tuning:Resource
class FakeApp extends Node:
	var torso=FakeTorso.new()
	var controller=FakeController.new()
	var override_error:=""
class SetupBlockedDriver extends "res://features/evaluator_reliability/scripts/reliability_driver.gd":
	func _fresh(_definition:Dictionary)->void:
		app=FakeApp.new()
		app.override_error="BASELINE_RESOURCE_MISMATCH:unit"
class RetirementBlockedDriver extends "res://features/evaluator_reliability/scripts/reliability_driver.gd":
	func _retire_previous_world()->bool:return false
class PureDriver extends "res://features/evaluator_reliability/scripts/reliability_driver.gd":
	var actual_input:=Vector2.ZERO
	func _snapshot(phase:String)->Dictionary:
		var row:Dictionary=_metadata(phase)
		row.merge({"body":{"com_m":Vector3.ZERO,"pose":Transform3D.IDENTITY,"linear_velocity_m_s":Vector3.ZERO,"angular_velocity_rad_s":Vector3.ZERO},"command_accepted":{"accepted_input":Vector2.ZERO},"support":{"valid":false,"grounded":false},"force_budget":{"ground_force_n":Vector3.ZERO,"ground_torque_nm":Vector3.ZERO},"hands":[{"id":0,"state":"FREE","pending":{},"anchor_runtime_id":0,"force_n":Vector3.ZERO},{"id":1,"state":"FREE","pending":{},"anchor_runtime_id":0,"force_n":Vector3.ZERO}]},true)
		row.command_accepted.accepted_input=actual_input
		return row
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
	for action in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	var driver=PureDriver.new();root.add_child(driver)
	driver.pre_probe.set_physics_process(false);driver.post_probe.set_physics_process(false)
	driver.app=FakeApp.new();root.add_child(driver.app)
	driver.current_definition={"id":"unit_queue","revision":1};driver.manifest={"run_id":"unit","engine_mode":"headless"};driver._scenario_enabled=true
	check(driver.pre_probe.process_physics_priority==-100 and driver.post_probe.process_physics_priority==100,"input and read-only probes bracket gameplay priorities")
	driver._set_keys(["bias_right"])
	check(not Input.is_action_pressed("bias_right"),"requested input does not mutate game input before a physics boundary")
	driver._pre_tick(1.0/120)
	check(Input.is_action_pressed("bias_right") and driver._scenario_tick==1,"queued request emitted exactly at first pre-control tick")
	driver._set_keys([])
	check(Input.is_action_pressed("bias_right"),"neutral request waits until next physics boundary")
	driver._pre_tick(1.0/120)
	check(not Input.is_action_pressed("bias_right") and driver._scenario_tick==2,"neutral emitted at exact next tick")
	driver._post_tick(1.0/120)
	check(driver.latest.sample_phase=="post_control" and driver.latest.tick==2 and driver.latest.episode_tick==2,"post snapshot names its consistent phase and tick aliases")
	check(driver.latest.command_accepted.accepted_input==Vector2.ZERO,"accepted input is measured separately, never copied from the requested command")
	driver._pending_transition={"kind":"reverse","requested_tick":1,"expected_input":Vector2.RIGHT}
	driver._post_tick(1.0/120)
	check(not driver._pending_transition.has("accepted_tick"),"requested tick cannot masquerade as accepted transition while routing input differs")
	driver.actual_input=Vector2.RIGHT;driver._post_tick(1.0/120)
	check(driver._pending_transition.accepted_tick==2 and driver._pending_transition.requested_tick==1,"late input acknowledgement records observed post-control tick, not prediction")
	driver.measurement_active=false;driver._pending_transition.clear();driver._tick_events.clear()
	var hand:Dictionary={"id":0,"state":"ATTACHED","pending":{},"anchor_runtime_id":33,"force_n":Vector3.UP*2}
	driver._chain({"hands":[hand,{"id":1,"state":"FREE","pending":{},"anchor_runtime_id":0,"force_n":Vector3.ZERO}]})
	var codes:Array=driver._tick_events.map(func(event):return event.event_code)
	check(codes.find("CONTACT_VALIDATED")>=0 and codes.find("CONTACT_VALIDATED")<codes.find("ATTACHED") and codes.find("ATTACHED")<codes.find("LOAD_ADMITTED"),"derived contact chain preserves contact, attachment and admitted-load ordering")
	driver._tick_events.clear();hand.anchor_runtime_id=44
	driver._chain({"hands":[hand,{"id":1,"state":"FREE","pending":{},"anchor_runtime_id":0,"force_n":Vector3.ZERO}]})
	check(driver._tick_events.any(func(event):return event.event_code=="CONTACT_VALIDATED") and driver._retained[0].anchor==44,"same-frame regrip identity starts a fresh contact/retention chain")
	var path:String="res://builds/evaluator_reliability/unit_"+str(Time.get_ticks_usec())
	var writer=Writer.new();check(writer.open_at(path,true),"new unique output opens trial-local temporary JSONL files")
	writer.counts["bounded"]=Writer.MAX_ROWS_PER_SCENARIO-1
	writer.sample({"scenario_id":"bounded","sample_phase":"post_control","body":{"com_m":Vector3(1,2,3)}})
	writer.sample({"scenario_id":"bounded","sample_phase":"post_control"})
	writer.event({"event_code":"CONTACT_VALIDATED","event_id":1})
	var stats:Dictionary=writer.close()
	check(stats.trace_rows==1 and stats.dropped_rows==1 and stats.event_rows==1,"trace bound is explicit and does not silently discard samples")
	var decoded:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"/trace.jsonl").strip_edges())
	check(decoded.body.com_m==[1.0,2.0,3.0],"numeric Vector3 serializes without losing the named COM reference")
	check(not FileAccess.file_exists(path+"/trace.jsonl.tmp") and FileAccess.file_exists(path+"/events.jsonl"),"JSONL files become final only after close/atomic rename")
	var repeated=Writer.new();check(not repeated.open_at(path,true),"existing evidence cannot be overwritten")
	var before:=Input.is_action_pressed("contract")
	var quiet=Writer.new();check(quiet.open_at(path+"_off",false),"recorder OFF creates no trace authority")
	quiet.sample({"scenario_id":"ignored"});quiet.event({"event_code":"ignored"});quiet.close()
	check(not FileAccess.file_exists(path+"_off/trace.jsonl") and Input.is_action_pressed("contract")==before,"disabled output leaves input unchanged and records no fake trace")
	var invalid=Driver.new();root.add_child(invalid)
	var rejected:Dictionary=await invalid.start({})
	check(rejected.status=="BLOCKED_SETUP" and invalid.app==null,"invalid manifest blocks before a gameplay Lab/body is constructed")
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Driver.CATALOG))
	check(catalog.scenarios.size()==12 and catalog.thresholds.clean_max_wait_s==5 and catalog.thresholds.clean_confirmation_s==.25,"prospective fixture registry and unchanged confirmation thresholds are explicit")
	check(catalog.revision==3 and catalog.thresholds.motion_velocity_interval_m_s==[.15,.5] and catalog.thresholds.low_energy_velocity_scope=="full_support_relative_speed_norm","revision 3 preserves calibrated bands and declares exact elapsed confirmation")
	check(not Driver._motion_velocity_eligible(.078,false),"stop preparation rejects the observed revision 1 start already inside the stopped band")
	check(Driver._motion_velocity_eligible(.15,false) and Driver._motion_velocity_eligible(.5,false) and not Driver._motion_velocity_eligible(.149999,false) and not Driver._motion_velocity_eligible(.500001,false),"stop/brake/reverse starts require the explicit .15 to .50 directed speed interval")
	check(Driver._motion_velocity_eligible(-.02,true) and Driver._motion_velocity_eligible(-.5,true) and not Driver._motion_velocity_eligible(-.019,true),"counter-swing preparation keeps its original opposing-speed interval")
	check(Driver._quiet_velocity_eligible(Vector3(.003,.145,0),Vector3.ZERO,Vector3.RIGHT) and not Driver._quiet_velocity_eligible(Vector3(.003,.145,0),Vector3.ZERO,Vector3.RIGHT,true),"clean lateral may be quiet while low-energy correctly rejects vertical/depth motion")
	check(Driver._quiet_velocity_eligible(Vector3(.09,0,0),Vector3.UP*.19,Vector3.RIGHT,true) and not Driver._quiet_velocity_eligible(Vector3(.09,.09,0),Vector3.ZERO,Vector3.RIGHT,true) and not Driver._quiet_velocity_eligible(Vector3.ZERO,Vector3.UP*.201,Vector3.RIGHT,true),"low-energy requires both full relative speed and angular norm inside the unchanged settling bands")
	var blocked=SetupBlockedDriver.new();root.add_child(blocked)
	blocked.pre_probe.set_physics_process(false);blocked.post_probe.set_physics_process(false)
	var setup_result:Dictionary=await blocked._control_case({"id":"unit_bad_baseline","revision":2})
	check(setup_result.status=="BLOCKED_SETUP" and not setup_result.completed and setup_result.reason=="BASELINE_RESOURCE_MISMATCH:unit" and blocked._scenario_tick==0 and blocked._desired_keys.is_empty(),"baseline setup error is returned before any acquisition, prep or settling can hide it")
	blocked.app.free();blocked.app=null;blocked.queue_free()
	check(not Driver._quiet_window_confirmed(100,129,120) and Driver._quiet_window_confirmed(100,130,120),"120 Hz quiet confirmation needs .25 elapsed seconds, not just 30 samples spanning .24167")
	check(not Driver._quiet_window_confirmed(100,114,60) and Driver._quiet_window_confirmed(100,115,60) and not Driver._quiet_window_confirmed(-1,200,60),"60 Hz quiet confirmation needs .25 elapsed seconds and cannot retain a broken interval")
	var clock=Driver.new();clock.hz=60
	clock._begin_clock_handshake();clock._record_clock_sample(1.0/120,0)
	check(clock._clock_status=="WAITING" and clock._clock_streak==0 and clock.app==null,"stale 120 Hz startup callback cannot authorize a requested 60 Hz world")
	clock._record_clock_sample(1.0/60,.01)
	check(clock._clock_status=="WAITING" and clock._clock_streak==1,"one correct callback alone does not settle the startup clock")
	clock._record_clock_sample(1.0/120,.02)
	check(clock._clock_streak==0 and clock._clock_status=="WAITING","wrong startup delta resets the consecutive confirmation")
	clock._record_clock_sample(1.0/60,.03);clock._record_clock_sample(1.0/60,.04)
	check(clock._clock_status=="READY" and not clock._clock_waiting and clock._clock_receipt.samples.size()==5 and clock._clock_receipt.samples.all(func(sample):return not sample.world_present),"two consecutive actual requested deltas authorize only an empty-world clock and retain every startup sample")
	clock._begin_clock_handshake();clock._record_clock_sample(1.0/60,5.0)
	check(clock._clock_status=="BLOCKED_SETUP" and clock._clock_receipt.reason=="CLOCK_NOT_SETTLED_TIMEOUT","unsettled startup clock has an explicit wall-deadline setup failure")
	clock._begin_clock_handshake()
	for index in Driver.CLOCK_MAX_TICKS:clock._record_clock_sample(1.0/120,.1)
	check(clock._clock_status=="BLOCKED_SETUP" and clock._clock_receipt.reason=="CLOCK_NOT_SETTLED_TICK_LIMIT" and clock._clock_receipt.samples.size()==Driver.CLOCK_MAX_TICKS,"startup callback budget is finite and never hides stale deltas")
	clock._begin_clock_handshake();clock.app=FakeApp.new();clock._record_clock_sample(1.0/60,0)
	check(clock._clock_status=="BLOCKED_SETUP" and clock._clock_receipt.reason=="WORLD_PRESENT_DURING_CLOCK_HANDSHAKE","startup settlement rejects any already-created lab instead of warming a mixed-frequency world")
	clock.app.free();clock.app=null;clock.free()
	var old_world=Node.new();old_world.name="RetirementUnitWorld"
	var old_child=Node.new();old_world.add_child(old_child);root.add_child(old_world)
	current_scene=old_world
	var exit_seen:Array=[false]
	old_world.tree_exited.connect(func():exit_seen[0]=true)
	var retired:Dictionary=Driver._retire_world_node(old_world)
	check(retired.present and retired.subtree_absent and retired.subtree_size==2 and not old_world.is_inside_tree() and not old_child.is_inside_tree() and exit_seen[0],"retirement synchronously exits the whole old subtree before another physics callback")
	check(current_scene==null and old_world.get_parent()==null and old_world.is_queued_for_deletion(),"current scene is cleared and reclamation is deferred only after synchronous detachment")
	var absent:Dictionary=Driver._retire_world_node(null)
	check(not absent.present and absent.subtree_absent and absent.physics_bodies_still_in_space==0,"first-world retirement explicitly records absence rather than inventing an old world")
	var retirement_blocked=RetirementBlockedDriver.new()
	var failed_retirement:Dictionary=await retirement_blocked._run_scenario({"id":"unit_failed_teardown","revision":3})
	check(failed_retirement.status=="BLOCKED_SETUP" and failed_retirement.reason=="OLD_WORLD_NOT_RETIRED" and retirement_blocked.app==null,"teardown failure returns before inherited acquisition can dereference a null Lab")
	retirement_blocked.free()
	var body_state:Dictionary={"body":{"com_m":Vector3.ZERO,"pose":Transform3D.IDENTITY,"linear_velocity_m_s":Vector3.ZERO,"angular_velocity_rad_s":Vector3.ZERO},"hands":[],"feet":[],"profile":4,"sample_phase":"pre_control"}
	var reference:Dictionary=Reader.stable_initial(body_state)
	body_state["runtime_id"]=12345;body_state["run_id"]="different_process"
	check(Reader.stable_initial(body_state)==reference,"stable physical initial-state identity excludes arbitrary process/run IDs")
	var baseline=BaselineLab.new();baseline.override_loader=Loader.new()
	var holder=TuningHolder.new();holder.tuning=Profile.new()
	var original:Resource=holder.tuning
	var verified:Dictionary=baseline.verify_tuning(holder)
	check(verified.ok and verified.mode=="BASELINE_IDENTITY_ONLY_NO_OVERRIDES" and holder.tuning==original and baseline.override_loader.bindings.is_empty(),"strict baseline verifies ORIGINAL Resource without duplication, assignment or override binding")
	holder.tuning.traversal_speed_m_s=.26
	verified=baseline.verify_tuning(holder)
	check(not verified.ok and holder.tuning==original and holder.tuning.traversal_speed_m_s==.26,"baseline drift is rejected and never silently rewritten to the expected value")
	holder.free();baseline.free()
	driver.app.queue_free();driver.queue_free();invalid.queue_free()
	for action in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:Input.action_release(action)
	print("RELIABILITY TICK CONTRACT RESULTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
