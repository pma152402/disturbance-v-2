extends RefCounted
## CPU approximation of camera_lens_grime.gdshader for semantic recognition.
## Keep the coverage, cleaning oval and opacity rules in sync with that shader.

static func capture(tree: SceneTree) -> Dictionary:
	var grime := tree.get_first_node_in_group(&"camera_lens_grime")
	if grime == null:
		return {}
	return grime.call(&"get_observer_state") as Dictionary


static func opacity_at(uv: Vector2, state: Dictionary) -> float:
	var dirt := float(state.get("dirt", 0.0))
	if dirt <= 0.001:
		return 0.0
	var large := _noise(uv * Vector2(6.0, 4.0) + Vector2.ONE * 3.7)
	var small := _noise(uv * Vector2(26.0, 18.0))
	var drops := _noise(uv * Vector2(53.0, 10.0) + Vector2.ONE * 8.0)
	var field := large * 0.64 + small * 0.28 + drops * 0.08
	var patches := smoothstep(0.76 - dirt * 0.66, 0.87 - dirt * 0.65, field)
	var opacity := minf(0.985, patches * (0.72 + dirt * 0.26) + dirt * 0.17)
	var oval := 1.0 - smoothstep(0.83, 1.17, ((uv - Vector2.ONE * 0.5) / Vector2(0.215, 0.155)).length())
	var cleared := float(state.get("central_clear", 0.0))
	if bool(state.get("wiping", false)):
		var progress := float(state.get("wipe_progress", 0.0))
		cleared = maxf(cleared, smoothstep(0.0, 0.15, progress) * smoothstep(0.95 - progress * 0.9, 1.05 - progress * 0.9, uv.x))
	opacity *= 1.0 - oval * cleared * (1.0 - lerpf(0.18, 0.28, drops))
	opacity *= 1.0 - float(state.get("wash_progress", 0.0))
	var maximum := float(state.get("maximum_opacity", 0.70))
	return clampf(opacity * maximum, 0.0, maximum)


static func _hash(point: Vector2) -> float:
	return fposmod(sin(point.dot(Vector2(127.1, 311.7))) * 43758.5453, 1.0)


static func _noise(point: Vector2) -> float:
	var cell := point.floor()
	var weight := point - cell
	weight = weight * weight * (Vector2.ONE * 3.0 - 2.0 * weight)
	return lerpf(lerpf(_hash(cell), _hash(cell + Vector2.RIGHT), weight.x), lerpf(_hash(cell + Vector2.DOWN), _hash(cell + Vector2.ONE), weight.x), weight.y)
