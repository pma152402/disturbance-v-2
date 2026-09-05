@tool
extends Node3D

@export var tick_sound_enabled := false
@export_category("Audio")
@export_range(-40.0, 6.0, 0.5) var volumen_tictac_db := 0.0
@export_range(0.5, 10.0, 0.25) var tamano_fuente_tictac := 4.0
@export_range(2.0, 30.0, 0.5) var distancia_maxima_tictac := 16.0

@onready var hour_hand: Node3D = $Hands/HourHand
@onready var minute_hand: Node3D = $Hands/MinuteHand
@onready var second_hand: Node3D = $Hands/SecondHand
@onready var tick_sound_loop: Node = $TickSoundLoop

func _ready() -> void:
	_update_clock()
	set_process(Engine.is_editor_hint())
	if not Engine.is_editor_hint():
		tick_sound_loop.set("volume_db", volumen_tictac_db)
		tick_sound_loop.call(&"set_spatial_range", tamano_fuente_tictac, distancia_maxima_tictac)
		tick_sound_loop.call(&"set_active", tick_sound_enabled)
		var refresh_timer := Timer.new()
		refresh_timer.name = "ClockRefreshTimer"
		refresh_timer.wait_time = 0.25
		refresh_timer.timeout.connect(_update_clock)
		add_child(refresh_timer)
		refresh_timer.start()


func _process(_delta: float) -> void:
	# En el editor no hay un Timer de runtime; mantener la previsualizacion viva.
	_update_clock()


func _update_clock() -> void:
	if hour_hand == null or minute_hand == null or second_hand == null:
		return
	var now := Time.get_time_dict_from_system()
	var seconds: float = float(now.second)
	var minutes: float = float(now.minute) + seconds / 60.0
	var hours: float = float(now.hour % 12) + minutes / 60.0
	hour_hand.rotation.z = -TAU * hours / 12.0
	minute_hand.rotation.z = -TAU * minutes / 60.0
	second_hand.rotation.z = -TAU * seconds / 60.0
