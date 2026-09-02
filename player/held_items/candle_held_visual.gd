extends Node3D

signal state_changed(data: Dictionary)

@export var burn_duration := 840.0

@onready var wax: MeshInstance3D = $Wax
@onready var wick_root: Node3D = $WickRoot
@onready var flame: Node3D = $WickRoot/Flame
@onready var flame_mesh: MeshInstance3D = $WickRoot/Flame/FlameMesh
@onready var candle_light: OmniLight3D = $WickRoot/Flame/CandleLight
@onready var forward_light: SpotLight3D = $WickRoot/Flame/ForwardLight
@onready var smoke: Node3D = $WickRoot/Smoke

var lit := false
var burn_remaining := 840.0
var _state_emit_timer := 0.0
var _motion_strength := 0.0
var _run_extinguish_exposure := 0.0
var _extinguish_threshold := 7.0
var _flame_stress := 0.0
var _flame_rest_position := Vector3.ZERO
var _smoke_rest_position := Vector3.ZERO
var _smoke_timer := 0.0
var _flame_material: StandardMaterial3D


func _ready() -> void:
	_flame_rest_position = flame.position
	_smoke_rest_position = smoke.position
	_flame_material = flame_mesh.get_active_material(0).duplicate() as StandardMaterial3D
	flame_mesh.material_override = _flame_material
	_apply_visual_state()


func _process(delta: float) -> void:
	_update_smoke(delta)
	if not lit:
		return
	burn_remaining = maxf(0.0, burn_remaining - delta)
	_apply_visual_state()
	if _motion_strength > 0.72:
		_run_extinguish_exposure += delta * _motion_strength * 2.0
	else:
		_run_extinguish_exposure = maxf(0.0, _run_extinguish_exposure - delta * 2.1)
	var exposure_ratio := clampf(_run_extinguish_exposure / _extinguish_threshold, 0.0, 1.0)
	var target_stress := lerpf(0.62, 1.0, exposure_ratio) if _motion_strength > 0.72 else exposure_ratio * 0.25
	var stress_speed := 1.35 if target_stress > _flame_stress else 0.72
	_flame_stress = move_toward(_flame_stress, target_stress, delta * stress_speed)
	_animate_flame()
	if _run_extinguish_exposure >= _extinguish_threshold:
		extinguish(true)
		return
	_state_emit_timer += delta
	if burn_remaining <= 0.0:
		lit = false
		_apply_visual_state()
		_emit_state()
	elif _state_emit_timer >= 1.0:
		_state_emit_timer = 0.0
		_emit_state()


func configure_candle(data: Dictionary) -> void:
	burn_remaining = clampf(float(data.get("burn_remaining", burn_duration)), 0.0, burn_duration)
	lit = bool(data.get("lit", false)) and burn_remaining > 0.0
	_state_emit_timer = 0.0
	_run_extinguish_exposure = 0.0
	_flame_stress = 0.0
	_extinguish_threshold = randf_range(5.5, 8.5)
	_apply_visual_state()


func ignite() -> bool:
	if lit or burn_remaining <= 0.0:
		return false
	lit = true
	_run_extinguish_exposure = 0.0
	_flame_stress = 0.0
	_extinguish_threshold = randf_range(5.5, 8.5)
	_apply_visual_state()
	_emit_state()
	return true


func extinguish(show_smoke := false) -> bool:
	if not lit:
		return false
	lit = false
	_apply_visual_state()
	if show_smoke:
		_start_smoke()
	_emit_state()
	return true


func get_candle_data() -> Dictionary:
	return {"burn_remaining": burn_remaining, "lit": lit}


func set_motion_strength(value: float) -> void:
	_motion_strength = clampf(value, 0.0, 1.0)


func get_status_text(can_ignite: bool) -> String:
	if burn_remaining <= 0.0:
		return "VELA CONSUMIDA"
	if lit:
		return "VELA ENCENDIDA    Z  APAGAR"
	if can_ignite:
		return "VELA    RMB  ENCENDER"
	return "VELA    NECESITAS CERILLAS U OTRA VELA"


func _apply_visual_state() -> void:
	var ratio := clampf(burn_remaining / burn_duration, 0.0, 1.0)
	var height_ratio := maxf(ratio, 0.035)
	wax.scale.y = height_ratio
	wax.position.y = -0.16 * (1.0 - height_ratio)
	wick_root.position.y = -0.16 + 0.32 * height_ratio
	flame.visible = lit and burn_remaining > 0.0
	candle_light.visible = flame.visible
	if not flame.visible:
		flame.scale = Vector3.ONE
		flame.position = _flame_rest_position
		flame.rotation = Vector3.ZERO


func _animate_flame() -> void:
	var time := Time.get_ticks_msec() * 0.001
	var calm_flicker := sin(time * 8.7) * 0.07 + sin(time * 15.3 + 1.1) * 0.035
	var wind_flutter := sin(time * 24.0) * 0.09 * _flame_stress
	var danger := smoothstep(0.68, 1.0, _flame_stress)
	var danger_blink := (sin(time * 18.0) * 0.5 + 0.5) * danger
	var size_factor := maxf(0.22, (1.0 + calm_flicker + wind_flutter) * lerpf(1.0, 0.38, _flame_stress))
	flame.scale = Vector3(size_factor * (1.0 + calm_flicker * 0.35), size_factor, size_factor)
	flame.position = _flame_rest_position
	flame.rotation.z = sin(time * 16.0) * 0.09 - _flame_stress * 0.58
	flame.rotation.x = sin(time * 21.0 + 0.8) * 0.052 * (0.3 + _flame_stress)
	_flame_material.albedo_color = Color(1.0, lerpf(0.58, 0.28, danger_blink), 0.06, lerpf(0.92, 0.48, danger_blink))
	_flame_material.emission = Color(1.0, lerpf(0.24, 0.08, danger_blink), 0.015, 1.0)
	candle_light.light_color = Color(1.0, lerpf(0.52, 0.24, danger_blink), 0.12, 1.0)
	candle_light.light_energy = (2.25 + calm_flicker * 2.15 - _flame_stress * 0.42) * lerpf(1.0, 0.62, danger_blink)
	forward_light.light_color = candle_light.light_color
	forward_light.light_energy = (1.9 + calm_flicker * 0.95) * lerpf(1.0, 0.68, danger_blink)


func _start_smoke() -> void:
	_smoke_timer = 2.2
	smoke.visible = true
	smoke.position = _smoke_rest_position
	smoke.scale = Vector3.ONE * 0.55


func _update_smoke(delta: float) -> void:
	if _smoke_timer <= 0.0:
		return
	_smoke_timer = maxf(0.0, _smoke_timer - delta)
	var progress := 1.0 - _smoke_timer / 2.2
	smoke.position = _smoke_rest_position + Vector3(sin(progress * 8.0) * 0.018, progress * 0.18, 0.0)
	smoke.scale = Vector3.ONE * lerpf(0.55, 1.45, progress)
	if _smoke_timer <= 0.0:
		smoke.visible = false


func _emit_state() -> void:
	state_changed.emit(get_candle_data())
