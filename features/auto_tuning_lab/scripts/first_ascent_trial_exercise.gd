extends "res://features/grip_up/tests/first_ascent_exercise.gd"
## Same existing continuous route and input policy. Only the Lab factory is
## replaced so four session-local planner values exist before any physics tick.
signal observed(lab:Node,delta:float)
signal physics_controller_ready(lab:Node,controller:Node)
const TrialLab=preload("res://features/auto_tuning_lab/scripts/optimization_trial_lab.gd")
var trial_candidate:Dictionary={}
var override_loader:RefCounted
var cancel_check:Callable
var _running:=false
var _aborted:=false
var _startup_ok:=true
var _phases:Dictionary={}
var _previous_phase:=""
var _previous_com:=Vector3.ZERO

func _controller_ready(controller:Node)->void:
	app._set_locomotion_diagnostics(true)
	app.transfer_diagnostics_enabled=true
	app._apply_independent_settings()
	physics_controller_ready.emit(app,controller)

func fresh(index:int,feet:bool=false)->void:
	if not is_instance_valid(app):
		app=TrialLab.new()
		app.override_loader=override_loader;app.trial_candidate=trial_candidate
		app.trial_controller_ready.connect(_controller_ready)
		get_tree().root.add_child(app);get_tree().current_scene=app
		_startup_ok=app.input_profile==2
	await super.fresh(index,feet)

func ticks(seconds:float)->void:
	for frame in int(seconds*hz):
		if _aborted:return
		if cancel_check.is_valid() and cancel_check.call():_aborted=true;return
		await super.ticks(1.0/hz)
		if not is_instance_valid(app):continue
		observed.emit(app,1.0/hz)
		if app.level.scenario!="FIRST_ASCENT":continue
		var phase:="hybrid_assisted" if app.controller.assisted_motion_owned else "dynamic"
		if not _phases.has(phase):_phases[phase]={"physics_samples":0,"duration_s":0.0,"com_path_m":0.0,"com_samples":0,"missing_com_samples":0,"partial_work_j":null}
		_phases[phase].physics_samples+=1;_phases[phase].duration_s+=1.0/hz
		var state:PhysicsDirectBodyState3D=PhysicsServer3D.body_get_direct_state(app.torso.get_rid())
		if state==null or not state.transform.origin.is_finite() or not state.center_of_mass.is_finite():
			_phases[phase].missing_com_samples+=1;_previous_phase="";continue
		var com:Vector3=state.transform.origin+state.center_of_mass
		_phases[phase].com_samples+=1
		if phase==_previous_phase:_phases[phase].com_path_m+=com.distance_to(_previous_com)
		_previous_phase=phase;_previous_com=com

func run_candidate(candidate:Dictionary,loader:RefCounted)->Dictionary:
	if _running or is_instance_valid(app):return {"completed":false,"reason":"EXERCISE_REUSE_NOT_SUPPORTED"}
	_running=true;trial_candidate=candidate.duplicate(true);override_loader=loader
	hz=int(candidate.requested_physics_hz)
	var result:Dictionary=await exercise_first_ascent()
	var actual:Dictionary={}
	for key in candidate.parameter_overrides:actual[key]=app.controller.tuning.get(key)
	for phase in _phases:
		_phases[phase]["observed_com_path_m"]=_phases[phase].com_path_m
		if _phases[phase].missing_com_samples>0 or _phases[phase].com_samples<2:_phases[phase].com_path_m=null
	var completed:bool=failures==0 and not _aborted and app.hybrid_mantle.completed and app.hybrid_mantle._native_ground() and app.hybrid_mantle.walk_distance>=.30 and not app.controller.assisted_motion_owned
	result.merge({"completed":completed,"reason":"ABORTED" if _aborted else "COMPLETE" if completed else "EXISTING_ROUTE_GOAL_FAILED","startup_profile_preserved":_startup_ok,"actual_parameters":actual,"phase_summary":_phases.duplicate(true),"driver_policy":"unchanged first_ascent_exercise.gd closed-loop physical reach windows; source hash in trial manifest","phase_scope":"Dynamic and assisted paths use actual Jolt direct-state COM, not the observer cache (which may pause during hybrid ownership). Missing samples are counted, never bridged; no whole-system energy claim. Kinematic crossing is not physical climbing; phase work is not estimated by this wrapper."},true)
	_running=false
	return result
