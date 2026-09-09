extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_validation")


func _run_validation() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(8.0, 0.2, 8.0)
	floor_collision.shape = floor_shape
	floor.add_child(floor_collision)
	floor.position.y = -0.1
	world.add_child(floor)

	var player_scene := load("res://player/player.tscn") as PackedScene
	var player := player_scene.instantiate() as CharacterBody3D
	player.position = Vector3(0.0, 0.9, 0.0)
	assert(is_equal_approx(float(player.get("death_sequence_seconds")), 7.1), "El estado muerto no dura los 7,1 segundos configurados")
	player.set("death_sequence_seconds", 100.0)
	world.add_child(player)
	var attacker := Node3D.new()
	attacker.position = Vector3(0.35, 0.9, -1.0)
	world.add_child(attacker)
	await physics_frame

	var camera := player.get_node("Head/Camera3D") as Camera3D
	var starting_camera_y := camera.global_position.y
	for _hit in 3:
		player.set("_monster_hit_cooldown", 0.0)
		player.call(&"receive_monster_attack", attacker)

	var camera_rig := world.get_node_or_null("DeathCameraPhysics") as RigidBody3D
	assert(camera_rig != null, "El tercer golpe no crea la fisica de la camara")
	assert(camera.get_parent() == camera_rig, "La camara no fue transferida al cuerpo fisico")
	assert(camera_rig.angular_velocity.length() > 2.0, "La camara no recibe giro lateral")
	assert(camera_rig.collision_mask != 0, "La camara fisica no colisiona con el mundo")
	var child_visual := world.get_node_or_null("PlayerDeathChildVisual") as Node3D
	assert(child_visual != null, "No aparece el asset del nino al morir")
	assert(child_visual.scene_file_path.ends_with("child_visual.tscn"), "Se instancio logica NPC en vez de solo el asset")
	assert(child_visual.scale.is_equal_approx(Vector3.ONE * 0.44), "El nino muerto no usa su escala correcta")
	assert(child_visual.find_children("*", "CollisionObject3D", true, false).is_empty(), "El asset del nino contiene colision")
	var death_origin := child_visual.global_position

	for _frame in 90:
		await physics_frame
	assert(camera_rig.global_position.y < starting_camera_y - 0.35, "La camara no cae con gravedad")
	assert(camera_rig.global_position.y >= 0.04, "La camara atraviesa el suelo")
	var horizontal_distance := Vector2(
		camera_rig.global_position.x - death_origin.x,
		camera_rig.global_position.z - death_origin.z
	).length()
	print("DEATH_CAMERA_DISTANCE meters=", horizontal_distance)
	assert(horizontal_distance > 1.0, "La camara no alcanza la nueva distancia de caida")
	print("DEATH_CAMERA_FINAL roll_axis_y=", camera.global_basis.x.y, " rotation=", camera_rig.rotation, " angular_velocity=", camera_rig.angular_velocity)
	assert(absf(camera.global_basis.x.y) > 0.5, "La camara no termina apoyada de lado")
	assert(absf(child_visual.rotation.z) > 0.7, "El cuerpo del nino no queda tumbado de lado")
	var child_direction := camera_rig.global_position.direction_to(child_visual.global_position + Vector3.UP * 0.42)
	assert((-camera.global_basis.z).dot(child_direction) > 0.55, "La camara no intenta terminar mirando al nino")
	for _frame in 330:
		await physics_frame
	child_direction = camera_rig.global_position.direction_to(child_visual.global_position + Vector3.UP * 0.42)
	assert(camera_rig.global_position.is_finite(), "La camara fisica se vuelve inestable durante el estado muerto")
	assert((-camera.global_basis.z).dot(child_direction) > 0.75, "La camara deja de mirar al nino durante la espera")
	print("PLAYER_DEATH_FALL_VALIDATION: PASS")
	quit()
