extends Node

## Musique avec fondu croisé + banque de SFX réutilisables (autoload `Audio`).

var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var active_music: AudioStreamPlayer
var current_music: String = ""
var sfx_cache: Dictionary = {}
var sfx_players: Array[AudioStreamPlayer] = []
var pos_players: Array[AudioStreamPlayer3D] = []
var music_tween: Tween = null


func _ready() -> void:
	music_a = _make_music_player()
	music_b = _make_music_player()
	active_music = music_a
	apply_settings()


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.volume_db = -60.0
	add_child(p)
	return p


func apply_settings() -> void:
	var master: float = clampf(float(Game.settings.get("master", 0.9)), 0.0, 1.0)
	var music: float = clampf(float(Game.settings.get("music", 0.55)), 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))
	# Sous-bus created on demand so music/sfx stay independently controllable.
	_ensure_bus("Music", music * master)
	_ensure_bus("SFX", clampf(float(Game.settings.get("sfx", 0.9)), 0.0, 1.0) * master)


func _ensure_bus(bus_name: String, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume, 0.0001)))


func stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null


func sfx_stream(name: String) -> AudioStream:
	if sfx_cache.has(name):
		return sfx_cache[name]
	var s := stream("res://assets/audio/sfx_%s.wav" % name)
	if s == null:
		s = stream("res://assets/audio/sfx_%s.ogg" % name)
	sfx_cache[name] = s
	return s


func play_music(name: String, fade: float = 1.2) -> void:
	var s := stream("res://assets/audio/music_%s.wav" % name)
	if s == null:
		s = stream("res://assets/audio/music_%s.ogg" % name)
	if s == null:
		return
	if current_music == name and active_music.playing:
		return
	current_music = name
	if music_tween and music_tween.is_valid():
		music_tween.kill()
	var next := music_b if active_music == music_a else music_a
	next.stream = s
	next.volume_db = -60.0
	next.play()
	music_tween = create_tween()
	music_tween.set_parallel(true)
	music_tween.tween_property(active_music, "volume_db", -60.0, fade)
	music_tween.tween_property(next, "volume_db", -7.0, fade)
	await music_tween.finished
	active_music.stop()
	active_music = next


func stop_music(fade: float = 0.6) -> void:
	if music_tween and music_tween.is_valid():
		music_tween.kill()
	music_tween = create_tween()
	music_tween.set_parallel(true)
	music_tween.tween_property(music_a, "volume_db", -60.0, fade)
	music_tween.tween_property(music_b, "volume_db", -60.0, fade)
	await get_tree().create_timer(fade).timeout
	music_a.stop()
	music_b.stop()
	current_music = ""


func play_sfx(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := sfx_stream(name)
	if s == null:
		return
	var p: AudioStreamPlayer = null
	for candidate in sfx_players:
		if not candidate.playing:
			p = candidate
			break
	if p == null:
		p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_sfx_at(name: String, world_pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := sfx_stream(name)
	if s == null:
		return
	var p: AudioStreamPlayer3D = null
	for candidate in pos_players:
		if not candidate.playing:
			p = candidate
			break
	if p == null:
		p = AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 8.0
		p.max_db = 12.0
		add_child(p)
		pos_players.append(p)
	p.global_position = world_pos
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
