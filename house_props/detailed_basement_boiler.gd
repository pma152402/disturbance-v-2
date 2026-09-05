@tool
extends StaticBody3D

signal boiler_state_changed(previous_state: BoilerState, new_state: BoilerState)
signal puzzle_completed

const MinigameScene := preload("res://boiler_minigame.tscn")
const GameplaySounds := preload("res://sounds/gameplay_sound_factory.gd")

enum BoilerState { OFF, RUNNING, CLOGGED }

@export_range(0.0, 100.0, 1.0) var temperature_percent := 0.0
# true: activa el puzle fisico. false: carga directamente el resultado resuelto.
var boiler_puzzle_enabled := false
@export_range(0.1, 10.0, 0.1) var temperature_response_speed := 2.8
@export_range(1.0, 60.0, 1.0) var needle_spring_strength := 30.0
@export_range(1.0, 20.0, 0.5) var needle_damping := 8.5
@export_category("Audio")
@export_range(-40.0, 6.0, 0.5) var volumen_controles_db := -3.0
@export_category("Estado")
@export var boiler_state: BoilerState = BoilerState.CLOGGED:
	get:
		return _boiler_state
	set(value):
		_change_boiler_state(value)

@onready var gauge_needle_pivot: Node3D = $GaugeNeedlePivot
@onready var gauge_color_sectors: MeshInstance3D = $GaugeColorSectors
@onready var firebox_smoke: CPUParticles3D = _find_primary_smoke_emitter()
@onready var firebox_smoke_leak: CPUParticles3D = get_node_or_null("FireboxSmokeLeak") as CPUParticles3D

const GAUGE_COLD_ANGLE := deg_to_rad(90.0)
const GAUGE_HOT_ANGLE := deg_to_rad(-90.0)
const GREEN_END_PERCENT := 12.5
const YELLOW_END_PERCENT := 41.6667
const ORANGE_END_PERCENT := 70.8333
const GAUGE_SECTOR_COLORS := [
	Color(0.015, 0.92, 0.075, 1.0),
	Color(1.0, 0.9, 0.025, 1.0),
	Color(1.0, 0.275, 0.01, 1.0),
	Color(1.0, 0.012, 0.008, 1.0),
]

var _running_smoke_ramp: Gradient
var _clogged_smoke_ramp: Gradient
var _boiler_state: BoilerState = BoilerState.CLOGGED
var _minigame_active := false
var _puzzle_completed := false
var _active_player: Node
var _active_layer: CanvasLayer
var _player_was_processing_input := true
var _player_was_processing_physics := true
var _control_audio: AudioStreamPlayer3D
var _water_valve: Node
var _air_intake_valve: Node
var _air_outlet_valve: Node
var _valves_discovered := false
var _needle_temperature := 0.0
var _needle_velocity := 0.0
var _target_temperature := 48.0


func _find_primary_smoke_emitter() -> CPUParticles3D:
	var emitter := get_node_or_null("FireboxSmoke") as CPUParticles3D
	if emitter == null:
		emitter = get_node_or_null("ChimneySmoke") as CPUParticles3D
	return emitter


func _ready() -> void:
	set_process(Engine.is_editor_hint() or boiler_puzzle_enabled)
	_build_gauge_color_sectors()
	_create_smoke_ramps()
	if boiler_puzzle_enabled:
		_apply_boiler_state()
	else:
		# Evita incluso un fotograma de humo antes de localizar las valvulas.
		temperature_percent = 9.0
		_set_runtime_boiler_state(BoilerState.OFF)
	_needle_temperature = temperature_percent
	_target_temperature = temperature_percent
	_control_audio = AudioStreamPlayer3D.new()
	_control_audio.max_distance = 12.0
	_control_audio.volume_db = volumen_controles_db
	_control_audio.stream = GameplaySounds.make_switch_click()
	add_child(_control_audio)
	call_deferred(&"_configure_boiler_puzzle")


func _exit_tree() -> void:
	if _minigame_active:
		_restore_player()


func get_interaction_key() -> Key:
	return KEY_F


func uses_switch_sound() -> bool:
	return false


func get_interaction_text(_player: Node = null) -> String:
	return ""


func interact(player: Node = null) -> bool:
	return false


func _start_minigame(player: Node) -> void:
	_minigame_active = true
	_active_player = player
	_change_boiler_state(BoilerState.CLOGGED)
	_active_layer = MinigameScene.instantiate() as CanvasLayer
	get_tree().current_scene.add_child(_active_layer)
	var minigame := _active_layer.get_node("BoilerMinigame")
	minigame.completed.connect(_on_minigame_completed)
	minigame.cancelled.connect(_on_minigame_cancelled)
	minigame.values_changed.connect(_on_minigame_values_changed)
	minigame.action_used.connect(_on_minigame_action_used)
	_lock_player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _lock_player() -> void:
	if not is_instance_valid(_active_player):
		return
	_player_was_processing_input = _active_player.is_processing_input()
	_player_was_processing_physics = _active_player.is_physics_processing()
	if _active_player.has_method(&"set_skill_check_active"):
		_active_player.call(&"set_skill_check_active", true)
	if _active_player is CharacterBody3D:
		(_active_player as CharacterBody3D).velocity = Vector3.ZERO
	_active_player.set_process_input(false)
	_active_player.set_physics_process(false)


func _restore_player() -> void:
	if is_instance_valid(_active_player):
		_active_player.set_process_input(_player_was_processing_input)
		_active_player.set_physics_process(_player_was_processing_physics)
		if _active_player.has_method(&"set_skill_check_active"):
			_active_player.call(&"set_skill_check_active", false)
	_active_player = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_minigame_values_changed(new_temperature: float, blockage: float) -> void:
	set_temperature(new_temperature)
	if blockage <= 0.0 and _boiler_state == BoilerState.CLOGGED:
		_change_boiler_state(BoilerState.RUNNING)


func _on_minigame_action_used(action: StringName) -> void:
	if not is_instance_valid(_control_audio):
		return
	match action:
		&"fuel": _control_audio.pitch_scale = 0.78
		&"vent": _control_audio.pitch_scale = 1.28
		&"pump": _control_audio.pitch_scale = 0.58
		_: _control_audio.pitch_scale = 0.42
	_control_audio.play()


func _on_minigame_completed() -> void:
	_puzzle_completed = true
	_minigame_active = false
	_change_boiler_state(BoilerState.RUNNING)
	set_temperature(28.0)
	_restore_player()
	if is_instance_valid(_active_layer):
		_active_layer.queue_free()
	_active_layer = null
	puzzle_completed.emit()


func _on_minigame_cancelled() -> void:
	_minigame_active = false
	_restore_player()
	if is_instance_valid(_active_layer):
		_active_layer.queue_free()
	_active_layer = null


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_apply_temperature_to_gauge()
		return
	if boiler_puzzle_enabled:
		_update_temperature_from_valves(delta)
	_update_needle_animation(delta)


func _configure_boiler_puzzle() -> void:
	_discover_physical_valves()
	if not _valves_discovered:
		return
	for valve in [_water_valve, _air_intake_valve, _air_outlet_valve]:
		valve.set("interaction_enabled", boiler_puzzle_enabled)
	if boiler_puzzle_enabled:
		_puzzle_completed = false
		return

	# Estado resuelto: cada rueda apunta exactamente a su valor correcto.
	for valve in [_water_valve, _air_intake_valve, _air_outlet_valve]:
		var correct_openness := float(valve.get("correct_percentage")) / 100.0
		valve.call(&"set_openness", correct_openness, true)
	var water := float(_water_valve.call(&"get_openness"))
	var air_intake := float(_air_intake_valve.call(&"get_openness"))
	var air_outlet := float(_air_outlet_valve.call(&"get_openness"))
	var solved_temperature := clampf(
		21.0 + air_intake * 65.0 - water * 30.0 - air_outlet * 25.0,
		0.0,
		GREEN_END_PERCENT
	)
	temperature_percent = solved_temperature
	_target_temperature = solved_temperature
	_needle_temperature = solved_temperature
	_needle_velocity = 0.0
	_apply_temperature_to_gauge(_needle_temperature)
	_set_runtime_boiler_state(BoilerState.OFF)
	_puzzle_completed = true
	# La caldera ya resuelta no cambia: la aguja y el humo pueden dormir.
	set_process(false)


func _discover_physical_valves() -> void:
	_water_valve = null
	_air_intake_valve = null
	_air_outlet_valve = null
	for candidate in get_tree().get_nodes_in_group(&"boiler_valve"):
		if not is_instance_valid(candidate):
			continue
		match int(candidate.get("valve_role")):
			0:
				_water_valve = candidate
			1:
				_air_intake_valve = candidate
			2:
				_air_outlet_valve = candidate
	_valves_discovered = (
		is_instance_valid(_water_valve)
		and is_instance_valid(_air_intake_valve)
		and is_instance_valid(_air_outlet_valve)
	)


func _update_temperature_from_valves(delta: float) -> void:
	if not _valves_discovered:
		_discover_physical_valves()
		if not _valves_discovered:
			return
	var water := float(_water_valve.call(&"get_openness"))
	var air_intake := float(_air_intake_valve.call(&"get_openness"))
	var air_outlet := float(_air_outlet_valve.call(&"get_openness"))

	# Equilibrio termico: el aire de entrada aviva el fuego; el agua y la
	# salida de gases extraen calor. La solucion 70/45/80 queda en el verde reducido.
	_target_temperature = clampf(
		21.0
		+ air_intake * 65.0
		- water * 30.0
		- air_outlet * 25.0,
		0.0,
		100.0
	)
	var response_weight := 1.0 - exp(-temperature_response_speed * delta)
	temperature_percent = lerpf(temperature_percent, _target_temperature, response_weight)
	_update_smoke_from_temperature()


func _update_smoke_from_temperature() -> void:
	# Verde: nada. Amarillo: humo ligero. Naranja/rojo: humo abundante.
	# Los pequeños márgenes al salir impiden parpadeos en las fronteras.
	if temperature_percent >= YELLOW_END_PERCENT and _boiler_state != BoilerState.CLOGGED:
		_set_runtime_boiler_state(BoilerState.CLOGGED)
	elif temperature_percent <= GREEN_END_PERCENT and _boiler_state != BoilerState.OFF:
		_set_runtime_boiler_state(BoilerState.OFF)
	elif _boiler_state == BoilerState.OFF and temperature_percent > GREEN_END_PERCENT + 1.5:
		_set_runtime_boiler_state(BoilerState.RUNNING)
	elif _boiler_state == BoilerState.CLOGGED and temperature_percent < YELLOW_END_PERCENT - 2.5:
		_set_runtime_boiler_state(BoilerState.RUNNING)


func _set_runtime_boiler_state(next_state: BoilerState) -> void:
	var previous_state := _boiler_state
	_boiler_state = next_state
	match _boiler_state:
		BoilerState.OFF:
			_stop_smoke(firebox_smoke)
			_stop_smoke(firebox_smoke_leak)
		BoilerState.RUNNING:
			_configure_running_smoke()
			_stop_smoke(firebox_smoke_leak)
		BoilerState.CLOGGED:
			_configure_clogged_smoke()
	if previous_state != _boiler_state:
		boiler_state_changed.emit(previous_state, _boiler_state)


func _update_needle_animation(delta: float) -> void:
	# Resorte amortiguado: responde enseguida, pero conserva peso e inercia.
	var safe_delta := minf(delta, 0.05)
	var error := temperature_percent - _needle_temperature
	_needle_velocity += error * needle_spring_strength * safe_delta
	_needle_velocity *= exp(-needle_damping * safe_delta)
	_needle_temperature = clampf(_needle_temperature + _needle_velocity * safe_delta, 0.0, 100.0)
	_apply_temperature_to_gauge(_needle_temperature)


func set_temperature(value: float) -> void:
	temperature_percent = clampf(value, 0.0, 100.0)
	_target_temperature = temperature_percent
	if Engine.is_editor_hint() or not is_node_ready():
		_needle_temperature = temperature_percent
		_apply_temperature_to_gauge(_needle_temperature)


func change_boiler_state(value: int) -> void:
	_change_boiler_state(clampi(value, BoilerState.OFF, BoilerState.CLOGGED))


func get_boiler_state() -> BoilerState:
	return _boiler_state


func _change_boiler_state(value: int) -> void:
	var next_state: BoilerState = value as BoilerState
	var previous_state := _boiler_state
	_boiler_state = next_state
	if is_node_ready():
		_apply_boiler_state()
		if previous_state != _boiler_state and not Engine.is_editor_hint():
			boiler_state_changed.emit(previous_state, _boiler_state)


func _create_smoke_ramps() -> void:
	_running_smoke_ramp = Gradient.new()
	_running_smoke_ramp.offsets = PackedFloat32Array([0.0, 0.16, 0.52, 1.0])
	_running_smoke_ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0),
		Color(1, 1, 1, 0.5),
		Color(1, 1, 1, 0.1),
		Color(1, 1, 1, 0),
	])
	_clogged_smoke_ramp = Gradient.new()
	_clogged_smoke_ramp.offsets = PackedFloat32Array([0.0, 0.1, 0.82, 1.0])
	_clogged_smoke_ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0),
		Color(1, 1, 1, 1),
		Color(1, 1, 1, 0.86),
		Color(1, 1, 1, 0),
	])


func _apply_boiler_state() -> void:
	if not is_instance_valid(firebox_smoke) or not is_instance_valid(firebox_smoke_leak):
		return
	match _boiler_state:
		BoilerState.OFF:
			set_temperature(0.0)
			_stop_smoke(firebox_smoke)
			_stop_smoke(firebox_smoke_leak)
		BoilerState.RUNNING:
			set_temperature(48.0)
			_configure_running_smoke()
			_stop_smoke(firebox_smoke_leak)
		BoilerState.CLOGGED:
			set_temperature(88.0)
			_configure_clogged_smoke()


func _stop_smoke(particles: CPUParticles3D) -> void:
	particles.restart()
	particles.emitting = false


func _configure_running_smoke() -> void:
	firebox_smoke.amount = 14
	firebox_smoke.lifetime = 1.65
	firebox_smoke.preprocess = 1.65
	firebox_smoke.randomness = 0.78
	firebox_smoke.emission_sphere_radius = 0.075
	firebox_smoke.direction = Vector3.UP
	firebox_smoke.spread = 10.0
	firebox_smoke.gravity = Vector3(0.018, 0.02, -0.01)
	firebox_smoke.initial_velocity_min = 0.14
	firebox_smoke.initial_velocity_max = 0.28
	firebox_smoke.scale_amount_min = 0.09
	firebox_smoke.scale_amount_max = 0.32
	firebox_smoke.color_ramp = _running_smoke_ramp
	firebox_smoke.emitting = true
	firebox_smoke.restart()


func _configure_clogged_smoke() -> void:
	firebox_smoke.amount = 80
	firebox_smoke.lifetime = 7.5
	firebox_smoke.preprocess = 7.5
	firebox_smoke.randomness = 0.9
	firebox_smoke.emission_sphere_radius = 0.24
	firebox_smoke.direction = Vector3.UP
	firebox_smoke.spread = 22.0
	firebox_smoke.gravity = Vector3(0.09, 0.08, -0.045)
	firebox_smoke.initial_velocity_min = 0.48
	firebox_smoke.initial_velocity_max = 0.95
	firebox_smoke.scale_amount_min = 1.15
	firebox_smoke.scale_amount_max = 3.8
	firebox_smoke.color_ramp = _clogged_smoke_ramp
	firebox_smoke.emitting = true
	firebox_smoke.restart()

	firebox_smoke_leak.amount = 28
	firebox_smoke_leak.lifetime = 4.2
	firebox_smoke_leak.preprocess = 4.2
	firebox_smoke_leak.randomness = 0.9
	firebox_smoke_leak.emission_sphere_radius = 0.16
	firebox_smoke_leak.direction = Vector3.UP
	firebox_smoke_leak.spread = 28.0
	firebox_smoke_leak.gravity = Vector3(0.06, 0.06, -0.03)
	firebox_smoke_leak.initial_velocity_min = 0.32
	firebox_smoke_leak.initial_velocity_max = 0.66
	firebox_smoke_leak.scale_amount_min = 0.75
	firebox_smoke_leak.scale_amount_max = 2.2
	firebox_smoke_leak.color_ramp = _clogged_smoke_ramp
	firebox_smoke_leak.emitting = true
	firebox_smoke_leak.restart()


func _build_gauge_color_sectors() -> void:
	if not is_instance_valid(gauge_color_sectors):
		return
	var sector_mesh := ArrayMesh.new()
	var outer_radius := 0.145
	var inner_radius := 0.026
	var start_angle := deg_to_rad(180.0)
	var end_angle := deg_to_rad(0.0)
	var total_width := start_angle - end_angle
	var sector_fractions: Array[float] = [0.125, 0.2916667, 0.2916667, 0.2916666]
	var subdivisions := 4
	var consumed_fraction := 0.0

	for sector_index in range(4):
		var surface_tool := SurfaceTool.new()
		surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sector_width: float = total_width * sector_fractions[sector_index]
		var sector_start := start_angle - total_width * consumed_fraction
		var sector_end: float = sector_start - sector_width
		for step in range(subdivisions):
			var amount_a := float(step) / float(subdivisions)
			var amount_b := float(step + 1) / float(subdivisions)
			var angle_a := lerpf(sector_start, sector_end, amount_a)
			var angle_b := lerpf(sector_start, sector_end, amount_b)
			var inner_a := Vector3(cos(angle_a), sin(angle_a), 0.0) * inner_radius
			var outer_a := Vector3(cos(angle_a), sin(angle_a), 0.0) * outer_radius
			var inner_b := Vector3(cos(angle_b), sin(angle_b), 0.0) * inner_radius
			var outer_b := Vector3(cos(angle_b), sin(angle_b), 0.0) * outer_radius
			surface_tool.set_normal(Vector3.FORWARD)
			surface_tool.add_vertex(inner_a)
			surface_tool.add_vertex(outer_a)
			surface_tool.add_vertex(outer_b)
			surface_tool.add_vertex(inner_a)
			surface_tool.add_vertex(outer_b)
			surface_tool.add_vertex(inner_b)
		surface_tool.commit(sector_mesh)
		var sector_material := StandardMaterial3D.new()
		sector_material.albedo_color = GAUGE_SECTOR_COLORS[sector_index]
		sector_material.roughness = 0.48
		sector_material.emission_enabled = true
		sector_material.emission = GAUGE_SECTOR_COLORS[sector_index]
		sector_material.emission_energy_multiplier = 0.32
		sector_mesh.surface_set_material(sector_index, sector_material)
		consumed_fraction += sector_fractions[sector_index]

	gauge_color_sectors.mesh = sector_mesh


func _apply_temperature_to_gauge(display_temperature := -1.0) -> void:
	if not is_instance_valid(gauge_needle_pivot):
		return
	var shown_temperature := temperature_percent if display_temperature < 0.0 else display_temperature
	var normalized_temperature := shown_temperature / 100.0
	gauge_needle_pivot.rotation.z = lerpf(
		GAUGE_COLD_ANGLE,
		GAUGE_HOT_ANGLE,
		normalized_temperature
	)
