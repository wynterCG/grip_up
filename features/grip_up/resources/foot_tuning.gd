extends Resource
## Separate M2 leg effort budget. Hands retain their existing 360 N budget.
@export var total_force_budget: float = 180.0
@export var max_force_per_foot: float = 120.0
@export var plant_speed: float = 2.0
@export var stiffness: float = 1800.0
@export var damping: float = 100.0
@export var contact_preload: float = 0.025
@export var extension_rate: float = 0.30
@export var lower_rate: float = 0.40
@export var engagement_time: float = 0.12
@export var foot_friction: float = 0.85
@export var search_interval: float = 0.10
@export var search_height: float = 0.35
@export var search_depth: float = 0.40
@export var lateral_search: float = 0.28
@export var max_leg_angle: float = 1.92
@export var minimum_length_ratio: float = 0.25
@export var contact_tolerance: float = 0.003
@export var slip_speed: float = 0.25
@export var step_preference: float = 1.8
@export var step_clearance: float = 0.06
@export var bearing_preference: float = 0.35
