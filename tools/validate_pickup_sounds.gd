extends SceneTree

const PlayerScene := preload("res://player/player.tscn")
const KeyScene := preload("res://pickups/collectible_key.tscn")
const BatteryScene := preload("res://pickups/flashlight_battery.tscn")
const FlashlightScene := preload("res://pickups/dropped_flashlight.tscn")
const CandleScene := preload("res://house_props/candle_pickup.tscn")
const PlungerScene := preload("res://house_props/toilet_plunger.tscn")
const TripodScene := preload("res://house_props/camera_tripod.tscn")
const KeysSound := preload("res://sounds/pickups/pickup_keys.mp3")
const MetalSound := preload("res://sounds/pickups/pickup_metal_tools.mp3")
const PlasticSound := preload("res://sounds/pickups/pickup_plastic_objects.mp3")
const CandleSound := preload("res://sounds/pickups/pickup_candle_grab.mp3")
const PlungerSound := preload("res://sounds/pickups/pickup_plunger_suction.mp3")
const TripodSound := preload("res://sounds/pickups/pickup_tripod_mechanical.mp3")
const EXPECTED_ITEM_TYPES: Array[StringName] = [
	&"key",
	&"flashlight",
	&"flashlight_battery",
	&"can",
	&"bottle",
	&"plunger",
	&"crowbar",
	&"flathead_screwdriver",
	&"note",
	&"recipe_book",
	&"matchbox",
	&"candle",
	&"tv_remote",
	&"camera_tripod",
	&"cassette",
	&"panel_fuse_good",
	&"panel_fuse_broken",
]


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var player := PlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	var audio := player.get_node_or_null("PickupSound") as AudioStreamPlayer
	_assert(audio != null, "El jugador debe tener una voz dedicada al foley de recogida")

	for item_type in EXPECTED_ITEM_TYPES:
		player.call(&"play_pickup_sound", item_type)
		_assert(audio.stream != null, "Falta el perfil sonoro de %s" % item_type)
		_assert(audio.stream.get_length() > 0.25, "El audio de %s esta vacio" % item_type)

	_assert(bool(player.call(&"pick_up_item", &"can")), "La lata debe poder entrar al inventario")
	_assert(audio.stream == MetalSound, "La recogida comun no dispara su foley metalico")
	player.call(&"_clear_inventory_item", &"can")

	var key := KeyScene.instantiate()
	root.add_child(key)
	_assert(bool(key.call(&"interact", player)), "La llave de prueba debe poder recogerse")
	_assert(audio.stream == KeysSound, "La llave no dispara el sonido de llavero")

	var battery := BatteryScene.instantiate()
	root.add_child(battery)
	_assert(bool(battery.call(&"interact", player)), "La pila de prueba debe poder recogerse")
	_assert(audio.stream == MetalSound, "La pila no dispara su pequeño contacto metalico")

	var flashlight := FlashlightScene.instantiate()
	root.add_child(flashlight)
	_assert(bool(flashlight.call(&"interact", player)), "La linterna de prueba debe poder recogerse")
	_assert(audio.stream == PlasticSound, "La linterna recuperada no dispara su foley de carcasa")

	var candle := CandleScene.instantiate()
	root.add_child(candle)
	_assert(bool(candle.call(&"interact", player)), "La vela de prueba debe poder recogerse")
	_assert(audio.stream == CandleSound and audio.playing, "La vela no reproduce un agarre audible")
	await create_timer(0.3).timeout
	player.call(&"_clear_inventory_item", &"candle")

	var plunger := PlungerScene.instantiate()
	root.add_child(plunger)
	_assert(bool(plunger.call(&"interact", player)), "El desatascador de prueba debe poder recogerse")
	_assert(audio.stream == PlungerSound and audio.playing, "El desatascador no reproduce su ventosa")
	await create_timer(0.3).timeout
	player.call(&"_clear_inventory_item", &"plunger")

	var tripod := TripodScene.instantiate()
	root.add_child(tripod)
	await process_frame
	_assert(bool(tripod.call(&"interact", player)), "El tripode de prueba debe poder recogerse")
	_assert(audio.stream == TripodSound and audio.playing, "El tripode no reproduce su mecanismo")
	player.call(&"_clear_inventory_item", &"camera_tripod")

	print("OK: los 17 tipos recogibles tienen foley; vela, desatascador y tripode reproducen clips dedicados")
	if is_instance_valid(key):
		key.queue_free()
	if is_instance_valid(battery):
		battery.queue_free()
	if is_instance_valid(flashlight):
		flashlight.queue_free()
	if is_instance_valid(candle):
		candle.queue_free()
	if is_instance_valid(plunger):
		plunger.queue_free()
	if is_instance_valid(tripod):
		tripod.queue_free()
	await create_timer(0.8).timeout
	player.queue_free()
	await process_frame
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
