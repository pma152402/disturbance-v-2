extends Node

## Componente ligero que convierte a su padre en contenido reconocible por la camara.
## Se registra una sola vez; CameraObserver se ocupa del muestreo y la visibilidad.

@export var observation_id: StringName = &"object"
@export var display_name := "OBJETO"
@export var focus_path: NodePath
@export var local_focus_offset := Vector3.ZERO
@export_range(0.05, 8.0, 0.05, "or_greater") var framing_radius := 0.5
@export_range(1.0, 80.0, 0.5, "or_greater") var maximum_distance := 18.0
@export_range(0.001, 0.3, 0.001) var minimum_screen_fraction := 0.012
@export_range(0.0, 10.0, 0.1) var priority := 1.0
@export var require_line_of_sight := true
@export_flags_3d_render var visibility_layer_mask := 1
@export var infer_room_from_instance_name := false

var _observation_root: Node3D
var _focus_node: Node3D
var _has_collision_geometry := false
var _geometry_nodes: Array[GeometryInstance3D] = []
var _collision_nodes: Array[Node3D] = []


func _ready() -> void:
	_observation_root = get_parent() as Node3D
	if _observation_root == null:
		push_warning("CameraObservable necesita un Node3D como padre: %s" % get_path())
		return
	if not focus_path.is_empty():
		_focus_node = _observation_root.get_node_or_null(focus_path) as Node3D
	refresh_geometry_cache()
	add_to_group(&"camera_observable")


func refresh_geometry_cache() -> void:
	if not is_instance_valid(_observation_root):
		return
	_geometry_nodes.clear()
	if _observation_root is GeometryInstance3D:
		_geometry_nodes.append(_observation_root as GeometryInstance3D)
	for geometry: Node in _observation_root.find_children("*", "GeometryInstance3D", true, false):
		_geometry_nodes.append(geometry as GeometryInstance3D)
	_collision_nodes = collect_collision_nodes(_observation_root)


static func collect_collision_nodes(root: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for kind in ["CollisionShape3D", "CollisionPolygon3D"]:
		for node: Node in root.find_children("*", kind, true, false):
			result.append(node as Node3D)
	return result


static func has_active_body_collision(nodes: Array[Node3D]) -> bool:
	# Las Areas no participan en los rayos visuales. Los optimizadores pueden
	# desactivar colisiones de decoración sin ocultar sus mallas.
	for node in nodes:
		if not is_instance_valid(node) or not node.is_inside_tree() or bool(node.get("disabled")):
			continue
		var body := node.get_parent() as PhysicsBody3D
		if body != null and body.collision_layer != 0:
			if node is CollisionShape3D and node.shape == null:
				continue
			if node is CollisionPolygon3D and node.polygon.size() < 3:
				continue
			return true
	return false


func get_observation_root() -> Node3D:
	return _observation_root


func get_focus_position() -> Vector3:
	var anchor := _focus_node if is_instance_valid(_focus_node) else _observation_root
	if anchor == null:
		return Vector3.ZERO
	return anchor.to_global(local_focus_offset)


func is_renderable_by(camera: Camera3D) -> bool:
	if camera == null:
		return false
	if is_instance_valid(_focus_node) and _focus_node is GeometryInstance3D:
		var focus_geometry := _focus_node as GeometryInstance3D
		return (
			focus_geometry.is_visible_in_tree()
			and (focus_geometry.layers & camera.cull_mask) != 0
		)
	if _geometry_nodes.is_empty():
		return true
	for geometry: GeometryInstance3D in _geometry_nodes:
		if (
			is_instance_valid(geometry)
			and geometry.is_visible_in_tree()
			and (geometry.layers & camera.cull_mask) != 0
		):
			return true
	return false


func get_observation_data() -> Dictionary:
	_has_collision_geometry = has_active_body_collision(_collision_nodes)
	var data := {
		"id": observation_id,
		"label": display_name,
		"radius": framing_radius,
		"maximum_distance": maximum_distance,
		"minimum_screen_fraction": minimum_screen_fraction,
		"priority": priority,
		"require_line_of_sight": require_line_of_sight,
		"visibility_layer_mask": visibility_layer_mask,
		"has_collision_geometry": _has_collision_geometry,
	}
	if infer_room_from_instance_name:
		_apply_instance_name_context(data)
	if _observation_root != null and _observation_root.has_method(&"get_camera_observation_state"):
		var dynamic_data: Variant = _observation_root.call(&"get_camera_observation_state")
		if dynamic_data is Dictionary:
			data.merge(dynamic_data as Dictionary, true)
	return data


func _apply_instance_name_context(data: Dictionary) -> void:
	if _observation_root == null:
		return
	var normalized_name := str(_observation_root.name).to_lower()
	if observation_id == &"table":
		if "kitchen" in normalized_name or "cocina" in normalized_name:
			data["id"] = &"kitchen_table"
			data["label"] = "MESA COCINA"
		elif "living" in normalized_name or "salon" in normalized_name:
			data["id"] = &"living_room_table"
			data["label"] = "MESA SALON"
	elif observation_id == &"chair" and ("kitchen" in normalized_name or "cocina" in normalized_name):
		data["id"] = &"kitchen_chair"
		data["label"] = "SILLA COCINA"
