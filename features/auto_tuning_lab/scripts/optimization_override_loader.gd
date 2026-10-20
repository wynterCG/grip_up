extends RefCounted
## Trial-only whitelist. No source/resource save and no physical body access.
const SPACE_PATH="res://features/auto_tuning_lab/resources/parameter_space.json"
const REQUIRED=["schema_version","trial_id","candidate_id","profile","parameter_overrides","scenarios","requested_physics_hz","input_trace_id","run_seed","repository_commit","timeout_seconds","source_hashes","engine_identity","evaluation_split"]
var space:Dictionary={}
var bindings:Array[Dictionary]=[]

func _init()->void:
	var decoded:Variant=JSON.parse_string(FileAccess.get_file_as_string(SPACE_PATH))
	if decoded is Dictionary:space=decoded

static func numeric(value:Variant)->bool:
	return (value is int or value is float) and not value is bool and is_finite(float(value))

static func matches(value:Variant,pattern:String)->bool:
	if not value is String:return false
	var expression:=RegEx.new()
	expression.compile(pattern)
	return expression.search(value)!=null

func canonical(values:Dictionary)->String:
	var ids:Array=values.keys();ids.sort()
	var fragments:Array[String]=[]
	for id in ids:fragments.append(JSON.stringify(str(id))+":"+String.num(float(values[id]),8))
	return "{"+",".join(fragments)+"}"

func validate(candidate:Dictionary,verify_sources:bool=true)->Dictionary:
	var errors:Array[String]=[]
	if space.get("schema_version")!="1.0" or space.get("version")!="AT1-r1":errors.append("PARAMETER_SPACE_VERSION")
	for key in candidate:
		if key not in REQUIRED:errors.append("UNKNOWN_FIELD:"+str(key))
	for key in REQUIRED:
		if not candidate.has(key):errors.append("MISSING_FIELD:"+key)
	if not errors.is_empty():return {"ok":false,"reason":"SCHEMA_FIELDS","errors":errors}
	if candidate.schema_version!="1.0":errors.append("SCHEMA_VERSION")
	if candidate.profile!="BASE-A0-B1":errors.append("PROFILE")
	if candidate.evaluation_split not in ["train","holdout","safety"]:errors.append("SPLIT")
	if not matches(candidate.trial_id,"^[A-Za-z0-9_-]{1,100}$"):errors.append("TRIAL_ID")
	if not matches(candidate.candidate_id,"^[a-f0-9]{64}$"):errors.append("CANDIDATE_ID")
	if not matches(candidate.repository_commit,"^[a-f0-9]{40}$"):errors.append("REPOSITORY_COMMIT")
	if not candidate.input_trace_id is String or candidate.input_trace_id.is_empty():errors.append("INPUT_TRACE_ID")
	if not numeric(candidate.run_seed) or float(candidate.run_seed)!=floor(float(candidate.run_seed)) or float(candidate.run_seed)<0 or float(candidate.run_seed)>2147483647:errors.append("RUN_SEED")
	if not numeric(candidate.requested_physics_hz) or (float(candidate.requested_physics_hz)!=60.0 and float(candidate.requested_physics_hz)!=120.0):errors.append("PHYSICS_HZ")
	if not numeric(candidate.timeout_seconds) or float(candidate.timeout_seconds)<1 or float(candidate.timeout_seconds)>1800:errors.append("TIMEOUT")
	if not candidate.scenarios is Array or candidate.scenarios.is_empty() or candidate.scenarios.size()>32:errors.append("SCENARIOS")
	else:
		var seen:Dictionary={}
		for id in candidate.scenarios:
			if not id is String or id.is_empty() or seen.has(id):errors.append("SCENARIO_ID")
			seen[id]=true
	if not candidate.engine_identity is Dictionary:errors.append("ENGINE_IDENTITY")
	elif candidate.engine_identity.size()!=2 or not candidate.engine_identity.has("version") or not matches(candidate.engine_identity.get("sha256"),"^[a-f0-9]{64}$") or not candidate.engine_identity.get("version") is String:errors.append("ENGINE_IDENTITY")
	var values:Variant=candidate.parameter_overrides
	if not values is Dictionary:errors.append("OVERRIDE_TYPE")
	else:
		var ids:Array=[]
		for knob:Dictionary in space.parameters:ids.append(knob.id)
		if values.size()!=ids.size():errors.append("FULL_OVERRIDE_REQUIRED")
		for id in values:
			if id not in ids:errors.append("UNKNOWN_PARAMETER:"+str(id))
		for knob:Dictionary in space.parameters:
			if not values.has(knob.id):errors.append("MISSING_PARAMETER:"+knob.id);continue
			var value:Variant=values[knob.id]
			if not numeric(value):errors.append("NONFINITE_OR_TYPE:"+knob.id);continue
			if float(value)<float(knob.min) or float(value)>float(knob.max):errors.append("RANGE:"+knob.id)
			if absf(float(value)-float(String.num(float(value),8)))>.0000000001:errors.append("PRECISION:"+knob.id)
		if errors.is_empty():
			if float(values.traversal_target_max_rate)**2/(2.0*float(values.traversal_target_max_acceleration))>.055+.0000000001:errors.append("TARGET_BRAKING_ENVELOPE")
			if float(values.traversal_input_ramp_s)<4.0/60:errors.append("RESOLVED_INPUT_RAMP")
			if canonical(values).sha256_text()!=candidate.candidate_id:errors.append("PARAMETER_HASH")
	var observed:Dictionary={}
	if not candidate.source_hashes is Dictionary or candidate.source_hashes.is_empty():errors.append("SOURCE_HASHES")
	else:
		for path in candidate.source_hashes:
			if not path is String or path.is_empty() or path.contains("..") or path.contains(":") or path.contains("\\") or path.begins_with("/"):
				errors.append("SOURCE_PATH");continue
			if candidate.evaluation_split=="train" and path.contains("/holdout/"):errors.append("PRIVATE_HOLDOUT_HASH");continue
			if not matches(candidate.source_hashes[path],"^[a-f0-9]{64}$"):errors.append("SOURCE_HASH_TYPE");continue
			if verify_sources:
				var actual:String=FileAccess.get_sha256("res://"+path)
				observed[path]=actual
				if actual!=candidate.source_hashes[path]:errors.append("SOURCE_MISMATCH:"+path)
	return {"ok":errors.is_empty(),"reason":"VALID" if errors.is_empty() else errors[0],"errors":errors,"source_hashes":observed,"parameter_space_sha256":FileAccess.get_sha256(SPACE_PATH)}

func protected_values(resource:Resource)->Dictionary:
	var ignored:Array=[]
	for knob:Dictionary in space.parameters:ignored.append(knob.id)
	var result:Dictionary={}
	for property:Dictionary in resource.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE and str(property.name) not in ignored:result[property.name]=resource.get(property.name)
	return result

func apply_to(controller:Node,candidate:Dictionary)->Dictionary:
	var checked:Dictionary=validate(candidate)
	if not checked.ok:return checked
	var original:Resource=controller.tuning
	for knob:Dictionary in space.parameters:
		if not is_equal_approx(float(original.get(knob.id)),float(knob.baseline)):return {"ok":false,"reason":"BASELINE_DRIFT:"+knob.id}
	var before:Dictionary=protected_values(original)
	var local:Resource=original.duplicate(true)
	for id in candidate.parameter_overrides:local.set(id,float(candidate.parameter_overrides[id]))
	if before!=protected_values(local):return {"ok":false,"reason":"PROTECTED_RESOURCE_CHANGED"}
	controller.tuning=local
	bindings.append({"controller":controller,"original":original,"local":local,"protected":before})
	return {"ok":true,"tuning":local,"original":original,"applied":candidate.parameter_overrides.duplicate(true),"protected":before}

func restore()->Dictionary:
	var preserved:=true
	var restored:=0
	for binding:Dictionary in bindings:
		preserved=preserved and binding.protected==protected_values(binding.original)
		if is_instance_valid(binding.controller) and binding.controller.tuning==binding.local:
			binding.controller.tuning=binding.original;restored+=1
	bindings.clear()
	return {"restored":restored,"originals_preserved":preserved}
