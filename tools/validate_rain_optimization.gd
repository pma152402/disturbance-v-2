extends SceneTree


func _init() -> void:
	var packed := load("res://environment/rainy_weather.tscn") as PackedScene
	assert(packed != null)
	var weather := packed.instantiate()
	root.add_child(weather)
	await process_frame

	var emitter := weather.get_node("Rain/NorthRain") as GPUParticles3D
	var material := emitter.process_material as ParticleProcessMaterial
	assert(emitter.amount == 480, "La lluvia debe usar el presupuesto reducido de 480 gotas.")
	assert(material.spread == 0.0, "Las gotas no deben desviarse hacia dentro de los tejados.")
	assert(material.emission_box_extents == Vector3(14.0, 0.5, 14.0), "El emisor debe ser compacto.")
	assert(emitter.visibility_aabb.size.x <= 44.0 and emitter.visibility_aabb.size.z <= 44.0, "El margen visible debe seguir siendo local.")
	assert(emitter.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Las gotas nunca deben proyectar sombras.")
	assert(not emitter.local_coords, "Las gotas ya emitidas no deben arrastrarse con el jugador.")
	assert(emitter.emitting, "La lluvia debe seguir activa tanto dentro como fuera.")
	assert(material.collision_mode == ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT, "Las cubiertas deben eliminar las gotas tambien en interiores.")
	for child in weather.get_node("Rain").get_children():
		if child is GPUParticlesCollision3D:
			assert(child.visible and (child.cull_mask & emitter.layers) != 0, "Las cubiertas deben bloquear el emisor local.")
	print("RAIN_OPTIMIZATION_VALIDATION: PASS")
	quit(0)
