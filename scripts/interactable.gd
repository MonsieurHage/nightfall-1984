extends StaticBody3D
class_name Interactable

## Base des objets interactifs détectés par le raycast du joueur.

var prompt_text: String = "Interagir"
var used: bool = false

func get_prompt() -> String:
	if used:
		return ""
	return "[E] " + prompt_text


func interact(_player: Node) -> void:
	pass


func mark_used() -> void:
	used = true
	collision_layer = 0
	collision_mask = 0
