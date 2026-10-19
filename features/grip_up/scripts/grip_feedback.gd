extends Node
## Quiet generated prototype cues, only used by the experimental control profile.
var players: Array[AudioStreamPlayer] = []
var contact: AudioStreamWAV
var release: AudioStreamWAV
var events := 0

func _ready() -> void:
	contact = _tone(620.0,0.045)
	release = _tone(340.0,0.025)
	for id in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = -23.0
		add_child(player)
		players.append(player)

func _tone(frequency: float, duration: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := int(duration*stream.mix_rate)
	var samples := PackedByteArray()
	samples.resize(count*2)
	for index in count:
		var time := float(index)/stream.mix_rate
		var envelope := minf(1.0,time/0.002)*pow(1.0-float(index)/count,3.0)
		samples.encode_s16(index*2,int(sin(time*TAU*frequency)*envelope*12000))
	stream.data = samples
	return stream

func cue(id: int, attached: bool) -> void:
	events += 1
	if DisplayServer.get_name()=="headless":
		return
	players[id].stream = contact if attached else release
	players[id].play()
