extends "res://features/evaluator_reliability/scripts/baseline_lab.gd"
func load_test(index:int,use_checkpoint:bool=false)->void:
	if is_instance_valid(controller) and override_loader!=null:
		var reason:String=override_loader.seal_pre_step(controller,{"physical_feet":physical_feet_enabled,"allow_out_of_reach_grip_targets":_distant_targeting_active()},"UNMEASURED_STARTUP_RETIRED")
		if not reason.is_empty():override_error=reason;return
	super.load_test(index,use_checkpoint)
	if not installs.is_empty():installs[-1].verification_only=false
## Parent invokes this synchronously after EACH load, before any physics callback.
func verify_tuning(target:Node)->Dictionary:
	if override_loader==null:return {"ok":false,"reason":"NO_MINIMAL_VALIDATOR"}
	var result:Dictionary=override_loader.apply_to(target,trial_candidate)
	if not result.ok:return result
	return {"ok":true,"actual":result.applied,"resource_instance_id":target.tuning.get_instance_id(),"identity_unchanged":target.tuning==result.original,"mode":"MBQ_SESSION_LOCAL_COPY"}
