extends RefCounted

const DEFAULTS := {"grip_left": MOUSE_BUTTON_LEFT, "grip_right": MOUSE_BUTTON_RIGHT,
	"contract": KEY_W, "extend": KEY_S, "bias_left": KEY_A, "bias_right": KEY_D,
	"launch": KEY_SPACE,
	"restart": KEY_R, "debug_overlay": KEY_TAB, "fixed_beam": KEY_F,
	"controls_menu": KEY_ESCAPE}

var owner := "GAME"
var pending_y: Array[float] = [0.0,0.0]
var pending_anchors: Array = [null,null]
var gestures: Dictionary = {}
var pointer_distance := 0.0
var eligible_vertical_distance := 0.0
var requested_length: Array[float] = [0.0,0.0]
var motion_events := 0
var rebase_events := 0
var boundary_events := 0
var last_displacements: Array[float] = [0.0,0.0]
var rebase_next_motion := false

func clear_motion(id: int = -1) -> void:
	for hand in 2:
		if id<0 or id==hand:
			pending_y[hand] = 0.0
			pending_anchors[hand] = null
			last_displacements[hand] = 0.0

func set_owner(next: String) -> void:
	if next!=owner:
		clear_motion()
		rebase_events += 1
		if next=="BOUNDARY":
			boundary_events += 1
	owner = next

func reset_control_input(reason: String = "GAME") -> void:
	clear_motion()
	gestures.clear()
	owner = reason
	rebase_events += 1

func capture_motion(raw: Vector2, controller: Node, held: Array[bool]) -> void:
	if owner!="GAME" or not raw.is_finite():
		return
	if rebase_next_motion:
		rebase_next_motion = false
		clear_motion()
		return
	motion_events += 1
	pointer_distance += raw.length()
	var eligible := false
	for id in 2:
		var hand: Dictionary = controller.hands[id]
		if not held[id] or hand.state not in ["ATTACHED","SLIPPING"]:
			clear_motion(id)
			continue
		if pending_anchors[id]!=hand.anchor:
			clear_motion(id)
			pending_anchors[id] = hand.anchor
		pending_y[id] += raw.y
		eligible = true
	if eligible:
		eligible_vertical_distance += absf(raw.y)

func consume_drag(controller: Node, held: Array[bool]) -> Array[float]:
	var result: Array[float] = [0.0,0.0]
	if owner=="GAME":
		for id in 2:
			var hand: Dictionary = controller.hands[id]
			if held[id] and hand.state in ["ATTACHED","SLIPPING"] and hand.anchor==pending_anchors[id] and absf(pending_y[id])>controller.tuning.arm_drag_deadzone_px:
				# User override: upward aiming shortens the supporting arm too.
				result[id] = pending_y[id]*controller.tuning.arm_drag_sensitivity_m_per_px
				requested_length[id] += result[id]
	clear_motion()
	last_displacements = result.duplicate()
	return result

func swing_direction(camera_right: Vector3) -> Vector3:
	var right := camera_right.slide(Vector3.UP).normalized()
	if right.length_squared()<0.5:
		right = Vector3.RIGHT
	var forward := Vector3.UP.cross(right).normalized()
	var basis := {"contract":forward,"extend":-forward,"bias_left":-right,"bias_right":right}
	var direction := Vector3.ZERO
	for action in basis:
		if Input.is_action_pressed(action):
			if not gestures.has(action):
				gestures[action] = basis[action]
			direction += Vector3(gestures[action])*Input.get_action_strength(action)
		else:
			gestures.erase(action)
	return direction.limit_length(1.0)

func diagnostics() -> Dictionary:
	return {"owner":owner,"pending_y":pending_y.duplicate(),"last_displacements":last_displacements.duplicate(),
		"gesture_directions":gestures.duplicate(),"pointer_distance_px":pointer_distance,"eligible_vertical_distance_px":eligible_vertical_distance,
		"requested_length":requested_length.duplicate(),"motion_events":motion_events,"rebases":rebase_events,"boundary_events":boundary_events}

func setup() -> void:
	for action in DEFAULTS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			var event: InputEvent
			if action.begins_with("grip_"):
				event = InputEventMouseButton.new()
				event.button_index = DEFAULTS[action]
			else:
				event = InputEventKey.new()
				event.physical_keycode = DEFAULTS[action]
			InputMap.action_add_event(action, event)
	var config := ConfigFile.new()
	if config.load("user://controls.cfg") == OK:
		for action in DEFAULTS:
			var saved: Variant = config.get_value("bindings", action, null)
			if saved is InputEvent:
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, saved)

func bind(action: String, event: InputEvent) -> String:
	if not event is InputEventKey and not event is InputEventMouseButton:
		return "Use a key or mouse button"
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return "Middle mouse and wheel are reserved for the camera"
	for other in DEFAULTS:
		if other != action and InputMap.event_is_action(event, other):
			return "Already used by " + other
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	var config := ConfigFile.new()
	for key in DEFAULTS:
		config.set_value("bindings", key, InputMap.action_get_events(key)[0])
	config.save("user://controls.cfg")
	return ""

func prompt(action: String) -> String:
	return InputMap.action_get_events(action)[0].as_text()
