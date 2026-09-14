extends SceneTree
## Real beams and geometry: exposure budget, safe flight and darkness recovery.
var failures := 0
var checks := 0
var world: Node3D

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func box(size_: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)
	body.position = at
	return body

func spawn() -> CharacterBody3D:
	var actor: CharacterBody3D = load("res://enemies/shadow_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.get_node("EditableVisual").set_physics_process(false)
	return actor

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	box(Vector3(30, 0.2, 30), Vector3(0, -0.1, 0))
	box(Vector3(30, 0.2, 30), Vector3(0, 5.1, 0))
	box(Vector3(0.2, 5, 30), Vector3(5.1, 2.5, 0))
	for fps in [30, 60, 120]:
		var actor := spawn()
		# Even a stale Inspector override and prior room damage must not make a
		# single flash lethal; the hard minimum survives frame-rate changes.
		actor.flashlight_dissolve_seconds = 0.1
		actor._apply_light_damage(4.0, 0.4, 0.0)
		for frame in int(1.4 * fps):
			actor._apply_light_damage(1.0 / fps, 0.0, 1.0)
		check(not actor._dissolved, "Beam killed before 1.5 seconds at %d FPS" % fps)
		var before: float = actor.dissolution
		for frame in fps: actor._apply_light_damage(1.0 / fps, 0.0, 0.0)
		check(absf(actor.dissolution - (before - 0.25)) < 0.0001, "Darkness healing differs across frame rates")
		check(actor._room_damage > 0.0 and actor._room_damage < 0.8, "Room-light damage does not heal")
		actor._apply_light_damage(0.11, 0.0, 1.0)
		check(not actor._dissolved, "Healing failed to restore light resistance")
		var room_damage: float = actor._room_damage
		actor._apply_light_damage(0.1, 0.0, 1.0)
		check(actor._room_damage == room_damage, "Healing continues under direct flashlight")
		for frame in fps * 4: actor._apply_light_damage(1.0 / fps, 0.0, 0.0)
		check(actor.dissolution == 0.0 and actor._beam_damage == 0.0 and actor._room_damage == 0.0, "Four seconds in darkness did not fully heal")
		actor._apply_light_damage(0.75, 0.0, 1.0)
		check(absf(actor.dissolution - 0.5) < 0.0001, "Fresh flashlight no longer takes 1.5 seconds")
		var beam_damage: float = actor._beam_damage
		actor._apply_light_damage(0.1, 0.4, 0.0)
		check(actor._beam_damage == beam_damage, "Healing continues under room light")
		actor._apply_light_damage(0.75, 0.0, 1.0)
		check(actor._dissolved, "Sustained beam never finishes dissolution")
		actor._apply_light_damage(10.0, 0.0, 0.0)
		check(actor._dissolved and actor.dissolution == 1.0, "Darkness revived a dissolved enemy")
		await process_frame
	var beam := SpotLight3D.new()
	beam.name = "Flashlight"
	beam.spot_angle = 16.0
	beam.spot_range = 21.0
	beam.light_energy = 6.5
	beam.position = Vector3(0, 2.2, 4)
	beam.visible = false
	world.add_child(beam)
	for attachment in [0]: # This variant now remains bipedal on the ground.
		var actor := spawn()
		if attachment != 0:
			var normal := Vector3.DOWN if attachment == 2 else Vector3.LEFT
			var center := Vector3(0, 4.22, 0) if attachment == 2 else Vector3(4.22, 2.5, 0)
			var basis_: Basis = actor.surface.JumpPlanner.aligned_basis(normal, Vector3.BACK)
			actor.transform = Transform3D(basis_, center - basis_ * actor.surface.collision.position)
			actor.surface.phase = attachment
			actor.surface.normal = normal
			actor.surface.wall_normal = normal
			actor.upright_amount = 0.0
		var visual: Node3D = actor.get_node("EditableVisual")
		for i in 20: visual._physics_process(1.0 / 60.0)
		beam.position.y = actor.surface._center().y
		beam.look_at(actor.surface._center())
		await physics_frame
		await physics_frame
		var sensor: Node3D = visual.shadow_coat.light_sensor
		sensor.update(0.0, true)
		check(not actor.light_escape.active, "Unlit enemy is already fleeing")
		beam.show()
		sensor.update(0.0, true)
		check(sensor.flashlight_exposure > 0.95, "Fixture beam missed creature")
		var initial := actor.global_position
		var remembered_player := Vector3(-10, 0, -10)
		actor._evidence_position = remembered_player
		var live_exposure: float = sensor.exposure
		sensor.sample_at_offset(Vector3(8, 0, 0))
		check(sensor.exposure == live_exposure, "Shelter prediction overwrote live damage sensor")
		actor._physics_process(1.0 / 60.0)
		check(actor.light_escape.active and actor.light_escape.has_goal, "Light failed to trigger a reachable escape route")
		check(not actor.can_ceiling_pounce(), "Fleeing creature can attack from ceiling")
		var peak_escape_speed := 0.0
		for frame in 115:
			if actor._dissolved: break
			actor._physics_process(1.0 / 60.0)
			peak_escape_speed = maxf(peak_escape_speed, actor.velocity.length())
			visual._physics_process(1.0 / 60.0)
			await physics_frame
		check(not actor._dissolved, "Creature failed to survive its escape")
		check(peak_escape_speed > 3.5, "Light escape still uses the old slow movement speed")
		check(actor._evidence_position == remembered_player, "Escape destination replaced player evidence")
		check(actor.global_position.distance_to(initial) > 0.7, "Fleeing creature stayed still")
		sensor.update(0.0, true)
		print("ESCAPE FIXTURE: attachment=", attachment, " initial=", initial, " final=", actor.global_position, " goal=", actor.light_escape.goal, " phase=", actor.surface.phase, " exposure=", sensor.exposure)
		check(sensor.exposure < actor.minimum_light_exposure, "Creature did not leave fixed flashlight beam")
		check(not actor.surface.collision_guard.penetrates(actor.surface, actor.surface.collision.global_transform), "Escape left body inside geometry")
		if attachment == 2:
			check(actor.surface.phase == actor.surface.Phase.CEILING and actor.global_basis.y.y < -0.98, "Escape dropped creature from ceiling")
		if attachment == 1:
			check(actor.surface.phase in [actor.surface.Phase.WALL, actor.surface.Phase.CEILING], "Wall escape lost attachment")
		beam.hide()
		sensor.update(0.0, true)
		actor.light_escape._safe_seconds = 0.0
		var damage: float = actor.dissolution
		var shelter := actor.position
		for frame in 60:
			actor._physics_process(1.0 / 60.0)
			await physics_frame
		check(actor.light_escape.active and actor.dissolution <= damage and is_equal_approx(actor.dissolution, maxf(0.0, damage - 0.25)), "Creature immediately resumed pursuit or failed to heal in shelter")
		check(actor.position.distance_to(shelter) < 0.3, "Creature kept moving out of shelter")
		actor._apply_light_damage(4.0, 0.0, 0.0)
		actor.light_escape.step(4.0, sensor)
		check(not actor.light_escape.active, "Creature never resumes normal behavior after sheltering")
		actor.queue_free()
		await process_frame
	# Occlusion must stop the light before it even triggers a flight response.
	var actor := spawn()
	box(Vector3(8, 5, 0.3), Vector3(0, 2.5, 2))
	beam.position = Vector3(0, 1.2, 4)
	beam.look_at(Vector3(0, 1.0, 0))
	beam.show()
	await physics_frame
	await physics_frame
	var sensor: Node3D = actor.get_node("EditableVisual").shadow_coat.light_sensor
	sensor.update(0.0, true)
	actor._physics_process(1.0 / 60.0)
	check(actor.dissolution == 0.0 and not actor.light_escape.active, "Light through a wall triggers damage or flight")
	world.queue_free()
	await process_frame
	print("SHADOW LIGHT ESCAPE: checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
