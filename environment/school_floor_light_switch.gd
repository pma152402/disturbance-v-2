extends StaticBody3D
## Interruptor de la escuela: controla solo las OmniLight3D de las zonas indicadas.

@export var floor_label: String = "PLANTA"
@export var target_roots: Array[NodePath] = []
@export var switch_on_sound: AudioStream
@export var switch_off_sound: AudioStream

@onready var rocker: MeshInstance3D = $Rocker
@onready var switch_audio: AudioStreamPlayer3D = $SwitchAudio

var _lights: Array[OmniLight3D] = []
var _initial_energy: Dictionary = {}
var _is_on := true
var _rocker_tween: Tween

func _ready() -> void:
	add_to_group(&"school_floor_light_switches")
	call_deferred(&"_cache_lights")

func get_interaction_key() -> Key:
	return KEY_F

func uses_switch_sound() -> bool:
	return false

func get_interaction_text(_player: Node = null) -> String:
	return ("F  APAGAR " if _is_on else "F  ENCENDER ") + floor_label

func interact(_player: Node = null) -> bool:
	if _lights.is_empty():
		_cache_lights()
	if _lights.is_empty():
		return false
	_is_on = not _is_on
	for light: OmniLight3D in _lights:
		if is_instance_valid(light):
			light.visible = _is_on
			if _is_on:
				light.light_energy = float(_initial_energy.get(light.get_instance_id(), light.light_energy))
	_set_rocker_position(_is_on, true)
	if switch_audio != null:
		switch_audio.stream = switch_on_sound if _is_on else switch_off_sound
		switch_audio.play()
	return true

func _cache_lights() -> void:
	_lights.clear()
	for root_path: NodePath in target_roots:
		# Las rutas se expresan desde el contenedor del interruptor, así el mismo
		# componente sirve tanto en la escena completa como dentro de una sala.
		var root := get_parent().get_node_or_null(root_path) if get_parent() != null else null
		if root == null:
			continue
		for candidate: Node in root.find_children("*", "OmniLight3D", true, false):
			var light := candidate as OmniLight3D
			if light != null and not _lights.has(light):
				_lights.append(light)
				_initial_energy[light.get_instance_id()] = light.light_energy

func _set_rocker_position(is_on: bool, animated: bool) -> void:
	if rocker == null:
		return
	var target_angle := deg_to_rad(-14.0 if is_on else 14.0)
	if _rocker_tween != null:
		_rocker_tween.kill()
	if not animated:
		rocker.rotation.x = target_angle
		return
	_rocker_tween = create_tween()
	_rocker_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_rocker_tween.tween_property(rocker, "rotation:x", target_angle, 0.075)
