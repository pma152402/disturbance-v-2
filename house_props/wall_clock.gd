@tool
extends Node3D

@onready var hour_hand: Node3D = $Hands/HourHand
@onready var minute_hand: Node3D = $Hands/MinuteHand
@onready var second_hand: Node3D = $Hands/SecondHand

func _ready() -> void:
	_update_clock()
	set_process(Engine.is_editor_hint())
	if not Engine.is_editor_hint():
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
