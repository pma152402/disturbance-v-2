extends Node3D
## Bounded opaque stains on floors, walls, ceilings and props. Age at 4 Hz;
## only stains attached to moving physics bodies need transform updates.
const CAPACITY := 48
const LIFETIME := 45.0
const MAX_RADIUS := 0.95
var batch: MultiMeshInstance3D
var actor: CharacterBody3D
var timer: Timer
var positions: Array[Vector3] = []
var normals: Array[Vector3] = []
var radii: Array[float] = []
var ages: Array[float] = []
var supports: Array[int] = []
var local_positions: Array[Vector3] = []
var local_normals: Array[Vector3] = []
var support_transforms: Array[Transform3D] = []
var moving: Array[bool] = []
var deposited_hits := 0

func setup(brain: CharacterBody3D) -> void:
	actor = brain
	set_process(false)
	set_physics_process(false)
	batch = MultiMeshInstance3D.new()
	batch.name = "PooledPuddles"
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Flat normals avoid the inflated-sphere shading of extremely compressed
	# MultiMesh instances. One small irregular disk is reused by every lobe.
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var mesh_normals := PackedVector3Array()
	for i in 16:
		var a := TAU * i / 16.0
		var b := TAU * (i + 1) / 16.0
		vertices.append(Vector3.ZERO)
		vertices.append(Vector3(cos(a), 0, sin(a)) * (0.91 + 0.08 * sin(a * 5.0 + 1.3)))
		vertices.append(Vector3(cos(b), 0, sin(b)) * (0.91 + 0.08 * sin(b * 5.0 + 1.3)))
		for j in 3: mesh_normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = mesh_normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.36
	mesh.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = CAPACITY * 3
	batch.multimesh = multimesh
	add_child(batch)
	for i in CAPACITY * 3:
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		multimesh.set_instance_color(i, Color(0.13, 0.25, 0.018) if i % 3 == 0 else Color(0.19, 0.31, 0.02))
	timer = Timer.new()
	timer.wait_time = 0.25
	timer.timeout.connect(_age_puddles)
	add_child(timer)
	batch.hide()

func deposit(point: Vector3, normal: Vector3, collider: Object) -> void:
	if not (collider is StaticBody3D or collider is RigidBody3D) or normal.length_squared() < 0.9:
		return
	normal = normal.normalized()
	var support_id := collider.get_instance_id()
	var index := -1
	for i in positions.size():
		if supports[i] == support_id and absf((point - positions[i]).dot(normals[i])) < 0.08 and positions[i].distance_to(point) < 0.46 and normals[i].dot(normal) > 0.96:
			index = i
			break
	if index >= 0:
		var proposed := minf(MAX_RADIUS if normal.y > 0.65 else 0.64, radii[index] + 0.085)
		if _supported(positions[index], normals[index], proposed, support_id):
			radii[index] = proposed
		ages[index] = 0.0
	else:
		var radius := 0.22
		# Narrow edges and small props retain a small spot instead of rejecting
		# the impact altogether. Every accepted footprint still has real support.
		while radius > 0.025 and not _supported(point, normal, radius, support_id):
			radius *= 0.5
		if not _supported(point, normal, radius, support_id):
			return
		if positions.size() < CAPACITY:
			index = positions.size()
			positions.append(point)
			normals.append(normal)
			radii.append(radius)
			ages.append(0.0)
			supports.append(support_id)
			local_positions.append(Vector3.ZERO)
			local_normals.append(Vector3.ZERO)
			support_transforms.append(Transform3D.IDENTITY)
			moving.append(false)
		else:
			index = ages.find(ages.max())
			positions[index] = point
			normals[index] = normal
			radii[index] = radius
			ages[index] = 0.0
			supports[index] = support_id
		var support := collider as Node3D
		local_positions[index] = support.to_local(point)
		local_normals[index] = (support.global_basis.transposed() * normal).normalized()
		support_transforms[index] = support.global_transform
		moving[index] = collider is AnimatableBody3D or collider is RigidBody3D
	deposited_hits += 1
	_draw(index)
	batch.show()
	if timer.is_stopped(): timer.start()
	if moving[index]: set_physics_process(true)

func _surface_frame(normal: Vector3) -> Basis:
	# Project gravity onto vertical surfaces so elongated marks run downward.
	# This remains valid for either Z-facing wall, unlike FORWARD.cross(normal).
	var z := Vector3.DOWN.slide(normal)
	if z.length_squared() < 0.01: z = Vector3.BACK.slide(normal)
	z = z.normalized()
	var x := normal.cross(z).normalized()
	return Basis(x, normal, x.cross(normal).normalized())

func _supported(point: Vector3, normal: Vector3, radius: float, support_id: int) -> bool:
	var frame := _surface_frame(normal)
	var x := frame.x
	var z := frame.z
	for direction in [x, -x, z, -z, (x + z).normalized(), (x - z).normalized(), (-x + z).normalized(), (-x - z).normalized()]:
		var edge: Vector3 = point + direction * radius
		var query := PhysicsRayQueryParameters3D.create(edge + normal * 0.15, edge - normal * 0.12, actor.collision_mask, [actor.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider.get_instance_id() != support_id or hit.normal.dot(normal) < 0.96:
			return false
	return true

func _draw(index: int) -> void:
	var normal := normals[index]
	var basis := _surface_frame(normal)
	var fade := clampf((LIFETIME - ages[index]) / 6.0, 0.0, 1.0)
	var radius := radii[index] * fade
	# Three overlapping, slightly raised lobes form an irregular wet footprint.
	for lobe in 3:
		var shift := Vector3(-0.26, 0, 0.2) if lobe == 1 else Vector3(0.29, 0, -0.18) if lobe == 2 else Vector3.ZERO
		var dimensions := Vector3(radius * (0.59 if lobe else 0.87), 0.005 * fade, radius * (0.43 if lobe else 0.73))
		if absf(normal.y) < 0.65:
			dimensions.x *= 0.72
			dimensions.z *= 1.1
		var center := positions[index] + normal * (0.007 + lobe * 0.002) + basis * shift * radius
		batch.multimesh.set_instance_transform(index * 3 + lobe, Transform3D(basis.scaled_local(dimensions), center))

func _sync_support(index: int) -> bool:
	var support := instance_from_id(supports[index]) as Node3D
	if not is_instance_valid(support) or not support.is_inside_tree():
		ages[index] = LIFETIME
		_draw(index)
		return false
	if not support.global_transform.is_equal_approx(support_transforms[index]):
		positions[index] = support.to_global(local_positions[index])
		normals[index] = (support.global_basis.inverse().transposed() * local_normals[index]).normalized()
		support_transforms[index] = support.global_transform
		_draw(index)
	return true

func _physics_process(_delta: float) -> void:
	var active := false
	for i in moving.size():
		if moving[i] and ages[i] < LIFETIME:
			active = _sync_support(i) or active
	if not active: set_physics_process(false)

func _age_puddles() -> void:
	var active := false
	for i in ages.size():
		if ages[i] >= LIFETIME: continue
		if not _sync_support(i): continue
		ages[i] += timer.wait_time
		active = active or ages[i] < LIFETIME
		if ages[i] > LIFETIME - 6.0: _draw(i)
	if not active:
		timer.stop()
		batch.hide()
		set_physics_process(false)
