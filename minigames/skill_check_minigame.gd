extends Control

signal completed
signal cancelled
signal attempted

const CHECK_SPEEDS := [4.8, 5.7, 6.7, 7.8]
const CHECK_WIDTHS := [deg_to_rad(52.0), deg_to_rad(45.0), deg_to_rad(39.0), deg_to_rad(33.0)]
const PIXEL_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

var _check_index := 0
var _needle_angle := PI
var _target_angles := [0.0, 0.0, 0.0, 0.0]
var _transition_timer := 0.0
var _feedback := ""
var _feedback_color := Color.WHITE
var _flash_amount := 0.0
var _accept_input := true
var _reset_after_transition := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_fit_to_viewport)
	_start_check(0)
	queue_redraw()


func _fit_to_viewport() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _process(delta: float) -> void:
	_flash_amount = move_toward(_flash_amount, 0.0, delta * 3.8)
	if _transition_timer > 0.0:
		_transition_timer -= delta
		if _transition_timer <= 0.0:
			if _reset_after_transition:
				_reset_after_transition = false
				_start_check(0)
			elif _check_index >= 4:
				completed.emit()
				return
			else:
				_start_check(_check_index)
	else:
		_needle_angle += CHECK_SPEEDS[_check_index] * delta
		if _needle_angle > TAU:
			_needle_angle = PI + fmod(_needle_angle - TAU, PI)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var pressed_key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		if pressed_key == KEY_ESCAPE:
			cancelled.emit()
			get_viewport().set_input_as_handled()
			return
		if pressed_key in [KEY_SPACE, KEY_F] and _accept_input:
			_resolve_attempt()
			get_viewport().set_input_as_handled()


func _start_check(index: int) -> void:
	_check_index = index
	if _check_index >= 4:
		return
	_needle_angle = PI
	var half_width: float = CHECK_WIDTHS[_check_index] * 0.5
	var first_third_angle := PI + PI / 3.0
	_target_angles[_check_index] = randf_range(first_third_angle + half_width, TAU - half_width - 0.08)
	_feedback = ""
	_accept_input = true


func _resolve_attempt() -> void:
	_accept_input = false
	attempted.emit()
	var angular_error := absf(_needle_angle - float(_target_angles[_check_index]))
	if angular_error <= CHECK_WIDTHS[_check_index] * 0.5:
		_feedback = "OK"
		_feedback_color = Color(0.67, 0.78, 0.65)
		_flash_amount = 0.22
		_check_index += 1
		_transition_timer = 0.17
	else:
		_feedback = "FALLO - REINICIO"
		_feedback_color = Color(0.72, 0.2, 0.16)
		_flash_amount = 0.62
		_reset_after_transition = true
		_transition_timer = 0.42


func _draw() -> void:
	var base_center := Vector2(size.x * 0.73, size.y * 0.34)
	var radius := clampf(minf(size.x, size.y) * 0.115, 82.0, 140.0)
	var row_spacing := radius * 0.72
	var visible_checks := mini(_check_index + 1, 4)

	for i in range(visible_checks):
		var center := base_center + Vector2(0.0, row_spacing * i)
		var completed_check := i < _check_index
		var panel_color := Color(0.025, 0.03, 0.029, 0.56 + (_flash_amount * 0.16 if i == _check_index else 0.0))
		draw_rect(Rect2(center - Vector2(radius + 25.0, radius + 24.0), Vector2((radius + 25.0) * 2.0, radius + 48.0)), panel_color)
		draw_arc(center, radius, PI, TAU, 56, Color(0.34, 0.37, 0.34, 0.84), 9.0, true)

		if completed_check:
			draw_arc(center, radius, PI, TAU, 56, Color(0.58, 0.68, 0.56, 0.92), 11.0, true)
			draw_string(PIXEL_FONT, center + Vector2(-55.0, 19.0), "HECHO", HORIZONTAL_ALIGNMENT_CENTER, 110.0, 10, Color(0.66, 0.74, 0.63))
		else:
			var half_width: float = CHECK_WIDTHS[i] * 0.5
			var target_angle: float = _target_angles[i]
			draw_arc(center, radius, target_angle - half_width, target_angle + half_width, 16, Color(0.76, 0.79, 0.72), 13.0, true)
			var needle_end := center + Vector2(cos(_needle_angle), sin(_needle_angle)) * (radius + 8.0)
			draw_line(center, needle_end, Color(0.7, 0.16, 0.13), 4.0, true)
			draw_circle(center, 6.0, Color(0.67, 0.7, 0.65))

		draw_string(PIXEL_FONT, center + Vector2(-radius, 35.0), "%d/4" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 9, Color(0.53, 0.56, 0.52))

	var title_position := base_center + Vector2(-radius - 25.0, -radius - 42.0)
	draw_string(PIXEL_FONT, title_position, "DESATASCANDO", HORIZONTAL_ALIGNMENT_CENTER, (radius + 25.0) * 2.0, 13, Color(0.7, 0.72, 0.68))
	draw_string(PIXEL_FONT, title_position + Vector2(0, 19), "F / ESPACIO", HORIZONTAL_ALIGNMENT_CENTER, (radius + 25.0) * 2.0, 8, Color(0.46, 0.49, 0.46))
	if not _feedback.is_empty():
		var feedback_y := base_center.y + row_spacing * maxf(visible_checks - 1, 0) + 58.0
		draw_string(PIXEL_FONT, Vector2(base_center.x - radius - 60.0, feedback_y), _feedback, HORIZONTAL_ALIGNMENT_CENTER, (radius + 60.0) * 2.0, 10, _feedback_color)
