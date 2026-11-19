extends Node

## Suivi des missions et déblocage des environnements.

signal mission_started(mission: Dictionary)
signal objective_progress(id: String, current: int, target: int)
signal objective_completed(id: String)
signal mission_completed(mission_id: String, results: Dictionary)

var missions: Dictionary = {}
var current: Dictionary = {}
var progress: Dictionary = {}
var current_id: String = ""


func _ready() -> void:
	var data: Dictionary = Game.load_json("res://data/missions.json")
	for m in data.get("missions", []):
		missions[String(m.get("id", ""))] = m


func start(id: String) -> void:
	if not missions.has(id):
		push_error("Mission inconnue: " + id)
		return
	current_id = id
	current = missions[id]
	Game.current_mission = id
	progress.clear()
	for o in current.get("objectives", []):
		progress[String(o.get("id", ""))] = 0
	mission_started.emit(current)
	refresh_ui()
	Game.save_game()


func increment(id: String, amount: int = 1) -> void:
	if not progress.has(id):
		return
	var obj := _objective(id)
	var target := maxi(1, int(obj.get("target", 1)))
	progress[id] = mini(target, int(progress[id]) + amount)
	objective_progress.emit(id, progress[id], target)
	if progress[id] >= target and not bool(obj.get("_done", false)):
		obj["_done"] = true
		objective_completed.emit(id)
		Game.add_score(int(obj.get("score", 250)))
		Game.add_xp(25)
		Audio.play_sfx("quiz_ok", -6.0)
	refresh_ui()
	check_complete()


func is_done(id: String) -> bool:
	var obj := _objective(id)
	return bool(obj.get("_done", false))


func all_done() -> bool:
	for o in current.get("objectives", []):
		if o.get("id", "") == "extraction":
			continue
		if not bool(o.get("_done", false)):
			return false
	return not current.is_empty()


func _objective(id: String) -> Dictionary:
	for o in current.get("objectives", []):
		if String(o.get("id", "")) == id:
			return o
	return {}


func check_complete() -> void:
	if current.is_empty():
		return
	for o in current.get("objectives", []):
		if not bool(o.get("_done", false)):
			return
	complete()


func complete() -> void:
	if current.is_empty():
		return
	var mid := current_id
	if not Game.completed_missions.has(mid):
		Game.completed_missions.append(mid)
	var next_id := String(current.get("unlocks", ""))
	if next_id != "":
		Game.unlock_mission(next_id)
	Game.add_score(int(current.get("reward_score", 1000)))
	Game.add_xp(int(current.get("reward_xp", 120)))
	var results := {
		"mission": mid,
		"score": Game.score,
		"grade": Quiz.grade(),
		"correct": Game.correct_questions,
		"total": Game.total_questions,
		"kills": int(Game.stats.get("kills", 0)),
		"chips": Game.memory_chips,
		"next": next_id
	}
	Game.save_game()
	mission_completed.emit(mid, results)
	Game.mission_completed.emit(mid, results)
	current = {}


func refresh_ui() -> void:
	if Game.ui and Game.ui.has_method("set_objectives"):
		Game.ui.set_objectives(objective_text())


func objective_text() -> String:
	var lines: Array[String] = []
	for o in current.get("objectives", []):
		var id := String(o.get("id", ""))
		var target := maxi(1, int(o.get("target", 1)))
		var done := bool(o.get("_done", false))
		var mark := "[X]" if done else "[ ]"
		lines.append("%s %s (%d/%d)" % [mark, String(o.get("label", id)), int(progress.get(id, 0)), target])
	return "\n".join(lines)


func brief() -> String:
	return String(current.get("brief", ""))
