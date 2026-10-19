extends RefCounted
## Scores broad regions from actual contacts; never requests movement or grips.
var stage:=0
var recoveries:=0
var stable_time:=0.0
var completed:=false
var started:=false
var started_at:=-1.0
var finished_at:=-1.0
var events:Array[Dictionary]=[]

func update(controller:Node,grounded:bool,zones:Array[Dictionary],time:float,delta:float) -> void:
	if completed or zones.is_empty():return
	var attached:Array=[]
	for hand in controller.hands:
		if hand.state=="ATTACHED" and hand.anchor!=null and hand.anchor.is_valid():attached.append(hand)
	if started and attached.is_empty():
		recoveries+=1
		stage=0
		stable_time=0
		started=false
		started_at=-1
		events.append({"time":time,"code":"ROUTE_INTERRUPTED"})
	if not started and not attached.is_empty():
		started=true
		started_at=time
	var zone:Dictionary=zones[stage]
	var bounds:AABB=zone.bounds
	var valid:bool=not attached.is_empty() and controller.torso.global_position.y>=float(zone.min_body_y)
	if zone.get("suspended",false):
		valid=valid and not grounded
		if controller.feet_solver!=null:
			var foot_load:=0.0
			for foot in controller.feet_solver.feet:
				foot_load+=Vector3(foot.force).length()
			valid=valid and foot_load<=1.0
	valid=valid and attached.any(func(hand):return bounds.has_point(hand.anchor.world_point()) and (not zone.has("support") or hand.anchor.support_body()==zone.support))
	stable_time=stable_time+delta if valid else 0.0
	if stable_time<.2:return
	events.append({"time":time,"code":"ROUTE_STAGE_COMPLETE","stage":stage,"label":zone.label})
	stage+=1
	stable_time=0
	if stage>=zones.size():
		completed=true
		finished_at=time

func diagnostics() -> Dictionary:
	return {"stage":stage,"recoveries":recoveries,"completed":completed,"started":started,"elapsed":finished_at-started_at if completed else -1.0,"events":events.duplicate(true)}
