extends MeshInstance3D
## Indexed rings share their vertices across every joint. End caps close the skin.
const SIDES := 12
var points := PackedVector3Array()
var widths := PackedVector2Array()
var _indices := PackedInt32Array()
var bust_depth := 0.0
var _uvs := PackedVector2Array()
var _cosines := PackedFloat64Array()
var _sines := PackedFloat64Array()
var _undersides := PackedFloat64Array()
var _longitudinals := PackedFloat64Array()
var _paired := PackedFloat64Array()
var _profile_widths := PackedVector2Array()
var _ring_count := 0

func _prepare_profile() -> void:
	if _cosines.is_empty():
		for side in SIDES:
			var angle := TAU * side / SIDES
			_cosines.append(cos(angle))
			_sines.append(sin(angle))
			_undersides.append(pow(maxf(0.0, -sin(angle)), 1.4))
	if _ring_count != points.size():
		_ring_count = points.size()
		_indices.clear()
		_uvs.resize(_ring_count * SIDES)
		_longitudinals.resize(_ring_count)
		for ring in _ring_count:
			_longitudinals[ring] = exp(-pow((float(ring) / (_ring_count - 1) - 0.68) / 0.17, 2.0))
			for side in SIDES:
				_uvs[ring * SIDES + side] = Vector2(float(side) / SIDES, float(ring) / (_ring_count - 1))
		for ring in _ring_count - 1:
			for side in SIDES:
				var a := ring * SIDES + side
				var b := ring * SIDES + (side + 1) % SIDES
				_indices.append_array(PackedInt32Array([a, a + SIDES, b, b, a + SIDES, b + SIDES]))
		for side in range(1, SIDES - 1):
			_indices.append_array(PackedInt32Array([0, side, side + 1]))
			var end := (_ring_count - 1) * SIDES
			_indices.append_array(PackedInt32Array([end, end + side + 1, end + side]))
		_profile_widths.clear()
	if bust_depth > 0.0 and widths != _profile_widths:
		# Guardar una instantánea: el llamante puede reutilizar y editar radii.
		# Un alias ocultaría esos cambios y clear() vaciaría su array anterior.
		_profile_widths = widths.duplicate()
		_paired.resize(_ring_count * SIDES)
		for ring in _ring_count:
			for side in SIDES:
				_paired[ring * SIDES + side] = 1.0 - 0.85 * exp(-pow(_cosines[side] * widths[ring].x / 0.075, 2.0))

func build(centers: PackedVector3Array, radii: PackedVector2Array, material: Material) -> void:
	points = centers
	widths = radii
	# El perfil y los UV dependen de la sección, no de la pose. Float64 conserva
	# la precisión de sin/cos y el orden de las operaciones geométricas originales.
	_prepare_profile()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	vertices.resize(points.size() * SIDES)
	normals.resize(points.size() * SIDES)
	var radial := Vector3.RIGHT
	for ring in points.size():
		var tangent := (points[mini(ring + 1, points.size() - 1)] - points[maxi(ring - 1, 0)]).normalized()
		radial = radial.slide(tangent)
		if radial.length_squared() < 0.001:
			radial = tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.BACK)
		radial = radial.normalized()
		var second := tangent.cross(radial).normalized()
		for side in SIDES:
			var cosine := _cosines[side]
			var sine := _sines[side]
			var index := ring * SIDES + side
			var vertex := points[ring] + radial * cosine * widths[ring].x + second * sine * widths[ring].y
			if bust_depth > 0.0:
				# Two soft, lowered lobes in the blouse itself. Keeping the same
				# indexed shell joins the bust to chest/abdomen without extra pieces.
				var longitudinal := _longitudinals[ring]
				var underside := _undersides[side]
				var paired := _paired[index]
				vertex -= second * bust_depth * longitudinal * underside * paired
			vertices[index] = vertex
			# El torso calcula después normales suaves por triángulo; no generar
			# antes normales radiales que se descartarían con normals.fill().
			if bust_depth <= 0.0:
				normals[index] = (radial * cosine / widths[ring].x + second * sine / widths[ring].y).normalized()
	if bust_depth > 0.0:
		# Recalculate smooth normals from the shaped cloth, preserving its
		# continuous topology and the original torso's material/render pass.
		normals.fill(Vector3.ZERO)
		for triangle in range(0, _indices.size(), 3):
			var a := _indices[triangle]
			var b := _indices[triangle + 1]
			var c := _indices[triangle + 2]
			var face := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
			normals[a] += face
			normals[b] += face
			normals[c] += face
		for index in normals.size():
			normals[index] = normals[index].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	if mesh == null:
		mesh = ArrayMesh.new()
	(mesh as ArrayMesh).clear_surfaces()
	(mesh as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	material_override = material
