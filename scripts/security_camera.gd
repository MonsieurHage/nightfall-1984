extends Interactable
class_name SecurityCamera

## Caméra de surveillance : détecte le joueur, déclenche l'alarme, peut être piratée.

var hacked: bool = false
var detection: float = 0.0
var sweep_speed: float = 0.7
var sweep_range: float = 0.9
var base_yaw: float = 0.0
var lens: MeshInstance3D = null
var alarm_cooldown: float = 0.0


func _ready() -> void:
	prompt_text = "Pirater la caméra de surveillance"
	base_yaw = rotation.y
	for c in find_children("*", "MeshInstance3D", true, false):
		if c is MeshInstance3D and String(c.name).to_lower().contains("lens"):
			lens = c as MeshInstance3D
			break


func _process(delta: float) -> void:
	if hacked:
		return
	rotation.y = base_yaw + sin(Time.get_ticks_msec() / 1000.0 * sweep_speed) * sweep_range
	alarm_cooldown = maxf(0.0, alarm_cooldown - delta)
	var player := Game.player
	if player == null or not is_instance_valid(player) or alarm_cooldown > 0.0:
		return
	var to: Vector3 = player.global_position - global_position
	var dist := to.length()
	if dist > 16.0:
		detection = maxf(0.0, detection - delta)
		return
	var forward := -global_transform.basis.z
	var angle := forward.angle_to(to.normalized())
	if angle < 0.5:
		var q := PhysicsRayQueryParameters3D.create(global_position, player.global_position + Vector3(0, 1.2, 0))
		q.collision_mask = 1
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or hit.get("collider") == player:
			detection += delta
			if detection > 1.8:
				detection = 0.0
				alarm_cooldown = 8.0
				Audio.play_sfx("alarm", -3.0)
				Game.notify("DÉTECTION ! ALARME DÉCLENCHÉE", 3.0)
				if Game.current_level and Game.current_level.has_method("trigger_alarm"):
					Game.current_level.trigger_alarm(global_position)
			if lens:
				lens.material_override = Game.material("neon_red")
		else:
			detection = maxf(0.0, detection - delta)
	else:
		detection = maxf(0.0, detection - delta)


func interact(_player: Node) -> void:
	if hacked:
		return
	hacked = true
	mark_used()
	Missions.increment("cameras")
	Game.add_score(180)
	Audio.play_sfx("camera", -2.0)
	Game.notify("CAMÉRA PIRATÉE — FLUX SÉCURISÉ", 2.0)
	if lens:
		lens.material_override = Game.material("neon_green")
	if Game.ui and Game.ui.has_method("ping_enemies"):
		Game.ui.ping_enemies(8.0)
