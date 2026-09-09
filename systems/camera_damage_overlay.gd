class_name CameraDamageOverlay
extends CanvasLayer

## Capa de dano persistente para una vida de tres golpes.
## 0 = camara intacta, 1 = grietas leves, 2 = grietas graves,
## 3 = cristal destruido durante el golpe mortal.
## Es una capa 2D del viewport principal: el SubViewport de la cinta solo captura
## World3D, por lo que este dano nunca queda grabado.

@export_category("Texturas de dano")
@export var first_hit_texture: Texture2D:
	set(value):
		first_hit_texture = value
		_refresh_texture()
@export var second_hit_texture: Texture2D:
	set(value):
		second_hit_texture = value
		_refresh_texture()
@export var fatal_hit_texture: Texture2D:
	set(value):
		fatal_hit_texture = value
		_refresh_texture()

@export_category("Texturas de sangre")
@export var first_hit_blood_texture: Texture2D:
	set(value):
		first_hit_blood_texture = value
		_refresh_texture()
@export var second_hit_blood_texture: Texture2D:
	set(value):
		second_hit_blood_texture = value
		_refresh_texture()
@export var fatal_hit_blood_texture: Texture2D:
	set(value):
		fatal_hit_blood_texture = value
		_refresh_texture()

@export_category("Presentacion")
@export_range(0.0, 1.0, 0.01) var overlay_opacity := 1.0
@export_range(0.0, 0.5, 0.01) var impact_fade_seconds := 0.12
@export_group("Sangre")
@export_range(0.0, 1.0, 0.01) var first_hit_blood_opacity := 0.46
@export_range(0.0, 1.0, 0.01) var second_hit_blood_opacity := 0.56
@export_range(0.0, 1.0, 0.01) var fatal_hit_blood_opacity := 0.62
@export_group("Legibilidad bajo el filtro")
@export_range(1.0, 2.5, 0.05) var first_hit_brightness := 2.5
@export_range(0.0, 0.35, 0.01) var first_hit_shadow_lift := 0.32
@export_range(1.0, 2.0, 0.05) var first_hit_alpha_boost := 2.0
@export_range(1.0, 2.5, 0.05) var second_hit_brightness := 2.5
@export_range(0.0, 0.35, 0.01) var second_hit_shadow_lift := 0.35
@export_range(1.0, 2.0, 0.05) var second_hit_alpha_boost := 2.0
@export_range(1.0, 2.5, 0.05) var fatal_hit_brightness := 1.7
@export_range(0.0, 0.35, 0.01) var fatal_hit_shadow_lift := 0.18
@export_range(0.0, 1.0, 0.05) var first_hit_postfilter_readability := 0.95
@export_range(0.0, 1.0, 0.05) var second_hit_postfilter_readability := 0.90
@export_range(0.0, 1.0, 0.05) var fatal_hit_postfilter_readability := 0.68

@onready var cracks: TextureRect = $Cracks
@onready var blood: TextureRect = $Blood
@onready var impact_flash: ColorRect = $ImpactFlash

var _damage_level := 0
var _fade_tween: Tween


func _ready() -> void:
	_refresh_texture()


func set_damage_level(hit_count: int, animate := true) -> void:
	var next_level := clampi(hit_count, 0, 3)
	if next_level == _damage_level and is_instance_valid(cracks):
		return
	_damage_level = next_level
	_refresh_texture()
	if animate and _damage_level > 0:
		_play_impact_reveal()


func get_damage_level() -> int:
	return _damage_level


func clear_damage(animate := false) -> void:
	set_damage_level(0, animate)


func _refresh_texture() -> void:
	if not is_instance_valid(cracks):
		return
	match _damage_level:
		1:
			cracks.texture = first_hit_texture
			blood.texture = first_hit_blood_texture
		2:
			cracks.texture = second_hit_texture
			blood.texture = second_hit_blood_texture
		3:
			cracks.texture = fatal_hit_texture
			blood.texture = fatal_hit_blood_texture
		_:
			cracks.texture = null
			blood.texture = null
	cracks.visible = cracks.texture != null
	cracks.modulate.a = overlay_opacity
	blood.visible = blood.texture != null
	blood.modulate.a = _blood_opacity_for_level()
	_apply_crack_brightness()


func _play_impact_reveal() -> void:
	if not is_instance_valid(cracks) or not cracks.visible:
		return
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	var flash_alpha := 0.48 if _damage_level == 1 else (0.38 if _damage_level == 2 else 0.58)
	var kick_strength := 12.0 if _damage_level == 1 else (9.0 if _damage_level == 2 else 16.0)
	offset = Vector2(
		randf_range(-kick_strength, kick_strength),
		randf_range(-kick_strength * 0.65, kick_strength * 0.65)
	)
	impact_flash.color.a = flash_alpha
	cracks.modulate.a = 1.0
	if blood.visible:
		blood.modulate.a = minf(_blood_opacity_for_level() + 0.12, 1.0)
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(self, "offset", Vector2.ZERO, maxf(impact_fade_seconds, 0.14))
	_fade_tween.tween_property(impact_flash, "color:a", 0.0, 0.22)
	_fade_tween.tween_property(cracks, "modulate:a", overlay_opacity, 0.12)
	if blood.visible:
		_fade_tween.tween_property(blood, "modulate:a", _blood_opacity_for_level(), 0.16)


func _blood_opacity_for_level() -> float:
	match _damage_level:
		1: return first_hit_blood_opacity
		2: return second_hit_blood_opacity
		3: return fatal_hit_blood_opacity
	return 0.0


func _apply_crack_brightness() -> void:
	if not is_instance_valid(cracks) or not cracks.material is ShaderMaterial:
		return
	var material := cracks.material as ShaderMaterial
	var brightness := fatal_hit_brightness
	var shadow_lift := fatal_hit_shadow_lift
	var alpha_boost := 1.0
	var white_mix := 0.10 if _damage_level == 3 else 0.0
	var tint_mix := 0.12 if _damage_level == 3 else 0.0
	var edge_thickness := 1.0
	var postfilter_readability := fatal_hit_postfilter_readability
	if _damage_level == 1:
		brightness = first_hit_brightness
		shadow_lift = first_hit_shadow_lift
		alpha_boost = first_hit_alpha_boost
		white_mix = 0.18
		tint_mix = 0.96
		edge_thickness = 6.0
		postfilter_readability = first_hit_postfilter_readability
	elif _damage_level == 2:
		brightness = second_hit_brightness
		shadow_lift = second_hit_shadow_lift
		alpha_boost = second_hit_alpha_boost
		white_mix = 0.18
		tint_mix = 0.94
		edge_thickness = 5.0
		postfilter_readability = second_hit_postfilter_readability
	material.set_shader_parameter(&"crack_brightness", brightness)
	material.set_shader_parameter(&"shadow_lift", shadow_lift)
	material.set_shader_parameter(&"alpha_boost", alpha_boost)
	material.set_shader_parameter(&"white_mix", white_mix)
	material.set_shader_parameter(&"tint_mix", tint_mix)
	material.set_shader_parameter(&"edge_thickness", edge_thickness)
	material.set_shader_parameter(&"postfilter_readability", postfilter_readability)
