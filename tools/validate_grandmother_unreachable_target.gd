extends SceneTree

## Regresión del bloqueo por objetivo inalcanzable.
##
## Cuando la presa se sube a un muro o a cualquier sitio fuera del navmesh, la
## ruta termina lejos (o degenera en dos puntos sobre la propia abuela). Antes
## eso la dejaba parada para siempre: `next_point` colapsaba sobre su posición,
## la dirección quedaba a cero y `_was_trying_to_move` pasaba a falso, con lo que
## la recuperación de atascos tampoco se armaba. Debe acechar y luego rendirse.

const FRAME := 1.0 / 60.0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := (load("res://levels/test.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	var navigation := game.get_node("RuntimeHouseNavigation") as NavigationRegion3D
	if navigation.navigation_mesh == null:
		await navigation.navigation_baked
	for _frame in 20:
		await physics_frame

	var monster := game.get_node("ImportedGrandmotherGroundFloor") as CharacterBody3D
	var player := game.get_node("Player") as CharacterBody3D
	var stalk_seconds := float(monster.get("stalk_seconds"))

	# El jugador se sube a un saliente: mismo pasillo, 2,6 m más arriba y fuera
	# de la malla de navegación.
	player.set_physics_process(false)
	player.global_position = monster.global_position + Vector3(-5.0, 2.6, 0.0)

	var frozen_run := 0.0
	var longest_freeze := 0.0
	var previous := monster.global_position
	var recent_movement := 0.0
	# Margen generoso: acecho + un ciclo de decisión.
	var total_seconds := stalk_seconds + 6.0
	var frames := int(total_seconds / FRAME)
	var tail_frames := int(3.0 / FRAME)
	for frame in frames:
		await physics_frame
		var step := monster.global_position.distance_to(previous)
		previous = monster.global_position
		if step < 0.0008:
			frozen_run += FRAME
			longest_freeze = maxf(longest_freeze, frozen_run)
		else:
			frozen_run = 0.0
		if frame >= frames - tail_frames:
			recent_movement += step

	# Acechar quieta es deliberado; quedarse así indefinidamente no lo es.
	var freeze_budget := stalk_seconds + 2.5
	if longest_freeze > freeze_budget:
		return _fail("Quedó inmóvil %.1f s seguidos con la presa en alto; el acecho son %.1f s" % [
			longest_freeze, stalk_seconds])
	if recent_movement < 0.5:
		return _fail("No retomó la actividad tras rendirse: sólo %.2f m en los últimos 3 s" % recent_movement)

	print("OK: acecho máximo %.1f s (límite %.1f s) y %.2f m recorridos tras rendirse" % [
		longest_freeze, freeze_budget, recent_movement])
	current_scene = null
	game.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
