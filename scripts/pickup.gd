extends Interactable
class_name Pickup

## Fragments mémoire, munitions, soins, batteries, fusible, carte, armes.

var kind: String = "chip"


func _ready() -> void:
	prompt_text = {
		"chip": "Récupérer le fragment mémoire",
		"ammo": "Récupérer des munitions",
		"health": "Utiliser le kit de réparation",
		"battery": "Récupérer la batterie",
		"fuse": "Récupérer le fusible de puissance",
		"keycard": "Récupérer la carte d'accès",
		"rifle": "Ramasser le fusil plasma AR-84",
		"shrink": "Ramasser le réducteur quantique Q-84"
	}.get(kind, "Récupérer l'objet")


func interact(player: Node) -> void:
	if used:
		return
	match kind:
		"chip":
			Game.memory_chips += 1
			Game.add_score(120)
			Game.register_codex(_random_codex())
			Missions.increment("chips")
			Game.notify("FRAGMENT MÉMOIRE %d — savoie technologique récupérée" % Game.memory_chips, 2.2)
		"ammo":
			player.give_ammo(30)
		"health":
			player.heal(38.0)
			Game.notify("INTÉGRITÉ +38", 1.5)
		"battery":
			Missions.increment("batteries")
			Game.notify("BATTERIE DE SECOURS RÉCUPÉRÉE", 2.0)
		"fuse":
			Missions.increment("fuse")
			Game.notify("FUSIBLE DE PUISSANCE RÉCUPÉRÉ", 2.0)
		"keycard":
			Missions.increment("keycard")
			Game.notify("CARTE D'ACCÈS NIVEAU 4 OBTENUE", 2.5)
		"rifle":
			player.unlock_weapon(1)
		"shrink":
			player.unlock_weapon(2)
	Audio.play_sfx("pickup")
	mark_used()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.25)
	tw.tween_property(self, "position", position + Vector3(0, 0.6, 0), 0.25)
	tw.tween_callback(queue_free)


func _random_codex() -> String:
	var entries: Array = Quiz.codex
	if entries.is_empty():
		return ""
	var pool: Array[String] = []
	for e in entries:
		var id := String(e.get("id", ""))
		if id != "" and not Game.codex_unlocked.has(id):
			pool.append(id)
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]
