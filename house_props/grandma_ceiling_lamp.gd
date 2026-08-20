extends Node3D

@onready var warm_light: OmniLight3D = $GentleWarmGlow
@onready var downward_halo: SpotLight3D = $DownwardHalo
@onready var glowing_bulb: MeshInstance3D = $WarmBulb

var is_on := true


func _process(_delta: float) -> void:
	if not is_on:
		return
	var base_energy := float(warm_light.get("base_energy"))
	var flicker_ratio := warm_light.light_energy / maxf(base_energy, 0.001)
	downward_halo.light_energy = 3.2 * flicker_ratio


func set_lamp_enabled(enabled: bool) -> void:
	is_on = enabled
	warm_light.visible = enabled
	warm_light.set_process(enabled)
	downward_halo.visible = enabled
	glowing_bulb.visible = enabled
	if enabled:
		warm_light.light_energy = float(warm_light.get("base_energy"))
		downward_halo.light_energy = 3.2


func toggle_lamp() -> bool:
	set_lamp_enabled(not is_on)
	return is_on
