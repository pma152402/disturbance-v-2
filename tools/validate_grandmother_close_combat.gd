extends SceneTree

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var game := (load("res://levels/test.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	var monster := game.get_node("ImportedGrandmotherGroundFloor") as CharacterBody3D
	var player := game.get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	monster.set_physics_process(false)
	player.set_physics_process(false)
	monster.set("dormant_until_door_opens", false)
	monster.set("remain_still", false)
	monster.global_position = Vector3(1.0, 0.0, -4.2)
	player.global_position = Vector3(1.0, 0.0, -1.8)
	var navigation := game.get_node("RuntimeHouseNavigation")
	if navigation.navigation_mesh == null:
		await navigation.navigation_baked
	for _frame in 4:
		await physics_frame
	monster.set("current_state", 2)
	monster.set("_photo_behavior", 2)
	monster.set("_player_hunt_active", true)
	monster.set("_attack_cooldown_timer", 0.0)
	monster.set("_target_refresh_timer", 0.0)
	var previous_angle := _angle_around(monster.global_position, player.global_position)
	var accumulated_orbit := 0.0
	var attack_frame := -1
	var closest_distance := INF
	for frame in 240:
		monster.call("_update_movement", 1.0 / 60.0)
		monster.move_and_slide()
		monster.call("_try_begin_attack")
		await physics_frame
		var angle := _angle_around(monster.global_position, player.global_position)
		accumulated_orbit += absf(wrapf(angle - previous_angle, -PI, PI))
		previous_angle = angle
		closest_distance = minf(closest_distance, float(monster.call("_player_planar_distance")))
		if int(monster.get("current_state")) == 4:
			attack_frame = frame
			break
	if attack_frame < 0:
		return _fail("No comprometió un ataque en cuatro segundos; distancia mínima=%.2f" % closest_distance)
	if accumulated_orbit > 1.25:
		return _fail("Orbitó alrededor del jugador antes de atacar: %.1f grados" % rad_to_deg(accumulated_orbit))
	print("OK: ataque comprometido en %.2f s; distancia=%.2f m; órbita=%.1f°" % [attack_frame / 60.0, closest_distance, rad_to_deg(accumulated_orbit)])
	current_scene = null
	game.queue_free()
	await process_frame
	quit(0)

func _angle_around(position: Vector3, center: Vector3) -> float:
	return atan2(position.z - center.z, position.x - center.x)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
