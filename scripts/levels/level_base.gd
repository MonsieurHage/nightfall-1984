extends Node3D
class_name LevelBase

## Boîte à outils de construction des 5 environnements (géométrie, lumières, objets).

var spawn: Vector3 = Vector3(0, 0, 0)
var spawn_yaw: float = 0.0
var exit_marker: ExitPoint = null
var geometry_root: Node3D
var objects_root: Node3D
var enemies_root: Node3D
var pickups: Array[Node] = []
var props_meshes: Dictionary = {}
var props_scene: PackedScene = null
var alarm_cooldown: float = 0.0
var alarm_waves: int = 0


func _ready() -> void:
	_setup_environment()
	geometry_root = Node3D.new()
	geometry_root.name = "Geometry"
	add_child(geometry_root)
	objects_root = Node3D.new()
	objects_root.name = "Objects"
	add_child(objects_root)
	enemies_root = Node3D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)
	build()
	Game.current_level = self


func build() -> void:
	push_warning("LevelBase.build() doit être surchargé")


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.52, 0.65)
	env.ambient_light_energy = 2.2
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.003
	env.fog_light_color = Color(0.18, 0.24, 0.32)
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.25
	env.glow_hdr_threshold = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 1.35
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.04
	env.adjustment_brightness = 1.32
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.78, 1.0)
	moon.light_energy = 1.6
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-38, 24, 0)
	add_child(moon)


func _process(delta: float) -> void:
	alarm_cooldown = maxf(0.0, alarm_cooldown - delta)
	for p in pickups:
		if is_instance_valid(p):
			p.rotation.y += delta * 1.6
			p.position.y += sin(Time.get_ticks_msec() / 500.0 + p.get_instance_id()) * delta * 0.08


# ---------------------------------------------------------------- géométrie
func box(name: String, pos: Vector3, size: Vector3, mat: String = "concrete",
		collision: bool = true, rotation: Vector3 = Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var target := parent if parent != null else geometry_root
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.rotation = rotation
	body.collision_layer = 1 if collision else 0
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.name = name + "_mesh"
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Game.material(mat)
	body.add_child(mi)
	target.add_child(body)
	return mi


func floor_slab(pos: Vector3, size: Vector2, mat: String = "asphalt") -> void:
	box("floor", pos, Vector3(size.x, 0.25, size.y), mat)


func wall(pos: Vector3, size: Vector3, mat: String = "concrete", yaw: float = 0.0) -> void:
	box("wall", pos, size, mat, true, Vector3(0, yaw, 0))


func neon_strip(pos: Vector3, size: Vector3, color: String = "neon_cyan", with_light: bool = true) -> void:
	box("neon", pos, size, color, false)
	if with_light:
		var l := OmniLight3D.new()
		l.light_color = Game.material(color).emission
		l.light_energy = 2.2
		l.omni_range = 8.0
		l.position = pos
		l.shadow_enabled = false
		geometry_root.add_child(l)


func point_light(pos: Vector3, color: Color, energy: float = 2.0, light_range: float = 10.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.shadow_enabled = false
	l.position = pos
	geometry_root.add_child(l)


func add_rain(count: int = 650, extent: Vector3 = Vector3(48, 18, 60), center: Vector3 = Vector3.ZERO) -> void:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0.8, -24.0, 0.0)
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 20.0
	pm.direction = Vector3(0.05, -1.0, 0.0)
	pm.spread = 3.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extent * 0.5
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.55)
	var rain_mat := StandardMaterial3D.new()
	rain_mat.albedo_color = Color(0.55, 0.75, 1.0, 0.5)
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_mat.emission_enabled = true
	rain_mat.emission = Color(0.2, 0.4, 0.7)
	rain_mat.emission_energy_multiplier = 0.6
	quad.material = rain_mat
	p.draw_pass_1 = quad
	p.amount = count
	p.lifetime = 1.4
	p.preprocess = 1.2
	p.position = center
	geometry_root.add_child(p)


# ------------------------------------------------------------------ modèles
func _prop_mesh(name: String) -> Mesh:
	if props_meshes.has(name):
		return props_meshes[name]
	var path := "res://assets/models/props.glb"
	if props_scene == null and ResourceLoader.exists(path):
		props_scene = load(path) as PackedScene
	if props_scene:
		var inst := props_scene.instantiate()
		for c in _descendants(inst):
			if c is MeshInstance3D and String(c.name).contains(name):
				props_meshes[name] = (c as MeshInstance3D).mesh
				break
		inst.free()
	return props_meshes.get(name)


func _descendants(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in node.get_children():
		out.append(c)
		out.append_array(_descendants(c))
	return out


func prop(model: String, pos: Vector3, yaw: float = 0.0, scale: float = 1.0,
		collider_size: Vector3 = Vector3.ZERO, mat: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = model
	var mesh := _prop_mesh(model)
	if mesh:
		mi.mesh = mesh
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 0.8, 0.6)
		mi.mesh = bm
		mi.material_override = Game.material("dark_metal")
	if mat != "":
		mi.material_override = Game.material(mat)
	mi.position = pos
	mi.rotation.y = yaw
	mi.scale = Vector3(scale, scale, scale)
	if collider_size != Vector3.ZERO:
		var body := StaticBody3D.new()
		body.position = pos
		body.rotation.y = yaw
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = collider_size * scale
		cs.shape = bs
		body.add_child(cs)
		objects_root.add_child(body)
		mi.position = Vector3.ZERO
		mi.rotation.y = 0.0
		mi.scale = Vector3.ONE
		body.add_child(mi)
		mi.scale = Vector3(scale, scale, scale)
	else:
		objects_root.add_child(mi)
	return mi


# ------------------------------------------------------------------ objets
func spawn_pickup(kind: String, pos: Vector3, model: String = "MemoryChip") -> Pickup:
	var p := Pickup.new()
	p.kind = kind
	p.position = pos
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.35
	cs.shape = sph
	p.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := _prop_mesh(model)
	if mesh:
		mi.mesh = mesh
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 0.16, 0.04)
		mi.mesh = bm
	mi.material_override = Game.material("neon_cyan" if kind == "chip" else "neon_amber")
	p.add_child(mi)
	objects_root.add_child(p)
	pickups.append(p)
	return p


func add_terminal(pos: Vector3, yaw: float, context: String, themes: Array,
		objective: String = "quiz", label: String = "TERMINAL DE DIAGNOSTIC") -> Terminal:
	var t := Terminal.new()
	t.position = pos
	t.rotation.y = yaw
	t.context = context
	t.themes = themes
	t.objective_id = objective
	t.label_text = label
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.1, 1.4, 0.7)
	cs.shape = bs
	t.add_child(cs)
	var body_mesh := _prop_mesh("Console")
	if body_mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = body_mesh
		t.add_child(mi)
	var screen := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.7, 0.45, 0.04)
	screen.mesh = sm
	screen.position = Vector3(0, 0.45, -0.38)
	screen.material_override = Game.material("neon_cyan")
	t.add_child(screen)
	point_light(pos + Vector3(0, 1.2, -0.5), Color(0.15, 0.8, 1.0), 1.6, 5.0)
	objects_root.add_child(t)
	return t


func add_breaker(pos: Vector3, yaw: float, context: String, themes: Array,
		order_index: int, level_ref: Node, label: String) -> Breaker:
	var t := Breaker.new()
	t.position = pos
	t.rotation.y = yaw
	t.context = context
	t.themes = themes
	t.objective_id = "breakers"
	t.label_text = label
	t.order_index = order_index
	t.level_ref = level_ref
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.1, 1.6, 0.7)
	cs.shape = bs
	t.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 1.5, 0.6)
	mi.mesh = bm
	mi.material_override = Game.material("panel")
	t.add_child(mi)
	var lever := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.12, 0.55, 0.12)
	lever.mesh = lb
	lever.position = Vector3(0, 0.35, -0.38)
	lever.rotation.x = 0.4
	lever.material_override = Game.material("warning")
	t.add_child(lever)
	neon_strip(pos + Vector3(0, 1.1, -0.5), Vector3(0.5, 0.08, 0.05), "neon_amber", false)
	objects_root.add_child(t)
	return t


func add_door(pos: Vector3, yaw: float, required_objective: String = "", size: Vector3 = Vector3(2.6, 3.2, 0.35)) -> Door:
	var d := Door.new()
	d.position = pos
	d.rotation.y = yaw
	d.required_objective = required_objective
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	d.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Game.material("metal")
	d.add_child(mi)
	var stripe := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(size.x * 0.7, 0.08, 0.02)
	stripe.mesh = sb
	stripe.position = Vector3(0, 0, -size.z * 0.5 - 0.02)
	stripe.material_override = Game.material("neon_red")
	d.add_child(stripe)
	d.slide_height = size.y + 0.3
	objects_root.add_child(d)
	return d


func add_security_camera(pos: Vector3, yaw: float) -> SecurityCamera:
	var c := SecurityCamera.new()
	c.position = pos
	c.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.5, 0.35, 0.6)
	cs.shape = bs
	c.add_child(cs)
	var mesh := _prop_mesh("Camera")
	if mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		c.add_child(mi)
	else:
		box("camera_body", Vector3.ZERO, Vector3(0.4, 0.3, 0.5), "plastic", false, Vector3.ZERO, c)
	var lens := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.09
	lens.mesh = sph
	lens.name = "Lens"
	lens.position = Vector3(0, 0, -0.34)
	lens.material_override = Game.material("neon_red")
	c.add_child(lens)
	objects_root.add_child(c)
	return c


func add_jet(pos: Vector3, yaw: float = 0.0) -> JetHazard:
	var j := JetHazard.new()
	j.position = pos
	j.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.7, 2.8, 0.7)
	cs.shape = bs
	cs.position.y = 1.4
	j.add_child(cs)
	objects_root.add_child(j)
	return j


func add_valve(pos: Vector3, jet: Node) -> Valve:
	var v := Valve.new()
	v.position = pos
	v.linked_jet = jet
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.4
	cs.shape = sph
	v.add_child(cs)
	box("valve_wheel", Vector3(0, 0, -0.25), Vector3(0.5, 0.5, 0.08), "warning", false, Vector3.ZERO, v)
	objects_root.add_child(v)
	return v


func add_exit(pos: Vector3, yaw: float = 0.0) -> ExitPoint:
	var e := ExitPoint.new()
	e.position = pos
	e.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.0
	cyl.height = 2.4
	cs.shape = cyl
	cs.position.y = 1.2
	e.add_child(cs)
	objects_root.add_child(e)
	exit_marker = e
	return e


func add_vent(start: Vector3, end: Vector3, width: float = 1.4) -> void:
	var mid := (start + end) * 0.5
	var length := start.distance_to(end)
	var yaw := atan2(end.x - start.x, end.z - start.z)
	# Plancher, plafond bas et parois : le joueur doit se baisser (Ctrl).
	box("vent_floor", mid + Vector3(0, -0.08, 0), Vector3(width, 0.15, length), "metal", true, Vector3(0, yaw, 0))
	box("vent_roof", mid + Vector3(0, 1.25, 0), Vector3(width, 0.16, length), "metal", true, Vector3(0, yaw, 0))
	box("vent_left", mid + Vector3(-width * 0.5, 0.65, 0), Vector3(0.14, 1.2, length), "rust", true, Vector3(0, yaw, 0))
	box("vent_right", mid + Vector3(width * 0.5, 0.65, 0), Vector3(0.14, 1.2, length), "rust", true, Vector3(0, yaw, 0))
	var grate := prop("VentGrate", start, yaw, 1.0, Vector3(width, 1.2, 0.1))


# ------------------------------------------------------------------ ennemis
func spawn_enemy(kind: String, pos: Vector3, waypoints: Array = [], health: float = -1.0) -> Enemy:
	var e := Enemy.new()
	e.configure(kind, health, waypoints)
	e.position = pos
	enemies_root.add_child(e)
	return e


func spawn_boss(pos: Vector3) -> Boss:
	var b := Boss.new()
	b.position = pos
	enemies_root.add_child(b)
	return b


func spawn_minions(pos: Vector3, count: int = 2) -> void:
	for i in count:
		var a := TAU * float(i) / float(maxi(1, count))
		spawn_enemy("drone", pos + Vector3(cos(a) * 3.0, 1.2, sin(a) * 3.0), [], 35.0)


func trigger_alarm(pos: Vector3) -> void:
	if alarm_cooldown > 0.0:
		return
	alarm_cooldown = 12.0
	alarm_waves += 1
	Game.notify("ALARME — RENFORT EN APPROCHE", 3.0)
	spawn_minions(pos + Vector3(0, 0, 4.0), mini(3, 1 + alarm_waves))


func boss_laser(from: Vector3, to: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, from.distance_to(to))
	mi.mesh = bm
	mi.material_override = Game.material("neon_red")
	mi.global_position = from
	geometry_root.add_child(mi)
	mi.look_at(to, Vector3.UP)
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(0.01, 2.0, 1.0), 0.25)
	tw.tween_callback(mi.queue_free)


func open_exit() -> void:
	if exit_marker:
		exit_marker.prompt_text = "Activer l'extraction"
		point_light(exit_marker.global_position + Vector3(0, 2, 0), Color(0.2, 1.0, 0.5), 4.0, 12.0)
