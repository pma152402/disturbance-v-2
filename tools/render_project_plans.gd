extends SceneTree

## Genera planos de trabajo a partir de la geometria real del proyecto.
## Uso: godot --path . --script res://tools/render_project_plans.gd

const OUTPUT_DIR := "res://DOCUMENTOS/planos"
const VIEW_SIZE := Vector2i(2200, 1600)
const BACKGROUND := Color("111820")
const GRID_MINOR := Color(0.37, 0.64, 0.72, 0.16)
const GRID_MAJOR := Color(0.53, 0.84, 0.91, 0.33)
const LABEL_COLOR := Color("e9f7f8")
const LABEL_ACCENT := Color("8edce8")
const KEY_COLORS := [
	Color("39d9e6"), # 1 Trastero
	Color("ff9f43"), # 2 Diogenes
	Color("ffd166"), # 3 Puerta principal
	Color("ef6aa8"), # 4 Dormitorio principal
	Color("9be564"), # 5 Ala norte
	Color("6da8ff"), # 6 Iglesia
	Color("aeb7c2"), # 7 Sotano, sin puerta vinculada
	Color("ff5e5b"), # 8 Azotea
]

var _camera: Camera3D
var _environment: WorldEnvironment
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _overlay: CanvasLayer


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = VIEW_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_setup_rendering()

	await _render_house_plan(
		"01_conjunto_planta_baja",
		"CONJUNTO · PLANTA BAJA",
		-0.45,
		3.72,
		Rect2(-37.0, -41.5, 54.0, 57.0),
		[
			["IGLESIA", Vector3(0.25, 7.0, -30.5), true],
			["ESCUELA", Vector3(-21.0, 7.0, -7.0), true],
			["CASA", Vector3(4.5, 7.0, -4.0), true],
			["SECRETARIA", Vector3(-31.8, 6.4, -11.3), false],
			["PROFESORES", Vector3(-31.8, 6.4, -5.7), false],
			["COCINA", Vector3(8.0, 6.4, 5.2), false],
			["SALON", Vector3(7.5, 6.4, -4.5), false],
			["RECEPCION", Vector3(-2.0, 6.4, 4.0), false],
		],
		"Corte 0,00–3,72 m · Norte arriba · Cuadricula de 1 m"
	)

	await _render_house_plan(
		"02_primera_planta_casa_escuela",
		"CASA + ESCUELA · PRIMERA PLANTA",
		3.88,
		7.95,
		Rect2(-36.0, -24.5, 53.0, 40.5),
		[
			["DORMITORIO", Vector3(-23.2, 11.2, -10.0), false],
			["AULA", Vector3(-17.8, 11.2, -10.0), false],
			["COMEDOR", Vector3(-16.0, 11.2, 1.7), false],
			["COCINA", Vector3(-21.2, 11.2, 2.0), false],
			["ENFERMERIA", Vector3(-31.8, 11.2, -11.2), false],
			["REUNION", Vector3(-31.8, 11.2, -5.7), false],
			["PUENTE", Vector3(-9.5, 11.2, -4.0), false],
			["DORMITORIO PRINCIPAL", Vector3(7.5, 11.2, -4.5), false],
			["ESTUDIO", Vector3(-1.0, 11.2, 4.8), false],
		],
		"Cota +4,16 m · Norte arriba · Cuadricula de 1 m"
	)

	await _render_house_plan(
		"03_segunda_planta_escuela",
		"ESCUELA · SEGUNDA PLANTA",
		8.15,
		12.10,
		Rect2(-36.0, -19.0, 25.0, 26.0),
		[
			["MANTENIMIENTO", Vector3(-31.8, 15.2, -11.2), false],
			["MATERIALES Y JUEGOS", Vector3(-31.8, 15.2, -5.7), false],
			["SALON DE ACTOS", Vector3(-20.8, 15.2, -11.0), false],
			["MUSICA", Vector3(-20.3, 15.2, 2.4), false],
			["LECTURA", Vector3(-15.6, 15.2, 2.4), false],
			["ESCALERA", Vector3(-28.3, 15.2, 1.8), false],
		],
		"Cota +8,40 m · Norte arriba · Cuadricula de 1 m"
	)

	await _render_house_plan(
		"04_sotano_caldera",
		"CASA · SOTANO Y CALDERA",
		-7.75,
		-3.65,
		Rect2(-15.5, -3.0, 18.5, 16.5),
		[
			["CALDERA", Vector3(-9.4, -1.0, 1.6), true],
			["CUARTO DE SERVICIO", Vector3(-3.0, -1.0, 1.6), false],
			["TUNEL", Vector3(-7.0, -1.0, 7.8), false],
			["ESCALERA", Vector3(-5.7, -1.0, 4.2), false],
		],
		"Cota aproximada -7,30 m · Norte arriba · Cuadricula de 1 m"
	)

	await _render_catacomb_plan()
	print("PLANOS: 5 imagenes guardadas en ", OUTPUT_DIR)
	quit(0)


func _setup_rendering() -> void:
	_environment = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d8edf0")
	environment.ambient_light_energy = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.environment = environment
	root.add_child(_environment)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-62.0, -28.0, 0.0)
	_sun.light_color = Color("e8f7f8")
	_sun.light_energy = 1.05
	_sun.shadow_enabled = true
	root.add_child(_sun)

	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(-48.0, 145.0, 0.0)
	_fill.light_color = Color("8cbac5")
	_fill.light_energy = 0.48
	root.add_child(_fill)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.current = true
	_camera.near = 0.1
	_camera.far = 500.0
	root.add_child(_camera)


func _render_house_plan(
	filename: String,
	title: String,
	min_y: float,
	max_y: float,
	bounds: Rect2,
	labels: Array,
	subtitle: String
) -> void:
	var scene := load("res://levels/house_baked.tscn").instantiate() as Node3D
	scene.set_script(null)
	root.add_child(scene)
	await process_frame
	_filter_visuals(scene, min_y, max_y, bounds)
	_add_grid(bounds, min_y + 0.04)
	_add_world_labels(labels)
	_add_access_markers(_markers_for(filename))
	_configure_camera(bounds, max_y + 70.0)
	_add_overlay(title, subtitle)
	_add_key_legend(filename)
	await _save_frame(filename)
	_clear_plan(scene)


func _render_catacomb_plan() -> void:
	var bounds := Rect2(-63.0, -187.0, 112.0, 143.0)
	var scene := load("res://environment/church_catacombs.tscn").instantiate() as Node3D
	scene.set_script(null)
	root.add_child(scene)
	await process_frame
	_filter_visuals(scene, -4.55, -0.25, bounds)
	_add_grid(bounds, -4.17)
	_add_world_labels([
		["ACCESO DESDE IGLESIA", Vector3(-6.0, 3.0, -52.0), true],
		["CATACUMBAS ESTE", Vector3(-2.0, 3.0, -104.0), true],
		["CRIPTA PROFUNDA", Vector3(-12.0, 3.0, -151.0), true],
		["CAMARA RITUAL", Vector3(19.5, 3.0, -161.7), false],
	], scene, 3.2)
	_configure_camera(bounds, 115.0)
	_add_overlay(
		"IGLESIA · CATACUMBAS",
		"Cota -4,25 m · Norte arriba · Cuadricula de 1 m"
	)
	await _save_frame("05_catacumbas")
	_clear_plan(scene)


func _filter_visuals(scene: Node3D, min_y: float, max_y: float, bounds: Rect2) -> void:
	for child: Node in scene.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual == null:
			continue
		var lowered_path := str(visual.get_path()).to_lower()
		if "roof" in lowered_path or "ceiling" in lowered_path or "occluder" in lowered_path:
			visual.visible = false
			continue
		var world_aabb := _world_aabb(visual)
		if world_aabb.size == Vector3.ZERO:
			continue
		var aabb_end := world_aabb.end
		var in_height := aabb_end.y >= min_y and world_aabb.position.y <= max_y
		var center := world_aabb.get_center()
		var in_bounds := bounds.grow(5.0).has_point(Vector2(center.x, center.z))
		visual.visible = in_height and in_bounds


func _world_aabb(visual: VisualInstance3D) -> AABB:
	if visual is MeshInstance3D:
		var mesh_instance := visual as MeshInstance3D
		if mesh_instance.mesh != null:
			return mesh_instance.global_transform * mesh_instance.get_aabb()
	elif visual is MultiMeshInstance3D:
		var multi_mesh_instance := visual as MultiMeshInstance3D
		if multi_mesh_instance.multimesh != null:
			return multi_mesh_instance.global_transform * multi_mesh_instance.get_aabb()
	return AABB()


func _configure_camera(bounds: Rect2, height: float) -> void:
	var center_2d := bounds.get_center()
	var aspect := float(VIEW_SIZE.x) / float(VIEW_SIZE.y)
	_camera.size = maxf(bounds.size.y, bounds.size.x / aspect) * 1.09
	_camera.position = Vector3(center_2d.x, height, center_2d.y)
	_camera.look_at(Vector3(center_2d.x, 0.0, center_2d.y), Vector3(0.0, 0.0, -1.0))


func _add_grid(bounds: Rect2, y: float) -> void:
	var minor_mesh := ImmediateMesh.new()
	var major_mesh := ImmediateMesh.new()
	minor_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	major_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var min_x := floori(bounds.position.x)
	var max_x := ceili(bounds.end.x)
	var min_z := floori(bounds.position.y)
	var max_z := ceili(bounds.end.y)
	for x: int in range(min_x, max_x + 1):
		var target := major_mesh if x % 5 == 0 else minor_mesh
		target.surface_add_vertex(Vector3(float(x), y, float(min_z)))
		target.surface_add_vertex(Vector3(float(x), y, float(max_z)))
	for z: int in range(min_z, max_z + 1):
		var target := major_mesh if z % 5 == 0 else minor_mesh
		target.surface_add_vertex(Vector3(float(min_x), y, float(z)))
		target.surface_add_vertex(Vector3(float(max_x), y, float(z)))
	minor_mesh.surface_end()
	major_mesh.surface_end()
	_add_grid_mesh(minor_mesh, GRID_MINOR)
	_add_grid_mesh(major_mesh, GRID_MAJOR)


func _add_grid_mesh(mesh: ImmediateMesh, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = false
	var instance := MeshInstance3D.new()
	instance.name = "PlanGrid"
	instance.add_to_group("plan_generated")
	instance.mesh = mesh
	instance.material_override = material
	root.add_child(instance)


func _add_world_labels(labels: Array, parent: Node = null, scale_factor: float = 1.0) -> void:
	var label_parent: Node = parent if parent != null else root
	for item: Array in labels:
		var label := Label3D.new()
		label.name = "PlanLabel"
		label.add_to_group("plan_generated")
		label.text = str(item[0])
		label.position = item[1] as Vector3
		label.font_size = 42 if bool(item[2]) else 30
		label.pixel_size = (0.015 if bool(item[2]) else 0.013) * scale_factor
		label.modulate = LABEL_ACCENT if bool(item[2]) else LABEL_COLOR
		label.outline_modulate = Color(0.02, 0.04, 0.05, 0.95)
		label.outline_size = 10
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label_parent.add_child(label)


func _markers_for(filename: String) -> Array:
	match filename:
		"01_conjunto_planta_baja":
			return [
				["P1", Vector3(-0.98, 30.0, -6.0), KEY_COLORS[0]],
				["P1", Vector3(-23.53, 30.0, -6.0), KEY_COLORS[0]],
				["P1", Vector3(-26.54, 30.0, -10.31), KEY_COLORS[0]],
				["P1", Vector3(-0.78, 30.0, -10.86), KEY_COLORS[0]],
				["P1", Vector3(-17.73, 30.0, -1.93), KEY_COLORS[0]],
				["L2", Vector3(6.79, 30.0, 10.40), KEY_COLORS[1]],
				["L3a", Vector3(4.62, 30.0, 12.60), KEY_COLORS[2]],
				["L3b", Vector3(1.53, 30.0, 10.34), KEY_COLORS[2], Vector3(0.95, 30.0, 12.00)],
				["P3", Vector3(-0.98, 30.0, 11.0), KEY_COLORS[2]],
				["L4*", Vector3(-4.78, 30.0, 8.04), KEY_COLORS[3]],
				["L5", Vector3(7.84, 30.0, 0.88), KEY_COLORS[4]],
				["P6", Vector3(-0.78, 30.0, -21.99), KEY_COLORS[5]],
				["L7a!", Vector3(1.78, 30.0, -35.73), KEY_COLORS[6]],
				["L7b!", Vector3(1.48, 30.0, 10.01), KEY_COLORS[6], Vector3(2.10, 30.0, 9.10)],
			]
		"02_primera_planta_casa_escuela":
			return [
				["L1", Vector3(3.68, 30.0, -3.54), KEY_COLORS[0]],
				["P2", Vector3(3.0, 30.0, -2.98), KEY_COLORS[1]],
				["P4", Vector3(3.0, 30.0, 7.98), KEY_COLORS[3]],
				["P5", Vector3(-0.78, 30.0, -21.99), KEY_COLORS[4]],
				["L6", Vector3(6.40, 30.0, 3.54), KEY_COLORS[5]],
				["P8", Vector3(-6.22, 30.0, -22.03), KEY_COLORS[7]],
			]
		"04_sotano_caldera":
			return [
				["L8", Vector3(-1.15, 30.0, 6.30), KEY_COLORS[7]],
			]
	return []


func _add_access_markers(markers: Array) -> void:
	for item: Array in markers:
		if item.size() > 3:
			var point := Label3D.new()
			point.name = "AccessMarkerPoint"
			point.add_to_group("plan_generated")
			point.text = "•"
			point.position = item[1] as Vector3
			point.font_size = 44
			point.pixel_size = 0.016
			point.modulate = item[2] as Color
			point.outline_modulate = Color(0.015, 0.025, 0.03, 1.0)
			point.outline_size = 10
			point.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			point.no_depth_test = true
			root.add_child(point)
		var marker := Label3D.new()
		marker.name = "AccessMarker"
		marker.add_to_group("plan_generated")
		marker.text = str(item[0])
		marker.position = (item[3] if item.size() > 3 else item[1]) as Vector3
		marker.font_size = 48
		marker.pixel_size = 0.020
		marker.modulate = item[2] as Color
		marker.outline_modulate = Color(0.015, 0.025, 0.03, 1.0)
		marker.outline_size = 14
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.no_depth_test = true
		root.add_child(marker)


func _legend_entries_for(filename: String) -> Array:
	match filename:
		"01_conjunto_planta_baja":
			return [
				["1", "TRASTERO · 5 PUERTAS", KEY_COLORS[0]],
				["2", "DIOGENES", KEY_COLORS[1]],
				["3", "PRINCIPAL · 2 COPIAS", KEY_COLORS[2]],
				["4", "DORMITORIO · OCULTA", KEY_COLORS[3]],
				["5", "ALA NORTE", KEY_COLORS[4]],
				["6", "IGLESIA", KEY_COLORS[5]],
				["7", "SOTANO · SIN PUERTA", KEY_COLORS[6]],
			]
		"02_primera_planta_casa_escuela":
			return [
				["1", "TRASTERO", KEY_COLORS[0]],
				["2", "DIOGENES", KEY_COLORS[1]],
				["4", "DORMITORIO", KEY_COLORS[3]],
				["5", "ALA NORTE", KEY_COLORS[4]],
				["6", "IGLESIA", KEY_COLORS[5]],
				["8", "AZOTEA", KEY_COLORS[7]],
			]
		"04_sotano_caldera":
			return [["8", "AZOTEA", KEY_COLORS[7]]]
	return []


func _add_key_legend(filename: String) -> void:
	var entries := _legend_entries_for(filename)
	if entries.is_empty() or _overlay == null:
		return
	var position := Vector2(1640.0, 34.0)
	if filename == "02_primera_planta_casa_escuela":
		position = Vector2(42.0, 1020.0)
	elif filename == "04_sotano_caldera":
		position = Vector2(1640.0, 200.0)
	var panel_height := 72.0 + float(entries.size()) * 34.0
	var panel := ColorRect.new()
	panel.position = position
	panel.size = Vector2(520.0, panel_height)
	panel.color = Color(0.035, 0.065, 0.082, 0.93)
	_overlay.add_child(panel)
	var heading := Label.new()
	heading.position = position + Vector2(20.0, 12.0)
	heading.text = "L = LLAVE   ·   P = PUERTA"
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", LABEL_ACCENT)
	_overlay.add_child(heading)
	for index: int in range(entries.size()):
		var entry: Array = entries[index]
		var row_y := position.y + 51.0 + float(index) * 34.0
		var swatch := ColorRect.new()
		swatch.position = Vector2(position.x + 20.0, row_y + 3.0)
		swatch.size = Vector2(20.0, 20.0)
		swatch.color = entry[2] as Color
		_overlay.add_child(swatch)
		var row := Label.new()
		row.position = Vector2(position.x + 52.0, row_y)
		row.text = str(entry[0]) + "  " + str(entry[1])
		row.add_theme_font_size_override("font_size", 17)
		row.add_theme_color_override("font_color", Color("e8f1f2"))
		_overlay.add_child(row)


func _add_overlay(title: String, subtitle: String) -> void:
	_overlay = CanvasLayer.new()
	root.add_child(_overlay)
	var panel := ColorRect.new()
	panel.position = Vector2(38.0, 34.0)
	panel.size = Vector2(850.0, 122.0)
	panel.color = Color(0.035, 0.065, 0.082, 0.91)
	_overlay.add_child(panel)
	var title_label := Label.new()
	title_label.position = Vector2(62.0, 49.0)
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", LABEL_ACCENT)
	_overlay.add_child(title_label)
	var subtitle_label := Label.new()
	subtitle_label.position = Vector2(64.0, 101.0)
	subtitle_label.text = subtitle
	subtitle_label.add_theme_font_size_override("font_size", 20)
	subtitle_label.add_theme_color_override("font_color", Color("c8dadd"))
	_overlay.add_child(subtitle_label)
	var north := Label.new()
	north.position = Vector2(VIEW_SIZE.x - 138.0, 43.0)
	north.text = "N\n↑"
	north.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	north.add_theme_font_size_override("font_size", 34)
	north.add_theme_color_override("font_color", LABEL_ACCENT)
	_overlay.add_child(north)


func _save_frame(filename: String) -> void:
	for _frame: int in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := OUTPUT_DIR + "/" + filename + ".png"
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("No se pudo guardar " + path + ": " + error_string(error))
	else:
		print("PLANO ", path)


func _clear_plan(scene: Node3D) -> void:
	scene.queue_free()
	for generated: Node in get_nodes_in_group("plan_generated"):
		if generated != null and not generated.is_queued_for_deletion():
			generated.queue_free()
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	await process_frame
