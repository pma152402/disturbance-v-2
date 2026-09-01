extends SceneTree


func _init() -> void:
	var house_scene := load("res://house_baked.tscn") as PackedScene
	if house_scene == null:
		_fail("No se pudo cargar house_baked.tscn")
		return

	var house := house_scene.instantiate()
	_check_door(house, "UpperNorthWingDoor", &"lower_north_wing_key", "LLAVE DEL ALA NORTE")
	_check_door(house, "Doors/StorageDoorSouth", &"storage_key", "LLAVE DEL TRASTERO")
	_check_door(house, "Doors/StorageDoorNorth", &"storage_key", "LLAVE DEL TRASTERO")
	_check_door(house, "Doors/ChurchDoor", &"church_key", "LLAVE DE LA IGLESIA")
	_check_door(house, "Doors/UpperNorthWingDoorMain", &"lower_north_wing_key", "LLAVE DEL ALA NORTE")
	var upper_north_door := house.get_node_or_null("UpperNorthWingDoor") as Node3D
	var upper_north_main_door := house.get_node_or_null("Doors/UpperNorthWingDoorMain") as Node3D
	var lower_church_door := house.get_node_or_null("Doors/ChurchDoor") as Node3D
	if (
		upper_north_door == null
		or upper_north_main_door == null
		or upper_north_door.position.y < 4.0
		or upper_north_main_door.position.y < 4.0
	):
		_fail("Las puertas del Ala Norte deben ser los accesos superiores")
	if lower_church_door == null or lower_church_door.position.y > 0.1:
		_fail("El acceso de Iglesia debe permanecer solo en la planta baja")
	_check_door(house, "Doors/PuertaPrincipal", &"main_door_key", "LLAVE DE LA PUERTA PRINCIPAL")
	var normal_basement_door := house.get_node_or_null("Doors/BasementDoor2")
	if normal_basement_door == null or normal_basement_door.get_node_or_null("Hinge") == null:
		_fail("La puerta interior del sótano debe seguir siendo una puerta normal")
	var cellar_bulkhead := house.get_node_or_null("CellarBulkheadEntranceStaging")
	if (
		cellar_bulkhead == null
		or cellar_bulkhead.get("required_key_id") != &"basement_key"
		or cellar_bulkhead.get("required_key_name") != "LLAVE DEL SÓTANO"
		or bool(cellar_bulkhead.get("starts_unlocked"))
	):
		_fail("El acceso CellarBulkhead debe empezar bloqueado con la llave del sótano")

	_check_key(house, "LockedDoorKeys/LowerNorthWingKey", &"lower_north_wing_key", "LLAVE DEL ALA NORTE")
	_check_key(house, "LockedDoorKeys/StorageKey", &"storage_key", "LLAVE DEL TRASTERO")
	_check_key(house, "LockedDoorKeys/ChurchKey", &"church_key", "LLAVE DE LA IGLESIA")
	_check_key(house, "LockedDoorKeys/MainDoorKey", &"main_door_key", "LLAVE DE LA PUERTA PRINCIPAL")
	_check_key(house, "LockedDoorKeys/BasementKey", &"basement_key", "LLAVE DEL SÓTANO")
	var main_door_key := house.get_node_or_null("LockedDoorKeys/MainDoorKey")
	if main_door_key == null or not bool(main_door_key.get("requires_crouch")):
		_fail("La llave exterior debe exigir que el jugador esté agachado")

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
