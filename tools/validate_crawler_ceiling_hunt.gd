extends SceneTree
var failures := 0
var actor: CharacterBody3D
var player: CharacterBody3D
var visual: Node
class Target:
	extends CharacterBody3D
	var hits := 0
	func is_personal_light_on() -> bool: return true
	func receive_monster_attack(_source: Node3D) -> void: hits += 1

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func box(world: Node3D, size: Vector3, point: Vector3) -> StaticBody3D:
	var node := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	node.add_child(collision)
	world.add_child(node)
	node.position = point
	return node
func tick() -> void:
	actor._physics_process(1.0 / 60.0)
	visual._physics_process(1.0 / 60.0)
	await physics_frame

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	box(world, Vector3(40, 0.2, 40), Vector3(0, -0.1, 0))
	var roof_height := 8.8 if "--high" in OS.get_cmdline_user_args() else 4.8
	box(world, Vector3(20, roof_height + 2, 0.2), Vector3(0, (roof_height + 2) / 2.0, 5))
	box(world, Vector3(20, 0.2, 20), Vector3(0, roof_height, 0))
	player = Target.new()
	player.add_to_group("player")
	player.collision_layer = 2
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 1.6
	collision.shape = shape
	collision.position.y = 0.8
	player.add_child(collision)
	world.add_child(player)
	player.position = Vector3(0, 0, -30)
	actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	# This suite isolates the original ceiling-perch/pounce contract. Random and
	# four-second relocation jumps have their own deterministic validation.
	actor.spider_jump_enabled = false
	visual = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	actor.surface.cooldown = 0
	await physics_frame
	await physics_frame
	for frame in 650:
		await tick()
		if actor.surface.phase == 2 and actor.basis.y.y < -0.99:
			break
	check(actor.surface.phase == 2, "Did not seek a remote wall and climb without a player clue")
	for frame in 620:
		await tick()
	check(actor.surface.phase == 2 and actor.basis.y.y < -0.98, "Did not stay perched after memory/time expired")
	print("CEILING SEEK/PERCH: ", actor.position)
	player.position = actor.position * Vector3(1, 0, 1) + Vector3(1.5, 0, -1)
	var prepared := false
	for frame in 120:
		await tick()
		if actor.surface.winding_up:
			prepared = true
			break
	check(prepared, "Did not prepare ambush after seeing player below")
	var aim: Vector3 = actor.surface.pounce_aim
	var jumped := false
	for frame in 200:
		await tick()
		jumped = jumped or actor.surface.pouncing
		if jumped and not actor.surface.active():
			break
	check(jumped, "Never jumped from ceiling")
	check(player.hits == 1, "Jump did not produce exactly one physical hit: %s" % player.hits)
	check(actor.surface.pounce_aim.is_equal_approx(aim), "Jump aim moved after commitment")
	check(not actor.surface.active(), "Jump did not land")
	check(actor.position.y < 0.08, "Treated the player's head as the landing floor")
	print("CEILING POUNCE: hits=", player.hits, " landed=", not actor.surface.active())
	# A missed leap remains committed; it must not steer into a sidestep.
	player.position = Vector3(0, 0, -30)
	for frame in 700:
		await tick()
		if actor.surface.phase == 2 and actor.basis.y.y < -0.99:
			break
	check(actor.surface.phase == 2, "Did not return to ceiling after landing")
	print("CEILING RETURN: phase=", actor.surface.phase, " position=", actor.position, " goal=", actor._ceiling_goal, " has_goal=", actor._has_ceiling_goal, " cooldown=", actor.surface.cooldown, " elapsed=", actor.surface.elapsed)
	player.position = actor.position * Vector3(1, 0, 1) + Vector3(-1.0, 0, -0.7)
	for frame in 150:
		await tick()
		if actor.surface.winding_up:
			break
	check(actor.surface.winding_up, "Did not prepare second ambush")
	aim = actor.surface.pounce_aim
	player.position += Vector3(6, 0, 0)
	for frame in 200:
		await tick()
		if not actor.surface.active():
			break
	check(actor.surface.pounce_aim.is_equal_approx(aim), "Leap tracked dodging player")
	check(player.hits == 1, "Dodged leap applied damage")
	# Geometry between the creature and player must also block damage.
	actor.position = Vector3(0, 0, 0)
	actor.rotation = Vector3.ZERO
	player.position = Vector3(0, 0, 0.8)
	box(world, Vector3(4, 3, 0.1), Vector3(0, 1.5, 0.4))
	await physics_frame
	await physics_frame
	check(not actor.check_pounce_contact(Vector3(0, 0.85, 0), Vector3(0, 0.85, 0.7)), "Leap hit through wall")
	print("CEILING HUNT: failures=", failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
