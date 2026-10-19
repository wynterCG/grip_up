extends RefCounted
## Read-only route scoring. Does not select contacts, retry or move the body.
var next_contact := 0
var transfers := 0
var recoveries := 0
var previous_hand := -1
var pending_hand := -1
var events: Array[Dictionary]=[]

func attached(controller: Node,id: int) -> bool:
	return id>=0 and controller.get_hand_state(id) in ["ATTACHED","SLIPPING"]

func update(controller: Node,points: Array[Vector3],time: float) -> void:
	if points.is_empty() or next_contact>=points.size():return
	if previous_hand>=0 and not attached(controller,previous_hand) and not attached(controller,pending_hand):
		recoveries+=1
		events.append({"time":time,"code":"ROUTE_INTERRUPTED","contact":next_contact})
		next_contact=0
		transfers=0
		previous_hand=-1
		pending_hand=-1
	if pending_hand>=0:
		if not attached(controller,pending_hand):pending_hand=-1
		elif not attached(controller,previous_hand):
			transfers+=1
			previous_hand=pending_hand
			pending_hand=-1
			next_contact+=1
			events.append({"time":time,"code":"TRANSFER_COMPLETE","transfer":transfers})
		return
	var hand: int=next_contact%2
	if not attached(controller,hand):return
	if Vector3(controller.hands[hand].anchor_world).distance_to(points[next_contact])>.085:return
	if previous_hand<0:
		previous_hand=hand
		next_contact+=1
		events.append({"time":time,"code":"ROUTE_STARTED"})
	elif hand!=previous_hand:
		pending_hand=hand

func diagnostics() -> Dictionary:
	return {"next_contact":next_contact,"transfers":transfers,"recoveries":recoveries,"pending_hand":pending_hand,"events":events.duplicate(true)}
