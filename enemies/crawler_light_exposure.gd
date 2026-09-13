extends Node3D
## Cached light registry; bounded visibility probes at 10 Hz, never GPU readback.
var exposure := 0.0
var _actor: CharacterBody3D
var _visual: Node3D
var _lights: Array[Light3D] = []
var _timer := 0.0

func configure(actor: CharacterBody3D, visual: Node3D) -> void:
	_actor = actor
	_visual = visual
	_collect(get_tree().root)
	get_tree().node_added.connect(_register)

func _register(node: Node) -> void:
	if node is Light3D and not _lights.has(node):
		_lights.append(node)

func _collect(node: Node) -> void:
	_register(node)
	for child in node.get_children():
		_collect(child)

func update(delta: float, immediate: bool = false) -> void:
	_timer -= delta
	if _timer <= 0.0 or immediate:
		_timer = 0.1
		exposure = sample_exposure()

func sample_exposure() -> float:
	var points: Array[Vector3] = [_visual._head.global_position, _actor.surface._center()]
	var candidates: Array[Dictionary] = []
	for i in range(_lights.size() - 1, -1, -1):
		var light := _lights[i]
		if not is_instance_valid(light):
			_lights.remove_at(i)
			continue
		if light.get_world_3d() != _actor.get_world_3d() or not light.is_visible_in_tree() or light.light_energy <= 0.01 or light.light_negative or (light.light_cull_mask & _visual.torso.layers) == 0:
			continue
		var strengths: Array[float] = []
		for point in points:
			strengths.append(_strength(light, point))
		var potential := maxf(strengths[0], strengths[1])
		if potential > 0.01:
			candidates.append({"light": light, "strengths": strengths, "potential": potential})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.potential > b.potential)
	var room := 0.0
	var beam := 0.0
	for i in mini(6, candidates.size()):
		var light: Light3D = candidates[i].light
		var visible_strength := 0.0
		for j in points.size():
			if candidates[i].strengths[j] <= 0.01:
				continue
			# Cast outward from the creature: exclude its own capsule; stop before
			# the bulb/held lamp so its housing cannot occlude its own emission.
			var end := light.global_position if not light is DirectionalLight3D else points[j] + light.global_basis.z * 40.0
			end = end.move_toward(points[j], 0.16)
			var query := PhysicsRayQueryParameters3D.create(points[j], end, _actor.collision_mask | (1 << 19), [_actor.get_rid()])
			if _actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				visible_strength = maxf(visible_strength, candidates[i].strengths[j])
		if _is_flashlight(light):
			beam = maxf(beam, visible_strength)
		else:
			room += visible_strength * 0.40
	return clampf(maxf(beam, minf(room, 0.55)), 0.0, 1.0)

func _is_flashlight(light: Light3D) -> bool:
	if not light is SpotLight3D:
		return false
	return str(light.name).to_lower().contains("flashlight") or (light.get_parent() != null and light.get_parent().scene_file_path == "res://pickups/dropped_flashlight.tscn")

func _strength(light: Light3D, point: Vector3) -> float:
	var energy := light.light_energy * light.light_color.get_luminance()
	if light is DirectionalLight3D:
		return clampf(energy, 0.0, 1.0)
	var offset := point - light.global_position
	var distance := offset.length()
	if not light is SpotLight3D and not light is OmniLight3D:
		return 0.0
	var reach: float = light.spot_range if light is SpotLight3D else light.omni_range
	if distance >= reach:
		return 0.0
	var falloff := 1.0 - smoothstep(reach * 0.25, reach, distance)
	if light is SpotLight3D:
		var cosine := (-light.global_basis.z).normalized().dot(offset.normalized())
		var edge := cos(deg_to_rad(light.spot_angle))
		falloff *= smoothstep(edge, lerpf(edge, 1.0, 0.35), cosine)
	return clampf(energy / 2.5 * falloff, 0.0, 1.0)
