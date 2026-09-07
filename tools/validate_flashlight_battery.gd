extends SceneTree


func _init() -> void:
	var house_scene := load("res://levels/house_baked.tscn") as PackedScene
	var player_scene := load("res://player/player.tscn") as PackedScene
	if house_scene == null or player_scene == null:
		_fail("No se pudieron cargar las escenas de prueba")
		return

	var house := house_scene.instantiate()
	var laundry_flashlight := house.get_node_or_null("DroppedFlashlight")
	var battery := house.get_node_or_null("LaundryFlashlightBattery")
	if laundry_flashlight == null or not bool(laundry_flashlight.get("requires_battery")):
		_fail("La linterna de la lavandería debe requerir una pila")
		return
	if not bool(laundry_flashlight.get("freeze")):
		_fail("La linterna de la lavandería debe permanecer físicamente fija")
		return
	if laundry_flashlight.get_node_or_null("SpotLight3D") == null or laundry_flashlight.get_node("SpotLight3D").visible:
		_fail("La linterna de la lavandería debe empezar apagada")
		return
	if battery == null or battery.get("item_id") != &"flashlight_battery":
		_fail("Falta la pila de la linterna")
		return

	var player := player_scene.instantiate()
	if bool(player.get("starts_with_flashlight")):
		_fail("El jugador no debe comenzar con linterna")
		return

	print("OK: recorrido de pila y linterna verificado")
	house.free()
	player.free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
