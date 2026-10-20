extends "res://features/grip_up/tests/test_intent_reversal.gd"
## Scripted mechanical probes; no gameplay edits or post-setup velocity writes.
const FootSolver=preload("res://features/grip_up/scripts/foot_contact_solver.gd")
const FootProfile=preload("res://features/grip_up/resources/foot_tuning.gd")
const FIXTURES="res://features/locomotion_test_suite/resources/technical_fixtures_r1.json"
var fixtures:Dictionary={}
var foot_rows:Array=[]
var swing_rows:Array=[]
var foot_invariants:=true
var foot_gesture:=true

func vec(values:Array)->Vector3:return Vector3(float(values[0]),float(values[1]),float(values[2]))

func foot_box(at:Vector3,tilt:float,size:Vector3)->StaticBody3D:
	var material:=StaticBody3D.new()
	material.position=at;material.rotation.z=tilt;material.collision_layer=1
	var surface:=PhysicsMaterial.new();surface.friction=.85;material.physics_material_override=surface
	var shape:=BoxShape3D.new();shape.size=size
	var col:=CollisionShape3D.new();col.shape=shape;material.add_child(col)
	world.add_child(material)
	return material

func foot_trial(definition:Dictionary,mirror_sign:int,mode:int)->Dictionary:
	var geometry:String=definition.id
	await physics_frame
	body=RigidBody3D.new();body.position=vec(fixtures.body.spawn);body.mass=12;body.gravity_scale=0;body.inertia=Vector3.ONE*3
	body.rotation.y=float(fixtures.body.mirrored_yaw_rad) if mirror_sign<0 else 0.0
	body.can_sleep=false;body.collision_layer=4;body.collision_mask=1
	body.linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE;body.angular_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp=0;body.angular_damp=0
	var sphere:=SphereShape3D.new();sphere.radius=float(fixtures.body.collision.radius)
	var collision:=CollisionShape3D.new();collision.shape=sphere;body.add_child(collision);world.add_child(body)
	var solver=FootSolver.new()
	var settings=FootProfile.new()
	var hips:Array[Vector3]=[Vector3.ZERO]
	var rest:Array[Vector3]=[Vector3(0,-.75,0)]
	var lengths:Array[float]=[.83]
	var clearances:Array[float]=[.10]
	solver.configure(body,settings,hips,rest,lengths,clearances)
	solver.intent_aware_selection=mode==2
	var intent:=Vector3.LEFT*mirror_sign
	solver.selection_intent=intent
	var tilt:float=float(definition.candidate_tilt_z_rad)*mirror_sign
	for center:Array in definition.candidate_centers_base:
		# Retain the original double-precision authoring calculation before
		# casting into Vector3, avoiding a new float32 rounding step in slope Y.
		var x:float=float(center[0])
		foot_box(Vector3(x,float(center[1])+tan(tilt)*x,float(center[2])),tilt,vec(definition.candidate_box_size))
	for frame in int(.7*hz):
		await physics_frame
		var old:Vector3=solver.feet[0].ankle
		solver.prepare(1.0/hz,0,0,0,mode!=0)
		foot_gesture=foot_gesture and old.distance_to(solver.feet[0].ankle)<=settings.plant_speed/hz+.00001
	var selected:Vector3=solver.feet[0].contact_point
	check(mode==0 or solver.feet[0].state=="SUPPORTING","T05 %s mirror%d B%d earns finite current support before effort"%[geometry,mirror_sign,mode])
	var start:Vector3=body.position
	var work:=0.0
	var peak:=0.0
	var loaded:=0
	var normal:=Vector3.ZERO
	for frame in int(.25*hz):
		await physics_frame
		var pose:Transform3D=body.global_transform
		var velocity:Vector3=body.linear_velocity
		var spin:Vector3=body.angular_velocity
		var entries:Array=solver.prepare(1.0/hz,1,0,0,mode!=0)
		foot_invariants=foot_invariants and body.global_transform==pose and body.linear_velocity==velocity and body.angular_velocity==spin
		solver.commit(1.0)
		var foot:Dictionary=solver.feet[0]
		var force:Vector3=foot.force
		normal=foot.normal
		peak=maxf(peak,force.length())
		var n:float=force.dot(normal)
		foot_invariants=foot_invariants and n>=-.00001 and (force-normal*n).length()<=.85*n+.00001 and force.length()<=120.001
		if force.length()>1:
			loaded+=1
			work+=force.dot(FootSolver.point_velocity(body,foot.contact_point)-FootSolver.point_velocity(foot.support,foot.contact_point))/hz
		if foot.state not in ["SUPPORTING","SLIDING"]:foot_invariants=foot_invariants and force.length()<.00001
	var progress:float=(body.position-start).dot(intent)
	var row:Dictionary={"geometry":geometry,"mirror":mirror_sign,"mode":"B%d"%mode,"direction":intent,"selected_point":selected,"last_normal":normal,"signed_progress":progress,"outcome":"MOVEMENT_AGAINST_INTENT" if progress<-.000001 else "MOVEMENT_WITH_INTENT" if progress>.000001 else "NO_MEASURED_MOVEMENT","displacement":body.position-start,"relative_partial_work_j":work,"peak_force_n":peak,"loaded_samples":loaded,"selection":solver.candidate_selection(),"scope":"isolated massless foot; tiny sphere body, zero gravity, fixed supports; not full biped gameplay"}
	check((mode==0 and peak==0) or (mode!=0 and peak>1 and loaded>0),"T05 %s mirror%d B%d motion is accompanied by real admitted load only when enabled"%[geometry,mirror_sign,mode])
	foot_rows.append(row)
	await clear()
	return row

func feet_matrix()->void:
	for definition:Dictionary in fixtures.geometries:
		var geometry:String=definition.id
		var original:Dictionary={}
		var mirrored:Dictionary={}
		for sign_value in [1,-1]:
			for mode in [0,1,2]:
				var row:Dictionary=await foot_trial(definition,sign_value,mode)
				if sign_value==1:original[mode]=row
				else:mirrored[mode]=row
		for mode in [0,1,2]:
			check(absf(original[mode].signed_progress-mirrored[mode].signed_progress)<.0001,"FEET_02 %s B%d mirrored geometry/body/input preserves corresponding signed result"%[geometry,mode])
		if geometry=="flat":check(original[2].signed_progress>0 and mirrored[2].signed_progress>0,"T05 flat B2 selected supports actually push both mirrored bodies in the indicated direction")
		else:check(original[2].signed_progress<0 and mirrored[2].signed_progress<0,"T05 known inclined B2 adverse result is preserved: loaded motion AGAINST intent, not a locomotion success")
	check(foot_invariants and foot_gesture,"T05 all normal variants preserve finite feet, read-only prepare, friction cone and unchanged effort limit")

func swing_trial(mode:String)->Dictionary:
	await prepare(false)
	# Equal initial motion is earned through the existing controller, never assigned.
	for frame in int(.6*hz):await sample(Vector2(1,0))
	var start_spin:Vector3=body.angular_velocity
	var work:=0.0
	var positive:=0.0
	var negative:=0.0
	var peak_energy:=0.0
	var peak_torque:=0.0
	var retained:=true
	var tail_coast:=0.0
	var final_torque:=0.0
	var coast_requested_zero:=true
	var peak_angle:=0.0
	var peak_pendulum_speed:=0.0
	var phase_counts:Dictionary={"PUMPING":0,"BRAKING":0,"NEUTRAL":0}
	var duration:float=8.0 if mode=="constant_held" else 2.0
	for frame in int(duration*hz):
		var lever:Vector3=controller.get_shoulder_world(0)-body.global_position
		var axis:Vector3=Vector3.RIGHT.cross(lever.normalized()).normalized()
		var phase:float=body.angular_velocity.dot(axis)
		var command:float=0.0
		if mode=="pump":command=signf(phase) if absf(phase)>.03 else 1.0
		elif mode=="brake":command=-signf(phase) if absf(phase)>.03 else 0.0
		elif mode=="constant_held":command=1.0
		var state:Dictionary=await sample(Vector2(command,0))
		var motion:Dictionary=controller.transfer_diagnostics().motion
		var power:float=motion.swing_power
		work+=power/hz;positive+=maxf(0.0,power)/hz;negative+=minf(0.0,power)/hz
		peak_torque=maxf(peak_torque,Vector3(state.swing_torque).length())
		final_torque=Vector3(state.swing_torque).length()
		peak_angle=maxf(peak_angle,float(motion.get("pendulum_angle",0.0)))
		peak_pendulum_speed=maxf(peak_pendulum_speed,Vector3(motion.get("pendulum_angular_velocity",Vector3.ZERO)).length())
		peak_energy=maxf(peak_energy,float(motion.relative_translation_energy)+float(motion.relative_rotation_energy))
		phase_counts[motion.swing_phase]+=1
		retained=retained and controller.get_hand_state(0)=="ATTACHED"
		if mode=="coast":
			coast_requested_zero=coast_requested_zero and controller.intent_locomotion.requested==Vector2.ZERO
			if frame>=hz:tail_coast=maxf(tail_coast,Vector3(state.swing_torque).length())
	var result:Dictionary={"mode":mode,"duration_s":duration,"earned_initial_spin":start_spin,"incremental_swing_work_j":work,"positive_work_j":positive,"negative_work_j":negative,"peak_relative_kinetic_energy_proxy_j":peak_energy,"peak_pendulum_angle_rad":peak_angle,"peak_pendulum_angular_speed_rad_s":peak_pendulum_speed,"peak_incremental_swing_torque_nm":peak_torque,"neutral_tail_torque_nm":tail_coast,"final_incremental_torque_nm":final_torque,"neutral_request_zero":coast_requested_zero,"retained":retained,"phases":phase_counts,"scope":"scripted reactive phase policy, no anticipation; torque work is incremental after common assist cap, not total actuator energy"}
	check(retained and budgets and is_finite(work) and peak_torque<=20.001,"T06 %s uses real retained support, finite signed work and 360/20/150 caps"%mode)
	if mode=="coast":check(coast_requested_zero and final_torque<.0001,"T06 raw neutral request remains ZERO and existing filters decay to negligible effort, without autonomous brake command")
	else:check(positive>0 or negative<0,"T06 %s exercises measured torque work rather than a diagnostic-only phase"%mode)
	swing_rows.append(result)
	await clear()
	return result

func run()->void:
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURES))
	if not parsed is Dictionary or parsed.get("revision")!=1 or parsed.get("schema_version")!="technical_fixtures_v12_1":
		push_error("Technical fixture schema/revision must be technical_fixtures_v12_1 / 1")
		quit(1);return
	fixtures=parsed
	if fixtures.body.collision.type!="sphere" or fixtures.geometries.size()!=2 or fixtures.geometries[0].id!="flat" or fixtures.geometries[1].id!="slope" or fixtures.geometries.any(func(item):return item.height_rule!="base_y_plus_tan_tilt_times_x"):
		push_error("Unsupported technical geometry definition")
		quit(1);return
	world=Node3D.new();root.add_child(world)
	await feet_matrix()
	for mode in ["pump","coast","brake","constant_held"]:await swing_trial(mode)
	# Existing matched free-pair fixture and actual unsupported release checks.
	await safety_and_reaction()
	var output:Dictionary={"schema":"measurement_physics_v12_1","physics_hz":hz,"checks":checks,"failures":failures,"source":"scripted_mechanical_probes","feet":foot_rows,"swing":swing_rows,"reaction":report.get("reaction",{}),"decisions":{"B2":"REVISE_local_inclined_candidate_moves_against_intent; global_benefit_unproven","B2_benefit_gate_met":false,"brake":"measured_signed_work_not_assumed_success","default_promotion":false},"initial_conditions":"fixture initialization only; all swing motion earned through finite support/controller forces"}
	output.merge({"fixture_path":FIXTURES,"fixture_revision":fixtures.revision,"fixture_sha256":FileAccess.get_sha256(FIXTURES),"outcome_changes_expected":false},true)
	FileAccess.open("res://builds/measurement_physics_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("MEASUREMENT PHYSICS RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
