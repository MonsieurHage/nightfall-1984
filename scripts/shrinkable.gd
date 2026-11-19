extends Interactable
class_name Shrinkable

## Objet rétréci par le rayon Q-84 : permet de le glisser dans un conduit.

var shrunk: bool = false
var original_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	original_scale = scale
	prompt_text = "Déplacer le conteneur"


func shrink(_duration: float = 10.0) -> void:
	if shrunk:
		return
	shrunk = true
	collision_layer = 0
	collision_mask = 0
	var tw := create_tween()
	tw.tween_property(self, "scale", original_scale * 0.32, 0.4)
	Audio.play_sfx("shrink", -3.0)
	Game.notify("CONTENEUR RÉTRÉCI — passage dégagé", 2.5)
	prompt_text = "Pousser le mini-conteneur"


func interact(_player: Node) -> void:
	if not shrunk:
		Game.notify("Trop lourd. Utilisez le rayon rétrécissant [3] puis tirez dessus.", 3.0)
		return
	var tw := create_tween()
	tw.tween_property(self, "position", position + Vector3(1.6, 0, 0), 0.5)
	prompt_text = ""
	Game.notify("CONDUIT DÉGAGÉ", 1.8)
