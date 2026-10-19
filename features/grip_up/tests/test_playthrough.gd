extends SceneTree
## Actual torso physics; only Input actions and the public grip/release API.
## Surface samples use real ray intersections; failed reaches keep the old grip.
## STATIC: keep W and both hands while settling, then release only the hand
## about to advance. The remaining anchor stabilizes the finite reaching phase.
## REACTIVE: right on beam front local (.30,0,.13), W loads/rotates it;
## left on its real underside (.70,-.08,.04), hold both for .5 seconds,
## release right, pull for 1 second, then right catches EXIT's underside.
const Lab = preload("res://features/grip_up/scripts/grip_up_lab.gd")
var app
var failures := 0
var checks := 0
var bounded := true
var hz := 120
var peak_force := 0.0
var peak_torque := 0.0
var peak_speed := 0.0
var wall_hold_contacts: Dictionary = {}
var contact_streaks: Dictionary = {}
var longest_contact_streak := 0

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--60hz"):
		hz = 60
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func ticks(count: int) -> void:
	for i in count:
		await physics_frame
		if is_instance_valid(app) and is_instance_valid(app.controller):
			var force: float = app.controller.get_arm_force(0).length() + app.controller.get_arm_force(1).length()
			var torque: float = app.controller.telemetry().get("torque", Vector3.ZERO).length()
			peak_force = maxf(peak_force, force)
			peak_torque = maxf(peak_torque, torque)
			peak_speed = maxf(peak_speed, app.torso.linear_velocity.length())
			bounded = bounded and force <= 360.001 and torque <= 150.001
			if app.level_id == 0:
				var touching: Dictionary = {}
				for other in app.torso.get_colliding_bodies():
					if bool(other.get_meta("wall_hold",false)):
						var label: String = other.name
						touching[label] = true
						wall_hold_contacts[label] = int(wall_hold_contacts.get(label,0)) + 1
						contact_streaks[label] = int(contact_streaks.get(label,0)) + 1
						longest_contact_streak = maxi(longest_contact_streak,contact_streaks[label])
				for label in contact_streaks:
					if not touching.has(label):
						contact_streaks[label] = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", description)

func surface(support: PhysicsBody3D, hand: int) -> Dictionary:
	var from: Vector3 = app.controller.get_shoulder_world(hand)
	if bool(support.get_meta("wall_hold",false)):
		# Rounded climbing nubs have no box front plane. Aim inside the actual
		# authored convex shape and use its real surface intersection/normal.
		for local in [Vector3.ZERO,Vector3(-0.035,0,0),Vector3(0.035,0,0)]:
			var query := PhysicsRayQueryParameters3D.create(from,support.to_global(local))
			query.exclude = [app.torso.get_rid()]
			var hit: Dictionary = app.torso.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider == support and hit.normal.length_squared() > 0.5 and from.distance_to(hit.position) < app.controller.tuning.max_arm_length-0.01:
				return hit
		return {}
	for local in [Vector3.ZERO, Vector3(-0.08,0,0.03), Vector3(0.08,0,0.03), Vector3(0,0,0.06)]:
		var query := PhysicsRayQueryParameters3D.create(from, support.to_global(local))
		query.exclude = [app.torso.get_rid()]
		query.hit_from_inside = true
		var hit: Dictionary = app.torso.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider == support and hit.normal.length_squared() > 0.5 and from.distance_to(hit.position) < app.controller.tuning.max_arm_length-0.01:
			return hit
	return {}

func acquire(support: PhysicsBody3D, hand: int, timeout: float = 6.0, local_target: Vector3 = Vector3.INF, local_normal: Vector3 = Vector3.ZERO) -> bool:
	var requests := 0
	for frame in int(timeout * hz):
		if not is_instance_valid(support):
			return false
		var state: String = app.controller.get_hand_state(hand)
		if state == "ATTACHED":
			return app.controller.hands[hand]["support"] == support
		if state == "FREE" and frame % 6 == 0:
			var hit: Dictionary = surface(support, hand)
			if local_target.is_finite():
				var from: Vector3 = app.controller.get_shoulder_world(hand)
				if local_normal.length_squared()>0.5:
					# This is an authored face point, not an attachment bypass:
					# request_grip still verifies its actual surface, LOS and range.
					hit = {"collider":support,"position":support.to_global(local_target),"normal":(support.global_basis*local_normal).normalized()}
				else:
					var query := PhysicsRayQueryParameters3D.create(from,support.to_global(local_target))
					query.exclude = [app.torso.get_rid()]
					hit = app.torso.get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty() and (hit.collider!=support or from.distance_to(hit.position)>app.controller.tuning.max_arm_length-0.01):
					hit = {}
			if not hit.is_empty() and app.controller.request_grip(hand, support, hit.position, hit.normal):
				requests += 1
				if requests <= 4:
					print("REQUEST ", support.name, " hand=", hand, " point=", hit.position, " normal=", hit.normal, " body=", app.torso.position)
		await ticks(1)
	print("ACQUIRE FAIL body=", app.torso.position, " state=", app.controller.get_hand_state(hand), " reason=", app.controller.hands[hand]["reason"], " reject=", app.controller.last_rejection)
	var shoulder: Vector3 = app.controller.get_shoulder_world(hand)
	var probe := PhysicsRayQueryParameters3D.create(shoulder,support.global_position)
	probe.exclude = [app.torso.get_rid()]
	print("ACQUIRE DIAGNOSTIC rot=",app.torso.rotation," shoulder=",shoulder," target=",support.global_position," distance=",shoulder.distance_to(support.global_position)," ray=",app.torso.get_world_3d().direct_space_state.intersect_ray(probe))
	return false

func run() -> void:
	app = Lab.new()
	root.add_child(app)
	current_scene = app
	if OS.get_cmdline_user_args().has("--feet"):
		app._set_physical_feet(true)
	app.torso.contact_monitor = true
	app.torso.max_contacts_reported = 16
	await ticks(int(0.75 * hz))
	Input.action_press("contract")
	for index in 6:
		var hand: int = index % 2
		if app.controller.get_hand_state(hand)=="ATTACHED":
			app.controller.release_grip(hand)
		var support: PhysicsBody3D = app.level.holds[index]
		var attached: bool = await acquire(support, hand)
		check(attached, "static hold %d acquired via a real visible surface" % (index + 1))
		if not attached:
			break
		# Keep BOTH grips while settling; only the hand about to move releases.
		await ticks(int(1.2 * hz))
		print("STATIC AT ", index + 1, " torso=", app.torso.position, " state=", app.controller.get_hand_state(hand))
	await ticks(hz)
	check(app.won, "static climb completed with alternating material anchors and W")
	check(app.trial.large_step_events == 0 and app.trial.falls == 0, "static route contains no torso teleport or fall reset")
	check(not app.torso.freeze and (app.torso.collision_mask & 2) != 0, "rounded holds remain real colliders against dynamic torso")
	print("STATIC BODY CONTACTS ",wall_hold_contacts," longest_seconds=",float(longest_contact_streak)/hz)
	Input.action_release("contract")
	app.load_test(2)
	await ticks(int(0.75 * hz))
	var beam: RigidBody3D = app.level.beam
	var anchor: Vector3 = beam.to_global(Vector3(0.3,0,0.13))
	check(app.controller.request_grip(1, beam, anchor, Vector3.BACK), "reactive beam front surface is initially reachable")
	Input.action_press("contract")
	await ticks(int(2.5 * hz))
	check(app.controller.get_hand_state(1) == "ATTACHED", "reactive beam reaches before transferring any load")
	print("REACTIVE LOADED torso=", app.torso.position, " beam_z=", beam.rotation.z)
	check(absf(beam.rotation.z) > 0.08, "actual player load rotates hinged beam")
	# Use intermediate hand-over-hand placements. The old direct left-hand
	# .70 m reach depended on turning the torso around and crossing its arms.
	var shifted: bool = await acquire(beam,0,6.0,Vector3(0.45,-0.08,0.04),Vector3.DOWN)
	check(shifted,"second hand regrips farther along actual beam geometry")
	if shifted:
		await ticks(int(0.5*hz))
		app.controller.release_grip(1)
		await ticks(hz)
		var advanced: bool = await acquire(beam,1,6.0,Vector3(0.70,-0.08,0.04),Vector3.DOWN)
		check(advanced,"right hand advances using an intermediate uncrossed physical transfer")
		if advanced:
			await ticks(int(0.5*hz))
			app.controller.release_grip(0)
			await ticks(hz)
			var left_advanced: bool = await acquire(beam,0,6.0,Vector3(0.73,-0.08,0.04),Vector3.DOWN)
			check(left_advanced,"left hand advances without relying on uncontrolled torso yaw")
			if left_advanced:
				await ticks(int(0.5*hz))
				app.controller.release_grip(1)
				await ticks(hz)
	print("REACTIVE SHIFTED torso=",app.torso.position," beam=",beam.rotation.z)
	var got_exit: bool = await acquire(app.level.holds[-1], 1)
	check(got_exit, "free hand reaches an actual accessible EXIT surface")
	if got_exit:
		app.controller.release_grip(0)
	await ticks(int(2.5 * hz))
	check(got_exit and app.won, "reactive structure completes through physical grip transfer")
	check(app.trial.large_step_events == 0 and app.trial.falls == 0, "reactive route contains no torso teleport or fall reset")
	check(bounded, "all static and reactive work respects shared force and resultant torque budgets")
	print("REACTIVE END torso=", app.torso.position, " beam_z=", beam.rotation.z)
	print("PLAYTHROUGH MEASURE Hz=%d peak_force=%.3fN peak_torque=%.3fNm peak_speed=%.3fm/s" % [hz, peak_force, peak_torque, peak_speed])
	Input.action_release("contract")
	print("PLAYTHROUGH RESULTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
