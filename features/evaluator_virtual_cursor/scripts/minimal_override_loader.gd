extends "res://features/auto_tuning_lab/scripts/optimization_override_loader.gd"
## Extra exact guards for MBQ only; original whitelist/copy installation is reused.
var receipts:Array[Dictionary]=[]
var full_bindings:Array[Dictionary]=[]
var restoration_failed:=false

func full_values(resource:Resource)->Dictionary:
	var values:Dictionary=protected_values(resource)
	for knob:Dictionary in space.parameters:values[knob.id]=resource.get(knob.id)
	return values

func apply_to(controller:Node,value:Dictionary)->Dictionary:
	if controller._step!=0:return {"ok":false,"reason":"OVERRIDE_AFTER_FIRST_STEP"}
	var original:Resource=controller.tuning
	var before:Dictionary=full_values(original)
	for knob:Dictionary in space.parameters:
		if float(original.get(knob.id))!=float(knob.baseline):return {"ok":false,"reason":"EXACT_BASELINE_DRIFT:"+str(knob.id)}
	var result:Dictionary=super.apply_to(controller,value)
	if not result.ok:return result
	for key in value.parameter_overrides:
		if float(controller.tuning.get(key))!=float(value.parameter_overrides[key]):return {"ok":false,"reason":"EXACT_RESOLVED_VALUE:"+str(key)}
	full_bindings.append({"controller":controller,"original":original,"local":controller.tuning,"before":before,"effective":full_values(controller.tuning),"sealed":false})
	receipts.append({"step":controller._step,"original_id":original.get_instance_id(),"local_id":controller.tuning.get_instance_id(),"original":before,"effective":full_values(controller.tuning),"original_unchanged":before==full_values(original),"copied":original!=controller.tuning})
	return result

func seal_pre_step(controller:Node,expected:Dictionary,scope:String)->String:
	if controller._step!=0:return "SEAL_AFTER_FIRST_STEP"
	for binding:Dictionary in full_bindings:
		if is_instance_valid(binding.controller) and binding.controller==controller:
			if controller.tuning!=binding.local or full_values(binding.original)!=binding.before:return "SEAL_ORIGINAL_OR_POINTER_DRIFT"
			var observed:Dictionary=full_values(binding.local)
			for key in observed:
				if key in ["physical_feet","allow_out_of_reach_grip_targets"]:
					if not expected.has(key) or observed[key]!=expected[key]:return "SEAL_PROFILE_FLAG:"+str(key)
				elif observed[key]!=binding.effective[key]:return "SEAL_PROTECTED_DRIFT:"+str(key)
			binding.effective=observed;binding.sealed=true
			receipts.append({"seal_scope":scope,"step":controller._step,"effective":observed,"expected_flags":expected,"original_unchanged":true})
			return ""
	return "SEAL_BINDING_MISSING"

func exact_effective_valid(controller:Node)->bool:
	for binding:Dictionary in full_bindings:
		if is_instance_valid(binding.controller) and binding.controller==controller:
			return binding.sealed and controller.tuning==binding.local and full_values(controller.tuning)==binding.effective and full_values(binding.original)==binding.before
	return false

func restore()->Dictionary:
	var exact:=true
	for binding:Dictionary in full_bindings:
		exact=exact and full_values(binding.original)==binding.before
		if is_instance_valid(binding.controller):exact=exact and binding.controller.tuning==binding.local and full_values(binding.local)==binding.effective
	var result:Dictionary=super.restore()
	for binding:Dictionary in full_bindings:
		if is_instance_valid(binding.controller):exact=exact and binding.controller.tuning==binding.original
	full_bindings.clear()
	restoration_failed=restoration_failed or not exact
	result["exact_originals_and_pointer_restore"]=exact and not restoration_failed
	result.originals_preserved=result.originals_preserved and exact and not restoration_failed
	return result
