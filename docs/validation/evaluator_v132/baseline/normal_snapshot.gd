extends SceneTree
const Lab=preload("res://features/grip_up/scripts/grip_up_lab.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
 var a=Lab.new();root.add_child(a)
 await process_frame
 await physics_frame
 await physics_frame
 var bindings={}
 for name in ["contract","extend","bias_left","bias_right","grip_left","grip_right"]:
  bindings[name]=InputMap.action_get_events(name).map(func(event):return event.as_text())
 var observed={"profile":a.input_profile,"allocation":a.movement_allocation,"physics_hz":Engine.physics_ticks_per_second,"hold":a.hold_mode,"physical_feet":a.physical_feet_enabled,"intent_aware_feet":a.intent_aware_feet_enabled,"observer":a.locomotion_diagnostics_enabled,"capture_recorder":a.capture_trace.enabled,"mass":a.torso.mass,"reach":a.controller.get_max_reach(),"values":[a.controller.tuning.traversal_speed_m_s,a.controller.tuning.traversal_input_ramp_s,a.controller.tuning.traversal_target_max_rate,a.controller.tuning.traversal_target_max_acceleration],"bindings":bindings}
 print("V132_BASELINE ",JSON.stringify(observed));quit(0)
