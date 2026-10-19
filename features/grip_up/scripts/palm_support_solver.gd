extends RefCounted
## P-A: finite-area virtual palm, ONE purely axial compression link per hand.
## Applies nothing itself. The controller's existing360N/20Nm/150Nm allocator
## admits the force and applies its collinear shoulder/material reaction pair.
const Mechanics=preload("res://features/grip_up/scripts/foot_contact_solver.gd")
const HALF_WIDTH:=.035
const HALF_LENGTH:=.050
const NORMAL_UP_MIN:=.85
const CONTACT_TOLERANCE:=.003
const SLIP_CONFIRM:=.10
var records:Dictionary={}
var enabled:=false

func reset()->void:
	records.clear()
	enabled=false

func release(id:int)->void:
	records.erase(id)

func is_palm(id:int)->bool:
	return enabled and records.has(id)

func _ray(body:RigidBody3D,from:Vector3,to:Vector3,mask:int)->Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(from,to,mask,[body.get_rid()])
	query.hit_from_inside=true
	return body.get_world_3d().direct_space_state.intersect_ray(query)

func _footprint(controller:Node,id:int,record:Dictionary)->String:
	var hand:Dictionary=controller.hands[id]
	var material:PhysicsBody3D=hand.anchor.support_body()
	if not is_instance_valid(material) or not material is StaticBody3D and not material is RigidBody3D:return "PALM_SUPPORT_INVALID"
	if not material.get_meta("palm_support",true):return "PALM_SURFACE_DISABLED"
	if material.collision_layer & controller.tuning.allowed_grip_surface_mask==0:return "PALM_SUPPORT_INVALID"
	var point:Vector3=hand.anchor.world_point()
	var normal:Vector3=hand.anchor.world_normal()
	if normal.dot(Vector3.UP)<NORMAL_UP_MIN:return "PALM_NORMAL_INVALID"
	var shoulder:Vector3=controller.get_shoulder_world(id)
	if shoulder.distance_to(point)>controller.get_max_reach()+.00005:return "PALM_OUT_OF_REACH"
	if Vector3(hand.hand_world).distance_to(point)>.001:return "PALM_HAND_NOT_ARRIVED"
	var right:Vector3=(material.global_basis*record.local_right).slide(normal).normalized()
	if right.length_squared()<.5:return "PALM_FRAME_INVALID"
	var forward:Vector3=normal.cross(right).normalized()
	for x in [-1.0,0.0,1.0]:
		for z in [-1.0,0.0,1.0]:
			var sample:Vector3=point+right*(x*HALF_WIDTH)+forward*(z*HALF_LENGTH)
			var hit:=_ray(controller.torso,sample+normal*.018,sample-normal*.012,controller.tuning.allowed_grip_surface_mask)
			if hit.is_empty() or hit.collider!=material or Vector3(hit.normal).dot(normal)<.98 or Vector3(hit.position).distance_to(sample)>CONTACT_TOLERANCE:return "PALM_FOOTPRINT_INSUFFICIENT"
	# Finite air-side palm volume must not intersect a raised wall/obstruction.
	# This is a virtual contact; no second physical palm body duplicates Jolt.
	var shape:=BoxShape3D.new()
	shape.size=Vector3(HALF_WIDTH*2,.012,HALF_LENGTH*2)
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform=Transform3D(Basis(right,normal,right.cross(normal)),point+normal*.010)
	query.collision_mask=controller.tuning.allowed_grip_surface_mask
	query.exclude=[controller.torso.get_rid()]
	query.margin=0
	if not controller.torso.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return "PALM_PLACEMENT_OBSTRUCTED"
	# Shoulder below a top cannot load compression; it is not made adhesive.
	# LOS is required when the shoulder is on the usable side. A wrong-side
	# hand stays unloaded until other actual supports improve the geometry.
	if normal.dot(shoulder-point)>.003:
		var hit:=_ray(controller.torso,shoulder,point+(point-shoulder).normalized()*.002,controller.tuning.allowed_grip_surface_mask)
		if hit.is_empty() or hit.collider!=material or Vector3(hit.position).distance_to(point)>CONTACT_TOLERANCE:return "PALM_SHOULDER_PATH_BLOCKED"
	return ""

func prepare(controller:Node,delta:float,active:bool)->void:
	enabled=active
	if not active:
		records.clear()
		for hand in controller.hands:
			hand.erase("contact_mode")
			hand.erase("palm")
		return
	for id in controller.hands.size():
		var hand:Dictionary=controller.hands[id]
		if hand.state not in ["ATTACHED","SLIPPING"] or hand.anchor==null or not hand.anchor.is_valid():
			records.erase(id)
			hand.contact_mode="REPOSITIONING" if hand.state=="REACHING" else "FREE"
			hand["palm"]={"valid":false,"requested_force":Vector3.ZERO,"applied_force":Vector3.ZERO,"reason":"NO_ACTUAL_CONTACT"}
			continue
		if not records.has(id) and hand.anchor.world_normal().dot(Vector3.UP)<NORMAL_UP_MIN:
			hand.contact_mode="GRIP_TRACTION"
			hand.erase("palm")
			continue
		if not records.has(id) or records[id].anchor!=hand.anchor:
			var material:PhysicsBody3D=hand.anchor.support_body()
			var right:Vector3=controller.torso.global_basis.x.slide(hand.anchor.world_normal()).normalized()
			var length:float=controller.get_shoulder_world(id).distance_to(hand.anchor.world_point())
			hand.rest_length=clampf(length,controller.tuning.min_arm_length,controller.tuning.max_arm_length)
			records[id]={"anchor":hand.anchor,"local_right":material.global_basis.inverse()*right,"hold":hand.rest_length,"velocity":0.0,"command_direction":0,"reference_actual":length,"reference_hold":hand.rest_length,"blend_elapsed":0.0,"slip_elapsed":0.0,"overload_elapsed":0.0,"valid":false,"force":Vector3.ZERO,"applied_force":Vector3.ZERO,"reason":"PALM_ACQUIRING","previous_actual":length,"stall":0.0}
		var record:Dictionary=records[id]
		var failure:=_footprint(controller,id,record)
		if failure!="":
			hand["palm"]={"valid":false,"requested_force":Vector3.ZERO,"applied_force":Vector3.ZERO,"reason":failure}
			controller.release_grip(id,failure)
			continue
		record.valid=true
		record.applied_force=Vector3.ZERO
		record.force=Vector3.ZERO
		record.blend_elapsed+=delta
		hand.contact_mode="PALM_CONTACT"
		var normal:Vector3=hand.anchor.world_normal()
		var length:float=controller.get_shoulder_world(id).distance_to(hand.anchor.world_point())
		var press:float=clampf(controller.intent_locomotion.requested.y,-1,1)
		var direction:=int(signf(press)) if absf(press)>.001 else 0
		if direction!=int(record.command_direction):
			record.command_direction=direction
			record.reference_actual=length
			record.reference_hold=record.hold
		if direction!=0:
			var achieved:float=record.reference_hold+length-record.reference_actual
			record.hold=maxf(record.hold,achieved) if direction>0 else minf(record.hold,achieved)
		var settings:Resource=controller.tuning
		record.hold=clampf(record.hold,settings.min_arm_length,settings.max_arm_length)
		var goal:float=record.hold+press*settings.traversal_max_target_offset
		# No integration of unachieved press. The virtual extension remaining
		# beyond current geometry is bounded even against an immovable ceiling.
		goal=clampf(goal,length-settings.traversal_max_target_offset,length+settings.traversal_max_target_offset)
		goal=clampf(goal,settings.min_arm_length,settings.max_arm_length)
		var progress:float=absf(length-float(record.previous_actual))/maxf(.000001,delta)
		record.stall=record.stall+delta if hand.rest_length-length>settings.traversal_tracking_tolerance and progress<.01 else 0.0
		record.previous_actual=length
		if record.stall>settings.traversal_stall_confirm_s and goal>hand.rest_length:goal=hand.rest_length
		var error:float=goal-hand.rest_length
		var desired:float=signf(error)*minf(settings.traversal_target_max_rate,maxf(0.0,sqrt(2*settings.traversal_target_max_acceleration*absf(error))-settings.traversal_target_max_acceleration*delta))
		var previous:float=record.velocity
		record.velocity=move_toward(previous,desired,settings.traversal_target_max_acceleration*delta)
		hand.rest_length=clampf(hand.rest_length+record.velocity*delta,settings.min_arm_length,settings.max_arm_length)
		record.target_rate=record.velocity
		record.target_acceleration=(record.velocity-previous)/delta
		record.goal=goal
		hand.palm=record.duplicate(true)

func evaluate(controller:Node,id:int,stiffness:float,damping:float,delta:float,engagement:float)->Dictionary:
	var hand:Dictionary=controller.hands[id]
	var record:Dictionary=records[id]
	var point:Vector3=hand.anchor.world_point()
	var shoulder:Vector3=controller.get_shoulder_world(id)
	var separation:Vector3=shoulder-point
	var length:float=separation.length()
	var axis:Vector3=separation/maxf(.000001,length)
	var normal:Vector3=hand.anchor.world_normal()
	var cosine:float=axis.dot(normal)
	var material:PhysicsBody3D=hand.anchor.support_body()
	var friction:=.85
	if material.physics_material_override!=null:friction=maxf(0.0,material.physics_material_override.friction)
	var tangent_ratio:float=axis.slide(normal).length()
	var allowed:bool=cosine>.003 and tangent_ratio<=friction*cosine+.0001
	var raw:=0.0
	var reason:="PALM_UNLOADED"
	var slip:=false
	if cosine<=.003:
		reason="PALM_UNFAVORABLE_SHOULDER_SIDE"
	elif not allowed:
		reason="PALM_AXIAL_FORCE_OUTSIDE_FRICTION_CONE"
		slip=true
	else:
		var speed:float=(Mechanics.point_velocity(controller.torso,shoulder)-hand.anchor.point_velocity()).dot(axis)
		var inverse:float=Mechanics.inverse_mass(controller.torso,shoulder,axis)
		if material is RigidBody3D:inverse+=Mechanics.inverse_mass(material,point,axis)
		var error:float=clampf(hand.rest_length-length,-controller.tuning.max_length_error,controller.tuning.max_length_error)
		if error>=-.002:
			raw=maxf(0.0,(stiffness*maxf(0.0,error)-damping*speed)/(1+(damping*delta+stiffness*delta*delta)*inverse))
			reason="PALM_AXIAL_COMPRESSION" if raw>0 else "PALM_UNLOADED"
	var blend:float=minf(engagement,smoothstep(0.0,maxf(.001,controller.tuning.grip_blend_duration),record.blend_elapsed))
	var limit:float=maxf(0.0,float(material.get_meta("palm_load_limit",controller.tuning.grip_force_limit)))
	var force:Vector3=axis*minf(raw,controller.tuning.max_force_per_arm)*blend if allowed else Vector3.ZERO
	record.overload_elapsed=record.overload_elapsed+delta if raw*blend>limit else maxf(0,record.overload_elapsed-2*delta)
	record.slip_elapsed=record.slip_elapsed+delta if slip else 0.0
	if slip or record.overload_elapsed>=controller.tuning.overload_confirm_time:
		hand.contact_mode="PALM_SLIPPING"
		force=Vector3.ZERO
		reason="PALM_CAPACITY_EXCEEDED" if not slip else reason
	record.force=force
	record.reason=reason
	record.normal_force=maxf(0.0,force.dot(normal))
	record.tangent_force=force.slide(normal)
	record.friction=friction
	record.tangent_limit=friction*record.normal_force
	record.raw_compression=raw*blend
	record.normal=normal
	record.point=point
	record.shoulder=shoulder
	record.axis=axis
	record.length=length
	record.effective_support=force.length()>.01
	hand.palm=record.duplicate(true)
	return {"force":force,"axis":axis,"raw":raw*blend,"release_reason":reason if record.slip_elapsed>=SLIP_CONFIRM or record.overload_elapsed>=controller.tuning.overload_confirm_time+controller.tuning.slip_duration else ""}

func admitted(controller:Node,id:int,force:Vector3)->void:
	if not records.has(id):return
	var record:Dictionary=records[id]
	record.applied_force=force
	record.applied_normal=maxf(0.0,force.dot(record.get("normal",Vector3.UP)))
	record.applied_tangent=force.slide(record.get("normal",Vector3.UP))
	record.body_offset=controller.get_shoulder_world(id)-controller.torso.global_position
	record.support_offset=controller.hands[id].anchor.world_point()-controller.hands[id].anchor.support_body().global_position
	record.reaction_force=-force
	record.pair_wrench_residual=(record.shoulder-record.point).cross(force)
	controller.hands[id].palm=record.duplicate(true)

func diagnostics()->Dictionary:
	var contacts:Dictionary={}
	for id in records:
		var snapshot:Dictionary=records[id].duplicate(true)
		snapshot.erase("anchor")
		contacts[id]=snapshot
	return {"enabled":enabled,"architecture":"P-A_AXIAL","footprint":Vector2(HALF_WIDTH*2,HALF_LENGTH*2),"hands":contacts}
