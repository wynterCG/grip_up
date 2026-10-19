extends "res://features/grip_up/tests/test_pending_grip.gd"
## M2 physical motion/obstruction gate. No new-branch attachment is enabled.
const PendingTarget = preload("res://features/grip_up/scripts/pending_grip_target.gd")
var motion_report: Dictionary = {}

class MotionOnlyController:
	extends "res://features/grip_up/scripts/climbing_controller.gd"
	func _try_held_contact(_id: int) -> void:
		pass # Isolate the historical M2 motion gate after M3 becomes available.

func setup(definition: Dictionary, enabled: bool) -> void:
	await super.setup(definition,enabled)
	var original = controller
	var fixture_hands: Array[Dictionary] = original.hands.duplicate(true)
	var fixture_tuning: Resource = original.tuning
	world.remove_child(original)
	original.queue_free()
	controller = MotionOnlyController.new()
	world.add_child(controller)
	controller.configure(body,fixture_tuning)
	controller.hands = fixture_hands

func enable_pending() -> void:
	controller.set_control_profile(3)
	controller.tuning.allow_out_of_reach_grip_targets = true

func body_transport() -> void:
	await setup({"label":"natural_shoulder_transport","velocity":Vector3(.25,.3,0),"spin":Vector3(.12,.16,-.10),"offset_y":1.30},false)
	enable_pending()
	controller.request_held_grip(0,support,anchor.world_point(),anchor.world_normal())
	var observer: Dictionary = {"frame":controller._held_targets[0].previous_frame,"endpoint":controller.get_hand_world(0),"max_error":0.0,"max_transport":0.0,"max_gesture":0.0,"valid":true,"samples":0}
	var callback := func(_delta: float):
		var data: Dictionary = controller.pending_diagnostics(0)
		if not data.active:return
		var frame: Transform3D = controller._held_targets[0].previous_frame
		var carried: Vector3 = frame*(Transform3D(observer.frame).affine_inverse()*Vector3(observer.endpoint))
		var expected := (carried-Vector3(observer.endpoint))/_delta
		observer.max_error = maxf(observer.max_error,expected.distance_to(data.transport_velocity))
		observer.max_transport = maxf(observer.max_transport,data.transport_speed)
		observer.max_gesture = maxf(observer.max_gesture,data.gesture_speed)
		observer.valid = observer.valid and data.endpoint_valid and data.workspace_valid and data.gesture_speed<=4.0002 and Vector3(data.hand_world).distance_to(data.shoulder_world)<=controller.get_max_reach()+.00005
		observer.frame = frame
		observer.endpoint = data.hand_world
		observer.samples += 1
	controller.sample_ready.connect(callback)
	await ticks(int(.6*hz))
	controller.sample_ready.disconnect(callback)
	check(observer.samples>hz*.5 and observer.max_transport>.1,"actual rigid-body translation/rotation transports the shoulder workspace")
	check(observer.valid and observer.max_error<.0001,"transport exactly uses actual successive physical shoulder frames and gesture remains finite/anatomical")
	check(controller.get_hand_state(0)=="REACHING" and controller.get_arm_force(0)==Vector3.ZERO and controller._attached_ids().is_empty(),"natural shoulder transport creates no premature grip, effort or effective support")
	motion_report.transport = observer.duplicate(true)
	await clear()

func approach_into_range() -> void:
	await setup({"label":"naturally_approach","velocity":Vector3.UP*.9,"offset_y":1.0},false)
	enable_pending()
	controller.transfer_diagnostics_enabled = true
	controller.record_unselected_attempt(1,"no_surface")
	controller.request_held_grip(0,support,anchor.world_point(),anchor.world_normal())
	var first: Dictionary = controller.pending_diagnostics(0)
	check(first.distance>controller.get_max_reach() and first.attempt_id==controller.transfer_journal.last_by_hand[0].attempt_id and first.target_selection_id!=first.attempt_id,"selection ID is distinct from the real journal attempt ID after prior attempts")
	var entered := false
	var closest := INF
	var finite := true
	for frame in int(1.2*hz):
		await tick()
		var data: Dictionary = controller.pending_diagnostics(0)
		entered = entered or data.get("physical_in_reach",false)
		closest = minf(closest,Vector3(data.hand_world).distance_to(data.target_world))
		finite = finite and data.active and data.endpoint_valid and data.gesture_speed<=4.0002 and data.local_point==first.local_point and data.selected_time==first.selected_time
	check(entered and controller.pending_diagnostics(0).transition_count>=1,"natural incoming body velocity brings the same selected point into current reach")
	check(finite and closest<.001 and controller.get_hand_state(0)=="REACHING" and controller.metrics.attaches==0,"one uninterrupted held gesture reaches the exact point finitely, with attachment still disabled at M2")
	check(controller.transfer_journal.last_by_hand[0].primary_failure=="","reversible pending transitions never poison the attempt as an old reach failure")
	motion_report.approach = {"closest":closest,"data":controller.pending_diagnostics(0)}
	await clear()

func translating_support() -> void:
	await setup({"label":"material_translation","moving":true,"target_velocity":Vector3.DOWN*.6,"offset_y":1.0},false)
	enable_pending()
	controller.request_held_grip(0,support,anchor.world_point(),anchor.world_normal())
	var first: Dictionary = controller.pending_diagnostics(0)
	var consistent := true
	var entered := false
	var max_speed := 0.0
	var minimum_gap := INF
	var published: Dictionary = {"consistent":true,"contact_candidate":false}
	var capture := func(_delta: float):
		var data: Dictionary = controller.pending_diagnostics(0)
		published.consistent = published.consistent and data.active and data.local_point==first.local_point and Vector3(data.target_world).is_equal_approx(controller.hands[0].anchor.world_point())
		if Vector3(data.hand_world).distance_to(data.target_world)<=.000001:
			published.contact_candidate = published.contact_candidate or controller.capture_evaluator.evaluate(controller,0).accepted
	controller.sample_ready.connect(capture)
	for frame in int(1.1*hz):
		await tick()
		var data: Dictionary = controller.pending_diagnostics(0)
		consistent = consistent and data.active and data.endpoint_valid and data.local_point==first.local_point
		entered = entered or data.physical_in_reach
		max_speed = maxf(max_speed,data.gesture_speed)
		minimum_gap = minf(minimum_gap,Vector3(data.hand_world).distance_to(data.target_world))
	controller.sample_ready.disconnect(capture)
	check(first.distance>controller.get_max_reach() and entered,"a real translating dynamic support brings its selected material point into reach")
	check(consistent and published.consistent and published.contact_candidate and max_speed<=4.0002 and minimum_gap<.001,"translating point remains material-local and finite hand arrival passes actual contact evaluator without attaching")
	check(controller.get_arm_force(0)==Vector3.ZERO and controller.hands[0].reaction_force==Vector3.ZERO and controller.metrics.attaches==0,"moving support receives no precontact reaction or fabricated attachment")
	motion_report.translation = {"closest":minimum_gap,"max_gesture":max_speed,"final":controller.pending_diagnostics(0)}
	await clear()

func hinged_support() -> void:
	await setup({"label":"hinged_material_point","moving":true,"target_velocity":Vector3(-.48,.2,0),"target_spin":Vector3(0,0,-.8),"offset_x":.8,"offset_y":.1},false)
	var pivot := StaticBody3D.new()
	pivot.position = support.to_global(Vector3(0,.6,0))
	world.add_child(pivot)
	var hinge := HingeJoint3D.new()
	hinge.position = pivot.position
	world.add_child(hinge)
	hinge.node_a = hinge.get_path_to(pivot)
	hinge.node_b = hinge.get_path_to(support)
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT,false)
	enable_pending()
	controller.request_held_grip(0,support,anchor.world_point(),anchor.world_normal())
	var first: Dictionary = controller.pending_diagnostics(0)
	var consistent := true
	var entered := false
	var max_error := 0.0
	var max_spin := 0.0
	var published: Dictionary = {"max_error":0.0,"normal":true,"contact_candidate":false,"closest":INF}
	var capture := func(_delta: float):
		var data: Dictionary = controller.pending_diagnostics(0)
		if data.active:
			published.max_error = maxf(published.max_error,Vector3(data.target_world).distance_to(controller.hands[0].anchor.world_point()))
			published.normal = published.normal and Vector3(data.normal_world).is_equal_approx(controller.hands[0].anchor.world_normal())
			published.closest = minf(published.closest,Vector3(data.hand_world).distance_to(data.target_world))
			if Vector3(data.hand_world).distance_to(data.target_world)<=.000001:
				published.contact_candidate = published.contact_candidate or controller.capture_evaluator.evaluate(controller,0).accepted
	controller.sample_ready.connect(capture)
	for frame in int(1.3*hz):
		await tick()
		var data: Dictionary = controller.pending_diagnostics(0)
		consistent = consistent and data.active and data.endpoint_valid and data.local_point==first.local_point and data.gesture_speed<=4.0002
		entered = entered or data.get("physical_in_reach",false)
		max_spin = maxf(max_spin,support.angular_velocity.length())
	controller.sample_ready.disconnect(capture)
	max_error = published.max_error
	check(first.distance>controller.get_max_reach() and entered and max_spin>.2,"real Jolt hinge rotation brings an initially distant point into reach")
	check(consistent and max_error<.00001 and published.normal and published.contact_candidate,"rotating target keeps exact local position/normal and reaches real contact finitely, without retargeting/attachment")
	check(controller.get_hand_state(0)=="REACHING" and controller.get_arm_force(0)==Vector3.ZERO,"hinge motion alone never authorizes an early physical grip")
	motion_report.hinge = {"initial":first,"final":controller.pending_diagnostics(0),"spin_peak":max_spin,"position_error":max_error,"closest_hand_distance":published.closest,"contact_candidate_valid":published.contact_candidate}
	await clear()

func obstruct_and_reopen() -> void:
	await setup({"label":"temporary_obstruction"},false)
	body.collision_mask = 0 # Hand-path isolation fixture; obstacles still ray-queryable.
	enable_pending()
	controller.transfer_diagnostics_enabled = true
	controller.request_held_grip(0,support,anchor.world_point(),anchor.world_normal())
	var first: Dictionary = controller.pending_diagnostics(0)
	await ticks(maxi(1,int(.04*hz)))
	var blocker := StaticBody3D.new()
	blocker.position = controller.get_shoulder_world(0).lerp(anchor.world_point(),.5)
	blocker.collision_layer = 2
	var solid := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2,2,.03)
	solid.shape = box
	blocker.add_child(solid)
	world.add_child(blocker)
	var never_crossed := true
	for frame in int(1.0*hz):
		await tick()
		never_crossed = never_crossed and controller.get_hand_world(0).z>=blocker.position.z+.015-.0002
	var obstructed: Dictionary = controller.pending_diagnostics(0)
	check(obstructed.active and obstructed.blocked and obstructed.blocker_id==blocker.get_instance_id() and obstructed.pending_time>.9,"temporary occluder pauses the same held attempt beyond legacy timeout")
	check(never_crossed and controller.get_arm_force(0)==Vector3.ZERO,"full swept path cannot tunnel through the temporary occluder")
	blocker.queue_free()
	await ticks(int(.6*hz))
	var opened: Dictionary = controller.pending_diagnostics(0)
	check(opened.active and not opened.blocked and opened.local_point==first.local_point and opened.selected_time==first.selected_time and opened.hand_world.distance_to(opened.target_world)<.001,"removing obstruction resumes finite approach to the original point without new click or reset")
	var codes: Array = controller.transfer_journal.events.map(func(event):return event.code)
	check("HAND_PATH_BLOCKED" in codes and "HAND_PATH_CLEAR" in codes and controller.transfer_journal.last_by_hand[0].primary_failure=="","blocked/clear are observations, not permanent transfer failures")
	await clear()

func label_hysteresis() -> void:
	var reach: float = Profile.new().max_reach_length
	await setup({"label":"hysteresis_geometry","offset_y":sqrt((reach+.001)*(reach+.001)-.35*.35)},false)
	var initial := Transform3D(body.global_basis,controller.get_shoulder_world(0))
	var target = PendingTarget.new()
	target.configure(anchor,initial,initial.origin,0,1,reach)
	var axis: Vector3 = (anchor.world_point()-initial.origin).normalized()
	var endpoint := initial.origin
	for index in 12:
		var frame := initial
		frame.origin += axis*(.0015 if index%2==0 else -.0015)
		endpoint = target.step(body,frame,endpoint,reach,4,controller.tuning.allowed_grip_surface_mask,index/float(hz),1.0/hz,.045,.18,.003)
	check(target.snapshot.transition_count==0 and target.snapshot.physical_transition_count>=10,"3mm hysteresis prevents label chatter while physical reach eligibility still changes exactly")
	var inward := initial
	inward.origin += axis*.006
	endpoint = target.step(body,inward,endpoint,reach,4,controller.tuning.allowed_grip_surface_mask,1,1.0/hz,.045,.18,.003)
	var marginal := initial
	marginal.origin -= axis*.001
	target.step(body,marginal,endpoint,reach,4,controller.tuning.allowed_grip_surface_mask,2,1.0/hz,.045,.18,.003)
	check(target.snapshot.label_in_reach and not target.snapshot.physical_in_reach and target.snapshot.transition_count==1,"a retained reachable label never inflates actual physical contact range")
	await clear()

func released_surface_departure() -> void:
	await setup({"label":"wall_departure"},false)
	controller.set_control_profile(3)
	controller.request_grip(0,support,anchor.world_point(),anchor.world_normal())
	await ticks(int(.5*hz))
	check(controller.get_hand_state(0)=="ATTACHED","departure fixture first establishes a real existing surface grip")
	controller.release_grip(0)
	controller.tuning.allow_out_of_reach_grip_targets = true
	var point: Vector3 = anchor.world_point()+Vector3(.12,.1,0)
	controller.request_held_grip(0,support,point,Vector3.BACK)
	var starts_outward: bool = controller._held_targets[0].phase=="DEPARTURE"
	var finite := true
	var never_inside := true
	for frame in int(.5*hz):
		await tick()
		var data: Dictionary = controller.pending_diagnostics(0)
		finite = finite and data.active and data.endpoint_valid and data.gesture_speed<=4.0002
		never_inside = never_inside and controller.get_hand_world(0).z>=point.z-.00005
	check(starts_outward and finite and never_inside,"released wall point gets a finite outward-normal departure instead of an inside-solid bypass")
	check(controller.get_hand_world(0).distance_to(point)<.001 and controller.get_hand_state(0)=="REACHING","departure then normal approach reaches the exact new material point without attachment at M2")
	await clear()

func rounded_free_departure() -> void:
	await setup({"label":"rounded_free_hand"},false)
	# Initial authored hand endpoint is outside a sphere flank by25mm; it is
	# inside anatomy, but its diagonal toward the selected front cuts the hold.
	support.queue_free()
	await ticks(2)
	var sphere_body := StaticBody3D.new()
	var point: Vector3 = controller.get_shoulder_world(0)+Vector3(0,.1,-.35)
	sphere_body.position = point-Vector3.BACK*.12
	sphere_body.collision_layer = 2
	sphere_body.set_meta("grippable",true)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .12
	shape.shape = sphere
	sphere_body.add_child(shape)
	world.add_child(sphere_body)
	await ticks(2)
	controller.hands[0].hand_world = sphere_body.position+Vector3.RIGHT*.145
	enable_pending()
	controller.request_held_grip(0,sphere_body,point,Vector3.BACK)
	var finite := true
	var outside := true
	var folded := false
	for frame in int(.7*hz):
		await tick()
		var data: Dictionary = controller.pending_diagnostics(0)
		finite = finite and data.active and data.endpoint_valid and data.gesture_speed<=4.0002
		outside = outside and Vector3(data.hand_world).distance_to(sphere_body.position)>=.12-.00005
		folded = folded or data.phase=="RETRACT"
	check(finite and outside and folded,"rounded presurface hand first retracts along a clear swept route without penetrating the flank")
	check(controller.get_hand_world(0).distance_to(point)<.001 and controller.get_arm_force(0)==Vector3.ZERO,"rounded hold front is reached finitely without stale hand_path_obstructed cancellation or effort")
	await clear()

func auto_com_evidence() -> void:
	await setup({"label":"auto_com_angular_velocity","moving":true,"target_spin":Vector3(0,0,1),"offset_y":1.2},false)
	var shape: CollisionShape3D = support.get_child(0)
	shape.position = Vector3(.30,.12,-.08)
	support.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_AUTO
	await ticks(3)
	await controller.sample_ready
	var state := PhysicsServer3D.body_get_direct_state(support.get_rid())
	var center: Vector3 = support.global_position+state.center_of_mass
	var point: Vector3 = support.to_global(shape.position+Vector3.BACK*.05)
	var normal: Vector3 = support.global_basis*Vector3.BACK
	var legacy_anchor = Anchor.new(support,point,normal)
	var expected: Vector3 = support.linear_velocity+support.angular_velocity.cross(point-center)
	var error: float = legacy_anchor.point_velocity().distance_to(expected)
	check(state.center_of_mass.length()>.1 and error>.1,"real asymmetric AUTO-COM body demonstrates legacy angular material-point velocity error")
	print("PENDING_AUTO_COM ",JSON.stringify({"hz":hz,"actual_com":center,"property_com":support.global_transform*support.center_of_mass,"point_velocity_error":error,"spin":support.angular_velocity}))
	enable_pending()
	controller.request_held_grip(0,support,point,normal)
	var selected_anchor = controller.hands[0].anchor
	var legacy_expression: Vector3 = support.linear_velocity+support.angular_velocity.cross(point-support.global_transform*support.center_of_mass)
	check(selected_anchor.use_actual_center_of_mass and selected_anchor.point_velocity().distance_to(expected)<.000001 and not legacy_anchor.use_actual_center_of_mass and legacy_anchor.point_velocity()==legacy_expression,"only new held anchor uses actual AUTO COM; legacy angular-velocity expression remains exactly unchanged")
	var observed: Dictionary = {"error":INF}
	var capture := func(_delta: float):
		var actual := PhysicsServer3D.body_get_direct_state(support.get_rid())
		var data: Dictionary = controller.pending_diagnostics(0)
		var velocity: Vector3 = support.linear_velocity+support.angular_velocity.cross(Vector3(data.target_world)-(support.global_position+actual.center_of_mass))
		observed.error = Vector3(data.target_velocity).distance_to(velocity)
	controller.sample_ready.connect(capture,CONNECT_ONE_SHOT)
	await ticks(2)
	check(observed.error<.000001,"pending material-point telemetry agrees with actual rotating AUTO-COM body at the same physical sample")
	motion_report.auto_com = {"legacy_error":error,"actual_com":center,"property_com":support.global_transform*support.center_of_mass}
	await clear()

func impossible_intersection() -> void:
	await distant(true)
	var point: Vector3 = anchor.world_point()
	controller.request_held_grip(0,support,point,anchor.world_normal())
	await ticks(int(.3*hz))
	var old_endpoint: Vector3 = controller.get_hand_world(0)
	var target = controller._held_targets[0]
	var blocker := StaticBody3D.new()
	blocker.position = old_endpoint+Vector3.RIGHT*.4
	blocker.collision_layer = 2
	var solid := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.03,4,4)
	solid.shape = box
	blocker.add_child(solid)
	world.add_child(blocker)
	await tick()
	# Explicit analytic adversarial frame fixture; no live torso is moved.
	var impossible: Transform3D = target.previous_frame
	impossible.origin += Vector3.RIGHT*2.0
	var returned: Vector3 = target.step(body,impossible,old_endpoint,controller.get_max_reach(),4,controller.tuning.allowed_grip_surface_mask,controller.simulation_time,1.0/hz,.045,.18,.003)
	check(not target.snapshot.endpoint_valid and target.snapshot.reason=="WORKSPACE_SWEEP_CONFLICT" and returned==old_endpoint,"impossible finite-workspace intersection reports invalid historical sample instead of a clamp/snap")
	# Seed the previous gesture frame as the adversarial fixture for the actual
	# controller callback: the physical body pose/velocities remain untouched.
	var pose := body.global_transform
	var velocity := body.linear_velocity
	controller._update_hand(0,1.0/hz)
	var invalid: Dictionary = controller.pending_diagnostics(0)
	check(not invalid.active and not invalid.endpoint_valid and invalid.reason=="WORKSPACE_SWEEP_CONFLICT" and controller.hands[0].anchor==null,"controller explicitly cancels impossible segment with no anchor and a persistent invalid-pose diagnostic")
	check(body.global_transform==pose and body.linear_velocity==velocity and controller.get_arm_force(0)==Vector3.ZERO,"impossible-case cancellation never writes torso pose/velocity or adds effort")
	await ticks(int(.3*hz))
	check(controller.get_hand_state(0)=="FREE" and controller.pending_diagnostics(0).endpoint_valid,"passive finite FREE recovery restores endpoint validity only upon actual workspace reentry")
	await clear()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	await body_transport()
	await approach_into_range()
	await translating_support()
	await hinged_support()
	await obstruct_and_reopen()
	await label_hysteresis()
	await released_surface_departure()
	await rounded_free_departure()
	await impossible_intersection()
	await auto_com_evidence()
	check(no_early_force and budgets,"every M2 sample remains zero preattachment effort and within original360N/150Nm budgets")
	var file := FileAccess.open("res://builds/pending_grip_m2_%dhz.json" % hz,FileAccess.WRITE)
	file.store_string(JSON.stringify({"hz":hz,"checks":checks,"failures":failures,"scope":"M2 motion only, attachment remains disabled","report":motion_report},"\t"))
	print("PENDING MOTION RESULTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
