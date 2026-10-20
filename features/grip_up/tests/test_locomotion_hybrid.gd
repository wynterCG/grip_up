extends "res://features/grip_up/tests/test_vault_v10.gd"
var assisted_ticks:=0
var observer_safe:=true
var records:Array=[]
var allocation_variant:=0

func _initialize()->void:
	allocation_variant=1 if OS.get_cmdline_user_args().has("--a1") else 0
	super._initialize()

func fresh(index:int,feet:bool=false)->void:
	await super.fresh(index,feet)
	app._set_movement_allocation(allocation_variant)
	app._set_locomotion_diagnostics(true)

func observe(delta:float)->void:
	super.observe(delta)
	var observation:Dictionary=app.controller.telemetry().get("locomotion_observation",{})
	if app.controller.assisted_motion_owned:
		assisted_ticks+=1
		observer_safe=observer_safe and observation.get("owner_bits",0)==16
		observer_safe=observer_safe and app.controller.intent_locomotion.constraint_allocation.data.is_empty()
		observer_safe=observer_safe and app.controller.get_effective_swing_request()==Vector3.ZERO
		observer_safe=observer_safe and Vector3(observation.get("ground_force",Vector3.ZERO))==Vector3.ZERO
		observer_safe=observer_safe and observation.get("hand_forces",[]).size()==2
		for force in observation.get("hand_forces",[]):observer_safe=observer_safe and Vector3(force)==Vector3.ZERO
	if assisted_ticks%12==0 and not observation.is_empty():records.append(observation.duplicate(true))

func run()->void:
	for scenario in [0,1]:
		trials.append(await ascent(scenario))
		check(app.controller.intent_locomotion.movement_allocation==allocation_variant,"selected allocation remains selected after actual top-out")
		check(app.hybrid_mantle.state=="DYNAMIC_GROUNDED" and app.hybrid_mantle.completed,"selected allocation and diagnostic path retain actual native top support and walking")
		check(absf(app.hybrid_mantle.route.duration-1.15)<.000001,"refinement keeps the certified v1.0 route duration")
	check(assisted_ticks>0 and observer_safe,"hybrid owns movement alone and clears A1 requests during committed traversal")
	check(budgets_ok,"A1 observed top-outs retain common dynamic budgets")
	FileAccess.open("res://builds/locomotion_hybrid_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify({"physics_hz":hz,"allocation_variant":allocation_variant,"checks":checks,"failures":failures,"trials":trials,"assisted_ticks":assisted_ticks,"observation_samples":records,"human_feel":"PENDING"},"\t"))
	app.queue_free()
	await ticks(.03)
	print("LOCOMOTION HYBRID RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
