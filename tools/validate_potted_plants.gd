extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://house_baked.tscn") as PackedScene
	if packed == null:
		_fail("No se pudo cargar la casa")
		return
	var house := packed.instantiate()
	root.add_child(house)
	await process_frame
	await process_frame
	var plant_names := ["TerracottaFern", "BlueMonstera", "CeramicSnakePlant", "StoneCactus", "GreenPottedPalm", "WovenPothos", "RoseFlowerPot", "BlackFicus"]
	var variants: Dictionary = {}
	for plant_name in plant_names:
		var plant := house.get_node_or_null(plant_name)
		if plant == null:
			_fail("Falta la planta independiente %s" % plant_name)
			return
		if plant_name in ["CeramicSnakePlant", "BlackFicus"]:
			if plant.get_script() != null:
				_fail("%s todavía depende de un script generador" % plant_name)
				return
			variants[2 if plant_name == "CeramicSnakePlant" else 7] = true
		else:
			variants[int(plant.get("variant"))] = true
		var detail := plant.get_node_or_null("GeneratedDetail")
		if detail == null or detail.get_child_count() < 12:
			_fail("Una planta no generó suficiente detalle: %s" % plant.name)
			return
	if variants.size() != 8:
		_fail("Las ocho plantas no son variantes diferentes")
		return
	print("OK: ocho plantas raíz independientes y ocho macetas distintas verificadas")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
