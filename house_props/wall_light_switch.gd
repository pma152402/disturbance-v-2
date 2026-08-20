extends StaticBody3D

@export var lamp_group: StringName = &"living_room_ceiling_lamp"

@onready var rocker: MeshInstance3D = $Rocker


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(_player: Node = null) -> String:
	var lamps := _get_controlled_lamps()
	if lamps.is_empty():
		return "SIN LUCES ASIGNADAS"
	var all_on := _are_all_lamps_on(lamps)
	var noun := "LUCES" if lamps.size() > 1 else "LAMPARA"
	return ("F  APAGAR " if all_on else "F  ENCENDER ") + noun


func interact(_player: Node = null) -> bool:
	var lamps := _get_controlled_lamps()
	if lamps.is_empty():
		return false
	var now_on := not _are_all_lamps_on(lamps)
	for lamp: Node in lamps:
		lamp.call("set_lamp_enabled", now_on)
	rocker.rotation.x = deg_to_rad(-14.0 if now_on else 14.0)
	return true


func _get_controlled_lamps() -> Array[Node]:
	var controlled: Array[Node] = []
	var lamps := get_tree().get_nodes_in_group(lamp_group)
	for lamp: Node in lamps:
		if not lamp is Node3D:
			continue
		var lamp_3d := lamp as Node3D
		if _belongs_to_this_controller(lamp_3d.global_position):
			controlled.append(lamp)
	controlled.sort_custom(func(a: Node, b: Node) -> bool:
		return global_position.distance_squared_to((a as Node3D).global_position) < global_position.distance_squared_to((b as Node3D).global_position)
	)
	return controlled


func _belongs_to_this_controller(lamp_position: Vector3) -> bool:
	# Planta superior: un interruptor controla las dos lámparas de arriba.
	if global_position.y > 4.2:
		return lamp_position.y > 6.0
	# Salón: la lámpara situada en el ala derecha de la planta baja.
	if global_position.x > 0.0:
		return lamp_position.y < 6.0 and lamp_position.x > 3.0
	# Pasillo central inferior: las dos lámparas alineadas cerca de X = 0.
	return lamp_position.y < 6.0 and lamp_position.x <= 3.0


func _are_all_lamps_on(lamps: Array[Node]) -> bool:
	for lamp: Node in lamps:
		if not bool(lamp.get("is_on")):
			return false
	return true
