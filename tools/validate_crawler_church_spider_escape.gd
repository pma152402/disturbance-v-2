extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	seed(91827)
	var level := load("res://levels/test.tscn").instantiate() as Node3D
	root.add_child(level)
	current_scene = level
	var actor = level.get_node("ImportedGrandmotherGroundFloor")
	var player = level.get_node("Player")
	var visual = actor.get_node("EditableVisual")
	actor.set_physics_process(false)
	player.set_physics_process(false)
	visual.set_physics_process(false)
	await physics_frame
	await physics_frame

	# Centre aisle between the two real rows of church pews.
	actor.global_position = Vector3(0.25, 0.0, -29.0)
	actor.global_basis = Basis.IDENTITY
	actor.velocity = Vector3.ZERO
	actor.force_update_transform()
	actor.surface.phase = actor.surface.Phase.GROUND
	actor.surface.normal = Vector3.UP
	actor.surface.cooldown = 0.0
	actor.surface.spider_jump_cooldown = 0.0
	actor.surface.spider_winding_up = false
	actor.surface.spider_leaping = false
	actor.current_state = actor.State.PATROL
	actor.intent = actor.Intent.ROAM
	actor._patrol_wait_timer = 99.0
	actor._spider_stuck_origin = actor.surface._center()
	actor._spider_stuck_elapsed = actor.spider_stuck_seconds
	var count_before: int = actor.surface.spider_jump_count
	actor._update_spider_jump_behavior(1.0 / 60.0)
	check(actor.surface.spider_winding_up, "Real church aisle offered no safe short escape jump")
	# Stress the longest permitted chain in the narrowest furnished area.
	actor._spider_chain_remaining = 5
	var planned := 6
	var last_count := count_before
	var longest_jump := 0.0
	var peak_step := 0.0
	for frame in 1600:
		var before: Vector3 = actor.surface._center()
		actor._update_spider_jump_behavior(1.0 / 60.0)
		actor.surface.step(1.0 / 60.0, Vector3.ZERO, true)
		actor._idle_clock += 1.0 / 60.0
		visual._physics_process(1.0 / 60.0)
		peak_step = maxf(peak_step, before.distance_to(actor.surface._center()))
		if actor.surface.spider_jump_count != last_count:
			last_count = actor.surface.spider_jump_count
			longest_jump = maxf(longest_jump, actor.surface.spider_curve_start.distance_to(actor.surface.spider_target_position))
		if not actor.surface.spider_busy() and actor._spider_chain_remaining == 0 and actor.surface.phase != actor.surface.Phase.DROP:
			break
		await physics_frame
	var completed: int = actor.surface.spider_jump_count - count_before
	check(actor.spider_max_consecutive_jumps == 6, "El máximo configurado no es de seis saltos")
	check(completed >= 1 and completed <= 6, "La cadena no respetó el máximo de seis saltos")
	check(completed == planned, "La cadena de seis saltos no pudo completarse en la iglesia")
	check(longest_jump <= actor.surface.SPIDER_MAX_JUMP_DISTANCE + 0.01, "Real church escape exceeded the configured jump limit")
	check(actor.surface.phase != actor.surface.Phase.DROP, "Real church escape ended falling or wedged against a collision")
	check(actor.global_basis.y.normalized().dot(actor.surface.normal.normalized()) > 0.995, "Real church escape landed back-first")
	check(actor._spider_last_landing_alignment > 0.995, "Real church landing callback observed a non-feet-first pose")
	check(peak_step < 0.34, "Real church escape teleported through a collision")

	# A close player in the aisle must remain the priority over a newly discovered
	# wall route. A genuine loss after the short occlusion grace releases the rule.
	actor.global_position = Vector3(0.25, 0.0, -29.0)
	actor.global_basis = Basis.IDENTITY
	actor.velocity = Vector3.ZERO
	actor.force_update_transform()
	actor.surface.phase = actor.surface.Phase.GROUND
	actor.surface.normal = Vector3.UP
	actor.surface.cooldown = 0.0
	player.global_position = Vector3(0.25, 0.0, -26.5)
	player.force_update_transform()
	actor._player = player
	actor._sight_confirmed = true
	actor._evidence_position = player.global_position
	actor._evidence_age = 0.0
	actor.intent = actor.Intent.HUNT
	actor.current_state = actor.State.CHASE
	actor._has_ceiling_goal = true
	actor._ceiling_goal = Vector3(-10.0, 0.0, -29.0)
	actor._physics_process(1.0 / 60.0)
	check(not actor._has_ceiling_goal, "Close aisle pursuit kept a wall/ceiling detour")
	check(actor.surface.phase == actor.surface.Phase.GROUND, "Close aisle pursuit attached to a wall")
	actor._sight_confirmed = false
	actor.intent = actor.Intent.INVESTIGATE
	actor._evidence_age = 1.2
	check(not actor.should_keep_ground_pursuit(), "Wall routes stayed blocked after the player was lost")

	print("CHURCH SPIDER ESCAPE: failures=", failures, " chain=", completed, "/", planned, " longest=", longest_jump, " alignment=", actor._spider_last_landing_alignment, " max_step=", peak_step)
	level.queue_free()
	await process_frame
	quit(1 if failures else 0)
