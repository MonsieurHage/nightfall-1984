extends CanvasLayer
class_name GameUI

## Interface complète : HUD, menus, QCM pédagogique, codex, bilan, mode professeur.

signal restart_requested
signal menu_requested
signal teacher_export_requested
signal next_requested

var player: Node = null
var root: Control
var hud: Control
var menu_panel: Control
var mission_panel: Control
var quiz_panel: Control
var codex_panel: Control
var pause_panel: Control
var result_panel: Control
var death_panel: Control
var teacher_panel: Control
var fade_rect: ColorRect

var objective_label: Label
var score_label: Label
var health_fill: ColorRect
var health_text: Label
var ammo_label: Label
var weapon_label: Label
var prompt_label: Label
var notif_label: Label
var reload_label: Label
var mission_title: Label
var quiz_title: Label
var quiz_question: Label
var quiz_feedback: Label
var quiz_buttons: Array[Button] = []
var quiz_continue: Button
var codex_container: VBoxContainer
var result_text: Label
var teacher_text: Label
var current_question: Dictionary = {}
var notif_timer: float = 0.0
var font_main: Font
var font_title: Font
var ping_timer: float = 0.0
var account_label: Label
var _fade_at: float = 0.0


func _ready() -> void:
	layer = 20
	if ResourceLoader.exists("res://assets/fonts/Orbitron-Bold.ttf"):
		font_title = load("res://assets/fonts/Orbitron-Bold.ttf")
	if ResourceLoader.exists("res://assets/fonts/Rajdhani-SemiBold.ttf"):
		font_main = load("res://assets/fonts/Rajdhani-SemiBold.ttf")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var th := Theme.new()
	if font_main:
		th.default_font = font_main
		th.default_font_size = 20
	root.theme = th

	_build_vignette()
	_build_hud()
	_build_main_menu()
	_build_mission_select()
	_build_quiz()
	_build_codex()
	_build_pause()
	_build_results()
	_build_death()
	_build_teacher()

	fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)

	Game.health_changed.connect(_on_health)
	Game.score_changed.connect(_on_score)
	Game.xp_changed.connect(_on_xp)
	Game.notification.connect(show_notification)


func input_blocked() -> bool:
	for p in [menu_panel, mission_panel, quiz_panel, codex_panel, pause_panel, result_panel, death_panel, teacher_panel]:
		if p and p.visible:
			return true
	return false


func hide_all() -> void:
	for p in [hud, menu_panel, mission_panel, quiz_panel, codex_panel, pause_panel, result_panel, death_panel, teacher_panel]:
		if p:
			p.visible = false
	set_prompt("")


func show_hud() -> void:
	hide_all()
	hud.visible = true
	_refresh_stats()


func fade_to(alpha: float, duration: float = 0.4) -> void:
	if fade_rect == null:
		return
	_fade_at = Time.get_ticks_msec() / 1000.0
	var t := create_tween()
	t.tween_property(fade_rect, "color:a", alpha, duration)


# ------------------------------------------------------------------ helpers
func _style(bg: Color, border: Color = Color(0.1, 0.75, 0.9, 0.85)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _panel(parent: Control, name: String, x: float, y: float, w: float, h: float,
		full: bool = false, bg: Color = Color(0.015, 0.03, 0.055, 0.94)) -> Panel:
	var p := Panel.new()
	p.name = name
	if full:
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
	else:
		p.set_anchors_preset(Control.PRESET_TOP_LEFT)
		p.offset_left = x
		p.offset_top = y
		p.offset_right = x + w
		p.offset_bottom = y + h
	p.add_theme_stylebox_override("panel", _style(bg))
	parent.add_child(p)
	return p


func _label(parent: Control, text: String, x: float, y: float, w: float, h: float,
		size: int = 20, color: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_LEFT,
		title: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.set_anchors_preset(Control.PRESET_TOP_LEFT)
	l.offset_left = x
	l.offset_top = y
	l.offset_right = x + w
	l.offset_bottom = y + h
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if title and font_title:
		l.add_theme_font_override("font", font_title)
	elif font_main:
		l.add_theme_font_override("font", font_main)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, x: float, y: float, w: float, h: float,
		callback: Callable, accent: Color = Color(0.1, 0.75, 0.9, 0.9)) -> Button:
	var b := Button.new()
	b.text = text
	b.set_anchors_preset(Control.PRESET_TOP_LEFT)
	b.offset_left = x
	b.offset_top = y
	b.offset_right = x + w
	b.offset_bottom = y + h
	var normal := _style(Color(0.02, 0.06, 0.1, 0.95), accent)
	var hover := _style(Color(0.05, 0.16, 0.22, 1.0), Color.WHITE)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	if font_main:
		b.add_theme_font_override("font", font_main)
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	b.connect("pressed", callback)
	parent.add_child(b)
	return b


func _build_vignette() -> void:
	if not ResourceLoader.exists("res://assets/shaders/cinematic.gdshader"):
		return
	var shader := load("res://assets/shaders/cinematic.gdshader") as Shader
	if shader == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = mat
	root.add_child(r)


# -------------------------------------------------------------------- HUD
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)

	var obj := _panel(hud, "Objectives", 18, 16, 470, 156)
	mission_title = _label(obj, "MISSION", 14, 8, 440, 30, 18, Color(0.25, 0.85, 1.0), HORIZONTAL_ALIGNMENT_LEFT, true)
	objective_label = _label(obj, "", 14, 38, 440, 108, 18, Color(0.9, 0.95, 1.0))

	score_label = _label(hud, "SCORE 0  |  NIV 1  |  XP 0/140", 1180, 18, 400, 40,
		19, Color(0.4, 0.9, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)

	var hp_bg := ColorRect.new()
	hp_bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hp_bg.offset_left = 20
	hp_bg.offset_top = 824
	hp_bg.offset_right = 310
	hp_bg.offset_bottom = 846
	hp_bg.color = Color(0.05, 0.1, 0.14, 0.9)
	hud.add_child(hp_bg)
	health_fill = ColorRect.new()
	health_fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	health_fill.offset_left = 22
	health_fill.offset_top = 826
	health_fill.offset_right = 308
	health_fill.offset_bottom = 844
	health_fill.color = Color(0.1, 0.85, 0.75)
	hud.add_child(health_fill)
	health_text = _label(hud, "INTÉGRITÉ 100", 20, 790, 300, 30, 17, Color(0.6, 1.0, 0.9))

	weapon_label = _label(hud, "Pistolet M9", 1120, 770, 460, 34,
		20, Color(0.4, 0.9, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	ammo_label = _label(hud, "12 / 72", 1180, 804, 400, 60,
		38, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, true)
	reload_label = _label(hud, "", 1000, 740, 580, 30, 18,
		Color(1, 0.6, 0.1), HORIZONTAL_ALIGNMENT_RIGHT)

	var cross := _label(hud, "+", 0, 0, 26, 26, 28, Color(0.8, 0.95, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.offset_left = -13
	cross.offset_top = -13
	cross.offset_right = 13
	cross.offset_bottom = 13

	prompt_label = _label(hud, "", 400, 690, 800, 42, 22,
		Color(1, 0.85, 0.35), HORIZONTAL_ALIGNMENT_CENTER)
	notif_label = _label(hud, "", 300, 120, 1000, 60, 26,
		Color(0.4, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER, true)
	hud.visible = false


func _process(delta: float) -> void:
	if notif_timer > 0.0:
		notif_timer -= delta
		if notif_timer <= 0.0 and notif_label:
			notif_label.text = ""
	if ping_timer > 0.0:
		ping_timer -= delta
	# Garde-fou : un voile noir oublié après une transition longue est relâché.
	if fade_rect and fade_rect.color.a > 0.95:
		var transitioning := false
		if Game.main != null:
			transitioning = bool(Game.main.get("_transitioning"))
		if not transitioning and Time.get_ticks_msec() / 1000.0 - _fade_at > 4.0:
			fade_to(0.0, 0.35)


func _on_health(value: float, maximum: float) -> void:
	var ratio := clampf(value / maxf(maximum, 1.0), 0.0, 1.0)
	if health_fill:
		health_fill.offset_right = 22 + 286.0 * ratio
		health_fill.color = Color(0.95, 0.2, 0.2) if ratio < 0.3 else Color(0.1, 0.85, 0.75)
	if health_text:
		health_text.text = "INTÉGRITÉ %d" % int(value)


func _on_score(_value: int) -> void:
	_refresh_stats()


func _on_xp(_value: int, _lvl: int) -> void:
	_refresh_stats()


func _refresh_stats() -> void:
	if score_label:
		score_label.text = "SCORE %d  |  NIV %d  |  XP %d/%d" % [
			Game.score, Game.level, Game.xp, Game.xp_for_level(Game.level)]


func set_objectives(text: String) -> void:
	if objective_label:
		objective_label.text = text


func on_mission_started(m: Dictionary) -> void:
	if mission_title:
		mission_title.text = String(m.get("name", "MISSION"))
	show_notification(String(m.get("brief", "")), 6.0)
	set_objectives(Missions.objective_text())


func on_objective_progress(_id: String, _cur: int, _target: int) -> void:
	call_deferred("set_objectives", Missions.objective_text())


func set_prompt(text: String) -> void:
	if prompt_label:
		prompt_label.text = text


func set_weapon(name: String, ammo: int, reserve: int) -> void:
	if weapon_label:
		weapon_label.text = name
	if ammo_label:
		ammo_label.text = "%d / %d" % [ammo, reserve]


func set_reload(active: bool) -> void:
	if reload_label:
		reload_label.text = "RECHARGEMENT..." if active else ""


func show_notification(text: String, duration: float = 2.5) -> void:
	if notif_label:
		notif_label.text = text
	notif_timer = duration


func damage_flash() -> void:
	if fade_rect:
		fade_rect.color = Color(0.8, 0.0, 0.0, 0.22)
		var t := create_tween()
		t.tween_property(fade_rect, "color", Color(0, 0, 0, 0), 0.28)


func ping_enemies(duration: float) -> void:
	ping_timer = duration
	show_notification("SCAN CAMÉRA : CONTACTS ENNEMIS SIGNALÉS", 2.5)


# -------------------------------------------------------------- menus
func _build_main_menu() -> void:
	menu_panel = _panel(root, "MainMenu", 0, 0, 0, 0, true, Color(0.01, 0.015, 0.03, 0.88))
	var title := _label(menu_panel, "NIGHTFALL 1984", 0, 130, 1600, 100, 76,
		Color(1.0, 0.12, 0.14), HORIZONTAL_ALIGNMENT_CENTER, true)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 130
	title.offset_bottom = 230
	var sub := _label(menu_panel, "P R O T O C O L E   S K Y N E T", 0, 235, 1600, 50, 30,
		Color(0.25, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, true)
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 235
	sub.offset_bottom = 290
	_label(menu_panel, "FPS PÉDAGOGIQUE — PROGRAMME TECHNOLOGIE CYCLE 4 (BO 29/02/2024)",
		0, 305, 1600, 40, 20, Color(0.65, 0.78, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	account_label = _label(menu_panel, "", 0, 348, 1600, 34, 20,
		Color(0.35, 0.95, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	_button(menu_panel, "REPRENDRE MA PARTIE", 590, 390, 420, 56, Callable(self, "_on_resume"),
		Color(0.15, 0.75, 0.4, 0.9))
	_button(menu_panel, "NOUVELLE MISSION", 590, 460, 420, 56, Callable(self, "_on_new_game"), Color(1, 0.2, 0.2, 0.9))
	_button(menu_panel, "CHOISIR UN ENVIRONNEMENT", 590, 530, 420, 56, Callable(self, "_on_mission_select"))
	_button(menu_panel, "COMPTE / CLASSEMENT", 590, 600, 420, 56, Callable(self, "_on_account"),
		Color(0.6, 0.4, 1.0, 0.9))
	_button(menu_panel, "MODE PROFESSEUR / BILAN", 590, 670, 420, 56, Callable(self, "_on_teacher"))
	_button(menu_panel, "QUITTER", 590, 740, 420, 52, Callable(self, "_on_quit"), Color(0.6, 0.6, 0.6, 0.9))
	_label(menu_panel, "ZQSD déplacer • Souris viser • Clic tirer • E interagir • Ctrl se baisser • Q spécial • Tab codex • Échap pause",
		0, 840, 1600, 36, 18, Color(0.55, 0.7, 0.8), HORIZONTAL_ALIGNMENT_CENTER)


func _on_new_game() -> void:
	Game.reset_run()
	Game.main.start_mission("alley")


func set_account(p: String) -> void:
	if account_label:
		account_label.text = ("AGENT CONNECTÉ : " + p) if p != "" else "MODE HORS-LIGNE — CONNECTEZ-VOUS POUR SAUVEGARDER"


func _on_account() -> void:
	if Game.main and Game.main.cloud_ui:
		Game.main.cloud_ui.show_auth()


func _on_resume() -> void:
	if Game.main:
		Game.main.resume_game()


func _on_mission_select() -> void:
	menu_panel.visible = false
	mission_panel.visible = true


func _on_teacher() -> void:
	menu_panel.visible = false
	teacher_panel.visible = true
	_refresh_teacher()


func _on_quit() -> void:
	get_tree().quit()


func show_main_menu() -> void:
	hide_all()
	menu_panel.visible = true
	set_account(Cloud.pseudo if Cloud.signed_in else "")
	_refresh_stats()


func _build_mission_select() -> void:
	mission_panel = _panel(root, "MissionSelect", 0, 0, 0, 0, true, Color(0.01, 0.02, 0.04, 0.96))
	_label(mission_panel, "SÉLECTION D'ENVIRONNEMENT", 0, 60, 1600, 60, 42,
		Color(0.25, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, true)
	var ids := ["alley", "factory", "vents", "plant", "core"]
	for i in ids.size():
		var m: Dictionary = Missions.missions.get(ids[i], {})
		var unlocked := Game.unlocked_missions.has(ids[i])
		var txt := String(m.get("name", ids[i]))
		if not unlocked:
			txt += "  [VERROUILLÉ]"
		var b := _button(mission_panel, txt, 330, 170 + i * 92, 940, 66,
			Callable(self, "_launch_%s" % ids[i]),
			Color(0.2, 0.8, 0.4, 0.9) if unlocked else Color(0.4, 0.4, 0.45, 0.8))
		b.disabled = not unlocked
	_button(mission_panel, "RETOUR", 660, 690, 280, 56, Callable(self, "_back_to_menu"))


func _launch_alley() -> void: Game.main.start_mission("alley")
func _launch_factory() -> void: Game.main.start_mission("factory")
func _launch_vents() -> void: Game.main.start_mission("vents")
func _launch_plant() -> void: Game.main.start_mission("plant")
func _launch_core() -> void: Game.main.start_mission("core")

func _back_to_menu() -> void:
	hide_all()
	menu_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ------------------------------------------------------------------ QCM
func _build_quiz() -> void:
	quiz_panel = _panel(root, "Quiz", 0, 0, 0, 0, true, Color(0.005, 0.01, 0.02, 0.97))
	var inner := _panel(quiz_panel, "QuizBox", 260, 90, 1080, 760, false,
		Color(0.02, 0.05, 0.09, 0.98))
	quiz_title = _label(inner, "BORNE PÉDAGOGIQUE — BO TECHNOLOGIE", 20, 16, 1040, 46, 26,
		Color(0.25, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT, true)
	quiz_question = _label(inner, "", 20, 74, 1040, 150, 27, Color.WHITE)
	quiz_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiz_question.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	for i in range(4):
		var b := _button(inner, "", 20, 236 + i * 82, 1040, 64,
			Callable(self, "_answer_%d" % i))
		quiz_buttons.append(b)
	quiz_feedback = _label(inner, "", 20, 556, 1040, 126, 18, Color(0.7, 0.9, 1.0))
	quiz_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiz_feedback.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	quiz_continue = _button(inner, "CONTINUER", 790, 694, 270, 54, Callable(self, "_close_quiz"))
	quiz_continue.visible = false
	quiz_panel.visible = false


func _answer_0() -> void: _answer(0)
func _answer_1() -> void: _answer(1)
func _answer_2() -> void: _answer(2)
func _answer_3() -> void: _answer(3)


func show_quiz(q: Dictionary) -> void:
	current_question = q
	quiz_title.text = "BORNE PÉDAGOGIQUE — " + String(q.get("theme", "")).to_upper()
	quiz_question.text = String(q.get("prompt", ""))
	var opts: Array = q.get("options", [])
	for i in range(4):
		quiz_buttons[i].text = String(opts[i]) if i < opts.size() else ""
		quiz_buttons[i].disabled = false
	quiz_feedback.text = ""
	quiz_continue.visible = false
	quiz_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _answer(index: int) -> void:
	if current_question.is_empty():
		return
	for b in quiz_buttons:
		b.disabled = true
	Quiz.answer(index)


func show_quiz_feedback(result: Dictionary) -> void:
	if not quiz_panel.visible:
		return
	var ok := bool(result.get("ok", false))
	var q: Dictionary = result.get("question", {})
	var correct := int(q.get("answer", 0))
	var opts: Array = q.get("options", [])
	quiz_buttons[correct].modulate = Color(0.25, 1.0, 0.45) if ok else Color(1.0, 0.3, 0.3)
	quiz_feedback.text = ("CORRECT ! " if ok else "INCORRECT. ") + String(q.get("explication", ""))
	quiz_feedback.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55) if ok else Color(1.0, 0.45, 0.4))
	quiz_continue.visible = true
	_refresh_stats()


func _close_quiz() -> void:
	quiz_panel.visible = false
	for b in quiz_buttons:
		b.modulate = Color.WHITE
	current_question = {}
	if Game.current_mission != "" and not input_blocked():
		Game.main.capture_mouse()


# ------------------------------------------------------------------ CODEX
func _build_codex() -> void:
	codex_panel = _panel(root, "Codex", 0, 0, 0, 0, true, Color(0.01, 0.02, 0.04, 0.97))
	_label(codex_panel, "CLASSEUR TECHNOLOGIQUE — BO CYCLE 4", 0, 45, 1600, 60, 40,
		Color(0.25, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, true)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scroll.offset_left = 180
	scroll.offset_top = 130
	scroll.offset_right = 1420
	scroll.offset_bottom = 790
	codex_panel.add_child(scroll)
	codex_container = VBoxContainer.new()
	codex_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(codex_container)
	_button(codex_panel, "FERMER [TAB]", 660, 810, 280, 54, Callable(self, "toggle_codex"))
	codex_panel.visible = false


func toggle_codex() -> void:
	if codex_panel.visible:
		codex_panel.visible = false
		if Game.current_mission != "" and not input_blocked():
			Game.main.capture_mouse()
		return
	for c in codex_container.get_children():
		c.queue_free()
	var by_theme: Dictionary = {}
	for e in Quiz.codex:
		var id := String(e.get("id", ""))
		if not Game.codex_unlocked.has(id):
			continue
		var t := String(e.get("theme", "?"))
		if not by_theme.has(t):
			by_theme[t] = []
		(by_theme[t] as Array).append(e)
	for t in by_theme.keys():
		var head := _label(codex_container, String(Quiz.themes.get(t, {"label": t}).get("label", t)),
			0, 0, 1180, 40, 28, Color(1, 0.6, 0.2), HORIZONTAL_ALIGNMENT_LEFT, true)
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for e in by_theme[t]:
			var l := _label(codex_container, String(e.get("title", "")) + " — " + String(e.get("text", "")),
				0, 0, 1180, 70, 19, Color(0.85, 0.93, 1.0))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if codex_container.get_children().is_empty():
		var l := _label(codex_container, "Aucune fiche débloquée. Ramassez des fragments mémoire et répondez correctement aux bornes.",
			0, 0, 1180, 80, 22, Color(0.7, 0.8, 0.9))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	codex_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ------------------------------------------------------------------ PAUSE
func _build_pause() -> void:
	pause_panel = _panel(root, "Pause", 0, 0, 0, 0, true, Color(0.01, 0.02, 0.04, 0.9))
	_label(pause_panel, "PAUSE", 0, 160, 1600, 80, 60, Color(1, 0.2, 0.2),
		HORIZONTAL_ALIGNMENT_CENTER, true)
	_button(pause_panel, "REPRENDRE", 620, 300, 360, 60, Callable(self, "toggle_pause"))
	_button(pause_panel, "RECOMMENCER LA MISSION", 620, 380, 360, 60, Callable(self, "_restart"))
	_button(pause_panel, "CLASSEUR [TAB]", 620, 460, 360, 60, Callable(self, "toggle_codex"))
	_button(pause_panel, "RETOUR AU MENU", 620, 540, 360, 60, Callable(self, "_menu"))
	pause_panel.visible = false


func _restart() -> void:
	restart_requested.emit()


func _menu() -> void:
	menu_requested.emit()


func toggle_pause() -> void:
	if quiz_panel.visible or death_panel.visible or result_panel.visible or menu_panel.visible:
		return
	pause_panel.visible = not pause_panel.visible
	if pause_panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not input_blocked():
		Game.main.capture_mouse()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var k := (event as InputEventKey).keycode
	if k == KEY_TAB and not menu_panel.visible and not result_panel.visible and not death_panel.visible:
		if not quiz_panel.visible:
			toggle_codex()
			get_viewport().set_input_as_handled()
	elif k == KEY_ESCAPE:
		if quiz_panel.visible:
			return
		if codex_panel.visible:
			toggle_codex()
			get_viewport().set_input_as_handled()
		else:
			toggle_pause()
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ BILAN
func _build_results() -> void:
	result_panel = _panel(root, "Results", 0, 0, 0, 0, true, Color(0.01, 0.02, 0.04, 0.97))
	_label(result_panel, "MISSION ACCOMPLIE", 0, 90, 1600, 80, 58,
		Color(0.25, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER, true)
	result_text = _label(result_panel, "", 380, 220, 840, 420, 27, Color.WHITE)
	_button(result_panel, "ENVIRONNEMENT SUIVANT", 560, 660, 480, 60,
		Callable(self, "_next"), Color(0.2, 0.9, 0.4, 0.9))
	_button(result_panel, "REJOUER", 620, 736, 360, 50, Callable(self, "_restart"))
	_button(result_panel, "MENU", 620, 800, 360, 50, Callable(self, "_menu"))
	result_panel.visible = false


func _next() -> void:
	next_requested.emit()
	Game.main.next_mission()


func show_results(r: Dictionary) -> void:
	hide_all()
	result_panel.visible = true
	var note := float(r.get("grade", 0.0))
	var mention := "PERFECT" if note >= 18.0 else ("BIEN" if note >= 14.0 else ("PASSABLE" if note >= 10.0 else "À RÉVISER"))
	result_text.text = "SCORE TOTAL        %d\n\n" % int(r.get("score", 0))
	result_text.text += "NOTE TECHNOLOGIE   %.1f / 20  (%s)\n" % [note, mention]
	result_text.text += "BORNES RÉUSSIES    %d / %d\n" % [int(r.get("correct", 0)), int(r.get("total", 0))]
	result_text.text += "SENTINELLES        %d\n" % int(r.get("kills", 0))
	result_text.text += "FRAGMENTS          %d\n\n" % int(r.get("chips", 0))
	var nxt := String(r.get("next", ""))
	result_text.text += ("NOUVEL ENVIRONNEMENT DÉBLOQUÉ : " + nxt.to_upper()) if nxt != "" else "CAMPAGNE TERMINÉE — SKYNET NEUTRALISÉ"
	_refresh_teacher()


# ------------------------------------------------------------------ DÉCÈS
func _build_death() -> void:
	death_panel = _panel(root, "Death", 0, 0, 0, 0, true, Color(0.08, 0.0, 0.0, 0.92))
	_label(death_panel, "INTÉGRITÉ CRITIQUE", 0, 250, 1600, 90, 64,
		Color(1.0, 0.15, 0.15), HORIZONTAL_ALIGNMENT_CENTER, true)
	_label(death_panel, "Le système d'infiltration a été détruit. Réessayez — chaque tentative apprend quelque chose.",
		0, 360, 1600, 50, 23, Color(0.9, 0.7, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	_button(death_panel, "RECOMMENCER", 620, 470, 360, 62, Callable(self, "_restart"), Color(1, 0.2, 0.2, 0.9))
	_button(death_panel, "MENU", 620, 554, 360, 56, Callable(self, "_menu"))
	death_panel.visible = false


func show_death() -> void:
	death_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ---------------------------------------------------------- MODE PROFESSEUR
func _build_teacher() -> void:
	teacher_panel = _panel(root, "Teacher", 0, 0, 0, 0, true, Color(0.01, 0.02, 0.04, 0.97))
	_label(teacher_panel, "MODE PROFESSEUR — SUIVI PÉDAGOGIQUE", 0, 70, 1600, 70, 44,
		Color(0.25, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, true)
	teacher_text = _label(teacher_panel, "", 200, 180, 1200, 460, 25, Color.WHITE)
	_button(teacher_panel, "EXPORTER LES RÉSULTATS (CSV)", 500, 660, 600, 62,
		Callable(self, "_export"))
	_button(teacher_panel, "RETOUR", 660, 750, 280, 56, Callable(self, "_back_to_menu"))
	teacher_panel.visible = false


func _refresh_teacher() -> void:
	if teacher_text == null:
		return
	var per: Dictionary = {}
	for q in Quiz.questions:
		var t := String(q.get("theme", "?"))
		if not per.has(t):
			per[t] = 0
		per[t] = int(per[t]) + 1
	teacher_text.text = "ÉLÈVE — NIVEAU %d | SCORE %d | XP %d\n\n" % [Game.level, Game.score, Game.xp]
	teacher_text.text += "Questions posées : %d | Réussites : %d | Note : %.1f/20\n" % [
		Game.total_questions, Game.correct_questions, Quiz.grade()]
	teacher_text.text += "Précision au tir : %.1f %%\n" % (100.0 * float(Game.stats.get("hits", 0)) / maxf(1.0, float(Game.stats.get("shots", 0))))
	teacher_text.text += "Fragments : %d | Fiches codex : %d | Environnements : %d/5\n\n" % [
		Game.memory_chips, Game.codex_unlocked.size(), Game.completed_missions.size()]
	teacher_text.text += "BANQUE BO (par thème) :\n"
	for t in per.keys():
		var label := String(Quiz.themes.get(t, {"label": t}).get("label", t))
		teacher_text.text += "  • %s : %d questions\n" % [label, int(per[t])]
	teacher_text.text += "\nRéférentiel : BO n°9 du 29/02/2024 — programme technologie cycle 4."


func _export() -> void:
	_refresh_teacher()
	teacher_export_requested.emit()
