class_name CameraAudioFilter
extends Node

## Respuesta tonal de un micrófono pequeño de videocámara. Se instala una sola
## vez en Master: no ejecuta lógica por fotograma ni crea una voz de audio.

@export_category("Filtro de audio de cámara")
@export var filtro_activo := true
@export_range(40.0, 400.0, 5.0) var corte_graves_hz := 95.0
@export_range(3000.0, 20000.0, 100.0) var corte_agudos_hz := 9800.0

var _bus_index := -1
var _high_pass: AudioEffectHighPassFilter
var _low_pass: AudioEffectLowPassFilter


func _ready() -> void:
	_install_filter()


func _exit_tree() -> void:
	_remove_owned_effects()


func _install_filter() -> void:
	if not filtro_activo:
		return
	_bus_index = AudioServer.get_bus_index(&"Master")
	if _bus_index < 0:
		return
	_high_pass = AudioEffectHighPassFilter.new()
	_high_pass.resource_name = "CameraMicHighPass"
	_high_pass.cutoff_hz = corte_graves_hz
	AudioServer.add_bus_effect(_bus_index, _high_pass)
	_low_pass = AudioEffectLowPassFilter.new()
	_low_pass.resource_name = "CameraMicLowPass"
	_low_pass.cutoff_hz = corte_agudos_hz
	AudioServer.add_bus_effect(_bus_index, _low_pass)


func _remove_owned_effects() -> void:
	if _bus_index < 0:
		return
	for effect_index in range(AudioServer.get_bus_effect_count(_bus_index) - 1, -1, -1):
		var effect := AudioServer.get_bus_effect(_bus_index, effect_index)
		if effect == _high_pass or effect == _low_pass:
			AudioServer.remove_bus_effect(_bus_index, effect_index)
	_bus_index = -1
