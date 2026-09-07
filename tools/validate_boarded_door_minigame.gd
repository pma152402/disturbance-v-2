extends SceneTree

const NAIL_COUNT := 8
const HALF_STROKES_PER_NAIL := 12


func _initialize() -> void:
	call_deferred(&"_run_validation")


func _run_validation() -> void:
	var packed_minigame := load("res://minigames/boarded_door_minigame.tscn") as PackedScene
	if packed_minigame == null:
		_fail("No se pudo cargar boarded_door_minigame.tscn")
		return
	var layer := packed_minigame.instantiate() as CanvasLayer
	root.size = Vector2i(1280, 720)
	root.add_child(layer)
	var minigame := layer.get_node("BoardedDoorMinigame") as Control
	await process_frame
	minigame.call(&"setup", [])
	minigame.call(&"_update_layout")
	var nail_centers: Array = minigame.get("_nail_centers") as Array
	if nail_centers.size() != NAIL_COUNT:
		_fail("La interfaz no contiene los ocho clavos de los cuatro tablones")
		return
	if int(minigame.call(&"_find_nail_at", nail_centers[0])) != 0:
		_fail("Los clavos no se pueden seleccionar con clic")
		return

	for nail_index in NAIL_COUNT:
		minigame.call(&"_select_nail", nail_index)
		minigame.call(&"_finish_insertion")
		for half_stroke in HALF_STROKES_PER_NAIL:
			var press := InputEventKey.new()
			press.physical_keycode = KEY_SPACE
			press.pressed = true
			minigame.call(&"_input", press)
			press.echo = true
			minigame.call(&"_input", press)
			if int(minigame.get("_half_strokes")) != half_stroke + 1:
				_fail("Las repeticiones automaticas no deben contar")
				return
			press.echo = false
			press.pressed = false
			minigame.call(&"_input", press)
		var removed_flags: Array = minigame.get("_removed_nails") as Array
		if not bool(removed_flags[nail_index]):
			_fail("Las pulsaciones de Espacio no extrajo el clavo %d" % (nail_index + 1))
			return
		minigame.call(&"_advance_after_release")
	if int(minigame.call(&"_count_removed_nails")) != NAIL_COUNT or not bool(minigame.get("_completion_emitted")):
		_fail("El minijuego no termina al extraer los ocho clavos")
		return

	var test_scene := Node3D.new()
	test_scene.name = "BoardedDoorTestScene"
	root.add_child(test_scene)
	current_scene = test_scene
	var packed_door := load("res://house_props/catacombs/boarded_labyrinth_door.tscn") as PackedScene
	var packed_player := load("res://player/player.tscn") as PackedScene
	if packed_door == null or packed_player == null:
		_fail("No se pudo cargar la puerta o el jugador")
		return
	var door := packed_door.instantiate()
	var player := packed_player.instantiate()
	test_scene.add_child(door)
	test_scene.add_child(player)
	await process_frame
	if (door.get("_nails") as Array).size() != NAIL_COUNT or (door.get("_boards") as Array).size() != 4:
		_fail("La puerta 3D no enlaza sus ocho clavos y cuatro tablones")
		return
	if door.collision_layer & 1 == 0 or door.collision_layer & 2 == 0:
		_fail("La puerta atrancada debe bloquear al jugador y aceptar F")
		return
	if not bool(player.call(&"pick_up_crowbar")):
		_fail("No se pudo equipar la palanca para probar la puerta")
		return
	if not bool(door.call(&"interact", player)) or not bool(door.get("_minigame_active")):
		_fail("F no abre el minijuego con la palanca equipada")
		return
	if player.get_node("Head/Camera3D/RightHandRig/HeldCrowbar").visible:
		_fail("La palanca de mano no se oculta durante la animacion del minijuego")
		return

	var first_nail := (door.get("_nails") as Array)[0] as MeshInstance3D
	var first_rest := first_nail.position
	door.call(&"_on_pry_motion", 0, 0.5, -1.0)
	if first_nail.position.is_equal_approx(first_rest):
		_fail("El clavo 3D no sale mientras movemos la palanca")
		return
	for nail_index in NAIL_COUNT:
		door.call(&"_on_nail_removed", nail_index)
	if not (door.get("_board_removed_flags") as Array).all(func(value: Variant) -> bool: return bool(value)):
		_fail("Los tablones no caen al perder sus dos clavos")
		return
	door.call(&"_on_minigame_completed")
	await process_frame
	if not bool(door.get("_removed")) or door.collision_layer != 0:
		_fail("La puerta sigue bloqueada tras completar el minijuego")
		return
	if not player.call(&"has_tool", &"crowbar") or not player.call(&"is_holding_item_type", &"crowbar"):
		_fail("La palanca no debe consumirse al quitar los tablones")
		return

	print("BOARDED_DOOR_MINIGAME_VALIDATION_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
