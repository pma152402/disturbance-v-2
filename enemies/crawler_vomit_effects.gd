extends Node3D
## Continuous pressure jet plus a fixed pool of small chunks/drips/splashes.
const CAPACITY := 80
const JET_CAPACITY := 56
const THROAT_RADIUS := 0.105
# The former balls + outward spread covered about 1.8 m at their far end.
# A 1.95 m joined cross-section adds a little width across twice the distance.
const END_RADIUS := 1.95
const JET_SPEED := 14.5
const JET_RATE := 18.0 # Only the small orange/dark chunks need particles now.
const DRIP_RATE := 11.0
const FLIGHT_LIMIT := 1.6
const STREAM_STEP := 1.0 / 30.0
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
var _player_collision: CollisionShape3D
var stream: MeshInstance3D
var _stream_age := 0.0
var _stream_tail := 0.0
var _stream_origin := Vector3.ZERO
var _stream_velocity := Vector3.ZERO
var _stream_stop_time := FLIGHT_LIMIT
var _stream_points := PackedVector3Array()
var _stream_radii := PackedFloat32Array()
var _stream_distances := PackedFloat32Array()

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
	mesh.radial_segments = 10
	mesh.rings = 3
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
	if is_instance_valid(attack.brain._player):
		_player_collision = attack.brain._player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	puddles = preload("res://enemies/crawler_vomit_puddles.gd").new()
	puddles.name = "VomitPuddles"
	add_child(puddles)
	puddles.setup(attack.brain)
	stream = preload("res://enemies/crawler_vomit_stream.gd").new()
	stream.name = "ContinuousPressureJet"
	add_child(stream)
	clear()

func mouth_position() -> Vector3:
	return mouth.global_position

func wake() -> void:
	_emission = 0.0
	_stream_age = 0.0
	_stream_tail = 0.0
	_stream_stop_time = FLIGHT_LIMIT
	set_physics_process(true)
	batch.show()

func clear() -> void:
	_lifetimes.fill(0.0)
	for i in CAPACITY:
		batch.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	alive_count = 0
	batch.hide()
	_stream_age = 0.0
	_stream_tail = 0.0
	_stream_points.clear()
	if stream != null:
		stream.ring_count = 0
		stream.hide()
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	_clock += delta
	var spray: bool = attack.phase == attack.Phase.SPRAY
	var dripping: bool = attack.phase == attack.Phase.DRIP
	_update_stream(delta, spray)
	if spray or dripping:
		_emission += delta * (JET_RATE if spray else DRIP_RATE)
		var origin := mouth_position()
		var muzzle_clear: bool = attack.mouth_is_clear()
		while _emission >= 1.0:
			_emission -= 1.0
			if muzzle_clear:
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
			if _can_damage[i] != 0 and next.distance_to(_stream_origin) > attack.MAX_RANGE:
				_spawn_fall(_positions[i], _velocities[i] * 0.08)
				_lifetimes[i] = 0.0
				batch.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
				continue
			var radius := _jet_radius(i)
			var hit := _sweep_slot(i, next)
			if _can_damage[i] != 0:
				_touch_wide_stream(_positions[i], hit.position if not hit.is_empty() else next, radius)
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
	if not spray and not dripping and not attack.stationary() and alive_count == 0 and not stream.visible:
		batch.hide()
		set_physics_process(false)

func _emit(origin: Vector3, spray: bool) -> void:
	var slot := _cursor
	_cursor = (_cursor + 1) % JET_CAPACITY
	_emitted += 1
	var chunk := spray
	_chunks[slot] = 1 if chunk else 0
	_can_damage[slot] = 1 if spray else 0
	_positions[slot] = origin
	_ages[slot] = 0.0
	_lifetimes[slot] = FLIGHT_LIMIT
	_splash_normals[slot] = Vector3.ZERO
	_sizes[slot] = randf_range(0.026, 0.042) if chunk else randf_range(0.016, 0.026)
	# World gravity is independent of the attachment normal, including drips
	# from an upside-down mouth. Only the initial jet follows the actual head.
	var forward := head.global_basis.z.normalized()
	var jitter := Vector3(randf_range(-0.23, 0.23), randf_range(-0.23, 0.23), randf_range(-0.23, 0.23))
	if spray:
		# Tiny inclusions travel within the liquid surface; they never supply
		# its silhouette. The joined stream performs the broad contact checks.
		var angle := _emitted * 2.399963
		var spread := randf_range(0.035, 0.095)
		var sideways := head.global_basis.x.normalized() * cos(angle) + head.global_basis.y.normalized() * sin(angle)
		_velocities[slot] = (forward + sideways * spread).normalized() * JET_SPEED + jitter
	else:
		_velocities[slot] = Vector3.DOWN * 0.18 + forward * 0.08
	var color := Color(0.31, 0.62, 0.025) * randf_range(0.85, 1.12)
	if chunk:
		color = Color(0.93, 0.27, 0.025) if _emitted % 2 == 0 else Color(0.025, 0.13, 0.012)
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
	_fall_ready = _clock + 0.14
	var slot := 64 + _fall_cursor
	_fall_cursor = (_fall_cursor + 1) % 16
	_secondary(slot, point, initial + Vector3.DOWN * 0.4, 3.0, 0.047)

func _impact(point: Vector3, normal: Vector3, collider: Object, source: int, stream_radius: float = -1.0) -> void:
	if _clock >= _puddle_ready and (collider is StaticBody3D or collider is RigidBody3D):
		_puddle_ready = _clock + 0.05
		puddles.deposit(point, normal, collider)
		var footprint := stream_radius if stream_radius > 0.0 else _jet_radius(source)
		if source < JET_CAPACITY and footprint > 0.22:
			var frame: Basis = puddles._surface_frame(normal)
			var sideways := (frame.x * cos(_clock * 4.7) + frame.z * sin(_clock * 4.7)) * footprint * 0.95
			puddles.deposit(point + sideways, normal, collider)
			puddles.deposit(point - sideways, normal, collider)
	if source >= JET_CAPACITY: return
	if normal.y < 0.65 or not collider is StaticBody3D:
		_spawn_fall(point + normal * 0.04, normal * 0.35)
	if _clock < _splash_ready: return
	_splash_ready = _clock + 0.065
	for side in [-1.0, 1.0]:
		var slot := JET_CAPACITY + _splash_cursor
		_splash_cursor = (_splash_cursor + 1) % 8
		var tangent := Vector3.RIGHT if absf(normal.x) < 0.8 else Vector3.BACK
		var velocity_: Vector3 = normal * randf_range(1.2, 2.4) + Vector3.UP * 0.9 + tangent * side * randf_range(0.9, 2.0)
		_secondary(slot, point + normal * 0.035, velocity_, 0.48, randf_range(0.045, 0.085))

func _jet_radius(slot: int) -> float:
	return _sizes[slot]

func _stream_radius(distance_: float) -> float:
	return lerpf(THROAT_RADIUS, END_RADIUS, clampf(distance_ / attack.MAX_RANGE, 0.0, 1.0))

func _stream_surface_contact(hit: Dictionary, radius: float) -> void:
	# Radial clipping both stops the surface penetrating walls and leaves wet
	# patches wherever the wide edge brushes scenery, not only at its centre.
	if _clock >= _puddle_ready:
		_impact(hit.position, hit.normal, hit.collider, -1, radius)

func _update_stream(delta: float, spraying: bool) -> void:
	if spraying and attack.mouth_is_clear():
		_stream_origin = mouth_position()
		_stream_velocity = head.global_basis.z.normalized() * JET_SPEED
		_stream_age = minf(_stream_age + delta, FLIGHT_LIMIT)
		_stream_tail = 0.0
		_stream_stop_time = FLIGHT_LIMIT
	elif _stream_age > 0.0:
		# Once the mouth stops, the remaining column drains forward from its
		# last launch frame while fresh drops fall from the articulated mouth.
		_stream_age = minf(_stream_age + delta, FLIGHT_LIMIT)
		_stream_tail += delta
		if _stream_tail >= minf(_stream_age, _stream_stop_time):
			_stream_age = 0.0
	else:
		stream.hide()
		return
	_stream_points.clear()
	_stream_radii.clear()
	_stream_distances.clear()
	if _stream_age <= 0.0:
		stream.ring_count = 0
		stream.hide()
		return
	var time_ := _stream_tail
	var point := _stream_origin + _stream_velocity * time_ + Vector3.DOWN * 4.9 * time_ * time_
	if point.distance_to(_stream_origin) >= attack.MAX_RANGE:
		_stream_age = 0.0
		stream.hide()
		return
	_stream_points.append(point)
	_stream_distances.append(point.distance_to(_stream_origin))
	_stream_radii.append(_stream_radius(_stream_distances[0]))
	var front_time := minf(_stream_age, _stream_stop_time)
	while time_ < front_time and _stream_points.size() < stream.MAX_RINGS:
		var previous_time := time_
		time_ = minf(time_ + STREAM_STEP, front_time)
		var next := _stream_origin + _stream_velocity * time_ + Vector3.DOWN * 4.9 * time_ * time_
		var segment_length := point.distance_to(next)
		var at_range: bool = next.distance_to(_stream_origin) >= attack.MAX_RANGE
		if at_range:
			# Intersect this final segment with the range sphere, rather than
			# shortening flight time and silently losing horizontal reach.
			var relative := point - _stream_origin
			var segment := next - point
			var b := relative.dot(segment)
			var c: float = relative.length_squared() - attack.MAX_RANGE * attack.MAX_RANGE
			var fraction := (-b + sqrt(maxf(0.0, b * b - segment.length_squared() * c))) / maxf(0.00001, segment.length_squared())
			next = point.lerp(next, clampf(fraction, 0.0, 1.0))
		var hit: Dictionary = attack._shot_ray(point, next)
		if not hit.is_empty(): next = hit.position + hit.normal * 0.015
		var distance_ := next.distance_to(_stream_origin)
		var radius := _stream_radius(distance_)
		_touch_wide_stream(point, next, radius)
		if next.distance_squared_to(point) > 0.000001:
			_stream_points.append(next)
			_stream_radii.append(radius)
			_stream_distances.append(distance_)
		if not hit.is_empty():
			_stream_stop_time = minf(_stream_stop_time, lerpf(previous_time, time_, clampf(point.distance_to(hit.position) / maxf(segment_length, 0.00001), 0.0, 1.0)))
			attack.contact_player(hit.collider)
			_impact(hit.position, hit.normal, hit.collider, -1, radius)
			break
		if at_range:
			_stream_stop_time = minf(_stream_stop_time, lerpf(previous_time, time_, clampf(point.distance_to(next) / maxf(segment_length, 0.00001), 0.0, 1.0)))
			break
		point = next
	stream.build(_stream_points, _stream_radii, _stream_distances, attack)

func _sweep_slot(slot: int, next: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(_positions[slot], next, attack.brain.collision_mask, [attack.brain.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)

func _touch_wide_stream(from: Vector3, to: Vector3, radius: float) -> void:
	if attack._lens_contact_cooldown > 0.0 or attack.phase != attack.Phase.SPRAY or not is_instance_valid(_player_collision): return
	var shape := _player_collision.shape as CapsuleShape3D
	if shape == null: return
	var scale_ := _player_collision.global_basis.get_scale()
	var half_segment := maxf(0.0, shape.height * 0.5 - shape.radius) * scale_.y
	var center := _player_collision.global_position
	if center.distance_squared_to(from) > pow(radius + shape.height + from.distance_to(to), 2): return
	var axis := _player_collision.global_basis.y.normalized() * half_segment
	var points := Geometry3D.get_closest_points_between_segments(from, to, center - axis, center + axis)
	if points[0].distance_to(points[1]) > radius + shape.radius * maxf(scale_.x, scale_.z): return
	# Broad visible liquid can hit the capsule edge, but cannot dirty the lens
	# through a wall just because its expanded radius overlaps the other side.
	var hit: Dictionary = attack._shot_ray(from, points[1])
	if hit.is_empty() or hit.collider == attack.brain._player:
		attack.contact_player(attack.brain._player)

func _draw_slot(slot: int) -> void:
	var splash := _splash_normals[slot] != Vector3.ZERO
	var direction := _splash_normals[slot] if splash else _velocities[slot].normalized()
	var up := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x := up.cross(direction).normalized()
	var basis := Basis(x, direction.cross(x).normalized(), direction)
	var size := _jet_radius(slot)
	# Only small inclusions, drips and impact droplets use the particle pool.
	var stretch := size if _chunks[slot] else maxf(_velocities[slot].length() * 0.017, size * 0.38)
	var scale_ := Vector3(size, size, stretch)
	if splash:
		var fade := clampf((_lifetimes[slot] - _ages[slot]) / 0.12, 0.0, 1.0)
		scale_ = Vector3(size * 1.8, size * 1.8, 0.008) * fade
	batch.multimesh.set_instance_transform(slot, Transform3D(basis.scaled_local(scale_), _positions[slot]))
