extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://house_baked.tscn") as PackedScene
	if packed == null:
		_fail("No se pudo cargar house_baked")
		return
	var house := packed.instantiate()
	root.add_child(house)
	await process_frame
	await process_frame
	var equipment_names := ["TallTriangularRadioMast", "DirectionalYagiAntenna", "SatelliteDish", "BrickChimney", "TurbineRoofVent", "GalvanizedWaterTank", "OldHVACUnit"]
	var variants: Dictionary = {}
	for prop_name in equipment_names:
		var prop := house.get_node_or_null(prop_name)
		if prop == null:
			_fail("Falta el elemento independiente %s" % prop_name)
			return
		if prop.get_parent() != house or not prop.get_meta("_edit_group_", false):
			_fail("%s no se puede seleccionar como pieza raiz independiente" % prop_name)
			return
		if prop.position.y > 0.1 or prop.position.z < 12.0:
			_fail("%s no esta fuera, a ras de suelo y frente a la entrada" % prop_name)
			return
		variants[int(prop.get("prop_type"))] = true
		var generated := prop.get_node_or_null("GeneratedDetail")
		if generated == null or generated.get_child_count() < 5:
			_fail("Falta detalle generado en %s" % prop.name)
			return
	if variants.size() != 7:
		_fail("Los elementos del tejado no son variantes independientes")
		return
	for plant_name in ["TerracottaFern", "BlueMonstera", "CeramicSnakePlant", "StoneCactus", "GreenPottedPalm", "WovenPothos", "RoseFlowerPot", "BlackFicus"]:
		var plant := house.get_node_or_null(plant_name)
		if plant == null:
			_fail("Falta la planta raíz independiente %s" % plant_name)
			return
		if plant.get_parent() != house or not plant.get_meta("_edit_group_", false):
			_fail("%s no se puede seleccionar como pieza raiz independiente" % plant_name)
			return
		if plant.position.y > 0.1 or plant.position.z < 12.0:
			_fail("%s no esta fuera, a ras de suelo y frente a la entrada" % plant_name)
			return
	print("OK: 7 elementos de tejado y 8 plantas como nodos raíz independientes")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
