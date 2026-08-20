extends OmniLight3D

@export var base_energy := 3.0
@export var flicker_speed := 5.0
@export_range(0.0, 1.0, 0.01) var flicker_strength := 0.42
@export var phase_offset := 0.0
@export var blackout_min_duration := 0.22
@export var blackout_max_duration := 0.58
@export var fixture_path: NodePath

var _time := 0.0
var _noise := FastNoiseLite.new()
var _blackout_remaining := 0.0
var _blackout_cooldown := 0.0
var _fixture_material: StandardMaterial3D
var _fixture_is_dark := false


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 0.48
	light_energy = base_energy
	var fixture := get_node_or_null(fixture_path) as MeshInstance3D
	if fixture:
		_fixture_material = fixture.get_active_material(0).duplicate() as StandardMaterial3D
		fixture.set_surface_override_material(0, _fixture_material)


func _process(delta: float) -> void:
	_time += delta * flicker_speed
	_blackout_cooldown = maxf(0.0, _blackout_cooldown - delta)

	if _blackout_remaining > 0.0:
		_blackout_remaining -= delta
		light_energy = 0.0
		_set_fixture_dark(true)
		return

	var sample := _noise.get_noise_1d(_time + phase_offset)
	if sample < -0.43 and _blackout_cooldown <= 0.0:
		_blackout_remaining = randf_range(blackout_min_duration, blackout_max_duration)
		_blackout_cooldown = _blackout_remaining + randf_range(0.65, 1.5)
		light_energy = 0.0
		_set_fixture_dark(true)
		return

	_set_fixture_dark(false)
	var target_energy := base_energy * (1.0 + sample * flicker_strength)
	light_energy = lerpf(light_energy, maxf(0.04, target_energy), minf(delta * 14.0, 1.0))


func _set_fixture_dark(should_be_dark: bool) -> void:
	if not _fixture_material or _fixture_is_dark == should_be_dark:
		return
	_fixture_is_dark = should_be_dark
	_fixture_material.emission_enabled = not should_be_dark
	_fixture_material.albedo_color = (
		Color(0.008, 0.008, 0.009, 1.0)
		if should_be_dark
		else Color(1.0, 0.82, 0.5, 1.0)
	)
