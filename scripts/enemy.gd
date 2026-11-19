extends CharacterBody3D
class_name Enemy

## Ennemi générique : patrouille, détection, poursuite, attaque, rétrécissement.

var kind: String = "endo"            # endo | drone | turret
var max_health: float = 80.0
var health: float = 80.0
var speed: float = 3.1
var damage: float = 14.0
var attack_range: float = 2.1
var attack_rate: float = 1.15
var sight_range: float = 21.0
var player: Node = null
var state: String = "patrol"
var waypoints: Array[Vector3] = []
var wp_index: int = 0
var last_seen: Vector3 = Vector3.ZERO
var last_attack: float = -99.0
var shrink_timer: float = 0.0
var base_scale: float = 1.0
var base_speed: float = 3.1
var base_damage: float = 14.0
var dead: bool = false
var anim_time: float = 0.0
var model_root: Node3D
var limbs: Dictionary = {}
var hover_offset: float = 0.0
var alarmed: bool = false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 3
	base_speed = speed
	base_damage = damage
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	if kind == "drone":
		capsule.radius = 0.38
		capsule.height = 0.7
		hover_offset = 1.5
	elif kind == "turret":
		capsule.radius = 0.4
		capsule.height = 1.0
	else:
		capsule.radius = 0.38
		capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	model_root = Node3D.new()
	add_child(model_root)
	_build_model()
	player = Game.player


func configure(p_kind: String, p_health: float = -1.0, p_waypoints: Array = []) -> void:
	kind = p_kind
	if p_health > 0.0:
		max_health = p_health
		health = p_health
	if not p_waypoints.is_empty():
		waypoints.clear()
		for v in p_waypoints:
			waypoints.append(v as Vector3)


func _build_model() -> void:
	var path := "res://assets/models/endoskeleton.glb"
	if kind == "drone":
		path = "res://assets/models/drone.glb"
	elif kind == "turret":
		path = "res://assets/models/props.glb"
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene:
			var inst := scene.instantiate()
			if kind == "turret":
				var keep := inst.get_node_or_null("Turret")
				if keep:
					keep.get_parent().remove_child(keep)
					model_root.add_child(keep)
			else:
				model_root.add_child(inst)
			_collect_limbs(inst)
			return
	_build_fallback()


func _collect_limbs(node: Node) -> void:
	for c in node.get_children():
		var n := String(c.name)
		for key in ["UpperArm_L", "UpperArm_R", "UpperLeg_L", "UpperLeg_R", "LowerArm_L", "LowerArm_R"]:
			if n.contains(key) and c is Node3D:
				limbs[key] = {"node": c, "base": (c as Node3D).rotation.x}
		_collect_limbs(c)


func _build_fallback() -> void:
	var body := MeshInstance3D.new()
	var cyl := CapsuleMesh.new()
	cyl.radius = 0.3 if kind != "turret" else 0.4
	cyl.height = 1.2
	body.mesh = cyl
	body.position.y = 0.95
	body.material_override = Game.material("dark_metal")
	model_root.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	head.mesh = sphere
	head.position.y = 1.72 if kind != "drone" else 0.75
	head.material_override = Game.material("chrome")
	model_root.add_child(head)
	for x in [-0.09, 0.09]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.045
		eye.mesh = es
		eye.position = Vector3(x, head.position.y, -0.2)
		eye.material_override = Game.material("neon_red")
		model_root.add_child(eye)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if player == null:
		player = Game.player
	if shrink_timer > 0.0:
		shrink_timer -= delta
		if shrink_timer <= 0.0:
			_restore_size()

	anim_time += delta * maxf(0.5, speed)
	_animate()

	if kind == "turret":
		_turret_logic(delta)
		return

	var to_player := Vector3.ZERO
	var distance := 999.0
	if player and is_instance_valid(player):
		to_player = player.global_position - global_position
		distance = to_player.length()
	var sees := false
	if distance < sight_range and player and is_instance_valid(player):
		var from := global_position + Vector3(0, 1.5, 0)
		var to: Vector3 = player.global_position + Vector3(0, 1.3, 0)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = 1
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		sees = hit.is_empty() or (hit.get("collider") == player)
	if sees:
		state = "chase"
		last_seen = player.global_position
	elif state == "chase" and global_position.distance_to(last_seen) < 1.5:
		state = "patrol"

	var target := last_seen if state == "chase" else _patrol_point()
	if state == "patrol" and waypoints.is_empty():
		velocity = Vector3.ZERO
	else:
		var heading := target - global_position
		heading.y = 0.0
		if heading.length() > 0.4:
			var dir := heading.normalized()
			# Évitement simple des obstacles
			var fwd := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.6, 0), global_position + dir * 1.4 + Vector3(0, 0.6, 0))
			fwd.collision_mask = 1
			if not get_world_3d().direct_space_state.intersect_ray(fwd).is_empty():
				dir = dir.rotated(Vector3.UP, 1.2 if randf() > 0.5 else -1.2)
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			var look := Vector3(dir.x, 0.0, dir.z)
			if look.length_squared() > 0.01:
				rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.z), minf(1.0, delta * 6.0))
		else:
			velocity.x = 0.0
			velocity.z = 0.0

	if kind == "drone":
		velocity.y = sin(anim_time * 1.8) * 0.35
		model_root.position.y = hover_offset + sin(anim_time * 3.0) * 0.09
	else:
		velocity.y -= 16.0 * delta
	move_and_slide()

	if distance < attack_range and sees and Time.get_ticks_msec() / 1000.0 - last_attack > attack_rate:
		attack()


func _patrol_point() -> Vector3:
	if waypoints.is_empty():
		return global_position
	if global_position.distance_to(waypoints[wp_index]) < 1.0:
		wp_index = (wp_index + 1) % waypoints.size()
	return waypoints[wp_index]


func _animate() -> void:
	if limbs.is_empty():
		return
	var walking: float = clampf(Vector2(velocity.x, velocity.z).length() / maxf(0.3, speed), 0.0, 1.0)
	for key in limbs.keys():
		var data: Dictionary = limbs[key]
		var node: Node3D = data["node"] as Node3D
		var phase := 0.0 if key.ends_with("_L") else PI
		var amp := 0.55 * walking
		if key.contains("Arm"):
			amp *= 0.55
		node.rotation.x = float(data["base"]) + sin(anim_time * 5.0 + phase) * amp


func attack() -> void:
	last_attack = Time.get_ticks_msec() / 1000.0
	if player == null or not is_instance_valid(player):
		return
	if kind == "drone" or kind == "turret":
		Audio.play_sfx_at("shot", global_position, -12.0, 1.35)
		var from := global_position + Vector3(0, 1.2, 0)
		var to: Vector3 = player.global_position + Vector3(0, 1.2, 0)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = 1
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or hit.get("collider") == player:
			player.take_damage(damage, self)
	else:
		Audio.play_sfx_at("hit", global_position, -6.0, 0.75)
		player.take_damage(damage, self)


func _turret_logic(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var d := global_position.distance_to(player.global_position)
	if d > sight_range:
		return
	var look: Vector3 = (player.global_position - global_position).normalized()
	rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.z), minf(1.0, delta * 3.0))
	if d < 18.0 and Time.get_ticks_msec() / 1000.0 - last_attack > attack_rate:
		attack()


func take_damage(amount: float, _from: Node = null) -> void:
	if dead:
		return
	health -= amount
	Audio.play_sfx_at("enemy_hit", global_position, -5.0, randf_range(0.9, 1.15))
	alarmed = true
	var scale_tw := create_tween()
	scale_tw.tween_property(model_root, "scale", Vector3(1.08, 0.94, 1.08), 0.06)
	scale_tw.tween_property(model_root, "scale", Vector3.ONE, 0.09)
	if health <= 0.0:
		die()


func shrink(duration: float = 8.0) -> void:
	if dead:
		return
	shrink_timer = duration
	speed = base_speed * 0.45
	damage = base_damage * 0.4
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.34, 0.34, 0.34), 0.35).set_ease(Tween.EASE_OUT)
	Audio.play_sfx_at("shrink", global_position, 0.0)


func _restore_size() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT)
	speed = base_speed
	damage = base_damage


func die() -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	Game.stats["kills"] = int(Game.stats.get("kills", 0)) + 1
	Game.add_score(90)
	Missions.increment("kills")
	Audio.play_sfx_at("explosion", global_position, -4.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(model_root, "rotation", Vector3(-PI * 0.48, model_root.rotation.y, 0.0), 0.55)
	tw.tween_property(model_root, "position", model_root.position + Vector3(0, -0.35, 0), 0.55)
	tw.chain().tween_property(model_root, "scale", Vector3.ZERO, 0.45)
	tw.tween_callback(queue_free)
	if randf() < 0.32 and Game.current_level and Game.current_level.has_method("spawn_pickup"):
		Game.current_level.spawn_pickup("ammo", global_position)
