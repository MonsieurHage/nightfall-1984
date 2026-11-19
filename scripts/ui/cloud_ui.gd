extends CanvasLayer
class_name CloudUI

## Écrans réseau : création de compte, connexion, reprise, classement.
## Au-dessus du menu principal (layer 30).

signal login_succeeded(pseudo: String)

var root: Control
var auth_panel: Panel
var board_panel: Panel
var pseudo_edit: LineEdit
var pass_edit: LineEdit
var status_label: Label
var account_label: Label
var board_list: VBoxContainer
var signout_button: Button
var font_main: Font
var font_title: Font
var _busy: bool = false


func _ready() -> void:
	layer = 30
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

	_build_auth()
	_build_board()

	Cloud.login_succeeded.connect(_on_login_succeeded)
	Cloud.auth_changed.connect(_on_auth_changed)
	Cloud.leaderboard_ready.connect(_render_board)
	Cloud.cloud_error.connect(func(t: String) -> void: _status("ERREUR RESEAU : " + t, true))
	_on_auth_changed(Cloud.signed_in, Cloud.pseudo)
	visible = false


func _style(bg: Color, border: Color = Color(0.1, 0.75, 0.9, 0.85)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb


func _panel(name: String, w: float, h: float) -> Panel:
	var p := Panel.new()
	p.name = name
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.offset_left = -w / 2.0
	p.offset_top = -h / 2.0
	p.offset_right = w / 2.0
	p.offset_bottom = h / 2.0
	p.add_theme_stylebox_override("panel", _style(Color(0.01, 0.02, 0.045, 0.98)))
	root.add_child(p)
	p.visible = false
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
		cb: Callable, accent: Color = Color(0.1, 0.75, 0.9, 0.9)) -> Button:
	var b := Button.new()
	b.text = text
	b.set_anchors_preset(Control.PRESET_TOP_LEFT)
	b.offset_left = x
	b.offset_top = y
	b.offset_right = x + w
	b.offset_bottom = y + h
	b.add_theme_stylebox_override("normal", _style(Color(0.02, 0.06, 0.1, 0.95), accent))
	b.add_theme_stylebox_override("hover", _style(Color(0.05, 0.16, 0.22, 1.0), Color.WHITE))
	b.add_theme_stylebox_override("pressed", _style(Color(0.08, 0.22, 0.3, 1.0), Color.WHITE))
	if font_main:
		b.add_theme_font_override("font", font_main)
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
	b.connect("pressed", cb)
	parent.add_child(b)
	return b


func _line(parent: Control, placeholder: String, x: float, y: float, w: float, secret: bool = false) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.set_anchors_preset(Control.PRESET_TOP_LEFT)
	e.offset_left = x
	e.offset_top = y
	e.offset_right = x + w
	e.offset_bottom = y + 52
	e.add_theme_font_size_override("font_size", 22)
	e.add_theme_color_override("font_color", Color(0.9, 0.97, 1.0))
	parent.add_child(e)
	return e


func _build_auth() -> void:
	auth_panel = _panel("Auth", 760, 660)
	_label(auth_panel, "RÉSEAU NIGHTFALL", 0, 24, 716, 60, 42,
		Color(1.0, 0.2, 0.22), HORIZONTAL_ALIGNMENT_CENTER, true)
	account_label = _label(auth_panel, "", 24, 92, 668, 34, 19,
		Color(0.3, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	pseudo_edit = _line(auth_panel, "PSEUDO (3-20 caractères)", 78, 150, 604)
	pass_edit = _line(auth_panel, "MOT DE PASSE (6 caractères minimum)", 78, 220, 604, true)
	_button(auth_panel, "SE CONNECTER", 78, 300, 290, 56, Callable(self, "_do_sign_in"),
		Color(0.15, 0.85, 0.5, 0.95))
	_button(auth_panel, "CRÉER UN COMPTE", 390, 300, 292, 56, Callable(self, "_do_sign_up"))
	status_label = _label(auth_panel, "", 40, 380, 680, 62, 19,
		Color(0.95, 0.78, 0.35), HORIZONTAL_ALIGNMENT_CENTER)
	_button(auth_panel, "CLASSEMENT", 78, 462, 290, 54, Callable(self, "show_board"),
		Color(0.75, 0.45, 1.0, 0.9))
	_button(auth_panel, "REPRENDRE MA PARTIE", 390, 462, 292, 54, Callable(self, "_resume"),
		Color(1.0, 0.6, 0.15, 0.9))
	signout_button = _button(auth_panel, "SE DÉCONNECTER", 78, 534, 290, 52,
		Callable(self, "_do_sign_out"), Color(0.8, 0.3, 0.3, 0.9))
	signout_button.visible = false
	_button(auth_panel, "RETOUR / JOUER SANS COMPTE", 390, 534, 292, 52, Callable(self, "hide"))
	_label(auth_panel, "La sauvegarde en ligne est active dès la connexion.", 24, 610, 668, 30,
		17, Color(0.55, 0.7, 0.82), HORIZONTAL_ALIGNMENT_CENTER)


func _build_board() -> void:
	board_panel = _panel("Leaderboard", 820, 720)
	_label(board_panel, "CLASSEMENT DES AGENTS", 0, 24, 776, 60, 42,
		Color(0.25, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, true)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scroll.offset_left = 34
	scroll.offset_top = 104
	scroll.offset_right = 786
	scroll.offset_bottom = 620
	board_list = VBoxContainer.new()
	board_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_list.add_theme_constant_override("separation", 6)
	scroll.add_child(board_list)
	board_panel.add_child(scroll)
	_button(board_panel, "RETOUR", 268, 646, 284, 52, Callable(self, "hide"))


func show_auth() -> void:
	hide()
	visible = true
	auth_panel.visible = true
	_on_auth_changed(Cloud.signed_in, Cloud.pseudo)
	_status("" if Cloud.configured else "Supabase non configuré : mode hors-ligne disponible.",
		not Cloud.configured)


func show_board() -> void:
	hide()
	visible = true
	board_panel.visible = true
	_render_placeholder()
	if Cloud.configured:
		Cloud.fetch_leaderboard()


func _render_placeholder() -> void:
	for c in board_list.get_children():
		c.queue_free()
	var l := _label(board_list, "CHARGEMENT DU CLASSEMENT...", 0, 0, 700, 44, 22,
		Color(0.5, 0.8, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size = Vector2(700, 44)


func _render_board(rows: Array[Dictionary]) -> void:
	if not board_panel.visible:
		return
	for c in board_list.get_children():
		c.queue_free()
	var i := 1
	for row in rows:
		var who := String(row.get("pseudo", "?"))
		var hb := HBoxContainer.new()
		hb.custom_minimum_size = Vector2(700, 42)
		hb.add_theme_constant_override("separation", 12)
		var accent := Color(1.0, 0.2, 0.22) if who == "monsieurhage" else Color(0.75, 0.9, 1.0)
		if who == Cloud.pseudo and Cloud.pseudo != "":
			accent = Color(0.3, 1.0, 0.55)
		var rank := _label(hb, "%2d." % i, 0, 0, 56, 40, 22, accent)
		rank.custom_minimum_size = Vector2(56, 40)
		var name := _label(hb, who, 0, 0, 420, 40, 24, accent)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sc := _label(hb, "%d pts" % int(row.get("score", 0)), 0, 0, 160, 40, 22, accent,
			HORIZONTAL_ALIGNMENT_RIGHT)
		sc.custom_minimum_size = Vector2(160, 40)
		board_list.add_child(hb)
		i += 1
	if rows.is_empty():
		_label(board_list, "AUCUN AGENT ENREGISTRÉ", 0, 0, 700, 44, 22,
			Color(0.7, 0.7, 0.7), HORIZONTAL_ALIGNMENT_CENTER)


func _status(text: String, error: bool = false) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color",
		Color(1.0, 0.35, 0.3) if error else Color(0.95, 0.78, 0.35))


func _set_busy(value: bool) -> void:
	_busy = value
	for b in auth_panel.get_children():
		if b is Button:
			(b as Button).disabled = value


func _do_sign_in() -> void:
	if _busy:
		return
	_set_busy(true)
	_status("CONNEXION EN COURS...")
	var r: Dictionary = await Cloud.sign_in(pseudo_edit.text, pass_edit.text)
	_set_busy(false)
	if not bool(r.get("ok", false)):
		_status(String(r.get("error", "Échec de connexion")), true)


func _do_sign_up() -> void:
	if _busy:
		return
	_set_busy(true)
	_status("CRÉATION DU COMPTE...")
	var r: Dictionary = await Cloud.sign_up(pseudo_edit.text, pass_edit.text)
	_set_busy(false)
	if not bool(r.get("ok", false)):
		_status(String(r.get("error", "Échec d'inscription")), true)
	elif bool(r.get("need_confirm", false)):
		_status("Confirmez votre email dans Supabase, puis reconnectez-vous.", true)


func _do_sign_out() -> void:
	Cloud.sign_out()
	Game.ui.show_main_menu()
	hide()
	Game.notify("DÉCONNECTÉ", 3.0)


func _resume() -> void:
	hide()
	Game.main.resume_game()


func _on_login_succeeded(p: String) -> void:
	hide()
	login_succeeded.emit(p)


func _on_auth_changed(is_in: bool, p: String) -> void:
	account_label.text = ("CONNECTÉ : " + p) if is_in else "COMPTE REQUIS POUR LA SAUVEGARDE EN LIGNE"
	if is_in:
		signout_button.visible = true
		pseudo_edit.text = ""
		pass_edit.text = ""
	else:
		signout_button.visible = false
