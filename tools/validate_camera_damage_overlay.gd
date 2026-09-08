extends SceneTree


func _init() -> void:
	var failed := false
	var asset_paths := [
		"res://assets/ui/camera_damage/camera_cracks_hit_1_a.png",
		"res://assets/ui/camera_damage/camera_cracks_hit_1_b.png",
		"res://assets/ui/camera_damage/camera_cracks_hit_2_a.png",
		"res://assets/ui/camera_damage/camera_cracks_hit_2_b.png",
		"res://assets/ui/camera_damage/camera_cracks_hit_3_fatal.png",
	]
	for asset_path in asset_paths:
		var texture := load(asset_path) as Texture2D
		if texture == null:
			push_error("No se pudo cargar: %s" % asset_path)
			failed = true
			continue
		var image := texture.get_image()
		var transparent_pixels := 0
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a < 0.01:
					transparent_pixels += 1
		var transparent_ratio := float(transparent_pixels) / float(image.get_width() * image.get_height())
		print("%s: %dx%d, transparente %.1f%%" % [asset_path, image.get_width(), image.get_height(), transparent_ratio * 100.0])
		var minimum_transparency := 0.30 if asset_path.ends_with("hit_3_fatal.png") else 0.45
		if transparent_ratio < minimum_transparency:
			push_error("El overlay tapa demasiado la imagen: %s" % asset_path)
			failed = true

	var overlay_scene := load("res://systems/camera_damage_overlay.tscn") as PackedScene
	var overlay := overlay_scene.instantiate() as CanvasLayer
	root.add_child(overlay)
	await process_frame
	var cracks := overlay.get_node("Cracks") as TextureRect
	var crack_material := cracks.material as ShaderMaterial
	if crack_material == null \
			or float(crack_material.get_shader_parameter(&"crack_brightness")) <= 1.0 \
			or float(crack_material.get_shader_parameter(&"shadow_lift")) <= 0.0:
		push_error("Las grietas no tienen su aclarado local independiente del postfiltro")
		failed = true
	for level in [0, 1, 2, 3]:
		overlay.set_damage_level(level, false)
		if overlay.get_damage_level() != level:
			push_error("Nivel de dano incorrecto: %d" % level)
			failed = true
	overlay.set_damage_level(0, false)
	overlay.set_damage_level(1, true)
	if not cracks.texture.resource_path.ends_with("camera_cracks_hit_1_a.png"):
		push_error("El primer golpe no comienza por el fotograma 1A")
		failed = true
	await create_timer(0.35).timeout
	if not cracks.texture.resource_path.ends_with("camera_cracks_hit_1_b.png"):
		push_error("El primer golpe no termina en el fotograma 1B")
		failed = true
	overlay.set_damage_level(2, true)
	if not cracks.texture.resource_path.ends_with("camera_cracks_hit_2_a.png"):
		push_error("El segundo golpe no comienza por el fotograma 2A")
		failed = true
	await create_timer(0.35).timeout
	if not cracks.texture.resource_path.ends_with("camera_cracks_hit_2_b.png"):
		push_error("El segundo golpe no termina en el fotograma 2B")
		failed = true
	overlay.set_damage_level(3, false)
	if not cracks.texture.resource_path.ends_with("camera_cracks_hit_3_fatal.png"):
		push_error("El golpe mortal no conserva la ultima imagen fatal")
		failed = true
	overlay.queue_free()

	var player_scene := load("res://player/player.tscn") as PackedScene
	if player_scene == null:
		push_error("No se pudo cargar player.tscn")
		failed = true
	else:
		var player := player_scene.instantiate()
		var player_overlay := player.get_node_or_null("CameraDamageOverlay") as CanvasLayer
		if player_overlay == null:
			push_error("El jugador no contiene CameraDamageOverlay")
			failed = true
		elif player_overlay.layer >= 99:
			push_error("Las grietas deben renderizarse antes de los filtros de camara de las capas 99/101")
			failed = true
		var ancestor := player_overlay.get_parent() if player_overlay != null else null
		while ancestor != null:
			if ancestor is SubViewport:
				push_error("CameraDamageOverlay no puede estar dentro del SubViewport que graba la cinta")
				failed = true
				break
			ancestor = ancestor.get_parent()
		player.free()

	print("CAMERA_DAMAGE_VALIDATION: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
