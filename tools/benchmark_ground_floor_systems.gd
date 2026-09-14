extends "res://tools/benchmark_ground_floor_gameplay.gd"

## Aislamiento temporal. Cada variante nace de una partida nueva y no se guarda.
func _watchdog() -> void:
	await create_timer(360.0, true, false, true).timeout
	_timed_out = true
	push_error("Timeout del diagnóstico de sistemas")
	quit(124)


func _select_variants(_batching: bool) -> Array:
	if "--scripts" in OS.get_cmdline_user_args():
		return ["scripts_baseline", "ente_brain_paused", "ente_animation_paused", "ente_all_paused", "grandma_paused", "rain_updates_paused", "scripts_baseline_repeat"]
	return ["shadows_baseline", "flashlight_shadow_off", "sun_shadow_off", "school_shadows_off", "budget_shadows_off", "all_shadows_off", "shadows_baseline_repeat"]


func _result_filename(_batching: bool) -> String:
	return "/ground_floor_scripts.json" if "--scripts" in OS.get_cmdline_user_args() else "/ground_floor_shadows.json"


func _configure_variant(variant: String) -> Dictionary:
	var result := {"disabled": [], "shadow_lights": []}
	var ente := current_scene.get_node_or_null("BlackEnteAtSpawn")
	if ente == null:
		ente = current_scene.get_node_or_null("ShadowCrawlerAtSpawn")
	if variant.begins_with("ente_"):
		assert(ente != null, "No se encontró el ente para la comparación")
		if variant == "ente_brain_paused":
			ente.set_physics_process(false)
			ente.set_process(false)
		elif variant == "ente_animation_paused":
			ente.get_node("EditableVisual").process_mode = Node.PROCESS_MODE_DISABLED
		else:
			ente.process_mode = Node.PROCESS_MODE_DISABLED
		result.disabled.append(str(ente.get_path()) + ":" + variant)
	if variant == "grandma_paused":
		var grandma := current_scene.get_node("ImportedGrandmotherGroundFloor")
		grandma.process_mode = Node.PROCESS_MODE_DISABLED
		result.disabled.append(str(grandma.get_path()))
	if variant == "rain_updates_paused":
		var timer := current_scene.get_node("Weather/RainFollowTimer") as Timer
		timer.stop()
		result.disabled.append(str(timer.get_path()))
	if not "--scripts" in OS.get_cmdline_user_args():
		# Misma selección de luces en todas las variantes gráficas, elegida por
		# el optimizador al aparecer. Evita reemplazos que oculten el coste aislado.
		current_scene.get_node("House/RuntimeRenderOptimizer").process_mode = Node.PROCESS_MODE_DISABLED
		var flashlight := current_scene.get_node("Player").get("flashlight") as Light3D
		for node in current_scene.find_children("*", "Light3D", true, false):
			var light := node as Light3D
			var path := str(light.get_path())
			var off := variant == "all_shadows_off"
			off = off or (variant == "flashlight_shadow_off" and light == flashlight)
			off = off or (variant == "sun_shadow_off" and light is DirectionalLight3D)
			off = off or (variant == "school_shadows_off" and ("SchoolUpperFloor" in path or "SchoolCompletion" in path))
			off = off or (variant == "budget_shadows_off" and path.begins_with(str(current_scene.get_node("House").get_path()) + "/") and light is not DirectionalLight3D)
			if off and light.shadow_enabled:
				light.shadow_enabled = false
				result.disabled.append(path)
			elif light.shadow_enabled:
				result.shadow_lights.append(path)
	return result
