extends Control

signal observations_changed(observations: Array[Dictionary])
signal recording_summary_ready(summary: Dictionary)

const MAX_LIGHT_SOURCES_PER_TARGET := 4
const ObservableComponent := preload("res://systems/camera_observable.gd")
const DISABLED_READOUT_COLOR := Color(0.48, 0.52, 0.49, 0.96)
const VISUAL_OCCLUDER_NAME_HINTS := [
	"wall", "pared", "partition", "door", "puerta", "bulkhead", "gate",
	"ceiling", "techo", "roof", "slab", "floor", "suelo", "foundation",
]
const NON_OCCLUDING_VISUAL_HINTS := ["glass", "cristal", "curtain", "cortina"]
const AUTO_OBSERVABLE_PREFIXES := ["res://house_props/", "res://pickups/"]
const AUTO_OBSERVABLE_SKIP_HINTS := [
	"visual", "architecture", "surround", "guardrail", "balustrade",
	"grass", "floor_tile", "stair", "ceiling", "door", "gate",
	"column", "baseboard", "corridor", "landing", "shell",
]
const AUTO_LABEL_REPLACEMENTS := {
	"DARKROOM": "CUARTO FOTOGRAFICO", "OFFICE": "DESPACHO",
	"ANTIQUE": "ANTIGUO", "DETAILED": "", "EDITABLE": "",
	"PHOTO FRAME": "MARCO DE FOTO", "PHOTO": "FOTO", "FRAME": "MARCO",
	"BOOKCASE": "ESTANTERIA", "BOOK": "LIBRO", "SHELF": "ESTANTE",
	"TABLE": "MESA", "CHAIR": "SILLA", "DESK": "ESCRITORIO",
	"LAMP": "LAMPARA", "LIGHT": "LUZ", "LANTERN": "FAROL",
	"BOTTLE": "BOTELLA", "CAN": "LATA", "BUCKET": "CUBO",
	"BOXES": "CAJAS", "BOX": "CAJA", "CRATE": "CAJON",
	"BARREL": "BARRIL", "BASKET": "CESTA", "RUG": "ALFOMBRA",
	"CLOCK": "RELOJ", "TELEPHONE": "TELEFONO", "CAMERA": "CAMARA",
	"TYPEWRITER": "MAQUINA DE ESCRIBIR", "TEAPOT": "TETERA",
	"CUP": "TAZA", "DOLL": "MUNECA", "STATUE": "ESTATUA",
	"CANDLESTICK": "CANDELABRO", "CANDLE": "VELA", "MIRROR": "ESPEJO",
	"WARDROBE": "ARMARIO", "CHEST": "ARCON", "BED": "CAMA",
	"CUSHION": "COJIN", "CURTAINS": "CORTINAS", "HAT": "SOMBRERO",
	"MANNEQUIN": "MANIQUI", "TRICYCLE": "TRICICLO", "WALKER": "ANDADOR",
	"WRENCH": "LLAVE INGLESA", "HAMMER": "MARTILLO", "SCREWDRIVER": "DESTORNILLADOR",
	"CROWBAR": "PALANCA", "FUSE": "FUSIBLE", "KEY": "LLAVE",
	"FLASHLIGHT": "LINTERNA", "BATTERY": "PILA", "CASSETTE TAPE": "CINTA",
	"CASSETTE": "CINTA", "REMOTE": "MANDO", "RADIO": "RADIO",
	"NEWSPAPER": "PERIODICOS", "MEDICINES": "MEDICINAS", "TEETH": "DENTADURA",
	"POTTED PLANT": "PLANTA EN MACETA", "PLANT": "PLANTA", "FLOWER": "FLOR",
	"CHEMICAL": "QUIMICO", "DEVELOPING TRAYS": "BANDEJAS DE REVELADO",
	"FILM CANISTERS": "BOTES DE PELICULA", "POLAROID": "POLAROID",
	"ENLARGER": "AMPLIADORA", "EXPOSURE TIMER": "TEMPORIZADOR",
	"DIPLOMA": "DIPLOMA", "DOCUMENT TRAYS": "BANDEJAS DE DOCUMENTOS",
	"PENCIL": "LAPICES", "STAPLER": "GRAPADORA", "WASTEBASKET": "PAPELERA",
	"SKULL": "CRANEO", "BONE": "HUESOS", "COFFIN": "ATAUD",
	"SARCOPHAGUS": "SARCOFAGO", "URN": "URNA", "CHAINS": "CADENAS",
	"RAT": "RATA", "AQUARIUM": "ACUARIO", "BIRD CAGE": "JAULA",
	"CLOTHESLINE": "TENDEDERO", "LAUNDRY": "ROPA", "IRONING BOARD": "TABLA DE PLANCHAR",
	"DETERGENT": "DETERGENTE", "DRYING RACK": "ESCURREPLATOS",
	"RADIATOR": "RADIADOR", "FAN": "VENTILADOR", "BARBECUE": "BARBACOA",
	"PICNIC": "PICNIC", "BEACH": "PLAYA", "UMBRELLA": "SOMBRILLA",
	"ROOFTOP": "TEJADO", "ANTENNA": "ANTENA", "HVAC UNIT": "CLIMATIZADOR",
}

@export_category("Debug")
@export var debug_overlay_enabled := true:
	set(value):
		debug_overlay_enabled = value
		_update_observer_visibility()
@export var debug_live_camera_enabled := false:
	set(value):
		debug_live_camera_enabled = value
		_apply_processing_mode()
		_update_observer_visibility()
@export_range(0.08, 1.0, 0.01, "suffix:s") var sample_interval := 0.18
@export_range(0.5, 5.0, 0.1, "suffix:s") var registry_refresh_interval := 1.0
@export_range(1, 24, 1) var maximum_visibility_checks := 12
@export_range(1, 24, 1) var maximum_lighting_checks := 12

@onready var _readout: RichTextLabel = $Readout
@onready var _observer_header: Label = $Header

var _observables: Array[Node] = []
var _automatic_observables: Array[Dictionary] = []
var _local_lights: Array[Light3D] = []
var _visual_occluders: Array[MeshInstance3D] = []
var _visual_query_cache: Dictionary = {}
var _visual_sample_active := false
var _registry_dirty := true
var _registry_refresh_count := 0
var _label_rules: Array[Dictionary] = []
var _observations: Array[Dictionary] = []
var _sample_time := 0.0
var _registry_time := 0.0
var _recording_active := false
var _recording_started_msec := 0
var _recording_evidence: Dictionary = {}
var _last_recording_summary: Dictionary = {}
var _last_debug_text := ""
var _player_rids: Array[RID] = []
var _playback_analysis_active := false
var _analysis_camera: Camera3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"camera_observer")
	get_tree().node_added.connect(_mark_registry_dirty)
	get_tree().node_removed.connect(_mark_registry_dirty)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.visible = false
	_observer_header.visible = false
	_apply_processing_mode()
	if debug_live_camera_enabled:
		_refresh_registry()
	_update_debug_readout()


func _process(delta: float) -> void:
	# En ARCHIVO cada fotograma llama explicitamente a analyze_recorded_frame().
	# Este bucle solo existe como referencia de depuracion de la camara real.
	if _playback_analysis_active or not debug_live_camera_enabled:
		return
	_registry_time -= delta
	if _registry_dirty or _registry_time <= 0.0:
		_refresh_registry()
	_sample_time -= delta
	if _sample_time > 0.0:
		return
	_sample_time = sample_interval
	_sample_camera()


func set_playback_analysis_active(active: bool) -> void:
	if active == _playback_analysis_active:
		# La visibilidad puede haber cambiado desde fuera (transiciones, debug o
		# recarga del CanvasLayer), aunque el modo lógico siga siendo el mismo.
		_apply_processing_mode()
		_update_observer_visibility()
		return
	_playback_analysis_active = active
	_apply_processing_mode()
	_update_observer_visibility()
	if not active:
		_set_observations([])
		if debug_live_camera_enabled:
			_sample_time = 0.0
		return
	_refresh_registry()


func analyze_recorded_frame(camera_state: Dictionary) -> Array[Dictionary]:
	if not _playback_analysis_active or camera_state.is_empty():
		_set_observations([])
		return []
	if _registry_dirty:
		_refresh_registry()
	if not is_instance_valid(_analysis_camera):
		_analysis_camera = Camera3D.new()
		_analysis_camera.name = "PlaybackAnalysisCamera"
		_analysis_camera.current = false
		add_child(_analysis_camera)
	_analysis_camera.global_transform = camera_state.get("transform", Transform3D.IDENTITY) as Transform3D
	_analysis_camera.fov = float(camera_state.get("fov", 75.0))
	_analysis_camera.projection = int(camera_state.get("projection", Camera3D.PROJECTION_PERSPECTIVE))
	_analysis_camera.size = float(camera_state.get("size", 1.0))
	_analysis_camera.near = float(camera_state.get("near", 0.05))
	_analysis_camera.far = float(camera_state.get("far", 4000.0))
	_analysis_camera.cull_mask = int(camera_state.get("cull_mask", 1))
	_analysis_camera.keep_aspect = int(camera_state.get("keep_aspect", Camera3D.KEEP_HEIGHT))
	_analysis_camera.h_offset = float(camera_state.get("h_offset", 0.0))
	_analysis_camera.v_offset = float(camera_state.get("v_offset", 0.0))
	_analysis_camera.frustum_offset = camera_state.get("frustum_offset", Vector2.ZERO) as Vector2
	_analysis_camera.set_meta(&"observer_exclude_player", bool(camera_state.get("exclude_player", true)))
	_sample_camera(_analysis_camera)
	return get_current_observations()


func get_current_observations() -> Array[Dictionary]:
	return _observations.duplicate(true)


func get_observation_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for observation: Dictionary in _observations:
		if bool(observation.get("detection_enabled", true)):
			result.append(StringName(observation.get("id", &"")))
	return result


func is_observing(observation_id: StringName) -> bool:
	for observation: Dictionary in _observations:
		if (
			StringName(observation.get("id", &"")) == observation_id
			and bool(observation.get("detection_enabled", true))
		):
			return true
	return false


func get_observation_strength(observation_id: StringName) -> float:
	for observation: Dictionary in _observations:
		if (
			StringName(observation.get("id", &"")) == observation_id
			and bool(observation.get("detection_enabled", true))
		):
			return float(observation.get("strength", 0.0))
	return 0.0


func begin_recording_observation() -> void:
	_recording_active = true
	_recording_started_msec = Time.get_ticks_msec()
	_recording_evidence.clear()
	_update_debug_readout()


func end_recording_observation() -> Dictionary:
	if not _recording_active:
		return {}
	_recording_active = false
	var items: Array[Dictionary] = []
	for evidence: Variant in _recording_evidence.values():
		items.append((evidence as Dictionary).duplicate(true))
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("visible_seconds", 0.0)) > float(b.get("visible_seconds", 0.0))
	)
	_last_recording_summary = {
		"duration_seconds": float(Time.get_ticks_msec() - _recording_started_msec) / 1000.0,
		"observations": items,
	}
	_recording_evidence.clear()
	_update_debug_readout()
	recording_summary_ready.emit(_last_recording_summary.duplicate(true))
	return _last_recording_summary.duplicate(true)


func get_last_recording_summary() -> Dictionary:
	return _last_recording_summary.duplicate(true)


func set_debug_overlay_enabled(enabled: bool) -> void:
	debug_overlay_enabled = enabled


func set_live_camera_debug_enabled(enabled: bool) -> void:
	debug_live_camera_enabled = enabled
	if enabled and not _playback_analysis_active:
		_refresh_registry()
		_sample_time = 0.0
	elif not _playback_analysis_active:
		_set_observations([])


func _apply_processing_mode() -> void:
	if not is_inside_tree():
		return
	set_process(debug_live_camera_enabled and not _playback_analysis_active)


func _update_observer_visibility() -> void:
	# ARCHIVO es el uso real del Observador y nunca depende de los interruptores
	# de debug. Estos solo gobiernan la copia opcional sobre la camara en directo.
	var live_debug_visible := debug_overlay_enabled and debug_live_camera_enabled
	var visible_in_current_mode := _playback_analysis_active or live_debug_visible
	visible = visible_in_current_mode
	# La referencia en directo queda tenue; en ARCHIVO debe leerse con la misma
	# presencia que el resto de la interfaz pixelada.
	modulate.a = 1.0 if _playback_analysis_active else 0.2
	if is_instance_valid(_readout):
		_readout.visible = visible_in_current_mode
	if is_instance_valid(_observer_header):
		_observer_header.visible = visible_in_current_mode


func _mark_registry_dirty(node: Node) -> void:
	# Agrupar altas/bajas hasta el siguiente análisis, sin recorrer el árbol
	# por cada pieza de una escena. La cámara auxiliar no cambia el catálogo.
	if (node is Node3D and node is not Camera3D) or node.has_method(&"get_observation_data"):
		_registry_dirty = true


func _refresh_registry() -> void:
	_registry_dirty = false
	_registry_refresh_count += 1
	_registry_time = registry_refresh_interval
	_observables.clear()
	for candidate: Node in get_tree().get_nodes_in_group(&"camera_observable"):
		if is_instance_valid(candidate) and candidate.has_method(&"get_observation_data"):
			if candidate.has_method(&"refresh_geometry_cache"):
				candidate.call(&"refresh_geometry_cache")
			_observables.append(candidate)
	_local_lights.clear()
	_visual_occluders.clear()
	var scene_roots: Array[Node3D] = []
	var world := get_viewport().world_3d
	# Un solo inventario sustituye los tres recorridos completos de luces,
	# mallas y escenas automáticas. Las vistas de otro World3D no participan.
	for candidate: Node in get_tree().root.find_children("*", "Node3D", true, false):
		var spatial := candidate as Node3D
		if spatial.get_world_3d() != world:
			continue
		# La luz direccional nocturna da legibilidad al escenario, pero no revela
		# objetos al Observador. Este necesita una fuente local real sobre ellos.
		if spatial is Light3D and spatial is not DirectionalLight3D:
			_local_lights.append(spatial as Light3D)
		if spatial is MeshInstance3D and spatial.mesh != null and _is_visual_occluder(spatial):
			_visual_occluders.append(spatial as MeshInstance3D)
		if not spatial.scene_file_path.is_empty():
			scene_roots.append(spatial)
	_refresh_automatic_observables(scene_roots)
	_player_rids.clear()
	var player := get_tree().get_first_node_in_group(&"player") as CollisionObject3D
	if player != null:
		_player_rids.append(player.get_rid())


func _sample_camera(camera_override: Camera3D = null) -> void:
	var camera := camera_override if is_instance_valid(camera_override) else get_viewport().get_camera_3d()
	if camera == null or not camera.is_inside_tree():
		_set_observations([])
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		_set_observations([])
		return
	var frustum := camera.get_frustum()
	var candidates: Array[Dictionary] = []
	for observable: Node in _observables:
		if not is_instance_valid(observable):
			continue
		var root := observable.call(&"get_observation_root") as Node3D
		if root == null or not root.is_visible_in_tree() or root.get_world_3d() != camera.get_world_3d():
			continue
		var center := observable.call(&"get_focus_position") as Vector3
		if not _inside_frustum(center, frustum):
			continue
		var data := observable.call(&"get_observation_data") as Dictionary
		if not bool(data.get("enabled", true)):
			continue
		if (camera.cull_mask & int(data.get("visibility_layer_mask", 1))) == 0:
			continue
		var distance := camera.global_position.distance_to(center)
		if distance > float(data.get("maximum_distance", 18.0)):
			continue
		if observable.has_method(&"is_renderable_by") and not bool(observable.call(&"is_renderable_by", camera)):
			continue
		var screen_center := camera.unproject_position(center)
		var radius := float(data.get("radius", 0.5))
		var edge_world := center + camera.global_basis.x.normalized() * radius
		var projected_radius := screen_center.distance_to(camera.unproject_position(edge_world))
		var screen_fraction := (projected_radius * 2.0) / minf(viewport_size.x, viewport_size.y)
		if screen_fraction < float(data.get("minimum_screen_fraction", 0.012)):
			continue
		# Criterio deliberadamente estricto: el centro semantico real tiene que
		# caer dentro del fotograma. Una esfera aproximada rozando el borde no
		# basta, porque produciria objetos anunciados que no se ven de verdad.
		if (
			screen_center.x < 0.0
			or screen_center.y < 0.0
			or screen_center.x > viewport_size.x
			or screen_center.y > viewport_size.y
		):
			continue
		var center_distance := screen_center.distance_to(viewport_size * 0.5)
		var center_score := 1.0 - clampf(center_distance / (viewport_size.length() * 0.5), 0.0, 1.0)
		var size_score := clampf(screen_fraction * 7.5, 0.0, 1.0)
		var priority_score := clampf(float(data.get("priority", 1.0)) * 0.025, 0.0, 0.2)
		data["node"] = root
		data["observable"] = observable
		data["world_position"] = center
		data["screen_position"] = screen_center
		data["distance"] = distance
		data["screen_fraction"] = screen_fraction
		data["strength"] = clampf(center_score * 0.62 + size_score * 0.38 + priority_score, 0.0, 1.0)
		candidates.append(data)
	for automatic: Dictionary in _automatic_observables:
		if not is_instance_valid(automatic.get("node")):
			continue
		var root := automatic.get("node") as Node3D
		if not root.is_visible_in_tree() or root.get_world_3d() != camera.get_world_3d():
			continue
		var center := root.to_global(automatic.get("local_focus", Vector3.ZERO) as Vector3)
		if not _inside_frustum(center, frustum):
			continue
		var distance := camera.global_position.distance_to(center)
		if distance > float(automatic.get("maximum_distance", 18.0)):
			continue
		if not _automatic_is_renderable(automatic, camera):
			continue
		var screen_center := camera.unproject_position(center)
		var radius := float(automatic.get("radius", 0.5))
		var edge_world := center + camera.global_basis.x.normalized() * radius
		var projected_radius := screen_center.distance_to(camera.unproject_position(edge_world))
		var screen_fraction := (projected_radius * 2.0) / minf(viewport_size.x, viewport_size.y)
		if screen_fraction < float(automatic.get("minimum_screen_fraction", 0.009)):
			continue
		if (
			screen_center.x < 0.0
			or screen_center.y < 0.0
			or screen_center.x > viewport_size.x
			or screen_center.y > viewport_size.y
		):
			continue
		var center_distance := screen_center.distance_to(viewport_size * 0.5)
		var center_score := 1.0 - clampf(center_distance / (viewport_size.length() * 0.5), 0.0, 1.0)
		var size_score := clampf(screen_fraction * 7.5, 0.0, 1.0)
		var data := automatic.duplicate()
		data["has_collision_geometry"] = ObservableComponent.has_active_body_collision(automatic.collisions)
		data.erase("geometries")
		data.erase("collisions")
		data.erase("local_focus")
		data["world_position"] = center
		data["screen_position"] = screen_center
		data["distance"] = distance
		data["screen_fraction"] = screen_fraction
		data["strength"] = clampf(center_score * 0.62 + size_score * 0.38, 0.0, 1.0)
		candidates.append(data)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("strength", 0.0)) > float(b.get("strength", 0.0))
	)
	var visible_observations: Array[Dictionary] = []
	var checked := 0
	var lighting_checked := 0
	var checks_by_id: Dictionary = {}
	_visual_query_cache.clear()
	_visual_sample_active = true
	for candidate: Dictionary in candidates:
		var needs_los := bool(candidate.get("require_line_of_sight", true))
		if needs_los:
			if checked >= maximum_visibility_checks:
				continue
			var semantic_id := StringName(candidate.get("id", &"object"))
			var same_id_checks := int(checks_by_id.get(semantic_id, 0))
			if same_id_checks >= 2:
				continue
			checks_by_id[semantic_id] = same_id_checks + 1
			checked += 1
			if not _has_line_of_sight(camera, candidate):
				continue
		if lighting_checked >= maximum_lighting_checks:
			continue
		lighting_checked += 1
		candidate["detection_enabled"] = _is_illuminated(candidate)
		candidate.erase("observable")
		visible_observations.append(candidate)
	_visual_sample_active = false
	_visual_query_cache.clear()
	_set_observations(_merge_semantic_duplicates(visible_observations))


func _inside_frustum(point: Vector3, planes: Array[Plane]) -> bool:
	for plane in planes:
		if plane.distance_to(point) > 0.0:
			return false
	return true


func _refresh_automatic_observables(scene_roots: Array[Node3D]) -> void:
	_automatic_observables.clear()
	var explicit_roots: Dictionary = {}
	for observable: Node in _observables:
		var explicit_root := observable.call(&"get_observation_root") as Node3D
		if is_instance_valid(explicit_root):
			explicit_roots[explicit_root.get_instance_id()] = true
	for root: Node3D in scene_roots:
		if not is_instance_valid(root) or root.scene_file_path.is_empty():
			continue
		if explicit_roots.has(root.get_instance_id()) or not _is_auto_observable_scene(root.scene_file_path):
			continue
		var descriptor := _build_automatic_observable(root)
		if not descriptor.is_empty():
			_automatic_observables.append(descriptor)


func _is_auto_observable_scene(scene_path: String) -> bool:
	var accepted := false
	for prefix: String in AUTO_OBSERVABLE_PREFIXES:
		if scene_path.begins_with(prefix):
			accepted = true
			break
	if not accepted:
		return false
	var basename := scene_path.get_file().get_basename().to_lower()
	for hint: String in AUTO_OBSERVABLE_SKIP_HINTS:
		if hint in basename:
			return false
	return true


func _build_automatic_observable(root: Node3D) -> Dictionary:
	var geometries: Array[GeometryInstance3D] = []
	var world_bounds := AABB()
	var has_bounds := false
	var visibility_mask := 0
	for child: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := child as GeometryInstance3D
		if geometry == null or geometry is GPUParticles3D:
			continue
		geometries.append(geometry)
		visibility_mask |= geometry.layers
		if geometry is MeshInstance3D and (geometry as MeshInstance3D).mesh != null:
			var bounds := geometry.global_transform * (geometry as MeshInstance3D).get_aabb()
			world_bounds = world_bounds.merge(bounds) if has_bounds else bounds
			has_bounds = true
	if not has_bounds or geometries.is_empty():
		return {}
	var largest_dimension := maxf(world_bounds.size.x, maxf(world_bounds.size.y, world_bounds.size.z))
	# Evita convertir habitaciones completas o arquitectura accidental en un
	# unico objetivo semantico; los componentes decorativos siguen entrando.
	if largest_dimension > 9.0:
		return {}
	var basename := root.scene_file_path.get_file().get_basename()
	var collisions := ObservableComponent.collect_collision_nodes(root)
	return {
		"id": StringName("auto_%s" % basename),
		"label": _automatic_display_name(basename),
		"node": root,
		"geometries": geometries,
		"collisions": collisions,
		"local_focus": root.to_local(world_bounds.get_center()),
		"radius": clampf(largest_dimension * 0.5, 0.08, 3.2),
		"maximum_distance": clampf(12.0 + largest_dimension * 2.5, 12.0, 30.0),
		"minimum_screen_fraction": 0.009,
		"priority": 1.0,
		"require_line_of_sight": true,
		"visibility_layer_mask": visibility_mask if visibility_mask != 0 else 1,
		"has_collision_geometry": ObservableComponent.has_active_body_collision(collisions),
	}


func _automatic_is_renderable(data: Dictionary, camera: Camera3D) -> bool:
	for value: Variant in data.get("geometries", []) as Array:
		var geometry := value as GeometryInstance3D
		if (
			is_instance_valid(geometry)
			and geometry.is_visible_in_tree()
			and (geometry.layers & camera.cull_mask) != 0
		):
			return true
	return false


func _automatic_display_name(basename: String) -> String:
	var label := basename.replace("_", " ").to_upper()
	if _label_rules.is_empty():
		var phrases := AUTO_LABEL_REPLACEMENTS.keys()
		phrases.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
		for source: String in phrases:
			var pattern := RegEx.new()
			pattern.compile("\\b%s\\b" % source)
			_label_rules.append({"pattern": pattern, "replacement": AUTO_LABEL_REPLACEMENTS[source]})
	for rule in _label_rules:
		label = (rule.pattern as RegEx).sub(label, rule.replacement, true)
	while "  " in label:
		label = label.replace("  ", " ")
	return label.strip_edges()


func get_catalog_counts() -> Dictionary:
	return {
		"manual": _observables.size(),
		"automatic": _automatic_observables.size(),
		"total": _observables.size() + _automatic_observables.size(),
	}


func _has_line_of_sight(camera: Camera3D, candidate: Dictionary) -> bool:
	var world := get_viewport().world_3d
	if world == null:
		return false
	var target := candidate.get("node") as Node3D
	var end_position := candidate.get("world_position", Vector3.ZERO) as Vector3
	var has_collision_geometry := bool(candidate.get("has_collision_geometry", false))
	if has_collision_geometry:
		var ray_direction := camera.global_position.direction_to(end_position)
		end_position += ray_direction * minf(float(candidate.get("radius", 0.5)) * 0.45, 0.35)
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, end_position)
	query.collision_mask = 0xFFFFFFFF
	# Las Areas son volumenes logicos invisibles (interaccion, audio, triggers),
	# por lo que no deben tapar visualmente un objeto.
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var target_is_player := target != null and target.is_in_group(&"player")
	var exclude_player := bool(camera.get_meta(&"observer_exclude_player", camera.name != &"FilmingCamera"))
	query.exclude = _player_rids if exclude_player and not target_is_player else []
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.has("collider"):
		# Si el observable tiene cuerpo fisico, el rayo debe tocarlo. Esto evita
		# aceptar como visible un punto teorico situado al otro lado de una pared.
		if has_collision_geometry:
			return false
		return not _is_blocked_by_visual_geometry(camera, candidate)
	var collider: Node = hit["collider"] as Node
	while collider != null:
		if collider == target:
			return not _is_blocked_by_visual_geometry(camera, candidate)
		collider = collider.get_parent()
	return false


func _is_visual_occluder(geometry: MeshInstance3D) -> bool:
	# El nombre de la malla o de su padre inmediato cubre la arquitectura
	# estatica. No heredamos nombres de ancestros lejanos: algunas escenas
	# cuelgan decoracion de un StaticBody llamado Wall y no debe volverse opaca.
	var context := String(geometry.name).to_lower()
	if geometry.get_parent() != null:
		context += " " + String(geometry.get_parent().name).to_lower()
	for hint: String in NON_OCCLUDING_VISUAL_HINTS:
		if hint in context:
			return false
	for hint: String in VISUAL_OCCLUDER_NAME_HINTS:
		if hint in context:
			return true
	# La hoja visual de las puertas esta un nivel por debajo de su bisagra
	# animable. Consultamos ese contexto solo para cuerpos moviles, de modo que
	# la prueba siga a la puerta abierta/cerrada sin absorber decorado vecino.
	var current: Node = geometry.get_parent()
	for _index in 3:
		if current == null:
			break
		if current is AnimatableBody3D:
			var moving_context := String(current.name).to_lower()
			if current.get_parent() != null:
				moving_context += " " + String(current.get_parent().name).to_lower()
			for hint: String in VISUAL_OCCLUDER_NAME_HINTS:
				if hint in moving_context:
					return true
			break
		current = current.get_parent()
	return false


func _is_blocked_by_visual_geometry(camera: Camera3D, candidate: Dictionary) -> bool:
	var target := candidate.get("node") as Node3D
	var ray_end := candidate.get("world_position", Vector3.ZERO) as Vector3
	return _visual_segment_is_blocked(camera.global_position, ray_end, camera.cull_mask, target)


func _visual_segment_is_blocked(ray_origin: Vector3, ray_end: Vector3, layer_mask: int, target: Node3D) -> bool:
	for geometry: MeshInstance3D in _visual_occluders:
		if (
			not is_instance_valid(geometry)
			or not geometry.is_inside_tree()
			or not geometry.is_visible_in_tree()
			or geometry.mesh == null
			or (geometry.layers & layer_mask) == 0
			or geometry.get_world_3d() != get_viewport().world_3d
			or (target != null and (geometry == target or target.is_ancestor_of(geometry)))
		):
			continue
		var geometry_data := _visual_geometry_data(geometry)
		if geometry_data.is_empty():
			continue
		var world_bounds: AABB = geometry_data.bounds
		if world_bounds.intersects_segment(ray_origin, ray_end) == null:
			continue
		if not geometry_data.has("inverse"):
			geometry_data["inverse"] = (geometry_data.pose as Transform3D).affine_inverse()
		var inverse_transform: Transform3D = geometry_data.inverse
		var local_origin := inverse_transform * ray_origin
		var local_end := inverse_transform * ray_end
		# Mesh conserva e invalida su árbol de triángulos al editarse. La consulta
		# nativa evita recorrer cada cara en GDScript y respeta huecos reales.
		var triangles := geometry.mesh.generate_triangle_mesh()
		if triangles != null and not triangles.intersect_segment(local_origin, local_end).is_empty():
			return true
	return false


func _visual_geometry_data(geometry: MeshInstance3D) -> Dictionary:
	var key := geometry.get_instance_id()
	if _visual_sample_active and _visual_query_cache.has(key):
		return _visual_query_cache[key]
	var pose := geometry.global_transform
	if absf(pose.basis.determinant()) < 0.000001:
		return {}
	var data := {"bounds": pose * geometry.get_aabb(), "pose": pose}
	if _visual_sample_active:
		_visual_query_cache[key] = data
	return data


func _is_illuminated(candidate: Dictionary) -> bool:
	var point := candidate.get("world_position", Vector3.ZERO) as Vector3
	var target_layer_mask := int(candidate.get("visibility_layer_mask", 1))
	var nearby_lights: Array[Light3D] = []
	var distances: Array[float] = []
	for light: Light3D in _local_lights:
		if _light_can_reach_point(light, point, target_layer_mask):
			var distance := light.global_position.distance_squared_to(point)
			var index := distances.bsearch(distance)
			if index < MAX_LIGHT_SOURCES_PER_TARGET:
				nearby_lights.insert(index, light)
				distances.insert(index, distance)
				if nearby_lights.size() > MAX_LIGHT_SOURCES_PER_TARGET:
					nearby_lights.pop_back()
					distances.pop_back()
	for index in mini(nearby_lights.size(), MAX_LIGHT_SOURCES_PER_TARGET):
		var light := nearby_lights[index]
		if not _light_is_occluded(light, point, candidate.get("node") as Node3D):
			return true
	return false


func _light_can_reach_point(light: Light3D, point: Vector3, target_layer_mask: int) -> bool:
	if (
		not is_instance_valid(light)
		or not light.is_inside_tree()
		or light.get_world_3d() != get_viewport().world_3d
		or not light.is_visible_in_tree()
		or light.light_energy <= 0.01
		or light.light_negative
		or light.light_color.get_luminance() <= 0.001
		or light.light_cull_mask == 0
		or (light.light_cull_mask & target_layer_mask) == 0
	):
		return false
	var offset := point - light.global_position
	var distance := offset.length()
	if light is OmniLight3D:
		return distance <= (light as OmniLight3D).omni_range
	if light is SpotLight3D:
		var spot := light as SpotLight3D
		if distance > spot.spot_range or distance <= 0.001:
			return false
		var forward := -spot.global_basis.z.normalized()
		return forward.dot(offset / distance) >= cos(deg_to_rad(spot.spot_angle))
	return false


func _light_is_occluded(light: Light3D, point: Vector3, target: Node3D) -> bool:
	var world := get_viewport().world_3d
	if world == null:
		return true
	var direction := light.global_position.direction_to(point)
	var query := PhysicsRayQueryParameters3D.create(
		light.global_position + direction * 0.08,
		point - direction * 0.03
	)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = _player_rids
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.has("collider"):
		return _visual_segment_is_blocked(query.from, query.to, light.light_cull_mask, target)
	var collider: Node = hit["collider"] as Node
	while collider != null:
		if collider == target:
			return _visual_segment_is_blocked(query.from, query.to, light.light_cull_mask, target)
		collider = collider.get_parent()
	return true


func _merge_semantic_duplicates(source: Array[Dictionary]) -> Array[Dictionary]:
	var by_id: Dictionary = {}
	for observation: Dictionary in source:
		var id := StringName(observation.get("id", &"object"))
		if not by_id.has(id):
			var first := observation.duplicate()
			first["instance_count"] = 1
			by_id[id] = first
			continue
		var existing := by_id[id] as Dictionary
		var count := int(existing.get("instance_count", 1)) + 1
		var observation_enabled := bool(observation.get("detection_enabled", true))
		var existing_enabled := bool(existing.get("detection_enabled", true))
		if (
			(observation_enabled and not existing_enabled)
			or (
				observation_enabled == existing_enabled
				and float(observation.get("strength", 0.0)) > float(existing.get("strength", 0.0))
			)
		):
			existing = observation.duplicate()
		existing["instance_count"] = count
		by_id[id] = existing
	var result: Array[Dictionary] = []
	for observation: Variant in by_id.values():
		result.append(observation as Dictionary)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("strength", 0.0)) > float(b.get("strength", 0.0))
	)
	return result


func _set_observations(next_observations: Array[Dictionary]) -> void:
	var changed := _observation_signature(_observations) != _observation_signature(next_observations)
	_observations = next_observations
	if _recording_active:
		_accumulate_recording_evidence()
	_update_debug_readout()
	if changed:
		observations_changed.emit(_observations.duplicate(true))


func _accumulate_recording_evidence() -> void:
	for observation: Dictionary in _observations:
		if not bool(observation.get("detection_enabled", true)):
			continue
		var id := StringName(observation.get("id", &"object"))
		var evidence := _recording_evidence.get(id, {
			"id": id,
			"label": str(observation.get("label", "OBJETO")),
			"visible_seconds": 0.0,
			"maximum_strength": 0.0,
			"samples": 0,
		}) as Dictionary
		evidence["label"] = str(observation.get("label", evidence.get("label", "OBJETO")))
		evidence["visible_seconds"] = float(evidence.get("visible_seconds", 0.0)) + sample_interval
		evidence["maximum_strength"] = maxf(
			float(evidence.get("maximum_strength", 0.0)),
			float(observation.get("strength", 0.0))
		)
		evidence["samples"] = int(evidence.get("samples", 0)) + 1
		_recording_evidence[id] = evidence


func _observation_signature(source: Array[Dictionary]) -> String:
	var parts: PackedStringArray = []
	for observation: Dictionary in source:
		parts.append("%s:%s:%s" % [
			observation.get("id", ""),
			observation.get("label", ""),
			observation.get("detection_enabled", true),
		])
	return "|".join(parts)


func _update_debug_readout() -> void:
	if not is_instance_valid(_readout):
		return
	_update_observer_visibility()
	if not _playback_analysis_active and not (debug_overlay_enabled and debug_live_camera_enabled):
		return
	var lines := PackedStringArray()
	if _observations.is_empty():
		lines.append("  -- SIN OBJETIVOS --")
	else:
		for observation: Dictionary in _observations:
			var count := int(observation.get("instance_count", 1))
			var count_suffix := "  x%d" % count if count > 1 else ""
			if bool(observation.get("detection_enabled", true)):
				lines.append("  + %s%s  %02d%%" % [
					str(observation.get("label", "OBJETO")),
					count_suffix,
					roundi(float(observation.get("strength", 0.0)) * 100.0),
				])
			else:
				lines.append("  - %s%s  [DISABLED]" % [
					str(observation.get("label", "OBJETO")),
					count_suffix,
				])
	var next_text := "\n".join(lines)
	if next_text != _last_debug_text:
		_last_debug_text = next_text
		_readout.clear()
		for line_index in lines.size():
			if line_index > 0:
				_readout.newline()
			var line := lines[line_index]
			if line.ends_with("[DISABLED]"):
				_readout.push_color(DISABLED_READOUT_COLOR)
				_readout.add_text(line)
				_readout.pop()
			else:
				_readout.add_text(line)
