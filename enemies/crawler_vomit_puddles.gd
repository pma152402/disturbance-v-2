extends Node3D
## Bounded opaque wet patches. Grow only on verified static support; age at 4 Hz.
const CAPACITY := 32
const LIFETIME := 45.0
const MAX_RADIUS := 0.72
var batch: MultiMeshInstance3D
var actor: CharacterBody3D
var timer: Timer
var positions: Array[Vector3] = []
var normals: Array[Vector3] = []
var radii: Array[float] = []
var ages: Array[float] = []
var supports: Array[int] = []
var deposited_hits := 0

func setup(brain: CharacterBody3D) -> void:
	actor = brain
	set_process(false)
	set_physics_process(false)
	batch = MultiMeshInstance3D.new()
	batch.name = "PooledPuddles"
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 2
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.13
	mesh.material = material
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
	if normal.y < 0.65 or not collider is StaticBody3D:
		return
	var support_id := collider.get_instance_id()
	var index := -1
	for i in positions.size():
		if supports[i] == support_id and absf((point - positions[i]).dot(normals[i])) < 0.08 and positions[i].distance_to(point) < 0.46 and normals[i].dot(normal) > 0.96:
			index = i
			break
	if index >= 0:
		var proposed := minf(MAX_RADIUS, radii[index] + 0.055)
		if _supported(positions[index], normals[index], proposed, support_id):
			radii[index] = proposed
		ages[index] = 0.0
	else:
		var radius := 0.16
		if not _supported(point, normal, radius, support_id):
			return
		if positions.size() < CAPACITY:
			index = positions.size()
			positions.append(point)
			normals.append(normal)
			radii.append(radius)
			ages.append(0.0)
			supports.append(support_id)
		else:
			index = ages.find(ages.max())
			positions[index] = point
			normals[index] = normal
			radii[index] = radius
			ages[index] = 0.0
			supports[index] = support_id
	deposited_hits += 1
	_draw(index)
	batch.show()
	if timer.is_stopped(): timer.start()

func _supported(point: Vector3, normal: Vector3, radius: float, support_id: int) -> bool:
	var x := Vector3.FORWARD.cross(normal).normalized()
	var z := x.cross(normal).normalized()
	for direction in [x, -x, z, -z, (x + z).normalized(), (x - z).normalized(), (-x + z).normalized(), (-x - z).normalized()]:
		var edge: Vector3 = point + direction * radius
		var query := PhysicsRayQueryParameters3D.create(edge + normal * 0.15, edge - normal * 0.12, actor.collision_mask, [actor.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider.get_instance_id() != support_id or hit.normal.dot(normal) < 0.96:
			return false
	return true

func _draw(index: int) -> void:
	var normal := normals[index]
	var x := Vector3.FORWARD.cross(normal).normalized()
	var basis := Basis(x, normal, x.cross(normal).normalized())
	var fade := clampf((LIFETIME - ages[index]) / 6.0, 0.0, 1.0)
	var radius := radii[index] * fade
	# Three overlapping, slightly raised lobes form an irregular wet footprint.
	for lobe in 3:
		var shift := Vector3(-0.26, 0, 0.2) if lobe == 1 else Vector3(0.29, 0, -0.18) if lobe == 2 else Vector3.ZERO
		var dimensions := Vector3(radius * (0.59 if lobe else 0.87), 0.005 * fade, radius * (0.43 if lobe else 0.73))
		var center := positions[index] + normal * (0.007 + lobe * 0.002) + basis * shift * radius
		batch.multimesh.set_instance_transform(index * 3 + lobe, Transform3D(basis.scaled_local(dimensions), center))

func _age_puddles() -> void:
	var active := false
	for i in ages.size():
		if ages[i] >= LIFETIME: continue
		ages[i] += timer.wait_time
		active = active or ages[i] < LIFETIME
		if ages[i] > LIFETIME - 6.0: _draw(i)
	if not active:
		timer.stop()
		batch.hide()
