extends RefCounted
## Crawler-only collision policy. Casts alone ignore objects already overlapping
## the starting shape: resolve those contacts before allowing any further motion.
const ROTATION_STEP := PI / 36.0
const RECOVERY_STEP := 0.08
var recoveries := 0
var _inner := CapsuleShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()

func query(surface: RefCounted, pose: Transform3D, inner: bool = false) -> PhysicsShapeQueryParameters3D:
	var shape: CapsuleShape3D = surface.collision.shape
	if inner:
		# Grounded move_and_slide has its own contact tolerance. Keep its tiny
		# resting overlap separate from stricter manual corner/flight sweeps.
		var tolerance := 0.003 if surface.phase == surface.Phase.GROUND else 0.001
		_inner.radius = maxf(0.01, shape.radius - tolerance)
		_inner.height = maxf(_inner.radius * 2.0, shape.height - tolerance * 2.0)
	_query.shape = _inner if inner else shape
	_query.transform = pose
	_query.collision_mask = surface.brain.collision_mask | surface.SURFACE_SUPPORT_LAYER
	_query.exclude = [surface.brain.get_rid()]
	_query.motion = Vector3.ZERO
	_query.margin = 0.0 if inner else 0.002
	return _query

func penetrates(surface: RefCounted, pose: Transform3D) -> bool:
	return overlaps(surface, query(surface, pose, true))

func overlaps(surface: RefCounted, parameters: PhysicsShapeQueryParameters3D) -> bool:
	var space: PhysicsDirectSpaceState3D = surface.brain.get_world_3d().direct_space_state
	var hits := space.intersect_shape(parameters, 32)
	if hits.size() == 32: return true # Saturated query: retain the conservative result.
	for hit: Dictionary in hits:
		var body := hit.collider as CollisionObject3D
		if body == null: return true
		var owner := body.shape_owner_get_owner(body.shape_find_owner(hit.shape)) as CollisionShape3D
		if owner == null or not owner.shape is BoxShape3D or not parameters.shape is CapsuleShape3D: return true
		var scale_: Vector3 = owner.global_basis.get_scale().abs()
		if scale_.max_axis_index() == scale_.min_axis_index() or scale_[scale_.max_axis_index()] < scale_[scale_.min_axis_index()] * 1.2: return true
		# Nonuniform church boxes can report an overlap well below their real
		# slanted surface. Check capsule-to-box distance for those hits only;
		# this also detects full containment, where contact manifolds can be empty.
		if _capsule_overlaps_box(parameters, owner): return true
	return false

func _capsule_overlaps_box(parameters: PhysicsShapeQueryParameters3D, box: CollisionShape3D) -> bool:
	var box_pose := box.global_transform
	var inverse := box_pose.basis.orthonormalized().transposed()
	var extent: Vector3 = box.shape.size * 0.5
	var axes := inverse * box_pose.basis
	# Enclose small authored shear conservatively in the box's orthogonal frame.
	var half := axes.x.abs() * extent.x + axes.y.abs() * extent.y + axes.z.abs() * extent.z
	var capsule: CapsuleShape3D = parameters.shape
	var pose := parameters.transform
	var scale_: Vector3 = pose.basis.get_scale().abs()
	var radius := capsule.radius * maxf(scale_.x, maxf(scale_.y, scale_.z)) + parameters.margin
	var segment := pose.basis.y * (capsule.height * 0.5 - capsule.radius)
	var a := inverse * (pose.origin - segment - box_pose.origin)
	var d := inverse * (segment * 2.0)
	var cuts: Array[float] = [0.0, 1.0]
	for axis in 3:
		if absf(d[axis]) < 0.000001: continue
		for side in [-1.0, 1.0]:
			var t: float = (half[axis] * side - a[axis]) / d[axis]
			if t > 0.0 and t < 1.0: cuts.append(t)
	cuts.sort()
	# On each interval the squared distance to the box is a quadratic. Its
	# clamped minimum gives exact segment/box distance without time sampling.
	for index in range(cuts.size() - 1):
		var middle := (cuts[index] + cuts[index + 1]) * 0.5
		var linear := 0.0
		var quadratic := 0.0
		for axis in 3:
			var coordinate := a[axis] + d[axis] * middle
			if absf(coordinate) <= half[axis]: continue
			linear += d[axis] * (a[axis] - signf(coordinate) * half[axis])
			quadratic += d[axis] * d[axis]
		var t := clampf(-linear / quadratic, cuts[index], cuts[index + 1]) if quadratic > 0.0000001 else middle
		var nearest := (a + d * t).abs() - half
		nearest = nearest.max(Vector3.ZERO)
		if nearest.length_squared() <= radius * radius: return true
	return false

func recover(surface: RefCounted) -> bool:
	var pose: Transform3D = surface.collision.global_transform
	if not penetrates(surface, pose): return true
	var space: PhysicsDirectSpaceState3D = surface.brain.get_world_3d().direct_space_state
	if surface.phase == surface.Phase.GROUND:
		# Grounded move_and_slide already resolves encounters with characters.
		# Treating the player's next step as an interrupted flight every frame
		# starved attack timers and repeatedly sent a close pursuit into DROP.
		var scenery := false
		for hit: Dictionary in space.intersect_shape(query(surface, pose, true), 16):
			if not hit.collider is CharacterBody3D: scenery = true
		if not scenery: return true
	var contacts := space.collide_shape(query(surface, pose), 8)
	var correction := Vector3.ZERO
	for i in range(0, contacts.size(), 2):
		var separation := contacts[i + 1] - contacts[i]
		var depth := separation.length()
		if depth < 0.00001: continue
		var normal := separation / depth
		correction += normal * maxf(0.0, depth + 0.004 - correction.dot(normal))
	correction = correction.limit_length(RECOVERY_STEP)
	if correction.length_squared() > 0.000001:
		# Existing contacts may be left behind, but a correction cannot push the
		# capsule into a different wall or through a newly closing door.
		var existing := space.intersect_shape(query(surface, pose), 16)
		var candidate := pose
		candidate.origin += correction
		var allowed := true
		for hit: Dictionary in space.intersect_shape(query(surface, candidate, true), 16):
			var known := false
			for old: Dictionary in existing:
				if hit.rid == old.rid and hit.shape == old.shape: known = true
			if not known: allowed = false
		if allowed:
			surface.brain.global_position += correction
			surface.brain.force_update_transform()
			recoveries += 1
			if surface.phase == surface.Phase.GROUND and not penetrates(surface, candidate): return true
	surface.brain.velocity = Vector3.ZERO
	return false # Pause motion; the caller revalidates a grip or cancels a flight.

func sweep(surface: RefCounted, motion: Vector3) -> Dictionary:
	if not recover(surface): return {"normal": Vector3.UP, "recovering": true}
	if motion.length_squared() < 0.00000001: return {}
	var space: PhysicsDirectSpaceState3D = surface.brain.get_world_3d().direct_space_state
	var from: Transform3D = surface.collision.global_transform
	var cast := query(surface, from)
	cast.margin = 0.005
	cast.motion = motion
	var fractions := space.cast_motion(cast)
	var safe := float(fractions[0])
	var pose := from
	pose.origin += motion * safe
	# Validate the end as well. This catches thin surfaces and start-contact
	# numerical cases that a cast can report as completely unobstructed.
	if penetrates(surface, pose):
		var low := 0.0
		var high := safe
		for i in 9:
			var mid := (low + high) * 0.5
			pose.origin = from.origin + motion * mid
			if penetrates(surface, pose): high = mid
			else: low = mid
		safe = low
	surface.brain.global_position += motion * safe
	surface.brain.force_update_transform()
	if safe >= 0.99999: return {}
	pose.origin = from.origin + motion * minf(1.0, maxf(fractions[1], safe + 0.001))
	var hit := space.get_rest_info(query(surface, pose))
	return hit if not hit.is_empty() else {"normal": -motion.normalized()}

func rotate_to(surface: RefCounted, basis: Basis) -> bool:
	var from: Transform3D = surface.collision.global_transform
	var start := from.basis.orthonormalized().get_rotation_quaternion()
	var end := basis.orthonormalized().get_rotation_quaternion()
	var steps := maxi(1, int(ceil(start.angle_to(end) / ROTATION_STEP)))
	for i in range(1, steps + 1):
		var next := Transform3D(Basis(start.slerp(end, float(i) / steps)).scaled(basis.get_scale()), from.origin)
		if penetrates(surface, next): return false
	# Rotate around the physical centre, keeping authored scale and local offset.
	surface.brain.global_transform = Transform3D(basis, from.origin - basis * surface.collision.position)
	surface.brain.force_update_transform()
	return true

func orient(surface: RefCounted, up: Vector3, forward: Vector3, delta: float) -> bool:
	var target: Basis = surface.JumpPlanner.aligned_basis(up.normalized(), forward)
	var start: Quaternion = surface.brain.global_basis.orthonormalized().get_rotation_quaternion()
	var blend := 1.0 - exp(-12.0 * delta)
	var next := Basis(start.slerp(target.get_rotation_quaternion(), blend)).scaled(surface.brain.global_basis.get_scale())
	return rotate_to(surface, next)
