extends CharacterBody3D
class_name Player

## Contrôleur FPS : déplacement, regard, armes, interactions, dégâts.

const WEAPONS := [
	{"name": "Pistolet M9", "model": "Pistol", "damage": 26, "rate": 0.26, "clip": 12,
	 "reserve": 72, "reload": 1.05, "auto": false, "range": 90, "sfx": "shot", "special": ""},
	{"name": "Fusil plasma AR-84", "model": "Rifle", "damage": 17, "rate": 0.085, "clip": 36,
	 "reserve": 180, "reload": 1.7, "auto": true, "range": 130, "sfx": "rifle", "special": ""},
	{"name": "Réducteur quantique Q-84", "model": "ShrinkRay", "damage": 8, "rate": 0.5, "clip": 12,
	 "reserve": 36, "reload": 2.0, "auto": false, "range": 35, "sfx": "shrink", "special": "shrink"}
]

var camera: Camera3D
var weapon_mount: Node3D
var interact_ray: RayCast3D
var flashlight: SpotLight3D
var models: Dictionary = {}
var weapon_index: int = 0
var unlocked_weapons: int = 1
var ammo: Array[int] = [12, 0, 0]
var reserve: Array[int] = [72, 0, 0]
var cooldown: float = 0.0
var reloading: float = 0.0
var max_health: float = 100.0
var health: float = 100.0
var alive: bool = true
var crouching: bool = false
var sprinting: bool = false
var shake: float = 0.0
var bob_time: float = 0.0
var step_distance: float = 0.0
var last_damage: float = -99.0
var muzzle_light: OmniLight3D
var muzzle_mesh: MeshInstance3D
var tracer_scene: PackedScene
var impact_scene: PackedScene
var spawn_point: Vector3 = Vector3.ZERO
var collision_shape: CollisionShape3D
var _base_eye: float = 1.62
var _current_interactable: Node = null
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _have_mouse_pos: bool = false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	shape.name = "PlayerCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	collision_shape = shape

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position.y = _base_eye
	camera.fov = 78.0
	camera.near = 0.05
	camera.far = 120.0
	camera.current = true
	add_child(camera)

	interact_ray = RayCast3D.new()
	interact_ray.target_position = Vector3(0, 0, -3.4)
	interact_ray.collision_mask = 1
	camera.add_child(interact_ray)

	weapon_mount = Node3D.new()
	weapon_mount.position = Vector3(0.22, -0.20, -0.42)
	camera.add_child(weapon_mount)

	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(-0.15, -0.05, 0)
	flashlight.light_color = Color(0.78, 0.88, 1.0)
	flashlight.light_energy = 3.2
	flashlight.spot_angle = 0.55
	flashlight.spot_angle_attenuation = 0.35
	flashlight.spot_range = 34.0
	flashlight.shadow_enabled = false
	camera.add_child(flashlight)

	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.72, 0.35)
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 6.0
	weapon_mount.add_child(muzzle_light)

	muzzle_mesh = MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.055
	mm.rings = 6
	mm.radial_segments = 8
	muzzle_mesh.mesh = mm
	muzzle_mesh.material_override = Game.material("neon_amber")
	muzzle_mesh.visible = false
	weapon_mount.add_child(muzzle_mesh)

	_load_models()
	_equip(0)
	Game.player = self
	Game.health_changed.emit(health, max_health)


func _load_models() -> void:
	var path := "res://assets/models/weapons.glb"
	var hands_path := "res://assets/models/player_hands.glb"
	for p in [path, hands_path]:
		if not ResourceLoader.exists(p):
			continue
		var scene := load(p) as PackedScene
		if scene == null:
			continue
		var inst := scene.instantiate()
		_flatten(inst, p == hands_path)
		inst.queue_free()


func _flatten(node: Node, hands: bool) -> void:
	for child in node.get_children():
		var mi := child as MeshInstance3D
		if mi and mi.mesh:
			var n := String(child.name)
			if hands:
				if n.contains("Hand_L") or n.contains("Hand_R"):
					models[n] = mi.mesh
			else:
				for w in WEAPONS:
					if n.contains(String(w["model"])):
						models[String(w["model"])] = mi.mesh
		_flatten(child, hands)


func _equip(index: int) -> void:
	if index < 0 or index >= unlocked_weapons:
		return
	weapon_index = index
	for c in weapon_mount.get_children():
		if c is MeshInstance3D and c != muzzle_mesh:
			c.queue_free()
	var key := String(WEAPONS[index]["model"])
	if models.has(key):
		var mi := MeshInstance3D.new()
		mi.mesh = models[key]
		mi.position = Vector3(0, 0, -0.12)
		weapon_mount.add_child(mi)
	else:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.09, 0.13, 0.42)
		mi.mesh = box
		mi.material_override = Game.material("dark_metal")
		mi.position = Vector3(0, 0, -0.2)
		weapon_mount.add_child(mi)
	if Game.ui:
		Game.ui.set_weapon(weapon_name(), ammo[weapon_index], reserve[weapon_index])


func weapon_name() -> String:
	return String(WEAPONS[weapon_index]["name"])


func teleport(pos: Vector3, yaw: float = 0.0) -> void:
	global_position = pos + Vector3(0, 0.1, 0)
	spawn_point = pos
	velocity = Vector3.ZERO
	rotation.y = yaw
	if camera:
		camera.rotation.x = 0.0


## État complet du joueur, sérialisé dans la sauvegarde en ligne.
func capture_state() -> Dictionary:
	var p := global_position
	return {
		"pos": [p.x, p.y, p.z],
		"yaw": rotation.y,
		"pitch": camera.rotation.x if camera else 0.0,
		"weapon": weapon_index,
		"unlocked_weapons": unlocked_weapons,
		"ammo": [ammo[0], ammo[1], ammo[2]],
		"reserve": [reserve[0], reserve[1], reserve[2]],
		"health": health,
		"alive": alive
	}


## Restaure l'état après reconnexion (remplace le spawn du niveau).
func restore_state(d: Dictionary) -> void:
	if d.is_empty():
		return
	var arr: Array = d.get("pos", [])
	if arr.size() == 3:
		global_position = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
		spawn_point = global_position
	velocity = Vector3.ZERO
	rotation.y = float(d.get("yaw", rotation.y))
	if camera:
		camera.rotation.x = clampf(float(d.get("pitch", 0.0)), -1.45, 1.45)
	unlocked_weapons = clampi(int(d.get("unlocked_weapons", 1)), 1, WEAPONS.size())
	var a: Array = d.get("ammo", [])
	var r: Array = d.get("reserve", [])
	for i in range(ammo.size()):
		if i < a.size():
			ammo[i] = maxi(0, int(a[i]))
		if i < r.size():
			reserve[i] = maxi(0, int(r[i]))
	health = clampf(float(d.get("health", max_health)), 1.0, max_health)
	alive = bool(d.get("alive", true))
	_equip(clampi(int(d.get("weapon", 0)), 0, unlocked_weapons - 1))
	Game.health_changed.emit(health, max_health)


func cycle_weapon() -> void:
	var count := clampi(unlocked_weapons, 1, WEAPONS.size())
	_equip((weapon_index + 1) % count)


func _input(event: InputEvent) -> void:
	if not alive or blocked():
		return
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		var delta := m.relative
		if not captured:
			# Sur le Web, le pointer lock peut être refusé : on utilise alors
			# le déplacement de position pour continuer à viser à la souris.
			if _have_mouse_pos:
				delta = m.position - _last_mouse_pos
			_last_mouse_pos = m.position
			_have_mouse_pos = true
		else:
			_have_mouse_pos = false
		if delta != Vector2.ZERO:
			_apply_look(delta)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
				and Game.current_mission != ""
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and Game.main):
			# Un clic dans le jeu redemande le verrouillage du curseur.
			Game.main.capture_mouse()


func _apply_look(delta: Vector2) -> void:
	var sens: float = float(Game.settings.get("sensitivity", 0.0022))
	rotation.y -= delta.x * sens
	var inv := -1.0 if bool(Game.settings.get("invert_y", false)) else 1.0
	if camera:
		camera.rotation.x = clampf(camera.rotation.x - delta.y * sens * inv, -1.45, 1.45)


func blocked() -> bool:
	return Game.ui != null and Game.ui.input_blocked()


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if blocked():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Regard tactile (mobile / tablette) : consomme le delta accumule par l'UI.
	var look := Game.touch_look
	if look != Vector2.ZERO:
		Game.touch_look = Vector2.ZERO
		var sens_t: float = float(Game.settings.get("sensitivity", 0.0022)) * 1.6
		rotation.y -= look.x * sens_t
		var inv_t := -1.0 if bool(Game.settings.get("invert_y", false)) else 1.0
		if camera:
			camera.rotation.x = clampf(camera.rotation.x - look.y * sens_t * inv_t, -1.45, 1.45)

	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	if Game.touch_move.length() > 0.05:
		input = Game.touch_move
	crouching = Input.is_action_pressed("crouch")
	sprinting = Input.is_action_pressed("sprint") and input.length() > 0.1 and not crouching
	var speed := 4.4
	if sprinting:
		speed = 7.4
	elif crouching:
		speed = 2.1
	var directional := (transform.basis * Vector3(input.x, 0.0, -input.y)).normalized()
	velocity.x = directional.x * speed
	velocity.z = directional.z * speed

	if not is_on_floor():
		velocity.y -= 17.0 * delta
	elif Input.is_action_just_pressed("jump") and not crouching:
		velocity.y = 5.6
		Audio.play_sfx("footstep", -10.0)

	var target_eye := _base_eye
	var capsule: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
	if crouching:
		target_eye = 1.02
		capsule.height = 1.12
		collision_shape.position.y = 0.58
	else:
		capsule.height = 1.75
		collision_shape.position.y = 0.9
	camera.position.y = lerpf(camera.position.y, target_eye, 12.0 * delta)

	var horizontal := Vector2(velocity.x, velocity.z)
	step_distance += horizontal.length() * delta
	if is_on_floor() and step_distance > (1.35 if sprinting else 1.9):
		step_distance = 0.0
		Audio.play_sfx("footstep", -14.0 if crouching else -9.0, randf_range(0.92, 1.08))
	if horizontal.length() > 0.5 and is_on_floor():
		bob_time += delta * (11.0 if sprinting else 7.5)
		camera.position.x = sin(bob_time) * 0.018
	else:
		camera.position.x = lerpf(camera.position.x, 0.0, 8.0 * delta)

	move_and_slide()

	# Réapparition si chute dans le vide (évite le redémarrage brutal de la mission)
	if global_position.y < -6.0 and Game.current_level != null:
		velocity = Vector3.ZERO
		teleport(Game.current_level.spawn, Game.current_level.spawn_yaw)
		health = maxf(1.0, health - 10.0)
		Game.health_changed.emit(health, max_health)
		if Game.ui:
			Game.ui.damage_flash()
		Game.notify("CHUTE DÉTECTÉE — RÉAPPARITION", 2.0)

	cooldown = maxf(0.0, cooldown - delta)
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			_finish_reload()
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 1.8)
		camera.rotation.z = sin(bob_time * 3.0) * shake * 0.08
	else:
		camera.rotation.z = lerpf(camera.rotation.z, 0.0, 10.0 * delta)

	if Time.get_ticks_msec() / 1000.0 - last_damage > 6.0 and health < max_health:
		heal(7.0 * delta, false)

	_update_interaction()

	# Saisie des armes / actions instantanées
	if Input.is_action_just_pressed("weapon_1"): _equip(0)
	if Input.is_action_just_pressed("weapon_2"): _equip(1)
	if Input.is_action_just_pressed("weapon_3"): _equip(2)
	if Input.is_action_just_pressed("reload"): start_reload()
	if Input.is_action_just_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
		Audio.play_sfx("ui", -12.0)
	if Input.is_action_just_pressed("special"):
		_use_special()
	var w: Dictionary = WEAPONS[weapon_index]
	if Input.is_action_pressed("fire") and (bool(w["auto"]) or Input.is_action_just_pressed("fire")):
		fire()


func _update_interaction() -> void:
	interact_ray.force_raycast_update()
	var col := interact_ray.get_collider()
	_current_interactable = null
	if col and col.has_method("get_prompt"):
		_current_interactable = col
	if Game.ui:
		Game.ui.set_prompt(_current_interactable.get_prompt() if _current_interactable else "")
	if _current_interactable and Input.is_action_just_pressed("interact"):
		_current_interactable.interact(self)


func fire() -> void:
	if cooldown > 0.0 or reloading > 0.0:
		return
	var w: Dictionary = WEAPONS[weapon_index]
	if ammo[weapon_index] <= 0:
		start_reload()
		return
	ammo[weapon_index] -= 1
	cooldown = float(w["rate"])
	Game.stats["shots"] = int(Game.stats.get("shots", 0)) + 1
	Audio.play_sfx_at(String(w["sfx"]), weapon_mount.global_position, -3.0)
	muzzle_light.light_energy = 4.0
	muzzle_mesh.visible = true
	var t := create_tween()
	t.tween_property(muzzle_light, "light_energy", 0.0, 0.07)
	t.tween_callback(func() -> void: muzzle_mesh.visible = false)

	var from := camera.global_position
	var dir := -camera.global_transform.basis.z.normalized()
	var to := from + dir * float(w["range"])
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	var end := to
	if not hit.is_empty():
		end = hit.position
		var col: Object = hit.get("collider")
		if col and col.has_method("take_damage"):
			col.take_damage(float(w["damage"]), self)
			Game.stats["hits"] = int(Game.stats.get("hits", 0)) + 1
		if col and String(w.get("special", "")) == "shrink" and col.has_method("shrink"):
			col.shrink(10.0)
			Game.notify("CIBLE RÉDUITE — 10 secondes", 1.6)
		_spawn_effect("impact", end, hit.get("normal", Vector3.UP))
	_spawn_effect("tracer", from, end)
	if Game.ui:
		Game.ui.set_weapon(weapon_name(), ammo[weapon_index], reserve[weapon_index])


func _spawn_effect(kind: String, a: Vector3, b: Vector3) -> void:
	var root: Node = Game.main.world
	if root == null:
		return
	if kind == "tracer":
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.008, 0.008, maxf(0.1, a.distance_to(b)))
		mi.mesh = box
		mi.material_override = Game.material("neon_cyan" if weapon_index != 0 else "neon_amber")
		mi.global_position = a
		root.add_child(mi)
		mi.look_at(b, Vector3.UP)
		var tw := create_tween()
		tw.tween_property(mi, "scale", Vector3(0.05, 0.05, 1.0), 0.09)
		tw.tween_callback(mi.queue_free)
	else:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.06
		mi.mesh = s
		mi.material_override = Game.material("neon_amber")
		mi.global_position = a
		root.add_child(mi)
		var tw := create_tween()
		tw.tween_property(mi, "scale", Vector3.ZERO, 0.22)
		tw.tween_callback(mi.queue_free)


func _use_special() -> void:
	if weapon_index == 2:
		Game.notify("RÉDUCTEUR ACTIF : tirez pour rétrécir cibles et objets", 2.0)
	else:
		Game.notify("Équipez le Réducteur quantique [3] pour utiliser le rayon rétrécissant", 2.0)


func start_reload() -> void:
	var w: Dictionary = WEAPONS[weapon_index]
	if reloading > 0.0 or ammo[weapon_index] >= int(w["clip"]) or reserve[weapon_index] <= 0:
		return
	reloading = float(w["reload"])
	Audio.play_sfx("ui", -8.0, 0.7)
	if Game.ui:
		Game.ui.set_reload(true)


func _finish_reload() -> void:
	var w: Dictionary = WEAPONS[weapon_index]
	var need := int(w["clip"]) - ammo[weapon_index]
	var give := mini(need, reserve[weapon_index])
	ammo[weapon_index] += give
	reserve[weapon_index] -= give
	if Game.ui:
		Game.ui.set_reload(false)
		Game.ui.set_weapon(weapon_name(), ammo[weapon_index], reserve[weapon_index])


func give_ammo(amount: int) -> void:
	for i in range(unlocked_weapons):
		reserve[i] = mini(int(WEAPONS[i]["reserve"]), reserve[i] + amount)
	Game.notify("MUNITIONS +%d" % amount, 1.5)
	if Game.ui:
		Game.ui.set_weapon(weapon_name(), ammo[weapon_index], reserve[weapon_index])


func unlock_weapon(index: int) -> void:
	if index >= unlocked_weapons:
		unlocked_weapons = index + 1
		ammo[index] = int(WEAPONS[index]["clip"])
		reserve[index] = int(WEAPONS[index]["reserve"])
		Game.notify("ARME TROUVÉE : " + String(WEAPONS[index]["name"]), 3.0)
		Audio.play_sfx("pickup")
		_equip(index)


func take_damage(amount: float, _from: Node = null) -> void:
	if not alive:
		return
	health = maxf(0.0, health - amount)
	last_damage = Time.get_ticks_msec() / 1000.0
	shake = 0.9
	Game.health_changed.emit(health, max_health)
	Audio.play_sfx("hit")
	if Game.ui:
		Game.ui.damage_flash()
	if health <= 0.0:
		die()


func heal(amount: float, notify_player: bool = true) -> void:
	health = mini(max_health, health + amount)
	Game.health_changed.emit(health, max_health)
	if notify_player and amount > 2.0:
		Game.notify("INTÉGRITÉ RESTAURÉE", 1.4)


func die() -> void:
	alive = false
	Game.stats["deaths"] = int(Game.stats.get("deaths", 0)) + 1
	Audio.play_sfx("explosion", -6.0)
	if Game.ui:
		Game.ui.show_death()
