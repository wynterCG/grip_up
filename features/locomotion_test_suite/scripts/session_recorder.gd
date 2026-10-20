extends RefCounted
## Explicit capture only; files stream to disk and the metric rings stay bounded.
const Metrics=preload("res://features/locomotion_test_suite/scripts/movement_metrics.gd")
var metrics=Metrics.new()
var active:=false
var directory:=""
var metadata:Dictionary={}
var _samples:FileAccess
var _events:FileAccess
var _last_write:=-1.0
var _rows:=0
var _max_rows:=100000
var _interval:=.05
var _started:=0.0
var _limits:Dictionary={}
var last_summary:Dictionary={}

static func serializable(value:Variant)->Variant:
	if value is Vector3 or value is Vector3i:return [value.x,value.y,value.z]
	if value is Vector2 or value is Vector2i:return [value.x,value.y]
	if value is Quaternion:return [value.x,value.y,value.z,value.w]
	if value is Basis:return [serializable(value.x),serializable(value.y),serializable(value.z)]
	if value is Transform3D:return {"origin":serializable(value.origin),"basis":serializable(value.basis)}
	if value is Array:
		var result:Array=[]
		for entry in value:result.append(serializable(entry))
		return result
	if value is Dictionary:
		var result:Dictionary={}
		for key in value:result[str(key)]=serializable(value[key])
		return result
	if value is float and not is_finite(value):return null
	if value==null or value is String or value is bool or value is int or value is float:return value
	return null

func begin(info:Dictionary,snapshot:Dictionary,direction:Vector3,options:Dictionary={})->bool:
	if active or info.get("source","") not in ["scripted","human","developer_exploratory"]:return false
	for key in ["scenario","variant","physics_hz","build_identity"]:
		if not info.has(key):return false
	var metric_options:Dictionary=options.duplicate(true)
	metric_options["physics_hz"]=int(info.physics_hz)
	if not metrics.start(snapshot,direction,metric_options):return false
	metadata=info.duplicate(true)
	_limits=options.duplicate(true)
	_interval=1.0/maxf(1.0,float(options.get("sample_hz",20.0)))
	_max_rows=clampi(int(options.get("max_rows",100000)),1,100000)
	_started=float(snapshot.time)
	_last_write=-1.0
	_rows=0
	directory="user://locomotion_v12/sessions/%s_%d"%[Time.get_datetime_string_from_system().replace(":","-").replace("T","_"),Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:return false
	_samples=FileAccess.open(directory+"/samples.jsonl",FileAccess.WRITE)
	_events=FileAccess.open(directory+"/events.jsonl",FileAccess.WRITE)
	if _samples==null or _events==null:
		_samples=null;_events=null
		return false
	active=true
	metadata["session_id"]=directory.get_file()
	FileAccess.open(directory+"/metadata.json",FileAccess.WRITE).store_string(JSON.stringify(serializable(metadata),"\t"))
	event({"type":"session_start","time":snapshot.time,"tick":snapshot.tick,"source":metadata.source})
	if snapshot.get("accepted_input") is Vector2 and Vector2(snapshot.accepted_input).length()>.001 and snapshot.get("accepted_input_time")!=null:
		var onset_time:float=snapshot.accepted_input_time
		var onset_tick:int=int(snapshot.tick)-int(round((float(snapshot.time)-onset_time)*float(metadata.physics_hz)))
		var onset_velocity:Variant=null
		if absf(float(snapshot.time)-onset_time)<.00001:onset_velocity=snapshot.get("velocity")
		event({"type":"command_onset","time":onset_time,"tick":onset_tick,"velocity":onset_velocity,"reason":"Coordinator accepted raw input timestamp; not hardware latency"})
	_write_sample(snapshot)
	return true

func _write_sample(snapshot:Dictionary)->void:
	if _rows>=_max_rows:return
	_samples.store_line(JSON.stringify(serializable(snapshot)))
	_last_write=float(snapshot.time)
	_rows+=1
	if _rows%20==0:_samples.flush()

func push(snapshot:Dictionary)->bool:
	if not active:return false
	var accepted:bool=metrics.push(snapshot)
	if accepted and float(snapshot.time)-_last_write>=_interval-.000001:_write_sample(snapshot)
	return accepted

func event(row:Dictionary)->void:
	if not active:return
	metrics.record_event(row)
	_events.store_line(JSON.stringify(serializable(row)))
	_events.flush()

func finish(completed:bool,reason:String,extra:Dictionary={})->Dictionary:
	if not active:return last_summary.duplicate(true)
	var data:Dictionary=metrics.finish()
	data.merge(metadata,true)
	data["schema_version"]="locomotion_v12_1"
	data["result"]={"completed":completed,"reason":reason,"duration_s":data.get("duration_s",0.0)}
	data["recording"]={"sample_hz":1.0/_interval,"physics_hz":metadata.physics_hz,"written_samples":_rows,"max_rows":_max_rows,"path":directory,"compression":"plain streaming JSONL; offline gzip available","truncated":_rows>=_max_rows}
	data["assessment"]={"confidence":"not_evaluated","human_ratings":null,"notes":"Automated metrics do not establish mastery or feel"}
	data.merge(extra,true)
	_samples.flush();_events.flush()
	_samples=null;_events=null
	active=false
	last_summary=data.duplicate(true)
	FileAccess.open(directory+"/summary.json",FileAccess.WRITE).store_string(JSON.stringify(serializable(data),"\t"))
	return last_summary.duplicate(true)
