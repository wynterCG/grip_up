extends Resource
@export_group("v0.5 transfer twist experiment")
@export var transfer_twist_blend_time: float = 0.20
@export var transfer_twist_frame_max_rate: float = 2.5
@export var transfer_twist_frame_response: float = 0.10
@export var transfer_posture_blend_time: float = 0.25
@export var transfer_posture_max_rate: float = 0.80
@export var transfer_posture_max_acceleration: float = 3.0
@export_group("v0.4 independent aim posture experiment")
@export var posture_comfort_extension_ratio: float = 0.30
@export var posture_body_surface_clearance: float = 0.24
@export var posture_target_max_speed: float = 0.25
@export var posture_target_max_acceleration: float = 1.0
@export var posture_max_settle_time: float = 2.0
@export var posture_tracking_tolerance: float = 0.07
@export var posture_stall_confirm_time: float = 0.25
@export var posture_saturation_ratio: float = 0.92
@export var posture_tilt_stiffness: float = 12.0
@export var posture_tilt_damping: float = 1.2
@export var posture_gravity_moment_compensation: float = 0.80
@export_group("v0.3 hold drag swing experiment")
@export var arm_drag_sensitivity_m_per_px: float = 0.0015
@export var arm_drag_deadzone_px: float = 0.10
@export var arm_target_max_rate_m_s: float = 0.60
@export var swing_max_support_torque: float = 18.0
@export var swing_input_ramp_s: float = 0.10
@export var swing_max_relative_speed: float = 1.8
@export_group("Contextual relative effort experiment")
@export var contextual_response_time: float = 0.08
@export var contextual_pull_offset: float = 0.10
@export var contextual_hold_tolerance: float = 0.03
@export var contextual_extension_max_rate_m_s: float = 0.35
@export_group("v0.2 experiments")
@export var predictive_grip: bool = false
@export var physical_feet: bool = false
@export var posture_solver: bool = false
@export var directional_grip_quality: bool = false
@export var reactive_challenge: bool = false
@export var capture_prediction_horizon: float = 0.20
@export var capture_intent_buffer_duration: float = 0.15
@export_group("Existing arm controller")
## Same finite point-servo family as janga_proto/data/grabber_tuning.gd.
@export var shoulder_left: Vector3 = Vector3(-0.32, 0.30, 0)
@export var shoulder_right: Vector3 = Vector3(0.32, 0.30, 0)
@export var max_arm_length: float = 2.35
@export var max_reach_length: float = 0.0
@export var min_arm_length: float = 0.55
@export var arm_stiffness: float = 900.0
@export var arm_damping: float = 70.0
@export var total_pull_force_budget: float = 360.0
@export var max_force_per_arm: float = 360.0
@export var max_total_torque: float = 150.0
@export var max_length_error: float = 0.75
@export var contraction_speed: float = 1.05
@export var extension_speed: float = 1.3
@export var hand_reach_speed: float = 8.0
@export var free_hand_rest_left: Vector3 = Vector3(-0.12,-0.45,-0.12)
@export var free_hand_rest_right: Vector3 = Vector3(0.12,-0.45,-0.12)
@export var hand_surface_approach_distance: float = 0.18
@export var attach_distance_tolerance: float = 0.045
@export var candidate_hold_timeout: float = 0.85
@export_flags_3d_physics var allowed_grip_surface_mask: int = 0xFFFFFFFF
@export var grip_blend_duration: float = 0.18
@export var allocation_response_time: float = 0.14
@export var intent_response_time: float = 0.0
@export var max_elastic_extension: float = 0.65
@export var grip_force_limit: float = 260.0
@export var overload_confirm_time: float = 0.20
@export var slip_duration: float = 0.40
@export var slip_force_multiplier: float = 0.65
@export var slip_recovery_ratio: float = 0.75
@export var slip_recovery_time: float = 0.16
@export var single_bias_torque: float = 18.0
@export var attitude_damping: float = 2.0
@export var max_attitude_torque: float = 20.0
@export var twist_stiffness: float = 0.0
@export var twist_damping: float = 0.0
@export var launch_charge_duration: float = 0.45
@export var launch_charge_extension_speed: float = 0.75
@export var launch_contraction_speed: float = 0.0
@export var launch_duration: float = 0.30
@export var launch_cooldown: float = 0.45
