extends SceneTree
## Compara geometría y materiales contra los generadores previos a la caché.
## Ejecutar con renderizador real: el dummy puede descartar datos de ArrayMesh.
const Surface := preload("res://enemies/crawler_surface_mesh.gd")
const SurfaceReference := preload("res://tools/fixtures/crawler_surface_mesh_reference.gd")
const Arm := preload("res://enemies/granny_continuous_arm.gd")
const ArmReference := preload("res://tools/fixtures/granny_continuous_arm_reference.gd")
const SAMPLE_COUNT := 120
const BENCHMARK_PASSES := 4
var failures := 0
var comparisons := 0
var _world: Node3D
var _skin := StandardMaterial3D.new()
var _cloth := StandardMaterial3D.new()

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		if failures <= 12:
			push_error(message)

func _compare(actual: MeshInstance3D, reference: MeshInstance3D, label: String) -> void:
	var actual_mesh := actual.mesh as ArrayMesh
	var expected_mesh := reference.mesh as ArrayMesh
	_check(actual_mesh.get_surface_count() == expected_mesh.get_surface_count(), label + ": cantidad de superficies")
	if actual_mesh.get_surface_count() != expected_mesh.get_surface_count():
		return
	_check(actual_mesh.get_aabb() == expected_mesh.get_aabb(), label + ": límites geométricos")
	for surface_index in actual_mesh.get_surface_count():
		var actual_arrays := actual_mesh.surface_get_arrays(surface_index)
		var expected_arrays := expected_mesh.surface_get_arrays(surface_index)
		_check(not actual_arrays.is_empty() and not expected_arrays.is_empty(), label + ": usar renderizador real para recuperar geometría")
		if actual_arrays.is_empty() or expected_arrays.is_empty():
			return
		for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
			_check(actual_arrays[slot].to_byte_array() == expected_arrays[slot].to_byte_array(), "%s: bytes distintos en superficie %d, canal %d" % [label, surface_index, slot])
		_check(actual.get_active_material(surface_index) == reference.get_active_material(surface_index), label + ": material")
	comparisons += 1

func _centers(rings: int, phase: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	var rotation := Basis(Vector3(1.0, 0.0, 1.0).normalized(), phase * 0.51)
	for ring in rings:
		var t := float(ring) / (rings - 1)
		result.append(rotation * Vector3(sin(phase + t * 1.3) * 0.18, t * 1.4, cos(phase * 0.73 + t) * 0.21))
	return result

func _widths(rings: int, scale_factor: float = 1.0) -> PackedVector2Array:
	var result := PackedVector2Array()
	for ring in rings:
		result.append(Vector2(0.09 + ring * 0.035, 0.08 + ring * 0.026) * scale_factor)
	return result

func _validate_surfaces() -> void:
	for rings in [3, 5, 6, 8, 9]:
		var actual := Surface.new()
		var reference := SurfaceReference.new()
		_world.add_child(actual)
		_world.add_child(reference)
		for frame in SAMPLE_COUNT:
			var phase := float(frame) * 0.09
			var centers := _centers(rings, phase)
			var widths := _widths(rings, 0.9 if frame >= 60 else 1.0)
			# Alternar busto, ancho y material comprueba que la caché se invalida.
			var depth := 0.0 if frame < 20 or frame >= 100 else 0.24 if frame < 80 else 0.31
			var material := _skin if frame < 70 else _cloth
			actual.bust_depth = depth
			reference.bust_depth = depth
			actual.build(centers, widths, material)
			reference.build(centers, widths, material)
			_compare(actual, reference, "piel %d anillos, pose %d" % [rings, frame])
		actual.free()
		reference.free()
	# Si cambia la topología, contrastar con una referencia recién creada.
	var changing := Surface.new()
	_world.add_child(changing)
	for rings in [6, 3, 9, 6]:
		var reference := SurfaceReference.new()
		_world.add_child(reference)
		changing.bust_depth = 0.24
		reference.bust_depth = 0.24
		changing.build(_centers(rings, 0.6), _widths(rings), _cloth)
		reference.build(_centers(rings, 0.6), _widths(rings), _cloth)
		_compare(changing, reference, "cambio de topología a %d anillos" % rings)
		reference.free()
	changing.free()
	# El mismo buffer puede cambiar in situ: comparar con una instantánea,
	# no con otro alias del array del llamante, es parte de la invalidación.
	var mutable_surface := Surface.new()
	var mutable_reference := SurfaceReference.new()
	_world.add_child(mutable_surface)
	_world.add_child(mutable_reference)
	mutable_surface.bust_depth = 0.24
	mutable_reference.bust_depth = 0.24
	var mutable_widths := _widths(6)
	var centers := _centers(6, 0.6)
	mutable_surface.build(centers, mutable_widths, _cloth)
	mutable_widths[3] = mutable_widths[3] * Vector2(1.25, 0.8)
	mutable_surface.build(centers, mutable_widths, _cloth)
	mutable_reference.build(centers, mutable_widths, _cloth)
	_compare(mutable_surface, mutable_reference, "cambio de radios en el mismo buffer")
	mutable_reference.free()
	var preserved_widths := mutable_widths.duplicate()
	mutable_surface.build(_centers(9, 0.6), _widths(9), _cloth)
	_check(mutable_widths == preserved_widths, "Cambiar topología no debe vaciar los radios de la llamada anterior")
	mutable_surface.free()

func _make_arm_rig() -> Array[Node3D]:
	var rig := Node3D.new()
	_world.add_child(rig)
	var shoulder := Node3D.new()
	var elbow := Node3D.new()
	var wrist := Node3D.new()
	rig.add_child(shoulder)
	shoulder.add_child(elbow)
	elbow.add_child(wrist)
	shoulder.position = Vector3(0.6, 1.6, 0)
	elbow.position = Vector3(0.1, -0.7, 0.2)
	wrist.position = Vector3(0.05, -0.65, 0.1)
	var palm := MeshInstance3D.new()
	palm.name = "TestPalm"
	palm.mesh = BoxMesh.new()
	palm.scale = Vector3(0.3, 0.1, 0.4)
	wrist.add_child(palm)
	var torso := MeshInstance3D.new()
	torso.mesh = BoxMesh.new()
	torso.material_override = _cloth
	rig.add_child(torso)
	return [rig, shoulder, elbow, wrist, torso, palm]

func _validate_arms() -> void:
	var nodes := _make_arm_rig()
	var actual := Arm.new()
	var reference := ArmReference.new()
	nodes[0].add_child(actual)
	nodes[0].add_child(reference)
	actual.configure(nodes[1], nodes[2], nodes[3], nodes[4] as MeshInstance3D, _skin)
	reference.configure(nodes[1], nodes[2], nodes[3], nodes[4] as MeshInstance3D, _skin)
	for frame in SAMPLE_COUNT:
		var phase := float(frame) * 0.08
		nodes[0].rotation = Vector3(sin(phase) * 0.3, phase * 0.2, cos(phase) * 0.4)
		nodes[1].rotation = Vector3(sin(phase) * 0.8, cos(phase) * 0.4, sin(phase * 0.6) * 0.3)
		nodes[2].rotation = Vector3(sin(phase * 1.3) * 0.5, 0, 0)
		nodes[3].rotation = Vector3(0, phase * 0.3, sin(phase) * 0.2)
		var thickness := 1.0 if frame < 30 else 0.82 if frame < 90 else 0.65
		actual.thickness_scale = thickness
		reference.thickness_scale = thickness
		actual.palm = null if frame >= 60 else nodes[5] as MeshInstance3D
		reference.palm = null if frame >= 60 else nodes[5] as MeshInstance3D
		actual.mount.z = sin(phase) * 0.05
		reference.mount.z = actual.mount.z
		actual.update_surface()
		reference.update_surface()
		_compare(actual, reference, "brazo, pose %d" % frame)
		actual.update_surface()
		reference.update_surface()
		_compare(actual, reference, "brazo sin cambio, pose %d" % frame)
	nodes[0].free()

func _benchmark_surfaces() -> Dictionary:
	var actual := Surface.new()
	var reference := SurfaceReference.new()
	actual.bust_depth = 0.24
	reference.bust_depth = 0.24
	_world.add_child(actual)
	_world.add_child(reference)
	var widths := _widths(6)
	var poses: Array[PackedVector3Array] = []
	for frame in SAMPLE_COUNT:
		poses.append(_centers(6, frame * 0.07))
	var optimized_times: Array[float] = []
	var reference_times: Array[float] = []
	for pass_index in BENCHMARK_PASSES:
		var order := [actual, reference] if pass_index % 2 == 0 else [reference, actual]
		for candidate in order:
			var started := Time.get_ticks_usec()
			for pose in poses:
				candidate.build(pose, widths, _cloth)
			var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0 / SAMPLE_COUNT
			if candidate == actual:
				optimized_times.append(elapsed_ms)
			else:
				reference_times.append(elapsed_ms)
	actual.free()
	reference.free()
	return {"reference_ms_per_build": reference_times, "optimized_ms_per_build": optimized_times}

func _benchmark_arms() -> Dictionary:
	var nodes := _make_arm_rig()
	var actual := Arm.new()
	var reference := ArmReference.new()
	nodes[0].add_child(actual)
	nodes[0].add_child(reference)
	actual.configure(nodes[1], nodes[2], nodes[3], nodes[4] as MeshInstance3D, _skin)
	reference.configure(nodes[1], nodes[2], nodes[3], nodes[4] as MeshInstance3D, _skin)
	var optimized_times: Array[float] = []
	var reference_times: Array[float] = []
	for pass_index in BENCHMARK_PASSES:
		var order := [actual, reference] if pass_index % 2 == 0 else [reference, actual]
		for candidate in order:
			var started := Time.get_ticks_usec()
			for frame in SAMPLE_COUNT:
				nodes[1].rotation.x = sin(frame * 0.07) * 0.5
				nodes[2].rotation.x = cos(frame * 0.07) * 0.5
				candidate.update_surface()
			var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0 / SAMPLE_COUNT
			if candidate == actual:
				optimized_times.append(elapsed_ms)
			else:
				reference_times.append(elapsed_ms)
	nodes[0].free()
	return {"reference_ms_per_update": reference_times, "optimized_ms_per_update": optimized_times}

func _run() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_validate_surfaces()
	_validate_arms()
	var result := {"comparisons": comparisons, "failures": failures, "surface": _benchmark_surfaces(), "arm": _benchmark_arms()}
	print("PROCEDURAL_MESH_CACHE ", JSON.stringify(result))
	_world.free()
	quit(1 if failures else 0)
