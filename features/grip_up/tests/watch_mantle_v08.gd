extends Node
## Visible replay of the existing native checks, at real speed, with short
## paused snapshots. Physics/controls/acceptance thresholds remain unchanged.
var banner:Label
var status:=""
var reports:Array=[]

func _ready()->void:
	var canvas:=CanvasLayer.new()
	canvas.layer=100
	add_child(canvas)
	banner=Label.new()
	banner.position=Vector2(25,185)
	banner.add_theme_font_size_override("font_size",24)
	banner.add_theme_color_override("font_color",Color("71eee0"))
	banner.add_theme_color_override("font_shadow_color",Color.BLACK)
	banner.add_theme_constant_override("shadow_offset_x",2)
	banner.add_theme_constant_override("shadow_offset_y",2)
	canvas.add_child(banner)
	run.call_deferred()

func stage(label:String)->void:
	var names:={"palm_fixed":"Palma num apoio fixo","palm_dynamic":"Palma num apoio movel: reacao fisica","leg_folded":"Pernas: colisores realmente recolhidos","leg_blocked":"Obstaculo impede estender as pernas","leg_restored":"Espaco livre: colisores de pe restaurados"}
	banner.text=status+"\n"+str(names.get(label,label))+"\nPausa de observacao: 3 segundos"

func main_scene()->void:
	if is_instance_valid(get_tree().current_scene):
		var previous=get_tree().current_scene
		get_tree().root.remove_child(previous)
		previous.queue_free()
	var app=load("res://features/grip_up/scenes/grip_up_lab.tscn").instantiate()
	get_tree().root.add_child(app)
	get_tree().current_scene=app
	await get_tree().physics_frame

func read_report(path:String)->void:
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:reports.append(data)

func run()->void:
	for hz in [120,60]:
		Engine.physics_ticks_per_second=hz
		status="TESTES AO VIVO / %d Hz / palmas e pernas"%hz
		banner.text=status+"\nEnsaios isolados; isto nao e um mantle completo."
		var primitives=load("res://features/grip_up/tests/capture_mantle_v08_primitives.gd").new()
		primitives.watch_seconds=3.0
		primitives.watch_stage.connect(stage)
		get_tree().root.add_child(primitives)
		await primitives.tree_exited
		read_report("C:/Users/Wynter/grip_up/builds/v08_primitives_native_%dhz.json"%hz)
		await main_scene()
		status="TESTES AO VIVO / %d Hz / tentativa de subir para o topo"%hz
		banner.text=status+"\nPlataformas 1.25m e 2.10m. O top-out ainda falha."
		var attempt=load("res://features/grip_up/tests/capture_mantle_v08.gd").new()
		attempt.watch_seconds=3.0
		attempt.watch_stage.connect(stage)
		get_tree().current_scene.add_child(attempt)
		await attempt.tree_exited
		read_report("C:/Users/Wynter/grip_up/builds/mantle_v08_native_%dhz.json"%hz)
	Engine.physics_ticks_per_second=120
	var results:={"complete":true,"window_screen":get_window().current_screen,"provenance":"Existing native tests replayed visibly at real simulation speed;3s paused snapshots; not human acceptance","reports":reports}
	FileAccess.open("C:/Users/Wynter/grip_up/builds/v08_live_watch.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	banner.text="TESTES TERMINADOS / 120 e 60 Hz\nPalmas e pernas: ensaios isolados. Top-out: ainda incompleto.\nCenario normal preparado para experimentares."
	await get_tree().create_timer(6.0).timeout
	queue_free()
