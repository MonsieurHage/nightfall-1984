extends Interactable
class_name Terminal

## Borne pédagogique : pose une question liée au BO et valide un objectif.

var context: String = "energie"
var themes: Array = []
var objective_id: String = "quiz"
var solved: bool = false
var solving: bool = false
var linked_door: Node = null
var linked_boss: Node = null
var label_text: String = "TERMINAL DE DIAGNOSTIC"


func _ready() -> void:
	prompt_text = "Interroger " + label_text


func interact(_player: Node) -> void:
	if solved or solving:
		return
	solving = true
	Game.notify("CONNEXION À LA BORNE PÉDAGOGIQUE...", 1.2)
	Audio.play_sfx("ui", -4.0)
	Quiz.request(context, themes)
	var cb := Callable(self, "_on_answered")
	Quiz.answered.connect(cb, CONNECT_ONE_SHOT)


func _on_answered(result: Dictionary) -> void:
	solving = false
	if bool(result.get("ok", false)):
		solved = true
		mark_used()
		Missions.increment(objective_id)
		Game.add_score(150)
		if linked_door and is_instance_valid(linked_door) and linked_door.has_method("open_door"):
			linked_door.open_door()
		if linked_boss and is_instance_valid(linked_boss) and linked_boss.has_method("disable_terminal"):
			linked_boss.disable_terminal()
		_set_color(Game.material("neon_green"))
		Game.notify("RÉPONSE CORRECTE — ACCÈS AUTORISÉ", 2.5)
	else:
		Game.add_score(-60)
		if Game.current_level and Game.current_level.has_method("trigger_alarm"):
			Game.current_level.trigger_alarm(global_position)
		Game.notify("RÉPONSE INCORRECTE — ALARME DÉCLENCHÉE", 3.0)


func _set_color(mat: Material) -> void:
	for c in find_children("*", "MeshInstance3D", true, false):
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = mat
