extends Node3D
## Stationary ranged attack; independent from the original grandmother skin.
enum Phase { IDLE, WINDUP, SPRAY, DRIP }
const COOLDOWN := 90.0
const WINDUP_SECONDS := 0.65
const DRIP_SECONDS := 3.0
const MAX_RANGE := 14.0
const AIM_TURN_SPEED := 7.5
const MAX_HEAD_YAW := PI
const MAX_HEAD_PITCH := PI * 0.499
var phase := Phase.IDLE
var unlocked := false
var cooldown := 0.0
var elapsed := 0.0
var spray_duration := 9.0
var aim_direction := Vector3.BACK
var _lens_contact_cooldown := 0.0
var completed_bursts := 0
var brain: CharacterBody3D
var visual: Node3D
var effects: Node3D
var _stationary_transform := Transform3D.IDENTITY
var _sense_timer := 0.0
var _last_aim := Vector3.ZERO
var tracking_direction := Vector3.BACK
var head_roll := 0.0
var _aim_height_offset := Vector3.ZERO
var _aim_clock := 0.0
var _chaos_seed := 0.0

func setup(actor: CharacterBody3D, animator: Node3D) -> void:
	brain = actor
	visual = animator
	set_process(false)
	set_physics_process(false)
	effects = preload("res://enemies/crawler_vomit_effects.gd").new()
	effects.name = "VomitDroplets"
	add_child(effects)
	effects.setup(self, visual._head)

func stationary() -> bool:
	return phase != Phase.IDLE

func step(delta: float) -> bool:
	_lens_contact_cooldown = maxf(0.0, _lens_contact_cooldown - delta)
	cooldown = maxf(0.0, cooldown - delta)
	_sense_timer -= delta
	if stationary() and (brain.remain_still or not _player_alive()):
		cancel()
		return false
	if phase == Phase.IDLE:
		if _sense_timer <= 0.0:
			_sense_timer = 0.18
			if can_begin():
				_begin()
		return stationary()
	# Hold the attachment frame: neither gravity nor the four-second stuck
	# escape may interrupt the stream or the three-second dripping recovery.
	brain.global_transform = _stationary_transform
	brain.velocity = Vector3.ZERO
	brain._was_trying_to_move = false
	brain._idle_clock += delta
	brain._evidence_age += delta
	brain._attack_cooldown_timer = maxf(0.0, brain._attack_cooldown_timer - delta)
	brain._spider_stuck_elapsed = 0.0
	brain._spider_goal_stall = 0.0
	_aim_clock += delta
	if _sense_timer <= 0.0:
		_sense_timer = 0.08
		if not _has_support():
			cancel()
			if brain.surface.active(): brain.surface.phase = brain.surface.Phase.DROP
			return false
		var target := _visible_target()
		if target.is_finite():
			_aim_height_offset = target - _target_point()
			brain._evidence_position = brain._player.global_position
			brain._evidence_age = 0.0
			brain._sight_confirmed = true
	if phase != Phase.DRIP:
		# Active spraying relentlessly follows the player, including a circle
		# behind the planted creature. Visibility only updates normal AI memory;
		# actual projectile collision still stops the liquid at walls and doors.
		_last_aim = _target_point() + _aim_height_offset
		var lead: Vector3 = brain._player.velocity.limit_length(6.0) * 0.07
		var desired := _aim_at(_last_aim + lead)
		tracking_direction = _turn_toward(tracking_direction, desired, delta * AIM_TURN_SPEED)
		var chaotic := _chaotic_direction(tracking_direction)
		aim_direction = _turn_toward(aim_direction, chaotic, delta * 10.0)
	brain.gaze_position = effects.mouth_position() + aim_direction * 4.0
	elapsed += delta
	if phase == Phase.WINDUP and elapsed >= WINDUP_SECONDS:
		phase = Phase.SPRAY
		elapsed = 0.0
	elif phase == Phase.SPRAY and elapsed >= spray_duration:
		phase = Phase.DRIP
		elapsed = 0.0
	elif phase == Phase.DRIP and elapsed >= DRIP_SECONDS:
		phase = Phase.IDLE
		elapsed = 0.0
		completed_bursts += 1
		brain.begin_vomit_escape()
		return false
	return true

func _player_alive() -> bool:
	return is_instance_valid(brain._player) and not bool(brain._player.get("_monster_restart_pending"))

func can_begin() -> bool:
	if not unlocked or cooldown > 0.0 or not _player_alive() or brain.remain_still:
		return false
	if brain.dormant_until_door_opens and not brain._dormant_released:
		return false
	if brain._prey != brain._player or (not brain._sight_confirmed and brain._evidence_age > 0.6):
		return false
	if brain.current_state in [brain.State.ATTACK, brain.State.EAT] or brain._door_traversal_active or brain._spider_chain_remaining > 0:
		return false
	var surface = brain.surface
	if surface.spider_busy() or surface.pouncing or surface.winding_up or surface.corner_active or surface.phase == surface.Phase.DROP:
		return false
	var target := _visible_target()
	if not target.is_finite(): return false
	var toward: Vector3 = target - effects.mouth_position()
	if toward.length() > MAX_RANGE or toward.length() < 0.6:
		return false
	# The neck can turn fully around during this attack in any attachment frame.
	if _limited_direction(toward).dot(toward.normalized()) < 0.96:
		return false
	return _clear_target(target) and _has_support()

func _begin() -> void:
	phase = Phase.WINDUP
	elapsed = 0.0
	cooldown = COOLDOWN
	spray_duration = randf_range(6.0, 12.0)
	_lens_contact_cooldown = 0.0
	_stationary_transform = brain.global_transform
	_last_aim = _visible_target()
	if not _last_aim.is_finite(): _last_aim = _target_point()
	_aim_height_offset = _last_aim - _target_point()
	_aim_clock = 0.0
	_chaos_seed = randf_range(0.0, TAU)
	head_roll = 0.0
	aim_direction = _aim_at(_last_aim)
	tracking_direction = aim_direction
	brain.velocity = Vector3.ZERO
	brain._has_ceiling_goal = false
	brain._escape_walk_remaining = 0.0
	brain._spider_stuck_elapsed = 0.0
	brain._spider_goal_stall = 0.0
	effects.wake()

func cancel() -> void:
	phase = Phase.IDLE
	elapsed = 0.0
	brain._spider_stuck_elapsed = 0.0
	brain._spider_stuck_origin = brain.surface._center()
	brain._target_refresh_timer = 0.0
	effects.clear()

func _limited_direction(direction: Vector3) -> Vector3:
	var local := brain.global_basis.orthonormalized().inverse() * direction
	var yaw := clampf(atan2(local.x, local.z), -MAX_HEAD_YAW, MAX_HEAD_YAW)
	var pitch := clampf(-atan2(local.y, maxf(Vector2(local.x, local.z).length(), 0.001)), -MAX_HEAD_PITCH, MAX_HEAD_PITCH)
	return (brain.global_basis.orthonormalized() * (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)).z).normalized()

func _turn_toward(from: Vector3, toward: Vector3, radians: float) -> Vector3:
	var angle := from.angle_to(toward)
	if angle <= radians or angle < 0.0001: return toward
	var axis := from.cross(toward)
	# Exactly opposite directions have no unique slerp plane. Pick a stable
	# surface-relative axis so a sudden move behind her never stalls the head.
	if axis.length_squared() < 0.00001:
		axis = from.cross(brain.global_basis.y)
		if axis.length_squared() < 0.00001: axis = from.cross(brain.global_basis.x)
	return from.rotated(axis.normalized(), radians).normalized()

func _chaotic_direction(center: Vector3) -> Vector3:
	var strength := smoothstep(0.0, 0.22, elapsed) if phase == Phase.SPRAY else 0.0
	var t := _aim_clock
	var s := _chaos_seed
	var yaw := (sin(t * 5.3 + s) * 0.18 + sin(t * 11.7 + s * 1.7) * 0.065 + sin(t * 20.9) * 0.035) * strength
	var pitch := (sin(t * 6.7 + s * 0.6) * 0.10 + sin(t * 15.1 + s) * 0.055) * strength
	head_roll = (sin(t * 9.3 + s) * 0.10 + sin(t * 17.7) * 0.035) * strength
	var up := brain.global_basis.y.normalized()
	var side := up.cross(center)
	if side.length_squared() < 0.001: side = brain.global_basis.x
	return _limited_direction(center.rotated(up, yaw).rotated(side.normalized(), pitch))

func _aim_at(target: Vector3) -> Vector3:
	var from: Vector3 = effects.mouth_position()
	var offset := target - from
	var speed_squared: float = effects.JET_SPEED * effects.JET_SPEED
	var b := speed_squared - 9.8 * offset.y
	var discriminant := b * b - 9.8 * 9.8 * offset.length_squared()
	# Solve the low ballistic arc. The previous distance / speed estimate
	# undercompensated gravity noticeably at the new fourteen-metre range.
	var time_squared := pow(minf(offset.length(), MAX_RANGE) / effects.JET_SPEED, 2.0)
	if discriminant >= 0.0 and b > 0.0:
		time_squared = 2.0 * offset.length_squared() / maxf(0.001, b + sqrt(discriminant))
	return _limited_direction(offset + Vector3.UP * 4.9 * time_squared)

func _clear_target(target: Vector3) -> bool:
	# Guard the short body-to-mouth segment, not body-to-player: pews below
	# the head must not blind an otherwise clear shot. Climbing-only collision
	# envelopes are not opaque scenery and must not freeze target updates.
	if not mouth_is_clear(): return false
	var hit := _shot_ray(effects.mouth_position(), target)
	return hit.is_empty() or hit.collider == brain._player or brain._player.is_ancestor_of(hit.collider)

func _shot_ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, brain.collision_mask, [brain.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)

func mouth_is_clear() -> bool:
	return _shot_ray(brain.surface._center(), effects.mouth_position()).is_empty()

func _visible_target() -> Vector3:
	var torso := _target_point()
	# A player partly concealed behind a bench can still be seen at the head.
	for point: Vector3 in [torso, torso + Vector3.UP * 0.42, torso - Vector3.UP * 0.3]:
		if _clear_target(point): return point
	return Vector3.INF

func _target_point() -> Vector3:
	var body_shape := brain._player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	# Player origin is at capsule height, not at the feet. Aim inside its
	# physical torso rather than above the head at close range.
	return body_shape.global_position + Vector3.UP * 0.25 if body_shape != null else brain._player.global_position + Vector3.UP * 0.85

func _has_support() -> bool:
	var center: Vector3 = brain.surface._center()
	var hit: Dictionary = brain.surface._ray(center, center - brain.global_basis.y.normalized() * 1.1)
	return brain.surface._structural(hit) and hit.normal.dot(brain.global_basis.y.normalized()) > 0.5

func contact_player(collider: Object) -> void:
	if _lens_contact_cooldown > 0.0 or phase != Phase.SPRAY or collider != brain._player or not _player_alive():
		return
	_lens_contact_cooldown = 0.075
	# Vomit obscures the lens; it never uses the player's health/damage path.
	if brain._player.has_method("receive_camera_splatter"):
		brain._player.receive_camera_splatter(0.09)
