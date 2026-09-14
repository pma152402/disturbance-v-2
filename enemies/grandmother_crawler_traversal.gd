extends "res://enemies/granny_surface_traversal.gd"
## The ceiling is home: climb, perch, stalk and commit to a dodgeable dive.
const SPIDER_MIN_JUMP_DISTANCE := 1.05
const SPIDER_MAX_JUMP_DISTANCE := 5.0
const SPIDER_PREFERRED_JUMP_DISTANCE := 3.6
const SPIDER_SUPPORT_OFFSET := 0.82
const SPIDER_FOOTPRINT_RADIUS := 0.42
const ATTACHMENT_REACH := 1.8
const CORNER_SPEED := 6.6
const JumpPlanner := preload("res://enemies/crawler_jump_planner.gd")
var collision_guard := preload("res://enemies/crawler_collision_guard.gd").new()
var _spider_plan: Dictionary = {}
var _spider_recent: Array[Vector3] = []
var _spider_recent_timer := 0.0
var _spider_retreating := false
var _spider_trace: Array[Transform3D] = []
var spider_settling := 0.0
var spider_plans_checked := 0
var spider_aborts := 0
var _transition_progress_position := Vector3.ZERO
var _transition_stall := 0.0
var _release_remaining := 0.0
var _release_direction := Vector3.ZERO
var winding_up := false
var windup_time := 0.0
var pouncing := false
var pounce_aim := Vector3.ZERO
var pounce_velocity := Vector3.ZERO
var pounce_time := 0.0
var pounce_hit := false
var pounce_flight_duration := 0.6
var _pounce_from_rotation := Quaternion.IDENTITY
var _pounce_to_rotation := Quaternion.IDENTITY
var landing_recovery := 0.0
var _rejected: Array[Vector3] = []
var _reject_seconds := 0.0
var wall_travel_sign := 1.0
var corner_transitions := 0
var wall_transition_lockout := 0.0
var _last_support_position := Vector3.ZERO
var corner_active := false
var _corner_stage := 0
var _corner_face_position := Vector3.ZERO
var _corner_face_normal := Vector3.ZERO
var _corner_old_normal := Vector3.ZERO
var _corner_travel_sign := 1.0
var _corner_kind := 0
var _corner_across := Vector3.ZERO
var _horizontal_commit_direction := Vector3.ZERO
var _horizontal_commit_remaining := 0.0
var spider_winding_up := false
var spider_windup_time := 0.0
var spider_leaping := false
var spider_jump_attack := false
var spider_jump_reason := ""
var spider_target_position := Vector3.ZERO
var spider_target_normal := Vector3.UP
var spider_launch_normal := Vector3.UP
var spider_curve_start := Vector3.ZERO
var spider_curve_departure := Vector3.ZERO
var spider_curve_approach := Vector3.ZERO
var spider_velocity := Vector3.ZERO
var spider_flight_time := 0.0
var spider_flight_duration := 0.0
var spider_hit := false
var spider_jump_cooldown := 0.0
var spider_jump_count := 0
var wants_to_travel := false

func support_offset() -> float:
	return SPIDER_SUPPORT_OFFSET * brain.global_basis.get_scale().abs().y

func _body_clearance() -> float:
	return 0.78 * brain.global_basis.get_scale().abs().y

func spider_busy() -> bool:
	return spider_winding_up or spider_leaping or _spider_retreating or spider_settling > 0.0

func ensure_body_clear() -> bool:
	if collision_guard.recover(self): return true
	# Correcting an external nudge does not remove a valid architectural grip.
	# Pause until the capsule clears, retaining adhesion rather than starting a
	# seven-metre fall for a centimetre of overlap against the church vault.
	if phase in [Phase.WALL, Phase.CEILING] and not spider_busy() and not pouncing:
		if not _attachment_support(_center(), normal, ATTACHMENT_REACH).is_empty():
			return false
	# An external push invalidates a saved curve or fixed vomiting transform.
	spider_winding_up = false
	spider_leaping = false
	_spider_retreating = false
	spider_settling = 0.0
	corner_active = false
	pouncing = false
	winding_up = false
	_release_remaining = 0.0
	phase = Phase.DROP
	brain.on_spider_jump_aborted()
	if is_instance_valid(brain.vomit) and brain.vomit.stationary(): brain.vomit.cancel()
	return false

func _attachment_support(center: Vector3, up: Vector3, reach: float) -> Dictionary:
	var hit := _ray(center, center - up * reach)
	if _structural(hit) and hit.normal.dot(up) > 0.8: return hit
	# Only retry on a missing centre contact. Paired probes bridge tiny panel
	# seams, while requiring support on BOTH sides prevents floating past edges.
	var forward := JumpPlanner.aligned_basis(up, brain.global_basis.z).z
	var side := up.cross(forward).normalized()
	for tangent in [forward, side]:
		var a := _ray(center + tangent * 0.16, center + tangent * 0.16 - up * reach)
		if not _structural(a) or a.normal.dot(up) < 0.8: continue
		var b := _ray(center - tangent * 0.16, center - tangent * 0.16 - up * reach)
		if not _structural(b) or b.normal.dot(up) < 0.8: continue
		if a.normal.dot(b.normal) > 0.95 and absf((Vector3(a.position) - Vector3(b.position)).dot(up)) < 0.08:
			return a
	return {}

func _sweep_motion(motion: Vector3) -> Dictionary:
	return collision_guard.sweep(self, motion)

func _orient(up: Vector3, forward: Vector3, delta: float) -> bool:
	return collision_guard.orient(self, up, forward, delta)

func _land_on_floor(facing: Vector3) -> bool:
	var basis := JumpPlanner.aligned_basis(Vector3.UP, facing).scaled(brain.global_basis.get_scale())
	if not collision_guard.rotate_to(self, basis): return false
	phase = Phase.GROUND
	normal = Vector3.UP
	brain.velocity = Vector3.ZERO
	cooldown = 2.0
	landing_recovery = 0.38
	spider_settling = 0.18
	brain._target_refresh_timer = 0.0
	return true

func _drop(delta: float) -> void:
	var facing := brain.global_basis.z.slide(Vector3.UP)
	if facing.length_squared() < 0.01: facing = wall_normal.slide(Vector3.UP)
	var upright := _orient(Vector3.UP, facing, delta * 2.0)
	if not upright:
		# A capsule lying against the floor needs room ABOVE it to stand. The
		# previous downward release kept it trapped and eventually crossed floors.
		brain.velocity = Vector3.UP * 1.4 + wall_normal.slide(Vector3.UP).limit_length(1.0) * 0.45
	elif brain.global_basis.y.normalized().y < 0.995:
		brain.velocity = wall_normal.slide(Vector3.UP).limit_length(1.0) * 0.4
	else:
		brain.velocity = Vector3(0, maxf(brain.velocity.y - 12.0 * delta, -10.0), 0)
	var contact := _sweep_motion(brain.velocity * delta)
	if not contact.is_empty() and not contact.get("recovering", false) and contact.normal.y > 0.7 and brain.global_basis.y.normalized().y > 0.995:
		_land_on_floor(facing)

func begin_spider_jump(target: Dictionary, attack: bool = false, reason: String = "reposition") -> bool:
	if spider_busy() or pouncing or winding_up or corner_active or target.is_empty() or spider_jump_cooldown > 0.0:
		return false
	if phase in [Phase.WALL, Phase.CEILING] and not _launch_support_exists(normal):
		return false
	var point := Vector3(target.get("position", Vector3.ZERO))
	var target_normal := Vector3(target.get("normal", Vector3.UP)).normalized()
	if not point.is_finite() or not target_normal.is_finite():
		return false
	var landing_center := point if attack else point + target_normal * support_offset()
	var jump_distance := _center().distance_to(landing_center)
	if not attack and (jump_distance < SPIDER_MIN_JUMP_DISTANCE or jump_distance > SPIDER_MAX_JUMP_DISTANCE):
		return false
	var facing := _spider_landing_facing(point, target_normal)
	if not attack and not _spider_landing_is_safe(point, target_normal, facing):
		return false
	_spider_plan = JumpPlanner.build(self, point, target_normal, facing, attack)
	spider_plans_checked += 1
	if _spider_plan.is_empty():
		return false
	spider_target_position = landing_center
	spider_target_normal = target_normal
	spider_launch_normal = normal if active() else Vector3.UP
	spider_jump_attack = attack
	spider_jump_reason = reason
	spider_winding_up = true
	spider_windup_time = 0.0
	spider_leaping = false
	spider_hit = false
	_spider_retreating = false
	_spider_trace.clear()
	_spider_trace.append(JumpPlanner.pose_at(_spider_plan, 0.0))
	corner_active = false
	winding_up = false
	pouncing = false
	phase = Phase.DROP
	brain.velocity = Vector3.ZERO
	return true

func find_spider_jump_target(preferred_direction: Vector3 = Vector3.ZERO) -> Dictionary:
	var center := _center()
	var origin := center + (normal if active() else Vector3.UP) * 0.12
	var preferred := preferred_direction.normalized()
	var directions: Array[Vector3] = [Vector3.UP, Vector3.DOWN]
	for index in 12:
		var radial := Vector3(sin(index * TAU / 12.0), 0.0, cos(index * TAU / 12.0))
		directions.append(radial)
		directions.append((radial * 0.62 + Vector3.UP).normalized())
		directions.append((radial * 0.72 + Vector3.DOWN * 0.48).normalized())
	if preferred.length_squared() > 0.01:
		directions.push_front(preferred)
		directions.push_front((preferred + Vector3.UP * 0.65).normalized())
	var candidates: Array[Dictionary] = []
	for direction in directions:
		var hit := _ray(origin, origin + direction * (SPIDER_MAX_JUMP_DISTANCE + SPIDER_SUPPORT_OFFSET * 2.0))
		if not _spider_surface_allowed(hit):
			continue
		var hit_normal := Vector3(hit.normal).normalized()
		var landing_center := Vector3(hit.position) + hit_normal * support_offset()
		var distance := center.distance_to(landing_center)
		if distance < SPIDER_MIN_JUMP_DISTANCE or distance > SPIDER_MAX_JUMP_DISTANCE:
			continue
		if not _spider_landing_is_safe(Vector3(hit.position), hit_normal, _spider_landing_facing(hit.position, hit_normal)):
			continue
		# Prefer a genuinely different plane and, as a natural bias for this
		# creature, reward ceilings without making them compulsory. Prefer a real
		# escape stride, keeping shorter alternatives for confined rooms.
		var score := -absf(distance - SPIDER_PREFERRED_JUMP_DISTANCE) * 0.5
		if preferred.length_squared() > 0.01:
			score += direction.dot(preferred) * 1.8
		if hit_normal.y < -0.65:
			score += 2.5 if normal.y < -0.65 and active() else 0.2
		if hit_normal.dot(normal) > 0.92:
			score += 0.25
		candidates.append({"position": Vector3(hit.position), "normal": hit_normal, "collider": hit.collider, "direction": direction, "score": score})
	# Dense furniture can block every ray cast from the body even though a safe
	# patch exists farther along the current support plane. Probe candidate points
	# from outside back toward that plane, allowing a short hop over an obstacle
	# without ever accepting the obstacle itself as the destination.
	var support_normal := normal if active() else Vector3.UP
	var tangent_forward := preferred.slide(support_normal).normalized()
	if tangent_forward.length_squared() < 0.01:
		tangent_forward = brain.global_basis.z.slide(support_normal).normalized()
	if tangent_forward.length_squared() < 0.01:
		tangent_forward = Vector3.FORWARD.slide(support_normal).normalized()
	for turn in [0.0, -0.52, 0.52, -1.05, 1.05, -1.57, 1.57, PI]:
		var tangent: Vector3 = tangent_forward.rotated(support_normal, float(turn)).normalized()
		for distance in [1.2, 2.4, 3.6, 4.8]:
			var above: Vector3 = center + tangent * float(distance) + support_normal * 0.32
			var plane_hit := _ray(above, above - support_normal * 1.35)
			if not _spider_surface_allowed(plane_hit):
				continue
			var hit_normal := Vector3(plane_hit.normal).normalized()
			if hit_normal.dot(support_normal) < 0.86:
				continue
			if not _spider_landing_is_safe(Vector3(plane_hit.position), hit_normal, _spider_landing_facing(plane_hit.position, hit_normal)):
				continue
			var score := tangent.dot(preferred) * 1.8 - absf(float(distance) - SPIDER_PREFERRED_JUMP_DISTANCE) * 0.5 + 0.25
			if support_normal.y < -0.65: score += 2.5
			candidates.append({"position": Vector3(plane_hit.position), "normal": hit_normal, "collider": plane_hit.collider, "direction": tangent, "score": score})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	var checked := 0
	for candidate in candidates:
		var point: Vector3 = candidate.position + candidate.normal * support_offset()
		if _center().distance_to(point) > SPIDER_MAX_JUMP_DISTANCE or _center().distance_to(point) < SPIDER_MIN_JUMP_DISTANCE:
			continue
		var repeated := false
		for recent in _spider_recent:
			repeated = repeated or point.distance_to(recent) < 0.75
		if repeated:
			continue
		var facing := _spider_landing_facing(candidate.position, candidate.normal)
		spider_plans_checked += 1
		checked += 1
		if not JumpPlanner.build(self, candidate.position, candidate.normal, facing).is_empty():
			return candidate
		if checked >= 12:
			break
	return {}

func _spider_surface_allowed(hit: Dictionary) -> bool:
	if not _structural(hit):
		return false
	# Furniture used to count as architecture because most props use StaticBody3D.
	# A jump can collide with it, but it must never choose a pew, table or chair as
	# a landing plane: their narrow tops strand the full capsule against an edge.
	var current := hit.collider as Node
	for depth in 6:
		if current == null or current == brain:
			break
		if current.scene_file_path.to_lower().begins_with("res://house_props/"):
			return false
		if current.get_node_or_null("CameraObservable") != null:
			return false
		var words := str(current.name).to_snake_case().split("_", false)
		for word in words:
			if word in ["pew", "bench", "banco", "chair", "table", "altar", "cabinet", "shelf"]:
				return false
		current = current.get_parent()
	return true

func _spider_landing_facing(point: Vector3, landing_normal: Vector3) -> Vector3:
	# Selección, despegue y recepción comprueban los mismos apoyos orientados.
	# Usar aquí la dirección preferida de búsqueda aprobaba una huella distinta.
	var facing := (point - _center()).slide(landing_normal).normalized()
	if facing.length_squared() < 0.01:
		facing = brain.global_basis.z.slide(landing_normal).normalized()
	return JumpPlanner.aligned_basis(landing_normal, facing).z

func _spider_landing_is_safe(point: Vector3, landing_normal: Vector3, preferred_forward: Vector3) -> bool:
	if landing_normal.length_squared() < 0.9:
		return false
	var forward := preferred_forward.slide(landing_normal).normalized()
	if forward.length_squared() < 0.01:
		forward = (Vector3.RIGHT if absf(landing_normal.x) < 0.8 else Vector3.FORWARD).slide(landing_normal).normalized()
	var side := landing_normal.cross(forward).normalized()
	# Confirm a complete footprint around the four limbs. This rejects ledges,
	# bank tops and seams where only the middle ray has support.
	for offset in [Vector3.ZERO, forward * 0.75, -forward * 0.96,
		forward * 0.67 + side * 0.43, forward * 0.67 - side * 0.43,
		-forward * 0.88 + side * 0.29, -forward * 0.88 - side * 0.29]:
		var scaled_offset: Vector3 = offset * brain.global_basis.get_scale().abs().y
		var probe := _ray(point + scaled_offset + landing_normal * 0.32, point + scaled_offset - landing_normal * 0.28)
		if not _spider_surface_allowed(probe) or Vector3(probe.normal).normalized().dot(landing_normal) < 0.86:
			return false
	return _spider_pose_is_clear(point + landing_normal * support_offset(), landing_normal, forward)

func _spider_pose_is_clear(center: Vector3, landing_normal: Vector3, forward: Vector3) -> bool:
	forward = forward.slide(landing_normal).normalized()
	if forward.length_squared() < 0.01:
		forward = (Vector3.RIGHT if absf(landing_normal.x) < 0.8 else Vector3.FORWARD).slide(landing_normal).normalized()
	var basis := Basis(landing_normal.cross(forward).normalized(), landing_normal, forward).orthonormalized()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = Transform3D(basis.scaled(brain.global_basis.get_scale()), center)
	query.collision_mask = brain.collision_mask | SURFACE_SUPPORT_LAYER
	query.exclude = [brain.get_rid()]
	query.margin = 0.015
	return not collision_guard.overlaps(self, query)

func reject_entry(point: Vector3) -> void:
	_rejected.append(point)
	if _rejected.size() > 6:
		_rejected.pop_front()
	_reject_seconds = 12.0

func find_ceiling_entry(radius: float) -> Dictionary:
	var center := _center()
	var best := {}
	var best_distance := INF
	for index in 16:
		var direction := Vector3(sin(index * TAU / 16), 0, cos(index * TAU / 16))
		var wall := _ray(center, center + direction * radius)
		if not _structural(wall) or absf(wall.normal.y) > 0.15:
			continue
		var above := _ray(center + Vector3.UP * 1.2, wall.position + Vector3.UP * 1.2 - wall.normal * 0.1)
		if not _structural(above) or above.normal.dot(wall.normal) < 0.95:
			continue
		var near: Vector3 = wall.position + wall.normal * 0.95
		var roof := _ray(near + Vector3.UP * 0.3, near + Vector3.UP * 12.0)
		if not _structural(roof) or roof.normal.y > -0.65:
			continue
		var floor_hit := _ray(near, near + Vector3.DOWN * 2.0)
		if not _structural(floor_hit) or floor_hit.normal.y < 0.7:
			continue
		var point: Vector3 = floor_hit.position
		var rejected := false
		for rejected_point in _rejected:
			rejected = rejected or point.distance_to(rejected_point) < 1.8
		if rejected:
			continue
		var distance := center.distance_to(near)
		if distance < best_distance:
			best_distance = distance
			best = {"position": point, "normal": wall.normal}
	return best

func consider(delta: float, evidence: Vector3, motivated: bool) -> void:
	# Attachment does not require a player clue: she seeks high ground at rest too.
	cooldown = maxf(0, cooldown - delta)
	_reject_seconds -= delta
	if _reject_seconds <= 0:
		_rejected.clear()
	if cooldown > 0 or active():
		return
	if brain.has_method("should_keep_ground_pursuit") and bool(brain.call("should_keep_ground_pursuit")):
		return
	scan_timer -= delta
	if scan_timer > 0:
		return
	scan_timer = 0.5
	var entry := find_ceiling_entry(1.8)
	if entry.is_empty():
		return
	wall_normal = entry.normal
	normal = wall_normal
	wall_travel_sign = 1.0
	phase = Phase.WALL
	elapsed = 0
	ceiling_elapsed = 0
	winding_up = false
	pouncing = false
	brain.velocity = Vector3.ZERO

func step(delta: float, evidence: Vector3, memory_valid: bool) -> void:
	wants_to_travel = false
	if not ensure_body_clear(): return
	elapsed += delta
	landing_recovery = maxf(0, landing_recovery - delta)
	spider_jump_cooldown = maxf(0.0, spider_jump_cooldown - delta)
	wall_transition_lockout = maxf(0.0, wall_transition_lockout - delta)
	_horizontal_commit_remaining = maxf(0.0, _horizontal_commit_remaining - delta)
	_spider_recent_timer -= delta
	if _spider_recent_timer <= 0.0:
		_spider_recent.clear()
	if _spider_retreating:
		_step_spider_retreat(delta)
		return
	if spider_settling > 0.0:
		spider_settling = maxf(0.0, spider_settling - delta)
		if not _launch_support_exists(brain.global_basis.y.normalized()):
			spider_settling = 0.0
			phase = Phase.DROP
		brain.velocity = Vector3.ZERO
		return
	if _release_remaining > 0.0:
		_release_remaining = maxf(0.0, _release_remaining - delta)
		_sweep_motion(_release_direction * delta * 1.4)
		brain.velocity = _release_direction * 1.4
		return
	if spider_winding_up:
		_step_spider_windup(delta)
		return
	if spider_leaping:
		_step_spider_leap(delta)
		return
	if corner_active or phase == Phase.DROP:
		if _center().distance_to(_transition_progress_position) > 0.12:
			_transition_progress_position = _center()
			_transition_stall = 0.0
		else:
			_transition_stall += delta
		if _transition_stall > 1.5:
			recover_blocked_transition()
			_transition_stall = 0.0
	else:
		_transition_stall = 0.0
	if corner_active:
		wants_to_travel = true
		if _corner_kind == 0:
			_step_ceiling_wall_corner(delta)
		else:
			_step_wall_horizontal_corner(delta)
		return
	if phase == Phase.DROP:
		winding_up = false
		if pouncing:
			_step_pounce(delta)
		else:
			_drop(delta)
		if phase == Phase.GROUND:
			cooldown = 2.0
			landing_recovery = 0.35
		return
	var center := _center()
	# A church balustrade is 1.08 m above its adjoining balcony. While crossing
	# its cap, retain support on the lower slab instead of treating that step as
	# empty air halfway through the climb.
	var support_distance := 2.2 if _horizontal_commit_remaining > 0.0 else ATTACHMENT_REACH
	var support := _attachment_support(center, normal, support_distance)
	if support.is_empty():
		if phase == Phase.WALL and _wall_to_horizontal(Vector3.UP * wall_travel_sign, delta):
			return
		phase = Phase.DROP
		return
	_last_support_position = support.position
	if phase == Phase.CEILING:
		normal = support.normal
	var direction := Vector3.UP * wall_travel_sign if phase == Phase.WALL else (evidence - center).slide(Vector3.UP).slide(normal).normalized()
	if phase == Phase.CEILING and _horizontal_commit_remaining > 0.0:
		direction = _horizontal_commit_direction.slide(normal).normalized()
	if phase == Phase.WALL:
		var roof := _ray(center, center + Vector3.UP * 1.05)
		if wall_travel_sign > 0.0 and wall_transition_lockout <= 0.0 and _structural(roof) and roof.normal.y < -0.65:
			phase = Phase.CEILING
			normal = roof.normal
			# Clear the wall before pursuing sideways. Otherwise the forward probe
			# selects that same wall while the body is still turning onto the roof.
			_horizontal_commit_direction = wall_normal.slide(normal).normalized()
			_horizontal_commit_remaining = 0.65
			wall_transition_lockout = 0.65
			corner_transitions += 1
			return
	else:
		ceiling_elapsed += delta
		var distance := (evidence - center).slide(Vector3.UP).length()
		if _horizontal_commit_remaining <= 0.0 and (not memory_valid or distance < 1.5):
			direction = Vector3.ZERO
		# Acquire once and lock the attack destination before leaving the roof.
		if not winding_up and ceiling_elapsed > 1.2 and distance < 4.5 and center.y - evidence.y > 1.8 and brain.global_basis.y.normalized().dot(normal) > 0.98 and brain.call("can_ceiling_pounce"):
			winding_up = true
			windup_time = 0.0
			pounce_aim = evidence + Vector3.UP * 0.85 + Vector3(brain.get("_evidence_velocity")) * 0.2
		if winding_up:
			direction = Vector3.ZERO
			windup_time += delta
			if windup_time >= 0.55:
				_begin_pounce()
				return
		if (normal.y > 0.65 or wall_transition_lockout <= 0.0) and brain.global_basis.y.normalized().dot(normal) > 0.98 and direction.length_squared() > 0.01 and _try_concave_wall(center, direction):
			return
		# Look beyond a complete church rail (24 cm deep). A shorter probe can
		# mistake the underside of the balustrade for more ceiling and drive the
		# capsule straight into its fascia instead of recognizing the corner.
		var next := _attachment_support(center + direction * 0.92, normal, support_distance)
		if next.is_empty():
			if direction.length_squared() > 0.01 and _ceiling_to_wall(direction, support, delta):
				return
			# A free edge with no solid vertical face is a perch, not empty air.
			direction = Vector3.ZERO
	wants_to_travel = direction.length_squared() > 0.01
	# Offset probes must correct only distance to the plane, never pull the body
	# sideways toward whichever shoulder ray happened to find a panel first.
	var plane_distance: float = (Vector3(support.position) - center).dot(normal)
	if _horizontal_commit_remaining > 0.0 and normal.y > 0.65:
		# Cross the rail before descending to the lower balcony. Following the
		# lower support immediately drove the capsule's rear into the rail cap.
		plane_distance = maxf(plane_distance, (_corner_face_position - center).dot(normal))
	var correction: Vector3 = normal * (plane_distance + _body_clearance()) * 4.0
	var travel_speed: float = brain.get_surface_hunt_speed(memory_valid)
	var motion := direction * travel_speed + correction.limit_length(1.8)
	var facing := direction if direction.length_squared() > 0.01 else brain.global_basis.z.slide(normal).normalized()
	if not _orient(normal, facing, delta):
		motion = normal * 0.65
	brain.velocity = motion
	var hit := _sweep_motion(motion * delta)
	if not hit.is_empty():
		# A blocked advance is still supported. Let the corner/escape controller
		# choose another route instead of letting go on every wall collision.
		brain.velocity = Vector3.ZERO

func _try_concave_wall(center: Vector3, direction: Vector3) -> bool:
	# On the balcony side of a rail, its inner face is in front of the body.
	# The convex-edge probe starts beyond the rail and sees the opposite face;
	# accepting that face attempted to walk through the entire balustrade.
	var face := _ray(center, center + direction * 0.95)
	if not _structural(face) or absf(face.normal.y) > 0.2 or face.normal.dot(direction) > -0.6: return false
	var above: Vector3 = face.position + face.normal * 0.12 + Vector3.UP * 0.35
	var continuation := _ray(above, above - face.normal * 0.3)
	if not _structural(continuation) or continuation.normal.dot(face.normal) < 0.9:
		# Near the top of a rail there is no face another 35 cm above. Its
		# continuous lower face is sufficient to climb the last part onto the cap.
		var below: Vector3 = face.position + face.normal * 0.12 + Vector3.DOWN * 0.35
		continuation = _ray(below, below - face.normal * 0.3)
		if not _structural(continuation) or continuation.normal.dot(face.normal) < 0.9: return false
	normal = face.normal.normalized()
	wall_normal = normal
	wall_travel_sign = 1.0
	phase = Phase.WALL
	elapsed = 0.0
	wall_transition_lockout = 0.3
	corner_transitions += 1
	brain.velocity = Vector3.ZERO
	return true

func _step_spider_windup(delta: float) -> void:
	if not _launch_support_exists(spider_launch_normal):
		_abort_spider_leap(spider_launch_normal)
		return
	spider_windup_time += delta
	brain.velocity = Vector3.ZERO
	if spider_windup_time < 0.42:
		return
	# Furniture or the player can enter the arc during anticipation. Revalidate
	# before takeoff while she can still cancel on her original support.
	var point := spider_target_position if spider_jump_attack else spider_target_position - spider_target_normal * support_offset()
	var fresh := JumpPlanner.build(self, point, spider_target_normal, _spider_plan.facing, spider_jump_attack)
	if fresh.is_empty() or (not spider_jump_attack and not _spider_landing_is_safe(point, spider_target_normal, _spider_plan.facing)):
		_cancel_spider_on_support()
		return
	_spider_plan = fresh
	spider_winding_up = false
	spider_leaping = true
	spider_flight_time = 0.0
	spider_jump_count += 1
	spider_flight_duration = fresh.duration
	spider_curve_start = fresh.start
	spider_curve_departure = fresh.departure
	spider_curve_approach = fresh.approach
	_spider_trace.assign([JumpPlanner.pose_at(fresh, 0.0)])
	_remember_spider_point(fresh.start)

func _apply_spider_pose(pose: Transform3D) -> void:
	brain.global_transform = Transform3D(pose.basis, pose.origin - pose.basis * collision.position)
	brain.force_update_transform()

func _step_spider_leap(delta: float) -> void:
	var before := _center()
	var next_time := minf(spider_flight_time + delta, spider_flight_duration)
	# Use the same swept trajectory at 30, 60 and 120 FPS. Small substeps also
	# check rotations against corners rather than rotating first into a wall.
	var subdivisions := maxi(1, int(ceil(delta / (1.0 / 120.0))))
	for index in range(1, subdivisions + 1):
		var time := lerpf(spider_flight_time, next_time, float(index) / subdivisions)
		var pose := JumpPlanner.pose_at(_spider_plan, clampf(time / spider_flight_duration, 0.0, 1.0))
		var from := collision.global_transform
		if not JumpPlanner.clear_segment(self, from, pose):
			if spider_jump_attack and not spider_hit:
				spider_hit = bool(brain.call("check_pounce_contact", from.origin, pose.origin, {}))
			_start_spider_retreat()
			return
		_apply_spider_pose(pose)
		_spider_trace.append(pose)
		if spider_jump_attack and not spider_hit:
			spider_hit = bool(brain.call("check_pounce_contact", from.origin, pose.origin, {}))
	spider_flight_time = next_time
	spider_velocity = (_center() - before) / maxf(delta, 0.001)
	brain.velocity = spider_velocity
	if spider_flight_time >= spider_flight_duration:
		if spider_jump_attack:
			_abort_spider_leap(Vector3.UP)
		elif not _finish_spider_landing(spider_target_normal, _spider_plan.facing):
			_start_spider_retreat()

func _remember_spider_point(point: Vector3) -> void:
	_spider_recent.append(point)
	if _spider_recent.size() > 8:
		_spider_recent.pop_front()
	_spider_recent_timer = 10.0

func _cancel_spider_on_support() -> void:
	if not _launch_support_exists(spider_launch_normal):
		_abort_spider_leap(spider_launch_normal)
		return
	spider_winding_up = false
	spider_leaping = false
	normal = spider_launch_normal
	phase = Phase.GROUND if normal.y > 0.65 else Phase.CEILING if normal.y < -0.65 else Phase.WALL
	spider_jump_cooldown = 0.8
	_remember_spider_point(spider_target_position)
	brain.call("on_spider_jump_aborted")

func _launch_support_exists(up: Vector3) -> bool:
	# Match climbing reach through anticipation, chained jumps and settling.
	# The shorter grounded probe still detects a platform removed underfoot.
	return not _attachment_support(_center(), up, ATTACHMENT_REACH if up.y < 0.65 else 1.15).is_empty()

func _start_spider_retreat() -> void:
	spider_leaping = false
	_spider_retreating = true
	spider_aborts += 1
	_remember_spider_point(spider_target_position)
	brain.velocity = Vector3.ZERO
	brain.call("on_spider_jump_aborted")

func _step_spider_retreat(delta: float) -> void:
	# Reverse only positions already visited safely. An unexpected moving object
	# must not leave the creature sideways against a pew after a failed jump.
	var distance_budget := delta * 9.0
	while _spider_trace.size() > 1 and distance_budget > 0.0:
		_spider_trace.pop_back()
		var previous: Transform3D = _spider_trace.back()
		if not JumpPlanner.clear_segment(self, collision.global_transform, previous):
			_spider_retreating = false
			_abort_spider_leap(spider_launch_normal)
			return
		distance_budget -= _center().distance_to(previous.origin)
		_apply_spider_pose(previous)
	if _spider_trace.size() <= 1:
		_spider_retreating = false
		_cancel_spider_on_support()

func _abort_spider_leap(obstacle_normal: Vector3 = Vector3.ZERO) -> void:
	spider_leaping = false
	spider_winding_up = false
	_spider_retreating = false
	spider_settling = 0.0
	spider_jump_cooldown = 0.8
	phase = Phase.DROP
	if obstacle_normal.length_squared() > 0.01:
		wall_normal = obstacle_normal.normalized()
	# Shed most lateral energy so the ordinary drop controller has room to turn
	# the capsule upright and place its feet before reaching the floor.
	brain.velocity = spider_velocity * 0.12 + Vector3.UP * 0.35
	var upright_facing := brain.global_basis.z.slide(Vector3.UP).normalized()
	if upright_facing.length_squared() > 0.01:
		_orient(Vector3.UP, upright_facing, 1.0)
	if brain.has_method("on_spider_jump_aborted"):
		brain.call("on_spider_jump_aborted")

func recover_blocked_transition() -> void:
	# If a connected corner still supports the current orientation, recover on
	# that surface first. A following escape jump can then choose a new route.
	var up := brain.global_basis.y.normalized()
	var support := _attachment_support(_center(), up, ATTACHMENT_REACH)
	if phase in [Phase.WALL, Phase.CEILING] and up.y < 0.65 and not support.is_empty():
		corner_active = false
		winding_up = false
		normal = support.normal.normalized()
		phase = Phase.CEILING if normal.y < -0.65 else Phase.WALL
		wall_normal = normal
		elapsed = 0.0
		_release_remaining = 0.0
		brain.velocity = Vector3.ZERO
		brain.call("on_spider_jump_aborted")
		return
	# A stalled corner/drop was previously exempt from every watchdog. Release
	# along a capsule-tested direction, then let the normal upright drop resume.
	corner_active = false
	pouncing = false
	winding_up = false
	phase = Phase.DROP
	_release_remaining = 0.0
	var directions: Array[Vector3] = [Vector3.UP, wall_normal, normal, brain.global_basis.x, -brain.global_basis.x, brain.global_basis.z, -brain.global_basis.z]
	for direction in directions:
		if direction.length_squared() < 0.01:
			continue
		var query := JumpPlanner.query_for(self, collision.global_transform)
		query.motion = direction.normalized() * 0.45
		if brain.get_world_3d().direct_space_state.cast_motion(query)[0] < 0.98:
			continue
		var destination := collision.global_transform
		destination.origin += query.motion
		if collision_guard.penetrates(self, destination): continue
		_release_direction = direction.normalized()
		_release_remaining = 0.34
		wall_normal = _release_direction
		break
	brain.call("on_spider_jump_aborted")

func _finish_spider_landing(landing_normal: Vector3, facing: Vector3) -> bool:
	landing_normal = landing_normal.normalized()
	facing = facing.slide(landing_normal).normalized()
	if facing.length_squared() < 0.01:
		facing = brain.global_basis.z.slide(landing_normal).normalized()
	# The landing is only committed once the real capsule can assume a feet-first
	# pose. If a dynamic obstacle entered the destination, abort into an upright
	# drop instead of setting a surface phase while the model is lying sideways.
	var point := _center() - landing_normal * support_offset()
	if not _spider_landing_is_safe(point, landing_normal, facing):
		return false
	if brain.global_basis.y.normalized().dot(landing_normal) < 0.995:
		return false
	if brain.global_basis.z.normalized().dot(facing) < 0.995:
		return false
	if landing_normal.y > 0.65:
		# Ground navigation expects an upright capsule. Check that final pose
		# around its centre too, including slightly inclined landing surfaces.
		var upright := JumpPlanner.aligned_basis(Vector3.UP, facing).scaled(brain.global_basis.get_scale())
		if not collision_guard.rotate_to(self, upright): return false
	spider_leaping = false
	spider_winding_up = false
	spider_jump_cooldown = 4.5 if spider_jump_attack else 3.0
	landing_recovery = 0.38
	spider_settling = 0.28
	_remember_spider_point(_center())
	normal = landing_normal
	wall_transition_lockout = 0.45
	elapsed = 0.0
	ceiling_elapsed = 0.0
	brain.velocity = Vector3.ZERO
	if landing_normal.y > 0.65:
		phase = Phase.GROUND
	elif landing_normal.y < -0.65:
		phase = Phase.CEILING
	else:
		phase = Phase.WALL
		wall_normal = landing_normal
		wall_travel_sign = 1.0
	if brain.has_method("on_spider_jump_landed"):
		brain.call("on_spider_jump_landed", spider_jump_reason, landing_normal, phase)
	return true

func _ceiling_to_wall(direction: Vector3, ceiling_support: Dictionary, delta: float) -> bool:
	# Probe just below the ceiling plane and back toward the edge. This catches
	# narrow balcony fascias and the solid collision envelope of balustrades;
	# probing at the actor centre would pass below both and leave her floating.
	var along := direction.normalized()
	var near_surface: Vector3 = ceiling_support.position - normal * 0.08
	var outside := near_surface + along * 0.92
	var face := _ray(outside, outside - along * 1.35)
	if not _structural(face) or absf(face.normal.y) > 0.35 or face.normal.dot(along) < 0.45:
		return false
	# Confirm continuation on at least one side of the lip. Balcony undersides
	# normally continue upward into their fascia/balustrade; wall cornices can
	# continue downward. Tiny trim and isolated ornaments fail both probes.
	# Start outside the widest visible rail cap. In the church the balustrade
	# protrudes 12 cm past the balcony fascia, so an 8 cm offset begins inside
	# its collision and Godot's ray query cannot report the face.
	var lower_start: Vector3 = face.position + face.normal * 0.24 + Vector3.DOWN * 0.36
	var lower := _ray(lower_start, lower_start - face.normal * 0.9)
	var upper_start: Vector3 = face.position + face.normal * 0.24 + Vector3.UP * 0.36
	var upper := _ray(upper_start, upper_start - face.normal * 0.9)
	var continues_lower: bool = _structural(lower) and lower.normal.dot(face.normal) >= 0.72
	var continues_upper: bool = _structural(upper) and upper.normal.dot(face.normal) >= 0.72
	if not continues_lower and not continues_upper:
		return false
	wall_normal = face.normal.normalized()
	# Use the outermost connected face as the rotation plane. Decorative rail
	# caps can project beyond the slab fascia; rotating around the recessed slab
	# plane would put the capsule a few centimetres inside the cap.
	var outer_offset := 0.0
	if continues_lower:
		outer_offset = maxf(outer_offset, (Vector3(lower.position) - Vector3(face.position)).dot(wall_normal))
	if continues_upper:
		outer_offset = maxf(outer_offset, (Vector3(upper.position) - Vector3(face.position)).dot(wall_normal))
	_corner_face_position = Vector3(face.position) + wall_normal * outer_offset
	var clearance_pose := collision.global_transform
	clearance_pose.origin = _corner_face_position + normal * _body_clearance() + wall_normal * _body_clearance()
	if not JumpPlanner.clear_segment(self, collision.global_transform, clearance_pose): return false
	_corner_face_normal = wall_normal
	_corner_old_normal = normal
	_corner_travel_sign = -1.0 if continues_lower else 1.0
	_corner_stage = 0
	_corner_kind = 0
	corner_active = true
	_horizontal_commit_remaining = 0.0
	brain.velocity = Vector3.ZERO
	return true

func _step_ceiling_wall_corner(delta: float) -> void:
	# Wrap in two bounded movements: first clear the lip while retaining the
	# ceiling orientation, then rotate in free space and approach the face. This
	# avoids both capsule penetration and a visible one-frame teleport.
	var target: Vector3
	if _corner_stage == 0:
		target = _corner_face_position + _corner_old_normal * _body_clearance() + _corner_face_normal * _body_clearance()
		var motion := (target - _center()).limit_length(CORNER_SPEED * delta)
		brain.velocity = motion / maxf(delta, 0.001)
		_sweep_motion(motion)
		if _center().distance_to(target) < 0.06:
			_corner_stage = 1
		return
	normal = _corner_face_normal
	var facing := Vector3.UP * _corner_travel_sign
	if not _orient(normal, facing, delta * 2.2):
		brain.velocity = Vector3.ZERO
		return
	target = _corner_face_position + normal * _body_clearance() + facing * 0.18
	var motion := (target - _center()).limit_length(CORNER_SPEED * delta)
	brain.velocity = motion / maxf(delta, 0.001)
	_sweep_motion(motion)
	if _center().distance_to(target) < 0.07 and brain.global_basis.y.normalized().dot(normal) > 0.985:
		phase = Phase.WALL
		wall_travel_sign = _corner_travel_sign
		wall_transition_lockout = 0.55
		corner_transitions += 1
		corner_active = false
		brain.velocity = Vector3.ZERO

func _wall_to_horizontal(direction: Vector3, delta: float) -> bool:
	# Reaching the physical end of a wall overrides the anti-oscillation timer;
	# the faster transition can reach a narrow rail cap before that timer ends.
	if _last_support_position == Vector3.ZERO:
		return false
	var along := direction.normalized()
	# Move the probe through the edge and cast back along the direction of
	# travel. Entering the solid by 8 cm lets it find narrow rail caps and slab
	# undersides without snapping to unrelated geometry across a gap.
	var beyond: Vector3 = _last_support_position - normal * 0.08 + along * 0.92
	var horizontal := _ray(beyond, beyond - along * 1.35)
	if not _structural(horizontal) or absf(horizontal.normal.y) < 0.65:
		return false
	var new_normal: Vector3 = horizontal.normal.normalized()
	# Cross behind the vertical face, onto the slab joined to the rail. Moving
	# along its outward normal only walks over the cap and immediately down the
	# same face again, which reads in game as being stuck on the balustrade.
	var across := (-normal).slide(new_normal).normalized()
	if across.length_squared() < 0.01:
		across = brain.global_basis.z.slide(new_normal).normalized()
	_corner_face_position = horizontal.position
	_corner_face_normal = new_normal
	_corner_old_normal = normal
	_corner_across = across
	_corner_stage = 0
	_corner_kind = 1
	corner_active = true
	brain.velocity = Vector3.ZERO
	return true

func _step_wall_horizontal_corner(delta: float) -> void:
	# Clear the end of the wall before rotating the capsule onto the horizontal
	# plane. Completing the phase early would cast the next support ray from
	# inside the rail cap and make the crawler fall.
	var target := _corner_face_position + _corner_old_normal * _body_clearance() + _corner_face_normal * _body_clearance()
	if _corner_stage == 0:
		var motion := (target - _center()).limit_length(CORNER_SPEED * delta)
		brain.velocity = motion / maxf(delta, 0.001)
		_sweep_motion(motion)
		if _center().distance_to(target) < 0.06:
			_corner_stage = 1
		return
	if _corner_stage == 1:
		if not _orient(_corner_face_normal, _corner_across, delta * 2.2):
			brain.velocity = Vector3.ZERO
			return
		if brain.global_basis.y.normalized().dot(_corner_face_normal) > 0.985:
			_corner_stage = 2
		return
	# Once horizontal, move over the narrow cap. Keeping the old wall offset
	# would leave the support ray outside the balustrade and cause an immediate fall.
	target = _corner_face_position + _corner_face_normal * _body_clearance() + _corner_across * 0.04
	var motion := (target - _center()).limit_length(CORNER_SPEED * delta)
	brain.velocity = motion / maxf(delta, 0.001)
	_sweep_motion(motion)
	if _center().distance_to(target) < 0.06:
		normal = _corner_face_normal
		phase = Phase.CEILING
		corner_transitions += 1
		wall_transition_lockout = 0.45
		_horizontal_commit_direction = _corner_across
		_horizontal_commit_remaining = 0.8
		corner_active = false
		brain.velocity = Vector3.ZERO

func _begin_pounce() -> void:
	winding_up = false
	pouncing = true
	pounce_hit = false
	pounce_time = 0.0
	phase = Phase.DROP
	var offset := pounce_aim - _center()
	var height := maxf(-offset.y, 0.1)
	var flight := clampf((-1.8 + sqrt(1.8 * 1.8 + 24.0 * height)) / 12.0, 0.2, 1.6)
	pounce_flight_duration = flight
	_pounce_from_rotation = brain.global_basis.orthonormalized().get_rotation_quaternion()
	_pounce_to_rotation = JumpPlanner.aligned_basis(Vector3.UP, offset.slide(Vector3.UP)).get_rotation_quaternion()
	pounce_velocity = (offset.slide(Vector3.UP) / flight).limit_length(5.5) + Vector3.DOWN * 1.8

func _step_pounce(delta: float) -> void:
	pounce_time += delta
	var before := _center()
	var facing := pounce_velocity.slide(Vector3.UP).normalized()
	if facing.length_squared() < 0.01:
		facing = brain.global_basis.z.slide(Vector3.UP).normalized()
	# Finish the somersault during the first part of the dive, instead of an
	# exponential turn that still had not finished when a low balcony hit ground.
	var turn := smoothstep(0.0, maxf(0.16, pounce_flight_duration * 0.58), pounce_time)
	var pose := Basis(_pounce_from_rotation.slerp(_pounce_to_rotation, turn)).scaled(brain.global_basis.get_scale())
	if not collision_guard.rotate_to(self, pose):
		pouncing = false
		brain.velocity = Vector3.ZERO
		return
	pounce_velocity.y = maxf(-18.0, pounce_velocity.y - 12.0 * delta)
	brain.velocity = pounce_velocity
	var hit := _sweep_motion(pounce_velocity * delta)
	if not pounce_hit:
		pounce_hit = bool(brain.call("check_pounce_contact", before, _center(), hit))
	if not hit.is_empty():
		var collider_id := int(hit.get("collider_id", 0))
		var obstacle := instance_from_id(collider_id) if collider_id != 0 else null
		if obstacle is CharacterBody3D:
			# A player's head is an impact, not a floor. Clear their capsule before
			# resuming ground navigation (which would mistake this height for stairs).
			var away: Vector3 = (_center() - obstacle.global_position).slide(Vector3.UP).normalized()
			if away.length_squared() < 0.01:
				away = brain.global_basis.x.normalized()
			pounce_velocity = away * 2.8 + Vector3.UP * 0.5
			return
		pouncing = false
		brain.velocity = Vector3.ZERO
		if hit.normal.y > 0.7 and brain.global_basis.y.normalized().y > 0.995:
			_land_on_floor(facing)
		else:
			wall_normal = hit.normal.slide(Vector3.UP).normalized()
	if pounce_time > 3.0:
		pouncing = false
