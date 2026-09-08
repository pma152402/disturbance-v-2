extends SceneTree


func _init() -> void:
	var packed := load("res://environment/rainy_weather.tscn") as PackedScene
	assert(packed != null)
	var weather := packed.instantiate()
	root.add_child(weather)
	await process_frame

	var emitter := weather.get_node("Rain/NorthRain") as GPUParticles3D
	var material := emitter.process_material as ParticleProcessMaterial
	assert(emitter.amount == 720, "La lluvia debe conservar densidad de tormenta con un presupuesto reducido.")
	assert(material.emission_box_extents == Vector3(14.0, 0.5, 14.0), "El emisor debe ser compacto.")
	assert(emitter.visibility_aabb.size == Vector3(32.0, 50.0, 32.0), "El volumen visible sigue siendo demasiado grande.")

	weather.call("_set_rain_outdoors", false)
	assert(emitter.emitting, "La lluvia exterior debe seguir visible desde las ventanas.")
	assert(material.collision_mode == 0, "La colision GPU debe apagarse en interiores.")
	assert(material.emission_box_extents == Vector3(8.0, 0.5, 8.0), "La lluvia vista desde ventanas debe usar un volumen aun menor.")
	for child in weather.get_node("Rain").get_children():
		if child is GPUParticlesCollision3D:
			assert(child.cull_mask == 0 and not child.visible, "Los colisionadores deben apagarse en interiores.")

	weather.call("_set_rain_outdoors", true)
	assert(emitter.emitting, "La lluvia debe reanudarse en exteriores.")
	assert(material.collision_mode != 0, "La colision GPU debe reactivarse en exteriores.")
	assert(material.emission_box_extents == Vector3(14.0, 0.5, 14.0), "El volumen exterior debe restaurarse.")
	print("RAIN_OPTIMIZATION_VALIDATION: PASS")
	quit(0)
