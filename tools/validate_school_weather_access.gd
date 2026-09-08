extends SceneTree
var errors := 0
func _init() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error(message)
func run() -> void:
	var house: Node3D = load("res://levels/house_baked.tscn").instantiate()
	house.set_script(null)
	root.add_child(house)
	var school := house.get_node("SchoolUpperFloor") as Node3D
	var weather: Node3D = load("res://environment/rainy_weather.tscn").instantiate()
	# Keep the same collision volumes without lightning/audio during visual review.
	weather.set_script(null)
	root.add_child(weather)
	for n in weather.find_children("*","GPUParticles3D",true,false):
		check(n.process_material.collision_mode == ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT, "Rain must disappear on particle shelter contact")
	var blockers := school.find_children("*","GPUParticlesCollisionBox3D",true,false)
	blockers.append_array(weather.find_children("*","GPUParticlesCollisionBox3D",true,false))
	for point in [Vector3(-23.5,6,-10),Vector3(-17.3,6,-10),Vector3(-17,6,2),Vector3(-21,6,2),Vector3(-28.4,6,-15),Vector3(-20,6,-4),Vector3(-22,1,-10),Vector3(-28,1,4),Vector3(-10,1,-4)]:
		check(sheltered(point,blockers), "Unprotected school interior " + str(point))
	for point in [Vector3(-10,6,-4),Vector3(-28,6,3),Vector3(-24,6,3),Vector3(-32,1,-10)]:
		check(not sheltered(point,blockers), "Outdoor area incorrectly protected " + str(point))
	await physics_frame
	await physics_frame
	var space := house.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-6,6.1,-6.15),Vector3(-4,6.1,-6.15),1))
	check(not hit.is_empty() and str(hit.collider.name) == "WindowGlass_06", "Window blocked by opaque wall or collider")
	var hinge: Node3D = school.get_node("HouseBridgePortal/HouseBridgeDoor/Hinge")
	check(hinge.has_method("interact"), "House door must keep normal project interaction")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	root.size = Vector2i(1200,900)
	camera.position = Vector3(-11.7,6.8,-5.5)
	camera.look_at(Vector3(-5.28,6.1,-4.8))
	await screenshot("school_access_finished", camera)
	house.queue_free()
	weather.queue_free()
	await process_frame
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12,0.14,0.15)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7,0.76,0.8)
	environment.environment.ambient_light_energy = 0.7
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-40,0)
	sun.light_energy = 1.2
	root.add_child(sun)
	var lamp: Node3D = load("res://house_props/courtyard_streetlamp.tscn").instantiate()
	root.add_child(lamp)
	check(lamp.get_node("WarmLight").visible, "Streetlamp starts on")
	lamp.get_node("WarmLight").visible = false
	check(not lamp.get_node("WarmLight").visible, "Streetlamp switches off")
	lamp.get_node("WarmLight").visible = true
	check(lamp.find_children("*","CollisionShape3D",true,false).size() == 3,"Streetlamp base/post/lantern collisions")
	camera.position = Vector3(5,3.4,6)
	camera.look_at(Vector3(0,2.2,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.2
	await screenshot("courtyard_streetlamp_preview",camera)
	print("ACCESS / WEATHER / STREETLAMP: ",errors," errors")
	quit(1 if errors else 0)
func sheltered(point: Vector3, blockers: Array) -> bool:
	for blocker in blockers:
		if AABB(-blocker.size/2,blocker.size).has_point(blocker.to_local(point)): return true
	return false
func screenshot(name_: String, _camera: Camera3D) -> void:
	for i in range(8): await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/output/" + name_ + ".png")
