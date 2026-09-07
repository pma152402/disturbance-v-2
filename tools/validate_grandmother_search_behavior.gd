extends SceneTree

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var game := (load("res://levels/test.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	var monster := game.get_node("ImportedGrandmotherGroundFloor") as CharacterBody3D
	monster.set_physics_process(false)
	monster.set("dormant_until_door_opens", false)
	var navigation := game.get_node("RuntimeHouseNavigation")
	if navigation.navigation_mesh == null:
		await navigation.navigation_baked
	monster.set("_navigation_available", true)
	monster.set("_last_known_player_position", monster.global_position + Vector3(2.0, 0.0, 0.0))
	monster.call("_begin_lost_player_search")
	if int(monster.get("current_state")) != 3 or int(monster.get("_photo_behavior")) != 5:
		return _fail("Perder al jugador no inició el estado de búsqueda")
	for _frame in 75:
		monster.call("_update_lost_stimulus", 1.0 / 60.0)
	if int(monster.get("_photo_behavior")) != 5:
		return _fail("Abandonó la búsqueda antes de inspeccionar el entorno")
	if int(monster.get("_search_step_index")) != 0:
		return _fail("Abandonó la última posición antes de intentar alcanzarla")
	monster.global_position = monster.get("_search_anchor")
	for _frame in 75:
		monster.call("_update_lost_stimulus", 1.0 / 60.0)
	if int(monster.get("_search_step_index")) < 1:
		return _fail("La búsqueda no generó un punto de inspección alrededor de la última posición")
	for _frame in 600:
		monster.call("_update_lost_stimulus", 1.0 / 60.0)
	if int(monster.get("_photo_behavior")) != 0:
		return _fail("No volvió a patrulla después de agotar la búsqueda")
	print("OK: llegada a la última posición, pausa de inspección, búsqueda de 8 s y retorno a patrulla")
	current_scene = null
	game.queue_free()
	await process_frame
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
