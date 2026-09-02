@tool
extends StaticBody3D

@export_node_path("Node3D") var linked_washing_machine_path: NodePath

@export_range(0.12, 2.5, 0.01) var hole_radius := 0.48:
	set(value):
		hole_radius = value
		_update_visual()

@export_range(0.45, 1.4, 0.01) var vertical_ratio := 0.82:
	set(value):
		vertical_ratio = value
		_update_visual()

@export_range(0.001, 0.08, 0.001) var wall_offset := 0.012:
	set(value):
		wall_offset = value
		_update_visual()

@onready var visual_root: Node3D = $VisualRoot


func _ready() -> void:
	_update_visual()


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(_player: Node = null) -> String:
	return "F  VOLVER POR EL AGUJERO" if _passage_is_unlocked() else ""


func interact(player: Node = null) -> bool:
	if not _passage_is_unlocked() or not is_instance_valid(player):
		return false
	var washer := get_node_or_null(linked_washing_machine_path)
	if washer == null or not washer.has_method(&"get_passage_return_position"):
		return false
	var target := washer.call(&"get_passage_return_position") as Vector3
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	if player is Node3D:
		(player as Node3D).global_position = target
	return true


func _passage_is_unlocked() -> bool:
	if linked_washing_machine_path.is_empty():
		return false
	var washer := get_node_or_null(linked_washing_machine_path)
	return washer != null and washer.has_method(&"is_passage_unlocked") and bool(washer.call(&"is_passage_unlocked"))


func _update_visual() -> void:
	if not is_node_ready():
		return
	visual_root.scale = Vector3(hole_radius, hole_radius * vertical_ratio, hole_radius)
	visual_root.position.z = wall_offset
