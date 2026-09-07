extends SceneTree


func _init() -> void:
	var monster_scene := load("res://monster_grandmother_imported.tscn") as PackedScene
	var player_scene := load("res://player/player.tscn") as PackedScene
	var game_scene := load("res://test.tscn") as PackedScene
	if monster_scene == null or player_scene == null or game_scene == null:
		_fail("No se pudieron cargar las escenas de la IA fotosensible")
		return

	var monster := monster_scene.instantiate()
	var player := player_scene.instantiate()
	var game := game_scene.instantiate()
	if not monster.has_method(&"_find_best_visible_static_light"):
		_fail("Falta la detección de lámparas")
		return
	if not monster.has_method(&"_can_see_flashlight"):
		_fail("Falta la detección de linterna")
		return
	if not is_equal_approx(float(monster.get("close_player_distance")), 1.2):
		_fail("La detección cercana del jugador debe ser de 1.2 metros")
		return
	if not player.has_method(&"is_flashlight_on") or not player.has_method(&"get_flashlight_world_position"):
		_fail("El jugador no expone el estado de su linterna a la IA")
		return
	var configured_monster := game.get_node_or_null("ImportedGrandmotherGroundFloor")
	if configured_monster == null or bool(configured_monster.get("remain_still")):
		_fail("La segunda grandmother debe tener activa la IA fotosensible")
		return
	if configured_monster.process_mode == Node.PROCESS_MODE_DISABLED or game.has_node("ChildCompanion"):
		_fail("La escena debe ejecutar a la abuela y no incluir a Nico")
		return

	print("OK: configuración de grandmother fotosensible verificada")
	monster.free()
	player.free()
	game.free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
