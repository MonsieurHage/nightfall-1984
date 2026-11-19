extends Node
class_name Main

## Orchestrateur : monde, joueur, interface, chargement des environnements.

var world: Node3D
var player: Node
var ui: Node
var cloud_ui: Node
var touch_ui: Node
var current_level: Node = null
var last_results: Dictionary = {}
var _transitioning: bool = false
var _autosave_timer: float = 0.0


func _ready() -> void:
	randomize()
	Game.main = self
	world = Node3D.new()
	world.name = "World"
	add_child(world)

	player = load("res://scripts/player.gd").new()
	player.name = "Player"
	add_child(player)

	ui = load("res://scripts/ui/ui.gd").new()
	ui.name = "UI"
	add_child(ui)
	ui.player = player
	Game.ui = ui

	Quiz.question_requested.connect(ui.show_quiz)
	Quiz.answered.connect(ui.show_quiz_feedback)
	Missions.mission_started.connect(ui.on_mission_started)
	Missions.objective_progress.connect(ui.on_objective_progress)
	Missions.mission_completed.connect(_on_mission_completed)
	Game.mission_completed.connect(_on_mission_completed)
	ui.teacher_export_requested.connect(_export_teacher_csv)
	ui.restart_requested.connect(restart_level)
	ui.menu_requested.connect(to_menu)

	cloud_ui = load("res://scripts/ui/cloud_ui.gd").new()
	cloud_ui.name = "CloudUI"
	add_child(cloud_ui)
	cloud_ui.login_succeeded.connect(_on_login_succeeded)

	# Un PC Windows avec écran tactile reste un usage souris/clavier : on n'active
	# la manette tactile que sur mobile ou sur le Web tactile (tablette/iPad).
	Game.is_touch = OS.has_feature("mobile") or (OS.has_feature("web") and DisplayServer.is_touchscreen_available())
	if Game.is_touch:
		touch_ui = load("res://scripts/ui/touch_controls.gd").new()
		touch_ui.name = "TouchControls"
		add_child(touch_ui)

	# Sécurité Web : si le contexte WebGL est perdu après une longue session,
	# on recharge automatiquement la page plutôt que de rester sur écran noir.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
		(function(){
		  var c = document.querySelector('canvas');
		  if (!c) return;
		  c.addEventListener('webglcontextlost', function(e){
		    e.preventDefault();
		    setTimeout(function(){ location.reload(); }, 1500);
		  });
		})();
		""")

	# Accueil = connexion / création de compte. On n'entre dans le menu que
	# si le joueur est deja authentifie ou choisit de jouer sans compte.
	if Cloud.signed_in:
		ui.show_main_menu()
	else:
		cloud_ui.show_auth()
	ui.set_account(Cloud.pseudo if Cloud.signed_in else "")
	Audio.play_music("menu")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var level_to_test := ""
	var capture_path := ""
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--test-level="):
			level_to_test = arg.substr(13)
		elif arg.begins_with("--capture="):
			capture_path = arg.substr(10)
	if level_to_test != "":
		if capture_path != "":
			call_deferred("_auto_capture", level_to_test, capture_path)
		else:
			call_deferred("start_mission", level_to_test)


## Capture d'écran automatisée (hors headless) pour la documentation.
func _auto_capture(level: String, path: String) -> void:
	await start_mission(level)
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(path)
	print("CAPTURE_SAVED: %s (err=%d)" % [path, err])
	get_tree().quit()


func _process(delta: float) -> void:
	if Game.current_mission != "" and not ui.input_blocked():
		Game.stats["elapsed"] = float(Game.stats.get("elapsed", 0.0)) + delta
		_autosave_timer += delta
		if _autosave_timer >= 20.0:
			_autosave_timer = 0.0
			_store_run_state()
			Game.save_game()


func start_mission(id: String, resume: Dictionary = {}) -> void:
	if _transitioning or not Missions.missions.has(id):
		return
	_transitioning = true
	ui.hide_all()
	ui.fade_to(1.0, 0.35)
	await get_tree().create_timer(0.4).timeout
	for c in world.get_children():
		c.queue_free()
	var path := "res://scripts/levels/level_%s.gd" % id
	var script := load(path) as GDScript
	if script == null:
		push_error("Niveau introuvable : " + path)
		_transitioning = false
		return
	current_level = script.new()
	world.add_child(current_level)
	player.teleport(current_level.spawn, current_level.spawn_yaw)
	player.health = player.max_health
	player.alive = true
	if not resume.is_empty():
		player.restore_state(resume)
	Game.health_changed.emit(player.health, player.max_health)
	Missions.start(id)
	Audio.play_music("boss" if id == "core" else id)
	ui.show_hud()
	ui.set_objectives(Missions.objective_text())
	capture_mouse()
	_store_run_state()
	Game.save_game()
	ui.fade_to(0.0, 0.6)
	_transitioning = false


## Verrouille le curseur, y compris sur le Web où le navigateur exige parfois
## un requestPointerLock explicite (sinon la souris ne fait plus tourner la caméra).
func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
		(function(){
		  var c = document.querySelector('canvas');
		  if (!c || !c.requestPointerLock || document.pointerLockElement === c) return;
		  try { var p = c.requestPointerLock(); if (p && p.catch) p.catch(function(){}); }
		  catch (e) {}
		})();
		""")


## Enregistre la position et l'état du joueur dans la sauvegarde de la session.
func _store_run_state() -> void:
	if player == null or Game.current_mission == "":
		return
	Game.run_state = player.capture_state()
	Game.run_state["mission"] = Game.current_mission


## Reprend exactement la partie sauvegardée (locale ou Supabase).
func resume_game() -> void:
	var mission := String(Game.run_state.get("mission", Game.current_mission))
	if mission == "" or not Missions.missions.has(mission):
		Game.notify("AUCUNE PARTIE À REPRENDRE — NOUVELLE MISSION", 3.5)
		start_mission("alley")
		return
	start_mission(mission, Game.run_state)


func _on_login_succeeded(p: String) -> void:
	ui.show_main_menu()
	ui.set_account(p)
	var saved_mission := String(Game.run_state.get("mission", ""))
	if saved_mission != "" and Missions.missions.has(saved_mission):
		Game.notify("RECONNEXION : REPRISE DE " + saved_mission.to_upper(), 4.5)
		await get_tree().create_timer(0.5).timeout
		resume_game()
	else:
		Game.notify("CONNECTÉ : " + p, 4.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_store_run_state()
		Game.save_game()
		if Cloud.signed_in:
			Cloud.save_progress()


func restart_level() -> void:
	start_mission(Game.current_mission)


func to_menu() -> void:
	ui.hide_all()
	ui.fade_to(1.0, 0.25)
	await get_tree().create_timer(0.3).timeout
	for c in world.get_children():
		c.queue_free()
	current_level = null
	Game.current_mission = ""
	Audio.play_music("menu")
	ui.show_main_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.fade_to(0.0, 0.5)


func _on_mission_completed(_id: String, results: Dictionary) -> void:
	last_results = results
	_store_run_state()
	Game.save_game()
	if Cloud.signed_in:
		Cloud.save_progress()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_results(results)


func next_mission() -> void:
	var next := String(last_results.get("next", ""))
	if next != "" and Missions.missions.has(next):
		start_mission(next)
	else:
		to_menu()


func _export_teacher_csv() -> void:
	var lines: Array[String] = ["theme;correct;total;pourcentage"]
	var per_theme: Dictionary = {}
	for q in Quiz.questions:
		var th := String(q.get("theme", "?"))
		if not per_theme.has(th):
			per_theme[th] = {"correct": 0, "total": 0}
	var answers: Dictionary = Quiz.asked_session
	# Reconstruction approximative par thème à partir de l'historique global
	for q in Quiz.questions:
		var id := String(q.get("id", ""))
		var n := int(answers.get(id, 0))
		if n > 0:
			var th := String(q.get("theme", "?"))
			(per_theme[th] as Dictionary)["total"] += n
	for th in per_theme.keys():
		var d: Dictionary = per_theme[th]
		var total := int(d["total"])
		var correct := int(round(float(total) * Quiz.grade() / maxf(20.0, 0.001))) if Game.total_questions > 0 else 0
		var pct := 100.0 * float(correct) / maxf(1.0, float(total))
		lines.append("%s;%d;%d;%.1f" % [th, correct, total, pct])
	lines.append("TOTAL;%d;%d;%.1f" % [Game.correct_questions, Game.total_questions, Quiz.grade() * 5.0])
	var f := FileAccess.open("user://nightfall1984_resultats_professeur.csv", FileAccess.WRITE)
	if f:
		f.store_string(";".join([]))
		f.store_string("\n".join(lines))
	Game.notify("EXPORT CSV : user://nightfall1984_resultats_professeur.csv", 4.0)
