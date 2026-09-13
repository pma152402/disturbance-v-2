extends SceneTree
## Regresiones de catálogo, proyección, luces y oclusión sin colisiones físicas.

var failures := 0
var checks := 0
var observer: Control
var camera: Camera3D
var world: Node3D


func _initialize() -> void:
	call_deferred(&"run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func wall_at(point: Vector3, size: Vector3) -> MeshInstance3D:
	var wall := MeshInstance3D.new()
	wall.name = "WallWithoutCollision%d" % world.get_child_count()
	var mesh := BoxMesh.new()
	mesh.size = size
	wall.mesh = mesh
	wall.position = point
	world.add_child(wall)
	return wall


func target_at(point: Vector3, id: StringName) -> Node3D:
	var target := Node3D.new()
	target.position = point
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	target.add_child(mesh)
	var observable := preload("res://systems/camera_observable.gd").new()
	observable.observation_id = id
	observable.display_name = "OBJETO DE PRUEBA"
	target.add_child(observable)
	world.add_child(target)
	return target


func analyze(extra: Dictionary = {}) -> Array[Dictionary]:
	var state := {"transform": camera.global_transform, "fov": 75.0, "near": 0.05, "far": 50.0, "cull_mask": 1}
	state.merge(extra, true)
	return observer.analyze_recorded_frame(state)


func run() -> void:
	root.size = Vector2i(960, 540)
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	camera = Camera3D.new()
	camera.position = Vector3(0, 1, 0)
	world.add_child(camera)
	camera.current = true
	observer = preload("res://systems/camera_observer.tscn").instantiate()
	root.add_child(observer)
	check(not observer.is_processing() and not observer.visible, "El Observador trabaja o dibuja fuera de ARCHIVO")
	observer.set_playback_analysis_active(true)
	var refreshes: int = observer._registry_refresh_count
	for frame in 20:
		analyze()
	observer.set_playback_analysis_active(true)
	check(observer._registry_refresh_count == refreshes, "Un catálogo vacío o activar dos veces ARCHIVO repite el inventario completo")

	var target := target_at(Vector3(0, 1, -4), &"audit_target")
	var light := OmniLight3D.new()
	light.position = Vector3(2, 1, -4)
	light.omni_range = 8
	world.add_child(light)
	await physics_frame
	var observations := analyze()
	check(observations.size() == 1 and observer.is_observing(&"audit_target"), "No se registró el objeto añadido durante ARCHIVO")
	refreshes = observer._registry_refresh_count
	for frame in 20:
		analyze()
	check(observer._registry_refresh_count == refreshes, "Un catálogo sin cambios se reconstruye cada fotograma")
	check(analyze({"far": 2.0}).is_empty(), "Detecta un objeto más allá del plano lejano")
	check(analyze({"near": 5.0}).is_empty(), "Detecta un objeto antes del plano cercano")

	light.light_negative = true
	observations = analyze()
	check(observations.size() == 1 and not observer.is_observing(&"audit_target"), "Una luz negativa habilita la detección")
	check("[DISABLED]" in observer.get_node("Readout").get_parsed_text(), "Se perdió la entrada deshabilitada del panel")
	check(observer.get_observation_ids().is_empty() and observer.get_observation_strength(&"audit_target") == 0, "DISABLED cuenta como evidencia activa")
	light.light_negative = false
	light.light_color = Color.BLACK
	analyze()
	check(not observer.is_observing(&"audit_target"), "Una luz negra habilita la detección")
	light.light_color = Color.WHITE
	light.light_energy = 0
	var other_view := SubViewport.new()
	other_view.own_world_3d = true
	root.add_child(other_view)
	var other_light := OmniLight3D.new()
	other_light.position = Vector3(0, 1, -3)
	other_light.omni_range = 10
	other_view.add_child(other_light)
	analyze()
	check(not observer.is_observing(&"audit_target"), "Una luz de otro World3D ilumina el catálogo principal")
	light.light_energy = 1

	var light_wall := wall_at(Vector3(1, 1, -4), Vector3(0.2, 2, 2))
	observations = analyze()
	check(observations.size() == 1 and not observer.is_observing(&"audit_target"), "La luz atraviesa una pared visible sin collider")
	light_wall.position.x = 4
	analyze()
	check(observer.is_observing(&"audit_target"), "Una pared desplazada sigue bloqueando la iluminación")
	var wall := wall_at(Vector3(0.6, 1, -2), Vector3(2, 2, 0.2))
	check(analyze().is_empty(), "La cámara ve a través de una pared sin collider")
	(wall.mesh as BoxMesh).size = Vector3(0.1, 0.1, 0.1)
	check(analyze().size() == 1, "Editar la malla conserva triángulos de oclusión obsoletos")
	(wall.mesh as BoxMesh).size = Vector3(2, 2, 0.2)
	wall.visible = false
	check(analyze().size() == 1, "Una pared oculta sigue bloqueando la cámara")
	wall.visible = true
	wall.layers = 2
	check(analyze().size() == 1, "Una pared fuera de las capas visibles sigue bloqueando")
	wall.layers = 1
	wall.scale = Vector3.ZERO
	check(analyze().size() == 1, "Una transformación singular deja el Observador bloqueado")
	wall.queue_free()
	light_wall.queue_free()
	await process_frame

	var body := StaticBody3D.new()
	body.add_to_group(&"player")
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	body.position = Vector3(0, 1, -2)
	world.add_child(body)
	await physics_frame
	check(analyze({"exclude_player": true}).size() == 1, "La cámara en primera persona se oculta con su propio cuerpo")
	check(analyze({"exclude_player": false}).is_empty(), "La cámara externa ignora el cuerpo del jugador que tapa el objeto")
	body.queue_free()
	await physics_frame
	check(observer._automatic_display_name("candle") == "VELA", "CAN corrompe el nombre de CANDLE")
	check(observer._automatic_display_name("camera") == "CAMARA", "Se corrompió el nombre de cámara")
	check(observer._automatic_display_name("bird_cage") == "JAULA", "Las frases no tienen prioridad al traducir etiquetas")
	check(observer._automatic_display_name("candlestick") == "CANDELABRO", "Una palabra corta corrompe una etiqueta larga")
	check(observer._automatic_display_name("typewriter") == "MAQUINA DE ESCRIBIR", "La traducción de etiquetas perdió una entrada válida")
	var physical_target := StaticBody3D.new()
	var target_collision := CollisionShape3D.new()
	target_collision.shape = BoxShape3D.new()
	physical_target.add_child(target_collision)
	target.add_child(physical_target)
	await physics_frame
	analyze()
	var component := target.get_child(1)
	check(component.get_observation_data().has_collision_geometry, "No se incorporó la colisión añadida después de _ready")
	target_collision.disabled = true
	await physics_frame
	check(analyze().size() == 1 and not component.get_observation_data().has_collision_geometry, "Desactivar la colisión hace desaparecer la malla visible")
	target_collision.disabled = false
	physical_target.collision_layer = 0
	check(not component.get_observation_data().has_collision_geometry, "Una colisión sin capas sigue exigiendo impacto físico")
	physical_target.queue_free()
	var area := Area3D.new()
	var area_shape := CollisionShape3D.new()
	area_shape.shape = BoxShape3D.new()
	area.add_child(area_shape)
	target.add_child(area)
	await physics_frame
	check(analyze().size() == 1 and not component.get_observation_data().has_collision_geometry, "Un área invisible de interacción se confunde con el cuerpo del objeto")
	target.queue_free()
	await process_frame
	check(analyze().is_empty(), "Un objeto eliminado permanece en las observaciones")
	observer.set_playback_analysis_active(false)
	check(not observer.is_processing() and not observer.visible and observer.get_current_observations().is_empty(), "Salir de ARCHIVO no limpia ni duerme el Observador")
	print("AUDITORÍA OBSERVADOR: %d comprobaciones, %d fallos" % [checks, failures])
	world.queue_free()
	other_view.queue_free()
	observer.queue_free()
	await process_frame
	quit(1 if failures else 0)
