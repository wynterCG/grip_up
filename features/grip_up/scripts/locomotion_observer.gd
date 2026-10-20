extends RefCounted
## Read-only per-tick observation. No actuator targets or physical state writes.
const WINDOW_SECONDS := 0.5
const MAX_WINDOWS := 16
var history: Array[Dictionary] = []
var windows: Array[Dictionary] = []
var pending: Array[Dictionary] = []
var previous: Dictionary = {}
var previous_key := ""
var serial := 0
var data: Dictionary = {}

func reset() -> void:
	history.clear()
	windows.clear()
	pending.clear()
	previous.clear()
	previous_key = ""
	serial = 0
	data.clear()

static func foot_loads(feet: Array) -> Dictionary:
	var rows: Array[Dictionary] = []
	var force := Vector3.ZERO
	var loaded := 0
	var sliding := 0
	for foot in feet:
		var actual: Vector3 = foot.get("force",Vector3.ZERO)
		var state: String = foot.get("state","FREE")
		var carrying: bool = state in ["SUPPORTING","SLIDING"] and actual.length_squared()>0.000001
		if carrying:
			loaded += 1
			if state=="SLIDING":sliding += 1
		force += actual
		rows.append({"state":state,"force":actual,"normal_force":foot.get("normal_force",0.0),"tangent_force":foot.get("tangent_force",Vector3.ZERO),"reason":foot.get("reason","")})
	return {"loaded_count":loaded,"sliding_loaded_count":sliding,"net_force":force,"feet":rows}

func _native_sole_contacts(body: RigidBody3D) -> Array[int]:
	var supports: Array[int] = []
	var state:=PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state==null:return supports
	for index in state.get_contact_count():
		var shape_index:int=state.get_contact_local_shape(index)
		if shape_index<0 or shape_index>=PhysicsServer3D.body_get_shape_count(body.get_rid()):continue
		var owner_node:Object=body.shape_owner_get_owner(body.shape_find_owner(shape_index))
		if owner_node!=null and owner_node.name=="FootBase" and state.get_contact_impulse(index).dot(Vector3.UP)>.0001:
			var identity:int=state.get_contact_collider_id(index)
			if not supports.has(identity):supports.append(identity)
	return supports

func _support_velocity(support:PhysicsBody3D,point:Vector3)->Variant:
	if support is RigidBody3D:
		var state:=PhysicsServer3D.body_get_direct_state(support.get_rid())
		if state==null:return null
		return state.linear_velocity+state.angular_velocity.cross(point-(state.transform.origin+state.center_of_mass))
	if support is StaticBody3D:return support.constant_linear_velocity+support.constant_angular_velocity.cross(point-support.global_position)
	return null

func sample(controller: Node, delta: float) -> Dictionary:
	if delta<=0 or not is_instance_valid(controller.torso):return {}
	var began:=Time.get_ticks_usec()
	var body: RigidBody3D = controller.torso
	var telemetry: Dictionary = controller.telemetry()
	var movement: Dictionary = controller.intent_locomotion.data
	var ground: Dictionary = controller.intent_locomotion.ground
	var assisted: bool = controller.assisted_motion_owned
	var feet: Dictionary = foot_loads(controller.feet_solver.feet if controller.feet_solver!=null else [])
	var states: Array = controller.hands.map(func(hand):return hand.state)
	var hand_forces: Array = [Vector3.ZERO,Vector3.ZERO] if assisted else telemetry.get("hand_force_vectors",[Vector3.ZERO,Vector3.ZERO])
	var ground_force: Vector3 = ground.get("applied_force",Vector3.ZERO) if not assisted else Vector3.ZERO
	var ground_torque: Vector3 = ground.get("applied_torque",Vector3.ZERO) if not assisted else Vector3.ZERO
	var swing: Vector3 = telemetry.get("swing_torque",Vector3.ZERO) if not assisted else Vector3.ZERO
	var swing_motion: Dictionary = telemetry.get("transfer_diagnostics",{}).get("motion",{})
	var owner_bits := 16 if assisted else 0
	if not assisted:
		if ground.get("grounded",false) and float(ground.get("authority",0.0))>0:owner_bits |= 1
		if controller._attached_ids().size()>0:owner_bits |= 2
		if feet.loaded_count>0:owner_bits |= 4
		if swing.length_squared()>0.000001:owner_bits |= 8
	var acceleration := Vector3.ZERO
	var angular_acceleration := Vector3.ZERO
	var jerk := Vector3.ZERO
	var derivative_valid := not previous.is_empty()
	if derivative_valid:
		acceleration = (body.linear_velocity-Vector3(previous.velocity))/delta
		angular_acceleration = (body.angular_velocity-Vector3(previous.angular_velocity))/delta
		if previous.get("derivative_valid",false):jerk = (acceleration-Vector3(previous.acceleration))/delta
	var direction: Vector3 = movement.get("movement_intent_world",Vector3.ZERO)
	var frame: Dictionary = movement.get("frame",{})
	var frame_rotation := 0.0
	var previous_frame: Dictionary = previous.get("frame",{})
	if frame.get("valid",false) and previous_frame.get("valid",false):
		var old_basis:=Basis(previous_frame.right,previous_frame.up,previous_frame.normal).orthonormalized()
		var new_basis:=Basis(frame.right,frame.up,frame.normal).orthonormalized()
		frame_rotation=(new_basis*old_basis.inverse()).get_rotation_quaternion().get_angle()
	var relative: Vector3 = movement.get("actual_relative_velocity",body.linear_velocity)
	var requested: Vector3 = movement.get("desired_com_velocity",Vector3.ZERO)
	var axis := direction.normalized()
	var feedback := ""
	var reason: String = movement.get("movement_block_reason","")
	if direction.length_squared()>0.000001 or controller.intent_locomotion.requested.length_squared()>0.000001:
		if reason in ["NO_REAL_SUPPORT","TARGET_PENDING_ONLY"] and not ground.get("grounded",false) and feet.loaded_count==0:feedback = "NO_SUPPORT"
		elif reason=="DIRECTION_UNACTUATABLE_AXIAL_SWING_ONLY":feedback = "AXIS_NOT_ACTUATABLE"
		elif reason=="ARM_FORCE_SATURATED":feedback = "ARM_SATURATED"
	var contact_blocked: bool = false
	for id in 2:
		if controller.pending_diagnostics(id).get("blocked",false):contact_blocked = true
	if contact_blocked and feedback.is_empty():feedback = "CONTACT_BLOCKED"
	var foot_feedback := "FOOT_NOT_PLANTED" if controller.tuning.physical_feet and feet.loaded_count==0 and (owner_bits & 2)!=0 and direction.length_squared()>0.000001 else ""
	var direct:=PhysicsServer3D.body_get_direct_state(body.get_rid())
	var actual_com:Variant=null
	if direct!=null:actual_com=direct.transform.origin+direct.center_of_mass
	var contacts:Array[Dictionary]=[]
	for id in 2:
		var hand:Dictionary=controller.hands[id]
		var valid:bool=hand.anchor!=null and hand.anchor.is_valid()
		var point:Vector3=controller.get_shoulder_world(id)
		var force:Vector3=hand_forces[id]
		var point_velocity:Variant=null
		var material_error:Variant=null
		if actual_com!=null:point_velocity=body.linear_velocity+body.angular_velocity.cross(point-Vector3(actual_com))
		if valid:material_error=Vector3(hand.anchor_world).distance_to(hand.anchor.world_point())
		contacts.append({"kind":"hand","id":id,"state":hand.state,"force":force,"point":point,
			"point_velocity":point_velocity,
			"support_velocity":_support_velocity(hand.anchor.support_body(),hand.anchor.world_point()) if valid else null,"normal":hand.anchor.world_normal() if valid else null,
			"support_id":hand.anchor.support_body().get_instance_id() if valid else null,"support_point":hand.anchor.world_point() if valid else null,
			"local_point":hand.anchor.local_point if valid else null,"force_anchor_world":hand.anchor_world if valid else null,
			"material_error_m":material_error,
			"applied":not assisted,"reason":hand.reason})
	if controller.feet_solver!=null:
		for id in controller.feet_solver.feet.size():
			var foot:Dictionary=controller.feet_solver.feet[id]
			var support:PhysicsBody3D=foot.get("support")
			var valid:bool=is_instance_valid(support) and support.is_inside_tree()
			var point:Vector3=foot.get("contact_point",Vector3.ZERO)
			var point_velocity:Variant=null
			var support_id:Variant=null
			if actual_com!=null:point_velocity=body.linear_velocity+body.angular_velocity.cross(point-Vector3(actual_com))
			if valid:support_id=support.get_instance_id()
			contacts.append({"kind":"foot","id":id,"state":foot.state,"force":foot.get("force",Vector3.ZERO),"point":point,
				"point_velocity":point_velocity,
				"support_velocity":_support_velocity(support,point) if valid else null,"normal":foot.get("normal",Vector3.ZERO),
				"support_id":support_id,"applied":not assisted,"reason":foot.reason})
	var row := {"time":controller.simulation_time,"tick":telemetry.get("step",0),"delta":delta,"profile":controller.control_profile,
		"position":body.global_position,"velocity":body.linear_velocity,"angular_velocity":body.angular_velocity,
		"acceleration":acceleration,"angular_acceleration":angular_acceleration,"jerk_proxy":jerk,"derivative_valid":derivative_valid,"jerk_valid":previous.get("derivative_valid",false),
		"movement_intent_world":direction,"desired_velocity":requested,"actual_relative_velocity":relative,
		"requested_useful_speed":requested.dot(axis),"actual_useful_speed":relative.dot(axis),"feedback_code":feedback,"foot_feedback":foot_feedback,
		"owner_bits":owner_bits,"owner_legend":{"ground":1,"hands":2,"feet":4,"swing":8,"hybrid":16},"hands":states,
		"grounded":ground.get("grounded",false),"native_sole_support_ids":_native_sole_contacts(body),"frame":frame.duplicate(true),"frame_angular_change":frame_rotation,
		"hand_forces":hand_forces,"hand_targets":controller.hands.map(func(hand):return hand.rest_length),"actual_lengths":controller.hands.map(func(hand):return hand.actual_length),
		"foot_load":feet,"ground_force":ground_force,"ground_torque":ground_torque,"ground_authority":ground.get("authority",0.0),
		"swing_request":controller.get_effective_swing_request(),"swing_torque":swing,"total_moment":telemetry.get("combined_ground_climb_torque",telemetry.get("torque",Vector3.ZERO)),
		"swing_phase":swing_motion.get("swing_phase","UNMEASURED"),"swing_power":swing_motion.get("swing_power",0.0),"pendulum_angular_velocity":swing_motion.get("pendulum_angular_velocity",Vector3.ZERO),
		"assisted":assisted,"scope":"finite difference includes real gravity/contact impulses; diagnostic, not a comfort threshold"}
	row["body_position"]=body.global_position
	row["accepted_input"]=movement.get("requested_input",Vector2.ZERO)
	row["accepted_input_time"]=movement.get("input_timestamp")
	row["accepted_input_frame_id"]=movement.get("input_frame_id")
	row["com_position"]=actual_com
	row["com_reference"]="Jolt direct-state origin + world COM offset" if actual_com!=null else "UNAVAILABLE"
	row["contacts"]=contacts
	if controller._attached_ids().size()==1:
		var id:int=controller._attached_ids()[0]
		var anchor=controller.hands[id].anchor
		if anchor!=null and anchor.is_valid():
			row["support_point_world"]=anchor.world_point()
			row["support_id"]="material:%d:%d"%[anchor.support_body().get_instance_id(),anchor.get_instance_id()]
	row["support_relative_scope"]="One retained material anchor only; multiple/changed supports are not an exact common reference"
	row["twist_rad"]=swing_motion.get("trunk_twist") if swing_motion.get("twist_valid",false) else null
	row["pendulum_angle_rad"]=swing_motion.get("pendulum_angle") if swing_motion.get("pendulum_valid",false) else null
	row["budget_use"]={"hands":telemetry.get("total_force",0.0)/controller.tuning.total_pull_force_budget,
		"feet":telemetry.get("leg_force",0.0)/maxf(.001,float(telemetry.get("leg_force_budget",180.0))),
		"assist":Vector3(telemetry.get("assist_torque",Vector3.ZERO)).length()/maxf(.001,controller.tuning.max_attitude_torque),
		"resultant":Vector3(row.total_moment).length()/maxf(.001,controller.tuning.max_total_torque)}
	row["saturated"]=row.budget_use.values().any(func(value):return float(value)>=.99)
	row["saturation_scope"]="Any shared hand, foot, assist or resultant budget >=99%; not actuator target saturation"
	row["contact_work_scope"]="Applied hand and foot linear forces only; excludes ground and torque work"
	var key := str(owner_bits)+str(states)+str(feet.feet.map(func(foot):return foot.state))
	if not previous_key.is_empty() and key!=previous_key:
		serial += 1
		pending.append({"id":serial,"time":row.time,"before_state":previous_key,"after_state":key,"before":history.duplicate(true),"after":[],"complete":false})
		if pending.size()>MAX_WINDOWS:pending.pop_front()
	for window in pending:
		window.after.append(row.duplicate(true))
		if row.time-float(window.time)>=WINDOW_SECONDS:
			window.complete = true
			windows.append(window.duplicate(true))
			if windows.size()>MAX_WINDOWS:windows.pop_front()
	pending = pending.filter(func(window):return not window.complete)
	history.append(row.duplicate(true))
	while not history.is_empty() and row.time-float(history[0].time)>WINDOW_SECONDS:history.pop_front()
	previous = row
	previous_key = key
	data = row.duplicate(true)
	data["transition_count"] = serial
	data["complete_windows"] = windows.size()
	data["pending_windows"] = pending.size()
	data["observer_cpu_usec"] = Time.get_ticks_usec()-began
	return data

func transition_windows() -> Dictionary:
	return {"window_seconds":WINDOW_SECONDS,"capacity":MAX_WINDOWS,"complete":windows.duplicate(true),"pending":pending.duplicate(true)}
