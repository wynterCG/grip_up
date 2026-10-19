extends RefCounted
## Optional sampled JSONL instrumentation. Reading this state cannot drive physics.
var enabled := false
var interval := 0.05
var path := "user://capture_frames.jsonl"
var _elapsed := 0.0
var _file: FileAccess

func vector(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func close() -> void:
	if _file!=null:
		_file.flush()
	_file = null
	_elapsed = 0.0

func sample(delta: float, controller: Node, extra: Dictionary = {}) -> void:
	if not enabled:
		close()
		return
	_elapsed += delta
	if _elapsed<interval:
		return
	_elapsed = 0.0
	var data: Dictionary = controller.telemetry()
	if data.is_empty():
		return
	if _file==null:
		_file = FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
		if _file==null:
			return
		_file.seek_end()
	var row := {"time":controller.simulation_time,"step":data.step,"physics_hz":Engine.physics_ticks_per_second,
		"features":data.features,"intent":vector(data.input_intent),"requested_intent":vector(data.requested_intent),
		"total_force":data.total_force,"force_budget":data.force_budget,"torque":vector(data.torque),
		"position":vector(controller.torso.global_position),"linear_velocity":vector(controller.torso.linear_velocity),
		"angular_velocity":vector(controller.torso.angular_velocity),"physics_step_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
		"fps":Engine.get_frames_per_second(),"hands":[]}
	for id in 2:
		var hand: Dictionary = controller.hands[id]
		var anchor = hand.anchor
		var valid: bool = anchor!=null and anchor.is_valid()
		var support: PhysicsBody3D = anchor.support_body() if valid else null
		var point: Vector3 = anchor.world_point() if valid else hand.hand_world
		var relative: Vector3 = controller.torso.linear_velocity+controller.torso.angular_velocity.cross(controller.get_shoulder_world(id)-controller.torso.global_position)-(anchor.point_velocity() if valid else Vector3.ZERO)
		row.hands.append({"id":id,"state":hand.state,"hand_position":vector(hand.hand_world),"target_world":vector(point),
			"target_local":vector(anchor.local_point) if valid else [],"support_id":support.get_instance_id() if support!=null else 0,
			"support_name":str(support.name) if support!=null else "","actual_length":controller.get_shoulder_world(id).distance_to(point),
			"desired_length":hand.rest_length,"relative_velocity":vector(relative),"force":vector(hand.force),
			"force_magnitude":Vector3(hand.force).length(),"grip_limit":hand.grip_limit,"reason":hand.reason,"capture":hand.get("capture",{})})
	row.merge(extra)
	_file.store_line(JSON.stringify(row))
	_file.flush()
