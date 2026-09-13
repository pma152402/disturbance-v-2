extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = load("res://player/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	var camera: Camera3D = player.get("camera")
	var curtain: Node3D = load("res://house_props/living_room_curtains.tscn").instantiate()
	world.add_child(curtain)
	for placement in [Transform3D.IDENTITY, Transform3D(Basis(Vector3.UP, 1.2).scaled(Vector3(0.8, 1.1, 1.0)), Vector3(4, 2, -3))]:
		curtain.transform = placement
		for side in [-1.0, 1.0]:
			var target: Vector3 = curtain.to_global(Vector3(-1.36, 1.4, 0))
			var eye: Vector3 = target + curtain.global_basis.z.normalized() * side * 1.6
			player.global_position += eye - camera.global_position
			camera.look_at(target)
			await physics_frame
			await physics_frame
			check(not player.call("_try_interact", KEY_E), "Wrong key activated curtain")
			for cycle in 3:
				check(player.call("_try_interact", KEY_F), "Player F failed from side " + str(side))
				if curtain.busy:
					curtain._tween.custom_step(curtain.transition_seconds + 0.05)
				await physics_frame
			check(curtain.mode == 0, "F did not complete the three-mode cycle")
			var wall := StaticBody3D.new()
			var collision := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1, 2.5, 0.2)
			collision.shape = box
			wall.add_child(collision)
			world.add_child(wall)
			wall.global_position = (eye + target) * 0.5
			wall.global_basis = curtain.global_basis.orthonormalized()
			await physics_frame
			await physics_frame
			check(not player.call("_try_interact", KEY_F), "Player activated curtain through a wall")
			wall.free()
		curtain.set_mode(2, false)
		var opening: Vector3 = curtain.to_global(Vector3(0, 1.4, 0))
		player.global_position += opening + curtain.global_basis.z.normalized() * 1.6 - camera.global_position
		camera.look_at(opening)
		await physics_frame
		await physics_frame
		check(not player.call("_try_interact", KEY_F), "Empty opening intercepted player interaction")
		curtain.set_mode(0, false)
	curtain.free()
	player.queue_free()
	await process_frame
	# Exercise the real scene and its batching scripts, including all 14 scaled
	# window instances, the church confessional and school stage.
	var house: Node3D = load("res://levels/house_baked.tscn").instantiate()
	house.set_script(null)
	world.add_child(house)
	await physics_frame
	await physics_frame
	var curtains := get_nodes_in_group("interactive_curtains")
	check(curtains.size() == 16, "Some existing curtain instances lack a controller: " + str(curtains.size()))
	var counts := [0, 0, 0]
	var surfaces := 0
	for control in curtains:
		counts[control.profile] += 1
		surfaces += control.visual.mesh.get_surface_count()
		check(control.visual.is_visible_in_tree(), "School/static optimizer hid curtain: " + str(control.get_path()))
		check(control.visual.mesh.get_blend_shape_count() == 0, "Real scene keeps idle morphs")
		check(control.interact(), "Real scene curtain cannot animate")
		control._tween.custom_step(control.transition_seconds + 0.05)
		check(not control.busy, "Real scene curtain did not finish")
		for state in [0, 1, 2]:
			control.set_mode(state, false)
			await physics_frame
			var reachable := false
			for handle in control._handles:
				if handle.collision_layer != 2:
					continue
				for side in [-1.0, 1.0]:
					var point: Vector3 = handle.global_position
					var eye: Vector3 = point + control.global_basis.z.normalized() * side * 1.4
					var ray := PhysicsRayQueryParameters3D.create(eye, point, 3)
					ray.collide_with_areas = true
					var hit := house.get_world_3d().direct_space_state.intersect_ray(ray)
					reachable = reachable or (not hit.is_empty() and hit.collider == handle)
			check(reachable, "No unobstructed handle in real scene: " + str(control.get_path()) + " mode " + str(state))
	check(counts == [14, 1, 1], "Wrong curtain variant coverage: " + str(counts))
	print("CURTAIN INTERACTION: failures=", failures, " checks=", checks, " instances=", counts, " static_material_surfaces=", surfaces)
	house.queue_free()
	await process_frame
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
