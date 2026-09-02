extends Node3D

signal state_changed(data: Dictionary)

@export var burn_duration := 30.0

@onready var box: MeshInstance3D = $Box
@onready var sleeve: MeshInstance3D = $Sleeve
@onready var match_root: Node3D = $MatchRoot
@onready var flame: Node3D = $MatchRoot/Flame
@onready var flame_mesh: MeshInstance3D = $MatchRoot/Flame/FlameMesh
@onready var match_light: OmniLight3D = $MatchRoot/Flame/MatchLight
@onready var forward_light: SpotLight3D = $MatchRoot/Flame/ForwardLight
@onready var smoke: Node3D = $MatchRoot/Smoke
@onready var strike_glow: OmniLight3D = $StrikeGlow

var matches_remaining := 20
var match_out := false
var match_lit := false
var strikes_done := 0
var strikes_required := 2
var burn_remaining := 0.0
var _strike_tween: Tween
var _motion_strength := 0.0
var _run_extinguish_exposure := 0.0
var _extinguish_threshold := 2.7
var _flame_stress := 0.0
var _flame_rest_position := Vector3.ZERO
var _smoke_rest_position := Vector3.ZERO
var _smoke_timer := 0.0
var _extinguishing := false
var _flame_material: StandardMaterial3D


func _ready() -> void:
	_flame_rest_position = flame.position
	_smoke_rest_position = smoke.position
	_flame_material = flame_mesh.get_active_material(0).duplicate() as StandardMaterial3D
	_flame_material.emission_enabled = true
	flame_mesh.material_override = _flame_material
	_reset_match_visual()


func _process(delta: float) -> void:
	_update_smoke(delta)
	if not match_lit:
		return
	burn_remaining = maxf(0.0, burn_remaining - delta)
	var ratio := clampf(burn_remaining / burn_duration, 0.0, 1.0)
	match_root.scale.y = maxf(ratio, 0.035)
	if _motion_strength > 0.72:
		_run_extinguish_exposure += delta * _motion_strength * 2.15
	else:
		_run_extinguish_exposure = maxf(0.0, _run_extinguish_exposure - delta * 2.25)
	var exposure_ratio := clampf(_run_extinguish_exposure / _extinguish_threshold, 0.0, 1.0)
	var target_stress := lerpf(0.58, 1.0, exposure_ratio) if _motion_strength > 0.72 else exposure_ratio * 0.22
	_flame_stress = move_toward(_flame_stress, target_stress, delta * (1.7 if target_stress > _flame_stress else 0.9))
	_animate_flame()
	if _run_extinguish_exposure >= _extinguish_threshold:
		_extinguish_from_wind()
		return
	if burn_remaining <= 0.0:
		_finish_match()


func configure_matchbox(data: Dictionary) -> void:
	matches_remaining = clampi(int(data.get("matches_remaining", 20)), 0, 20)
	_discard_current_match(false)


func draw_match() -> bool:
	if match_out or matches_remaining <= 0:
		return false
	matches_remaining -= 1
	match_out = true
	match_lit = false
	strikes_done = 0
	strikes_required = randi_range(2, 8)
	burn_remaining = 0.0
	match_root.scale = Vector3.ONE
	match_root.visible = true
	_set_box_visible(false)
	flame.visible = false
	match_light.visible = false
	_emit_state()
	return true


func strike_match() -> bool:
	if not match_out or match_lit or _extinguishing:
		return false
	strikes_done += 1
	_play_strike_animation()
	if strikes_done >= strikes_required:
		match_lit = true
		burn_remaining = burn_duration
		_run_extinguish_exposure = 0.0
		_flame_stress = 0.0
		_extinguish_threshold = randf_range(2.2, 3.4)
		flame.visible = true
		match_light.visible = true
		forward_light.visible = true
	_emit_state()
	return true


func holster_match() -> void:
	if match_out:
		_discard_current_match(true)


func get_status_text() -> String:
	if match_lit:
		return "CERILLAS %d    ENCENDIDA %.0fs    G  SOLTAR" % [matches_remaining, ceilf(burn_remaining)]
	if match_out:
		if _extinguishing:
			return "CERILLA APAGADA"
		return "CERILLAS %d    LMB  RASPAR    G  SOLTAR" % matches_remaining
	if matches_remaining <= 0:
		return "SIN CERILLAS    G  SOLTAR CAJA"
	return "CERILLAS %d    RMB  SACAR CERILLA    G  SOLTAR" % matches_remaining


func get_matchbox_data() -> Dictionary:
	return {"matches_remaining": matches_remaining}


func _play_strike_animation() -> void:
	if is_instance_valid(_strike_tween):
		_strike_tween.kill()
	strike_glow.visible = true
	strike_glow.light_energy = 1.8
	var rest_rotation := match_root.rotation
	_strike_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_strike_tween.tween_property(match_root, "rotation:z", rest_rotation.z - 0.42, 0.055)
	_strike_tween.tween_property(match_root, "rotation:z", rest_rotation.z, 0.09)
	_strike_tween.parallel().tween_property(strike_glow, "light_energy", 0.0, 0.12)
	_strike_tween.finished.connect(func() -> void: strike_glow.visible = false)


func _finish_match() -> void:
	_extinguishing = false
	match_lit = false
	flame.visible = false
	match_light.visible = false
	forward_light.visible = false
	match_root.visible = false
	_set_box_visible(true)
	match_out = false
	burn_remaining = 0.0
	_emit_state()


func _discard_current_match(emit_change: bool) -> void:
	match_out = false
	match_lit = false
	strikes_done = 0
	burn_remaining = 0.0
	_extinguishing = false
	_smoke_timer = 0.0
	_reset_match_visual()
	if emit_change:
		_emit_state()


func _reset_match_visual() -> void:
	_set_box_visible(true)
	match_root.visible = false
	match_root.scale = Vector3.ONE
	flame.scale = Vector3.ONE
	flame.position = _flame_rest_position
	flame.rotation = Vector3.ZERO
	flame.visible = false
	match_light.visible = false
	forward_light.visible = false
	smoke.visible = false
	strike_glow.visible = false


func _set_box_visible(value: bool) -> void:
	box.visible = value
	sleeve.visible = value


func set_motion_strength(value: float) -> void:
	_motion_strength = clampf(value, 0.0, 1.0)


func _animate_flame() -> void:
	var time := Time.get_ticks_msec() * 0.001
	var calm_flicker := sin(time * 8.7) * 0.07 + sin(time * 15.3 + 1.1) * 0.035
	var danger := smoothstep(0.68, 1.0, _flame_stress)
	var danger_blink := (sin(time * 18.0) * 0.5 + 0.5) * danger
	var size_factor := maxf(0.2, (1.0 + calm_flicker) * lerpf(1.0, 0.34, _flame_stress))
	flame.scale = Vector3(size_factor, size_factor, size_factor)
	flame.position = _flame_rest_position
	flame.rotation.z = sin(time * 16.0) * 0.1 - _flame_stress * 0.65
	_flame_material.albedo_color = Color(1.0, lerpf(0.58, 0.25, danger_blink), 0.05, lerpf(0.92, 0.46, danger_blink))
	_flame_material.emission = Color(1.0, lerpf(0.24, 0.07, danger_blink), 0.012, 1.0)
	match_light.light_color = Color(1.0, lerpf(0.52, 0.23, danger_blink), 0.12, 1.0)
	match_light.light_energy = (1.75 + calm_flicker * 2.0) * lerpf(1.0, 0.62, danger_blink)
	forward_light.light_color = match_light.light_color
	forward_light.light_energy = (1.45 + calm_flicker * 0.8) * lerpf(1.0, 0.68, danger_blink)


func _extinguish_from_wind() -> void:
	match_lit = false
	_extinguishing = true
	flame.visible = false
	match_light.visible = false
	forward_light.visible = false
	_smoke_timer = 1.7
	smoke.visible = true
	smoke.position = _smoke_rest_position
	smoke.scale = Vector3.ONE * 0.5
	_emit_state()


func _update_smoke(delta: float) -> void:
	if _smoke_timer <= 0.0:
		return
	_smoke_timer = maxf(0.0, _smoke_timer - delta)
	var progress := 1.0 - _smoke_timer / 1.7
	smoke.position = _smoke_rest_position + Vector3(sin(progress * 8.0) * 0.012, progress * 0.13, 0.0)
	smoke.scale = Vector3.ONE * lerpf(0.5, 1.15, progress)
	if _smoke_timer <= 0.0:
		smoke.visible = false
		_finish_match()


func _emit_state() -> void:
	state_changed.emit(get_matchbox_data())
