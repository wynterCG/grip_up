extends RefCounted
## One selected material point per held button. No retargeting or automatic retry.
var held: Array[bool] = [false,false]
var entries: Array[Dictionary] = [{},{}]

func press(controller: Node, id: int, support: PhysicsBody3D, point: Vector3, normal: Vector3) -> bool:
	held[id] = true
	if controller.get_hand_state(id) in ["ATTACHED","SLIPPING","REACHING"]:
		return true
	var ok: bool = controller.request_buffered_grip(id,support,point,normal)
	if ok:
		entries[id] = {"anchor":controller.hands[id].anchor,"input_time":controller.simulation_time}
	return ok

func release(controller: Node, id: int) -> void:
	held[id] = false
	if not entries[id].is_empty() and controller.get_hand_state(id)=="REACHING" and controller.hands[id].anchor==entries[id].anchor:
		controller.release_grip(id,"input_released")
	entries[id].clear()

func update(controller: Node) -> void:
	for id in 2:
		if not entries[id].is_empty() and (not held[id] or controller.get_hand_state(id)!="REACHING" or controller.hands[id].anchor!=entries[id].anchor):
			entries[id].clear()

func clear(controller: Node) -> void:
	for id in 2:
		release(controller,id)
