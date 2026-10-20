extends Node
## Fixture/attempt adapter. Setup is explicit; evaluation never drives the body.
const GEOMETRY_PATH:="res://features/locomotion_test_suite/resources/mastery_course_r1.json"
var app:Node
var geometry:Dictionary={}
var segment_index:=-1
var mirrored:=false
var fixture:Node3D
var previous:Dictionary={}
var attempt:Dictionary={}
var history:Array[Dictionary]=[]
var serial:=0
var _last_contacts:Dictionary={}
var _goal_stable:=0.0
var _source_observed:=false
var _source_shoulders:Dictionary={}
var _goal_signature:=""

class MasteryFixture extends "res://features/grip_up/scripts/climb_test_level.gd":
	var definition:Dictionary={}
	var mirrored:=false
	var transfer_points:Array[Vector3]=[]
	var surfaces:Dictionary={}
	func vec(value:Array)->Vector3:
		return Vector3(float(value[0])*(-1 if mirrored else 1),float(value[1]),float(value[2]))
	func _ready()->void:
		title=definition.title
		objective=definition.objective+ (" Mirrored: move left." if mirrored else "")
		spawn=vec(definition.spawn)
		for item:Dictionary in definition.primitives:
			var body:=box(item.key,vec(item.at),Vector3(item.size[0],item.size[1],item.size[2]),Color(item.color),item.grippable)
			body.set_meta("mastery_surface",item.key)
			surfaces[item.key]=body
			if item.grippable:holds.append(body)
			if item.get("foot",false):footholds.append(body)
		for point:Array in definition.contacts:transfer_points.append(vec(point))
		finish_point=transfer_points[-1]
		label3("BROAD GOAL / CHOOSE YOUR CONTACTS",vec(definition.label),cyan,22)
		if definition.goal.has("bounds_at"):
			var bounds:=region(definition.goal)
			var mesh:=MeshInstance3D.new()
			var quad:=QuadMesh.new()
			quad.size=Vector2(bounds.size.x,bounds.size.y)
			mesh.mesh=quad
			mesh.position=bounds.get_center()+Vector3(0,0,.035)
			var mat:=material(Color(cyan,.25))
			mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.material_override=mat
			add_child(mesh)
	func region(goal:Dictionary)->AABB:
		var at:=Vector3(goal.bounds_at[0],goal.bounds_at[1],goal.bounds_at[2])
		var size:=Vector3(goal.bounds_size[0],goal.bounds_size[1],goal.bounds_size[2])
		if mirrored:at.x=-at.x-size.x
		return AABB(at,size)

func _ready()->void:
	set_physics_process(false)

func apply_segment(target:Node,index:int,mirror:bool=false)->Dictionary:
	if not attempt.is_empty() and attempt.get("active",false):
		return {"ok":false,"reason":"ATTEMPT_ACTIVE_RESET_MUST_END_MEASUREMENT"}
	if index<0 or index>2:return {"ok":false,"reason":"UNKNOWN_SEGMENT"}
	if geometry.is_empty():geometry=JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY_PATH))
	app=target
	if previous.is_empty():
		previous={"level":app.level_id,"profile":app.input_profile,"feet":app.physical_feet_enabled,"movement":app.movement_allocation,"foot_variant":app.intent_aware_feet_enabled,"distant":app.allow_out_of_reach_grip_targets,"launch":app.experimental_launch_enabled,"posture_variant":app.posture_variant,"posture_policy":app.posture_policy,"transfer_assist":app.transfer_assist_enabled,"transfer_diagnostics":app.transfer_diagnostics_enabled,"swing_feedback":app.swing_phase_feedback_enabled,"locomotion_diagnostics":app.locomotion_diagnostics_enabled}
	segment_index=index
	mirrored=mirror
	var definition:Dictionary=geometry.segments[index]
	# This is a deliberate reset/setup action, outside any observed attempt.
	for action in ["contract","extend","bias_left","bias_right","grip_left","grip_right","launch"]:
		if InputMap.has_action(action):Input.action_release(action)
	app._open_intent_arena(int(definition.base_arena),true)
	app._set_movement_allocation(0)
	app._set_intent_aware_feet(false)
	app._set_distant_targeting(true)
	var old_level:Node=app.level
	app.world.remove_child(old_level)
	old_level.queue_free()
	fixture=MasteryFixture.new()
	fixture.definition=definition
	fixture.mirrored=mirror
	app.world.add_child(fixture)
	app.level=fixture
	# Mirrored start placement belongs to reset, never to evaluation/measurement.
	app.torso.global_position=fixture.spawn
	app.torso.linear_velocity=Vector3.ZERO
	app.torso.angular_velocity=Vector3.ZERO
	app.torso.reset_physics_interpolation()
	app.won=true # The separate course evaluator owns outcomes, not legacy popup.
	app.rating_panel.hide()
	app._update_objective()
	attempt={}
	return describe()

func describe()->Dictionary:
	if not is_instance_valid(fixture):return {"ok":false,"reason":"NO_FIXTURE"}
	var definition:Dictionary=geometry.segments[segment_index]
	return {"ok":true,"id":definition.id,"revision":geometry.revision,"geometry_resource":GEOMETRY_PATH,"geometry_sha256":FileAccess.get_sha256(GEOMETRY_PATH),"mirrored":mirrored,"spawn":fixture.spawn,"goal":definition.goal.duplicate(true),"regions":[fixture.region(definition.goal)] if definition.goal.has("bounds_at") else [],"representative_contacts":fixture.transfer_points.duplicate(),"supports":fixture.surfaces.duplicate(),"measurement_ready":false,"checkpoint":"SEGMENT_FLOOR_START_ONLY","variant":_variant()}

func _variant()->Dictionary:
	return {"profile":app.input_profile,"allocation":"A%d"%app.movement_allocation,"feet":"B0" if not app.physical_feet_enabled else "B2" if app.intent_aware_feet_enabled else "B1","physical_feet":app.physical_feet_enabled,"swing_feedback":app.swing_phase_feedback_enabled}

func begin_attempt(mode:String="scored",source:String="human")->Dictionary:
	if not is_instance_valid(fixture):return {"ok":false,"reason":"NO_FIXTURE"}
	if attempt.get("active",false):return {"ok":false,"reason":"ATTEMPT_ALREADY_ACTIVE"}
	if mode not in ["scored","practice","familiarization","retention"]:return {"ok":false,"reason":"UNKNOWN_MODE"}
	if source not in ["human","scripted","developer_exploratory"]:return {"ok":false,"reason":"UNKNOWN_SOURCE"}
	serial+=1
	_goal_stable=0
	_source_observed=false
	_source_shoulders.clear()
	_goal_signature=""
	_last_contacts.clear()
	attempt={"ok":true,"attempt":serial,"scenario":geometry.segments[segment_index].id,"scenario_revision":geometry.revision,"mirrored":mirrored,"mode":mode,"scored":mode in ["scored","retention"],"source":source,"active":true,"completed":false,"reason":"IN_PROGRESS","elapsed_s":0.0,"transfers":0,"source_observed":false,"catch_started_outside_reach":false,"static_distance_m":null,"retained_s":0.0,"start_body":app.torso.global_position,"start_tick":Engine.get_physics_frames(),"checkpoint":"SEGMENT_FLOOR_START_ONLY"}
	attempt.variant=_variant()
	set_physics_process(true)
	return attempt.duplicate(true)

func _physics_process(delta:float)->void:
	if not attempt.get("active",false):return
	if not is_instance_valid(app) or not is_instance_valid(fixture) or app.level!=fixture:
		end_attempt("FIXTURE_CHANGED")
		return
	attempt.elapsed_s+=delta
	var definition:Dictionary=geometry.segments[segment_index]
	var goal:Dictionary=definition.goal
	var valid_contacts:Array=[]
	for id in 2:
		var hand:Dictionary=app.controller.hands[id]
		if hand.state!="ATTACHED" or hand.anchor==null or not hand.anchor.is_valid():continue
		var support:PhysicsBody3D=hand.anchor.support_body()
		var point:Vector3=hand.anchor.world_point()
		var key:String=support.get_meta("mastery_surface","")
		valid_contacts.append({"id":id,"surface":key,"point":point})
		if _last_contacts.has(id) and (_last_contacts[id].point.distance_to(point)>.03 or _last_contacts[id].surface!=key):attempt.transfers+=1
		_last_contacts[id]={"point":point,"surface":key}
	if goal.kind=="catch" and not _source_observed and not app.ground_motor.grounded:
		for contact:Dictionary in valid_contacts:
			if contact.surface!=goal.source_surface:continue
			_source_observed=true
			for hand_id in 2:_source_shoulders[hand_id]=app.controller.get_shoulder_world(hand_id)
			var target_point:Vector3=fixture.transfer_points[-1]
			var distance:float=app.controller.get_shoulder_world(1-int(contact.id)).distance_to(target_point)
			attempt.static_distance_m=distance
			attempt.source_observed=true
			attempt.source_was_ungrounded=true
			attempt.catch_started_outside_reach=distance>app.controller.get_max_reach()+float(goal.static_reach_margin_m)
	var at_goal:=false
	var signature:=""
	for contact:Dictionary in valid_contacts:
		if contact.surface!=goal.surface:continue
		if goal.kind=="catch":
			if _source_observed:
				var actual_start_distance:float=Vector3(_source_shoulders[contact.id]).distance_to(contact.point)
				attempt.actual_catch_start_distance_m=actual_start_distance
				attempt.catch_started_outside_reach=actual_start_distance>app.controller.get_max_reach()+float(goal.static_reach_margin_m)
				at_goal=attempt.catch_started_outside_reach and not app.ground_motor.grounded
		else:
			var bounds:AABB=fixture.region(goal)
			at_goal=bounds.has_point(contact.point) and app.torso.global_position.y>=float(goal.min_body_y) and attempt.transfers>=int(goal.minimum_transfers)
			if goal.kind=="traverse":at_goal=at_goal and app.torso.global_position.x*(-1 if mirrored else 1)>=float(goal.min_signed_body_x)
		if at_goal:
			signature="%s_%s"%[contact.id,app.controller.hands[contact.id].anchor.get_instance_id()]
			break
	_goal_stable=(_goal_stable+delta if _goal_signature==signature else delta) if at_goal else 0.0
	_goal_signature=signature
	attempt.retained_s=_goal_stable
	attempt.actual_body=app.torso.global_position
	attempt.contacts=valid_contacts
	if app.torso.global_position.y<-.5:end_attempt("FALL")
	elif _goal_stable+0.000001>=float(goal.retention_s):end_attempt("COMPLETE")

func evaluate()->Dictionary:
	return attempt.duplicate(true)

func end_attempt(reason:String="CANCELLED")->Dictionary:
	if not attempt.is_empty() and attempt.get("active",false):
		attempt.active=false
		attempt.reason=reason
		attempt.completed=reason=="COMPLETE"
		attempt.end_tick=Engine.get_physics_frames()
		history.append(attempt.duplicate(true))
		if history.size()>128:history.pop_front()
	set_physics_process(false)
	return evaluate()

func cancel_attempt()->Dictionary:
	return end_attempt("CANCELLED")

func restore(target:Node=null)->void:
	end_attempt("RESTORE")
	var current:Node=target if target!=null else app
	if is_instance_valid(current) and not previous.is_empty():
		current._set_input_profile(previous.profile)
		current._set_physical_feet(previous.feet)
		current._set_movement_allocation(previous.movement)
		current._set_intent_aware_feet(previous.foot_variant)
		current._set_distant_targeting(previous.distant)
		current._set_experimental_launch(previous.launch)
		current._set_posture_variant(previous.posture_variant)
		current._set_posture_policy(previous.posture_policy)
		current.transfer_assist_enabled=previous.transfer_assist
		current.transfer_diagnostics_enabled=previous.transfer_diagnostics
		current.transfer_diagnostics_toggle.set_pressed_no_signal(previous.transfer_diagnostics)
		current.swing_phase_feedback_enabled=previous.swing_feedback
		current._set_locomotion_diagnostics(previous.locomotion_diagnostics)
		current.load_test(previous.level)
	fixture=null
	previous={}
