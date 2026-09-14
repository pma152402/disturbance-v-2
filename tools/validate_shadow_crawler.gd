extends SceneTree

var failures := 0
var checks := 0
var world: Node3D

class DummyPrey extends CharacterBody3D:
	var hits := 0
	func receive_monster_attack(_source: Node) -> void:
		hits += 1

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func spawn_actor() -> CharacterBody3D:
	var actor: CharacterBody3D = load("res://enemies/shadow_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.get_node("EditableVisual").set_physics_process(false)
	return actor

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var actor := spawn_actor()
	var visual: Node3D = actor.get_node("EditableVisual")
	var sensor: Node3D = visual.shadow_coat.light_sensor
	check(actor.get_node_or_null("FloatingHair") == null, "Floating hair survived")
	check(visual.shadow_coat.eyes.size() == 2, "Missing two white eye dots")
	check(visual.shadow_coat.eye_material.get_shader_parameter("eye_glow") == 1.0, "Eyes cannot be seen in darkness")
	check(not visual._head.get_node("OriginalEyes").visible, "Old eyes visible alongside dots")
	check(visual._head.get_node_or_null("HairCap") == null, "Scalp hair survived")
	check(actor.surface.get_script() == load("res://enemies/grandmother_crawler_traversal.gd"), "Lost climbing controller")
	check(not actor.can_climb and not actor.spider_jump_enabled and not actor.obstacle_jump_enabled, "Humanoid retained quadruped traversal")
	check(not is_instance_valid(actor.vomit), "Harmless enemy retained vomit")
	var prey := DummyPrey.new()
	world.add_child(prey)
	actor._player = prey
	actor._prey = prey
	actor._sight_confirmed = true
	check(not actor.can_begin_attack(), "Harmless enemy can start melee")
	actor._change_state(actor.State.ATTACK)
	actor._update_attack(2.0)
	actor.check_pounce_contact(Vector3.ZERO, Vector3.UP, {"collider_id": prey.get_instance_id()})
	actor.on_player_attack_landed(prey, 1)
	check(prey.hits == 0, "Harmless enemy applied damage")
	actor._change_state(actor.State.CHASE)
	for sound_name in ["BreathingSound", "FootstepSound", "VoiceSound"]:
		var sound: AudioStreamPlayer3D = actor.get_node(sound_name)
		sound.play()
		check(sound.stream == null and not sound.playing, "Enemy emits " + sound_name)
	actor._player = null
	actor._prey = null
	prey.queue_free()
	var original: CharacterBody3D = load("res://enemies/grandmother_crawler.tscn").instantiate()
	world.add_child(original)
	original.position = Vector3(30, 0, 0)
	original.set_physics_process(false)
	original.get_node("EditableVisual").set_physics_process(false)
	check(original.has_node("FloatingHair"), "Original lost its hair")
	check(original.get_node("EditableVisual").shadow_coat.get_script() == load("res://enemies/crawler_shadow_coat.gd"), "Original coat changed")
	var lamp := OmniLight3D.new()
	lamp.light_energy = 6.0
	lamp.omni_range = 9.0
	lamp.position = Vector3(0, 2.5, 2)
	lamp.visible = false
	world.add_child(lamp)
	var beam := SpotLight3D.new()
	beam.name = "Flashlight"
	beam.light_energy = 6.5
	beam.spot_range = 21.0
	beam.spot_angle = 29.0
	beam.position = Vector3(0, 1.2, 4)
	beam.visible = false
	world.add_child(beam)
	beam.look_at(Vector3(0, 1.0, 0))
	await physics_frame
	await physics_frame
	sensor.update(0.0, true)
	check(sensor.exposure == 0.0, "Darkness detected as light")
	actor._apply_light_damage(20.0, sensor.room_exposure, sensor.flashlight_exposure)
	check(actor.dissolution == 0.0, "Died in darkness")
	lamp.visible = true
	sensor.update(0.0, true)
	check(sensor.room_exposure > 0.3 and sensor.flashlight_exposure == 0.0, "Lamp classification")
	actor._apply_light_damage(0.5, sensor.room_exposure, sensor.flashlight_exposure)
	check(actor.dissolution > 0.05 and actor.dissolution < 0.2, "Room did not start gradual dissolution")
	lamp.visible = false
	beam.visible = true
	sensor.update(0.0, true)
	check(sensor.flashlight_exposure > 0.99 and sensor.room_exposure == 0.0, "Beam classification")
	beam.look_at(Vector3(0, 1, 10))
	sensor.update(0.0, true)
	check(sensor.flashlight_exposure == 0.0, "Damage outside flashlight cone")
	beam.look_at(Vector3(0, 1, 0))
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 6, 0.3)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector3(0, 1, 2)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	sensor.update(0.0, true)
	check(sensor.flashlight_exposure == 0.0, "Beam damages through wall")
	var previous: float = actor.dissolution
	actor._apply_light_damage(5.0, sensor.room_exposure, sensor.flashlight_exposure)
	check(actor.dissolution < previous and actor.dissolution == 0.0, "Shade failed to heal room-light damage")
	wall.queue_free()
	await physics_frame
	await physics_frame
	sensor.update(0.0, true)
	check(sensor.flashlight_exposure > 0.99, "Beam not restored after wall removal")
	beam.visible = false
	for pose in [Basis.IDENTITY, Basis(Vector3.BACK, PI * 0.5), Basis(Vector3.BACK, PI)]:
		actor.basis = pose
		visual._physics_process(1.0 / 60.0)
		check(visual.torso.material_override == visual.shadow_coat.material, "Animated torso lost black coat")
		check(visual._head.get_node("Head").material_override == visual.shadow_coat.material, "Head lost permanent black mask")
		for eye in visual.shadow_coat.eyes:
			check(eye.get_parent() == visual._head and eye.material_override == visual.shadow_coat.eye_material, "White eye detached during pose")
	actor.queue_free()
	for fps in [30, 60, 120]:
		for is_beam in [false, true]:
			actor = spawn_actor()
			var duration: float = actor.flashlight_dissolve_seconds if is_beam else actor.room_dissolve_seconds
			var elapsed := 0.0
			while not actor._dissolved and elapsed < duration + 1.0:
				actor._apply_light_damage(1.0 / fps, 0.0 if is_beam else 0.4, 1.0 if is_beam else 0.0)
				elapsed += 1.0 / fps
			check(absf(elapsed - duration) < 1.1 / fps, "Wrong dissolution timing at %d FPS" % fps)
			check(actor.is_queued_for_deletion() and actor.collision_layer == 0 and actor.process_mode == Node.PROCESS_MODE_DISABLED, "Dead enemy can still interact")
			check(not actor.visible, "Dead enemy still visible")
		await process_frame
	# Exercise actual physics entry point, not only the damage accumulator.
	actor = spawn_actor()
	lamp.visible = true
	actor.remain_still = true
	actor.set_physics_process(true)
	actor.get_node("EditableVisual").set_physics_process(true)
	for frame in 15:
		await physics_frame
	check(actor.dissolution > 0.0, "Runtime physics failed to apply light damage")
	world.queue_free()
	await process_frame
	print("SHADOW CRAWLER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
