extends "res://features/grip_up/scripts/grip_up_lab.gd"
## Reuse baseline input scenarios with only the explicit presentation flag on.
func _open_hybrid_mantle(scenario:int=0,use_vault_presentation:bool=true)->void:
	super._open_hybrid_mantle(scenario,use_vault_presentation)
