extends StaticBody3D

@export_range(0, 3) var switch_index := 0


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_distance() -> float:
	return 1.65


func get_interaction_text(_player: Node = null) -> String:
	return "F  PULSAR INTERRUPTOR %d" % (switch_index + 1)


func interact(_player: Node = null) -> bool:
	var current: Node = get_parent()
	while current != null:
		if current.has_method(&"toggle_switch"):
			return bool(current.call(&"toggle_switch", switch_index))
		current = current.get_parent()
	return false
