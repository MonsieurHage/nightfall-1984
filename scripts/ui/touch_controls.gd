extends CanvasLayer
class_name TouchControls

## Commandes tactiles pour mobile / tablette : joystick de déplacement,
## zone de regard, boutons d'action. Sous la couche UI (layer 15).

var root: Control
var look_pad: Control
var joy_base: Control
var joy_knob: ColorRect
var joy_center: Vector2 = Vector2(100, 100)
var joy_id: int = -1
var look_id: int = -1
var look_last: Vector2 = Vector2.ZERO
var font_main: Font


func _ready() -> void:
	layer = 15
	if ResourceLoader.exists("res://assets/fonts/Rajdhani-SemiBold.ttf"):
		font_main = load("res://assets/fonts/Rajdhani-SemiBold.ttf")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	look_pad = Control.new()
	look_pad.name = "LookPad"
	look_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	look_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	look_pad.gui_input.connect(_on_look_input)
	root.add_child(look_pad)

	_build_joystick()
	_build_buttons()


func _place(c: Control, preset: int, l: float, t: float, r: float, b: float) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


func _build_joystick() -> void:
	joy_base = Control.new()
	joy_base.name = "Joystick"
	_place(joy_base, Control.PRESET_BOTTOM_LEFT, 30, -262, 250, -42)
	joy_base.mouse_filter = Control.MOUSE_FILTER_STOP
	joy_base.gui_input.connect(_on_joy_input)
	joy_base.draw.connect(_draw_joystick)
	root.add_child(joy_base)
	joy_knob = ColorRect.new()
	joy_knob.color = Color(0.2, 0.85, 1.0, 0.85)
	joy_knob.set_anchors_preset(Control.PRESET_CENTER)
	joy_knob.offset_left = -28
	joy_knob.offset_top = -28
	joy_knob.offset_right = 28
	joy_knob.offset_bottom = 28
	joy_base.add_child(joy_knob)


func _draw_joystick() -> void:
	var c := Vector2(100, 100)
	joy_base.draw_circle(c, 92, Color(0.05, 0.12, 0.18, 0.45))
	joy_base.draw_arc(c, 92, 0.0, TAU, 48, Color(0.25, 0.8, 1.0, 0.6), 3.0)


func _button(text: String, preset: int, l: float, t: float, r: float, b: float,
		action: String) -> Button:
	var btn := Button.new()
	btn.text = text
	_place(btn, preset, l, t, r, b)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	if font_main:
		btn.add_theme_font_override("font", font_main)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.09, 0.14, 0.78)
	sb.border_color = Color(0.2, 0.8, 1.0, 0.75)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(36)
	btn.add_theme_stylebox_override("normal", sb)
	var sbp := sb.duplicate() as StyleBoxFlat
	sbp.bg_color = Color(0.1, 0.35, 0.45, 0.95)
	btn.add_theme_stylebox_override("pressed", sbp)
	if action == "PAUSE":
		btn.connect("pressed", Callable(self, "_pause"))
	elif action == "CODEX":
		btn.connect("pressed", Callable(self, "_codex"))
	elif action == "WEAPON":
		btn.connect("pressed", Callable(self, "_weapon"))
	else:
		btn.button_down.connect(func() -> void: Input.action_press(action))
		btn.button_up.connect(func() -> void: Input.action_release(action))
	root.add_child(btn)
	return btn


func _build_buttons() -> void:
	_button("FEU", Control.PRESET_BOTTOM_RIGHT, -200, -228, -30, -98, "fire")
	_button("ACTION", Control.PRESET_BOTTOM_RIGHT, -370, -158, -220, -68, "interact")
	_button("RECH.", Control.PRESET_BOTTOM_RIGHT, -370, -262, -220, -172, "reload")
	_button("SAUT", Control.PRESET_BOTTOM_RIGHT, -560, -150, -390, -60, "jump")
	_button("SPECIAL", Control.PRESET_BOTTOM_RIGHT, -560, -256, -390, -166, "special")
	_button("LAMPE", Control.PRESET_BOTTOM_RIGHT, -360, -356, -210, -278, "flashlight")
	_button("ARME", Control.PRESET_BOTTOM_RIGHT, -190, -352, -30, -278, "WEAPON")
	_button("ACCROUP.", Control.PRESET_BOTTOM_LEFT, 260, -160, 450, -70, "crouch")
	_button("COURIR", Control.PRESET_BOTTOM_LEFT, 260, -266, 450, -176, "sprint")
	_button("PAUSE", Control.PRESET_TOP_RIGHT, -190, 24, -30, 84, "PAUSE")
	_button("CODEX", Control.PRESET_TOP_RIGHT, -360, 24, -200, 84, "CODEX")


func _on_look_input(event: InputEvent) -> void:
	if Game.ui != null and Game.ui.input_blocked():
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and look_id == -1:
			look_id = t.index
			look_last = t.position
		elif not t.pressed and t.index == look_id:
			look_id = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == look_id:
			Game.touch_look += d.position - look_last
			look_last = d.position
	elif event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if (m.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			Game.touch_look += m.relative


func _on_joy_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and joy_id == -1:
			joy_id = t.index
			_update_knob(t.position)
		elif not t.pressed and t.index == joy_id:
			joy_id = -1
			_reset_joy()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == joy_id:
			_update_knob(d.position)
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT and m.pressed:
			joy_id = 999
			_update_knob(m.position)
		elif m.button_index == MOUSE_BUTTON_LEFT and not m.pressed:
			joy_id = -1
			_reset_joy()
	elif event is InputEventMouseMotion and joy_id == 999:
		_update_knob((event as InputEventMouseMotion).position)


func _update_knob(pos: Vector2) -> void:
	var delta := (pos - joy_center).limit_length(84.0)
	joy_knob.offset_left = delta.x - 28
	joy_knob.offset_top = delta.y - 28
	joy_knob.offset_right = delta.x + 28
	joy_knob.offset_bottom = delta.y + 28
	Game.touch_move = Vector2(delta.x / 78.0, delta.y / 78.0).limit_length(1.0)


func _reset_joy() -> void:
	joy_knob.offset_left = -28
	joy_knob.offset_top = -28
	joy_knob.offset_right = 28
	joy_knob.offset_bottom = 28
	Game.touch_move = Vector2.ZERO


func _pause() -> void:
	if Game.ui:
		Game.ui.toggle_pause()


func _codex() -> void:
	if Game.ui:
		Game.ui.toggle_codex()


func _weapon() -> void:
	if Game.player and Game.player.has_method("cycle_weapon"):
		Game.player.cycle_weapon()
