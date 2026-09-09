extends SceneTree


func _init() -> void:
	var failed := false
	var asset_paths := [
		"res://assets/ui/camera_damage/camera_cracks_hit_1_a.png",
		"res://assets/ui/camera_damage/camera_cracks_hit_1_more.png",
		"res://assets/ui/camera_damage/camera_cracks_hit_1_b.png",
		"res://assets/ui/camera_damage/camera_cracks_hit_2_a.png",
		"res://assets/ui/camera_damage/camera_cracks_hit_2_b.png",
		"res://assets/ui/camera_damage/camera_cracks_hit_3_fatal.png",
		"res://assets/ui/camera_damage/camera_cracks_hit_3_fatal_clear_center.png",
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

	var fatal_original := (load("res://assets/ui/camera_damage/camera_cracks_hit_3_fatal.png") as Texture2D).get_image()
	var fatal_clear := (load("res://assets/ui/camera_damage/camera_cracks_hit_3_fatal_clear_center.png") as Texture2D).get_image()
	var original_center_alpha := 0.0
	var clear_center_alpha := 0.0
	for y in range(int(fatal_clear.get_height() * 0.30), int(fatal_clear.get_height() * 0.65)):
		for x in range(int(fatal_clear.get_width() * 0.38), int(fatal_clear.get_width() * 0.76)):
			original_center_alpha += fatal_original.get_pixel(x, y).a
			clear_center_alpha += fatal_clear.get_pixel(x, y).a
	var center_alpha_ratio := clear_center_alpha / maxf(original_center_alpha, 0.001)
	print("Rotura fatal central: %.1f%% del alpha original" % (center_alpha_ratio * 100.0))
	if center_alpha_ratio > 0.45:
		push_error("La rotura fatal central vuelve a tapar demasiado la escena")
		failed = true

	var blood_paths := [
		"res://assets/ui/blood_damage/blood_damage_hit_1.png",
		"res://assets/ui/blood_damage/blood_damage_hit_2.png",
		"res://assets/ui/blood_damage/blood_damage_hit_3.png",
	]
	var blood_coverages: Array[float] = []
	for blood_path in blood_paths:
		var blood_texture := load(blood_path) as Texture2D
		if blood_texture == null:
			push_error("No se pudo cargar: %s" % blood_path)
			failed = true
			continue
		var blood_image := blood_texture.get_image()
		var visible_blood_pixels := 0
		for y in blood_image.get_height():
			for x in blood_image.get_width():
				if blood_image.get_pixel(x, y).a >= 0.01:
					visible_blood_pixels += 1
		var coverage := float(visible_blood_pixels) / float(blood_image.get_width() * blood_image.get_height())
		blood_coverages.append(coverage)
		print("%s: cobertura %.1f%%" % [blood_path, coverage * 100.0])
	if blood_coverages.size() == 3:
		if not (blood_coverages[0] < blood_coverages[1] and blood_coverages[1] < blood_coverages[2]):
			push_error("La sangre no aumenta de forma progresiva con los tres golpes")
			failed = true
		if blood_coverages[2] > 0.25:
			push_error("La sangre fatal tapa demasiado la pantalla")
			failed = true

	var overlay_scene := load("res://systems/camera_damage_overlay.tscn") as PackedScene
	var overlay := overlay_scene.instantiate() as CanvasLayer
	root.add_child(overlay)
	await process_frame
	var cracks := overlay.get_node("Cracks") as TextureRect
	var blood := overlay.get_node("Blood") as TextureRect
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
		if level == 0 and blood.visible:
			push_error("La sangre aparece con la camara intacta")
			failed = true
		elif level > 0:
			var expected_blood_path: String = blood_paths[level - 1]
			if not blood.visible or blood.texture == null or blood.texture.resource_path != expected_blood_path:
				push_error("La fase %d no usa su capa de sangre correspondiente" % level)
				failed = true
		if level in [1, 2]:
			var minimum_brightness := 2.45 if level == 1 else 2.25
			var minimum_alpha := 1.95 if level == 1 else 1.65
			if float(crack_material.get_shader_parameter(&"crack_brightness")) < minimum_brightness \
					or float(crack_material.get_shader_parameter(&"alpha_boost")) < minimum_alpha \
					or float(crack_material.get_shader_parameter(&"tint_mix")) < 0.9 \
					or float(crack_material.get_shader_parameter(&"edge_thickness")) < 5.0:
				push_error("El nivel %d no atraviesa con suficiente fuerza el postfiltro" % level)
				failed = true
	overlay.set_damage_level(0, false)
	overlay.set_damage_level(1, true)
	if not cracks.texture.resource_path.ends_with("camera_cracks_hit_1_more.png"):
		push_error("El primer golpe no usa su imagen persistente")
		failed = true
	await create_timer(0.35).timeout
	if not cracks.texture.resource_path.ends_with("camera_cracks_hit_1_more.png"):
		push_error("El primer golpe ha cambiado de imagen durante la aparicion")
		failed = true
	overlay.set_damage_level(2, true)
	if not cracks.texture.resource_path.ends_with("camera_cracks_hit_2_a.png"):
		push_error("El segundo golpe no usa su imagen persistente")
		failed = true
	await create_timer(0.35).timeout
	if not cracks.texture.resource_path.ends_with("camera_cracks_hit_2_a.png"):
		push_error("El segundo golpe ha cambiado de imagen durante la aparicion")
		failed = true
	overlay.set_damage_level(3, false)
	if not cracks.texture.resource_path.ends_with("camera_cracks_hit_3_fatal_clear_center.png"):
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
		elif player_overlay.layer >= 101:
			push_error("Las grietas deben pasar por el postfiltro de camara de la capa 101 (capa actual: %d)" % player_overlay.layer)
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
