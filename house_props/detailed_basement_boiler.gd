@tool
extends StaticBody3D

signal boiler_state_changed(previous_state: BoilerState, new_state: BoilerState)

enum BoilerState { OFF, RUNNING, CLOGGED }

@export_range(0.0, 100.0, 1.0) var temperature_percent := 0.0
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
const GAUGE_SECTOR_COLORS := [
	Color(0.015, 0.92, 0.075, 1.0),
	Color(1.0, 0.9, 0.025, 1.0),
	Color(1.0, 0.275, 0.01, 1.0),
	Color(1.0, 0.012, 0.008, 1.0),
]

var _running_smoke_ramp: Gradient
var _clogged_smoke_ramp: Gradient
var _boiler_state: BoilerState = BoilerState.CLOGGED


func _find_primary_smoke_emitter() -> CPUParticles3D:
	var emitter := get_node_or_null("FireboxSmoke") as CPUParticles3D
	if emitter == null:
		emitter = get_node_or_null("ChimneySmoke") as CPUParticles3D
	return emitter


func _ready() -> void:
	_build_gauge_color_sectors()
	_create_smoke_ramps()
	_apply_boiler_state()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_apply_temperature_to_gauge()


func set_temperature(value: float) -> void:
	temperature_percent = clampf(value, 0.0, 100.0)
	_apply_temperature_to_gauge()


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
	var sector_width := (start_angle - end_angle) / 4.0
	var subdivisions := 4

	for sector_index in range(4):
		var surface_tool := SurfaceTool.new()
		surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sector_start := start_angle - sector_width * float(sector_index)
		var sector_end := sector_start - sector_width
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

	gauge_color_sectors.mesh = sector_mesh


func _apply_temperature_to_gauge() -> void:
	if not is_instance_valid(gauge_needle_pivot):
		return
	var normalized_temperature := temperature_percent / 100.0
	gauge_needle_pivot.rotation.z = lerpf(
		GAUGE_COLD_ANGLE,
		GAUGE_HOT_ANGLE,
		normalized_temperature
	)
