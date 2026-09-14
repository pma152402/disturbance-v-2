extends "res://enemies/grandmother_crawler.gd"
## Humanoid, harmless observer; reuses crawler senses and retreats into cover.
signal dissolved

@export_group("Vulnerabilidad a la luz")
@export_range(2.0, 20.0, 0.1) var room_dissolve_seconds := 5.0
@export_range(1.5, 10.0, 0.05) var flashlight_dissolve_seconds := 1.5
@export_range(0.01, 0.5, 0.01) var minimum_light_exposure := 0.06
@export_range(1.0, 15.0, 0.25) var darkness_heal_seconds := 4.0
@export_range(2.5, 7.0, 0.1) var light_escape_speed := 4.5
var dissolution := 0.0
var light_pain := 0.0
var _dissolved := false
var _shadow_visual: Node3D
var _room_damage := 0.0
var _beam_damage := 0.0
var light_escape: RefCounted
@export_group("Acecho huidizo")
@export var stalking_distance := 7.5
@export var retreat_distance := 4.5
@export var stalking_speed := 0.65
@export var retreat_speed := 2.5
@export_group("Huida al mirarlo fijamente")
@export_range(1.0, 8.0, 0.25) var stare_activation_distance := 4.0
@export_range(0.5, 10.0, 0.1) var stare_escape_seconds := 4.0
@export_range(1.0, 10.0, 0.25) var stare_escape_speed_multiplier := 6.0
var upright_amount := 1.0
var humanoid_crouch := 0.0
var gaze_has_sight := false
var _fixed_gaze_position := Vector3.ZERO
var _gaze_timer := 0.0
var stalking: RefCounted
var _stance_collision: CollisionShape3D
var _stance_query := PhysicsShapeQueryParameters3D.new()

func _enter_tree() -> void:
	# Remove before children initialize: no hair mesh, animation or shader work.
	var hair := get_node_or_null("FloatingHair")
	if hair != null:
		remove_child(hair)
		hair.free()

func _create_shadow_coat() -> RefCounted:
	return preload("res://enemies/shadow_crawler_coat.gd").new()

func _ready() -> void:
	can_climb = false
	spider_jump_enabled = false
	obstacle_jump_enabled = false
	super._ready()
	_shadow_visual = get_node("EditableVisual")
	light_escape = preload("res://enemies/shadow_crawler_escape.gd").new(self)
	add_to_group(&"shadow_enemies")
	stalking = preload("res://enemies/shadow_crawler_stalking.gd").new(self)
	_stance_collision = CollisionShape3D.new()
	_stance_collision.name = "UprightClearance"
	var upper_shape := CapsuleShape3D.new()
	upper_shape.radius = 0.23
	upper_shape.height = 1.45
	_stance_collision.shape = upper_shape
	_stance_collision.position.y = 1.78
	add_child(_stance_collision)
	_stance_query.shape = upper_shape
	_stance_query.collision_mask = collision_mask | (1 << 19)
	_stance_query.exclude = [get_rid()]
	_stance_query.margin = 0.01

func _setup_vomit(_visual: Node3D) -> void:
	# Do not construct/register ranged effects for this harmless variant.
	pass

func can_begin_attack() -> bool:
	return false

func can_ceiling_pounce() -> bool:
	return false

func should_keep_ground_pursuit() -> bool:
	return false

func _update_spider_jump_behavior(_delta: float) -> void:
	# This variant remains bipedal; blocked routes are replanned on the ground.
	pass

func get_attention_position() -> Vector3:
	if stalking != null and stalking.sprint_remaining > 0.0:
		return global_position + global_basis.z * 4.0 + Vector3.UP * 1.6
	return _fixed_gaze_position if gaze_has_sight else gaze_position

func _update_fixed_gaze(delta: float) -> void:
	_gaze_timer -= delta
	if _gaze_timer > 0.0: return
	_gaze_timer = 0.1
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	gaze_has_sight = false
	if not is_instance_valid(_player): return
	var target := _player.global_position + Vector3.UP * 1.5
	var camera := _player.get_node_or_null("Head/Camera3D") as Camera3D
	if camera != null and camera.global_position.distance_to(_player.global_position) < 2.8:
		target = camera.global_position
	var origin: Vector3 = _shadow_visual._head.global_position
	if origin.distance_to(target) > maxf(dark_sight_distance, light_detection_distance): return
	var sight: Dictionary = surface._ray(origin, target)
	if not sight.is_empty() and sight.collider != _player: return
	gaze_has_sight = true
	_fixed_gaze_position = target

func face_shadow_attention(direction: Vector3, delta: float, responsiveness: float) -> void:
	var sprinting: bool = stalking != null and stalking.sprint_remaining > 0.0
	var facing := (_fixed_gaze_position - global_position).slide(Vector3.UP) if gaze_has_sight and not sprinting else direction
	if facing.length_squared() > 0.01:
		_turn_toward(atan2(facing.x, facing.z), delta, maxf(responsiveness, 24.0) if sprinting else responsiveness)

func get_surface_hunt_speed(_memory_valid: bool) -> float:
	if light_escape != null and light_escape.active:
		return maxf(climb_speed, light_escape_speed)
	return climb_speed if stalking != null and stalking.mode == stalking.Mode.RETREAT else stalking_speed

func _update_attack(_delta: float) -> void:
	_change_state(State.INVESTIGATE)

func check_pounce_contact(_from: Vector3, _to: Vector3, _contact: Dictionary = {}) -> bool:
	return false

func on_player_attack_landed(_target: Node3D, _hits: int) -> void:
	pass

func _make_breathing_sound() -> AudioStreamWAV:
	return null

func _make_footstep_sound() -> AudioStreamWAV:
	return null

func _make_chase_voice() -> AudioStreamWAV:
	return null

func _physics_process(delta: float) -> void:
	if _dissolved:
		return
	var sensor: Node3D = _shadow_visual.shadow_coat.light_sensor
	sensor.update(delta)
	_apply_light_damage(delta, sensor.room_exposure, sensor.flashlight_core_exposure)
	if _dissolved:
		return
	_update_upright_stance(delta)
	_update_fixed_gaze(delta)
	stalking.update_stare(delta)
	# Finish the pose before launch, leaving a short, fully open still moment.
	var opening_seconds := maxf(0.1, stare_escape_seconds - 0.25)
	_shadow_visual.shadow_coat.set_stare_progress(1.0 if stalking.sprint_remaining > 0.0 else stalking.stare_elapsed / opening_seconds, delta)
	if stalking.stare_elapsed > 0.0 and stalking.sprint_remaining <= 0.0:
		stalking.hold_charge(delta)
		return
	if stalking.sprint_remaining > 0.0 or not light_escape.step(delta, sensor):
		stalking.step(delta)

func _update_upright_stance(delta: float) -> void:
	_stance_query.transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 1.78, 0))
	var upright := get_world_3d().direct_space_state.intersect_shape(_stance_query, 1).is_empty()
	# Bend knees under a lintel, keeping the torso vertical and hands off the floor.
	humanoid_crouch = move_toward(humanoid_crouch, 0.0 if upright else 1.0, delta * 6.0)
	_stance_collision.position.y = 1.78 - humanoid_crouch * 0.65
	_stance_collision.disabled = false
	upright_amount = 1.0

func _apply_light_damage(delta: float, room: float, beam: float) -> void:
	if _dissolved:
		return
	var dt := maxf(delta, 0.0)
	if room >= minimum_light_exposure:
		_room_damage += dt * clampf(room / 0.4, 0.25, 1.0) / maxf(room_dissolve_seconds, 2.0)
	if beam >= minimum_light_exposure:
		_beam_damage += dt * clampf(beam, 0.4, 1.0) / maxf(flashlight_dissolve_seconds, 1.5)
	if room < minimum_light_exposure and beam < minimum_light_exposure:
		var recovery := dt / maxf(darkness_heal_seconds, 1.0)
		_room_damage = move_toward(_room_damage, 0.0, recovery)
		_beam_damage = move_toward(_beam_damage, 0.0, recovery)
	# Separate exposure budgets: a brief beam cannot finish off room-light damage,
	# and combining lamps with a flashlight cannot bypass its minimum duration.
	# Both damage budgets heal in shade; a dissolved creature cannot revive.
	dissolution = minf(1.0, maxf(_room_damage, _beam_damage))
	# Only damaging light hurts: the outer flashlight ring can scare it without
	# triggering convulsions. Pain eases after it escapes, even while still faded.
	var burning := room >= minimum_light_exposure or beam >= minimum_light_exposure
	var pain_target := lerpf(0.35, 1.0, dissolution) if burning else 0.0
	light_pain = lerpf(light_pain, pain_target, 1.0 - exp(-dt * (15.0 if burning else 5.0)))
	if light_pain < 0.001:
		light_pain = 0.0
	_shadow_visual.shadow_coat.set_dissolution(dissolution)
	if dissolution >= 1.0:
		_dissolved = true
		velocity = Vector3.ZERO
		collision_layer = 0
		collision_mask = 0
		if is_instance_valid(vomit):
			vomit.cancel()
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED
		dissolved.emit()
		queue_free()
