extends Interactable
class_name Valve

var linked_jet: Node = null
var cooldown: float = 0.0


func _ready() -> void:
	prompt_text = "Actionner la vanne (coupe le jet 8 s)"


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)


func interact(_player: Node) -> void:
	if cooldown > 0.0:
		Game.notify("VANNE EN REFROIDISSEMENT", 1.4)
		return
	cooldown = 10.0
	Audio.play_sfx("door", -5.0, 1.5)
	if linked_jet and is_instance_valid(linked_jet) and linked_jet.has_method("disable_for"):
		linked_jet.disable_for(8.0)
	rotation.z += PI * 0.5
