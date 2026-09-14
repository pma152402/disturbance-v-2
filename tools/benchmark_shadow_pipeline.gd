extends "res://tools/benchmark_ground_floor_systems.gd"

var _shadow_probe: RefCounted
var _occlusion_probe: RefCounted


func _select_variants(_batching: bool) -> Array:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			return [argument.get_slice("=", 1)]
	return ["pipeline_baseline", "shadow_batch", "exact_occlusion", "combined", "pipeline_repeat"]


func _result_filename(_batching: bool) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			return "/shadow_pipeline_%s.json" % argument.get_slice("=", 1).validate_filename()
	return "/shadow_pipeline.json"


func _configure_variant(variant: String) -> Dictionary:
	var installed_pipeline := current_scene.get_node_or_null("RuntimeShadowPipeline")
	if installed_pipeline != null and variant != "production_enabled":
		installed_pipeline.disable()
	var result := super._configure_variant(variant)
	var effective_variant := variant.trim_prefix("live_")
	result["live_shadow_budget"] = variant.begins_with("live_")
	if result.live_shadow_budget:
		current_scene.get_node("House/RuntimeRenderOptimizer").process_mode = Node.PROCESS_MODE_INHERIT
	var flashlight := current_scene.get_node("Player").get("flashlight") as SpotLight3D
	result["flashlight"] = {"shadow_enabled": flashlight.shadow_enabled, "range": flashlight.spot_range, "angle": flashlight.spot_angle, "bias": flashlight.shadow_bias, "normal_bias": flashlight.shadow_normal_bias}
	result["sun"] = []
	for node in current_scene.find_children("*", "DirectionalLight3D", true, false):
		var sun := node as DirectionalLight3D
		result.sun.append({"path": str(sun.get_path()), "mode": sun.directional_shadow_mode, "shadow_enabled": sun.shadow_enabled, "max_distance": sun.directional_shadow_max_distance})
	if effective_variant in ["shadow_batch", "combined"]:
		_shadow_probe = preload("res://systems/static_shadow_batcher.gd").new()
		var scopes: Array = []
		for path: String in ["House", "House/SchoolUpperFloor"]:
			scopes.append({"path": path, "stats": _shadow_probe.install(current_scene.get_node(path))})
		result["shadow_batch"] = scopes
	if effective_variant in ["exact_occlusion", "combined"]:
		_occlusion_probe = load("res://systems/runtime_exact_occlusion.gd").new()
		result["occlusion"] = _occlusion_probe.install(current_scene)
	if variant == "production_enabled" and installed_pipeline != null:
		result["production_pipeline"] = installed_pipeline.inventory()
	return result
