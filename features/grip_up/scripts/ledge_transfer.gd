extends RefCounted
## Opt-in M6 feasibility candidate. Queries and a bounded reacted attitude request
## only: no contact creation, torso pose/velocity writes or independent force.
const MAX_TORQUE := 8.0
const TILT_STIFFNESS := 12.0
const TILT_DAMPING := 3.0
const TORQUE_SLEW := 40.0
const MAX_TILT := 0.959931 #55 degrees; never a kinematic lock.
var data:Dictionary={}
var torque:=Vector3.ZERO
var inward:=Vector3.ZERO
var active:=false

func reset()->void:
	data.clear()
	torque=Vector3.ZERO
	inward=Vector3.ZERO
	active=false

func _ray(body:RigidBody3D,a:Vector3,b:Vector3)->Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(a,b,body.collision_mask,[body.get_rid()])
	query.hit_from_inside=true
	return body.get_world_3d().direct_space_state.intersect_ray(query)

func _standing_clear(body:RigidBody3D,point:Vector3,normal:Vector3)->bool:
	# Destination occupancy is advisory, never authorization to move through the
	# lip. Every actual intermediate rigid-body collision remains in Jolt.
	var inward_axis:Vector3=-normal.slide(Vector3.UP).normalized()
	var basis:=Basis.looking_at(inward_axis,Vector3.UP)
	var pose:=Transform3D(basis,point+inward_axis*.45+Vector3.UP*.93)
	var found:=false
	for child in body.get_children():
		if not child is CollisionShape3D or child.disabled or child.shape==null:continue
		found=true
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=child.shape
		query.transform=pose*child.transform
		query.collision_mask=body.collision_mask
		query.exclude=[body.get_rid()]
		query.margin=.002
		if not body.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
	return found

func step(controller:Node,delta:float,enabled:bool)->void:
	active=false
	inward=Vector3.ZERO
	var body:RigidBody3D=controller.torso
	data={"enabled":enabled,"status":"DISABLED","reason":"FEATURE_DISABLED","path_clear":false,"destination_clear":false,"top_point":Vector3.ZERO,"top_normal":Vector3.ZERO,"requested_torque":Vector3.ZERO,"applied_torque":Vector3.ZERO,"physical_completion":false}
	if not enabled:
		torque=Vector3.ZERO
		return
	var ids:Array=[]
	for id in controller._attached_ids():
		if controller.hands[id].state=="ATTACHED":ids.append(id)
	var loaded_foot:=false
	if controller.feet_solver!=null:
		for foot in controller.feet_solver.feet:
			loaded_foot=loaded_foot or Vector3(foot.force).length()>1.0
	var supported:bool=ids.size()>=2 or ids.size()==1 and loaded_foot
	data.status="SEARCHING"
	data.reason="TWO_HANDS_OR_HAND_AND_LOADED_FOOT_REQUIRED"
	if not supported:
		torque=Vector3.ZERO
		return
	var selected:Dictionary={}
	for id in ids:
		var hand:Dictionary=controller.hands[id]
		var material:PhysicsBody3D=hand.anchor.support_body()
		var normal:Vector3=hand.anchor.world_normal().slide(Vector3.UP)
		if normal.length_squared()<.5:continue
		normal=normal.normalized()
		var anchor:Vector3=hand.anchor.world_point()
		var hit:=_ray(body,anchor-normal*.08+Vector3.UP*.28,anchor-normal*.08-Vector3.UP*.12)
		if hit.is_empty() or hit.collider!=material or Vector3(hit.normal).dot(Vector3.UP)<.85:continue
		# A real bearing patch behind the edge, not a narrow lip or imagined plane.
		var rear:=_ray(body,hit.position-normal*.35+Vector3.UP*.12,hit.position-normal*.35-Vector3.UP*.12)
		if rear.is_empty() or rear.collider!=material or Vector3(rear.normal).dot(Vector3.UP)<.85:continue
		if absf(rear.position.y-hit.position.y)>.025:continue
		selected={"support":material,"point":hit.position,"normal":normal,"top_normal":hit.normal}
		break
	if selected.is_empty():
		data.reason="NO_BEARING_TOP_ON_ACTUAL_GRIP_SUPPORT"
		torque=Vector3.ZERO
		return
	var clear:=_standing_clear(body,selected.point,selected.normal)
	data.merge({"support_id":selected.support.get_instance_id(),"top_point":selected.point,"top_normal":selected.top_normal,"inward":-selected.normal,"destination_clear":clear,"path_scope":"unknown continuous path; standing destination occupancy only, actual intermediate collisions remain authoritative"},true)
	var ground:Dictionary=controller.intent_locomotion.ground
	if ground.get("grounded",false) and int(ground.get("support_id",0))==selected.support.get_instance_id():
		data.status="GROUNDED_ON_TOP"
		data.reason="ACTUAL_GROUND_HANDOFF"
		data.physical_completion=true
		torque=Vector3.ZERO
		return
	var upward:float=maxf(0.0,controller.intent_locomotion.requested.y)
	if not clear or upward<=.01:
		data.status="BLOCKED" if not clear else "AVAILABLE"
		data.reason="TOP_DESTINATION_OCCUPIED" if not clear else "EXPLICIT_UPWARD_INPUT_REQUIRED"
		torque=torque.move_toward(Vector3.ZERO,TORQUE_SLEW*delta) if clear else Vector3.ZERO
		return
	inward=-selected.normal
	active=true
	var target_up:Vector3=Vector3.UP*cos(MAX_TILT)+inward*sin(MAX_TILT)
	var support_spin:=Vector3.ZERO
	if selected.support is RigidBody3D:support_spin=selected.support.angular_velocity
	var spin:Vector3=body.angular_velocity-support_spin
	var pitch_axis:Vector3=Vector3.UP.cross(inward).normalized()
	var requested:Vector3=(body.global_basis.y.normalized().cross(target_up)*TILT_STIFFNESS-pitch_axis*spin.dot(pitch_axis)*TILT_DAMPING).limit_length(MAX_TORQUE)*upward
	var engagement:=0.0
	for id in ids:engagement+=smoothstep(0.0,maxf(.001,controller.tuning.grip_blend_duration),controller.hands[id].blend_elapsed)/ids.size()
	torque=torque.move_toward(requested*engagement,TORQUE_SLEW*delta)
	data.status="ATTEMPTING"
	data.reason="FINITE_ARM_TRACTION_AND_REACTED_TILT_ONLY"
	data.requested_torque=torque
	data.torque_cap=MAX_TORQUE
	data.requested_target_up=target_up
	data.physical_completion=false
