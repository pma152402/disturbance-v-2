extends SceneTree
var failures := 0
var checks := 0
var world: Node3D
var actor: CharacterBody3D
var player: CharacterBody3D
var visual: Node3D
var attack: Node3D

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func box(size_: Vector3, point: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	body.position = point
	return body

func run() -> void:
	seed(14631)
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	box(Vector3(24, 0.2, 24), Vector3(0, -0.1, 0))
	box(Vector3(24, 0.2, 24), Vector3(0, 4.1, 0))
	box(Vector3(0.2, 4.2, 24), Vector3(5.1, 2, 0))
	player = load("res://player/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.position = Vector3(0, 0.9, 3.5)
	actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor._prey = player
	visual = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	attack = actor.vomit
	await physics_frame
	await physics_frame
	check(not attack.can_begin(), "Vomit unlocked before a successful hit")
	player._monster_hit_cooldown = 1.0
	player.receive_monster_attack(actor)
	check(not attack.unlocked and player._monster_hits == 0, "Rejected hit unlocked vomit")
	player._monster_hit_cooldown = 0.0
	player.receive_monster_attack(actor)
	check(attack.unlocked and player._monster_hits == 1, "First effective hit did not unlock vomit at two remaining lives")
	print("VOMIT mouth=", attack.effects.mouth_position(), " head=", visual._head.global_position)
	for attachment in 3:
		attack.cancel()
		attack.cooldown = 0.0
		actor.current_state = actor.State.CHASE
		actor._prey = player
		actor._sight_confirmed = true
		actor._evidence_age = 0.0
		actor._spider_chain_remaining = 0
		actor.surface.phase = attachment
		actor.surface.normal = [Vector3.UP, Vector3.LEFT, Vector3.DOWN][attachment]
		actor.transform = [Transform3D.IDENTITY, Transform3D(Basis(Vector3.UP, Vector3.LEFT, Vector3.BACK), Vector3(4.88, 1.8, 0)), Transform3D(Basis(Vector3.BACK, PI), Vector3(0, 3.88, 0))][attachment]
		player.position = Vector3(3 if attachment == 1 else 0, 0.9, 3.5)
		player._monster_hits = 1
		player.get_camera_lens_grime().dirt = 0.0
		player.get_camera_lens_grime().central_clear = 0.0
		player._monster_hit_cooldown = 0.0
		visual._reset_contacts()
		for i in 30: visual._physics_process(1.0 / 60.0)
		await physics_frame
		await physics_frame
		check(attack.can_begin(), "Cannot vomit on attachment " + str(attachment))
		attack._begin()
		attack.effects.set_physics_process(false)
		check(attack.spray_duration >= 3 and attack.spray_duration <= 9, "Spray duration outside 3-9 seconds")
		var fixed: Transform3D = actor.global_transform
		var spray_time := 0.0
		var drip_time := 0.0
		var total := 0.0
		var max_pool := 0
		var dripping_world_down := false
		var moved_target := false
		var followed_target := false
		while attack.stationary() and total < 17.0:
			if total > 2.0 and not moved_target:
				player.position.x += -1.1 if attachment == 1 else 1.1
				moved_target = true
			if total > 3.5 and not followed_target:
				check(attack.tracking_direction.dot(attack._aim_at(attack._target_point())) > 0.99, "Jet tracking centre did not follow lateral movement")
				check(visual._head.global_basis.z.normalized().dot(attack.aim_direction) > 0.97, "Head and jet aim diverged")
				followed_target = true
			var phase: int = attack.phase
			# Use the brain entry point so its normal stuck and ceiling logic
			# cannot silently run concurrently with the stationary attack.
			actor._physics_process(1.0 / 60.0)
			visual._physics_process(1.0 / 60.0)
			attack.effects._physics_process(1.0 / 60.0)
			player._monster_hit_cooldown = 0.0
			if phase == attack.Phase.SPRAY: spray_time += 1.0 / 60.0
			if phase == attack.Phase.DRIP:
				drip_time += 1.0 / 60.0
				for slot in attack.effects.CAPACITY:
					if attack.effects._lifetimes[slot] > 0.0 and attack.effects._can_damage[slot] == 0 and attack.effects._velocities[slot].y < -0.1:
						dripping_world_down = true
			if attack.stationary() and not actor.global_transform.is_equal_approx(fixed):
				check(false, "Creature moved during vomit or recovery")
				break
			max_pool = maxi(max_pool, attack.effects.alive_count)
			total += 1.0 / 60.0
			await physics_frame
		check(absf(spray_time - attack.spray_duration) < 0.035, "Wrong active stream duration")
		check(absf(drip_time - 3.0) < 0.035, "Recovery is not three seconds")
		check(dripping_world_down, "Ceiling/wall drips ignored world gravity")
		check(player._monster_hits == 1, "Vomit damaged health: " + str(player._monster_hits))
		check(player.get_camera_lens_grime().dirt > 0.1, "Stream did not accumulate camera grime")
		check(attack.effects.puddles.deposited_hits > 0, "Stream did not leave floor puddles")
		check(max_pool > 10 and max_pool <= attack.effects.CAPACITY, "VFX pool is missing or unbounded")
		check(absf(attack.cooldown - (90.0 - total)) < 0.04 and not attack.can_begin(), "90-second cooldown was lost during attack")
		check(actor.surface.spider_jump_reason == "vomit_escape", "Recovery did not enter existing spider jumps")
		print("VOMIT attachment=", attachment, " spray=", spray_time, " drip=", drip_time, " hits=", player._monster_hits, " peak_pool=", max_pool)
		# Finish the real checked arcs before preparing the next attachment.
		var before_jumps: int = actor.surface.spider_jump_count
		for frame in 420:
			actor._physics_process(1.0 / 60.0)
			visual._physics_process(1.0 / 60.0)
			if not actor.surface.spider_busy() and actor._spider_chain_remaining == 0:
				break
			await physics_frame
		print("VOMIT escape attachment=", attachment, " jumps=", actor.surface.spider_jump_count - before_jumps, " aborts=", actor.surface.spider_aborts, " remaining=", actor._spider_chain_remaining, " position=", actor.global_position)
		check(actor.surface.spider_jump_count - before_jumps >= 2, "Vomit recovery did not execute several checked jumps")
		attack.effects.clear()
	# A low pew obscures the physical body, not the mouth. Repeat with the
	# church's authored quarter-turn to catch world/local aiming mistakes.
	for yaw in [0.0, -PI * 0.5]:
		actor.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
		actor.surface.phase = actor.surface.Phase.GROUND
		actor.surface.normal = Vector3.UP
		actor.current_state = actor.State.CHASE
		actor._prey = player
		actor._sight_confirmed = true
		actor._spider_chain_remaining = 0
		actor.surface.spider_settling = 0.0
		player.position = actor.transform * Vector3(0, 0.9, 3.5)
		visual._reset_contacts()
		for i in 30: visual._physics_process(1.0 / 60.0)
		var pew := box(Vector3(4.5, 0.92, 0.16), actor.transform * Vector3(0, 0.46, 1.6))
		pew.basis = actor.basis
		var proxy := box(Vector3(5, 3.8, 0.16), actor.transform * Vector3(0, 1.9, 2.5))
		proxy.basis = actor.basis
		proxy.collision_layer = 1 << 19
		await physics_frame
		await physics_frame
		check(not actor.surface._ray(actor.surface._center(), attack._target_point()).is_empty(), "Pew/proxy regression fixture does not obstruct old body ray")
		check(attack._clear_target(attack._target_point()), "Low pew or climbing proxy blinds visible mouth")
		attack._begin()
		attack.effects.set_physics_process(false)
		var held: Transform3D = actor.global_transform
		for side in [-1.0, 1.0]:
			player.position = actor.transform * Vector3(side * 1.4, 0.9, 3.5)
			for i in 100:
				actor._physics_process(1.0 / 60.0)
				visual._physics_process(1.0 / 60.0)
				attack.effects._physics_process(1.0 / 60.0)
				await physics_frame
			var actual: Vector3 = visual._head.global_basis.z.normalized()
			check(attack.tracking_direction.dot(attack._aim_at(attack._target_point())) > 0.99 and actual.dot(attack.tracking_direction) > 0.94, "Rotated chaotic jet loses moving player above a pew")
			check(actor.global_transform.is_equal_approx(held), "Tracking rotates or translates planted body")
			var jet_slot: int = posmod(attack.effects._cursor - 1, attack.effects.JET_CAPACITY)
			check(attack.effects._velocities[jet_slot].normalized().dot(actual) > 0.96, "Physical liquid does not follow animated head")
		attack.cancel()
		pew.free()
		proxy.free()
	# Wall blocks acquiring a target. It also intercepts in-flight droplets.
	actor.transform = Transform3D.IDENTITY
	actor.surface.phase = actor.surface.Phase.GROUND
	actor.surface.normal = Vector3.UP
	actor.current_state = actor.State.CHASE
	actor._prey = player
	actor._sight_confirmed = true
	actor._evidence_age = 0.0
	actor._spider_chain_remaining = 0
	player.position = Vector3(0, 0.9, 3.5)
	attack.cooldown = 0.0
	visual._reset_contacts()
	for i in 30: visual._physics_process(1.0 / 60.0)
	var blocker := box(Vector3(5, 4, 0.2), Vector3(0, 2, 1.8))
	await physics_frame
	await physics_frame
	check(not attack.can_begin(), "Vomit started through a wall")
	attack._begin() # Deliberately force a burst to verify projectile collision.
	attack.effects.set_physics_process(false)
	player._monster_hits = 1
	player.get_camera_lens_grime().dirt = 0.0
	for i in 120:
		attack.step(1.0 / 60.0)
		visual._physics_process(1.0 / 60.0)
		attack.effects._physics_process(1.0 / 60.0)
		await physics_frame
	check(player._monster_hits == 1, "Droplets dealt damage through a wall")
	check(player.get_camera_lens_grime().dirt == 0.0, "Droplets stained the lens through a wall")
	check(attack.effects.puddles.supports.has(blocker.get_instance_id()), "Wall hit did not leave a persistent stain")
	var remembered: Vector3 = attack._last_aim
	var seen_position: Vector3 = actor._evidence_position
	player.position.x += 1.0
	for i in 20: attack.step(1.0 / 60.0)
	check(attack._last_aim.distance_to(remembered) > 0.8, "Active stream froze its aim behind cover")
	check(actor._evidence_position.is_equal_approx(seen_position), "Spray tracking incorrectly updates ordinary visual memory through walls")
	player.position.x -= 1.0
	blocker.free()
	attack.cancel()
	attack.cooldown = 0.02
	attack._sense_timer = 0.0
	attack.step(0.01)
	check(not attack.stationary(), "Attack restarted before cooldown expired")
	attack._sense_timer = 0.0
	await physics_frame
	attack.step(0.02)
	check(attack.stationary() and is_equal_approx(attack.cooldown, 90.0), "Attack cannot repeat after 90 seconds")
	attack.cancel()
	check(not attack.effects.is_physics_processing(), "VFX retains an idle update loop")
	# Puddle support must not spread across ledges; storage and lifetime stay bounded.
	var puddles: Node3D = attack.effects.puddles
	var ledge := box(Vector3(0.5, 0.2, 0.5), Vector3(-4, 0.9, -4))
	await physics_frame
	await physics_frame
	puddles.deposit(Vector3(-4, 1, -4), Vector3.UP, ledge)
	var index: int = puddles.positions.find(Vector3(-4, 1, -4))
	check(index >= 0, "Supported puddle was rejected")
	for i in 30: puddles.deposit(Vector3(-4, 1, -4), Vector3.UP, ledge)
	check(index >= 0 and puddles.radii[index] <= 0.25, "Puddle grows unsupported beyond ledge")
	var before_edge: int = puddles.deposited_hits
	puddles.deposit(Vector3(-3.77, 1, -4), Vector3.UP, ledge)
	check(puddles.deposited_hits <= before_edge + 1 and puddles.positions.size() <= puddles.CAPACITY, "Puddle pool unbounded")
	# Orientations parallel to FORWARD used to produce a degenerate basis.
	for normal: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3.DOWN]:
		var frame: Basis = puddles._surface_frame(normal)
		check(absf(frame.determinant() - 1.0) < 0.001 and frame.y.dot(normal) > 0.99, "Surface stain basis is degenerate")
	var movable := AnimatableBody3D.new()
	movable.sync_to_physics = false
	var movable_shape := CollisionShape3D.new()
	movable_shape.shape = BoxShape3D.new()
	movable_shape.shape.size = Vector3(2, 2, 0.2)
	movable.add_child(movable_shape)
	world.add_child(movable)
	movable.position = Vector3(-4, 1, 5)
	await physics_frame
	await physics_frame
	puddles.deposit(Vector3(-4, 1, 4.9), Vector3.FORWARD, movable)
	var moving_index: int = puddles.supports.find(movable.get_instance_id())
	check(moving_index >= 0, "Moving door did not accept stain")
	if moving_index >= 0:
		movable.rotate_y(0.6)
		movable.position.x += 0.5
		puddles._physics_process(0.016)
		check(puddles.positions[moving_index].distance_to(movable.to_global(Vector3(0, 0, -0.1))) < 0.002, "Stain floats when door moves")
		check(puddles.normals[moving_index].dot(movable.global_basis * Vector3.FORWARD) > 0.99, "Stain normal fails to follow door")
	movable.free()
	puddles._physics_process(0.016)
	check(moving_index < 0 or puddles.ages[moving_index] >= puddles.LIFETIME, "Stain survives removal of its support")
	for i in 190: puddles._age_puddles()
	check(puddles.timer.is_stopped() and not puddles.batch.visible, "Dry puddles retain work or visible geometry")
	print("CRAWLER VOMIT: failures=", failures, " checks=", checks)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
