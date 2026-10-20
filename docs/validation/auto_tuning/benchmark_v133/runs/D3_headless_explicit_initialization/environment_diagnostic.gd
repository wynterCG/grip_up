extends SceneTree
class Clock extends Node:
	signal sample(delta:float)
	func _physics_process(delta:float)->void:sample.emit(delta)
func snap()->Dictionary:
	return {"size":[root.size.x,root.size.y],"mode":root.mode,"position":[root.position.x,root.position.y],"screen":root.current_screen,"visible_size":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"content_scale_size":[root.content_scale_size.x,root.content_scale_size.y],"content_scale_mode":root.content_scale_mode,"content_scale_aspect":root.content_scale_aspect,"display_server":DisplayServer.get_name()}
func _initialize()->void:run.call_deferred()
func run()->void:
	var before:=snap()
	var initialized:=true
	if initialized:root.size=Vector2i(1024,576)
	Engine.physics_ticks_per_second=120
	var clock:=Clock.new();root.add_child(clock)
	var samples:Array=[];var streak:=0
	for i in 12:
		var delta:float=await clock.sample
		samples.append(delta);streak=streak+1 if absf(delta-1.0/120)<.0000001 else 0
		if streak>=2:break
	var result={"scope":"ENVIRONMENT_DIAGNOSTIC_NOT_QUALIFICATION","before":before,"after":snap(),"explicit_size_initialization":initialized,"clock_samples":samples,"clock_settled":streak>=2,"gameplay_bodies_created":0,"physics_outcomes":0}
	var file:=FileAccess.open("C:/Users/Wynter/grip_up/builds/eval_virtual_cursor/benchmark_v133_r1/attempts/D3_headless_explicit_initialization/result.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"",true,true));file.close()
	quit(0)
