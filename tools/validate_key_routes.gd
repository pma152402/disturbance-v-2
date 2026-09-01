extends SceneTree


func _init() -> void:
	var house_scene := load("res://house_baked.tscn") as PackedScene
	if house_scene == null:
		_fail("No se pudo cargar house_baked.tscn")
		return

	var house := house_scene.instantiate()
	_check_door(house, "UpperChurchCorridorDoor", &"lower_north_wing_key", "LLAVE DEL ALA NORTE")
	_check_door(house, "Doors/StorageDoorSouth", &"storage_key", "LLAVE DEL TRASTERO")
	_check_door(house, "Doors/StorageDoorNorth", &"storage_key", "LLAVE DEL TRASTERO")
	_check_door(house, "Doors/ChurchDoor", &"church_key", "LLAVE DE LA IGLESIA")
	_check_door(house, "Doors/ChurchDoorSide", &"church_key", "LLAVE DE LA IGLESIA")
	_check_door(house, "Doors/PuertaPrincipal", &"main_door_key", "LLAVE DE LA PUERTA PRINCIPAL")
	_check_door(house, "Doors/PuertaSotano", &"basement_key", "LLAVE DEL SÓTANO")

	_check_key(house, "LockedDoorKeys/LowerNorthWingKey", &"lower_north_wing_key", "LLAVE DEL ALA NORTE")
	_check_key(house, "LockedDoorKeys/StorageKey", &"storage_key", "LLAVE DEL TRASTERO")
	_check_key(house, "LockedDoorKeys/ChurchKey", &"church_key", "LLAVE DE LA IGLESIA")
	_check_key(house, "LockedDoorKeys/MainDoorKey", &"main_door_key", "LLAVE DE LA PUERTA PRINCIPAL")
	_check_key(house, "LockedDoorKeys/BasementKey", &"basement_key", "LLAVE DEL SÓTANO")

	print("OK: rutas de llaves y puertas verificadas")
	house.free()
	quit(0)


func _check_door(house: Node, path: String, expected_id: StringName, expected_name: String) -> void:
	var door := house.get_node_or_null(path)
	if door == null:
		_fail("Falta la puerta: %s" % path)
		return
	var hinge := door.get_node_or_null("Hinge")
	if hinge == null:
		_fail("Falta Hinge en: %s" % path)
		return
	if hinge.get("required_key_id") != expected_id or hinge.get("required_key_name") != expected_name:
		_fail("Cerradura incorrecta en: %s" % path)


func _check_key(house: Node, path: String, expected_id: StringName, expected_name: String) -> void:
	var key := house.get_node_or_null(path)
	if key == null:
		_fail("Falta la llave: %s" % path)
		return
	if key.get("key_id") != expected_id or key.get("key_name") != expected_name:
		_fail("Datos incorrectos en: %s" % path)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
