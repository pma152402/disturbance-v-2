extends SceneTree

const REQUIRED_SEQUENCE := [2, 7, 6, 9, 4, 1]


func _initialize() -> void:
	call_deferred(&"_run_validation")


func _run_validation() -> void:
	var packed_minigame := load("res://washing_machine_minigame.tscn") as PackedScene
	if packed_minigame == null:
		_fail("No se pudo cargar washing_machine_minigame.tscn")
		return
	var layer := packed_minigame.instantiate() as CanvasLayer
	root.add_child(layer)
	await process_frame
	var minigame := layer.get_node_or_null("WashingMachineMinigame")
	if minigame == null:
		_fail("La escena no contiene WashingMachineMinigame")
		return
	minigame.size = Vector2(1280.0, 720.0)
	minigame.call(&"_update_layout")
	if (minigame.get("_red_button_center") as Vector2).x >= (minigame.get("_dial_center") as Vector2).x:
		_fail("El boton rojo debe quedar a la izquierda de la ruleta")
		return
	var constants: Dictionary = minigame.get_script().get_script_constant_map()
	var program_names: Array = constants.get("PROGRAM_NAMES", []) as Array
	if program_names.size() != 9 or not program_names.has("CORTO") or not program_names.has("ALGODÓN"):
		_fail("Faltan los nombres de los nueve programas")
		return

	minigame.call(&"_set_program", 9)
	minigame.call(&"_submit_program")
	if int(minigame.get("_progress")) != 0:
		_fail("Un programa incorrecto no reinicio la secuencia")
		return

	for program: int in REQUIRED_SEQUENCE:
		minigame.call(&"_set_program", program)
		minigame.call(&"_submit_program")
	if int(minigame.get("_progress")) != REQUIRED_SEQUENCE.size():
		_fail("La secuencia correcta no completo el minijuego")
		return

	var packed_washer := load("res://house_props/washing_machine.tscn") as PackedScene
	if packed_washer == null:
		_fail("No se pudo cargar washing_machine.tscn")
		return
	var washer := packed_washer.instantiate()
	root.add_child(washer)
	await process_frame
	if not washer.has_method(&"interact") or not washer.has_method(&"get_interaction_text"):
		_fail("La lavadora no expone la interfaz de interaccion")
		return
	if int(washer.get("collision_layer")) & 2 == 0:
		_fail("La lavadora inferior no esta en la capa 2 del raycast de interaccion")
		return

	var packed_house := load("res://house_baked.tscn") as PackedScene
	if packed_house == null:
		_fail("No se pudo cargar house_baked.tscn")
		return
	var house := packed_house.instantiate()
	var lower_washer := house.get_node_or_null("FurnitureAndPickups/EntranceWashingMachine")
	var upper_washer := house.get_node_or_null("FurnitureAndPickups/EntranceWashingMachine2")
	var wall_hole := house.get_node_or_null("WallHole") as Node3D
	if lower_washer == null or upper_washer == null:
		_fail("No se encontraron las dos instancias de lavadora")
		return
	if not bool(lower_washer.get("minigame_enabled")) or int(lower_washer.get("collision_layer")) & 2 == 0:
		_fail("La lavadora inferior no quedo activada para F")
		return
	if bool(upper_washer.get("minigame_enabled")) or int(upper_washer.get("collision_layer")) & 2 != 0:
		_fail("La lavadora superior todavia puede ser detectada como interactuable")
		return
	if wall_hole == null or wall_hole.get_node_or_null("PassageArrivalPoint") == null:
		_fail("El agujero no tiene un punto de llegada vinculado a su posición actual")
		return
	house.free()

	var packed_player := load("res://player/player.tscn") as PackedScene
	var player := packed_player.instantiate()
	root.add_child(player)
	await process_frame
	var interaction_ray := player.get_node("Head/Camera3D/InteractionRay") as RayCast3D
	if interaction_ray.collision_mask & 1 == 0 or interaction_ray.collision_mask & 2 == 0:
		_fail("El rayo de interacción no comprueba paredes y objetos a la vez")
		return
	player.queue_free()

	print("WASHING_MACHINE_MINIGAME_VALIDATION_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
