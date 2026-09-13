extends SceneTree
var failures := 0

func _init() -> void:
	call_deferred("run")

func box(parent: Node, size: Vector3, position_: Vector3) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = position_

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	box(world, Vector3(18, 0.2, 18), Vector3(0, -0.1, 0))
	box(world, Vector3(18, 6, 0.2), Vector3(0, 3, 1.5))
	box(world, Vector3(18, 0.2, 18), Vector3(0, 5.1, 0))
	var church := "--church" in OS.get_cmdline_user_args()
	var start := Vector3.ZERO
	var wall_clue := Vector3(0, 0, 5)
	var ceiling_clue := Vector3(0, 0, -3)
	if church:
		for child in world.get_children():
			child.free()
		var scene := load("res://levels/house_baked.tscn").instantiate() as Node3D
		for floor_name in ["GroundFloor", "UpperFloor"]:
			var floor_root := scene.get_node(floor_name) as Node3D
			for child in floor_root.get_children():
				if child is StaticBody3D and str(child.name).begins_with("Church"):
					var body := child.duplicate() as StaticBody3D
					body.transform = floor_root.transform * child.transform
					world.add_child(body)
		for index in range(1, 9):
			check(world.has_node("ChurchVaultSurfaceCollision%d" % index), "Missing visible vault collision")
		scene.free()
		start = Vector3(-10.5, 0, -32.5)
		wall_clue = Vector3(-20, 0, -32.5)
		ceiling_clue = Vector3(-5, 0, -32.5)
	var player := CharacterBody3D.new()
	player.add_to_group("player")
	world.add_child(player)
	player.position = Vector3(0, 0, -3)
	var actor := load("res://enemies/church_grandmother.tscn").instantiate() as CharacterBody3D
	world.add_child(actor)
	actor.position = start
	actor.set_physics_process(false)
	var visual := actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	await physics_frame
	await physics_frame
	actor.set("alertness", 1.0)
	var surface: RefCounted = actor.get("surface")
	surface.cooldown = 0.0
	surface.consider(0.6, wall_clue, true)
	check(surface.active(), "Failed to attach to a solid wall")
	var ceiling_seen := false
	var inverted := false
	var peak := 0.0
	for frame in 1000:
		var previous_center: Vector3 = surface._center()
		surface.step(1.0 / 60.0, ceiling_clue, true)
		check(previous_center.distance_to(surface._center()) < 0.16, "Surface motion displaced the capsule abruptly")
		actor.set("_idle_clock", float(frame) / 60.0)
		visual._physics_process(1.0 / 60.0)
		peak = maxf(peak, surface._center().y)
		ceiling_seen = ceiling_seen or surface.phase == surface.Phase.CEILING
		inverted = inverted or actor.global_basis.y.y < -0.85
		if not surface.active():
			break
		await physics_frame
	check(peak > 3.5, "Did not ascend wall")
	check(ceiling_seen, "Did not transfer to ceiling")
	check(inverted, "Did not invert on ceiling")
	check(not surface.active(), "Did not return to ground")
	check(actor.global_basis.y.y > 0.99, "Not upright after landing")
	if church:
		check(peak > 6.0, "Did not reach the church vault")
		print("CHURCH VAULT: failures=", failures, " peak=", peak, " ceiling=", ceiling_seen, " inverted=", inverted)
		world.queue_free()
		await process_frame
		quit(1 if failures else 0)
		return
	# No supporting wall: must remain grounded.
	actor.position = Vector3(0, 0, -6)
	surface.cooldown = 0.0
	surface.scan_timer = 0.0
	surface.consider(0.6, Vector3(0, 0, -12), true)
	check(not surface.active(), "Climbed empty air")
	# Both alternating attacks must load above the head, then descend.
	actor.position = Vector3.ZERO
	actor.rotation = Vector3.ZERO
	actor.set("_prey", player)
	actor.set("_player", player)
	actor.set("current_state", 4)
	actor.set("_attack_direction", Vector3.BACK)
	actor.set("attack_target_position", Vector3(0, 1, 1.3))
	for side in [1.0, -1.0]:
		actor.set("attack_side", side)
		actor.set("_attack_timer", actor.get("attack_windup_seconds"))
		for frame in 90:
			visual._physics_process(1.0 / 60.0)
		var wrist: Node3D = visual.get("_left_wrist" if side > 0 else "_right_wrist")
		var head: Node3D = visual.get("_head")
		var loaded_height := wrist.global_position.y
		check(loaded_height > head.global_position.y, "Attack does not load above the head: side %s" % side)
		actor.set("_attack_timer", actor.get("attack_hit_seconds"))
		for frame in 90:
			visual._physics_process(1.0 / 60.0)
		check(loaded_height - wrist.global_position.y > 0.4, "Attack does not descend: side %s" % side)
	# Losing the last clue while attached must release the wall safely.
	surface.cooldown = 0.0
	surface.scan_timer = 0.0
	surface.consider(0.6, Vector3(0, 0, 5), true)
	check(surface.active(), "Cannot start a second excursion")
	surface.step(1.0 / 60.0, Vector3(0, 0, 5), false)
	check(surface.phase == surface.Phase.DROP or not surface.active(), "Ignores expired evidence while climbing")
	print("GRANNY SURFACES: failures=", failures, " peak=", peak, " ceiling=", ceiling_seen, " inverted=", inverted)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
