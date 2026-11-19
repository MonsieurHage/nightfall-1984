extends LevelBase
class_name LevelPlant

## 04 — Centrale électrique : chaîne énergétique, séquence de disjoncteurs, jets.

var breaker_step: int = 0

func build() -> void:
	spawn = Vector3(0, 0, 18)
	spawn_yaw = 0.0
	floor_slab(Vector3(0, -0.12, -10), Vector2(40, 66), "concrete")
	box("plant_ceiling", Vector3(0, 10.0, -10), Vector3(40, 0.5, 66), "metal", false)
	for x in [-20, 20]:
		box("plant_wall", Vector3(x, 5.0, -10), Vector3(0.6, 10.0, 66), "concrete")
	box("plant_north", Vector3(0, 5.0, 22), Vector3(40, 10.0, 0.6), "concrete")
	box("plant_south_left", Vector3(-14, 5.0, -34), Vector3(12, 10.0, 0.6), "concrete")
	box("plant_south_right", Vector3(14, 5.0, -34), Vector3(12, 10.0, 0.6), "concrete")

	# Générateurs, transformateurs, tuyauterie
	for side in [-1.0, 1.0]:
		for i in range(4):
			var z := 12.0 - float(i) * 11.0
			var x: float = side * 14.0
			box("generator", Vector3(x, 2.2, z), Vector3(5.0, 4.4, 6.0), "panel")
			neon_strip(Vector3(x - side * 2.55, 3.2, z), Vector3(0.08, 2.4, 0.08),
				"neon_amber" if i % 2 == 0 else "neon_cyan", false)
			prop("Pipe", Vector3(side * 17.5, 6.5, z), 0.0, 1.0, Vector3(0.6, 0.6, 5.0), "rust")
	for i in range(7):
		var z := 16.0 - float(i) * 7.5
		prop("Pipe", Vector3(0, 8.6, z), PI * 0.5, 1.0, Vector3(0.5, 0.5, 6.0), "metal")
	for z in [14, -2, -18]:
		neon_strip(Vector3(0, 9.3, z), Vector3(16, 0.12, 0.12), "neon_cyan", false)
		point_light(Vector3(0, 8.5, z), Color(0.3, 0.7, 1.0), 2.4, 20.0)

	# Séquence des disjoncteurs : production -> transport -> distribution
	add_breaker(Vector3(-6.0, 1.0, 8), PI, "energie", ["energie"], 0, self, "PRODUCTION")
	add_breaker(Vector3(0.0, 1.0, -4), PI, "energie", ["energie", "fluides"], 1, self, "TRANSPORT")
	add_breaker(Vector3(6.0, 1.0, -16), PI, "energie", ["energie"], 2, self, "DISTRIBUTION")

	# Jets de vapeur et vannes
	var j1 := add_jet(Vector3(-6.0, 0, -22))
	add_valve(Vector3(-9.5, 1.2, -22), j1)
	var j2 := add_jet(Vector3(6.0, 0, -10))
	add_valve(Vector3(9.5, 1.2, -10), j2)
	var j3 := add_jet(Vector3(0, 0, -27))
	add_valve(Vector3(3.5, 1.2, -27), j3)

	# Batteries, bornes, objets
	spawn_pickup("battery", Vector3(-15.0, 0.8, -6), "Battery")
	spawn_pickup("battery", Vector3(15.0, 0.8, -25), "Battery")
	add_terminal(Vector3(-12.0, 0.9, -14), PI * 0.5, "energie", ["energie"], "quiz", "BORNE CHAÎNE ÉNERGÉTIQUE")
	add_terminal(Vector3(12.0, 0.9, -1), -PI * 0.5, "fluides", ["fluides"], "quiz", "BORNE FLUIDES")
	spawn_pickup("ammo", Vector3(0, 0.8, 6), "Battery")
	spawn_pickup("health", Vector3(-16.0, 0.8, -28), "Medkit")

	# Défenses
	spawn_enemy("endo", Vector3(-8, 0, -6), [Vector3(-8, 0, -6), Vector3(8, 0, -14)])
	spawn_enemy("endo", Vector3(7, 0, -24), [Vector3(7, 0, -24), Vector3(-7, 0, -29)])
	spawn_enemy("drone", Vector3(0, 3.5, -12), [Vector3(0, 3.5, -12), Vector3(-10, 4, -20)])
	spawn_enemy("turret", Vector3(0, 0.8, -31), [], 90.0)
	add_security_camera(Vector3(0, 5.0, -20), PI)

	# Accès au noyau
	var door := add_door(Vector3(0, 2.0, -33), 0.0, "breakers", Vector3(5, 4.5, 0.5))
	door.slide_height = 4.8
	add_exit(Vector3(0, 0, -40))
	neon_strip(Vector3(0, 6.0, -33.4), Vector3(5.5, 0.15, 0.1), "neon_red", false)
