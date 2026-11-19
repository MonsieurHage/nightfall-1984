extends Interactable
class_name ExitPoint

var beacon: OmniLight3D = null
var ring: MeshInstance3D = null
var exit_id: String = "extraction"


func _ready() -> void:
	prompt_text = "Atteindre l'extraction"
	beacon = OmniLight3D.new()
	beacon.light_color = Color(0.2, 0.9, 1.0)
	beacon.light_energy = 3.0
	beacon.omni_range = 9.0
	beacon.position.y = 1.0
	add_child(beacon)
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	ring.mesh = torus
	ring.material_override = Game.material("neon_cyan")
	ring.rotation.x = PI * 0.5
	ring.position.y = 0.08
	add_child(ring)


func _process(delta: float) -> void:
	if ring:
		ring.rotation.z += delta * 0.8
		ring.position.y = 0.08 + sin(Time.get_ticks_msec() / 400.0) * 0.06
	if beacon:
		beacon.light_energy = 2.0 + sin(Time.get_ticks_msec() / 300.0) * 1.2
	var ready := Missions.all_done()
	prompt_text = "Activer l'extraction" if ready else "Extraction verrouillée — objectifs incomplets"


func interact(_player: Node) -> void:
	if not Missions.all_done():
		Game.notify("EXTRACTION VERROUILLÉE — TERMINEZ LES OBJECTIFS", 2.5)
		Audio.play_sfx("quiz_fail", -8.0)
		return
	Missions.increment(exit_id)
	Audio.play_sfx("pickup", 2.0)
