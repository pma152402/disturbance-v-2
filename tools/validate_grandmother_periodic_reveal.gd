extends SceneTree

const GrandmotherScene := preload("res://enemies/monster_grandmother_imported.tscn")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	var player := CharacterBody3D.new()
	player.add_to_group(&"player")
	level.add_child(player)
	player.global_position = Vector3(14.0, 0.0, -6.0)
	var grandmother := GrandmotherScene.instantiate() as CharacterBody3D
	grandmother.process_mode = Node.PROCESS_MODE_DISABLED
	level.add_child(grandmother)
	await process_frame
	grandmother.set("_player", player)
	grandmother.set("_navigation_available", false)
	grandmother.set("supernatural_player_reveal", true)
	grandmother.set("reveal_after_seconds", 20.0)
	grandmother.set("_reveal_countdown", 0.05)

	if not bool(grandmother.call(&"_update_player_reveal", 0.06)):
		push_error("El pulso periódico no reveló al jugador")
		quit(1)
		return
	if int(grandmother.get("_photo_behavior")) != 7:
		push_error("El pulso no activó la búsqueda de posición revelada")
		quit(2)
		return
	var revealed: Vector3 = grandmother.get("_last_known_player_position")
	if revealed.distance_to(player.global_position) > 0.01:
		push_error("La pista no coincide con la posición revelada")
		quit(3)
		return
	if absf(float(grandmother.get("_reveal_countdown")) - 20.0) > 0.01:
		push_error("El pulso no rearmó su intervalo")
		quit(4)
		return

	print("GRANDMOTHER PERIODIC REVEAL PASSED")
	quit(0)
