extends SceneTree

var failures := 0

class Target:
	extends CharacterBody3D
	var hits := 0
	func is_personal_light_on() -> bool: return true
	func receive_monster_attack(_source: Node3D) -> void: hits += 1

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func box(parent: Node3D, name_: String, size: Vector3, point: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = point
	return body

func run() -> void:
	seed(77421)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	box(world, "Floor", Vector3(18, 0.2, 18), Vector3(0, -0.1, 0))
	box(world, "Ceiling", Vector3(18, 0.2, 18), Vector3(0, 4.1, 0))
	box(world, "NorthWall", Vector3(18, 4.2, 0.2), Vector3(0, 2.0, 3.6))
	box(world, "EastWall", Vector3(0.2, 4.2, 18), Vector3(5.0, 2.0, 0))
	var player := Target.new()
	player.add_to_group("player")
	player.collision_layer = 2
	var player_collision := CollisionShape3D.new()
	var player_shape := CapsuleShape3D.new()
	player_shape.radius = 0.3
	player_shape.height = 1.7
	player_collision.shape = player_shape
	player_collision.position.y = 0.85
	player.add_child(player_collision)
	world.add_child(player)
	player.position = Vector3(0, 0, -7)
	var actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.spider_jump_enabled = false
	var visual = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	await physics_frame
	await physics_frame
	var started: bool = actor.surface.begin_spider_jump({"position": Vector3(0, 6.0, 0), "normal": Vector3.DOWN}, false, "too_long")
	check(not started, "Spider jump accepted an excessive floor-to-ceiling distance")
	started = actor.surface.begin_spider_jump({"position": Vector3(0, 4.0, 0), "normal": Vector3.DOWN}, false, "test_ceiling")
	check(started, "Could not prepare floor-to-ceiling spider jump")
	var crouched := false
	var launched := false
	var peak_speed := 0.0
	var maximum_step := 0.0
	for frame in 240:
		var before: Vector3 = actor.surface._center()
		actor.surface.step(1.0 / 60.0, Vector3.ZERO, true)
		actor._idle_clock += 1.0 / 60.0
		visual._physics_process(1.0 / 60.0)
		maximum_step = maxf(maximum_step, before.distance_to(actor.surface._center()))
		peak_speed = maxf(peak_speed, actor.surface.spider_velocity.length())
		crouched = crouched or (actor.surface.spider_winding_up and visual._rear < -0.28)
		launched = launched or actor.surface.spider_leaping
		if launched and not actor.surface.spider_busy():
			break
		await physics_frame
	check(crouched, "Spider jump has no visible compression before take-off")
	check(launched, "Spider jump never left the floor")
	check(actor.surface.phase == actor.surface.Phase.CEILING and actor.surface.normal.y < -0.65, "Spider jump did not attach to the ceiling")
	check(actor.global_basis.y.normalized().dot(Vector3.DOWN) > 0.995, "Crawler reached the ceiling back-first")
	check(actor.surface.spider_jump_count == 1, "Spider jump counter is incorrect")
	check(peak_speed > 8.0, "Emergency spider jump is not substantially faster than ordinary movement")
	check(maximum_step < 0.32, "Spider jump teleported instead of following its trajectory")
	# Ceiling to wall uses the same anticipation and must arrive already turned
	# toward the vertical plane.
	actor.surface.spider_jump_cooldown = 0.0
	started = actor.surface.begin_spider_jump({"position": Vector3(0, 2.1, 3.5), "normal": Vector3.FORWARD}, false, "test_wall")
	check(started, "Could not prepare ceiling-to-wall spider jump")
	launched = false
	for frame in 260:
		actor.surface.step(1.0 / 60.0, Vector3.ZERO, true)
		actor._idle_clock += 1.0 / 60.0
		visual._physics_process(1.0 / 60.0)
		launched = launched or actor.surface.spider_leaping
		if launched and not actor.surface.spider_busy():
			break
		await physics_frame
	check(actor.surface.phase == actor.surface.Phase.WALL and actor.surface.normal.dot(Vector3.FORWARD) > 0.65, "Spider jump did not attach to a wall")
	check(actor.global_basis.y.normalized().dot(Vector3.FORWARD) > 0.995, "Crawler reached the wall back-first")
	# It can also jump down from a wall and recover its quadruped floor pose.
	actor.surface.spider_jump_cooldown = 0.0
	started = actor.surface.begin_spider_jump({"position": Vector3(1.2, 0, 1.5), "normal": Vector3.UP}, false, "test_floor")
	check(started, "Could not prepare wall-to-floor spider jump")
	launched = false
	for frame in 260:
		actor.surface.step(1.0 / 60.0, Vector3.ZERO, true)
		actor._idle_clock += 1.0 / 60.0
		visual._physics_process(1.0 / 60.0)
		launched = launched or actor.surface.spider_leaping
		if launched and not actor.surface.spider_busy():
			break
		await physics_frame
	check(actor.surface.phase == actor.surface.Phase.GROUND and actor.global_basis.y.y > 0.995, "Spider jump did not land upright on its feet")
	# The same mechanic can commit to a dodgeable player attack.
	actor.global_position = Vector3.ZERO
	actor.global_basis = Basis.IDENTITY
	actor.surface.phase = actor.surface.Phase.GROUND
	actor.surface.normal = Vector3.UP
	actor.surface.spider_jump_cooldown = 0.0
	actor.force_update_transform()
	player.position = Vector3(0, 0, 3.2)
	actor._player = player
	started = actor.surface.begin_spider_jump({"position": player.global_position + Vector3.UP * 0.85, "normal": Vector3.UP}, true, "attack")
	check(started, "Could not prepare attacking spider jump")
	launched = false
	var locked_attack_target: Vector3 = actor.surface.spider_target_position
	for frame in 260:
		actor.surface.step(1.0 / 60.0, player.global_position, true)
		actor._idle_clock += 1.0 / 60.0
		visual._physics_process(1.0 / 60.0)
		if actor.surface.spider_leaping and not launched:
			player.position += Vector3.RIGHT * 3.0
		launched = launched or actor.surface.spider_leaping
		if launched and not actor.surface.spider_busy() and actor.surface.phase == actor.surface.Phase.GROUND:
			break
		await physics_frame
	check(player.hits == 0, "Spider attack tracked and hit a player who dodged after take-off")
	check(actor.surface.spider_target_position.is_equal_approx(locked_attack_target), "Spider attack changed its locked flight target")
	actor.global_position = Vector3.ZERO
	actor.global_basis = Basis.IDENTITY
	actor.surface.phase = actor.surface.Phase.GROUND
	actor.surface.normal = Vector3.UP
	actor.surface.spider_jump_cooldown = 0.0
	actor.force_update_transform()
	player.position = Vector3(0, 0, 3.2)
	started = actor.surface.begin_spider_jump({"position": player.global_position + Vector3.UP * 0.85, "normal": Vector3.UP}, true, "attack")
	check(started, "Could not prepare second attacking spider jump")
	launched = false
	for frame in 260:
		actor.surface.step(1.0 / 60.0, player.global_position, true)
		actor._idle_clock += 1.0 / 60.0
		visual._physics_process(1.0 / 60.0)
		launched = launched or actor.surface.spider_leaping
		if launched and not actor.surface.spider_busy() and actor.surface.phase == actor.surface.Phase.GROUND:
			break
		await physics_frame
	check(player.hits == 1 and actor.surface.spider_hit, "Attacking spider jump did not produce exactly one physical hit")
	# Normal movement must never trigger an occasional spider jump: this mechanic
	# now exists exclusively as the four-second immobility escape.
	actor.global_position = Vector3(0, 0, 0)
	actor.global_basis = Basis.IDENTITY
	actor.surface.phase = actor.surface.Phase.GROUND
	actor.surface.normal = Vector3.UP
	actor.surface.spider_jump_cooldown = 0.0
	actor.spider_jump_enabled = true
	actor.current_state = actor.State.PATROL
	actor.intent = actor.Intent.ROAM
	actor._patrol_wait_timer = 99.0
	actor._was_trying_to_move = false
	actor._spider_stuck_origin = actor.global_position
	actor._spider_stuck_elapsed = 0.0
	var jumps_before_normal_motion: int = actor.surface.spider_jump_count
	for frame in 720:
		if frame > 0 and frame % 180 == 0:
			actor.global_position.x += 0.2
		actor._update_spider_jump_behavior(1.0 / 60.0)
	check(not actor.surface.spider_busy() and actor.surface.spider_jump_count == jumps_before_normal_motion, "Spider jump triggered during normal movement")
	# A literal four-second standstill must trigger even during a deliberate wait.
	actor.global_position = Vector3.ZERO
	actor._spider_stuck_origin = actor.global_position
	actor._spider_stuck_elapsed = 0.0
	for frame in 250:
		actor._update_spider_jump_behavior(1.0 / 60.0)
		if actor.surface.spider_winding_up:
			break
	check(actor.surface.spider_winding_up, "Four-second standstill during an intentional wait did not force a spider jump")
	check(actor.surface.spider_jump_reason == "stuck" and actor._spider_forced_jumps == 1, "Stall jump did not replace the blocked route")
	var planned_chain: int = actor._spider_chain_remaining + 1
	var chain_start_count: int = actor.surface.spider_jump_count
	for frame in 1200:
		actor._update_spider_jump_behavior(1.0 / 60.0)
		actor.surface.step(1.0 / 60.0, Vector3.ZERO, true)
		actor._idle_clock += 1.0 / 60.0
		visual._physics_process(1.0 / 60.0)
		if not actor.surface.spider_busy() and actor._spider_chain_remaining == 0:
			break
		await physics_frame
	var completed_chain: int = actor.surface.spider_jump_count - chain_start_count
	check(planned_chain >= 1 and planned_chain <= 3, "El atasco no planificó una cadena de uno a tres saltos")
	check(completed_chain >= 1 and completed_chain <= planned_chain, "La cadena superó el número de saltos planificado")
	check(actor._spider_last_landing_alignment > 0.995, "A chained jump landed without its feet toward the support")
	# Furniture and narrow surfaces may block a flight but cannot be destinations.
	var pew := box(world, "ChurchPew", Vector3(2.2, 1.15, 0.82), Vector3(0, 0.575, 2.0))
	var pew_hit := {"collider": pew, "normal": Vector3.UP, "position": Vector3(0, 1.15, 2.0)}
	check(not actor.surface._spider_surface_allowed(pew_hit), "Church pew was accepted as a spider landing surface")
	# A nearby confirmed player suppresses both direct wall attachment and an
	# already selected ceiling detour. Once the recent sight memory expires,
	# climbing is allowed again.
	actor.global_position = Vector3(0, 0, 3.45)
	actor.global_basis = Basis.IDENTITY
	actor.surface.phase = actor.surface.Phase.GROUND
	actor.surface.normal = Vector3.UP
	actor.surface.cooldown = 0.0
	actor.surface.scan_timer = 0.0
	player.global_position = Vector3(0, 0, 2.0)
	actor._player = player
	actor._sight_confirmed = true
	actor._evidence_age = 0.0
	actor.intent = actor.Intent.HUNT
	actor._has_ceiling_goal = true
	actor._ceiling_goal = Vector3(0, 0, 4.8)
	actor.surface.consider(0.6, player.global_position, true)
	check(actor.surface.phase == actor.surface.Phase.GROUND, "Close pursuit turned toward the church wall")
	actor._physics_process(1.0 / 60.0)
	check(not actor._has_ceiling_goal, "Close pursuit kept an obsolete ceiling detour")
	actor._sight_confirmed = false
	actor._evidence_age = 1.2
	check(not actor.should_keep_ground_pursuit(), "Crawler kept ground pursuit after genuinely losing the player")
	print("SPIDER JUMP: failures=", failures, " crouched=", crouched, " peak_speed=", peak_speed, " max_step=", maximum_step, " chain=", completed_chain, "/", planned_chain, " alignment=", actor._spider_last_landing_alignment, " forced=", actor._spider_forced_jumps)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
