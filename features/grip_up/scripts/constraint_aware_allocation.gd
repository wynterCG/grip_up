extends RefCounted
## A1 local heuristic, not a force allocator or a forward contact simulation.
## Only attenuates prospective contraction. Existing extension, rate/acceleration
## limits, capture, spring, force/moment budgets and reaction paths stay authoritative.
const Actuator=preload("res://features/grip_up/scripts/arm_actuator.gd")
var _memory:Dictionary={}
var data:Dictionary={}

func reset()->void:
	_memory.clear()
	data.clear()

func evaluate(controller:Node, ids:Array[int], body_step:Vector3, direction:Vector3, delta:float)->Dictionary:
	var changes:Dictionary={}
	var source:Dictionary={}
	var weights:Dictionary={}
	var rows:Dictionary={}
	var tuning:Resource=controller.tuning
	var body:RigidBody3D=controller.torso
	var center:Vector3=body.global_transform*body.center_of_mass
	var trunk:Vector3=((controller.get_shoulder_world(0)+controller.get_shoulder_world(1))*.5-center).normalized()
	var command:Vector3=direction.normalized() if direction.length_squared()>.000001 else Vector3.ZERO
	var current_twist:=0.0
	var predicted_twist:=0.0
	var pulling:Array[int]=[]
	for id in ids:
		var hand:Dictionary=controller.hands[id]
		if hand.state!="ATTACHED" or hand.anchor==null or not hand.anchor.is_valid() or controller.is_palm_hand(id):continue
		var shoulder:Vector3=controller.get_shoulder_world(id)
		var separation:Vector3=hand.anchor_world-shoulder
		var length:float=separation.length()
		var axis:Vector3=separation/maxf(length,.000001)
		var change:float=(shoulder+body_step).distance_to(hand.anchor_world)-hand.actual_length
		var alignment:float=axis.dot(command)
		var current_load:float=Vector3(hand.force).length()
		var material_limit:float=maxf(1.0,float(hand.anchor.support_body().get_meta("grip_load_limit",tuning.grip_force_limit)))
		var margin:float=clampf((material_limit-current_load)/material_limit,0.0,1.0)
		# A negative length delta can only pull along +axis. Positive deltas
		# relieve tension; do not suppress lowering or claim that it is pushing.
		var weight:=1.0
		if change<-.000001:
			weight=clampf((alignment-.02)/.35,0.0,1.0)*clampf(margin/.35,0.0,1.0)
			pulling.append(id)
		var lever:Vector3=shoulder-center
		var allocation:float=maxf(.001,float(hand.allocation))
		var stiffness:float=tuning.arm_stiffness*allocation
		var damping:float=tuning.arm_damping*allocation
		var inverse_mass:float=Actuator.inverse_effective_mass(body,shoulder,axis)
		var support:PhysicsBody3D=hand.anchor.support_body()
		if support is RigidBody3D:inverse_mass+=Actuator.inverse_effective_mass(support,hand.anchor_world,-axis)
		var sensitivity:float=stiffness/(1.0+(damping*delta+stiffness*delta*delta)*inverse_mass)
		var increment:float=maxf(0.0,-change)*sensitivity*weight
		var twist:float=lever.cross(axis*increment).dot(trunk)
		current_twist+=lever.cross(Vector3(hand.force)).dot(trunk)
		predicted_twist+=twist
		source[id]=change
		weights[id]=weight
		rows[id]={"alignment":alignment,"load":current_load,"material_limit":material_limit,"remaining_load_fraction":margin,"incremental_twist":twist,"unscaled_incremental_twist":lever.cross(axis*maxf(0.0,-change)*sensitivity).dot(trunk),"force_sensitivity":sensitivity,"anchor_id":hand.anchor.get_instance_id(),"support_id":support.get_instance_id()}
	# With two opposing axial moment arms, reduce only the incremental pull
	# which worsens net trunk twist. Never manufacture counter-torque, amplify
	# the other arm or cancel natural one-hand pendular rotation.
	if pulling.size()==2:
		var a:int=pulling[0]
		var b:int=pulling[1]
		if float(rows[a].incremental_twist)*float(rows[b].incremental_twist)<-.000001:
			# Existing load is already balanced by the physical body/attitude
			# system. Do not mistake that support moment for a new input error.
			var total:float=predicted_twist
			for id in pulling:
				var moment:float=rows[id].incremental_twist
				if moment*total>0:
					weights[id]*=1.0-clampf(absf(total)/maxf(absf(moment),.000001),0.0,.75)
	var predicted_after:=0.0
	var unscaled_before:=0.0
	var contractions:=0
	var extensions:=0
	for id in source:
		var hand:Dictionary=controller.hands[id]
		var change:float=source[id]
		var raw_weight:float=weights[id]
		if not _memory.has(id) or _memory[id].anchor!=hand.anchor:_memory[id]={"anchor":hand.anchor,"scale":1.0}
		if change<-.000001:
			# Finite allocation response, then the unchanged target acceleration
			# limiter. No displacement or force is integrated in this helper.
			_memory[id].scale=lerpf(float(_memory[id].scale),raw_weight,1.0-exp(-delta/.08))
			changes[id]=change*float(_memory[id].scale)
			contractions+=1
		else:
			changes[id]=change
			if change>.000001:extensions+=1
		weights[id]=float(_memory[id].scale) if change<-.000001 else 1.0
		unscaled_before+=float(rows[id].unscaled_incremental_twist)
		predicted_after+=float(rows[id].unscaled_incremental_twist)*float(weights[id])
	for id in _memory.keys():
		if not source.has(id):_memory.erase(id)
	var reason:="NO_SUPPORT" if source.is_empty() else "HOLD" if body_step.length_squared()<.00000001 else "RELAXATION_ONLY" if contractions==0 and extensions>0 else "GEOMETRY_LOAD_TWIST_HEURISTIC"
	var saturated:bool=float(controller.telemetry().get("total_force",0.0))>tuning.total_pull_force_budget*.94 or float(controller.telemetry().get("budget_scale",1.0))<.90
	var partial:bool=extensions>0 or weights.values().any(func(value):return float(value)<.95)
	var classification:="NO_SUPPORT" if source.is_empty() else "SATURATED" if saturated else "PARTIALLY_ACTUATABLE" if partial else "AVAILABLE"
	data={"variant":1,"label":"A1_GEOMETRY_LOAD","reason":reason,"advisory_classification":classification,"collision_assessed":false,"source_changes":source,"changes":changes,"weights":weights,"contacts":rows,"current_trunk_moment":current_twist,"predicted_incremental_twist_before":unscaled_before,"predicted_incremental_twist_after":predicted_after,"authority":"bounded_existing_arm_targets_only","prediction_scope":"local_axial_sensitivity; not a collision or capture guarantee"}
	return data
