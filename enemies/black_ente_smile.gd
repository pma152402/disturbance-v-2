extends MeshInstance3D
## A tooth ribbon fitted to the actual face triangles, following the head pose.
func configure(face: MeshInstance3D) -> void:
	name = "BlackEnteSmile"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	extra_cull_margin = 0.3
	# Include the authored teeth: these protrude beyond the skin at the chin.
	var triangles := PackedVector3Array()
	for part in face.get_parent().get_children():
		if part is MeshInstance3D and part.name in ["Head", "LowerTeeth", "UpperTeeth"]:
			var faces: PackedVector3Array = part.mesh.get_faces()
			for point in faces:
				triangles.append(part.transform * point)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	const SEGMENTS := 64
	const ROWS := 8
	for i in SEGMENTS + 1:
		var u := float(i) / SEGMENTS
		var x := (u * 2.0 - 1.0) * 1.18
		var curve := pow(absf(x / 1.18), 1.7)
		var center_y := 0.44 + curve * 0.78
		var half_height := lerpf(0.30, 0.018, curve)
		for edge in ROWS + 1:
			var v := float(edge) / ROWS
			var y := center_y + half_height * (1.0 - 2.0 * v)
			var front := -INF
			for jaw_offset in [0.0, -0.2, -0.4, -0.65, -0.85]:
				for t in range(0, triangles.size(), 3):
					var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(x, y + jaw_offset, 5), Vector3.FORWARD, triangles[t], triangles[t + 1], triangles[t + 2])
					if hit != null:
						front = maxf(front, hit.z)
			# Reserve clearance for the whole jaw-opening movement, not just rest.
			vertices.append(Vector3(x, y, (front if is_finite(front) else 1.1) + 0.16))
			uvs.append(Vector2(u, v))
		if i < SEGMENTS:
			for row in ROWS:
				var base := i * (ROWS + 1) + row
				var next := base + ROWS + 1
				indices.append_array(PackedInt32Array([base, base + 1, next, base + 1, next + 1, next]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var ribbon := ArrayMesh.new()
	ribbon.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = ribbon
	var teeth := ShaderMaterial.new()
	teeth.shader = preload("res://shaders/black_ente_smile.gdshader")
	material_override = teeth
