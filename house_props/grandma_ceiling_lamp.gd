extends Node3D

@onready var warm_light: OmniLight3D = $GentleWarmGlow
@onready var downward_halo: SpotLight3D = $DownwardHalo
@onready var glowing_bulb: MeshInstance3D = $WarmBulb
@onready var flicker_sound: AudioStreamPlayer3D = $FlickerSound

var is_on := false
var _requested_on := false


func _ready() -> void:
	add_to_group(&"house_power_consumers")
	set_lamp_enabled(false)


func _process(_delta: float) -> void:
	if not is_on:
		return
	var base_energy := float(warm_light.get("base_energy"))
	var flicker_ratio := warm_light.light_energy / maxf(base_energy, 0.001)
	downward_halo.light_energy = 3.2 * flicker_ratio


func set_lamp_enabled(enabled: bool) -> void:
	_requested_on = enabled
	refresh_house_power()


func refresh_house_power() -> void:
	var enabled := _requested_on and _house_power_available()
	is_on = enabled
	warm_light.visible = enabled
	warm_light.set_process(enabled)
	downward_halo.visible = enabled
	glowing_bulb.visible = true
	_set_bulb_visual(enabled)
	if not enabled and flicker_sound.has_method(&"stop_flicker"):
		flicker_sound.call(&"stop_flicker")
	if enabled:
		warm_light.light_energy = float(warm_light.get("base_energy"))
		downward_halo.light_energy = 3.2


func _set_bulb_visual(enabled: bool) -> void:
	var material := glowing_bulb.get_active_material(0) as StandardMaterial3D
	if material == null:
		return
	material.emission_enabled = enabled
	material.albedo_color = Color(1.0, 0.82, 0.5, 1.0) if enabled else Color(0.34, 0.30, 0.23, 1.0)


func _house_power_available() -> bool:
	var panels := get_tree().get_nodes_in_group(&"house_power_panel")
	if panels.is_empty():
		return true
	return bool(panels[0].call(&"is_house_power_available"))


func toggle_lamp() -> bool:
	set_lamp_enabled(not _requested_on)
	return _requested_on


func get_requested_lamp_state() -> bool:
	return _requested_on
