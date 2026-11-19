extends Interactable
class_name JetHazard

## Jet de vapeur / décharge électrique. Un robinet peut le couper temporairement.

var active: bool = true
var period: float = 4.5
var damage: float = 22.0
var visual: MeshInstance3D = null
var light: OmniLight3D = null
var _timer: float = 0.0
var _hit_cd: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	prompt_text = "Jet actif — coupez la vanne"
	_phase = randf() * period
	var cone := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.06
	cyl.height = 3.0
	cone.mesh = cyl
	cone.material_override = Game.material("glass")
	cone.position.y = 1.5
	add_child(cone)
	visual = cone
	light = OmniLight3D.new()
	light.light_color = Color(0.5, 0.85, 1.0)
	light.light_energy = 1.4
	light.omni_range = 5.0
	light.position.y = 1.2
	add_child(light)


func _process(delta: float) -> void:
	_phase += delta
	active = fmod(_phase, period) < period * 0.45
	if visual:
		visual.visible = active
		visual.scale.y = 0.85 + sin(_phase * 12.0) * 0.15
	if light:
		light.visible = active
	_hit_cd = maxf(0.0, _hit_cd - delta)
	if active and _hit_cd <= 0.0 and Game.player and is_instance_valid(Game.player):
		var d := global_position.distance_to(Game.player.global_position)
		if d < 1.7:
			_hit_cd = 0.55
			Game.player.take_damage(damage, self)
			Audio.play_sfx("jet", -6.0)


func disable_for(seconds: float) -> void:
	_phase = period * 0.5
	var t := create_tween()
	t.tween_interval(seconds)
	t.tween_callback(func() -> void: _phase = 0.0)
	Game.notify("JET NEUTRALISÉ %d s" % int(seconds), 1.8)


func interact(_player: Node) -> void:
	Game.notify("UN ROBINET PERMET DE COUPER CE JET", 2.0)
