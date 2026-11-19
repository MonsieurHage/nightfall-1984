extends Interactable
class_name Door

## Porte coulissante, verrouillée par un objectif ou une borne.

var required_objective: String = ""
var open: bool = false
var slide_height: float = 3.4


func _ready() -> void:
	prompt_text = "Ouvrir la porte"


func interact(_player: Node) -> void:
	if open:
		return
	if required_objective != "" and not Missions.is_done(required_objective):
		Game.notify("ACCÈS REFUSÉ — OBJECTIF NON REMPLI : " + required_objective.to_upper(), 2.5)
		Audio.play_sfx("quiz_fail", -6.0)
		return
	open_door()


func open_door() -> void:
	if open:
		return
	open = true
	used = true
	Audio.play_sfx_at("door", global_position, 0.0)
	var start := position
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position", start + Vector3(0, slide_height, 0), 1.1)
	tw.tween_callback(func() -> void:
		collision_layer = 0
		collision_mask = 0
	)
