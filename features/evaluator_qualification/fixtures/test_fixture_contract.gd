extends SceneTree
## Pure authored-data/shape-query bounds checks; no physics world is created.
const Fixture=preload("res://features/evaluator_qualification/fixtures/qualification_fixture.gd")
const PREPS="res://features/evaluator_qualification/resources/preparation_registry_v132_r1.json"
const SCENARIOS="res://features/evaluator_qualification/resources/scenarios_v132_r1.json"
class LateController extends Node:
	var _step:=1
	var simulation_time:=.01
class LateLab extends Node:
	var controller=LateController.new()
	var torso=Node.new()
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var registry:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Fixture.REGISTRY))
	var geometry:Dictionary=registry.geometries.symmetric_clearance_r1
	check(registry.revision==1 and registry.status=="PROSPECTIVE_UNMEASURED","fixture identity is a new prospective revision, not a historical result")
	check(geometry.spawn_m==[0.0,1.17,.4] and geometry.required_base_arena==8,"fixture preserves the existing arena8 initial body spawn")
	var mirror_ok:=true
	for part:Dictionary in geometry.parts:
		var found:=false
		for candidate:Dictionary in geometry.parts:
			if candidate.role==part.role and candidate.size_m==part.size_m and candidate.position_m==[-float(part.position_m[0]),float(part.position_m[1]),float(part.position_m[2])]:found=true
		mirror_ok=mirror_ok and found
	check(mirror_ok,"every physical solid has a reflected equal-size counterpart or lies on the symmetry plane")
	check(geometry.contact_points_m[0]==[-.24,2.1,0.0] and geometry.contact_points_m[1]==[.24,2.1,0.0] and geometry.camera.yaw_rad==0,"anchors and declared initial camera have a common left-right mirror frame")
	check(geometry.clearance_contract.status=="NOT_PROVEN_BEFORE_NATIVE_QUERIES" and geometry.clearance_contract.collision_mask==1,"authored geometry never fabricates native swept-ground clearance")
	var preps:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PREPS))
	check(preps.scripts.size()==3 and preps.budget.max_screen_attempts==24,"one-hand preparations are a bounded prospective 3x2x2x2 set")
	var legal:=true
	for script:Dictionary in preps.scripts:
		for step:Dictionary in script.steps:
			legal=legal and step.op in ["acquire","release","hold_keys"]
			for key in step.get("keys",[]):legal=legal and key in ["contract","extend","bias_left","bias_right"]
	check(legal,"preparation registry contains only existing input operations, never body/force/state setters")
	check(preps.onset_contract.motion_directed_speed_min_m_s==.15 and preps.onset_contract.quiet_full_relative_speed_max_m_s==.1 and preps.onset_contract.quiet_confirmation_elapsed_s==.25,"preparations preserve qualified velocity and elapsed-time bands")
	var scenarios:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SCENARIOS))
	var own_new_cases:bool=scenarios.scenarios.size()==16
	for scenario:Dictionary in scenarios.scenarios:own_new_cases=own_new_cases and scenario.arena==8 and str(scenario.id).begins_with("eq132_") and registry.fixtures.has(scenario.fixture)
	check(own_new_cases,"new cases retain distinct IDs and explicitly require the declared geometry")
	var capsule:=CapsuleShape3D.new();capsule.radius=.22;capsule.height=.98
	var sphere:=SphereShape3D.new();sphere.radius=.13
	var box:=BoxShape3D.new();box.size=Vector3(.36,.08,.28)
	check(is_equal_approx(Fixture._shape_radius(capsule),.49) and is_equal_approx(Fixture._shape_radius(sphere),.13) and is_equal_approx(Fixture._shape_radius(box),box.size.length()*.5),"sweep rotation bounds use full actual capsule/sphere/box geometry, not point feet")
	check(Fixture.MAX_SWEEP_STEPS==128 and Fixture.TRANSLATION_STEP_M==.02 and is_equal_approx(Fixture.ROTATION_STEP_RAD,PI/90),"swept-query subdivision is finite and has declared translation/rotation bounds")
	check(not Fixture.apply(null,{}).ok,"fixture construction rejects absent lab")
	var late=LateLab.new();var result:Dictionary=Fixture.apply(late,{"fixture":"qualification_mirror_v1"})
	check(not result.ok and result.reason=="FIXTURE_REQUIRES_PRE_FIRST_STEP","fixture replacement rejects any already-advanced controller before mutating the scene")
	late.controller.free();late.torso.free();late.free()
	print("QUALIFICATION FIXTURE CONTRACT RESULTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
