extends SceneTree

const GRANDMOTHER := preload("res://enemies/monster_grandmother.tscn")


class TargetPlayer:
	extends CharacterBody3D


func _initialize() -> void:
	call_deferred(&"_run")


func _box(parent: Node3D, size: Vector3, position: Vector3, name_value: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_value
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = position
	return body


func _run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	_box(level, Vector3(12.0, 0.2, 12.0), Vector3(0.0, -0.1, 0.0), "Floor")
	var platform := _box(
		level,
		Vector3(4.0, 0.62, 2.8),
		Vector3(0.0, 0.31, 2.25),
		"ChurchSanctuaryPlatformTest"
	)

	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.vertices = PackedVector3Array([
		Vector3(-5.0, 0.0, -5.0), Vector3(-5.0, 0.0, 5.0),
		Vector3(5.0, 0.0, 5.0), Vector3(5.0, 0.0, -5.0),
	])
	navigation_mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var region := NavigationRegion3D.new()
	region.navigation_mesh = navigation_mesh
	level.add_child(region)

	var player := TargetPlayer.new()
	player.add_to_group(&"player")
	level.add_child(player)
	player.position = Vector3(0.0, 0.7, 3.0)

	var grandmother := GRANDMOTHER.instantiate()
	grandmother.starts_waiting_covered_eyes = false
	grandmother.position = Vector3.ZERO
	level.add_child(grandmother)
	grandmother.set_physics_process(false)
	for _frame in 6:
		await physics_frame
	grandmother.set("_player", player)
	grandmother.set("_prey", player)
	grandmother.set("_player_has_moved", true)
	grandmother.set("current_state", grandmother.State.CHASE)
	grandmother.set("_navigation_available", true)
	grandmother.set("_last_known_player_position", player.position)

	var maximum_height: float = grandmother.global_position.y
	for _frame in 180:
		var delta := 1.0 / 60.0
		if not grandmother.is_on_floor():
			grandmother.velocity.y -= float(grandmother.get("_gravity")) * delta
		else:
			grandmother.velocity.y = -0.2
		grandmother.set("_target_refresh_timer", maxf(0.0, float(grandmother.get("_target_refresh_timer")) - delta))
		grandmother.call("_update_movement", delta)
		grandmother.move_and_slide()
		maximum_height = maxf(maximum_height, grandmother.global_position.y)
		await physics_frame

	if int(grandmother.get("_obstacle_jump_count")) < 1:
		_fail("La abuela no intentó saltar el obstáculo bajo")
		return
	if maximum_height < 0.72:
		_fail("El salto no ganó altura suficiente: %.3f" % maximum_height)
		return
	if grandmother.global_position.z < 1.3:
		_fail("La abuela saltó pero no superó el borde: %s" % grandmother.global_position)
		return

	# Una pared alta no se puede confundir con un peldaño saltando a través de ella.
	platform.queue_free()
	await physics_frame
	_box(level, Vector3(4.0, 2.4, 0.25), Vector3(0.0, 1.2, 1.0), "TallWall")
	grandmother.position = Vector3.ZERO
	grandmother.velocity = Vector3.ZERO
	grandmother.set("_obstacle_jump_active", false)
	grandmother.set("_obstacle_jump_cooldown_timer", 0.0)
	var jumps_before := int(grandmother.get("_obstacle_jump_count"))
	for _frame in 90:
		var delta := 1.0 / 60.0
		if not grandmother.is_on_floor():
			grandmother.velocity.y -= float(grandmother.get("_gravity")) * delta
		else:
			grandmother.velocity.y = -0.2
		grandmother.call("_update_movement", delta)
		grandmother.move_and_slide()
		await physics_frame
	if int(grandmother.get("_obstacle_jump_count")) != jumps_before:
		_fail("La abuela intentó atravesar una pared alta saltando")
		return

	print("OK: salto de obstáculos bajos y rechazo de paredes altas")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
