extends RefCounted
## Keep the existing scene visible through windows. Do not force hidden gameplay
## objects on, reveal tape-only clues, or bypass the basement door.

static func apply(scene_root: Node) -> Dictionary:
	var excluded := {}
	var gate := scene_root.find_child("BoilerBasementRenderComponent", true, false)
	if gate != null:
		for branch: Node in gate.get_gated_roots():
			excluded[branch] = true
	var result := {"geometry": 0, "lights": 0}
	_clear_distance_limits(scene_root, excluded, result)
	scene_root.get_viewport().use_occlusion_culling = false
	return result


static func _clear_distance_limits(node: Node, excluded: Dictionary, result: Dictionary) -> void:
	if excluded.has(node):
		return
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		# Distance is part of the paranormal clue mechanic, not an optimization.
		if not (geometry.layers & (1 << 19)):
			if geometry.visibility_range_begin != 0.0 or geometry.visibility_range_end != 0.0:
				result.geometry += 1
			geometry.visibility_range_begin = 0.0
			geometry.visibility_range_end = 0.0
			geometry.visibility_range_begin_margin = 0.0
			geometry.visibility_range_end_margin = 0.0
			geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	elif node is Light3D:
		var light := node as Light3D
		if light.distance_fade_enabled:
			result.lights += 1
		light.distance_fade_enabled = false
	for child in node.get_children():
		_clear_distance_limits(child, excluded, result)
