extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var level := (load("res://test.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	var companion: CharacterBody3D
	var player: CharacterBody3D
	for _frame in range(360):
		await physics_frame
		companion = get_first_node_in_group(&"companion_npc") as CharacterBody3D
		player = get_first_node_in_group(&"player") as CharacterBody3D
		if companion != null and player != null and companion.get_node_or_null("VisualSocket/ChildVisual") != null:
			break
	if companion == null or player == null:
		push_error("No aparecieron el jugador y Nico")
		quit(1)
		return
	companion.call(&"issue_command", CompanionNPCBase.Command.WAIT)
	var capsule := (companion.get_node("Collision") as CollisionShape3D).shape as CapsuleShape3D
	var visual := companion.get_node("VisualSocket/ChildVisual")
	var standing_height := capsule.height

	player.set("_stance", 1)
	player.set("_pending_stance", 1)
	for _frame in range(45):
		await physics_frame
	var crouch_height := capsule.height
	var crouch_blend := float(visual.get("_posture_blend"))
	var crouch_knee_min := INF
	var crouch_knee_max := -INF
	var crouch_body_min := INF
	var crouch_body_max := -INF
	for _frame in range(150):
		visual.call(&"set_motion_context", 0.83, 0.0, visual.global_position + Vector3.FORWARD * 2.0, false)
		visual.call(&"update_companion_animation", 1.0 / 60.0, 1.0, false)
		var knee_x := (visual.get_node("LeftLeg/Knee") as Node3D).rotation.x
		var body_y := (visual.get_node("Body") as Node3D).position.y
		crouch_knee_min = minf(crouch_knee_min, knee_x)
		crouch_knee_max = maxf(crouch_knee_max, knee_x)
		crouch_body_min = minf(crouch_body_min, body_y)
		crouch_body_max = maxf(crouch_body_max, body_y)

	player.set("_stance", 2)
	player.set("_pending_stance", 2)
	for _frame in range(45):
		await physics_frame
	var prone_height := capsule.height
	var prone_blend := float(visual.get("_posture_blend"))
	var crawl_arm_min := INF
	var crawl_arm_max := -INF
	var crawl_leg_min := INF
	var crawl_leg_max := -INF
	var crawl_sway_min := INF
	var crawl_sway_max := -INF
	for _frame in range(180):
		visual.call(&"set_motion_context", 0.48, 0.0, visual.global_position + Vector3.FORWARD * 2.0, false)
		visual.call(&"update_companion_animation", 1.0 / 60.0, 1.0, false)
		var arm_x := (visual.get_node("Body/LeftArm") as Node3D).rotation.x
		var leg_x := (visual.get_node("RightLeg") as Node3D).rotation.x
		var sway_x := (visual.get_node("Body") as Node3D).position.x
		crawl_arm_min = minf(crawl_arm_min, arm_x)
		crawl_arm_max = maxf(crawl_arm_max, arm_x)
		crawl_leg_min = minf(crawl_leg_min, leg_x)
		crawl_leg_max = maxf(crawl_leg_max, leg_x)
		crawl_sway_min = minf(crawl_sway_min, sway_x)
		crawl_sway_max = maxf(crawl_sway_max, sway_x)

	player.set("_stance", 0)
	player.set("_pending_stance", 0)
	for _frame in range(90):
		await physics_frame
	var restored_height := capsule.height
	var standing_blend := float(visual.get("_posture_blend"))
	print("POSTURE RESULT standing=%.3f crouch=%.3f prone=%.3f restored=%.3f blends=[%.2f, %.2f, %.2f] crouch_motion=[knee %.2f body %.3f] crawl_motion=[arm %.2f leg %.2f sway %.3f] speed_scales=[%.2f, %.2f]" % [
		standing_height,
		crouch_height,
		prone_height,
		restored_height,
		crouch_blend,
		prone_blend,
		standing_blend,
		crouch_knee_max - crouch_knee_min,
		crouch_body_max - crouch_body_min,
		crawl_arm_max - crawl_arm_min,
		crawl_leg_max - crawl_leg_min,
		crawl_sway_max - crawl_sway_min,
		companion.get("crouch_speed_scale"),
		companion.get("prone_speed_scale"),
	])
	if crouch_height >= standing_height - 0.2 or crouch_blend < 0.95:
		push_error("Nico no completo la postura agachada")
		quit(2)
		return
	if prone_height >= crouch_height - 0.2 or prone_blend < 1.95:
		push_error("Nico no completo la postura cuerpo a tierra")
		quit(3)
		return
	if crouch_knee_max - crouch_knee_min < 0.18 or crouch_body_max - crouch_body_min < 0.015:
		push_error("La marcha agachada carece de articulacion o transferencia de peso")
		quit(5)
		return
	if crawl_arm_max - crawl_arm_min < 0.32 or crawl_leg_max - crawl_leg_min < 0.32 or crawl_sway_max - crawl_sway_min < 0.015:
		push_error("El gateo no usa apoyos diagonales ni desplazamiento corporal")
		quit(6)
		return
	if absf(restored_height - standing_height) > 0.01 or standing_blend > 0.01:
		push_error("Nico no recupero limpiamente la postura de pie")
		quit(4)
		return
	quit(0)
