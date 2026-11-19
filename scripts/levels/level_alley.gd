extends LevelBase
class_name LevelAlley

## 01 — Rue industrielle de Los Angeles, nuit de juin 1984, sous la pluie.

func build() -> void:
	spawn = Vector3(0, 0, 12)
	spawn_yaw = 0.0
	add_rain(700, Vector3(34, 16, 64), Vector3(0, 8, -8))

	# Chaussée, trottoirs, flaques
	floor_slab(Vector3(0, -0.12, -10), Vector2(26, 66), "asphalt")
	box("sidewalk_l", Vector3(-11.3, 0.12, -10), Vector3(3, 0.28, 66), "concrete")
	box("sidewalk_r", Vector3(11.3, 0.12, -10), Vector3(3, 0.28, 66), "concrete")
	for z in [-22, -6, 9]:
		box("puddle", Vector3(1.5 + randf() * 4, 0.015, z), Vector3(4.5, 0.02, 2.2), "glass", false)

	# Façades
	for side in [-1.0, 1.0]:
		for i in range(7):
			var z := 14.0 - float(i) * 9.0
			var h := 9.0 + randf() * 11.0
			var x: float = side * (15.5 + randf() * 2.0)
			box("building", Vector3(x, h * 0.5, z), Vector3(8.0, h, 8.4), "concrete")
			# Fenêtres éclairées
			for row in range(int(h / 3.0) - 1):
				for col in range(2):
					if randf() > 0.62:
						var wz := z - 2.2 + float(col) * 4.4
						var wy := 2.0 + float(row) * 3.0
						box("window", Vector3(x - side * 4.05, wy, wz), Vector3(0.08, 1.1, 1.8),
							"neon_amber" if randf() > 0.5 else "neon_cyan", false)
			if i % 2 == 0:
				var sign := "neon_red" if side < 0 else "neon_cyan"
				box("neon_sign", Vector3(x - side * 4.15, 3.4, z), Vector3(0.12, 2.2, 0.25), sign, false)
				point_light(Vector3(x - side * 5.0, 3.4, z),
					Color(1, 0.1, 0.1) if side < 0 else Color(0.1, 0.8, 1), 2.4, 11.0)

	# Éclairage public, camion, poubelles, câbles
	for z in [8, -8, -26]:
		box("lamp_post", Vector3(-9.6, 2.5, z), Vector3(0.16, 5.0, 0.16), "dark_metal")
		box("lamp_head", Vector3(-9.0, 4.9, z), Vector3(1.3, 0.12, 0.4), "neon_amber", false)
		point_light(Vector3(-8.7, 4.7, z), Color(1, 0.65, 0.25), 2.0, 12.0)
	prop("Barrel", Vector3(9.4, 0.6, 2), 0.4, 1.0, Vector3(0.9, 1.2, 0.9), "rust")
	prop("Barrel", Vector3(9.9, 0.6, 3.4), 1.1, 1.0, Vector3(0.9, 1.2, 0.9), "rust")
	prop("Crate", Vector3(-9.5, 0.6, -14), 0.2, 1.1, Vector3(1.3, 1.2, 1.3), "metal")
	prop("Pipe", Vector3(12.0, 3.2, -18), 0.0, 1.0, Vector3(0.5, 0.5, 6.0), "rust")

	# Bornes pédagogiques (démarche de projet, énergie)
	add_terminal(Vector3(-8.4, 0.9, 2), PI * 0.5, "projet", ["projet"], "quiz", "BORNE TECHNE")
	add_terminal(Vector3(8.4, 0.9, -19), -PI * 0.5, "energie", ["energie"], "quiz", "BORNE ÉNERGIE")

	# Fragments mémoire
	spawn_pickup("chip", Vector3(-8.8, 0.75, -5))
	spawn_pickup("chip", Vector3(9.2, 1.1, -29))
	spawn_pickup("chip", Vector3(0.5, 0.8, -36))

	# Objets et armes
	spawn_pickup("ammo", Vector3(-9.0, 0.7, -24), "Battery")
	spawn_pickup("health", Vector3(8.8, 0.7, -1), "Medkit")
	spawn_pickup("rifle", Vector3(-6.0, 0.8, -17), "Rifle")

	# Patrouilles
	spawn_enemy("endo", Vector3(-4, 0, -12), [Vector3(-4, 0, -12), Vector3(4, 0, -20), Vector3(-2, 0, -28)])
	spawn_enemy("endo", Vector3(6, 0, -31), [Vector3(6, 0, -31), Vector3(-5, 0, -34)])
	spawn_enemy("drone", Vector3(0, 2.5, -22), [Vector3(0, 2.5, -22), Vector3(7, 3.0, -12)])

	# Extraction
	add_exit(Vector3(0, 0, -40))
	neon_strip(Vector3(0, 3.6, -40.4), Vector3(4.5, 0.18, 0.18), "neon_cyan")
	point_light(Vector3(0, 3.0, -39), Color(0.2, 0.9, 1.0), 3.0, 14.0)

	# Limites de la rue
	box("end_north", Vector3(0, 4, 19), Vector3(30, 8, 1), "concrete")
	box("end_south", Vector3(0, 4, -44), Vector3(30, 8, 1), "concrete")
