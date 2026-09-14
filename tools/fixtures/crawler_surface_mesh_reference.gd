extends MeshInstance3D
## Indexed rings share their vertices across every joint. End caps close the skin.
const SIDES := 12
var points := PackedVector3Array()
var widths := PackedVector2Array()
var _indices := PackedInt32Array()
var bust_depth := 0.0

func build(centers: PackedVector3Array, radii: PackedVector2Array, material: Material) -> void:
	points = centers
	widths = radii
	if _indices.is_empty():
		for ring in points.size() - 1:
			for side in SIDES:
				var a := ring * SIDES + side
				var b := ring * SIDES + (side + 1) % SIDES
				_indices.append_array(PackedInt32Array([a, a + SIDES, b, b, a + SIDES, b + SIDES]))
		for side in range(1, SIDES - 1):
			_indices.append_array(PackedInt32Array([0, side, side + 1]))
			var end := (points.size() - 1) * SIDES
			_indices.append_array(PackedInt32Array([end, end + side + 1, end + side]))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var radial := Vector3.RIGHT
	for ring in points.size():
		var tangent := (points[mini(ring + 1, points.size() - 1)] - points[maxi(ring - 1, 0)]).normalized()
		radial = radial.slide(tangent)
		if radial.length_squared() < 0.001:
			radial = tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.BACK)
		radial = radial.normalized()
		var second := tangent.cross(radial).normalized()
		for side in SIDES:
			var angle := TAU * side / SIDES
			var vertex := points[ring] + radial * cos(angle) * widths[ring].x + second * sin(angle) * widths[ring].y
			if bust_depth > 0.0:
				# Two soft, lowered lobes in the blouse itself. Keeping the same
				# indexed shell joins the bust to chest/abdomen without extra pieces.
				var longitudinal := exp(-pow((float(ring) / (points.size() - 1) - 0.68) / 0.17, 2.0))
				var underside := pow(maxf(0.0, -sin(angle)), 1.4)
				var paired := 1.0 - 0.85 * exp(-pow(cos(angle) * widths[ring].x / 0.075, 2.0))
				vertex -= second * bust_depth * longitudinal * underside * paired
			vertices.append(vertex)
			normals.append((radial * cos(angle) / widths[ring].x + second * sin(angle) / widths[ring].y).normalized())
			uvs.append(Vector2(float(side) / SIDES, float(ring) / (points.size() - 1)))
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
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	if mesh == null:
		mesh = ArrayMesh.new()
	(mesh as ArrayMesh).clear_surfaces()
	(mesh as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	material_override = material
