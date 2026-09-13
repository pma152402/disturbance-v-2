extends Node3D
## Stationary ranged attack; independent from the original grandmother skin.
enum Phase { IDLE, WINDUP, SPRAY, DRIP }
const COOLDOWN := 90.0
const WINDUP_SECONDS := 0.65
const DRIP_SECONDS := 3.0
const MAX_RANGE := 7.0
const AIM_TURN_SPEED := 1.6
const MAX_HEAD_YAW := 1.4
const MAX_HEAD_PITCH := 1.35
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
	if _sense_timer <= 0.0:
		_sense_timer = 0.08
		if not _has_support():
			cancel()
			if brain.surface.active(): brain.surface.phase = brain.surface.Phase.DROP
			return false
		var target := _target_point()
		if _clear_target(target):
			_last_aim = target
			brain._evidence_position = brain._player.global_position
			brain._evidence_age = 0.0
			brain._sight_confirmed = true
	if phase != Phase.DRIP:
		var desired := _aim_at(_last_aim)
		var angle := aim_direction.angle_to(desired)
		# Limited tracking lets the player dodge; do not follow through walls.
		aim_direction = aim_direction.slerp(desired, minf(1.0, delta * AIM_TURN_SPEED / maxf(angle, 0.001))).normalized()
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
	var target := _target_point()
	var toward: Vector3 = target - effects.mouth_position()
	if toward.length() > MAX_RANGE or toward.length() < 0.6:
		return false
	# Only aim inside the neck's anatomical cone, in any attachment frame.
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
	_last_aim = _target_point()
	aim_direction = _aim_at(_last_aim)
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

func _aim_at(target: Vector3) -> Vector3:
	var from: Vector3 = effects.mouth_position()
	var flight_time: float = minf(from.distance_to(target), MAX_RANGE) / effects.JET_SPEED
	# Compensate the drop using world gravity even when hanging upside down.
	return _limited_direction(target + Vector3.UP * 4.9 * flight_time * flight_time - from)

func _clear_target(target: Vector3) -> bool:
	# Also trace from the physical body: a protruding head cannot shoot through
	# a wall even if the mouth happens to end up beyond the wall's collider.
	for origin: Vector3 in [brain.surface._center(), effects.mouth_position()]:
		var hit: Dictionary = brain.surface._ray(origin, target)
		if not hit.is_empty() and hit.collider != brain._player:
			return false
	return true

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
	_lens_contact_cooldown = 0.1
	# Vomit obscures the lens; it never uses the player's health/damage path.
	if brain._player.has_method("receive_camera_splatter"):
		brain._player.receive_camera_splatter(0.04)
