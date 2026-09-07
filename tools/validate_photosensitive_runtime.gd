extends SceneTree


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game_scene := load("res://levels/test.tscn") as PackedScene
	if game_scene == null:
		_fail("No se pudo cargar test.tscn")
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	current_scene = game
	var navigation := game.get_node_or_null("RuntimeHouseNavigation")
	if navigation != null and navigation.navigation_mesh == null:
		await navigation.navigation_baked
	var test_monster := game.get_node_or_null("ImportedGrandmotherGroundFloor")
	if test_monster != null:
		for _frame in 5:
			await physics_frame
		test_monster.set("dormant_until_door_opens", false)
		(test_monster as Node3D).global_position = Vector3(10.15, 0.95, 8.65)
	for _frame in 120:
		await physics_frame

	var monster := game.get_node_or_null("ImportedGrandmotherGroundFloor") as CharacterBody3D
	var lamp := game.get_node_or_null("House/FurnitureAndPickups/LivingRoomGrandmaCeilingLamp")
	if monster == null or lamp == null:
		_fail("Faltan la grandmother o la lámpara de prueba")
		return
	monster.set("light_wander_radius", 100.0)
	monster.set("static_light_attention_seconds", 0.6)
	lamp.call(&"set_lamp_enabled", true)
	for _frame in 15:
		await physics_frame
	if int(monster.get("_photo_behavior")) != 1:
		_fail("La grandmother no detectó la lámpara encendida del salón")
		return
	for _frame in 60:
		await physics_frame
	if int(monster.get("_photo_behavior")) == 1:
		_fail("La grandmother no perdió el interés por una luz ya atendida (atencion=%s, llegada=%s, aproximacion=%s)" % [monster.get("_static_light_attention_timer"), monster.get("_static_light_arrived"), monster.get("_static_light_approach_timer")])
		return

	lamp.call(&"set_lamp_enabled", false)
	for _frame in 15:
		await physics_frame
	lamp.call(&"set_lamp_enabled", true)
	for _frame in 15:
		await physics_frame
	if int(monster.get("_photo_behavior")) != 1:
		_fail("La misma lámpara no volvió a atraerla después de apagarla y encenderla")
		return

	lamp.call(&"set_lamp_enabled", false)
	for _frame in 120:
		await physics_frame
	if int(monster.get("_photo_behavior")) != 0:
		_fail("La grandmother no volvió a patrullar tras perder la luz")
		return

	var start_position := monster.global_position
	var start_patrol_index := int(monster.get("_patrol_point_index"))
	for _frame in 420:
		await physics_frame
	var patrol_advanced := start_patrol_index != int(monster.get("_patrol_point_index"))
	var patrol_moved := start_position.distance_to(monster.global_position) > 0.3
	if not patrol_advanced and not patrol_moved:
		_fail("La patrulla quedó detenida después de un ciclo")
		return

	var player := game.get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		_fail("Falta el jugador para probar el revelado anti-espera")
		return
	player.global_position = monster.global_position + Vector3(12.0, 0.0, 0.0)
	# test.tscn deja el revelado desactivado; hay que armarlo para poder medirlo.
	monster.set("supernatural_player_reveal", true)
	monster.set("reveal_after_seconds", 0.2)
	monster.set("reveal_live_seconds", 0.3)
	monster.set("_reveal_countdown", 0.2)
	for _frame in 18:
		await physics_frame
	if int(monster.get("_photo_behavior")) != 7:
		_fail("La posición del jugador no se reveló después del tiempo sin cercanía")
		return

	print("OK: luces, patrulla y revelado anti-espera verificados")
	current_scene = null
	game.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
