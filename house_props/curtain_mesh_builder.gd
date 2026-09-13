extends RefCounted
## Build/cache the three opaque poses once. Idle curtains use ordinary static
## meshes; only the curtain currently moving uses two GPU blend shapes.
static var _cache := {}

static func build(sources: Array[MeshInstance3D], transforms: Array[Transform3D], profile: int, width: float, bottom: float, top: float) -> Dictionary:
	var key := str([profile, width, bottom, top])
	for i in sources.size():
		key += str(sources[i].mesh.get_instance_id()) + str(transforms[i])
		for surface in sources[i].mesh.get_surface_count():
			key += str(sources[i].get_active_material(surface).get_instance_id()) + ":"
	if _cache.has(key):
		return _cache[key]
	var groups := {}
	var folds: Array[int] = []
	for i in sources.size():
		if (profile == 0 and str(sources[i].name).contains("Pleat")) or (profile == 1 and sources[i].mesh is CylinderMesh):
			folds.append(i)
	folds.sort_custom(func(a: int, b: int) -> bool: return transforms[a].origin.x < transforms[b].origin.x)
	var upper_folds: Array[int] = []
	var lower_folds: Array[int] = []
	if profile == 0:
		for index in folds:
			if str(sources[index].name).contains("Upper"):
				upper_folds.append(index)
			else:
				lower_folds.append(index)
	for i in sources.size():
		var source := sources[i]
		var source_mesh := source.mesh
		if profile == 2 and source_mesh is BoxMesh:
			source_mesh = source_mesh.duplicate()
			source_mesh.subdivide_height = 12
		for surface in source_mesh.get_surface_count():
			var material := source.get_active_material(surface)
			var material_id := material.get_instance_id()
			if not groups.has(material_id):
				groups[material_id] = {"material": material, "vertices": [PackedVector3Array(), PackedVector3Array(), PackedVector3Array()],
					"normals": [PackedVector3Array(), PackedVector3Array(), PackedVector3Array()], "uv": PackedVector2Array(), "indices": PackedInt32Array()}
			var group: Dictionary = groups[material_id]
			var arrays := source_mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var offset: int = group.vertices[0].size()
			for index in indices:
				group.indices.append(index + offset)
			group.uv.append_array(uv)
			for state in 3:
				var target := transforms[i]
				if profile != 2 and state != 0:
					var family := folds
					var is_tail := profile == 0 and lower_folds.has(i)
					if profile == 0:
						family = lower_folds if is_tail else upper_folds
					var fold := family.find(i)
					if fold >= 0:
						var half_count := family.size() / 2
						var side := -1.0 if fold < half_count else 1.0
						var slot := fold if side < 0 else family.size() - 1 - fold
						var cell := width * 0.5 / half_count
						var stack := width * (0.105 if profile == 0 else 0.025)
						var x := side * (width * 0.5 - (slot + 0.5) * (cell if state == 1 else stack / half_count))
						var bounds := source_mesh.get_aabb()
						var radius := maxf(bounds.size.x * 0.5, 0.001)
						var sx := (cell * 0.69 if state == 1 else stack / half_count * 0.80) / radius
						# The upper fold unfolds downwards, carrying the tail joint
						# with it. Tails contract into the hem instead of becoming a
						# second, disconnected set of full-height hanging strips.
						var hem_top := bottom + 0.045
						var y_min := bottom if is_tail else bottom + (0.015 if profile == 0 else 0.0)
						var y_max := hem_top if is_tail else top
						var sy := (y_max - y_min) / bounds.size.y
						var basis := Basis(Vector3.BACK, PI) if transforms[i].basis.y.y < 0.0 else Basis.IDENTITY
						target = Transform3D(basis.scaled(Vector3(sx, sy, 0.72 if profile == 0 else 1.0)), Vector3(x, (y_max + y_min) * 0.5, 0))
					elif str(source.name).ends_with("Tie"):
						target.basis = target.basis.scaled(Vector3.ONE * 0.001)
						target.origin.y = bottom + 0.025
				var normal_basis := target.basis.inverse().transposed()
				for v in vertices.size():
					var point := target * vertices[v]
					if profile != 2 and state == 1 and folds.has(i):
						# Overlap adjacent folds, but keep the outer hem inside the rail.
						point.x = clampf(point.x, -width * 0.5, width * 0.5)
					if profile == 2 and state != 1:
						var t := clampf((point.y - bottom) / (top - bottom), 0.0, 1.0)
						var opening := 0.16 if state == 2 else lerpf(0.17, 1.0, smoothstep(0.54, 1.0, t))
						point.x = -width * 0.5 + (point.x + width * 0.5) * opening
					group.vertices[state].append(point)
					group.normals[state].append((normal_basis * normals[v]).normalized())
	var animated := ArrayMesh.new()
	animated.add_blend_shape("Closed")
	animated.add_blend_shape("Open")
	animated.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	var poses: Array[ArrayMesh] = [ArrayMesh.new(), ArrayMesh.new(), ArrayMesh.new()]
	var envelope := AABB()
	var first := true
	for group: Dictionary in groups.values():
		var state_arrays: Array[Array] = []
		for state in 3:
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = group.vertices[state]
			arrays[Mesh.ARRAY_NORMAL] = group.normals[state]
			arrays[Mesh.ARRAY_TEX_UV] = group.uv
			arrays[Mesh.ARRAY_INDEX] = group.indices
			poses[state].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			poses[state].surface_set_material(poses[state].get_surface_count() - 1, group.material)
			state_arrays.append(arrays)
			for point: Vector3 in group.vertices[state]:
				envelope = AABB(point, Vector3.ZERO) if first else envelope.expand(point)
				first = false
		var blends: Array[Array] = []
		for state in [1, 2]:
			var blend := []
			blend.resize(Mesh.ARRAY_MAX)
			blend[Mesh.ARRAY_VERTEX] = group.vertices[state]
			blend[Mesh.ARRAY_NORMAL] = group.normals[state]
			blends.append(blend)
		animated.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, state_arrays[0], blends)
		animated.surface_set_material(animated.get_surface_count() - 1, group.material)
	animated.custom_aabb = envelope
	var data := {"animated": animated, "poses": poses, "envelope": envelope}
	_cache[key] = data
	return data
