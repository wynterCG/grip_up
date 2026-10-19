extends Node
## Native rendered fixtures only. No claim of player-controlled full top-out.
var hz:=120
var report:={"checks":[],"complete":false,"provenance":"Godot MCP Pro rendered isolated primitives; not human mantle evidence","palm":[],"leg":{}}
var fixture:Node3D
signal watch_stage(label:String)
var watch_seconds:=0.0

func _ready()->void:
	hz=Engine.physics_ticks_per_second
	run.call_deferred()

func ticks(seconds:float)->void:
	for frame in maxi(1,int(seconds*hz)):await get_tree().physics_frame

func check(value:bool,label:String)->void:
	report.checks.append({"passed":value,"label":label})

func replace_scene(path:String,definition:Dictionary={})->void:
	if is_instance_valid(get_tree().current_scene):
		var old=get_tree().current_scene
		get_tree().root.remove_child(old)
		old.queue_free()
	fixture=load(path).instantiate()
	if not definition.is_empty():fixture.definition=definition
	get_tree().root.add_child(fixture)
	get_tree().current_scene=fixture
	await ticks(.1)

func shot(label:String)->void:
	watch_stage.emit(label)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Wynter/grip_up/builds/v08_%dhz_%s.png"%[hz,label])
	if watch_seconds>0:
		get_tree().paused=true
		await get_tree().create_timer(watch_seconds,true,false,true).timeout
		get_tree().paused=false

func render_palm()->void:
	for physical in [fixture.body,fixture.support]:
		for shape in physical.get_children():
			if not shape is CollisionShape3D:continue
			var mesh:=MeshInstance3D.new()
			if shape.shape is CapsuleShape3D:
				var capsule:=CapsuleMesh.new()
				capsule.height=shape.shape.height
				capsule.radius=shape.shape.radius
				mesh.mesh=capsule
			else:
				var box:=BoxMesh.new()
				box.size=shape.shape.size
				mesh.mesh=box
			var mat:=StandardMaterial3D.new()
			mat.albedo_color=Color("e6ae58") if physical==fixture.body else Color("314955")
			mesh.material_override=mat
			shape.add_child(mesh)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-40,-25,0)
	fixture.add_child(light)
	var camera:=Camera3D.new()
	fixture.add_child(camera)
	camera.position=fixture.body.position+Vector3(2,1.2,4)
	camera.look_at(fixture.body.position-Vector3.UP*.2)
	camera.current=true
	var canvas:=CanvasLayer.new()
	fixture.add_child(canvas)
	var label:=Label.new()
	label.position=Vector2(25,25)
	label.add_theme_font_size_override("font_size",22)
	label.text="M1 / ISOLATED PALM COMPRESSION\n12 kg favorable handstand fixture. Finite contact, no body pose writes.\nThis is not a hanging-to-mantle success."
	canvas.add_child(label)

func run()->void:
	report.physics_hz=hz
	for moving in [false,true]:
		await replace_scene("res://features/grip_up/tests/palm_compression_lab.tscn",{"moving":moving,"two":false})
		render_palm()
		check(fixture.request(0),"native isolated palm begins finite contact acquisition")
		for frame in hz:
			await ticks(1.0/hz)
			if fixture.controller.get_hand_state(0)=="ATTACHED":break
		check(fixture.controller.get_hand_state(0)=="ATTACHED","native finite palm arrival")
		await ticks(.12)
		var start:Vector3=fixture.body.position
		var platform_start:Vector3=fixture.support.position
		if not moving:fixture.body.gravity_scale=1
		fixture.press=1
		var peak:float=start.y
		var caps:=true
		for frame in int(.65*hz):
			await ticks(1.0/hz)
			peak=maxf(peak,fixture.body.position.y)
			var data:Dictionary=fixture.controller.telemetry()
			caps=caps and data.total_force<=360.001 and Vector3(data.assist_torque).length()<=20.001 and Vector3(data.torque).length()<=150.001
		check(peak>start.y+.015,"native actual palm force produces measured lift in favorable posture")
		check(caps,"native palm remains inside existing shared force and torque budgets")
		if moving:check(fixture.support.position.y<platform_start.y-.001,"native dynamic platform receives downward reaction")
		report.palm.append({"dynamic":moving,"start":start,"peak_y":peak,"support_displacement":fixture.support.position-platform_start,"telemetry":fixture.controller.telemetry()})
		await shot("palm_dynamic" if moving else "palm_fixed")
		fixture.controller.release_grip(0)
		await ticks(.05)
		check(fixture.controller.get_arm_force(0)==Vector3.ZERO,"native release removes palm support")
	await replace_scene("res://features/grip_up/tests/mantle_leg_clearance_lab.tscn")
	fixture.request_flex(1)
	await ticks(1.8)
	check(fixture.legs.achieved_flex>.99,"native C1 physical colliders reach crouched pose")
	check(fixture.body.position.length()<.001 and fixture.body.linear_velocity.length()<.001,"native free collider folding does not move the body")
	await shot("leg_folded")
	check(fixture.set_blocker("EXPANSION"),"native obstruction inserted without overlapping current crouched body")
	fixture.request_flex(0)
	await ticks(1)
	check(fixture.legs.blocked and fixture.legs.achieved_flex>.1,"native blocked expansion retains collision-valid pose")
	await shot("leg_blocked")
	fixture.set_blocker("NONE")
	await ticks(1.8)
	check(fixture.legs.achieved_flex<.001,"native valid clearance restores standing geometry")
	report.leg={"data":fixture.data,"samples":fixture.samples}
	await shot("leg_restored")
	report.window_screen=get_window().current_screen
	report.complete=true
	FileAccess.open("C:/Users/Wynter/grip_up/builds/v08_primitives_native_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	queue_free()
