extends SceneTree
## Compara la consulta nativa con el antiguo bucle por caras, sin render ni IA.


func _initialize() -> void:
	call_deferred(&"run")


func legacy_hit(faces: PackedVector3Array, from: Vector3, to: Vector3) -> bool:
	for i in range(0, faces.size(), 3):
		if Geometry3D.segment_intersects_triangle(from, to, faces[i], faces[i + 1], faces[i + 2]) != null:
			return true
	return false


func run() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 64
	mesh.rings = 32
	var faces := mesh.get_faces()
	var triangles := mesh.generate_triangle_mesh()
	var expected: Array[bool] = []
	var origins: Array[Vector3] = []
	var ends: Array[Vector3] = []
	for row in 16:
		for column in 16:
			origins.append(Vector3(-2, (row - 7.5) / 7.5, (column - 7.5) / 7.5))
			ends.append(Vector3(2, (row - 7.5) / 7.5, (column - 7.5) / 7.5))
	var started := Time.get_ticks_usec()
	for i in origins.size():
		expected.append(legacy_hit(faces, origins[i], ends[i]))
	var legacy_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var actual: Array[bool] = []
	for i in origins.size():
		actual.append(not triangles.intersect_segment(origins[i], ends[i]).is_empty())
	var native_us := Time.get_ticks_usec() - started
	if actual != expected:
		push_error("La consulta optimizada no coincide con las intersecciones anteriores")
		quit(1)
		return
	# Un hueco dentro del AABB no debe convertirse en una pared maciza.
	var frame_faces := PackedVector3Array([
		Vector3(-2, -1, 0), Vector3(-0.6, -1, 0), Vector3(-0.6, 1, 0),
		Vector3(-2, -1, 0), Vector3(-0.6, 1, 0), Vector3(-2, 1, 0),
		Vector3(0.6, -1, 0), Vector3(2, -1, 0), Vector3(2, 1, 0),
		Vector3(0.6, -1, 0), Vector3(2, 1, 0), Vector3(0.6, 1, 0)])
	var frame_mesh := TriangleMesh.new()
	frame_mesh.create_from_faces(frame_faces)
	if not frame_mesh.intersect_segment(Vector3(0, 0, 1), Vector3(0, 0, -1)).is_empty() or frame_mesh.intersect_segment(Vector3(1, 0, 1), Vector3(1, 0, -1)).is_empty():
		push_error("El árbol de triángulos no respeta la abertura del marco")
		quit(1)
		return
	print("TRIÁNGULOS OBSERVADOR: %d rayos equivalentes, %d caras; bucle=%.3f ms nativo=%.3f ms; hueco conservado" % [origins.size(), faces.size() / 3, legacy_us / 1000.0, native_us / 1000.0])
	quit(0)
