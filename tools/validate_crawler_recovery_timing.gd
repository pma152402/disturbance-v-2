extends SceneTree
## Distingue bloqueo físico, órbita sin progreso, avance y espera deliberada.

var failures := 0
var actor: CharacterBody3D


func _initialize() -> void:
	call_deferred(&"run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func reset_actor() -> void:
	actor.global_transform = Transform3D.IDENTITY
	actor.force_update_transform()
	actor.velocity = Vector3.ZERO
	actor.remain_still = false
	actor.surface.phase = actor.surface.Phase.GROUND
	actor.surface.normal = Vector3.UP
	actor.surface.spider_winding_up = false
	actor.surface.spider_leaping = false
	actor.surface._spider_retreating = false
	actor.surface.spider_settling = 0.0
	actor.surface.spider_jump_cooldown = 0.0
	actor.surface._spider_recent.clear()
	actor._spider_chain_remaining = 0
	actor._spider_stuck_elapsed = 0.0
	actor._spider_stuck_origin = actor.surface._center()
	actor._spider_goal_stall = 0.0
	actor._spider_best_goal_distance = INF
	actor._spider_was_advancing = false
	actor._spider_retry_timer = 0.0
	actor._navigation_available = false
	actor._navigation_detour_timer = 0.0
	actor._has_ceiling_goal = false
	actor._patrol_target = Vector3(0, 0, 12)
	actor._was_trying_to_move = true
	actor.intent = actor.Intent.ROAM
	actor.current_state = actor.State.PATROL


func run() -> void:
	seed(140926)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(50, 0.2, 50)
	collision.shape = shape
	floor_body.add_child(collision)
	world.add_child(floor_body)
	floor_body.position.y = -0.1
	actor = preload("res://enemies/grandmother_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.get_node("EditableVisual").set_physics_process(false)
	await physics_frame
	await physics_frame
	check(not actor.obstacle_jump_enabled, "El salto heredado compite con los saltos de la trepadora")

	reset_actor()
	var blocked_time := 0.0
	for frame in 60:
		actor._update_spider_jump_behavior(1.0 / 60.0)
		blocked_time += 1.0 / 60.0
		if actor.surface.spider_winding_up:
			break
	check(actor.surface.spider_winding_up and blocked_time >= 0.78 and blocked_time <= 0.85, "La recuperación física no se activó a los 0,8 s")

	reset_actor()
	for frame in 240:
		actor.global_position.z += 0.015
		actor.force_update_transform()
		actor._update_spider_jump_behavior(1.0 / 60.0)
	check(not actor.surface.spider_busy(), "Un avance normal se confundió con un atasco")

	reset_actor()
	actor._navigation_available = true
	actor._navigation_detour_timer = 2.4
	actor._navigation_detour = Vector3(0, 0, -8)
	for frame in 240:
		actor.global_position.z -= 0.015
		actor.force_update_transform()
		actor._update_spider_jump_behavior(1.0 / 60.0)
	check(not actor.surface.spider_busy(), "Rodear un obstáculo alejándose de la presa se confundió con un atasco")

	reset_actor()
	actor.global_position = Vector3(0, 0, 16)
	actor._spider_stuck_origin = actor.surface._center()
	var orbit_time := 0.0
	for frame in 110:
		var angle := frame / 60.0
		actor.global_position = actor._patrol_target + Vector3(sin(angle), 0, cos(angle)) * 4.0
		actor.force_update_transform()
		actor._update_spider_jump_behavior(1.0 / 60.0)
		orbit_time += 1.0 / 60.0
		if actor.surface.spider_winding_up:
			break
	check(actor.surface.spider_winding_up and orbit_time <= 1.6, "Dar vueltas sin acercarse al objetivo no provocó una ruta de escape")

	reset_actor()
	actor._was_trying_to_move = false
	for frame in 235:
		actor._update_spider_jump_behavior(1.0 / 60.0)
	check(not actor.surface.spider_busy(), "La espera deliberada usó el umbral rápido de persecución")
	for frame in 10:
		actor._update_spider_jump_behavior(1.0 / 60.0)
	check(actor.surface.spider_winding_up, "Se perdió la recuperación tras cuatro segundos inmóvil")

	reset_actor()
	actor.current_state = actor.State.ATTACK
	for frame in 80:
		actor._update_spider_jump_behavior(1.0 / 60.0)
	actor.current_state = actor.State.INVESTIGATE
	actor._update_spider_jump_behavior(0.1)
	check(not actor.surface.spider_busy(), "La pausa del ataque se contó como un atasco al reanudar la marcha")

	reset_actor()
	for frame in 44:
		actor._update_spider_jump_behavior(1.0 / 60.0)
	actor.remain_still = true
	actor._update_spider_jump_behavior(1.0)
	actor.remain_still = false
	actor._update_spider_jump_behavior(0.1)
	check(not actor.surface.spider_busy(), "La inmovilidad forzada dejó pendiente un salto obsoleto")
	print("RECUPERACIÓN TREPADORA: fallos=%d bloqueo=%.3f s órbita=%.3f s; avance y espera conservados" % [failures, blocked_time, orbit_time])
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
