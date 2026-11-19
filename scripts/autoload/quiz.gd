extends Node

## Banque de questions conforme au BO technologie cycle 4 (arrêté 29/02/2024).

signal question_requested(question: Dictionary)
signal answered(result: Dictionary)

var questions: Array[Dictionary] = []
var themes: Dictionary = {}
var codex: Array[Dictionary] = []
var by_context: Dictionary = {}
var by_theme: Dictionary = {}
var recent: Array[String] = []
var current: Dictionary = {}
var asked_session: Dictionary = {}


func _ready() -> void:
	var qdata: Dictionary = Game.load_json("res://data/questions.json")
	for t in qdata.get("themes", []):
		themes[t.get("id", "")] = t
	for q in qdata.get("questions", []):
		if q.get("id", "") == "" or q.get("options", []).size() != 4:
			continue
		questions.append(q)
		var ctx := String(q.get("contexte", "projet"))
		var th := String(q.get("theme", "projet"))
		if not by_context.has(ctx):
			by_context[ctx] = []
		if not by_theme.has(th):
			by_theme[th] = []
		(by_context[ctx] as Array).append(q)
		(by_theme[th] as Array).append(q)
	var cdata: Dictionary = Game.load_json("res://data/codex.json")
	for e in cdata.get("entries", []):
		codex.append(e)
	if questions.is_empty():
		push_warning("Banque de questions vide : les bornes utiliseront des questions de secours.")
		_install_fallbacks()


func _install_fallbacks() -> void:
	var fb := [
		{"id": "fb1", "theme": "energie", "niveau": "4e", "difficulte": 1,
		 "prompt": "Dans une chaîne énergétique, quel élément convertit l'énergie électrique en énergie mécanique ?",
		 "options": ["Un moteur", "Un interrupteur", "Un capteur", "Un transformateur"],
		 "answer": 0, "explication": "Le moteur est l'actionneur qui transforme l'énergie électrique en mouvement (BO cycle 4, champ Énergie).",
		 "bo_ref": "BO n°9 du 29/02/2024 — Énergie", "contexte": "energie", "tags": ["moteur"], "score": 100},
		{"id": "fb2", "theme": "information", "niveau": "4e", "difficulte": 1,
		 "prompt": "Quel protocole est utilisé pour transmettre des pages web sur Internet ?",
		 "options": ["HTTP", "USB", "HDMI", "Bluetooth"],
		 "answer": 0, "explication": "HTTP (HyperText Transfer Protocol) transporte les ressources du web ; il s'appuie sur TCP/IP (BO cycle 4, champ Information).",
		 "bo_ref": "BO n°9 du 29/02/2024 — Information", "contexte": "terminal", "tags": ["réseau"], "score": 100}
	]
	for q in fb:
		questions.append(q)
		var ctx := String(q["contexte"])
		var th := String(q["theme"])
		if not by_context.has(ctx): by_context[ctx] = []
		if not by_theme.has(th): by_theme[th] = []
		(by_context[ctx] as Array).append(q)
		(by_theme[th] as Array).append(q)


func request(context: String = "projet", allowed_themes: Array = [], force_id: String = "") -> Dictionary:
	var pool: Array = []
	if force_id != "":
		for q in questions:
			if q.get("id", "") == force_id:
				pool = [q]
				break
	if pool.is_empty() and allowed_themes.size() > 0:
		for th in allowed_themes:
			if by_theme.has(th):
				pool.append_array(by_theme[th])
	if pool.is_empty() and by_context.has(context):
		pool = by_context[context]
	if pool.is_empty():
		pool = questions
	if pool.is_empty():
		return {}
	# Préfère les questions pas encore vues, puis les plus anciennes.
	var fresh: Array[Dictionary] = []
	var old: Array[Dictionary] = []
	for q in pool:
		var id := String(q.get("id", ""))
		if recent.has(id) or asked_session.get(id, 0) >= 2:
			old.append(q)
		else:
			fresh.append(q)
	var chosen: Dictionary = (fresh if not fresh.is_empty() else old)[randi() % maxi(1, (fresh if not fresh.is_empty() else old).size())]
	current = chosen
	if not fresh.is_empty():
		recent.append(String(chosen.get("id", "")))
		if recent.size() > 10:
			recent.pop_front()
	var id2 := String(chosen.get("id", ""))
	asked_session[id2] = int(asked_session.get(id2, 0)) + 1
	question_requested.emit(chosen)
	return chosen


func answer(index: int) -> Dictionary:
	if current.is_empty():
		return {}
	var ok := index == int(current.get("answer", -1))
	var theme := String(current.get("theme", "projet"))
	Game.total_questions += 1
	if ok:
		Game.correct_questions += 1
	var gained := int(current.get("score", 100)) if ok else 0
	Game.add_score(gained)
	Game.add_xp(20 if ok else 5)
	Audio.play_sfx("quiz_ok" if ok else "quiz_fail")
	if ok:
		_unlock_codex_for(theme)
	var result := {
		"ok": ok, "question": current, "chosen": index,
		"correct": int(current.get("answer", -1)), "score": gained
	}
	answered.emit(result)
	save_results()
	return result


func _unlock_codex_for(theme: String) -> void:
	for e in codex:
		if String(e.get("theme", "")) == theme and not Game.codex_unlocked.has(String(e.get("id", ""))):
			Game.register_codex(String(e.get("id", "")))
			break


func save_results() -> void:
	var f := FileAccess.open("user://nightfall1984_results.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"total": Game.total_questions, "correct": Game.correct_questions,
			"history": asked_session, "date": Time.get_datetime_string_from_system()
		}, "  "))


func grade() -> float:
	if Game.total_questions == 0:
		return 0.0
	return 20.0 * float(Game.correct_questions) / float(Game.total_questions)


func accuracy() -> float:
	return grade() * 5.0
