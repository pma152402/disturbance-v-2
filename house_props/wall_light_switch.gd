extends StaticBody3D

const MAX_ACTIVE_WALL_LIGHTS := 3

@export var assigned_lamps: Array[NodePath] = []
@export var switch_on_sound: AudioStream
@export var switch_off_sound: AudioStream

@onready var rocker: MeshInstance3D = $Rocker
@onready var switch_audio: AudioStreamPlayer3D = $SwitchAudio

var _rocker_tween: Tween

# Historial comun para todos los interruptores de pared. Cada entrada es una
# bombilla, no un interruptor, por lo que un interruptor doble ocupa 2 huecos.
static var _active_wall_lamps: Array[WeakRef] = []


func _ready() -> void:
	add_to_group(&"wall_light_switches")
	# Las lamparas terminan su propio _ready primero; despues reflejamos su estado real.
	call_deferred(&"_sync_rocker_with_lamps")


func get_interaction_key() -> Key:
	return KEY_F


func uses_switch_sound() -> bool:
	# El componente reproduce su audio 3D; el jugador no debe duplicarlo.
	return false


func get_interaction_text(_player: Node = null) -> String:
	var lamps := _get_controlled_lamps()
	if lamps.is_empty():
		return "SIN LUCES ASIGNADAS"
	var all_on := _are_all_lamps_on(lamps)
	var noun := "LUCES" if lamps.size() > 1 else "LAMPARA"
	return ("F  APAGAR " if all_on else "F  ENCENDER ") + noun


func interact(player: Node = null) -> bool:
	var lamps := _get_controlled_lamps()
	if lamps.is_empty():
		return false
	var now_on := not _are_all_lamps_on(lamps)
	for lamp: Node in lamps:
		if now_on:
			_turn_on_and_remember(lamp)
		else:
			_forget_lamp(lamp)
			lamp.call("set_lamp_enabled", false)
		if now_on and player != null and player.has_method(&"notify_light_switched_on") and lamp is Node3D:
			player.call(&"notify_light_switched_on", lamp as Node3D)
	_set_rocker_position(now_on, true)
	_play_switch_sound(now_on)
	call_deferred(&"_sync_all_wall_switches")
	return true


func _turn_on_and_remember(lamp: Node) -> void:
	_forget_lamp(lamp)
	lamp.call(&"set_lamp_enabled", true)
	_active_wall_lamps.append(weakref(lamp))
	_cleanup_light_history()
	while _active_wall_lamps.size() > MAX_ACTIVE_WALL_LIGHTS:
		var oldest_ref: WeakRef = _active_wall_lamps.pop_front()
		var oldest_lamp := oldest_ref.get_ref() as Node
		if is_instance_valid(oldest_lamp):
			oldest_lamp.call(&"set_lamp_enabled", false)


func _forget_lamp(lamp: Node) -> void:
	for index in range(_active_wall_lamps.size() - 1, -1, -1):
		var remembered: Node = _active_wall_lamps[index].get_ref() as Node
		if not is_instance_valid(remembered) or remembered == lamp:
			_active_wall_lamps.remove_at(index)


func _cleanup_light_history() -> void:
	for index in range(_active_wall_lamps.size() - 1, -1, -1):
		if not is_instance_valid(_active_wall_lamps[index].get_ref()):
			_active_wall_lamps.remove_at(index)


func _sync_all_wall_switches() -> void:
	get_tree().call_group(&"wall_light_switches", &"_sync_rocker_with_lamps")


func _sync_rocker_with_lamps() -> void:
	var lamps := _get_controlled_lamps()
	_set_rocker_position(not lamps.is_empty() and _are_all_lamps_on(lamps), false)


func _set_rocker_position(is_on: bool, animated: bool) -> void:
	var target_angle := deg_to_rad(-14.0 if is_on else 14.0)
	if _rocker_tween != null:
		_rocker_tween.kill()
	if not animated:
		rocker.rotation.x = target_angle
		return
	_rocker_tween = create_tween()
	_rocker_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_rocker_tween.tween_property(rocker, "rotation:x", target_angle, 0.075)


func _play_switch_sound(is_on: bool) -> void:
	var selected_stream := switch_on_sound if is_on else switch_off_sound
	if selected_stream == null:
		return
	switch_audio.stream = selected_stream
	switch_audio.pitch_scale = randf_range(0.985, 1.015)
	switch_audio.play()


func _get_controlled_lamps() -> Array[Node]:
	var controlled: Array[Node] = []
	for lamp_path: NodePath in assigned_lamps:
		var lamp := get_node_or_null(lamp_path)
		if lamp != null and lamp.has_method("set_lamp_enabled"):
			controlled.append(lamp)
	return controlled


func _are_all_lamps_on(lamps: Array[Node]) -> bool:
	for lamp: Node in lamps:
		var requested_on := bool(lamp.call(&"get_requested_lamp_state")) if lamp.has_method(&"get_requested_lamp_state") else bool(lamp.get("is_on"))
		if not requested_on:
			return false
	return true
