extends SceneTree

func _initialize() -> void:
	var props := ClassDB.class_get_property_list("Environment", true)
	var names: Array[String] = []
	for p in props:
		var n := String(p.get("name", ""))
		if n.contains("fog") or n.contains("glow") or n.contains("tonemap") or n.contains("adjustment") or n.contains("ssao"):
			names.append(n)
	print("ENV_PROPS: ", names)
	quit()
