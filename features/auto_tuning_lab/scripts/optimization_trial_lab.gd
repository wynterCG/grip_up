extends "res://features/grip_up/scripts/grip_up_lab.gd"
## Explicit evaluator-only factory. Four knobs are unused by load/configure;
## duplicate installation occurs synchronously before the first physics step.
signal trial_controller_ready(controller:Node)
var override_loader:RefCounted
var trial_candidate:Dictionary={}
var override_error:=""
var installs:Array[Dictionary]=[]

func load_test(index:int,use_checkpoint:bool=false)->void:
	super.load_test(index,use_checkpoint)
	if override_loader==null or trial_candidate.is_empty():return
	var applied:Dictionary=override_loader.apply_to(controller,trial_candidate)
	if not applied.get("ok",false):
		override_error=str(applied.get("reason","OVERRIDE_FAILED"))
		controller.set_physics_process(false);ground_motor.set_physics_process(false)
		return
	trial_controller_ready.emit(controller)
	installs.append({"level":index,"controller_step":controller._step,"applied":applied.applied.duplicate(true),"before_first_step":controller._step==0})
