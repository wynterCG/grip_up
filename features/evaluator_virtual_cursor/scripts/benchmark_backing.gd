extends RefCounted
## Test-only startup configuration. Never called after gameplay-world creation.
static func safe_value(value:Variant)->Variant:
	if value is float and not is_finite(value):return {"nonfinite":str(value)}
	if value is Array:
		var result:Array=[]
		for item in value:result.append(safe_value(item))
		return result
	if value is Dictionary:
		var result:Dictionary={}
		for key in value:result[key]=safe_value(value[key])
		return result
	return value

static func canonical_dimensions(document:Variant,key:String,expected:Vector2i)->Dictionary:
	var result:Dictionary={"field":key,"status":"INVALID_SCHEMA","reason":"MISSING_KEY","raw_values":null,"parsed_types":[],"canonical":null}
	if not document is Dictionary or not document.has(key):return result
	var values:Variant=document[key]
	result.raw_values=safe_value(values)
	if not values is Array or values.size()!=2:result.reason="ARRAY_LENGTH";return result
	for value:Variant in values:result.parsed_types.append(type_string(typeof(value)))
	for value:Variant in values:
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:result.reason="NUMERIC_TYPE_REQUIRED";return result
		if not is_finite(float(value)):result.reason="NONFINITE";return result
		if float(value)!=floor(float(value)):result.reason="NON_INTEGRAL";return result
		if value<=0 or value>16384:result.reason="POSITIVE_DIMENSION_BOUNDS";return result
	var canonical:Array=[int(values[0]),int(values[1])]
	result.canonical=canonical
	if canonical[0]!=expected.x or canonical[1]!=expected.y:result.reason="WRONG_DIMENSIONS";return result
	result.status="VALID_SCHEMA";result.reason="";return result

static func projection_schema(config:Variant)->Dictionary:
	var window:Dictionary=canonical_dimensions(config,"window_size",Vector2i(1024,576))
	var viewport:Dictionary=canonical_dimensions(config,"logical_viewport_size",Vector2i(1920,1080))
	var reason:String=window.reason if not window.reason.is_empty() else viewport.reason
	if reason.is_empty() and (not config.has("probe_enabled") or not config.probe_enabled is bool):reason="PROBE_BOOLEAN_REQUIRED"
	return {"status":"VALID_SCHEMA" if reason.is_empty() else "INVALID_SCHEMA","reason":reason,"window":window,"viewport":viewport,"raw_config":safe_value(config)}

static func initialize(window:Window,config:Variant)->Dictionary:
	var before:Vector2i=window.size
	var initialized:=false
	var reason:=""
	var requested:Array=[]
	var schema:Dictionary=projection_schema(config)
	if not schema.reason.is_empty():reason="INVALID_SCHEMA:"+schema.reason
	if reason.is_empty() and DisplayServer.get_name()=="headless":
		# Engine options are consumed before OS exposes arguments to scripts.
		var args:PackedStringArray=OS.get_cmdline_user_args()
		var index:int=args.find("--backing-size")
		if index<0 or index+1>=args.size():reason="RESOLUTION_ARGUMENT_REQUIRED"
		else:
			var dimensions:PackedStringArray=args[index+1].split("x")
			if dimensions.size()!=2 or not dimensions[0].is_valid_int() or not dimensions[1].is_valid_int():reason="CANONICAL_BACKING"
			else:
				requested=[int(dimensions[0]),int(dimensions[1])]
				if requested!=[1024,576]:reason="CANONICAL_BACKING"
		if reason.is_empty():
			# Headless Window ignores the CLI size in this build; initialize preworld.
			if window.size!=Vector2i(1024,576):window.size=Vector2i(1024,576)
			initialized=true
	if reason.is_empty() and window.size!=Vector2i(1024,576):reason="CANONICAL_BACKING"
	if reason.is_empty() and window.get_visible_rect().size!=Vector2(1920,1080):reason="LOGICAL_VIEWPORT"
	return {"reason":reason,"projection_schema":schema,"before_size":[before.x,before.y],"requested_cli_size":requested,"explicit_headless_initialization":initialized,"actual_size":[window.size.x,window.size.y],"logical_size":[window.get_visible_rect().size.x,window.get_visible_rect().size.y],"phase":"BEFORE_GAMEPLAY_WORLD"}
