extends "res://features/grip_up/tests/first_ascent_exercise.gd"
## F0 only: ordinary input preparation followed by a declared diagnostic block.
## No body, contact, geometry or force assignments. Optional F0 ablation uses
## only the existing UI physical-feet setter, including its ordinary reset.
const Diagnostics=preload("res://features/foot_release_lab/scripts/foot_diagnostics.gd")

signal post_tick

var observer:Node
var condition:="B1"
var output_dir:=""
var _stage:="NOT_STARTED"
var _events:Array[Dictionary]=[]
var _sections:Array[Dictionary]=[]
var _configuration:Dictionary={}
var _recording:=false
var _physics_tick:=0
var _hotspot_reached:=false
var _support_losses:Array[Dictionary]=[]
var _ever_attached:=false
var _was_supported:=false
var _hard_failure:=""
var _ablate_at_cross:=false
var _ablation_receipt:Dictionary={}

func _ready()->void:
	# The F0 observer samples at 100, after the existing control callbacks.
	# Resume the input exercise only after that same tick's observation at 200.
	process_physics_priority=200

func _physics_process(delta:float)->void:
	if _recording and is_instance_valid(app) and is_instance_valid(app.controller):
		_physics_tick+=1
		elapsed+=delta
		var data:Dictionary=app.controller.telemetry()
		if not data.is_empty():
			var hand_force:float=data.total_force
			var leg_force:float=data.leg_force
			var combined:Vector3=Vector3(data.torque)+app.ground_motor.applied_torque
			peaks.hand_force=maxf(peaks.hand_force,hand_force)
			peaks.leg_force=maxf(peaks.leg_force,leg_force)
			peaks.combined_moment=maxf(peaks.combined_moment,combined.length())
			if not is_finite(hand_force) or not is_finite(leg_force) or not combined.is_finite():
				_hard_failure="NONFINITE_TELEMETRY"
			elif hand_force>360.001 or leg_force>180.001 or combined.length()>150.001:
				_hard_failure="OBSERVED_BUDGET_EXCEEDED"
			budgets_ok=budgets_ok and _hard_failure.is_empty()
		var supported:bool=not app.controller._attached_ids().is_empty()
		if _was_supported and not supported:
			_support_losses.append(_state("ALL_REAL_HAND_SUPPORT_LOST"))
		_ever_attached=_ever_attached or supported
		_was_supported=supported
		if app.controller.assisted_motion_owned or app.hybrid_mantle.commits>0:
			_hard_failure="UNEXPECTED_ASSISTED_OWNERSHIP"
	post_tick.emit()

func ticks(seconds:float)->void:
	for frame in maxi(1,int(round(seconds*hz))):
		await post_tick
		if not _hard_failure.is_empty():return

func _state(label:String)->Dictionary:
	if not is_instance_valid(app):return {"label":label,"time_s":elapsed,"tick":_physics_tick}
	return {"label":label,"stage":_stage,"time_s":elapsed,"tick":_physics_tick,
		"torso_origin":app.torso.global_position,"body_velocity":app.torso.linear_velocity,
		"grounded":app.ground_motor.grounded,"hybrid_owned":app.controller.assisted_motion_owned,
		"hands":app.controller.hands.map(func(hand):return {"state":hand.state,"reason":hand.reason,"anchor":hand.anchor_world,"force_N":hand.force}),
		"actions":{"W":Input.is_action_pressed("contract"),"S":Input.is_action_pressed("extend"),"A":Input.is_action_pressed("bias_left"),"D":Input.is_action_pressed("bias_right")}}

func _label(value:String,policy:String)->void:
	_stage=value
	if is_instance_valid(observer):observer.stage=value
	var entry:Dictionary=_state(value)
	entry["policy"]=policy
	_events.append(entry)

func _movement(w:bool=false,d:bool=false,a:bool=false)->void:
	for action:String in ["contract","extend","bias_left","bias_right"]:
		Input.action_release(action)
	if w:Input.action_press("contract")
	if d:Input.action_press("bias_right")
	if a:Input.action_press("bias_left")

func _wait_stage(label:String,seconds:float,w:bool=false,d:bool=false,a:bool=false)->void:
	if not _hard_failure.is_empty():return
	_label(label,"FIXED_DURATION_REAL_ACTIONS")
	_movement(w,d,a)
	var start:Dictionary=_state("START")
	await ticks(seconds)
	_sections.append({"label":label,"policy":"FIXED_DURATION_REAL_ACTIONS","planned_duration_s":seconds,"start":start,"end":_state("END")})

func _contact(id:int,point:Vector3,label:String,timeout_s:float=3.0)->bool:
	if not _hard_failure.is_empty():return false
	_label(label,"ADAPTIVE_ACTUAL_CONTACT_WAIT_BOUNDED_%.2fs"%timeout_s)
	button(id,false)
	aim(point)
	button(id,true)
	var began:float=elapsed
	_events.append({"event":"REAL_MOUSE_SELECTION","label":label,"hand":id,"selected":point,"time_s":elapsed,"tick":_physics_tick,"shoulder":app.controller.get_shoulder_world(id)})
	for frame in int(round(timeout_s*hz)):
		await ticks(1.0/hz)
		if not _hard_failure.is_empty():return false
		if app.controller.get_hand_state(id)=="ATTACHED":
			var hand:Dictionary=app.controller.hands[id]
			var support:PhysicsBody3D=hand.anchor.support_body()
			ascent_contacts.append({"label":label,"hand":id,"time_s":elapsed,"tick":_physics_tick,"wait_s":elapsed-began,"selected":point,"actual_contact":hand.anchor.world_point(),"support_name":str(support.name) if support!=null else "INVALID","pending":app.controller.pending_diagnostics(id),"state":_state("CONTACT")})
			return true
	failed_transfer={"label":label,"hand":id,"selected":point,"wait_s":elapsed-began,"state":_state("CONTACT_TIMEOUT"),"pending":app.controller.pending_diagnostics(id)}
	return false

func _prefix()->bool:
	# The existing original_course prefix, with its input order and wait durations.
	# Its real-contact waits are adaptive; this is deliberately not a fixed tape.
	if not await _contact(0,app.level.transfer_points[0],"ENTRY_LEFT",1.0):return false
	if not await _contact(1,app.level.transfer_points[1],"ENTRY_RIGHT",1.0):return false
	await _wait_stage("ENTRY_DUAL_SETTLE",.30)
	await _wait_stage("CLIMB_W",3.0,true)
	if not await _contact(0,app.level.transfer_points[2],"HIGHER_LEFT_WALL"):return false
	await _wait_stage("HIGHER_LEFT_W",.25,true)
	_movement(true,true)
	if not await _contact(1,app.level.transfer_points[3],"HIGHER_RIGHT_WALL"):return false
	await _wait_stage("HIGHER_RIGHT_W",1.0,true)
	_movement(true,true)
	if not await _contact(0,app.level.transfer_points[4],"LEFT_CROSSING"):return false
	await _wait_stage("CROSS_W_D",.60,true,true)
	if not await _contact(1,app.level.transfer_points[5],"RIGHT_UNCOVERED_WALL_EDGE"):return false
	await _wait_stage("WALL_EDGE_W_D",.30,true,true)
	if not await _contact(1,Vector3(.69,2.51,.20),"RIGHT_AROUND_BAR_LEADING_EDGE"):return false
	await _wait_stage("BAR_LEADING_EDGE_W_D",.30,true,true)
	_hotspot_reached=true
	_events.append(_state("LOCALIZED_CROSS_WINDOW_REACHED"))
	return _hard_failure.is_empty()

func _diagnostic_block()->void:
	# Same fixed commands in B0/B1. No state-dependent rescue, release policy,
	# replant or synthetic anchor. W is genuinely released in each neutral stage.
	await _wait_stage("DIAGNOSTIC_NEUTRAL_1",.30)
	await _wait_stage("DIAGNOSTIC_D_AWAY",.60,false,true)
	await _wait_stage("DIAGNOSTIC_NEUTRAL_2",.30)
	await _wait_stage("DIAGNOSTIC_A_REVERSAL",.25,false,false,true)
	await _wait_stage("DIAGNOSTIC_NEUTRAL_3",.30)
	if not _hard_failure.is_empty():return
	_label("DIAGNOSTIC_RELEASE_LEFT","REAL_MOUSE_RELEASE_ONLY_NO_CONTACT_WRITES")
	button(0,false)
	await _wait_stage("DIAGNOSTIC_RIGHT_ONLY_D",.45,false,true)
	await _wait_stage("DIAGNOSTIC_RIGHT_ONLY_NEUTRAL",.30)
	if not _hard_failure.is_empty():return
	_movement(true,true)
	var recovered:bool=await _contact(0,Vector3(.74,2.53,.20),"RECOVERY_FIRST_BAR_LEFT")
	_events.append({"event":"RECOVERY_ATTEMPT_RESULT","attached":recovered,"time_s":elapsed,"tick":_physics_tick})
	await _wait_stage("DIAGNOSTIC_FINAL_NEUTRAL",.30)

func _ablation_state()->Dictionary:
	return {"controller_step":app.controller._step,"physical_feet":app.physical_feet_enabled,"resource_physical_feet":app.controller.tuning.physical_feet,
		"body_transform":app.torso.global_transform,"linear_velocity":app.torso.linear_velocity,"angular_velocity":app.torso.angular_velocity,
		"collision_layer":app.torso.collision_layer,"collision_mask":app.torso.collision_mask,
		"FootBase_transform":app.torso.get_node("FootBase").global_transform,"LowerCapsule_transform":app.torso.get_node("LowerCapsule").global_transform,
		"feet":app.controller.feet_solver.feet.map(func(foot):return {"state":foot.state,"force_N":foot.force,"ankle":foot.ankle,"contact_point":foot.contact_point,"local_point":foot.local_point,"reason":foot.reason}),
		"hands":_state("ABLATION_HANDS").hands}

func _apply_cross_ablation()->void:
	_label("ABLATION_B1_TO_B0_AT_CROSS","EXISTING_UI_PHYSICAL_FEET_SETTER_NO_SIMULATION_BETWEEN_BEFORE_AFTER")
	var before:Dictionary=_ablation_state()
	app._set_physical_feet(false)
	var after:Dictionary=_ablation_state()
	var unchanged:bool=before.body_transform==after.body_transform and before.linear_velocity==after.linear_velocity and before.angular_velocity==after.angular_velocity and before.collision_layer==after.collision_layer and before.collision_mask==after.collision_mask and before.FootBase_transform==after.FootBase_transform and before.LowerCapsule_transform==after.LowerCapsule_transform and before.hands==after.hands and before.controller_step==after.controller_step
	_ablation_receipt={"event":"B1_TO_B0_ABLATION","time_s":elapsed,"tick":_physics_tick,"before":before,"after":after,
		"body_native_geometry_and_hands_unchanged_by_setter":unchanged,"setter":"app._set_physical_feet(false)","setter_semantics":"EXISTING_UI_SWITCH_INCLUDES_FOOT_SOLVER_RESET",
		"effective_force_boundary":"NEXT_CONTROLLER_PREP; ALREADY_SUBMITTED_FORCE_IS_NOT_RETROACTIVELY_REMOVED",
		"scope":"State-matched intervention on physical feet plus existing foot IK ownership; not an independent actuator-only intervention or B3 policy"}
	_events.append(_ablation_receipt)
	if not unchanged or app.physical_feet_enabled or app.controller.tuning.physical_feet:
		_hard_failure="ABLATION_SWITCH_FAILED_OR_UNEXPECTED_BODY_HAND_MUTATION"

func run_condition(feet_enabled:bool,destination:String)->Dictionary:
	_ablate_at_cross=OS.get_cmdline_user_args().has("--ablate-at-cross")
	condition="B1" if feet_enabled else "B0"
	if _ablate_at_cross:condition="B1_TO_B0_ABLATION"
	output_dir=destination
	for action:String in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:
		if InputMap.has_action(action):Input.action_release(action)
	app=Lab.new()
	get_tree().root.add_child(app)
	get_tree().current_scene=app
	# Synchronous before the new First Ascent world's first simulation step.
	app._open_first_ascent()
	app._set_movement_allocation(0)
	app._set_intent_aware_feet(false)
	app._set_physical_feet(feet_enabled)
	app._set_distant_targeting(true)
	_configuration={"profile":app.input_profile,"controller_profile":app.controller.control_profile,"allocation":app.movement_allocation,"coordinator_allocation":app.controller.intent_locomotion.movement_allocation,"B2":app.intent_aware_feet_enabled,"controller_B2":app.controller.intent_aware_feet_enabled,"physical_feet":app.physical_feet_enabled,"resource_physical_feet":app.controller.tuning.physical_feet,"hold_mode":app.hold_mode,"scenario":app.level.scenario,"controller_step":app.controller._step}
	_configuration["planned_cross_ablation"]=_ablate_at_cross
	observer=Diagnostics.new()
	observer.app=app
	observer.output_dir=output_dir
	observer.condition=condition
	app.add_child(observer)
	_label("SETUP_WARMUP","FIXED_0.40s_NO_MOVEMENT_COMMAND")
	observer.start_recording()
	_recording=true
	var exact_flags:bool=app.input_profile==4 and app.controller.control_profile==4 and app.movement_allocation==0 and app.controller.intent_locomotion.movement_allocation==0 and not app.intent_aware_feet_enabled and not app.controller.intent_aware_feet_enabled and app.physical_feet_enabled==feet_enabled and app.controller.tuning.physical_feet==feet_enabled and app.hold_mode and app.level.scenario=="FIRST_ASCENT" and app.controller._step==0
	exact_flags=exact_flags and (not _ablate_at_cross or feet_enabled)
	if not exact_flags:
		_hard_failure="SETUP_FLAGS_NOT_A0_B0_OR_B1_PRE_STEP"
	else:
		await ticks(.40)
		var prepared:bool=await _prefix()
		if prepared:
			if _ablate_at_cross:_apply_cross_ablation()
			if _hard_failure.is_empty():await _diagnostic_block()
	_label("END_MEASUREMENT_BEFORE_CLEANUP","NO_CLEANUP_RELEASE_INCLUDED_IN_SUPPORT_LOSS_COUNTS")
	var final_state:Dictionary=_state("FINAL")
	_recording=false
	var receipt:Dictionary=observer.stop_recording()
	var status:String="DIAGNOSTIC_COMPLETE" if _hotspot_reached else "PREPARATION_FAILED"
	if not _hard_failure.is_empty():status="BLOCKED_SAFETY_OR_SETUP"
	report={"schema":"foot_release_repro_v14_F0_r1","status":status,"condition":condition,"physics_hz":hz,"hard_failure":_hard_failure,"configuration_pre_step":_configuration,"reached_localized_cross_window":_hotspot_reached,"prefix_policy":"ORIGINAL_FIRST_ASCENT_REAL_INPUT_PREFIX_WITH_BOUNDED_ADAPTIVE_CONTACT_WAITS","diagnostic_policy":"DECLARED_FIXED_DURATION_ACTIONS_AFTER_CROSS_WINDOW_PLUS_ONE_BOUNDED_REAL_RECOVERY_SELECTION","sample_phase":"AFTER_OBSERVER_PRIORITY_100_AT_DRIVER_PRIORITY_200_BEFORE_NEXT_INTEGRATION","scope":"F0 causal diagnosis only; not a desticking test, no B3 and no human-feel verdict","selected_bar_points_scope":"Existing first_ascent_exercise free-surface points; no geometry changes","contacts":ascent_contacts,"failed_transfer":failed_transfer,"sections":_sections,"events":_events,"support_losses_before_cleanup":_support_losses,"ever_actual_attached":_ever_attached,"budgets_ok":budgets_ok,"peaks":peaks,"final_state":final_state,"observer":receipt,"cleanup":{}}
	report["driver_revision"]="F0_r2_optional_declared_cross_ablation"
	report["driver_sha256"]=FileAccess.get_sha256("res://features/foot_release_lab/tests/foot_release_repro.gd")
	report["cross_ablation"]=_ablation_receipt
	# Cleanup follows measurement, through the same public input route.
	_movement()
	for id in 2:button(id,false)
	await post_tick
	report.cleanup={"actions_neutral":not Input.is_action_pressed("contract") and not Input.is_action_pressed("extend") and not Input.is_action_pressed("bias_left") and not Input.is_action_pressed("bias_right"),"hands":app.controller.hands.map(func(hand):return hand.state),"phase":"POST_INPUT_CLEANUP_NOT_MEASURED"}
	Diagnostics.save_json(output_dir.path_join("attempt_report.json"),report)
	return report
