extends LevelBase
class_name LevelVents

## 03 — Conduits de ventilation et salle serveur : infiltration, caméras, cyber-sécurité.

func build() -> void:
	spawn = Vector3(0, 0, 12)
	spawn_yaw = 0.0

	# Salle d'accès
	floor_slab(Vector3(0, -0.12, 10), Vector2(18, 14), "concrete")
	box("access_ceiling", Vector3(0, 3.4, 10), Vector3(18, 0.3, 14), "metal", false)
	for x in [-9, 9]:
		box("access_wall", Vector3(x, 1.7, 10), Vector3(0.4, 3.4, 14), "concrete")
	box("access_end", Vector3(0, 1.7, 17), Vector3(18, 3.4, 0.4), "concrete")
	var grate_door := add_door(Vector3(0, 0.9, 5.6), 0.0, "", Vector3(1.8, 1.4, 0.2))
	grate_door.scale = Vector3(1.6, 1.6, 1.6)
	var grate_mesh := _prop_mesh("VentGrate")
	for c in grate_door.get_children():
		if c is MeshInstance3D and c.mesh is BoxMesh:
			(c as MeshInstance3D).mesh = grate_mesh
			(c as MeshInstance3D).material_override = Game.material("metal")
		elif c is MeshInstance3D:
			c.visible = false
	spawn_pickup("shrink", Vector3(-5.5, 0.8, 11), "ShrinkRay")
	var net_terminal := add_terminal(Vector3(6.4, 0.9, 12), -PI * 0.5, "information", ["information"], "quiz", "BORNE RÉSEAU")
	net_terminal.linked_door = grate_door

	# Conduit bas : 12 m à parcourir accroupi
	add_vent(Vector3(0, 0, 5.5), Vector3(0, 0, -7.5), 1.7)
	point_light(Vector3(0, 1.0, -1), Color(0.15, 0.6, 0.8), 1.4, 6.0)

	# Salle serveur
	floor_slab(Vector3(0, -0.12, -26), Vector2(30, 38), "metal")
	box("server_ceiling", Vector3(0, 5.4, -26), Vector3(30, 0.4, 38), "concrete", false)
	for x in [-15, 15]:
		box("server_wall", Vector3(x, 2.7, -26), Vector3(0.5, 5.4, 38), "concrete")
	box("server_end_left", Vector3(-9.5, 2.7, -41), Vector3(11, 5.4, 0.5), "concrete")
	box("server_end_right", Vector3(9.5, 2.7, -41), Vector3(11, 5.4, 0.5), "concrete")
	for i in range(7):
		var z := -11.0 - float(i) * 4.0
		prop("ServerRack", Vector3(-11.5, 1.4, z), PI * 0.5, 1.0, Vector3(1.0, 2.8, 2.0), "panel")
		prop("ServerRack", Vector3(11.5, 1.4, z), -PI * 0.5, 1.0, Vector3(1.0, 2.8, 2.0), "panel")
		for side in [-1.0, 1.0]:
			neon_strip(Vector3(side * 10.8, 2.4, z), Vector3(0.06, 1.8, 0.06),
				"neon_cyan" if i % 2 == 0 else "neon_green", false)
	point_light(Vector3(0, 4.6, -18), Color(0.2, 0.6, 1.0), 2.2, 16.0)
	point_light(Vector3(0, 4.6, -32), Color(0.2, 0.6, 1.0), 2.2, 16.0)

	# Caméras de surveillance
	add_security_camera(Vector3(-13.5, 3.6, -12), PI * 0.4)
	add_security_camera(Vector3(13.5, 3.6, -24), -PI * 0.6)
	add_security_camera(Vector3(-13.5, 3.6, -35), PI * 0.3)
	prop("Monitor", Vector3(0, 2.0, -16), 0.0, 1.0, Vector3(1.6, 1.0, 0.3), "screen")
	point_light(Vector3(0, 2.2, -15.5), Color(0.1, 0.8, 1.0), 1.2, 5.0)

	# Jets de vapeur et vannes
	var jet1 := add_jet(Vector3(-5.0, 0, -18))
	add_valve(Vector3(-8.0, 1.2, -18), jet1)
	var jet2 := add_jet(Vector3(5.0, 0, -32))
	add_valve(Vector3(8.0, 1.2, -32), jet2)

	# Conteneur rétrécissable bloquant l'alcôve du fusible
	box("alcove_floor", Vector3(-12.5, -0.1, -38), Vector3(5, 0.2, 5), "metal")
	var crate := Shrinkable.new()
	crate.position = Vector3(-10.3, 0.8, -38)
	var ccs := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(1.8, 1.6, 1.8)
	ccs.shape = cbox
	crate.add_child(ccs)
	var cmi := MeshInstance3D.new()
	var cmesh := BoxMesh.new()
	cmesh.size = Vector3(1.7, 1.5, 1.7)
	cmi.mesh = cmesh
	cmi.material_override = Game.material("rust")
	crate.add_child(cmi)
	objects_root.add_child(crate)
	spawn_pickup("fuse", Vector3(-13.5, 0.8, -39), "Battery")

	# Bornes sécurité / information
	add_terminal(Vector3(-5.0, 0.9, -26), PI, "securite", ["securite"], "quiz", "BORNE SÉCURITÉ")
	add_terminal(Vector3(5.0, 0.9, -36), 0.0, "information", ["information", "securite"], "quiz", "BORNE CYBER")

	# Ennemis
	spawn_enemy("endo", Vector3(-4, 0, -15), [Vector3(-4, 0, -15), Vector3(4, 0, -22)])
	spawn_enemy("endo", Vector3(6, 0, -29), [Vector3(6, 0, -29), Vector3(-6, 0, -35)])
	spawn_enemy("drone", Vector3(0, 3.0, -28), [Vector3(0, 3, -28), Vector3(8, 3.2, -14)])
	spawn_pickup("ammo", Vector3(0, 0.8, -20), "Battery")
	spawn_pickup("health", Vector3(12.0, 0.8, -37), "Medkit")

	# Sortie vers la centrale
	var door := add_door(Vector3(0, 2.0, -39.5), 0.0, "fuse")
	add_exit(Vector3(0, 0, -44))
	neon_strip(Vector3(0, 4.4, -39.8), Vector3(4, 0.14, 0.1), "neon_red", false)
