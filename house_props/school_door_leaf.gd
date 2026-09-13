extends AnimatableBody3D

const DoorSoundStream := preload("res://sounds/interactions/door_open_close_sound.mp3")
const DOOR_CLOSE_START := 3.72
const DOOR_OPEN_END := 3.66

@export var open_angle_degrees := 96.0
@export var open_sign := 1.0
@export var transition_time := 0.65
@export var panel_direction := 1.0
@export var panel_width := 1.19
@export_category("Audio")
@export_range(-40.0, 6.0, 0.5) var volumen_apertura_db := -7.5
@export_range(-40.0, 6.0, 0.5) var volumen_cierre_db := -6.0

@onready var panel_collision: CollisionShape3D = $PanelCollision

var _is_open := false
var _is_animating := false
var _active_tween: Tween
var _last_interactor: Node3D
var _restore_token := 0
var _sound_play_token := 0
var _door_sound: AudioStreamPlayer3D


func _ready() -> void:
	for sibling in get_parent().get_children():
		if sibling.get_script() == get_script():
			if sibling != self:
				return
			break
	add_to_group(&"npc_door")
	_door_sound = AudioStreamPlayer3D.new()
	_door_sound.name = "DoorSound"
	_door_sound.stream = DoorSoundStream
	_door_sound.unit_size = 2.0
	_door_sound.max_distance = 18.0
	_door_sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	add_child(_door_sound)


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(_player: Node) -> String:
	return "F  CERRAR PUERTA" if _is_open else "F  ABRIR PUERTA"


func interact(player: Node) -> bool:
	for leaf in get_parent().get_children():
		if leaf.get_script() == get_script() and leaf._is_animating:
			return true
	var opening := not _is_open
	# Keep the authored leaf signs for the normal approach, but mirror the
	# whole double-door set when the player pushes from the opposite side.
	var approach_multiplier := _approach_multiplier(player)
	for leaf in get_parent().get_children():
		if leaf.get_script() == get_script():
			leaf._play_door_sound(opening)
			break
	for leaf in get_parent().get_children():
		if leaf.get_script() == get_script():
			leaf._set_open(opening, player, approach_multiplier)
	return true


func _play_door_sound(opening: bool) -> void:
	if not is_instance_valid(_door_sound):
		return
	_sound_play_token += 1
	var token := _sound_play_token
	_door_sound.volume_db = volumen_apertura_db if opening else volumen_cierre_db
	_door_sound.pitch_scale = randf_range(0.97, 1.03)
	_door_sound.play(0.0 if opening else DOOR_CLOSE_START)
	if opening:
		_stop_opening_sound_at_split(token)


func _stop_opening_sound_at_split(token: int) -> void:
	await get_tree().create_timer(DOOR_OPEN_END / maxf(_door_sound.pitch_scale, 0.01)).timeout
	if token == _sound_play_token and _is_open and is_instance_valid(_door_sound):
		_door_sound.stop()


func ensure_open_for_npc(actor: Node) -> bool:
	return true if _is_open else interact(actor)


func get_npc_traversal_portal() -> Dictionary:
	var portal_root := get_parent() as Node3D
	if not is_instance_valid(portal_root):
		return {"center": global_position, "normal": global_basis.z.normalized(), "open_wait": transition_time * 0.25}
	return {
		"center": portal_root.global_position,
		"normal": portal_root.global_basis.z.normalized(),
		"open_wait": transition_time * 0.25,
	}


func _set_open(opening: bool, player: Node, approach_multiplier := 1.0) -> void:
	_is_open = opening
	_is_animating = true
	_last_interactor = player as Node3D
	_restore_token += 1
	panel_collision.set_deferred("disabled", true)
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	var target := deg_to_rad(open_angle_degrees) * open_sign * approach_multiplier if _is_open else 0.0
	_active_tween.tween_property(self, "rotation:y", target, transition_time)
	_active_tween.finished.connect(func() -> void:
		rotation.y = target
		_is_animating = false
		_restore_collision(_restore_token)
	)


func _approach_multiplier(actor: Node) -> float:
	if not is_instance_valid(actor) or not (actor is Node3D):
		return 1.0
	# The school door panels are authored in the local X/Y plane.  Local Z
	# therefore tells us which face was pushed.  A small dead zone avoids a
	# flip when the interaction point is exactly in the threshold.
	var local_actor := to_local((actor as Node3D).global_position)
	if absf(local_actor.z) < 0.12:
		return 1.0
	return -1.0 if local_actor.z > 0.0 else 1.0


func is_npc_passage_ready() -> bool:
	for leaf in get_parent().get_children():
		if leaf.get_script() == get_script() and (not leaf._is_open or leaf._is_animating):
			return false
	return _is_open


func _restore_collision(token: int) -> void:
	while token == _restore_token and _actor_in_panel():
		await get_tree().physics_frame
	if token == _restore_token:
		panel_collision.set_deferred("disabled", false)


func _actor_in_panel() -> bool:
	if not is_instance_valid(_last_interactor):
		return false
	var p := to_local(_last_interactor.global_position)
	return p.x * panel_direction > -0.45 and p.x * panel_direction < panel_width + 0.45 and absf(p.z) < 0.55 and p.y > -0.4 and p.y < 3.0
