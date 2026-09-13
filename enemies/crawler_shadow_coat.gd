extends RefCounted
## Light-reactive darkness on existing materials only, including the head.
var amount := 0.0
var mesh_count := 0
var _brain: CharacterBody3D
var _visual: Node
var _copies := {}
var _surfaces: Array[Dictionary] = []
var _hair: ShaderMaterial
var _last_applied := -1.0
var light_sensor: Node3D

func configure(brain: CharacterBody3D, visual: Node) -> void:
	_brain = brain
	_visual = visual
	# Procedural meshes are rebuilt while animating. Bind their material sources
	# too, so the skin cannot revert to a bright material on the following frame.
	visual._cloth = _local_material(visual._cloth)
	visual._leg_cloth = _local_material(visual._leg_cloth)
	visual._skin_material = _local_material(visual._skin_material)
	for arm in visual._continuous_arms:
		arm._cloth = visual._cloth
		arm._skin = visual._skin_material
	_bind_meshes(visual)
	var hair := brain.get_node_or_null("FloatingHair") as MeshInstance3D
	if hair != null and hair.material_override is ShaderMaterial:
		_hair = hair.material_override.duplicate() as ShaderMaterial
		hair.material_override = _hair
		mesh_count += 1
	light_sensor = preload("res://enemies/crawler_light_exposure.gd").new()
	light_sensor.name = "ShadowLightSensor"
	brain.add_child(light_sensor)
	light_sensor.configure(brain, visual)
	update(0.0, true)

func _local_material(source: Material) -> Material:
	if source == null or not source is StandardMaterial3D:
		return source
	var id := source.get_instance_id()
	if _copies.has(id):
		return _copies[id]
	var copy := source.duplicate() as StandardMaterial3D
	_copies[id] = copy
	_copies[copy.get_instance_id()] = copy
	_surfaces.append({"material": copy, "albedo": copy.albedo_color,
		"specular": copy.metallic_specular, "emission": copy.emission})
	return copy

func _bind_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.material_override != null:
			mesh.material_override = _local_material(mesh.material_override)
		elif mesh.mesh != null:
			for surface in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(surface, _local_material(mesh.get_active_material(surface)))
		mesh_count += 1
	for child in node.get_children():
		_bind_meshes(child)

func update(delta: float, immediate: bool = false) -> void:
	var target := 0.0
	var player := _brain.get("_player") as Node3D
	light_sensor.update(delta, immediate)
	if _visual.shadow_coat_enabled and is_instance_valid(player):
		# Purely visual distance: this never feeds perception or navigation. Use
		# body centres so walking on the ceiling does not invert the fade origin.
		var center: Vector3 = _brain.surface._center()
		var distance := center.distance_to(player.global_position + Vector3.UP * 0.85)
		var near_distance := float(_visual.shadow_reveal_distance)
		var far_distance := maxf(near_distance + 0.1, float(_visual.shadow_full_distance))
		# Darkness persists nearby if no actual light reaches her. Distance keeps
		# a modest reveal, but a direct beam can reveal the skin fully.
		var distance_darkness := lerpf(0.72, float(_visual.shadow_darkness), smoothstep(near_distance, far_distance, distance))
		target = distance_darkness * (1.0 - light_sensor.exposure)
	# Reveal promptly during fast approaches, reform more slowly when retreating.
	var speed := 12.0 if target < amount else 5.0
	amount = target if immediate else lerpf(amount, target, 1.0 - exp(-speed * delta))
	if absf(amount - target) < 0.0001:
		amount = target
	if absf(amount - _last_applied) < 0.0001:
		return
	_last_applied = amount
	var light_fraction := 1.0 - amount
	for entry in _surfaces:
		var material: StandardMaterial3D = entry.material
		var color: Color = entry.albedo
		material.albedo_color = Color(color.r * light_fraction, color.g * light_fraction, color.b * light_fraction, color.a)
		material.metallic_specular = float(entry.specular) * light_fraction
		material.emission = entry.emission * light_fraction
	if _hair != null:
		_hair.set_shader_parameter("shadow_coat", amount)
