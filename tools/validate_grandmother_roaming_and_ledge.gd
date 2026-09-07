extends SceneTree

## Dos comportamientos que antes no existían:
##
## 1. Sin estímulo debe pasearse por la casa, no rondar su punto de aparición.
## 2. Con la presa subida a un muro debe plantarse debajo y sacudir hacia
##    arriba, empujándola del saliente, en vez de quedarse mirando.


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := (load("res://test.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	var navigation := game.get_node("RuntimeHouseNavigation") as NavigationRegion3D
	if navigation.navigation_mesh == null:
		await navigation.navigation_baked
	for _frame in 20:
		await physics_frame

	var monster := game.get_node("ImportedGrandmotherGroundFloor") as CharacterBody3D
	var player := game.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)

	# --- Zarpazo al saliente -------------------------------------------------
	# La presa se sube a un muro de 2,2 m: fuera del navmesh y fuera de la
	# tolerancia vertical del golpe normal.
	player.global_position = monster.global_position + Vector3(-2.6, 2.2, 0.0)
	var shoves := 0
	var pushed_away := false
	for _frame in 600:
		await physics_frame
		if int(player.get("_monster_hits")) > 0:
			shoves += 1
			# El empujón debe alejarla del muro, no sólo restar vida.
			if Vector2(player.velocity.x, player.velocity.z).length() > 1.0 and player.velocity.y > 0.0:
				pushed_away = true
			player.set("_monster_hits", 0)
			player.set("_monster_hit_cooldown", 0.0)
			player.velocity = Vector3.ZERO
			player.global_position = monster.global_position + Vector3(-2.6, 2.2, 0.0)
	if shoves == 0:
		return _fail("No sacudió ni una vez con la presa a 2,2 m sobre ella")
	if not pushed_away:
		return _fail("Golpeó pero sin impulso que la despegue del saliente")

	# --- Paseo por la casa ---------------------------------------------------
	player.global_position = Vector3(0.0, -400.0, 0.0)
	monster.set("_photo_behavior", 0)
	monster.set("_player_hunt_active", false)
	monster.set("_patrol_wait_timer", 0.2)
	for _frame in 10:
		await physics_frame
	var spawn: Vector3 = monster.get("_spawn_position")
	var previous := monster.global_position
	var travelled := 0.0
	var cells: Dictionary = {}
	var furthest := 0.0
	for _frame in 3600:
		await physics_frame
		travelled += monster.global_position.distance_to(previous)
		previous = monster.global_position
		cells["%d,%d" % [int(monster.global_position.x / 3.0), int(monster.global_position.z / 3.0)]] = true
		furthest = maxf(furthest, monster.global_position.distance_to(spawn))

	# Los dos puntos de patrulla fijos cubren unos 6 m y 2-3 celdas. Superarlo
	# con holgura demuestra que está eligiendo destinos por el mapa.
	if cells.size() < 8:
		return _fail("Sólo pisó %d celdas de 3 m en 60 s: sigue rondando su punto de aparición" % cells.size())
	if furthest < 8.0:
		return _fail("No se alejó más de %.1f m de su aparición en 60 s" % furthest)

	print("OK: %d zarpazos con empuje desde el suelo; paseo de %.1f m por %d celdas, hasta %.1f m del inicio" % [
		shoves, travelled, cells.size(), furthest])
	current_scene = null
	game.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
