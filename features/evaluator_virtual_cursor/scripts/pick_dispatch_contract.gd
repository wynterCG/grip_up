extends RefCounted
## Read-only migration of logical decisions and actual query observations.
const SCHEMA="grip_pick_dispatch_contract_v134"
const OFFSETS=[[0,0],[12,0],[-12,0],[0,12],[0,-12],[8,8],[-8,-8]]
const RAY_FIELDS={"offset_px":"offset","point_px":"screen_point","origin_m":"origin","direction":"world_normal_used","reason":"reason"}
const HIT_FIELDS={"collider_key":"collider_key","collider_runtime_id":"runtime_id","local_point_m":"material_point","local_normal":"material_normal","world_point_m":"world_point","world_normal":"world_normal","shape":"shape"}

static func exact_integer(value:Variant,low:int=0,high:int=9223372036854775807)->bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floor(float(value)) and value>=low and value<=high

static func dispatch_identity(session_id:String,tick:int,hand:int,ordinal:int)->String:
	return "%s:t%d:h%d:d%d"%[session_id,tick,hand,ordinal]

static func same_numbers(left:Variant,right:Variant)->bool:
	if typeof(left) in [TYPE_INT,TYPE_FLOAT] and typeof(right) in [TYPE_INT,TYPE_FLOAT]:return left==right
	if left is Array and right is Array:
		if left.size()!=right.size():return false
		for i in left.size():
			if not same_numbers(left[i],right[i]):return false
		return true
	return typeof(left)==typeof(right) and left==right

static func _fail(reason:String)->Dictionary:
	return {"schema":SCHEMA,"status":"INVALID","reason":reason}

static func _finite(value:Variant)->bool:
	if value is float:return is_finite(value)
	if value is Array:
		for v:Variant in value:
			if not _finite(v):return false
	if value is Dictionary:
		for v:Variant in value.values():
			if not _finite(v):return false
	return true

static func _vector(value:Variant,length:int)->bool:
	if not value is Array or value.size()!=length:return false
	for component:Variant in value:
		if not typeof(component) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(component)):return false
	return true

static func _audit(pick:Dictionary,physical:Dictionary)->String:
	var audit:Dictionary=pick.audit
	var rays:Variant=audit.get("rays");var observed:Variant=physical.get("rays")
	if not rays is Array or rays.is_empty() or rays.size()>7 or not observed is Array or rays.size()!=observed.size():return "PICK_RAY_COUNT_MISMATCH"
	if not physical.get("cursor") is Dictionary:return "INVALID_PICK_CURSOR"
	for value:Variant in [pick.get("pointer"),audit.get("pointer"),physical.cursor.get("actual_vector")]:
		if not _vector(value,2):return "INVALID_PICK_CURSOR"
	if pick.get("pointer")!=audit.get("pointer") or audit.get("pointer")!=physical.get("cursor",{}).get("actual_vector"):return "PICK_CURSOR_MISMATCH"
	if audit.get("mask")!=3:return "PICK_MASK_MISMATCH"
	if audit.get("range_m")!=70:return "PICK_RANGE_MISMATCH"
	var winner:Variant=null
	for index in rays.size():
		if not rays[index] is Dictionary or not observed[index] is Dictionary:return "INVALID_PICK_RAY"
		var logical:Dictionary=rays[index];var real:Dictionary=observed[index]
		for key:String in ["offset_px","point_px","origin_m","direction"]:
			if not _vector(logical.get(key),2 if key in ["offset_px","point_px"] else 3):return "INVALID_PICK_RAY_VECTOR"
		for key:String in ["offset","screen_point","origin","world_normal_used","query_from","query_to"]:
			if not _vector(real.get(key),2 if key in ["offset","screen_point"] else 3):return "INVALID_PICK_RAY_VECTOR"
		if not exact_integer(real.get("query_index")) or real.query_index!=index or not same_numbers(logical.get("offset_px"),OFFSETS[index]):return "PICK_RAY_ORDER"
		for src:String in RAY_FIELDS:
			var dst:String=RAY_FIELDS[src]
			if not logical.has(src) or not real.has(dst):return "PICK_RAY_FIELD_MISSING"
			if logical[src]!=real[dst]:return "PICK_RAY_MISMATCH:"+src
		if real.get("query_from")!=logical.origin_m:return "PICK_RAY_MISMATCH:query_from"
		# Recreate only native Vector3 arithmetic, never dispatch another query.
		var origin:=Vector3(logical.origin_m[0],logical.origin_m[1],logical.origin_m[2])
		var direction:=Vector3(logical.direction[0],logical.direction[1],logical.direction[2])
		var endpoint:Vector3=origin+direction*70.0
		# Godot's JSON parser can shift the raw promoted scalar by one double
		# ULP. Bind this named native Vector3 channel to its measured bits.
		var bits:Variant=physical.get("numeric_bits")
		if not bits is Dictionary:return "PICK_ENDPOINT_BITS_MISSING"
		for component in 3:
			var encoded:Variant=bits.get("/rays/%d/query_to/%d"%[index,component])
			if not encoded is String or encoded.length()!=16:return "PICK_ENDPOINT_BITS_MISSING"
			for digit:String in encoded:
				if not "0123456789abcdef".contains(digit):return "PICK_ENDPOINT_BITS_INVALID"
			var measured:=PackedByteArray()
			for offset in range(0,16,2):measured.append(encoded.substr(offset,2).hex_to_int())
			var expected:=PackedByteArray();expected.resize(8);expected.encode_double(0,endpoint[component])
			if expected!=measured:return "PICK_RAY_MISMATCH:query_to"
			var raw_native:=Vector3(real.query_to[0],real.query_to[1],real.query_to[2])
			if raw_native[component]!=measured.decode_double(0):return "PICK_ENDPOINT_RAW_BITS_MISMATCH"
		if real.get("mask")!=audit.mask:return "PICK_MASK_MISMATCH"
		if real.get("distance_m")!=audit.range_m:return "PICK_RANGE_MISMATCH"
		if not logical.reason is String:return "UNKNOWN_PICK_RESULT"
		var reason:String=logical.reason
		if not reason in ["MISS","INELIGIBLE","SELECTED"]:return "UNKNOWN_PICK_RESULT"
		if reason=="MISS":
			if real.has("hit"):return "FABRICATED_PICK_HIT"
			for key:String in HIT_FIELDS:
				if logical.has(key):return "FABRICATED_PICK_HIT"
		else:
			var hit:Variant=real.get("hit")
			if not hit is Dictionary:return "PICK_MATERIAL_MISMATCH"
			for key:String in ["local_point_m","local_normal","world_point_m","world_normal"]:
				if not _vector(logical.get(key),3):return "INVALID_PICK_MATERIAL_VECTOR"
			for key:String in ["material_point","material_normal","world_point","world_normal"]:
				if not _vector(hit.get(key),3):return "INVALID_PICK_MATERIAL_VECTOR"
			if not logical.get("collider_key") is String or logical.collider_key.is_empty() or not exact_integer(logical.get("collider_runtime_id"),1):return "INVALID_PICK_MATERIAL_ID"
			if not exact_integer(logical.get("shape")):return "INVALID_PICK_MATERIAL_SHAPE"
			for src:String in HIT_FIELDS:
				var dst:String=HIT_FIELDS[src]
				if not logical.has(src) or not hit.has(dst):return "PICK_MATERIAL_FIELD_MISSING"
				if logical[src]!=hit[dst]:return "PICK_MATERIAL_MISMATCH:"+src
			if hit.get("surface_material_id")!=logical.collider_key:return "PICK_MATERIAL_MISMATCH:surface_material_id"
		if reason=="SELECTED":
			if index!=rays.size()-1:return "PICK_QUERY_AFTER_WINNER"
			winner=logical
	if winner==null and rays.size()!=7:return "PICK_INCOMPLETE_MISS_RAYS"
	if not physical.get("selected") is bool or audit.get("winner")!=winner or physical.get("selected")!=(winner!=null):return "PICK_WINNER_MISMATCH"
	return ""

static func build_view(ticks:Array,sidecars:Array,session_id:String,completed:bool=true,expected_tick_count:int=-1,strict_new:bool=false)->Dictionary:
	if not completed:return _fail("INCOMPLETE_PICK_STREAM")
	if session_id.is_empty():return _fail("INVALID_PICK_STREAM_SCHEMA")
	if not _finite(ticks) or not _finite(sidecars):return _fail("PICK_NONFINITE")
	if expected_tick_count>=0 and ticks.size()!=expected_tick_count:return _fail("INCOMPLETE_PICK_STREAM")
	var view:Dictionary={"schema":SCHEMA,"session_id":session_id,"status":"PASS","reason":"","events":[],"dispatches":[],"sidecars":[],"logical_count":0,"dispatch_count":0,"ray_count":0,"suppressed_count":0}
	var physical_index:int=0
	for i in ticks.size():
		if not ticks[i] is Dictionary:return _fail("INVALID_PICK_STREAM_SCHEMA")
		var row:Dictionary=ticks[i]
		if not row.get("target",{}) is Dictionary:return _fail("INVALID_PICK_STREAM_SCHEMA")
		if not exact_integer(row.get("tick"),1):return _fail("INVALID_PICK_TICK")
		var tick:int=int(row.tick)
		if tick!=i+1:return _fail("INCOMPLETE_PICK_STREAM")
		var picks:Variant=row.get("target",{}).get("picks",[])
		if not picks is Array:return _fail("INVALID_PICK_STREAM_SCHEMA")
		var ordinal:int=0
		for event_index in picks.size():
			if not picks[event_index] is Dictionary:return _fail("UNKNOWN_LEGACY_EVENT")
			var pick:Dictionary=picks[event_index]
			if not exact_integer(pick.get("hand"),0,1):return _fail("INVALID_PICK_HAND")
			var hand:int=int(pick.hand)
			var event:Dictionary={"event_id":"%s:t%d:h%d:e%d"%[session_id,tick,hand,event_index],"tick":tick,"hand":hand,"logical_index":event_index}
			if pick.get("reason")=="INVALID_AIM_NO_NEW_TARGET" and not pick.has("audit"):
				event.merge({"kind":"PICK_SUPPRESSED","dispatched_world_queries":false,"dispatch_id":null,"reason":"INVALID_AIM_NO_NEW_TARGET"})
				view.suppressed_count+=1
			elif pick.get("audit") is Dictionary and not pick.has("reason"):
				var identity:String=dispatch_identity(session_id,tick,hand,ordinal)
				if physical_index>=sidecars.size():return _fail("MISSING_REAL_PICK_RECORDS")
				if not sidecars[physical_index] is Dictionary:return _fail("INVALID_PICK_SIDECAR")
				var real:Dictionary=sidecars[physical_index]
				if not exact_integer(real.get("tick"),1):return _fail("INVALID_PICK_TICK")
				if not exact_integer(real.get("hand"),0,1):return _fail("INVALID_PICK_HAND")
				if real.get("trial_id")!=session_id or real.tick!=tick or real.hand!=hand:return _fail("PICK_DISPATCH_IDENTITY_MISMATCH")
				if not exact_integer(real.get("pick_call_index")):return _fail("INVALID_PICK_CALL_INDEX")
				if real.pick_call_index!=physical_index:return _fail("DUPLICATE_OR_MISORDERED_PICK_SIDECAR")
				if strict_new and (not real.has("dispatch_identity") or not real.has("dispatch_ordinal")):return _fail("MISSING_DISPATCH_IDENTITY")
				if real.has("dispatch_identity") and real.dispatch_identity!=identity:return _fail("PICK_DISPATCH_IDENTITY_MISMATCH")
				if real.has("dispatch_ordinal") and (not exact_integer(real.dispatch_ordinal) or real.dispatch_ordinal!=ordinal):return _fail("PICK_DISPATCH_IDENTITY_MISMATCH")
				var audit_error:String=_audit(pick,real)
				if not audit_error.is_empty():return _fail(audit_error)
				var winner:Variant=pick.audit.get("winner")
				var outcome:String="SELECTED" if winner!=null else "MISS_OR_INELIGIBLE"
				view.dispatches.append({"kind":"PICK_DISPATCH","dispatch_id":identity,"tick":tick,"hand":hand,"ordinal":ordinal,"sidecar_index":physical_index,"original_pick_call_index":real.pick_call_index,"dispatched_world_queries":true,"ray_count":pick.audit.rays.size(),"winning_offset":winner.offset_px.duplicate() if winner!=null else null,"outcome":outcome})
				view.sidecars.append({"dispatch_id":identity,"sidecar_index":physical_index,"original_pick_call_index":real.pick_call_index})
				event.merge({"kind":"PICK_RESULT","dispatched_world_queries":true,"dispatch_id":identity,"outcome":outcome})
				view.ray_count+=pick.audit.rays.size();physical_index+=1;ordinal+=1
			else:return _fail("UNKNOWN_LEGACY_EVENT")
			view.events.append(event);view.logical_count+=1
	if physical_index!=sidecars.size():return _fail("ORPHAN_OR_DUPLICATE_PICK_SIDECAR")
	view.dispatch_count=physical_index
	return view
