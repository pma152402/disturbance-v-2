extends StaticBody3D

@export var lamp_group: StringName = &"living_room_ceiling_lamp"
@export var assigned_lamps: Array[NodePath] = []
@export var switch_on_sound: AudioStream
@export var switch_off_sound: AudioStream

@onready var rocker: MeshInstance3D = $Rocker
@onready var switch_audio: AudioStreamPlayer3D = $SwitchAudio

var _rocker_tween: Tween


func _ready() -> void:
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


func interact(_player: Node = null) -> bool:
	var lamps := _get_controlled_lamps()
	if lamps.is_empty():
		return false
	var now_on := not _are_all_lamps_on(lamps)
	for lamp: Node in lamps:
		lamp.call("set_lamp_enabled", now_on)
	_set_rocker_position(now_on, true)
	_play_switch_sound(now_on)
	return true


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
	if not assigned_lamps.is_empty():
		for lamp_path: NodePath in assigned_lamps:
			var lamp := get_node_or_null(lamp_path)
			if lamp != null and lamp.has_method("set_lamp_enabled"):
				controlled.append(lamp)
		return controlled
	var lamps := get_tree().get_nodes_in_group(lamp_group)
	for lamp: Node in lamps:
		if not lamp is Node3D:
			continue
		var lamp_3d := lamp as Node3D
		if _belongs_to_this_controller(lamp_3d.global_position):
			controlled.append(lamp)
	controlled.sort_custom(func(a: Node, b: Node) -> bool:
		return global_position.distance_squared_to((a as Node3D).global_position) < global_position.distance_squared_to((b as Node3D).global_position)
	)
	return controlled


func _belongs_to_this_controller(lamp_position: Vector3) -> bool:
	# Planta superior: un interruptor controla las dos lámparas de arriba.
	if global_position.y > 4.2:
		return lamp_position.y > 6.0
	# Salón: la lámpara situada en el ala derecha de la planta baja.
	if global_position.x > 0.0:
		return lamp_position.y < 6.0 and lamp_position.x > 3.0
	# Pasillo central inferior: las dos lámparas alineadas cerca de X = 0.
	return lamp_position.y < 6.0 and lamp_position.x <= 3.0


func _are_all_lamps_on(lamps: Array[Node]) -> bool:
	for lamp: Node in lamps:
		if not bool(lamp.get("is_on")):
			return false
	return true
