extends Node3D
## Fixed airborne pool plus bounded wet patches; no lights or rigid bodies.
const CAPACITY := 80
const JET_CAPACITY := 56
const WIDTH_MULTIPLIER := 3.0
const JET_SPEED := 14.5
const JET_RATE := 86.0
const DRIP_RATE := 11.0
var attack: Node3D
var head: Node3D
var mouth: Marker3D
var batch: MultiMeshInstance3D
var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _ages := PackedFloat32Array()
var _sizes := PackedFloat32Array()
var _lifetimes := PackedFloat32Array()
var _splash_normals := PackedVector3Array()
var _can_damage := PackedByteArray()
var _chunks := PackedByteArray()
var _cursor := 0
var _emission := 0.0
var _emitted := 0
var alive_count := 0
var puddles: Node3D
var _clock := 0.0
var _splash_ready := 0.0
var _fall_ready := 0.0
var _puddle_ready := 0.0
var _splash_cursor := 0
var _fall_cursor := 0

func setup(controller: Node3D, head_node: Node3D) -> void:
	attack = controller
	head = head_node
	set_as_top_level(true)
	global_transform = Transform3D.IDENTITY
	process_physics_priority = 2 # The articulated head updates at priority 1.
	mouth = Marker3D.new()
	mouth.name = "VomitMouth"
	var lower := head.get_node("LowerTeeth") as MeshInstance3D
	var upper := head.get_node("UpperTeeth") as MeshInstance3D
	var lower_center := lower.transform * lower.get_aabb().get_center()
	var upper_center := upper.transform * upper.get_aabb().get_center()
	mouth.position = (lower_center + upper_center) * 0.5
	head.add_child(mouth)
	batch = MultiMeshInstance3D.new()
	batch.name = "PooledVomit"
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 2
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.42
	mesh.material = material
	multimesh.mesh = mesh
	multimesh.instance_count = CAPACITY
	batch.multimesh = multimesh
	add_child(batch)
	_positions.resize(CAPACITY)
	_velocities.resize(CAPACITY)
	_ages.resize(CAPACITY)
	_sizes.resize(CAPACITY)
	_lifetimes.resize(CAPACITY)
	_splash_normals.resize(CAPACITY)
	_can_damage.resize(CAPACITY)
	_chunks.resize(CAPACITY)
	puddles = preload("res://enemies/crawler_vomit_puddles.gd").new()
	puddles.name = "VomitPuddles"
	add_child(puddles)
	puddles.setup(attack.brain)
	clear()

func mouth_position() -> Vector3:
	return mouth.global_position

func wake() -> void:
	_emission = 0.0
	set_physics_process(true)
	batch.show()

func clear() -> void:
	_lifetimes.fill(0.0)
	for i in CAPACITY:
		batch.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	alive_count = 0
	batch.hide()
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	_clock += delta
	var spray: bool = attack.phase == attack.Phase.SPRAY
	var dripping: bool = attack.phase == attack.Phase.DRIP
	if spray or dripping:
		_emission += delta * (JET_RATE if spray else DRIP_RATE)
		var origin := mouth_position()
		var muzzle_hit: Dictionary = attack.brain.surface._ray(attack.brain.surface._center(), origin)
		while _emission >= 1.0:
			_emission -= 1.0
			if muzzle_hit.is_empty():
				_emit(origin, spray)
	alive_count = 0
	for i in CAPACITY:
		if _lifetimes[i] <= 0.0:
			continue
		_ages[i] += delta
		if _ages[i] >= _lifetimes[i]:
			if i < JET_CAPACITY and _can_damage[i] != 0 and _splash_normals[i] == Vector3.ZERO:
				_spawn_fall(_positions[i], _velocities[i] * 0.08)
			_lifetimes[i] = 0.0
			batch.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		if _splash_normals[i] == Vector3.ZERO:
			var next := _positions[i] + _velocities[i] * delta + Vector3.DOWN * 4.9 * delta * delta
			var query := PhysicsRayQueryParameters3D.create(_positions[i], next, attack.brain.collision_mask, [attack.brain.get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				if _can_damage[i] != 0:
					attack.contact_player(hit.collider)
				_impact(hit.position, hit.normal, hit.collider, i)
				_positions[i] = hit.position + hit.normal * 0.009
				_splash_normals[i] = hit.normal
				_velocities[i] = Vector3.ZERO
				_lifetimes[i] = _ages[i] + randf_range(0.12, 0.28)
			else:
				_positions[i] = next
				_velocities[i] += Vector3.DOWN * 9.8 * delta
		_draw_slot(i)
		alive_count += 1
	if not spray and not dripping and not attack.stationary() and alive_count == 0:
		batch.hide()
		set_physics_process(false)

func _emit(origin: Vector3, spray: bool) -> void:
	var slot := _cursor
	_cursor = (_cursor + 1) % JET_CAPACITY
	_emitted += 1
	var chunk := spray and _emitted % 5 == 0
	_chunks[slot] = 1 if chunk else 0
	_can_damage[slot] = 1 if spray else 0
	_positions[slot] = origin
	_ages[slot] = 0.0
	_lifetimes[slot] = attack.MAX_RANGE / JET_SPEED if spray else 1.6
	_splash_normals[slot] = Vector3.ZERO
	_sizes[slot] = randf_range(0.026, 0.042) if chunk else randf_range(0.027, 0.045) if spray else randf_range(0.016, 0.026)
	if spray and not chunk: _sizes[slot] *= WIDTH_MULTIPLIER
	# World gravity is independent of the attachment normal, including drips
	# from an upside-down mouth. Only the initial jet follows the actual head.
	var forward := head.global_basis.z.normalized()
	var jitter := Vector3(randf_range(-0.23, 0.23), randf_range(-0.23, 0.23), randf_range(-0.23, 0.23))
	_velocities[slot] = forward * JET_SPEED + jitter if spray else Vector3.DOWN * 0.18 + forward * 0.08
	var color := Color(0.31, 0.62, 0.025) * randf_range(0.85, 1.12)
	if chunk:
		color = Color(0.93, 0.27, 0.025) if _emitted % 10 == 0 else Color(0.025, 0.13, 0.012)
	color.a = 1.0
	batch.multimesh.set_instance_color(slot, color)

func _secondary(slot: int, point: Vector3, velocity_: Vector3, life: float, size_: float) -> void:
	_positions[slot] = point
	_velocities[slot] = velocity_
	_ages[slot] = 0.0
	_lifetimes[slot] = life
	_sizes[slot] = size_
	_splash_normals[slot] = Vector3.ZERO
	_can_damage[slot] = 0
	_chunks[slot] = 0
	batch.multimesh.set_instance_color(slot, Color(0.27, 0.48, 0.025))

func _spawn_fall(point: Vector3, initial: Vector3) -> void:
	if _clock < _fall_ready: return
	_fall_ready = _clock + 0.22
	var slot := 64 + _fall_cursor
	_fall_cursor = (_fall_cursor + 1) % 16
	_secondary(slot, point, initial + Vector3.DOWN * 0.4, 3.0, 0.047)

func _impact(point: Vector3, normal: Vector3, collider: Object, source: int) -> void:
	if _clock >= _puddle_ready and normal.y > 0.65 and collider is StaticBody3D:
		_puddle_ready = _clock + 0.08
		puddles.deposit(point, normal, collider)
	if source >= JET_CAPACITY: return
	if normal.y < 0.65 or not collider is StaticBody3D:
		_spawn_fall(point + normal * 0.04, normal * 0.35)
	if _clock < _splash_ready: return
	_splash_ready = _clock + 0.1
	for side in [-1.0, 1.0]:
		var slot := JET_CAPACITY + _splash_cursor
		_splash_cursor = (_splash_cursor + 1) % 8
		var tangent := Vector3.RIGHT if absf(normal.x) < 0.8 else Vector3.BACK
		var velocity_: Vector3 = normal * randf_range(1.0, 1.9) + Vector3.UP * 0.8 + tangent * side * randf_range(0.5, 1.3)
		_secondary(slot, point + normal * 0.035, velocity_, 0.42, randf_range(0.035, 0.065))

func _draw_slot(slot: int) -> void:
	var splash := _splash_normals[slot] != Vector3.ZERO
	var direction := _splash_normals[slot] if splash else _velocities[slot].normalized()
	var up := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x := up.cross(direction).normalized()
	var basis := Basis(x, direction.cross(x).normalized(), direction)
	var size := _sizes[slot]
	var stretch := size if _chunks[slot] else clampf(_velocities[slot].length() * 0.014, size, 0.23)
	var scale_ := Vector3(size, size, stretch)
	if splash:
		var fade := clampf((_lifetimes[slot] - _ages[slot]) / 0.12, 0.0, 1.0)
		scale_ = Vector3(size * 1.8, size * 1.8, 0.008) * fade
	batch.multimesh.set_instance_transform(slot, Transform3D(basis.scaled_local(scale_), _positions[slot]))
