extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var actor: CharacterBody3D = load("res://enemies/shadow_crawler.tscn").instantiate()
	actor.remain_still = true
	world.add_child(actor)
	actor.set_physics_process(false)
	var visual: Node3D = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	var sensor: Node3D = visual.shadow_coat.light_sensor
	check(is_equal_approx(visual.shadow_coat.eye_material.get_shader_parameter("eye_brightness"), 0.25), "Eye brightness did not drop to 25 percent")
	for dropped in [false, true]:
		var source: Node3D = load("res://pickups/dropped_flashlight.tscn" if dropped else "res://player/player.tscn").instantiate()
		var beam: SpotLight3D
		if dropped:
			source.freeze = true
			world.add_child(source)
			beam = source.get_node("SpotLight3D")
		else:
			beam = source.get_node("Head/Camera3D/HandRig/Flashlight").duplicate()
			world.add_child(beam)
		beam.global_position = Vector3(0, 1.5, 6)
		beam.global_basis = Basis.IDENTITY
		beam.show()
		var projector := beam.light_projector as GradientTexture2D
		check(is_equal_approx(projector.gradient.get_offset(1), sensor.FLASHLIGHT_CORE_RADIUS), "Damage core disagrees with flashlight's bright ring")
		for depth in [2.0, 6.0, 12.0]:
			var edge: float = depth * tan(deg_to_rad(beam.spot_angle))
			check(sensor._inside_flashlight_core(beam, beam.global_position + Vector3(edge * 0.38, 0, -depth)), "Inner edge fails at distance " + str(depth))
			check(not sensor._inside_flashlight_core(beam, beam.global_position + Vector3(edge * 0.39, 0, -depth)), "Outer ring counted as damaging core")
		actor.position = Vector3(2.0, 0, 0)
		await physics_frame
		await physics_frame
		sensor.update(0.0, true)
		check(sensor.flashlight_exposure > actor.minimum_light_exposure and sensor.flashlight_core_exposure == 0.0, "Halo is not separated from damage")
		actor._beam_damage = 0.0
		actor._room_damage = 0.0
		actor._physics_process(0.1)
		check(actor.dissolution == 0.0, "Runtime halo still inflicts damage")
		actor.position = Vector3.ZERO
		sensor.update(0.0, true)
		actor._physics_process(0.1)
		check(actor._beam_damage > 0.0, "Runtime core does not inflict damage")
		var wall := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(8, 8, 0.2)
		collider.shape = shape
		wall.add_child(collider)
		wall.position = Vector3(0, 1.5, 3)
		world.add_child(wall)
		await physics_frame
		await physics_frame
		sensor.update(0.0, true)
		check(sensor.flashlight_core_exposure == 0.0, "Core damages through wall")
		wall.queue_free()
		beam.hide()
		if not dropped:
			beam.queue_free()
		if dropped:
			source.queue_free()
		else:
			source.free()
		await process_frame
	world.queue_free()
	await process_frame
	print("SHADOW FLASHLIGHT CORE: checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
