extends Terminal
class_name Breaker

## Disjoncteur : la séquence d'activation doit respecter la chaîne énergétique.

var order_index: int = 0
var level_ref: Node = null


func _ready() -> void:
	prompt_text = "Actionner le disjoncteur %d" % (order_index + 1)


func _on_answered(result: Dictionary) -> void:
	solving = false
	if not bool(result.get("ok", false)):
		Game.add_score(-60)
		if level_ref and level_ref.has_method("trigger_alarm"):
			level_ref.trigger_alarm(global_position)
		Game.notify("ERREUR DE SÉQUENCE — ALARME", 3.0)
		return
	if level_ref and int(level_ref.get("breaker_step")) != order_index:
		Game.add_score(-40)
		if level_ref.has_method("trigger_alarm"):
			level_ref.trigger_alarm(global_position)
		Game.notify("ORDRE INCORRECT — suivez la chaîne : production → transport → distribution", 3.5)
		return
	if level_ref:
		level_ref.set("breaker_step", order_index + 1)
	solved = true
	mark_used()
	Missions.increment("breakers")
	Game.add_score(200)
	_set_color(Game.material("neon_green"))
	Game.notify("DISJONCTEUR %d ACTIVÉ" % (order_index + 1), 2.0)
