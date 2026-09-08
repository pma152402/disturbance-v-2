extends SceneTree

class TargetPlayer:
	extends CharacterBody3D
	var hits := 0
	func receive_monster_attack(_actor: Node3D) -> void:
		hits += 1
	func is_flashlight_on() -> bool:
		return false
	func is_personal_light_on() -> bool:
		return false

func _initialize() -> void:
	call_deferred(&"_run")

func _box(parent: Node3D, size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = position
	return body

func _run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	_box(level, Vector3(20, 0.2, 20), Vector3(0, -0.1, 0))
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-9,0,-9),Vector3(-9,0,9),Vector3(9,0,9),Vector3(9,0,-9)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	var region := NavigationRegion3D.new()
	region.navigation_mesh = mesh
	level.add_child(region)
	var player := TargetPlayer.new()
	player.add_to_group(&"player")
	level.add_child(player)
	player.position = Vector3(0, 0, 0.9)
	var grandma := (load("res://enemies/monster_grandmother_imported.tscn") as PackedScene).instantiate() as CharacterBody3D
	level.add_child(grandma)
	grandma.set("remain_still", false)
	grandma.set_physics_process(false)
	grandma.position = Vector3.ZERO
	for frame in 4:
		await physics_frame
	grandma.call(&"_refresh_preferred_prey", true)
	var wall := _box(level, Vector3(3, 3, 0.12), Vector3(0, 1.5, 0.45))
	await physics_frame
	await physics_frame
	if grandma.call(&"_has_attack_contact", 2.0):
		_fail("Attack contact went through wall")
		return
	grandma.call(&"_change_state", 4)
	for frame in 65:
		grandma.call(&"_update_attack", 1.0 / 60.0)
	if player.hits != 0:
		_fail("Damage applied through wall")
		return
	wall.queue_free()
	await physics_frame
	await physics_frame
	grandma.set("_attack_cooldown_timer", 0.0)
	grandma.call(&"_change_state", 2)
	grandma.call(&"_try_begin_attack")
	if int(grandma.get("current_state")) != 4:
		_fail("Clear attack never started")
		return
	grandma.set_physics_process(true)
	for frame in 45:
		await physics_frame
	grandma.set_physics_process(false)
	if player.hits != 1:
		_fail("Committed attack did not apply exactly one hit: %d" % player.hits)
		return
	grandma.position = Vector3.ZERO
	player.position = Vector3(8, 0, 8)
	# Esta comprobación aísla el modo puramente sensorial; el nivel jugable sí
	# activa aparte el pulso anti-espera solicitado.
	grandma.set("supernatural_player_reveal", false)
	grandma.set("_last_known_player_position", Vector3(0, 0, 2))
	grandma.call(&"_begin_lost_player_search")
	for frame in 60:
		grandma.call(&"_update_lost_player_search", 1.0 / 60.0)
	if int(grandma.get("_search_step_index")) != 0:
		_fail("Search skipped last known position")
		return
	grandma.position = Vector3(0, 0, 2)
	for frame in 60:
		grandma.call(&"_update_lost_player_search", 1.0 / 60.0)
	if int(grandma.get("_search_step_index")) < 1:
		_fail("Search did not inspect after reaching evidence")
		return
	var memory: Vector3 = grandma.get("_last_known_player_position")
	if grandma.call(&"_update_player_reveal", 60.0) or memory != grandma.get("_last_known_player_position"):
		_fail("Hidden player location was revealed without a stimulus")
		return
	for frame in 600:
		grandma.call(&"_update_lost_player_search", 1.0 / 60.0)
	if int(grandma.get("_photo_behavior")) != 0:
		_fail("Search never returned to patrol")
		return
	var sound_wall := _box(level, Vector3(3, 3, 0.15), Vector3(0, 1.5, 4))
	await physics_frame
	await physics_frame
	grandma.call(&"_on_player_footstep_heard", Vector3(0, 0, 6), 6.0)
	if int(grandma.get("_photo_behavior")) == 6:
		_fail("Distant footstep ignored wall attenuation")
		return
	sound_wall.queue_free()
	await physics_frame
	await physics_frame
	grandma.call(&"_on_player_footstep_heard", Vector3(0, 0, 6), 6.0)
	if int(grandma.get("_photo_behavior")) != 6 or float(grandma.get("_footstep_interest_timer")) < 2.0:
		_fail("Audible footstep did not allow time to investigate")
		return
	grandma.position = Vector3(0, 0, 6)
	grandma.call(&"_update_lost_stimulus", 0.1)
	if int(grandma.get("current_state")) != 3:
		_fail("Footstep arrival did not lead to inspection")
		return
	print("INTELLIGENCE PASSED: wall protection, committed hit, memory, inspection, no omniscience, patrol, hearing")
	level.queue_free()
	await process_frame
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
