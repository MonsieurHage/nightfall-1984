extends LevelBase
class_name LevelCore

## 05 — Noyau Skynet : arène circulaire, gardien, terminaux du bouclier.

var boss_node: Boss = null

func build() -> void:
	spawn = Vector3(0, 0, 20)
	spawn_yaw = 0.0
	floor_slab(Vector3(0, -0.12, -4), Vector2(52, 56), "metal")
	box("core_ceiling", Vector3(0, 14.0, -4), Vector3(52, 0.6, 56), "concrete", false)
	for x in [-26, 26]:
		box("core_wall", Vector3(x, 7.0, -4), Vector3(0.8, 14.0, 56), "panel")
	box("core_north", Vector3(0, 7.0, 24), Vector3(52, 14.0, 0.8), "concrete")
	box("core_south_left", Vector3(-17, 7.0, -32), Vector3(18, 14.0, 0.8), "concrete")
	box("core_south_right", Vector3(17, 7.0, -32), Vector3(18, 14.0, 0.8), "concrete")

	# Anneaux lumineux et colonnes de protection
	for r in [8.0, 15.0, 22.0]:
		for i in range(24):
			var a := TAU * float(i) / 24.0
			var p := Vector3(cos(a) * r, 0.03, -4.0 + sin(a) * r)
			box("core_ring", p, Vector3(0.5, 0.05, 0.5), "neon_red" if r == 22.0 else "neon_cyan", false,
				Vector3(0, a, 0))
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var p := Vector3(cos(a) * 12.0, 2.6, -4.0 + sin(a) * 12.0)
		box("pillar", p, Vector3(1.5, 5.2, 1.5), "panel")
		neon_strip(p + Vector3(0, 2.4, -0.8), Vector3(0.9, 0.1, 0.05), "neon_cyan", false)
	point_light(Vector3(0, 10.0, -4), Color(0.15, 0.55, 1.0), 3.5, 30.0)
	point_light(Vector3(0, 2.0, -20), Color(1.0, 0.1, 0.1), 3.0, 18.0)

	# Câbles et machines autour du noyau
	for i in range(10):
		var a := TAU * float(i) / 10.0
		var p := Vector3(cos(a) * 21.0, 2.0, -4.0 + sin(a) * 21.0)
		prop("ServerRack", p, -a + PI * 0.5, 1.2, Vector3(1.6, 4.0, 1.6), "panel")
		neon_strip(p + Vector3(0, 2.2, 0), Vector3(0.1, 1.6, 0.1), "neon_red", false)

	# Terminaux du bouclier (thèmes mélangés du BO)
	var t1 := add_terminal(Vector3(-14.0, 0.9, 2.0), -PI * 0.5, "energie", ["energie"], "terminals", "TERMINAL ALPHA")
	var t2 := add_terminal(Vector3(14.0, 0.9, 2.0), PI * 0.5, "information", ["information", "securite"], "terminals", "TERMINAL BÊTA")
	var t3 := add_terminal(Vector3(0.0, 0.9, -19.0), 0.0, "materiaux", ["materiaux", "mecanique", "fluides", "projet"], "terminals", "TERMINAL GAMMA")
	t1.linked_boss = boss_node
	t2.linked_boss = boss_node
	t3.linked_boss = boss_node

	# Objets utiles
	spawn_pickup("ammo", Vector3(-18.0, 0.8, 12.0), "Battery")
	spawn_pickup("ammo", Vector3(18.0, 0.8, 12.0), "Battery")
	spawn_pickup("health", Vector3(0.0, 0.8, 14.0), "Medkit")
	spawn_pickup("shrink", Vector3(-19.0, 0.8, -12.0), "ShrinkRay")

	# Le Gardien
	boss_node = spawn_boss(Vector3(0, 0, -6.0))

	# Extraction derrière le noyau,_initialement verrouillée
	add_exit(Vector3(0, 0, -29.0))
	neon_strip(Vector3(0, 5.0, -29.4), Vector3(6, 0.18, 0.12), "neon_cyan", false)
	point_light(Vector3(0, 4.0, -28), Color(0.2, 1.0, 0.6), 2.0, 12.0)
