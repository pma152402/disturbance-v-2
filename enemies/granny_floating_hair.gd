extends MeshInstance3D

## Cabello procedural de la abuela. Cada tira comparte una raíz rígida con el
## cuero cabelludo y deja libres el resto de sus vértices para el shader.

@export_node_path("Node3D") var head_path: NodePath
# Los 46 originales forman la melena de nuca. Las capas adicionales rellenan
# la bóveda del cráneo y la línea frontal sin eliminar esa silueta trasera.
@export_range(16, 72, 1) var strand_count := 46
@export_range(12, 48, 1) var crown_strand_count := 30
@export_range(2, 16, 1) var front_wisp_count := 8
@export_range(4, 12, 1) var segments_per_strand := 8
@export_range(0.3, 1.3, 0.01) var minimum_length := 0.56
@export_range(0.3, 1.5, 0.01) var maximum_length := 0.96
@export_range(0.005, 0.05, 0.001) var minimum_width := 0.016
@export_range(0.005, 0.06, 0.001) var maximum_width := 0.034
@export var random_seed := 7331
@export_range(0.5, 1.5, 0.01) var head_size_multiplier := 1.0

var _head: Node3D


func _ready() -> void:
	_head = get_node_or_null(head_path) as Node3D
	mesh = _build_hair_mesh()
	custom_aabb = AABB(Vector3(-0.8, -1.15, -0.75), Vector3(1.6, 1.75, 1.5))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	process_priority = 20
	_follow_head()


func _process(_delta: float) -> void:
	_follow_head()


func _follow_head() -> void:
	if not is_instance_valid(_head):
		_head = get_node_or_null(head_path) as Node3D
	if not is_instance_valid(_head):
		return
	# Conserva posición y rotación de la cabeza sin heredar la escala irregular
	# del GLB. Así los parámetros del pelo permanecen expresados en metros.
	# Uniform sizing preserves the root envelope, strand length and animated
	# displacement together, without inheriting the imported rig's scale.
	global_transform = Transform3D(_head.global_basis.orthonormalized().scaled(Vector3.ONE * head_size_multiplier), _head.global_position)


func _build_hair_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	var random := RandomNumberGenerator.new()
	random.seed = random_seed
	# Envolvente medida del mesh Head respecto a HeadPivot. Las raíces antiguas
	# usaban un cráneo de ~20 cm y quedaban dentro de la cabeza real (~36 cm).
	var skull_center := Vector3(-0.003, 0.25, 0.185)
	var skull_radii := Vector3(0.372, 0.365, 0.305)
	var total_strands := strand_count + crown_strand_count + front_wisp_count
	for strand_index in total_strands:
		var angle := 0.0
		var root := Vector3.ZERO
		var crown := false
		var front_wisp := false
		if strand_index < strand_count:
			# Capa original: conserva los mechones largos de nuca y laterales.
			var fraction := float(strand_index) / float(strand_count)
			angle = fraction * TAU + random.randf_range(-0.075, 0.075)
			crown = strand_index % 4 == 0
			var radial_scale := random.randf_range(1.015, 1.055)
			var root_height := random.randf_range(0.235, 0.43)
			var vertical_fraction := (root_height - skull_center.y) / skull_radii.y
			var horizontal_radius := sqrt(maxf(0.15, 1.0 - vertical_fraction * vertical_fraction))
			root = Vector3(
				skull_center.x + sin(angle) * skull_radii.x * horizontal_radius * radial_scale,
				root_height,
				skull_center.z + cos(angle) * skull_radii.z * horizontal_radius * radial_scale
			)
		elif strand_index < strand_count + crown_strand_count:
			# Disco de coronilla con ángulo áureo: evita anillos o calvas visibles
			# y reparte raíces sobre toda la parte superior del cráneo.
			crown = true
			var crown_index := strand_index - strand_count
			var crown_radius := sqrt((float(crown_index) + 0.35) / float(crown_strand_count))
			angle = crown_index * 2.399963 + random.randf_range(-0.08, 0.08)
			var polar_angle := lerpf(0.08, 1.22, crown_radius)
			root = Vector3(
				skull_center.x + sin(angle) * skull_radii.x * sin(polar_angle) * 1.035,
				skull_center.y + skull_radii.y * cos(polar_angle) * 1.035 + random.randf_range(0.0, 0.008),
				skull_center.z + cos(angle) * skull_radii.z * sin(polar_angle) * 1.035
			)
		else:
			# Pelos finos naciendo en la frente y las sienes. Son pocos para que
			# la cara siga siendo legible, pero eliminan el aspecto de calvicie.
			front_wisp = true
			var wisp_index := strand_index - strand_count - crown_strand_count
			var wisp_fraction := (float(wisp_index) + 0.5) / float(front_wisp_count)
			var side := lerpf(-1.0, 1.0, wisp_fraction)
			angle = lerpf(-0.72, 0.72, wisp_fraction)
			var wisp_x := side * 0.245
			var wisp_y := random.randf_range(0.39, 0.525)
			var x_fraction := (wisp_x - skull_center.x) / skull_radii.x
			var y_fraction := (wisp_y - skull_center.y) / skull_radii.y
			var front_surface := sqrt(maxf(0.04, 1.0 - x_fraction * x_fraction - y_fraction * y_fraction))
			root = Vector3(wisp_x, wisp_y, skull_center.z + skull_radii.z * front_surface + 0.012)
		var front_center := not front_wisp and root.z > 0.39 and absf(root.x) < 0.18
		var length := random.randf_range(minimum_length, maximum_length)
		if crown and strand_index >= strand_count:
			length *= random.randf_range(0.72, 0.94)
		if front_wisp:
			length *= random.randf_range(0.43, 0.62)
		if front_center:
			# Sólo algunos pelos finos caen sobre la cara; el resto se abre hacia
			# las sienes para conservar ojos y boca legibles.
			length *= 0.48 if strand_index % 3 else 0.72
		var width := random.randf_range(minimum_width, maximum_width)
		if front_center or front_wisp:
			width *= 0.72
		var radial := Vector3(
			(root.x - skull_center.x) / skull_radii.x,
			0.0,
			(root.z - skull_center.z) / skull_radii.z
		).normalized()
		if radial.length_squared() < 0.1:
			radial = Vector3(sin(angle), 0.0, cos(angle)).normalized()
		if front_wisp:
			radial = Vector3(signf(root.x) * 0.38, 0.0, 0.92).normalized()
		var tangent := Vector3(cos(angle), 0.0, -sin(angle)).normalized()
		var curl_direction := random.randf_range(-1.0, 1.0)
		var phase := random.randf_range(0.0, TAU)
		# Gris blanco de pelo envejecido, con variación cálida y sucia entre
		# mechones para evitar un blanco plástico o completamente uniforme.
		var tint := random.randf_range(0.78, 1.16)
		var grime := random.randf_range(0.0, 0.075)
		var strand_color := Color(
			0.58 * tint - grime * 0.35,
			0.565 * tint - grime * 0.55,
			0.515 * tint - grime,
			1.0
		)
		var first_vertex := vertices.size()
		for segment_index in segments_per_strand + 1:
			var t := float(segment_index) / float(segments_per_strand)
			var point := root
			point += Vector3.DOWN * length * t
			point += radial * (0.035 * t + 0.055 * t * t)
			point += tangent * curl_direction * sin(t * PI) * random.randf_range(0.055, 0.12)
			point.y += sin(t * PI * 1.35 + phase) * 0.025 * t
			var taper := lerpf(1.0, 0.16, pow(t, 1.35))
			var half_width := width * taper * 0.5
			vertices.append(point - tangent * half_width)
			vertices.append(point + tangent * half_width)
			normals.append(radial)
			normals.append(radial)
			colors.append(strand_color)
			colors.append(strand_color)
			uvs.append(Vector2(0.0, t))
			uvs.append(Vector2(1.0, t))
			uv2s.append(Vector2(phase / TAU, curl_direction * 0.5 + 0.5))
			uv2s.append(Vector2(phase / TAU, curl_direction * 0.5 + 0.5))
		if strand_index % 7 == 0:
			# Un pequeño quiebro rígido cerca de la raíz rompe la silueta de
			# peluca y hace que algunos mechones parezcan arrancados o erizados.
			var root_index := first_vertex
			vertices[root_index] += radial * 0.012
			vertices[root_index + 1] += radial * 0.012
		for segment_index in segments_per_strand:
			var a := first_vertex + segment_index * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
