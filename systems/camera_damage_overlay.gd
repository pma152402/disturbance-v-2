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
@export var first_hit_settled_texture: Texture2D:
	set(value):
		first_hit_settled_texture = value
		_refresh_texture()
@export var second_hit_texture: Texture2D:
	set(value):
		second_hit_texture = value
		_refresh_texture()
@export var second_hit_settled_texture: Texture2D:
	set(value):
		second_hit_settled_texture = value
		_refresh_texture()
@export var fatal_hit_texture: Texture2D:
	set(value):
		fatal_hit_texture = value
		_refresh_texture()

@export_category("Presentacion")
@export_range(0.0, 1.0, 0.01) var overlay_opacity := 0.92
@export_range(0.0, 0.5, 0.01) var impact_fade_seconds := 0.12
@export_range(0.0, 1.0, 0.01) var impact_frame_seconds := 0.16
@export_range(1.0, 2.5, 0.05) var crack_brightness := 1.45
@export_range(0.0, 0.35, 0.01) var crack_shadow_lift := 0.12

@onready var cracks: TextureRect = $Cracks

var _damage_level := 0
var _fade_tween: Tween


func _ready() -> void:
	_refresh_texture()


func set_damage_level(hit_count: int, animate := true) -> void:
	var next_level := clampi(hit_count, 0, 3)
	if next_level == _damage_level and is_instance_valid(cracks):
		return
	_damage_level = next_level
	if animate and _damage_level > 0:
		_play_impact_sequence()
	else:
		_refresh_texture()


func get_damage_level() -> int:
	return _damage_level


func clear_damage(animate := false) -> void:
	set_damage_level(0, animate)


func _refresh_texture() -> void:
	if not is_instance_valid(cracks):
		return
	match _damage_level:
		1:
			cracks.texture = first_hit_settled_texture if first_hit_settled_texture != null else first_hit_texture
		2:
			cracks.texture = second_hit_settled_texture if second_hit_settled_texture != null else second_hit_texture
		3:
			cracks.texture = fatal_hit_texture
		_:
			cracks.texture = null
	cracks.visible = cracks.texture != null
	cracks.modulate.a = overlay_opacity
	_apply_crack_brightness()


func _play_impact_sequence() -> void:
	if not is_instance_valid(cracks):
		return
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	var impact_texture := _get_impact_texture()
	var settled_texture := _get_settled_texture()
	cracks.texture = impact_texture
	cracks.visible = impact_texture != null
	_apply_crack_brightness()
	if not cracks.visible:
		return
	cracks.modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if impact_fade_seconds > 0.0:
		_fade_tween.tween_property(cracks, "modulate:a", overlay_opacity, impact_fade_seconds)
	else:
		cracks.modulate.a = overlay_opacity
	if settled_texture != null and settled_texture != impact_texture:
		_fade_tween.tween_interval(impact_frame_seconds)
		_fade_tween.tween_callback(func() -> void: cracks.texture = settled_texture)


func _get_impact_texture() -> Texture2D:
	match _damage_level:
		1: return first_hit_texture
		2: return second_hit_texture
		3: return fatal_hit_texture
	return null


func _get_settled_texture() -> Texture2D:
	match _damage_level:
		1: return first_hit_settled_texture if first_hit_settled_texture != null else first_hit_texture
		2: return second_hit_settled_texture if second_hit_settled_texture != null else second_hit_texture
		3: return fatal_hit_texture
	return null


func _apply_crack_brightness() -> void:
	if not is_instance_valid(cracks) or not cracks.material is ShaderMaterial:
		return
	var material := cracks.material as ShaderMaterial
	material.set_shader_parameter(&"crack_brightness", crack_brightness)
	material.set_shader_parameter(&"shadow_lift", crack_shadow_lift)
