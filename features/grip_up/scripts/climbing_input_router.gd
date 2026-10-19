extends RefCounted

const DEFAULTS := {"grip_left": MOUSE_BUTTON_LEFT, "grip_right": MOUSE_BUTTON_RIGHT,
	"contract": KEY_W, "extend": KEY_S, "bias_left": KEY_A, "bias_right": KEY_D,
	"launch": KEY_SPACE,
	"restart": KEY_R, "debug_overlay": KEY_TAB, "fixed_beam": KEY_F}

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
