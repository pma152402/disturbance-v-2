extends "res://tools/benchmark_ground_floor_systems.gd"

## Candidatos de optimización; nunca se instalan en la partida normal.
func _select_variants(_batching: bool) -> Array:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			return [argument.get_slice("=", 1)]
	return ["candidate_baseline", "sun_two_splits", "three_local_shadows", "static_merge", "candidate_baseline_repeat"]


func _result_filename(_batching: bool) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			return "/ground_floor_candidate_%s.json" % argument.get_slice("=", 1).validate_filename()
	return "/ground_floor_candidates.json"


func _configure_variant(variant: String) -> Dictionary:
	var result := super._configure_variant(variant)
	if variant == "sun_two_splits":
		for node in current_scene.find_children("*", "DirectionalLight3D", true, false):
			var light := node as DirectionalLight3D
			result["previous_sun_mode"] = light.directional_shadow_mode
			light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			result["sun_mode"] = light.directional_shadow_mode
	if variant == "three_local_shadows":
		var optimizer := current_scene.get_node("House/RuntimeRenderOptimizer")
		var camera := current_scene.get_node("Player/Head/Camera3D") as Camera3D
		var candidates: Array = []
		for light: Light3D in optimizer.get("_lights"):
			if light.shadow_enabled:
				candidates.append(light)
		candidates.sort_custom(func(a: Light3D, b: Light3D) -> bool: return a.global_position.distance_squared_to(camera.global_position) < b.global_position.distance_squared_to(camera.global_position))
		for index in range(3, candidates.size()):
			candidates[index].shadow_enabled = false
			result.disabled.append(str(candidates[index].get_path()))
		result["local_shadows_kept"] = mini(3, candidates.size())
	if variant == "static_merge":
		var probe = load("res://tools/static_geometry_merge_probe.gd").new()
		var scopes: Array = []
		for path: String in ["House", "House/SchoolUpperFloor"]:
			var branch := current_scene.get_node(path)
			var stats: Dictionary = probe.install(branch)
			scopes.append({"path": path, "stats": stats})
		result["merge"] = scopes
	return result
