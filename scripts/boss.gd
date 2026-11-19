extends Enemy
class_name Boss

## Gardien du noyau : bouclier alimenté par 3 terminaux, point faible, 3 phases.

var shield_up: bool = true
var terminals_disabled: int = 0
var weak_point: MeshInstance3D = null
var phase: int = 1
var laser_cooldown: float = 0.0
var minions_spawned: bool = false
var shield_mesh: MeshInstance3D = null


func _ready() -> void:
	kind = "boss"
	max_health = 780.0
	health = max_health
	speed = 2.0
	base_speed = 2.0
	damage = 22.0
	base_damage = 22.0
	attack_range = 3.8
	attack_rate = 1.5
	sight_range = 45.0
	super._ready()
	var cs: CollisionShape3D = get_child(0) as CollisionShape3D
	if cs and cs.shape is CapsuleShape3D:
		cs.shape.radius = 0.95
		cs.shape.height = 3.9
		cs.position.y = 1.95
	collision_mask = 3
	_build_shield()
	Game.notify("AVERTISSEMENT : GARDIEN ACTIVÉ — BOUCLIER EN LIGNE", 4.0)


func _build_model() -> void:
	model_root = Node3D.new()
	add_child(model_root)
	var path := "res://assets/models/boss.glb"
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene:
			var inst := scene.instantiate()
			model_root.add_child(inst)
			for c in _all_descendants(inst):
				if c is MeshInstance3D and String(c.name).contains("WeakPoint"):
					weak_point = c as MeshInstance3D
			return
	_build_fallback_boss()


func _all_descendants(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in node.get_children():
		out.append(c)
		out.append_array(_all_descendants(c))
	return out


func _build_fallback_boss() -> void:
	var torso := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.5, 2.4, 1.4)
	torso.mesh = box
	torso.position.y = 2.5
	torso.material_override = Game.material("dark_metal")
	model_root.add_child(torso)
	var head := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.9, 0.6, 0.8)
	head.mesh = hb
	head.position.y = 4.0
	head.material_override = Game.material("chrome")
	model_root.add_child(head)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.42
	core.mesh = sphere
	core.position = Vector3(0, 2.65, -0.78)
	core.material_override = Game.material("neon_cyan")
	model_root.add_child(core)
	weak_point = core
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.35
		cyl.bottom_radius = 0.28
		cyl.height = 2.3
		leg.mesh = cyl
		leg.position = Vector3(side * 0.7, 1.1, 0)
		leg.material_override = Game.material("dark_metal")
		model_root.add_child(leg)


func _build_shield() -> void:
	shield_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 3.1
	sphere.radial_segments = 24
	sphere.rings = 16
	shield_mesh.mesh = sphere
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.65, 1.0, 0.12)
	m.emission_enabled = true
	m.emission = Color(0.1, 0.5, 1.0)
	m.emission_energy_multiplier = 1.8
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	shield_mesh.material_override = m
	shield_mesh.position.y = 2.1
	model_root.add_child(shield_mesh)


func disable_terminal() -> void:
	if not shield_up:
		return
	terminals_disabled += 1
	Game.notify("TERMINAL DÉSACTIVÉ %d/3" % terminals_disabled, 2.0)
	Audio.play_sfx("door", -4.0)
	if terminals_disabled >= 3:
		shield_up = false
		if shield_mesh:
			var tw := create_tween()
			tw.tween_property(shield_mesh, "scale", Vector3.ZERO, 0.7)
			tw.tween_callback(func() -> void: shield_mesh.visible = false)
		Audio.play_sfx("explosion", -2.0)
		Game.notify("BOUCLIER DÉSACTIVÉ — POINT FAIBLE EXPOSÉ !", 4.0)


func take_damage(amount: float, from: Node = null) -> void:
	if dead:
		return
	if shield_up:
		amount *= 0.06
		Audio.play_sfx("hit", -4.0, 1.6)
		if randf() < 0.25:
			Game.notify("BOUCLIER ACTIF — DÉSACTIVEZ LES 3 TERMINAUX", 1.2)
	else:
		Audio.play_sfx_at("enemy_hit", global_position, -2.0)
	health -= amount
	if weak_point and is_instance_valid(weak_point):
		var tw := create_tween()
		tw.tween_property(weak_point, "scale", Vector3(1.5, 1.5, 1.5), 0.08)
		tw.tween_property(weak_point, "scale", Vector3.ONE, 0.16)
	if not minions_spawned and health < max_health * 0.55:
		minions_spawned = true
		phase = 2
		speed = base_speed * 1.7
		damage = base_damage * 1.25
		Game.notify("PHASE 2 : SURCHARGE — RENFORT DÉPLOYÉ", 3.5)
		if Game.current_level and Game.current_level.has_method("spawn_minions"):
			Game.current_level.spawn_minions(global_position, 2)
	if health <= 0.0:
		die()


func attack() -> void:
	last_attack = Time.get_ticks_msec() / 1000.0
	if player == null or not is_instance_valid(player):
		return
	Audio.play_sfx_at("rifle", global_position, -2.0, 0.55)
	var from := global_position + Vector3(0, 3.0, 0)
	var to: Vector3 = player.global_position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit.get("collider") == player:
		player.take_damage(damage, self)
	if phase >= 2 and randf() < 0.5 and Game.current_level and Game.current_level.has_method("boss_laser"):
		Game.current_level.boss_laser(from, to)


func die() -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision_mask = 0
	Game.stats["kills"] = int(Game.stats.get("kills", 0)) + 1
	Game.add_score(1800)
	Missions.increment("boss")
	Audio.play_sfx_at("explosion", global_position, 2.0)
	if Game.player:
		Game.player.shake = 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(model_root, "scale", Vector3(1.15, 0.7, 1.15), 0.5)
	tw.tween_property(model_root, "position", model_root.position + Vector3(0, -1.5, 0), 0.7)
	tw.chain().tween_property(model_root, "scale", Vector3.ZERO, 0.9)
	tw.tween_callback(func() -> void:
		Game.notify("GARDIEN NEUTRALISÉ — EXTRACTION DISPONIBLE", 5.0)
		if Game.current_level and Game.current_level.has_method("open_exit"):
			Game.current_level.open_exit()
	)
