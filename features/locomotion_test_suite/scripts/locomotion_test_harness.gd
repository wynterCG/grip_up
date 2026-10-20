extends Node
## Explicit scenario setup is separate from the read-only recording path.
const Recorder=preload("res://features/locomotion_test_suite/scripts/session_recorder.gd")
const Course=preload("res://features/locomotion_test_suite/scripts/mastery_course.gd")
const TASKS="res://features/locomotion_test_suite/resources/tasks.json"
const IDENTITY="res://features/locomotion_test_suite/resources/build_identity.json"
var app:Node
var definitions:Dictionary={}
var task:Dictionary={}
var variant:Dictionary={}
var recorder=Recorder.new()
var course=Course.new()
var selected_case:="canonical"
var source:="developer_exploratory"
var mode:="practice"
var waiting:=false
var _watched:Node
var _started_wait:=0.0
var _last_time:=0.0
var _previous_flags:Dictionary={}
var _signature:Dictionary={}
var _retention:Dictionary={}
var _attempt_ids:Dictionary={}
var _outside:Dictionary={}
var _observed:Dictionary={}
var _last_hands:=0
var _goal_hold:=0.0
var _mouse_distance:=0.0
var _orbit_gestures:=0
var _orbit_seconds:=0.0
var _render_count:=0
var _render_seconds:=0.0
var _physics_ms_sum:=0.0
var _physics_count:=0
var _memory_start:=0
var _memory_peak:=0
var _material_error_peak:=0.0
var _material_known:=false
var _goal_time:Variant=null
var _target_known_s:=0.0
var _target_occluded_s:=0.0
var _target_offscreen_s:=0.0
var _visibility:Dictionary={}
var _visibility_time:=-1.0
var _selected_index:=0
var _order:=0
var task_choice:OptionButton
var variant_choice:OptionButton
var case_choice:OptionButton
var mode_choice:OptionButton
var source_choice:OptionButton
var participant:LineEdit
var details:Label
var status:Label
var banner:Label
var mirror:CheckButton
var inspection:CheckButton
var ratings:Array[OptionButton]=[]
var note:LineEdit
var fatigue:LineEdit
var last_summary:Dictionary={}

func configure(target:Node,parent:Control)->void:
	app=target
	definitions=JSON.parse_string(FileAccess.get_file_as_string(TASKS))
	add_child(course)
	var title:=Label.new();title.text="v1.2 / Locomotion tasks and mastery";parent.add_child(title)
	task_choice=OptionButton.new()
	for item in definitions.tasks:task_choice.add_item(item.id+" / "+item.name)
	for label in ["M-A / Controlled ascent","M-B / Asymmetric traverse","M-C / Swing catch"]:task_choice.add_item(label)
	parent.add_child(task_choice)
	task_choice.item_selected.connect(func(index:int):_selected_index=index;_refresh_cases())
	variant_choice=OptionButton.new()
	for item in definitions.variants:variant_choice.add_item(item.label)
	parent.add_child(variant_choice)
	case_choice=OptionButton.new();parent.add_child(case_choice)
	mirror=CheckButton.new();mirror.text="Mirror mastery geometry";parent.add_child(mirror)
	mode_choice=OptionButton.new()
	for label in ["Practice / untimed learning","Familiarization / guided","Scored attempt","Later retention attempt"]:mode_choice.add_item(label)
	parent.add_child(mode_choice)
	source_choice=OptionButton.new()
	for label in ["Developer exploratory / real input","Human participant / real input"]:source_choice.add_item(label)
	parent.add_child(source_choice)
	participant=LineEdit.new();participant.text="anonymous_01";participant.placeholder_text="Pseudonym only; no name or email";participant.max_length=32;parent.add_child(participant)
	inspection=CheckButton.new();inspection.text="Inspection HUD / optional, off during normal trials";parent.add_child(inspection)
	_button(parent,"Prepare / retry selected task",prepare_selected)
	_button(parent,"Arm recording and play",arm)
	_button(parent,"Finish current attempt",func():finish(false,"OPERATOR_STOP"))
	_button(parent,"Next mastery segment",func():finish(false,"NEXT_SEGMENT");_selected_index=10+((_selected_index-10+1)%3) if _selected_index>=10 else 10;task_choice.select(_selected_index);_refresh_cases();prepare_selected())
	details=Label.new();details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.custom_minimum_size.y=90;parent.add_child(details)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(status)
	var heading:=Label.new();heading.text="After a real-input block: 1 difficult / 5 reliable; leave unanswered if not rated.";heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(heading)
	for label in ["Control response","Predictability","Grip aiming","Swing agency","Comfort","Skill expression","Replay desire"]:
		var row:=HBoxContainer.new();parent.add_child(row)
		var text:=Label.new();text.text=label;text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text)
		var choice:=OptionButton.new();choice.add_item("Not answered")
		for value in range(1,6):choice.add_item(str(value))
		row.add_child(choice);ratings.append(choice)
	note=LineEdit.new();note.placeholder_text="What I intended / what happened / why (optional)";note.max_length=512;parent.add_child(note)
	fatigue=LineEdit.new();fatigue.placeholder_text="Fatigue or break note (optional)";fatigue.max_length=128;parent.add_child(fatigue)
	_button(parent,"Save self-reported notes on last real-input attempt",save_assessment)
	banner=Label.new();banner.position=Vector2(40,260);banner.mouse_filter=Control.MOUSE_FILTER_IGNORE;banner.add_theme_font_size_override("font_size",16);app.hud.add_child(banner)
	_refresh_cases()
	status.text="Recording OFF. Prepare, arm, then acquire the required real supports. Esc returns to these controls."

func _button(parent:Control,label:String,callback:Callable)->void:
	var button:=Button.new();button.text=label;button.pressed.connect(callback);parent.add_child(button)

func _refresh_cases()->void:
	case_choice.clear()
	var cases:Array=definitions.tasks[_selected_index].cases if _selected_index<10 else ["canonical"]
	for label in cases:case_choice.add_item(label)
	if is_instance_valid(details):details.text=definitions.tasks[_selected_index].instructions if _selected_index<10 else "Three checkpoint segments, in order. One familiarization, one practice, five scored attempts per segment, then a later re-test. Alternative contacts are allowed."

func prepare_selected()->void:
	prepare(_selected_index,variant_choice.selected,case_choice.get_item_text(case_choice.selected),mirror.button_pressed)

func prepare(index:int,variant_index:int=0,condition:String="canonical",mirrored:bool=false)->Dictionary:
	finish(false,"TASK_CHANGED")
	_selected_index=clampi(index,0,12)
	task_choice.select(_selected_index)
	variant_choice.select(clampi(variant_index,0,4))
	_refresh_cases()
	for item in case_choice.item_count:
		if case_choice.get_item_text(item)==condition:case_choice.select(item)
	mirror.set_pressed_no_signal(mirrored)
	selected_case=condition
	variant=definitions.variants[clampi(variant_index,0,4)].duplicate(true)
	if index>=10:
		var setup:Dictionary=course.apply_segment(app,index-10,mirrored)
		if not setup.get("ok",false):return setup
		task={"id":setup.id,"name":setup.id,"revision":setup.revision,"ready_hands":0,"direction":[0,1,0],"goal":{"kind":"mastery"},"cases":["canonical"],"instructions":"Choose contacts freely. Segment checkpoint reset occurs only before an attempt."}
	else:
		course.cancel_attempt()
		task=definitions.tasks[index].duplicate(true)
		if task.id=="T10":app.fixed_beam=condition=="fixed"
		if task.id=="T09":app._open_first_ascent()
		elif task.id=="T08" and condition=="hybrid_walk":app._open_hybrid_mantle(0,true)
		else:app._open_intent_arena(int(task.arena),bool(variant.physical_feet))
	app._set_movement_allocation(int(variant.allocation))
	app._set_intent_aware_feet(bool(variant.intent_feet))
	app._set_physical_feet(bool(variant.physical_feet))
	app.swing_phase_feedback_enabled=bool(variant.feedback)
	for control in app.settings.find_children("*","CheckButton",true,false):
		if control.text.begins_with("C1 /"):control.set_pressed_no_signal(app.swing_phase_feedback_enabled)
	app._apply_independent_settings()
	app.debug_visible=false
	app.capture_trace.enabled=false;app.capture_trace.close()
	_connect_observation()
	status.text=task.id+" / prepared. Arm capture before gripping; setup is outside measurement."
	return {"ok":true,"task":task.duplicate(true),"variant":variant.duplicate(true)}

func _connect_observation()->void:
	if is_instance_valid(_watched) and _watched.sample_ready.is_connected(_sample):_watched.sample_ready.disconnect(_sample)
	if is_instance_valid(_watched) and _watched.transfer_event.is_connected(_grip_event):_watched.transfer_event.disconnect(_grip_event)
	_watched=app.controller
	_watched.sample_ready.connect(_sample)
	_watched.transfer_event.connect(_grip_event)

func _runtime_signature()->Dictionary:
	return {"profile":app.input_profile,"allocation":app.movement_allocation,"feet":app.physical_feet_enabled,"intent_feet":app.intent_aware_feet_enabled,"feedback":app.swing_phase_feedback_enabled,"physics_hz":Engine.physics_ticks_per_second,"level_instance":app.level.get_instance_id(),"distant":app.allow_out_of_reach_grip_targets,"hybrid":app.hybrid_mantle_v09_enabled,"vault":app.contextual_vault_v10_enabled,"posture":app.posture_variant,"policy":app.posture_policy,"posture_assist":app.posture_assist_enabled,"posture_tilt":app.posture_tilt_assist_enabled,"swing":app.supported_wasd_swing_enabled,"transfer_assist":app.transfer_assist_enabled,"prediction":app.reach_prediction_enabled,"catch_buffer":app.catch_buffer_enabled,"launch":app.experimental_launch_enabled,"fixed_beam":app.fixed_beam,"tuning":_runtime_tuning()}

func _runtime_tuning()->Dictionary:
	var tuning:Resource=app.controller.tuning
	return {"mass_kg":app.torso.mass,"reach_m":app.controller.get_max_reach(),"hand_budget_n":tuning.total_pull_force_budget,"foot_budget_n":app.controller.feet_solver.tuning.total_force_budget,"per_foot_budget_n":app.controller.feet_solver.tuning.max_force_per_foot,"assist_nm":tuning.max_attitude_torque,"resultant_nm":tuning.max_total_torque,"target_rate_m_s":tuning.traversal_target_max_rate,"target_accel_m_s2":tuning.traversal_target_max_acceleration,"gravity_scale":app.torso.gravity_scale,"linear_damp":app.torso.linear_damp,"angular_damp":app.torso.angular_damp}

func arm(kind:String="",attempt_mode:String="")->bool:
	if waiting or recorder.active:return false
	if task.is_empty():prepare_selected()
	source=kind if not kind.is_empty() else ("human" if source_choice.selected==1 else "developer_exploratory")
	mode=attempt_mode if not attempt_mode.is_empty() else ["practice","familiarization","scored","retention"][mode_choice.selected]
	if source not in ["human","scripted","developer_exploratory"] or mode not in ["practice","familiarization","scored","retention"]:return false
	if source=="human" and variant.id=="V2":
		status.text="V2 has demonstrated regressions. Use developer exploratory for this diagnostic comparison; human sessions use the other variants."
		return false
	if RegEx.create_from_string("^[A-Za-z0-9_-]{1,32}$").search(participant.text)==null:
		status.text="Use a short pseudonym: letters, numbers, underscore or dash. No personal data."
		return false
	var identity:Variant=JSON.parse_string(FileAccess.get_file_as_string(IDENTITY)) if FileAccess.file_exists(IDENTITY) else null
	if not identity is Dictionary:
		status.text="Build identity missing: run tools/prepare_locomotion_tests.py before recording."
		return false
	_previous_flags={"observer":app.locomotion_diagnostics_enabled,"journal":app.transfer_diagnostics_enabled}
	app._set_locomotion_diagnostics(true)
	app.transfer_diagnostics_enabled=true;app._apply_independent_settings()
	_signature=_runtime_signature()
	_connect_observation()
	waiting=true;_started_wait=app.controller.simulation_time;_last_time=_started_wait
	_retention.clear();_attempt_ids.clear();_outside.clear();_observed.clear();_goal_hold=0;_last_hands=0
	_mouse_distance=0;_orbit_gestures=0;_orbit_seconds=0;_render_count=0;_render_seconds=0;_physics_count=0;_physics_ms_sum=0
	_memory_start=OS.get_static_memory_usage();_memory_peak=_memory_start
	_material_error_peak=0;_material_known=false
	_goal_time=null
	_target_known_s=0;_target_occluded_s=0;_target_offscreen_s=0;_visibility.clear();_visibility_time=-1
	app.settings.hide()
	status.text="Waiting for actual start conditions. Measurement has not started."
	return true

func _ready_for(row:Dictionary)->bool:
	var count:int=app.controller._attached_ids().size()
	if task.get("ready_hands",0)>0 and count!=int(task.ready_hands):return false
	if task.id in ["T04","T06","T07"] and app.ground_motor.grounded:return false
	if task.id=="T06" and selected_case=="brake" and float(row.get("pendulum_angle_rad",0.0) if row.get("pendulum_angle_rad")!=null else 0.0)<.2:return false
	if task.id=="T02" and count==2:
		var a:Vector3=app.controller.hands[0].anchor_world
		var b:Vector3=app.controller.hands[1].anchor_world
		if maxf(absf(a.y-b.y),absf(a.z-b.z))<.05:return false
	if task.id=="T10" and selected_case in ["fixed","dynamic","moving_material"]:
		if not is_instance_valid(app.level.beam):return false
		if not app.controller._attached_ids().any(func(id):return app.controller.hands[id].anchor.support_body()==app.level.beam):return false
	if task.id in ["T01","T02","T03","T05"] and Vector3(row.movement_intent_world).length()<.001:return false
	return row.get("com_position") is Vector3

func _begin(row:Dictionary)->bool:
	var direction:Vector3=row.movement_intent_world
	if direction.length()<.001:
		var values:Array=task.direction
		direction=Vector3(values[0],values[1],values[2])
		var frame:Dictionary=row.get("frame",{})
		if frame.get("valid",false):direction=Vector3(frame.right)*direction.x+Vector3(frame.up)*direction.y+Vector3(frame.normal)*direction.z
	var bindings:Dictionary={}
	for action in app.router.DEFAULTS:bindings[action]=app.router.prompt(action)
	_order+=1
	var info:Dictionary={"source":source,"scenario":task.id,"scenario_revision":task.revision,"task_set_revision":definitions.revision,"task_hash":FileAccess.get_sha256(TASKS),"variant":variant.duplicate(true),"physics_hz":Engine.physics_ticks_per_second,"build_identity":JSON.parse_string(FileAccess.get_file_as_string(IDENTITY)),"engine":Engine.get_version_info(),"backend":ProjectSettings.get_setting("physics/3d/physics_engine"),"bindings":bindings,"tester_id":participant.text.validate_filename(),"mode":mode,"scored":mode in ["scored","retention"],"attempt_order":_order,"condition":selected_case,"mirrored_geometry":course.mirrored if _selected_index>=10 else false,"manual_start":source!="scripted","flags":{"hybrid":app.hybrid_mantle_v09_enabled,"vault":app.contextual_vault_v10_enabled,"posture":app.posture_variant,"posture_policy":app.posture_policy,"distant":app.allow_out_of_reach_grip_targets},"initial_state":row.duplicate(true),"reference_frame":"accepted supported intent frozen at onset; configured support axis for no-input tasks"}
	var options:Dictionary=definitions.thresholds.duplicate(true)
	options.merge({"max_samples":512,"max_events":128,"response_velocity_m_s":definitions.thresholds.latency_velocity_m_s,"response_persistence_s":definitions.thresholds.latency_persistence_s})
	if task.goal.kind=="progress":options["target_progress_m"]=float(task.goal.distance_m)
	info["display"]={"window_size":app.get_window().size,"viewport_size":app.get_viewport().get_visible_rect().size,"camera_fov":app.camera.fov,"camera_yaw":app.camera.yaw,"camera_elevation":app.camera.elevation,"camera_distance":app.camera.distance,"mouse_sensitivity_source":"Unchanged climbing_camera.gd in build hash; physical mouse DPI not measured"}
	info["tuning"]=_runtime_tuning()
	info["ready_wait_s"]=float(row.time)-_started_wait
	info["condition_scope"]="Starting pose/contact choices in unchanged lab; actual contacts and normals must match before paired comparison. Only mastery mirror explicitly transforms the scene. Mechanical fixtures are separate revisioned studies."
	if not recorder.begin(info,row,direction.normalized(),options):return false
	_mouse_distance=0;_orbit_gestures=0;_orbit_seconds=0
	for choice in ratings:choice.select(0)
	note.text="";fatigue.text=""
	if _selected_index>=10:course.begin_attempt(mode,source)
	waiting=false;_last_time=float(row.time)
	return true

func _sample(delta:float)->void:
	if not waiting and not recorder.active:return
	if _watched!=app.controller or _runtime_signature()!=_signature:
		finish(false,"CONFIG_OR_SCENE_CHANGED");return
	var row:Dictionary=app.controller.locomotion_observer.data.duplicate(true)
	if row.is_empty():return
	if float(row.time)<_last_time:
		finish(false,"RESET");return
	_last_time=float(row.time)
	row["monotonic_usec"]=Time.get_ticks_usec()
	row["renderer_frame"]=Engine.get_process_frames()
	row["physics_frame"]=Engine.get_physics_frames()
	row["camera_basis"]=app.camera.global_basis
	row["camera_position"]=app.camera.global_position
	row["manual_orbit"]=app.orbiting
	row["pointer"]=app.pointer
	row["physics_process_ms"]=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
	row["render_process_ms"]=Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
	row["swing_partial_work_power_w"]=row.get("swing_power")
	if waiting:
		if _ready_for(row):
			if not _begin(row):finish(false,"RECORDER_FAILED")
		elif float(row.time)-_started_wait>float(definitions.thresholds.ready_timeout_s):finish(false,"NOT_READY")
		return
	for contact:Dictionary in row.get("contacts",[]):
		if row.get("com_position") is Vector3 and contact.get("point") is Vector3:
			contact["moment_about_com"]=Vector3(contact.point-Vector3(row.com_position)).cross(Vector3(contact.force))
		contact["current_intent_contribution_n"]=Vector3(contact.force).dot(Vector3(row.movement_intent_world).normalized())
	if task.id=="T09":
		var selected:Dictionary={}
		for id in 2:
			var pending:Dictionary=app.controller.pending_diagnostics(id)
			if pending.get("active",false) and pending.get("substate","")!="ATTACHED":selected=pending;break
		if selected.get("target_world") is Vector3:
			if float(row.time)-_visibility_time>=.05 or _visibility.get("selection_id")!=selected.get("target_selection_id"):
				var point:Vector3=selected.target_world
				var screen:Vector2=app.camera.unproject_position(point)
				var outside:bool=app.camera.is_position_behind(point) or not app.get_viewport().get_visible_rect().has_point(screen)
				var query:=PhysicsRayQueryParameters3D.create(app.camera.global_position,point,3,[app.torso.get_rid()])
				var hit:Dictionary=app.camera.get_world_3d().direct_space_state.intersect_ray(query)
				var occluded:bool=not hit.is_empty() and app.camera.global_position.distance_to(hit.position)<app.camera.global_position.distance_to(point)-.03
				_visibility={"known":true,"selection_id":selected.get("target_selection_id"),"offscreen":outside,"occluded":occluded,"sample_hz":20}
				_visibility_time=float(row.time)
			_target_known_s+=delta
			if _visibility.get("occluded",false):_target_occluded_s+=delta
			if _visibility.get("offscreen",false):_target_offscreen_s+=delta
			row["selected_target_visibility"]=_visibility.duplicate(true)
	if not recorder.push(row):finish(false,"INVALID_SAMPLE");return
	_physics_ms_sum+=float(row.physics_process_ms);_physics_count+=1
	_memory_peak=maxi(_memory_peak,OS.get_static_memory_usage())
	for contact:Dictionary in row.get("contacts",[]):
		if contact.kind=="hand" and contact.get("material_error_m")!=null:
			_material_known=true
			_material_error_peak=maxf(_material_error_peak,float(contact.material_error_m))
	var hands:int=app.controller._attached_ids().size()
	_observed["ground"]=_observed.get("ground",false) or not row.native_sole_support_ids.is_empty()
	_observed["reaching_ground"]=_observed.get("reaching_ground",false) or (row.grounded and row.hands.has("REACHING"))
	_observed["air_hands"]=_observed.get("air_hands",false) or (not row.grounded and hands>0)
	_observed["two_to_one"]=_observed.get("two_to_one",false) or (_last_hands==2 and hands==1)
	_observed["hands_feet"]=_observed.get("hands_feet",false) or (hands>0 and int(row.foot_load.loaded_count)>0)
	_last_hands=hands
	for id in 2:
		if not _retention.has(id):continue
		var contact:Dictionary=_retention[id]
		var hand:Dictionary=app.controller.hands[id]
		if hand.state!="ATTACHED" or hand.anchor==null or hand.anchor.get_instance_id()!=contact.anchor:
			_retention.erase(id);continue
		if not contact.reported and float(row.time)-float(contact.time)>=float(definitions.thresholds.retention_s):
			contact.reported=true
			recorder.event({"type":"retained","time":row.time,"tick":row.tick,"hand_id":id,"attempt_id":contact.attempt,"initially_outside_reach":_outside.get(str(contact.attempt),false)})
	if int(row.owner_bits)&16 and int(row.owner_bits)!=16:finish(false,"AUTHORITY_CONFLICT");return
	var progress:Dictionary=recorder.metrics.finish()
	var goal:Dictionary=task.goal
	var completed:=false
	if goal.kind=="progress":completed=progress.movement.useful_progress_m!=null and float(progress.movement.useful_progress_m)>=float(goal.distance_m) and hands>0
	elif goal.kind=="new_retained_grip":
		for contact:Dictionary in _retention.values():
			if contact.reported and (not goal.get("require_outside_static_reach",false) or _outside.get(str(contact.attempt),false)):completed=true
	elif goal.kind=="retained_transfers":completed=int(progress.capture.retained)>=int(goal.count)
	elif goal.kind=="swing_band" and row.get("pendulum_angle_rad")!=null:
		var angle:float=row.pendulum_angle_rad
		if selected_case=="brake":
			var slow:bool=Vector3(row.pendulum_angular_velocity).length()<.15 and angle<float(goal.brake_angle_rad)
			_goal_hold=_goal_hold+delta if slow else 0.0
			completed=_goal_hold>=float(goal.hold_s)
		else:completed=angle>=float(goal.build_angle_rad) and hands==1
	elif goal.kind=="transition_sequence":
		match selected_case:
			"walk_reach":completed=_observed.get("reaching_ground",false)
			"attach_load":completed=_observed.get("ground",false) and hands>0 and row.hand_forces.any(func(value):return Vector3(value).length()>1)
			"two_to_one":completed=_observed.get("two_to_one",false)
			"hands_feet":completed=_observed.get("hands_feet",false)
			"hang_ground":completed=_observed.get("air_hands",false) and not row.native_sole_support_ids.is_empty() and hands==0
			"hybrid_walk":completed=is_instance_valid(app.hybrid_mantle) and app.hybrid_mantle.completed and app.hybrid_mantle._native_ground() and app.hybrid_mantle.walk_distance>=float(goal.native_walk_m)
	elif goal.kind=="material_tracking":completed=progress.duration_s>=float(goal.duration_s) and hands>0 and _material_known and _material_error_peak<=float(goal.anchor_error_m)
	elif goal.kind=="mastery":completed=course.evaluate().get("completed",false)
	if completed and _goal_time==null:
		_goal_time=float(row.time)
		recorder.event({"type":"goal_attained","time":row.time,"tick":row.tick,"reason":"Recording continues for the configured transition post-roll"})
	if app.torso.global_position.y<-.5:finish(false,"FALL")
	elif _goal_time!=null and float(row.time)-float(_goal_time)>=float(definitions.thresholds.get("postroll_s",.5)):finish(true,"COMPLETE")
	elif progress.duration_s>=float(definitions.thresholds.max_duration_s):finish(false,"TIME_LIMIT")

func _grip_event(event:Dictionary)->void:
	if not recorder.active:return
	var code:String=event.get("code","")
	var id:int=event.get("hand",-1)
	var attempt_id:String="%s:%s"%[str(event.get("session",0)),str(event.get("attempt_id",0))]
	var kind:String={"ATTEMPT_STARTED":"attempt","SUCCESS":"contact","GRIP_SLIP":"slip","RELEASED":"release","CANCELLED":"release"}.get(code,"diagnostic")
	var row:Dictionary=event.duplicate(true)
	row.merge({"type":kind,"tick":int(event.get("step",0)),"hand_id":id,"attempt_id":attempt_id},true)
	recorder.event(row)
	if code=="ATTEMPT_STARTED":
		_attempt_ids[id]=attempt_id
		_outside[attempt_id]=float(event.get("input_distance",0.0))>float(event.get("max_reach",app.controller.get_max_reach()))
	if code=="SUCCESS" and id in [0,1] and app.controller.hands[id].anchor!=null:
		_retention[id]={"time":event.time,"attempt":attempt_id,"anchor":app.controller.hands[id].anchor.get_instance_id(),"reported":false}

func _input(event:InputEvent)->void:
	if not waiting and not recorder.active:return
	if event.is_action_pressed("restart"):
		finish(false,"RESET")
		if _selected_index>=10:
			prepare_selected.call_deferred();get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and not app.settings.visible:
		_mouse_distance+=event.relative.length()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_MIDDLE and event.pressed and not app.settings.visible:_orbit_gestures+=1

func _process(delta:float)->void:
	if waiting or recorder.active:
		if not is_instance_valid(_watched) or _watched!=app.controller:finish(false,"RESET_OR_SCENE_CHANGED");return
		_render_count+=1;_render_seconds+=delta
		if app.orbiting:_orbit_seconds+=delta
		banner.text=task.id+" / "+("waiting for real start" if waiting else "recording "+mode)+" / Esc > tests > Finish"
		if inspection.button_pressed and recorder.active:
			var data:Dictionary=recorder.metrics.finish()
			banner.text+="\nCOM progress %s m / path %.3f m / owners %s"%[str(data.movement.useful_progress_m),data.movement.path_length_m,str(app.controller.locomotion_observer.data.get("owner_bits",0))]
	else:banner.text=""

func finish(completed:bool,reason:String)->Dictionary:
	if not waiting and not recorder.active:return last_summary
	var had_recording:bool=recorder.active
	waiting=false
	if _selected_index>=10:course.end_attempt("COMPLETE" if completed else reason)
	if recorder.active:
		var performance:Dictionary={"render_frames":_render_count,"render_elapsed_s":_render_seconds,"mean_physics_process_ms":null,"static_memory_start_bytes":_memory_start,"static_memory_peak_bytes":_memory_peak,"static_memory_end_bytes":OS.get_static_memory_usage()}
		if _physics_count>0:performance.mean_physics_process_ms=_physics_ms_sum/_physics_count
		var mastery:Variant=null
		if _selected_index>=10:mastery=course.evaluate()
		var material_error:Variant=null
		if _material_known:material_error=_material_error_peak
		var camera_data:Dictionary={"mouse_travel_viewport_px":_mouse_distance,"manual_orbit_gestures":_orbit_gestures,"manual_orbit_s":_orbit_seconds,"occluded_target_time_s":null,"offscreen_target_time_s":null,"known_pending_target_s":_target_known_s,"visibility_sample_hz":20,"occlusion_reason":"No unique selected pending material target observed"}
		if _target_known_s>0:
			camera_data.occluded_target_time_s=_target_occluded_s;camera_data.offscreen_target_time_s=_target_offscreen_s
			camera_data.occlusion_reason="Selected pending target only; 20Hz read-only rays, 3cm endpoint tolerance; no inferred next hold"
		last_summary=recorder.finish(completed,reason,{"camera":camera_data,"performance":performance,"transition_windows":app.controller.locomotion_observer.transition_windows() if is_instance_valid(_watched) and _watched==app.controller else {},"mastery":mastery,"observed_transitions":_observed.duplicate(true),"material_tracking":{"known":_material_known,"peak_force_point_vs_material_error_m":material_error}})
	if is_instance_valid(app) and is_instance_valid(app.controller):
		app._set_locomotion_diagnostics(bool(_previous_flags.get("observer",false)))
		app.transfer_diagnostics_enabled=bool(_previous_flags.get("journal",false));app._apply_independent_settings()
	status.text=reason+" / "+(ProjectSettings.globalize_path(recorder.directory) if had_recording else "no measured attempt; start conditions missing")
	return last_summary

func save_assessment()->void:
	if last_summary.is_empty() or last_summary.source=="scripted":status.text="No real-input attempt to rate.";return
	var values:Dictionary={}
	var names:Array=["control_response","predictability","grip_aiming","swing_agency","comfort","skill_expression","replay_desire"]
	for index in ratings.size():
		values[names[index]]=null
		if ratings[index].selected>0:values[names[index]]=ratings[index].selected
	last_summary.assessment={"confidence":"self_reported_real_input","human_ratings":values,"notes":note.text,"fatigue":fatigue.text}
	FileAccess.open(recorder.directory+"/summary.json",FileAccess.WRITE).store_string(JSON.stringify(Recorder.serializable(last_summary),"\t"))
	status.text="Self-reported notes saved locally; missing ratings remain null."
