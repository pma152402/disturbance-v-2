extends AnimatableBody3D

const DoorSoundStream := preload("res://sounds/interactions/door_open_close_sound.mp3")
const DOOR_CLOSE_START := 3.72
const DOOR_OPEN_END := 3.66

@export_range(70.0, 110.0, 1.0) var open_angle_degrees := 90.0
@export_range(0.05, 1.5, 0.01) var transition_time := 0.58
@export var panel_half_width := 0.98
@export_range(-1.0, 1.0, 1.0) var panel_direction := 1.0
@export_range(-1.0, 1.0, 1.0) var forced_open_sign := 0.0
@export_range(0.0, 110.0, 1.0) var positive_open_angle_degrees := 0.0
@export_range(0.0, 110.0, 1.0) var negative_open_angle_degrees := 0.0
@export_category("Audio")
@export_range(-40.0, 6.0, 0.5) var volumen_apertura_db := -15.5
@export_range(-40.0, 6.0, 0.5) var volumen_cierre_db := -37.0

@onready var panel_collision: CollisionShape3D = $PanelCollision
@onready var door_sound: AudioStreamPlayer3D = $DoorSound

var _is_open := false
var _is_animating := false
var _open_sign := 1.0
var _active_tween: Tween
var _last_interactor: Node3D
var _collision_restore_token := 0
var _sound_play_token := 0


func _ready() -> void:
	door_sound.stream = DoorSoundStream


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(_player: Node) -> String:
	return "F  CERRAR PUERTA" if _is_open else "F  ABRIR PUERTA"


func is_open() -> bool:
	return _is_open


func interact(player: Node) -> bool:
	if _is_animating:
		return true

	if not _is_open:
		_open_sign = _get_open_sign(player)
	_last_interactor = player as Node3D if player is Node3D else null
	_is_open = not _is_open
	_play_door_sound(_is_open)
	_animate_to(_open_sign * deg_to_rad(_get_open_angle()) if _is_open else 0.0)
	return true

func ensure_open_for_npc(actor: Node) -> bool:
	# NPCs only request an open passage. Reusing interact() while closed keeps
	# locked-door checks in derived scripts, but never toggles an open door shut.
	if _is_open:
		return true
	return interact(actor)


func get_npc_traversal_portal() -> Dictionary:
	var portal_root := get_parent() as Node3D
	if not is_instance_valid(portal_root):
		return {"center": global_position, "normal": global_basis.z.normalized(), "open_wait": transition_time * 0.25}
	return {
		"center": portal_root.global_position,
		"normal": portal_root.global_basis.z.normalized(),
		"open_wait": transition_time * 0.25,
	}


func _play_door_sound(opening: bool) -> void:
	_sound_play_token += 1
	var token := _sound_play_token
	door_sound.volume_db = volumen_apertura_db if opening else volumen_cierre_db
	door_sound.pitch_scale = randf_range(0.95, 1.05)
	door_sound.play(0.0 if opening else DOOR_CLOSE_START)
	if opening:
		_stop_opening_sound_at_split(token)


func _stop_opening_sound_at_split(token: int) -> void:
	await get_tree().create_timer(DOOR_OPEN_END / maxf(door_sound.pitch_scale, 0.01)).timeout
	if token == _sound_play_token and _is_open and is_instance_valid(door_sound):
		door_sound.stop()


func _get_open_sign(player: Node) -> float:
	if not is_zero_approx(forced_open_sign):
		return signf(forced_open_sign)
	if not player is Node3D:
		return 1.0
	var player_3d := player as Node3D
	var panel_center := global_position + global_basis.x * panel_half_width * panel_direction
	var player_side := (player_3d.global_position - panel_center).dot(global_basis.z)
	if absf(player_side) < 0.01:
		return 1.0
	# Positive rotation moves the free edge toward local -Z, away from a player on local +Z.
	return signf(player_side) * panel_direction


func _get_open_angle() -> float:
	if _open_sign > 0.0 and positive_open_angle_degrees > 0.0:
		return positive_open_angle_degrees
	if _open_sign < 0.0 and negative_open_angle_degrees > 0.0:
		return negative_open_angle_degrees
	return open_angle_degrees


func _animate_to(target_angle: float) -> void:
	_is_animating = true
	_collision_restore_token += 1
	panel_collision.set_deferred("disabled", true)
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(self, "rotation:y", target_angle, transition_time)
	_active_tween.finished.connect(func() -> void:
		rotation.y = target_angle
		_is_animating = false
		_restore_collision_when_clear(_collision_restore_token)
	)


func _restore_collision_when_clear(token: int) -> void:
	while token == _collision_restore_token and _player_intersects_panel():
		await get_tree().physics_frame
	if token == _collision_restore_token and is_instance_valid(panel_collision):
		panel_collision.set_deferred("disabled", false)


func _player_intersects_panel() -> bool:
	if not is_instance_valid(_last_interactor):
		return false
	var local_player := to_local(_last_interactor.global_position)
	var distance_along_panel := local_player.x * panel_direction
	# Margen extra para la capsula del jugador: no reactivar una puerta cerrada
	# mientras su cuerpo siga dentro del panel o apenas haya cruzado el marco.
	return (
		distance_along_panel > -0.45
		and distance_along_panel < panel_half_width * 2.0 + 0.45
		and absf(local_player.z) < 0.7
		and local_player.y > -0.4
		and local_player.y < 2.8
	)
