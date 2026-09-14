extends SceneTree

var _failed := false


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	change_scene_to_file("res://levels/test.tscn")
	for frame in 90:
		await process_frame
	var house := current_scene.get_node("House")
	_check(house.full_startup_visibility, "Full startup visibility is disabled")
	var shadow_pipeline := current_scene.get_node_or_null("RuntimeShadowPipeline")
	_check(shadow_pipeline != null and shadow_pipeline.inventory().enabled, "Exact shadow pipeline missing at startup")
	_check(root.use_occlusion_culling, "Verified exact occlusion is not enabled")
	if shadow_pipeline != null:
		_check(int(shadow_pipeline.inventory().occlusion.occluders) == 256, "Unexpected exact occluder count")
	_check(house.get_node_or_null("RuntimeOccluders") == null, "Automatic box occluders were installed")
	_check(house.get_node_or_null("SchoolUpperFloor") != null, "School missing at startup")
	_check(house.get_node_or_null("SchoolCompletion") != null, "School third floor and staff rooms missing at startup")
	_check(house.get_node("GroundFloor/ChurchNaveFloor").is_visible_in_tree(), "Church missing at startup")
	_check(house.get_node("Clothesline_mixed_family").is_visible_in_tree(), "Courtyard clothesline hidden")
	_check(house.get_node("Clothesline_large_blanket").is_visible_in_tree(), "Rooftop clothesline hidden")
	_check(not ResourceLoader.has_cached("res://environment/church_catacombs.tscn"), "Labyrinth loaded early")
	var gate := house.get_node("BoilerBasementRenderComponent")
	_check(not gate.is_content_rendered(), "Basement must remain door-gated")
	var exclusions := {}
	for branch: Node in gate.get_gated_roots():
		exclusions[branch] = true
	_inspect(current_scene, exclusions)
	_check(house.get_node("RuntimeSectorActivityOptimizer").inventory().lights == 0, "Sector timer still gates lights")
	print("FULL STARTUP VISIBILITY ", "FAILED" if _failed else "PASSED: church, school, clotheslines, exterior; basement hidden, labyrinth absent")
	quit(1 if _failed else 0)


func _inspect(node: Node, exclusions: Dictionary) -> void:
	if exclusions.has(node):
		return
	if node is GeometryInstance3D and not (node.layers & (1 << 19)):
		_check(node.visibility_range_begin == 0.0 and node.visibility_range_end == 0.0, "Distance limit remains: " + str(node.get_path()))
	if node is Light3D:
		_check(not node.distance_fade_enabled, "Light fade remains: " + str(node.get_path()))
	for child in node.get_children():
		_inspect(child, exclusions)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
