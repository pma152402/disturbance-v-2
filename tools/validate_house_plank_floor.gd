extends SceneTree

const Layer := preload("res://environment/house_plank_floor.gd")

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var house := load("res://levels/house_baked.tscn").instantiate() as Node3D
	house.set_script(null)
	# Conservar las losas reales, incluidas sus colisiones; no arrancar todo el
	# mobiliario y la escuela para una regresion geometrica del revestimiento.
	for child: Node in house.get_children():
		if child.name not in [&"GroundFloor", &"UpperFloor", &"HousePlankFloor", &"FurnitureAndPickups"]:
			child.free()
	for branch_name in ["GroundFloor", "UpperFloor", "FurnitureAndPickups"]:
		for child: Node in house.get_node(branch_name).get_children():
			var path := str(house.get_path_to(child))
			var needed := false
			for source_path in Layer.SOURCE_PATHS:
				if str(source_path) == path or str(source_path).begins_with(path + "/"):
					needed = true
			if not needed:
				child.free()
	var old_meshes: Array[Mesh] = []
	for path in Layer.SOURCE_PATHS:
		old_meshes.append((house.get_node(path) as MeshInstance3D).mesh)
	var collision_count := house.find_children("*", "CollisionShape3D", true, false).size()
	root.add_child(house)
	current_scene = house
	await process_frame
	var layer := house.get_node("HousePlankFloor")
	assert(layer.surface_count > 0 and layer.surface_count <= Layer.SOURCE_PATHS.size(), "La capa debe agruparse, no crear un nodo por tablon")
	assert(layer.covered_area > 300.0 and layer.covered_area < 900.0, "Superficie de tarima fuera del rango de la vivienda")
	assert(house.find_children("*", "CollisionShape3D", true, false).size() == collision_count, "La capa modifica colisiones")
	assert(layer.find_children("*", "CollisionObject3D", true, false).is_empty(), "El revestimiento no debe afectar a la navegacion")
	for index in Layer.SOURCE_PATHS.size():
		assert((house.get_node(Layer.SOURCE_PATHS[index]) as MeshInstance3D).mesh == old_meshes[index], "Se ha sustituido el suelo original")
	var faces := PackedVector3Array()
	for panel: MeshInstance3D in layer.get_children():
		faces.append_array(panel.mesh.get_faces())
	assert(not _covered(faces, Vector2(-1.0, 0.0), 4.2), "La tarima tapa el hueco de escalera")
	assert(_covered(faces, Vector2(1.0, 1.0), 0.0), "Falta el revestimiento de planta baja")
	assert(_covered(faces, Vector2(5.0, 1.0), 4.2), "Falta el revestimiento superior")
	assert(not _covered(faces, Vector2(-4.7, 7.95), 0.0675), "La madera tapa los azulejos del bano")
	assert(not _covered(faces, Vector2(-4.7, 7.95), 0.0), "La madera invade la huella reservada al bano")
	for panel: MeshInstance3D in layer.get_children():
		var ground := str(panel.get_meta(&"floor_source")).begins_with("GroundFloor/")
		var marble: Variant = panel.material_override.get_shader_parameter(&"kitchen_marble")
		assert((marble == true) == ground, "El marmol debe limitarse a la planta baja")
	assert(not _covered(faces, Vector2(0.0, -30.0), 0.0), "La capa invade la iglesia")
	# La suma de triangulos no debe ocultar solapes. Muestrear puntos no
	# alineados con las juntas comprueba que cada zona se dibuja una sola vez.
	var samples := 0
	for height in [0.0, 4.2, 0.0675]:
		for ix in range(32):
			for iz in range(53):
				var point := Vector2(-7.873 + ix * 0.7, -23.819 + iz * 0.7)
				assert(_coverage_count(faces, point, height) <= 1, "Dos paneles se solapan y pueden parpadear")
				samples += 1
	var square := PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)])
	var inner := PackedVector2Array([Vector2(1, 1), Vector2(3, 1), Vector2(3, 3), Vector2(1, 3)])
	var area := 0.0
	for piece in Layer._subtract_convex(square, inner):
		area += Layer._area(piece)
	assert(is_equal_approx(area, 12.0), "El recorte de solapes no conserva el hueco interior")
	var count: int = layer.surface_count
	var total_area: float = layer.covered_area
	layer.rebuild()
	assert(layer.surface_count == count and is_equal_approx(layer.covered_area, total_area), "Regenerar duplica o altera la capa")
	print("OK: tarima %.2f m2, %d paneles, %d triangulos; %d muestras sin solapes; losas, colisiones y huecos conservados" % [total_area, count, faces.size() / 3, samples])
	if "--render" in OS.get_cmdline_user_args():
		await _render(house)
	house.queue_free()
	await process_frame
	quit(0)

func _covered(faces: PackedVector3Array, point: Vector2, height: float) -> bool:
	return _coverage_count(faces, point, height) > 0

func _coverage_count(faces: PackedVector3Array, point: Vector2, height: float) -> int:
	var count := 0
	for index in range(0, faces.size(), 3):
		if absf(faces[index].y - height) > 0.05:
			continue
		var normal := (faces[index + 1] - faces[index]).cross(faces[index + 2] - faces[index])
		if absf(normal.y) < 0.00001:
			continue
		assert(normal.y < 0.0, "La tarima debe tener la cara frontal orientada hacia arriba")
		var polygon := PackedVector2Array()
		for vertex in [faces[index], faces[index + 1], faces[index + 2]]:
			polygon.append(Vector2(vertex.x, vertex.z))
		if Geometry2D.is_point_in_polygon(point, polygon):
			count += 1
	return count

func _render(house: Node3D) -> void:
	house.get_node("UpperFloor").hide()
	for panel: MeshInstance3D in house.get_node("HousePlankFloor").get_children():
		panel.visible = panel.mesh.get_aabb().position.y < 1.0
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.14, 0.16)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.68, 0.75, 0.86)
	environment.environment.ambient_light_energy = 0.6
	house.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -30, 0)
	light.light_color = Color(1.0, 0.85, 0.65)
	light.light_energy = 1.3
	house.add_child(light)
	var camera := Camera3D.new()
	house.add_child(camera)
	camera.position = Vector3(3.0, 1.6, 3.8)
	camera.look_at(Vector3(1.0, 0.0, 0.5))
	camera.fov = 66.0
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/output/house_plank_floor.png")
