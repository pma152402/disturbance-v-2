class_name DoorLinkedRenderComponent
extends Node

## Groups the renderable roots found inside a world-space box and gates them with a door.
## Visibility is the only state changed: collisions, navigation and gameplay keep running.

@export var door_path: NodePath
@export var player_group: StringName = &"player"
@export var content_bounds := AABB(Vector3(-13.0, -20.0, -1.5), Vector3(13.0, 19.0, 9.5))
@export var inside_height := -0.35
@export_range(0.02, 1.0, 0.01) var refresh_interval := 0.10
@export var nested_container_paths: Array[NodePath] = []

var _door: Node
var _render_roots: Array[Node3D] = []
var _last_visible := true
var _refresh_timer: Timer


func _ready() -> void:
	_door = get_node_or_null(door_path)
	_collect_render_roots()
	_refresh_visibility(true)
	# A timer avoids waking this component on every rendered frame. Door/player
	# state does not need frame-perfect polling; 10 Hz is visually immediate.
	set_process(false)
	_refresh_timer = Timer.new()
	_refresh_timer.name = "VisibilityRefreshTimer"
	_refresh_timer.wait_time = refresh_interval
	_refresh_timer.timeout.connect(_refresh_visibility)
	add_child(_refresh_timer)
	_refresh_timer.start()


func _collect_render_roots() -> void:
	_render_roots.clear()
	var content_parent := get_parent()
	if content_parent == null:
		return
	for child in content_parent.get_children():
		if child == self or not child is Node3D:
			continue
		var root := child as Node3D
		if content_bounds.has_point(root.global_position):
			_render_roots.append(root)
	for container_path in nested_container_paths:
		var container := get_node_or_null(container_path)
		if container != null:
			for child in container.get_children():
				_collect_branch(child)


func _collect_branch(candidate: Node) -> void:
	if candidate is Node3D:
		var spatial := candidate as Node3D
		if content_bounds.has_point(spatial.global_position):
			# Keep the highest matching root so inherited visibility gates its whole asset.
			_render_roots.append(spatial)
			return
	for child in candidate.get_children():
		_collect_branch(child)


func _refresh_visibility(force := false) -> void:
	var should_render := _door_is_open() or _player_is_inside()
	if not force and should_render == _last_visible:
		return
	_last_visible = should_render
	for root in _render_roots:
		if is_instance_valid(root):
			root.visible = should_render


func _door_is_open() -> bool:
	return is_instance_valid(_door) and _door.has_method(&"is_open") and bool(_door.call(&"is_open"))


func _player_is_inside() -> bool:
	var player := get_tree().get_first_node_in_group(player_group) as Node3D
	return is_instance_valid(player) and player.global_position.y < inside_height


func get_gated_roots() -> Array[Node3D]:
	return _render_roots.duplicate()


func is_content_rendered() -> bool:
	return _last_visible
