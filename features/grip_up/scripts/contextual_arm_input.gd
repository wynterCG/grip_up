extends RefCounted
## Relative anatomical hand aims; supported effort is transient, never pixel length.
const Targeting = preload("res://features/grip_up/scripts/grip_targeting.gd")
var sensitivity := 0.0018
var effort_speed := 700.0
var offsets: Array[Vector2] = [Vector2(0,.35),Vector2(0,.35)]
var states: Array[String] = ["FREE","FREE"]
var pending := Vector2.ZERO
var effort := Vector2.ZERO
var targeting = Targeting.new()

func reset() -> void:
	offsets=[Vector2(0,.35),Vector2(0,.35)]
	states=["FREE","FREE"]
	clear_motion()

func clear_motion() -> void:
	pending=Vector2.ZERO
	effort=Vector2.ZERO

func frame(camera: Camera3D) -> Basis:
	var right := camera.global_basis.x.slide(Vector3.UP).normalized()
	if right.length_squared()<.5:right=Vector3.RIGHT
	return Basis(right,Vector3.UP,right.cross(Vector3.UP))

func synchronize(controller: Node,camera: Camera3D) -> void:
	var axes := frame(camera)
	for id in 2:
		var state: String=controller.get_hand_state(id)
		if state in ["FREE","RELEASED"] and states[id] in ["ATTACHED","SLIPPING","REACHING"]:
			var relative: Vector3=controller.get_hand_world(id)-controller.get_shoulder_world(id)
			offsets[id]=Vector2(relative.dot(axes.x),relative.y)
		states[id]=state
		clamp_aim(id,controller)

func clamp_aim(id: int,controller: Node) -> void:
	var reach: float=controller.get_max_reach()
	var depth: float=reach*.35
	offsets[id]=offsets[id].limit_length(sqrt(reach*reach-depth*depth))

func capture_motion(raw: Vector2,controller: Node,camera: Camera3D) -> void:
	if not raw.is_finite():return
	synchronize(controller,camera)
	for id in 2:
		if controller.get_hand_state(id) in ["FREE","RELEASED"]:
			offsets[id]+=Vector2(raw.x,-raw.y)*sensitivity
			clamp_aim(id,controller)
	if not controller._attached_ids().is_empty():
		pending+=raw

func target(id: int,controller: Node,camera: Camera3D) -> Vector3:
	clamp_aim(id,controller)
	var axes := frame(camera)
	return controller.get_shoulder_world(id)+axes.x*offsets[id].x+Vector3.UP*offsets[id].y-axes.z*controller.get_max_reach()*.35

func candidate(id: int,controller: Node,camera: Camera3D) -> Dictionary:
	var hit: Dictionary=targeting.candidate(camera,camera.unproject_position(target(id,controller,camera)),controller.torso)
	if not hit.is_empty() and controller.get_shoulder_world(id).distance_to(hit.position)>controller.get_max_reach()+.00001:
		return {}
	return hit

func consume_effort(delta: float) -> Vector2:
	effort=(pending/(maxf(.0001,delta)*effort_speed)).limit_length(1.0)
	pending=Vector2.ZERO
	return effort

func diagnostics() -> Dictionary:
	return {"offsets":[[offsets[0].x,offsets[0].y],[offsets[1].x,offsets[1].y]],"pending":[pending.x,pending.y],"effort":[effort.x,effort.y],"sensitivity":sensitivity}
