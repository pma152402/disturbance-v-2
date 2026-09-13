extends RefCounted
## One trajectory/orientation model shared by planning and execution. Physics
## queries include the whole rotating capsule, never just a ray to the endpoint.
const SAMPLE_DISTANCE := 0.10
const TURN_START := 0.18
const TURN_END := 0.60

static func aligned_basis(up: Vector3, forward: Vector3) -> Basis:
	forward = forward.slide(up).normalized()
	if forward.length_squared() < 0.01:
		forward = (Vector3.RIGHT if absf(up.x) < 0.8 else Vector3.BACK).slide(up).normalized()
	return Basis(up.cross(forward).normalized(), up, forward).orthonormalized()

static func pose_at(plan: Dictionary, t: float) -> Transform3D:
	var u := 1.0 - t
	var center: Vector3 = plan.start * u * u * u + plan.departure * 3.0 * u * u * t + plan.approach * 3.0 * u * t * t + plan.end * t * t * t
	var rotation: Quaternion = plan.from_rotation.slerp(plan.to_rotation, smoothstep(TURN_START, TURN_END, t))
	return Transform3D(Basis(rotation).scaled(plan.scale), center)

static func query_for(surface: RefCounted, pose: Transform3D) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = surface.collision.shape
	query.transform = pose
	query.collision_mask = surface.brain.collision_mask | surface.SURFACE_SUPPORT_LAYER
	query.exclude = [surface.brain.get_rid()]
	query.margin = 0.003
	return query

static func clear_segment(surface: RefCounted, from: Transform3D, to: Transform3D) -> bool:
	var space: PhysicsDirectSpaceState3D = surface.brain.get_world_3d().direct_space_state
	var query := query_for(surface, to)
	if not space.intersect_shape(query, 1).is_empty():
		return false
	query.transform = from
	query.motion = to.origin - from.origin
	if query.motion.length_squared() > 0.0000001 and space.cast_motion(query)[0] < 0.999:
		return false
	return true

static func build(surface: RefCounted, point: Vector3, target_normal: Vector3, facing: Vector3, attack: bool = false) -> Dictionary:
	var start: Vector3 = surface._center()
	var end: Vector3 = point if attack else point + target_normal * surface.SPIDER_SUPPORT_OFFSET
	var launch: Vector3 = surface.brain.global_basis.y.normalized()
	var distance := start.distance_to(end)
	var rotation_from: Quaternion = surface.brain.global_basis.orthonormalized().get_rotation_quaternion()
	var rotation_to := aligned_basis(target_normal, facing).get_rotation_quaternion()
	var same_plane := launch.dot(target_normal) > 0.86
	# Try a modest arch first. Only raise it when there is an actual obstruction;
	# the old fixed high arch hit low ceilings even for metre-long escapes.
	var reaches := [0.22, 0.45, 0.90, 1.65] if same_plane else [clampf(distance * 0.28, 0.85, 1.35), 1.65]
	for reach_value in reaches:
		var reach := float(reach_value)
		var plan := {"start": start, "end": end, "departure": start + launch * reach, "approach": end + target_normal * reach,
			"from_rotation": rotation_from, "to_rotation": rotation_to, "scale": surface.brain.global_basis.get_scale(),
			"launch_normal": launch, "target_normal": target_normal, "facing": aligned_basis(target_normal, facing).z}
		var arc_length := 0.0
		var before := pose_at(plan, 0.0)
		var steps := maxi(32, int(ceil((distance + reach * 2.0) / SAMPLE_DISTANCE)))
		var valid := true
		for index in range(1, steps + 1):
			var next := pose_at(plan, float(index) / steps)
			arc_length += before.origin.distance_to(next.origin)
			# The legacy attack is only used by explicit validation/tools. Gameplay
			# emergency hops always validate the destination including characters.
			if not (attack and index > steps * 0.7) and not clear_segment(surface, before, next):
				valid = false
				break
			before = next
		if valid:
			plan["duration"] = clampf(arc_length / 11.5, 0.28, 0.68)
			return plan
	return {}
