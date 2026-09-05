extends AudioStreamPlayer3D

const CRACK_START_OFFSETS: Array[float] = [
	0.16, 2.58, 14.58, 15.78, 17.82, 18.98, 20.35,
]

@export_node_path("Node3D") var player_path: NodePath = NodePath("../Player")
@export_range(8.0, 90.0, 1.0) var initial_delay_min := 14.0
@export_range(8.0, 90.0, 1.0) var initial_delay_max := 30.0
@export_range(10.0, 120.0, 1.0) var repeat_delay_min := 28.0
@export_range(10.0, 120.0, 1.0) var repeat_delay_max := 58.0
@export_category("Audio")
@export_range(-40.0, 6.0, 0.5) var volumen_min_db := -19.0
@export_range(-40.0, 6.0, 0.5) var volumen_max_db := -15.5
@export_range(0.25, 1.0, 0.01) var duracion_crack_min := 0.34
@export_range(0.25, 1.0, 0.01) var duracion_crack_max := 0.55
@export_range(0.02, 0.2, 0.01) var fundido_salida := 0.08

var _player: Node3D
var _fragment_timer := 0.0
var _fragment_volume_db := -18.0
var _schedule_timer: Timer


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_schedule_timer = Timer.new()
	_schedule_timer.name = "CrackScheduleTimer"
	_schedule_timer.one_shot = true
	_schedule_timer.timeout.connect(_play_crack)
	add_child(_schedule_timer)
	_schedule_next(initial_delay_min, initial_delay_max)
	set_process(false)


func _process(delta: float) -> void:
	if playing:
		_fragment_timer = maxf(0.0, _fragment_timer - delta)
		if _fragment_timer < fundido_salida:
			volume_db = lerpf(-40.0, _fragment_volume_db, _fragment_timer / maxf(fundido_salida, 0.001))
		if _fragment_timer <= 0.0:
			stop()
			set_process(false)
			_schedule_next(repeat_delay_min, repeat_delay_max)
		return


func _play_crack() -> void:
	if not is_instance_valid(_player):
		_player = get_node_or_null(player_path) as Node3D
	if not is_instance_valid(_player) or stream == null:
		_schedule_next(2.0, 2.0)
		return
	_place_on_another_floor()
	_fragment_volume_db = randf_range(minf(volumen_min_db, volumen_max_db), maxf(volumen_min_db, volumen_max_db))
	volume_db = _fragment_volume_db
	pitch_scale = randf_range(0.94, 1.04)
	var crack_offset: float = CRACK_START_OFFSETS.pick_random()
	play(crack_offset)
	_fragment_timer = randf_range(
		minf(duracion_crack_min, duracion_crack_max),
		maxf(duracion_crack_min, duracion_crack_max)
	) / pitch_scale
	set_process(true)


func _schedule_next(minimum: float, maximum: float) -> void:
	if _schedule_timer != null:
		_schedule_timer.start(randf_range(minf(minimum, maximum), maxf(minimum, maximum)))


func _place_on_another_floor() -> void:
	var angle := randf() * TAU
	var horizontal_distance := randf_range(3.5, 8.0)
	var source_height := 0.55
	if _player.global_position.y < 2.0:
		source_height = 4.45
	global_position = Vector3(
		_player.global_position.x + cos(angle) * horizontal_distance,
		source_height,
		_player.global_position.z + sin(angle) * horizontal_distance
	)
