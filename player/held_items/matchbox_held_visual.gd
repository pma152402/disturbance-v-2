extends Node3D

signal state_changed(data: Dictionary)

@export var burn_duration := 30.0

@onready var box: MeshInstance3D = $Box
@onready var sleeve: MeshInstance3D = $Sleeve
@onready var match_root: Node3D = $MatchRoot
@onready var flame: Node3D = $MatchRoot/Flame
@onready var match_light: OmniLight3D = $MatchRoot/Flame/MatchLight
@onready var strike_glow: OmniLight3D = $StrikeGlow

var matches_remaining := 20
var match_out := false
var match_lit := false
var strikes_done := 0
var strikes_required := 2
var burn_remaining := 0.0
var _strike_tween: Tween


func _ready() -> void:
	_reset_match_visual()


func _process(delta: float) -> void:
	if not match_lit:
		return
	burn_remaining = maxf(0.0, burn_remaining - delta)
	var ratio := clampf(burn_remaining / burn_duration, 0.0, 1.0)
	match_root.scale.y = maxf(ratio, 0.035)
	match_light.light_energy = 2.15 + sin(Time.get_ticks_msec() * 0.028) * 0.22
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
	if not match_out or match_lit:
		return false
	strikes_done += 1
	_play_strike_animation()
	if strikes_done >= strikes_required:
		match_lit = true
		burn_remaining = burn_duration
		flame.visible = true
		match_light.visible = true
	_emit_state()
	return true


func holster_match() -> void:
	if match_out:
		_discard_current_match(true)


func get_status_text() -> String:
	if match_lit:
		return "CERILLAS %d    ENCENDIDA %.0fs    G  SOLTAR" % [matches_remaining, ceilf(burn_remaining)]
	if match_out:
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
	match_lit = false
	flame.visible = false
	match_light.visible = false
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
	_reset_match_visual()
	if emit_change:
		_emit_state()


func _reset_match_visual() -> void:
	_set_box_visible(true)
	match_root.visible = false
	match_root.scale = Vector3.ONE
	flame.visible = false
	match_light.visible = false
	strike_glow.visible = false


func _set_box_visible(value: bool) -> void:
	box.visible = value
	sleeve.visible = value


func _emit_state() -> void:
	state_changed.emit(get_matchbox_data())
