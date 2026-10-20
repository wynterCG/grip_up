extends RefCounted
## Trial-local bounded JSONL. Disk output is independent of gameplay decisions.
const Serializer=preload("res://features/locomotion_test_suite/scripts/session_recorder.gd")
var enabled:=true
var trace:FileAccess
var events:FileAccess
var directory:=""
var error:=""
var rows:=0
var event_rows:=0
var dropped_rows:=0
var counts:Dictionary={}
const MAX_ROWS_PER_SCENARIO=10240
const MAX_EVENTS=32768
func open_at(path:String,on:bool)->bool:
	enabled=on;directory=path
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:error="OUTPUT_DIRECTORY";return false
	for file in ["trace.jsonl","events.jsonl","trace.jsonl.tmp","events.jsonl.tmp","initial_state.json"]:
		if FileAccess.file_exists(directory.path_join(file)):error="OUTPUT_EXISTS";return false
	if enabled:
		trace=FileAccess.open(directory.path_join("trace.jsonl.tmp"),FileAccess.WRITE)
		events=FileAccess.open(directory.path_join("events.jsonl.tmp"),FileAccess.WRITE)
		if trace==null or events==null:error="OUTPUT_OPEN_FAILED";return false
	return true
func sample(row:Dictionary)->void:
	if not enabled or trace==null:return
	var id:String=str(row.scenario_id)
	if int(counts.get(id,0))>=MAX_ROWS_PER_SCENARIO:dropped_rows+=1;return
	counts[id]=int(counts.get(id,0))+1;rows+=1
	trace.store_line(JSON.stringify(Serializer.serializable(row)))
func event(row:Dictionary)->void:
	if not enabled or events==null:return
	if event_rows>=MAX_EVENTS:dropped_rows+=1;return
	event_rows+=1;events.store_line(JSON.stringify(Serializer.serializable(row)))
func close()->Dictionary:
	if enabled:
		if trace!=null:trace.flush();trace.close();trace=null
		if events!=null:events.flush();events.close();events=null
		for name in ["trace.jsonl","events.jsonl"]:
			if FileAccess.file_exists(directory.path_join(name+".tmp")):
				if DirAccess.rename_absolute(directory.path_join(name+".tmp"),directory.path_join(name))!=OK:error="OUTPUT_RENAME_FAILED"
	return {"enabled":enabled,"trace_rows":rows,"event_rows":event_rows,"dropped_rows":dropped_rows,"error":error,"phase_scope":"pre_control before application callbacks; post_control after existing application callbacks and before next integration; neither is falsely labelled post-solver"}
static func atomic_json(path:String,value:Dictionary)->bool:
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(Serializer.serializable(value),"\t"));file.flush();file.close()
	return DirAccess.rename_absolute(path+".tmp",path)==OK
