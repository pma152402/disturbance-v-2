extends RefCounted
## Opaque body cutout and two tiny emissive eyes, without extra lights or aura.
var light_sensor: Node3D
var material: ShaderMaterial
var eye_material: ShaderMaterial
var eyes: Array[MeshInstance3D] = []
var smile: MeshInstance3D
var smile_material: ShaderMaterial
var smile_progress := 0.0

func configure(brain: CharacterBody3D, visual: Node) -> void:
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/shadow_crawler_dissolve.gdshader")
	_bind(visual)
	_build_eyes(visual._head)
	smile = preload("res://enemies/black_ente_smile.gd").new()
	visual._head.add_child(smile)
	smile.configure(visual._head.get_node("Head"))
	smile_material = smile.material_override
	light_sensor = preload("res://enemies/crawler_light_exposure.gd").new()
	light_sensor.name = "ShadowLightSensor"
	brain.add_child(light_sensor)
	light_sensor.configure(brain, visual)

func _bind(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_bind(child)

func update(_delta: float, _immediate: bool = false) -> void:
	# The brain samples once per physics tick, including while climbing/attacking.
	pass

func set_dissolution(value: float) -> void:
	material.set_shader_parameter("dissolution", value)
	eye_material.set_shader_parameter("dissolution", value)
	smile_material.set_shader_parameter("dissolution", value)

func set_stare_progress(value: float, delta: float) -> void:
	var target := clampf(value, 0.0, 1.0)
	smile_progress = target if target >= smile_progress else move_toward(smile_progress, target, maxf(delta, 0.0) * 3.0)
	smile.visible = smile_progress > 0.001
	smile_material.set_shader_parameter("progress", smile_progress)
	eye_material.set_shader_parameter("pupil_dilation", smoothstep(0.0, 0.85, smile_progress))
	for eye in eyes:
		eye.scale = Vector3(1.0 / 0.78, 1.0, 1.0 / 0.85) * lerpf(1.0, 1.45, smoothstep(0.0, 1.0, smile_progress))

func _build_eyes(head: Node3D) -> void:
	var original := head.get_node("OriginalEyes") as MeshInstance3D
	original.hide()
	eye_material = material.duplicate() as ShaderMaterial
	eye_material.set_shader_parameter("eye_glow", 1.0)
	eye_material.set_shader_parameter("eye_brightness", 0.25)
	# Find each authored eye in head-local space, so the dots stay inside the
	# sockets when the head turns, scales, crawls on walls or hangs upside down.
	var bounds: Array[AABB] = [AABB(), AABB()]
	var seen := [false, false]
	for surface_index in original.mesh.get_surface_count():
		var vertices: PackedVector3Array = original.mesh.surface_get_arrays(surface_index)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var point: Vector3 = original.transform * vertex
			var side := 0 if point.x < 0.0 else 1
			bounds[side] = bounds[side].expand(point) if seen[side] else AABB(point, Vector3.ZERO)
			seen[side] = true
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.50
	sphere.radial_segments = 20
	sphere.rings = 12
	for side in 2:
		var eye := MeshInstance3D.new()
		eye.name = "LeftShadowEye" if side == 0 else "RightShadowEye"
		eye.mesh = sphere
		eye.material_override = eye_material
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(eye)
		eye.position = bounds[side].get_center()
		eye.position.z = bounds[side].end.z - 0.06
		eye.scale = Vector3(1.0 / 0.78, 1.0, 1.0 / 0.85)
		eyes.append(eye)
