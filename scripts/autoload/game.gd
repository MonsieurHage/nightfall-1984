extends Node

## État global, réglages, cache matériaux, sauvegarde. Autoload unique.

signal score_changed(value: int)
signal xp_changed(value: int, current_level: int)
signal health_changed(value: float, maximum: float)
signal notification(text: String, duration: float)
signal objective_changed(text: String)
signal mission_completed(mission_id: String, results: Dictionary)
signal codex_entry_unlocked(id: String)
signal settings_changed()

const SAVE_PATH := "user://nightfall1984_save.json"

var main: Node = null
var ui: Node = null
var current_level: Node = null
var player: Node = null

var score: int = 0
var xp: int = 0
var level: int = 1
var memory_chips: int = 0
var total_questions: int = 0
var correct_questions: int = 0
var codex_unlocked: Array[String] = []
var completed_missions: Array[String] = []
var unlocked_missions: Array[String] = ["alley"]
var current_mission: String = ""
## État de la partie en cours (mission, position, armes, vie) pour reprise en ligne.
var run_state: Dictionary = {}
## Apports des commandes tactiles (mobile / tablette).
var touch_move: Vector2 = Vector2.ZERO
var touch_look: Vector2 = Vector2.ZERO
var is_touch: bool = false
var stats: Dictionary = {"kills": 0, "shots": 0, "hits": 0, "deaths": 0, "elapsed": 0.0}
var settings: Dictionary = {
	"sensitivity": 0.0022, "invert_y": false,
	"master": 0.9, "music": 0.55, "sfx": 0.9,
	"quality": "high", "grain": true
}

var mat_cache: Dictionary = {}
var tex_cache: Dictionary = {}


func _ready() -> void:
	setup_input()
	load_save()


static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("JSON absent: " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parser := JSON.new()
	var err := parser.parse(f.get_as_text())
	if err != OK:
		push_error("JSON invalide %s : %s" % [path, parser.get_error_message()])
		return {}
	return parser.data


## Toutes les données nécessaires pour reprendre exactement la partie.
func build_save_data() -> Dictionary:
	return {
		"score": score, "xp": xp, "level": level, "memory_chips": memory_chips,
		"total_questions": total_questions, "correct_questions": correct_questions,
		"codex_unlocked": codex_unlocked, "completed_missions": completed_missions,
		"unlocked_missions": unlocked_missions, "stats": stats, "settings": settings,
		"mission": current_mission, "run_state": run_state
	}


func save_game() -> void:
	var data := build_save_data()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
	var cloud := get_node_or_null("/root/Cloud")
	if cloud != null and cloud.has_method("queue_sync"):
		cloud.queue_sync()


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d: Dictionary = load_json(SAVE_PATH)
	if not d.is_empty():
		_apply_data(d)


## Applique le profil téléchargé depuis Supabase (source de vérité en ligne).
func apply_cloud_profile(profile: Dictionary) -> void:
	var cloud_data: Dictionary = {}
	if profile.get("save_data") is Dictionary:
		cloud_data = (profile["save_data"] as Dictionary).duplicate(true)
	cloud_data["score"] = int(profile.get("score", score))
	cloud_data["xp"] = int(profile.get("xp", xp))
	cloud_data["level"] = maxi(1, int(profile.get("level", level)))
	_apply_data(cloud_data)


func _apply_data(d: Dictionary) -> void:
	score = maxi(0, int(d.get("score", 0)))
	xp = int(d.get("xp", 0))
	level = maxi(1, int(d.get("level", 1)))
	memory_chips = int(d.get("memory_chips", 0))
	total_questions = int(d.get("total_questions", 0))
	correct_questions = int(d.get("correct_questions", 0))
	var saved_codex: Array = d.get("codex_unlocked", [])
	codex_unlocked.clear()
	for v in saved_codex:
		codex_unlocked.append(String(v))
	var saved_done: Array = d.get("completed_missions", [])
	completed_missions.clear()
	for v in saved_done:
		completed_missions.append(String(v))
	var unlocked: Array = d.get("unlocked_missions", [])
	if not unlocked.is_empty():
		unlocked_missions.clear()
		for v in unlocked:
			unlocked_missions.append(String(v))
	if d.get("stats") is Dictionary:
		stats = d["stats"] as Dictionary
	current_mission = String(d.get("mission", current_mission))
	run_state = {}
	if d.get("run_state") is Dictionary:
		run_state = (d["run_state"] as Dictionary).duplicate(true)
	var s: Dictionary = {}
	if d.get("settings") is Dictionary:
		s = d["settings"] as Dictionary
	for k in s.keys():
		if settings.has(k):
			settings[k] = s[k]


# ------------------------------------------------------------------ entrées
func setup_input() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("sprint", KEY_SHIFT)
	_add_key("crouch", KEY_CTRL)
	_add_key("jump", KEY_SPACE)
	_add_key("interact", KEY_E)
	_add_key("reload", KEY_R)
	_add_key("flashlight", KEY_F)
	_add_key("codex", KEY_TAB)
	_add_key("pause", KEY_ESCAPE)
	_add_key("weapon_1", KEY_1)
	_add_key("weapon_2", KEY_2)
	_add_key("weapon_3", KEY_3)
	_add_key("special", KEY_Q)
	_add_key("map", KEY_M)
	_add_mouse("fire", MOUSE_BUTTON_LEFT)
	_add_mouse("aim", MOUSE_BUTTON_RIGHT)


func _add_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _add_mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


# ------------------------------------------------------------------ score / XP
func add_score(amount: int) -> void:
	score = maxi(0, score + amount)
	score_changed.emit(score)


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_for_level(level):
		xp -= xp_for_level(level)
		level += 1
		notify("NIVEAU %d — nouveau capacités d'infiltration débloquées" % level, 3.0)
	xp_changed.emit(xp, level)
	save_game()


func xp_for_level(lvl: int) -> int:
	return 140 + (lvl - 1) * 110


func notify(text: String, duration: float = 2.5) -> void:
	notification.emit(text, duration)


func register_codex(id: String) -> void:
	if id.is_empty() or codex_unlocked.has(id):
		return
	codex_unlocked.append(id)
	codex_unlocked.sort()
	codex_unlocked.append("")
	codex_unlocked.pop_back()
	codex_unlocked.sort()
	add_score(35)
	codex_entry_unlocked.emit(id)
	save_game()


func unlock_mission(id: String) -> void:
	if not unlocked_missions.has(id):
		unlocked_missions.append(id)
		notify("NOUVEL ENVIRONNEMENT DÉBLOQUÉ : " + id.to_upper(), 4.0)
		save_game()


# ------------------------------------------------------------------ matériaux
func tex(set_name: String, kind: String = "diffuse") -> Texture2D:
	var key := set_name + "_" + kind
	if tex_cache.has(key):
		return tex_cache[key]
	var path := "res://assets/textures/%s_%s.jpg" % [set_name, kind]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	tex_cache[key] = t
	return t


func material(name: String) -> StandardMaterial3D:
	if mat_cache.has(name):
		return mat_cache[name]
	var m := StandardMaterial3D.new()
	match name:
		"asphalt":
			_pbr(m, "asphalt", Color(0.48, 0.52, 0.58), 0.12, 1.0, Vector2(7, 7))
		"concrete":
			_pbr(m, "concrete", Color(0.72, 0.75, 0.8), 0.02, 1.0, Vector2(4, 4))
		"metal":
			_pbr(m, "metal", Color(0.72, 0.78, 0.86), 0.92, 1.0, Vector2(3, 3))
		"rust":
			_pbr(m, "rust", Color(0.9, 0.72, 0.6), 0.62, 1.0, Vector2(3, 3))
		"panel":
			_pbr(m, "panel", Color(0.55, 0.62, 0.72), 0.78, 1.0, Vector2(2, 2))
		"chrome":
			m.albedo_color = Color(0.7, 0.78, 0.88)
			m.metallic = 1.0
			m.roughness = 0.16
		"dark_metal":
			m.albedo_color = Color(0.075, 0.09, 0.12)
			m.metallic = 0.85
			m.roughness = 0.42
		"plastic":
			m.albedo_color = Color(0.045, 0.05, 0.06)
			m.metallic = 0.05
			m.roughness = 0.65
		"glass":
			m.albedo_color = Color(0.06, 0.16, 0.22, 0.45)
			m.metallic = 0.1
			m.roughness = 0.08
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"neon_red":
			_emissive(m, Color(1.0, 0.11, 0.12), 6.0)
		"neon_cyan":
			_emissive(m, Color(0.18, 0.9, 1.0), 5.5)
		"neon_green":
			_emissive(m, Color(0.25, 1.0, 0.5), 5.0)
		"neon_amber":
			_emissive(m, Color(1.0, 0.55, 0.1), 5.0)
		"screen":
			_emissive(m, Color(0.05, 0.35, 0.5), 1.6)
		"warning":
			m.albedo_color = Color(1.0, 0.62, 0.05)
			m.metallic = 0.1
			m.roughness = 0.55
		_:
			m.albedo_color = Color(0.5, 0.5, 0.55)
			m.roughness = 0.7
	mat_cache[name] = m
	return m


func _pbr(m: StandardMaterial3D, set_name: String, tint: Color, metallic: float, roughness: float, uv: Vector2) -> void:
	m.albedo_color = tint
	var d := tex(set_name, "diffuse")
	if d:
		m.albedo_texture = d
	var n := tex(set_name, "normal")
	if n:
		m.normal_enabled = true
		m.normal_texture = n
	var r := tex(set_name, "rough")
	if r:
		m.roughness_texture = r
	var ao := tex(set_name, "ao")
	if ao:
		m.ao_enabled = true
		m.ao_texture = ao
	m.metallic = metallic
	m.roughness = roughness
	m.uv1_scale = Vector3(uv.x, uv.y, 1.0)


func _emissive(m: StandardMaterial3D, color: Color, energy: float) -> void:
	m.albedo_color = color
	m.metallic = 0.0
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy


func reset_run() -> void:
	score = 0
	xp = 0
	level = 1
	memory_chips = 0
	total_questions = 0
	correct_questions = 0
	codex_unlocked.clear()
	completed_missions.clear()
	unlocked_missions = ["alley"]
	current_mission = ""
	run_state.clear()
	stats = {"kills": 0, "shots": 0, "hits": 0, "deaths": 0, "elapsed": 0.0}
	save_game()
