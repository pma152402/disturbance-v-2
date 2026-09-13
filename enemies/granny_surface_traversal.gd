extends RefCounted
## Short, collision-checked surface excursions; grounded navigation remains authoritative.
enum Phase { GROUND, WALL, CEILING, DROP }
const SURFACE_SUPPORT_LAYER := 1 << 19
var phase := Phase.GROUND
var normal := Vector3.UP
var elapsed := 0.0
var ceiling_elapsed := 0.0
var scan_timer := 0.0
var cooldown := 4.0
var stalled := 0.0
var last_position := Vector3.ZERO
var wall_normal := Vector3.ZERO
var brain: CharacterBody3D
var collision: CollisionShape3D

func setup(actor: CharacterBody3D) -> void:
	brain = actor
	collision = actor.get_node("Collision")
	last_position = actor.global_position

func active() -> bool:
	return phase != Phase.GROUND

func _center() -> Vector3:
	return brain.global_transform * collision.position

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, brain.collision_mask | SURFACE_SUPPORT_LAYER, [brain.get_rid()])
	return brain.get_world_3d().direct_space_state.intersect_ray(query)

func _structural(hit: Dictionary) -> bool:
	if hit.is_empty() or not hit.collider is StaticBody3D:
		return false
	return not _belongs_to_door(hit.collider as Node)

func _belongs_to_door(node: Node) -> bool:
	# Door leaves are normally AnimatableBody3D, but baked frames, lintels and
	# collision helpers can be StaticBody3D. Inspect the complete owning branch:
	# a static child of a door must never become a climbing support either.
	var current := node
	for depth in 10:
		if current == null or current == brain:
			break
		if current.is_in_group(&"npc_door") or current.is_in_group(&"door"):
			return true
		if current.has_method(&"get_npc_traversal_portal") or current.has_method(&"ensure_open_for_npc"):
			return true
		var words := str(current.name).to_snake_case().split("_", false)
		for word in words:
			if word in ["door", "doors", "puerta", "puertas", "porton"]:
				return true
		var script := current.get_script() as Script
		if script != null:
			var path := script.resource_path.to_lower()
			if "/doors/" in path or "door_leaf" in path or path.ends_with("/door.gd"):
				return true
		current = current.get_parent()
	return false

func _sweep_motion(motion: Vector3) -> Dictionary:
	# Sweep the actual rotated capsule. CharacterBody motion recovery produces
	# large lateral displacements against this level's nonuniformly scaled walls
	# during inversion; a bounded shape cast keeps every displacement physical.
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.collision_mask = brain.collision_mask | SURFACE_SUPPORT_LAYER
	query.exclude = [brain.get_rid()]
	query.margin = 0.005
	query.motion = motion
	var space := brain.get_world_3d().direct_space_state
	var fractions := space.cast_motion(query)
	brain.global_position += motion * fractions[0]
	brain.force_update_transform()
	if fractions[0] >= 1.0:
		return {}
	query.transform.origin += motion * fractions[1]
	query.motion = Vector3.ZERO
	var hit := space.get_rest_info(query)
	return hit if not hit.is_empty() else {"normal": -motion.normalized()}

func _orient(up: Vector3, forward: Vector3, delta: float) -> bool:
	forward = forward.slide(up).normalized()
	if forward.length_squared() < 0.01:
		forward = (Vector3.RIGHT if absf(up.z) > 0.9 else Vector3.FORWARD).slide(up).normalized()
	var basis := Basis(up.cross(forward).normalized(), up, forward).orthonormalized()
	basis = Basis(brain.global_basis.get_rotation_quaternion().slerp(basis.get_rotation_quaternion(), 1.0 - exp(-4.0 * delta)))
	var pose := Transform3D(basis, _center() - basis * collision.position)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = pose * collision.transform
	query.collision_mask = brain.collision_mask | SURFACE_SUPPORT_LAYER
	query.exclude = [brain.get_rid()]
	if not brain.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	brain.global_transform = pose
	brain.force_update_transform()
	return true

func consider(delta: float, evidence: Vector3, motivated: bool) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if not motivated or cooldown > 0.0 or bool(brain.get("_obstacle_jump_active")):
		stalled = 0.0
		return
	scan_timer -= delta
	if scan_timer > 0.0:
		return
	scan_timer = 0.6
	stalled = stalled + 0.6 if brain.global_position.distance_to(last_position) < 0.18 else 0.0
	last_position = brain.global_position
	var toward := (evidence - _center()).slide(Vector3.UP).normalized()
	if toward.length_squared() < 0.01 or evidence.distance_to(brain.global_position) < 2.4:
		return
	# Frontal obstruction or flank: no dynamic props or door leaves as climbing supports.
	for angle in [0.0, -1.15, 1.15]:
		var hit := _ray(_center(), _center() + toward.rotated(Vector3.UP, angle) * 1.8)
		if not _structural(hit) or absf(hit.normal.y) > 0.15:
			continue
		# Una pared lateral o situada a espaldas de la pista no es un atajo. Sin
		# esta condición podía abandonar el altar escalando el retablo opuesto.
		if (hit.position as Vector3).distance_to(evidence) >= _center().distance_to(evidence) - 0.12:
			continue
		var above := _ray(_center() + Vector3.UP * 1.2, _center() + Vector3.UP * 1.2 - hit.normal * 1.8)
		if not _structural(above) or above.normal.dot(hit.normal) < 0.95:
			continue
		if angle != 0.0 and stalled < 1.2 and float(brain.get("alertness")) < 0.8:
			continue
		wall_normal = hit.normal
		normal = wall_normal
		phase = Phase.WALL
		elapsed = 0.0
		ceiling_elapsed = 0.0
		brain.velocity = Vector3.ZERO
		return

func step(delta: float, evidence: Vector3, memory_valid: bool) -> void:
	elapsed += delta
	if elapsed > 12.0 or not memory_valid:
		phase = Phase.DROP
	var center := _center()
	if phase == Phase.DROP:
		_drop(delta)
		return
	var support := _ray(center, center - normal * 2.1)
	if not _structural(support) or support.normal.dot(normal) < 0.8:
		phase = Phase.DROP
		return
	if phase == Phase.CEILING:
		normal = support.normal
	var direction := Vector3.UP if phase == Phase.WALL else (evidence - center).slide(Vector3.UP).slide(normal).normalized()
	if phase == Phase.WALL:
		var roof := _ray(center, center + Vector3.UP * 1.25)
		if _structural(roof) and roof.normal.y < -0.65:
			phase = Phase.CEILING
			normal = roof.normal
			return
	else:
		ceiling_elapsed += delta
		if (evidence - center).slide(Vector3.UP).length() < 1.2 or ceiling_elapsed > 5.0:
			phase = Phase.DROP
			return
		var next_support := _ray(center + direction * 0.55, center + direction * 0.55 - normal * 2.1)
		if not _structural(next_support) or next_support.normal.dot(normal) < 0.8:
			phase = Phase.DROP
			return
	var correction: Vector3 = (support.position + normal * 1.04 - center) * 3.0
	var target_velocity := direction * float(brain.get("climb_speed")) + correction.limit_length(1.8)
	if not _orient(normal, direction, delta):
		# Move off the corner before rotating; never rotate the capsule into masonry.
		target_velocity = normal * 0.65
	brain.velocity = target_velocity
	var contact := _sweep_motion(brain.velocity * delta)
	if not contact.is_empty() and elapsed > 2.0:
		phase = Phase.DROP

func _drop(delta: float) -> void:
	var facing := brain.global_basis.z.slide(Vector3.UP)
	if facing.length_squared() < 0.01:
		facing = wall_normal
	var upright := _orient(Vector3.UP, facing.normalized(), delta)
	# First gain room to turn upright; retain collisions during the entire descent.
	if not upright or brain.global_basis.y.dot(Vector3.UP) < 0.98:
		brain.velocity = wall_normal * 0.6 + Vector3.DOWN * 0.3
	else:
		brain.velocity = Vector3(0, maxf(brain.velocity.y - 12.0 * delta, -8.0), 0)
	var contact := _sweep_motion(brain.velocity * delta)
	if not contact.is_empty() and contact.normal.y > 0.7 and brain.global_basis.y.y > 0.98:
		brain.rotation = Vector3(0, atan2(facing.x, facing.z), 0)
		brain.velocity = Vector3.ZERO
		phase = Phase.GROUND
		normal = Vector3.UP
		cooldown = 10.0
		stalled = 0.0
		brain.set("_target_refresh_timer", 0.0)
