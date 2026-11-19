extends LevelBase
class_name LevelFactory

## 02 — Usine CyberTech : convoyeurs, bras robots, sentinelles.

func build() -> void:
	spawn = Vector3(0, 0, 22)
	spawn_yaw = 0.0
	floor_slab(Vector3(0, -0.12, -8), Vector2(44, 68), "metal")
	box("ceiling", Vector3(0, 8.5, -8), Vector3(44, 0.4, 68), "concrete", false)
	for x in [-21.5, 21.5]:
		box("outer_wall", Vector3(x, 4.2, -8), Vector3(0.6, 8.4, 68), "concrete")
	box("end_wall_north", Vector3(0, 4.2, 23), Vector3(44, 8.4, 0.6), "concrete")
	box("end_wall_left", Vector3(-16, 4.2, -35), Vector3(12, 8.4, 0.6), "concrete")
	box("end_wall_right", Vector3(16, 4.2, -35), Vector3(12, 8.4, 0.6), "concrete")

	# Convoyeurs et machines
	for lane in [-9.0, 9.0]:
		box("conveyor", Vector3(lane, 0.65, -6), Vector3(4.2, 0.5, 46), "dark_metal")
		box("conveyor_belt", Vector3(lane, 0.94, -6), Vector3(3.8, 0.06, 46), "plastic", false)
		for i in range(9):
			var z := 14.0 - float(i) * 5.2
			box("roller", Vector3(lane, 1.02, z), Vector3(3.7, 0.1, 0.12), "metal", false)
			prop("Crate", Vector3(lane, 1.5, z + 1.5), randf() * 3.0, 0.7, Vector3(0.8, 0.8, 0.8), "rust")
	for i in range(6):
		var z := 16.0 - float(i) * 9.0
		for side in [-1.0, 1.0]:
			var x: float = side * 16.5
			box("robot_base", Vector3(x, 1.6, z), Vector3(2.4, 3.2, 2.4), "panel")
			box("robot_arm", Vector3(x - side * 1.6, 3.6, z), Vector3(3.2, 0.5, 0.5), "chrome", false,
				Vector3(0, 0, side * 0.4))
			neon_strip(Vector3(x, 3.4, z - 1.25), Vector3(1.6, 0.12, 0.08), "neon_amber", false)

	# Tuyaux et néons industriels
	for i in range(8):
		var z := 18.0 - float(i) * 7.0
		prop("Pipe", Vector3(-19.5, 6.0, z), 0.0, 1.0, Vector3(0.5, 0.5, 5.0), "rust")
		prop("Pipe", Vector3(19.5, 6.0, z), 0.0, 1.0, Vector3(0.5, 0.5, 5.0), "rust")
	for z in [16, 0, -16, -30]:
		neon_strip(Vector3(0, 7.8, z), Vector3(14, 0.12, 0.12), "neon_cyan", false)
		point_light(Vector3(0, 7.0, z), Color(0.3, 0.8, 1.0), 2.0, 18.0)

	# Consoles de production (sabotage pédagogique)
	add_terminal(Vector3(-13.5, 0.9, 10), PI * 0.5, "materiaux", ["materiaux"], "consoles", "CONSOLE MATIÈRES")
	add_terminal(Vector3(13.5, 0.9, -6), -PI * 0.5, "mecanique", ["mecanique"], "consoles", "CONSOLE MÉCANISMES")
	add_terminal(Vector3(-13.5, 0.9, -24), PI * 0.5, "materiaux", ["materiaux", "mecanique"], "consoles", "CONSOLE STRUCTURES")

	# Carte d'accès gardée
	prop("ServerRack", Vector3(16.0, 1.3, -25), PI, 1.0, Vector3(1.4, 2.6, 1.0), "panel")
	spawn_pickup("keycard", Vector3(16.0, 1.2, -23.5), "Keycard")
	spawn_pickup("ammo", Vector3(-15.0, 0.8, 4), "Battery")
	spawn_pickup("health", Vector3(14.0, 0.8, -17), "Medkit")
	spawn_pickup("shrink", Vector3(0, 1.1, -20), "ShrinkRay")

	# Ennemis
	spawn_enemy("drone", Vector3(-6, 3.0, 8), [Vector3(-6, 3, 8), Vector3(6, 3, 4)])
	spawn_enemy("drone", Vector3(7, 3.2, -12), [Vector3(7, 3, -12), Vector3(-7, 3, -18)])
	spawn_enemy("endo", Vector3(-4, 0, -4), [Vector3(-4, 0, -4), Vector3(5, 0, -10), Vector3(-6, 0, -18)])
	spawn_enemy("endo", Vector3(8, 0, -26), [Vector3(8, 0, -26), Vector3(-8, 0, -30)])
	spawn_enemy("turret", Vector3(0, 0.7, -30), [], 70.0)

	# Porte verrouillée puis sortie
	var door := add_door(Vector3(0, 1.7, -33), 0.0, "keycard")
	add_exit(Vector3(0, 0, -39))
	door.slide_height = 3.6
	neon_strip(Vector3(0, 5.5, -33.4), Vector3(5, 0.15, 0.1), "neon_red", false)
