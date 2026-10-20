extends "res://features/grip_up/scripts/grip_up_lab.gd"
## Strict reference factory. Constructs the ORIGINAL gameplay Lab/Resource and
## verifies it; no Resource duplicate, override application or value assignment.
var override_loader:RefCounted
var trial_candidate:Dictionary={}
var override_error:=""
var installs:Array[Dictionary]=[]
func verify_tuning(target:Node)->Dictionary:
	if override_loader==null:return {"ok":false,"reason":"NO_BASELINE_VALIDATOR"}
	var original:Resource=target.tuning
	var actual:Dictionary={}
	for knob:Dictionary in override_loader.space.parameters:
		actual[knob.id]=original.get(knob.id)
		if float(actual[knob.id])!=float(knob.baseline):return {"ok":false,"reason":"BASELINE_RESOURCE_MISMATCH:"+str(knob.id),"actual":actual}
	return {"ok":true,"actual":actual,"resource_instance_id":original.get_instance_id(),"identity_unchanged":target.tuning==original,"mode":"BASELINE_IDENTITY_ONLY_NO_OVERRIDES"}
func load_test(index:int,use_checkpoint:bool=false)->void:
	super.load_test(index,use_checkpoint)
	var verified:Dictionary=verify_tuning(controller)
	if not verified.ok:
		override_error=str(verified.reason)
		controller.set_physics_process(false);ground_motor.set_physics_process(false)
		return
	installs.append({"level":index,"controller_step":controller._step,"before_first_step":controller._step==0,"verification_only":true,"actual_baseline":verified.actual,"resource_instance_id":verified.resource_instance_id,"identity_unchanged":verified.identity_unchanged,"mode":verified.mode})
