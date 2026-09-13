extends SceneTree

## Conserva la ruta historica del validador, pero ahora comprueba las posturas
## del cuerpo del jugador: el acompanante infantil ya no existe.


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var player := (load("res://player/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame
	var visual := player.get_node("PlayerAvatar") as Node3D
	var capsule := (player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	var standing_height := capsule.height

	player.call(&"_set_stance_immediate", 1)
	var crouch_height := capsule.height
	var crouch_knee_min := INF
	var crouch_knee_max := -INF
	var crouch_body_min := INF
	var crouch_body_max := -INF
	for frame in 150:
		visual.call(&"update_player_animation", 1.0 / 60.0, Vector3(0.25, 0.0, -0.9), 1.0, true, false, 0.0, 0.0, &"", &"")
		var knee_x := (visual.get_node("LeftLeg/Knee") as Node3D).rotation.x
		var body_y := (visual.get_node("Body") as Node3D).position.y
		crouch_knee_min = minf(crouch_knee_min, knee_x)
		crouch_knee_max = maxf(crouch_knee_max, knee_x)
		crouch_body_min = minf(crouch_body_min, body_y)
		crouch_body_max = maxf(crouch_body_max, body_y)

	player.call(&"_set_stance_immediate", 2)
	var prone_height := capsule.height
	var crawl_arm_min := INF
	var crawl_arm_max := -INF
	var crawl_leg_min := INF
	var crawl_leg_max := -INF
	var crawl_sway_min := INF
	var crawl_sway_max := -INF
	for frame in 180:
		visual.call(&"update_player_animation", 1.0 / 60.0, Vector3(0.0, 0.0, -0.55), 2.0, true, false, 0.0, 0.0, &"", &"")
		var arm_x := (visual.get_node("Body/LeftArm") as Node3D).rotation.x
		var leg_x := (visual.get_node("RightLeg") as Node3D).rotation.x
		var sway_x := (visual.get_node("Body") as Node3D).position.x
		crawl_arm_min = minf(crawl_arm_min, arm_x)
		crawl_arm_max = maxf(crawl_arm_max, arm_x)
		crawl_leg_min = minf(crawl_leg_min, leg_x)
		crawl_leg_max = maxf(crawl_leg_max, leg_x)
		crawl_sway_min = minf(crawl_sway_min, sway_x)
		crawl_sway_max = maxf(crawl_sway_max, sway_x)

	player.call(&"_set_stance_immediate", 0)
	for frame in 90:
		visual.call(&"update_player_animation", 1.0 / 60.0, Vector3.ZERO, 0.0, true, false, 0.0, 0.0, &"", &"")
	var restored_height := capsule.height
	var standing_blend := float(visual.get("_stance_blend"))
	print("PLAYER POSTURES standing=%.3f crouch=%.3f prone=%.3f restored=%.3f crouch_motion=[knee %.2f body %.3f] crawl_motion=[arm %.2f leg %.2f sway %.3f]" % [
		standing_height,
		crouch_height,
		prone_height,
		restored_height,
		crouch_knee_max - crouch_knee_min,
		crouch_body_max - crouch_body_min,
		crawl_arm_max - crawl_arm_min,
		crawl_leg_max - crawl_leg_min,
		crawl_sway_max - crawl_sway_min,
	])
	assert(crouch_height < standing_height - 0.5, "La postura agachada no reduce la colision")
	assert(prone_height < crouch_height - 0.25, "La postura tumbada no reduce la colision")
	assert(crouch_knee_max - crouch_knee_min > 0.16, "La marcha agachada carece de rodillas articuladas")
	assert(crouch_body_max - crouch_body_min > 0.008, "La marcha agachada carece de transferencia de peso")
	assert(crawl_arm_max - crawl_arm_min > 0.1, "El gateo no alterna los brazos")
	assert(crawl_leg_max - crawl_leg_min > 0.2, "El gateo no alterna las piernas")
	assert(crawl_sway_max - crawl_sway_min > 0.008, "El gateo no desplaza el peso corporal")
	assert(absf(restored_height - standing_height) < 0.01 and standing_blend < 0.02, "El cuerpo no recupera limpiamente la postura de pie")
	print("PLAYER_POSTURE_VALIDATION: PASS")
	player.queue_free()
	await process_frame
	quit(0)
