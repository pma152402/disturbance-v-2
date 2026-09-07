extends Control

signal completed
signal cancelled
signal selection_changed(program: int)
signal program_submitted(program: int, correct: bool)

const REQUIRED_SEQUENCE := [2, 7, 6, 9, 4, 1]
const PROGRAM_NAMES := [
	"CORTO",
	"ALGODÓN",
	"SINTÉTICOS",
	"DELICADO",
	"LANA",
	"MIXTO",
	"ECO",
	"ACLARADO",
	"CENTRIFUGADO",
]
const PIXEL_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

var _selected_program := 1
var _progress := 0
var _feedback := "SELECCIONA UN PROGRAMA"
var _feedback_color := Color(0.67, 0.72, 0.66)
var _button_press := 0.0
var _dial_pulse := 0.0
var _input_lock_timer := 0.0
var _completion_timer := 0.0
var _completion_emitted := false

var _panel_rect := Rect2()
var _dial_center := Vector2.ZERO
var _dial_radius := 0.0
var _red_button_center := Vector2.ZERO
var _red_button_radius := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	call_deferred(&"grab_focus")
	queue_redraw()


func _process(delta: float) -> void:
	_button_press = move_toward(_button_press, 0.0, delta * 6.5)
	_dial_pulse = move_toward(_dial_pulse, 0.0, delta * 3.2)
	_input_lock_timer = maxf(0.0, _input_lock_timer - delta)
	if _completion_timer > 0.0:
		_completion_timer -= delta
		if _completion_timer <= 0.0 and not _completion_emitted:
			_completion_emitted = true
			completed.emit()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var pressed_key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		if pressed_key == KEY_ESCAPE:
			cancelled.emit()
			get_viewport().set_input_as_handled()
			return
		if _input_lock_timer > 0.0 or _completion_timer > 0.0:
			return
		if pressed_key in [KEY_LEFT, KEY_A, KEY_Q]:
			_change_program(-1)
			get_viewport().set_input_as_handled()
			return
		if pressed_key in [KEY_RIGHT, KEY_D, KEY_E]:
			_change_program(1)
			get_viewport().set_input_as_handled()
			return
		if pressed_key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_F]:
			_submit_program()
			get_viewport().set_input_as_handled()
			return
		if pressed_key >= KEY_1 and pressed_key <= KEY_9:
			_set_program(pressed_key - KEY_0)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if _input_lock_timer > 0.0 or _completion_timer > 0.0:
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_program(1)
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_program(-1)
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_update_layout()
			if mouse_event.position.distance_to(_red_button_center) <= _red_button_radius * 1.16:
				_submit_program()
			elif mouse_event.position.distance_to(_dial_center) <= _dial_radius * 1.34:
				_select_program_from_position(mouse_event.position)
			get_viewport().set_input_as_handled()


func _change_program(direction: int) -> void:
	_set_program(wrapi(_selected_program - 1 + direction, 0, 9) + 1)


func _set_program(program: int) -> void:
	_selected_program = clampi(program, 1, 9)
	_dial_pulse = 1.0
	_feedback = "%d  %s" % [_selected_program, PROGRAM_NAMES[_selected_program - 1]]
	_feedback_color = Color(0.73, 0.76, 0.68)
	selection_changed.emit(_selected_program)
	queue_redraw()


func _select_program_from_position(mouse_position: Vector2) -> void:
	var offset := mouse_position - _dial_center
	if offset.length() < _dial_radius * 0.34:
		_change_program(1)
		return
	var angle := atan2(offset.y, offset.x)
	var normalized := fposmod(angle + PI * 0.5 + TAU / 18.0, TAU)
	_set_program(int(floor(normalized / (TAU / 9.0))) + 1)


func _submit_program() -> void:
	if _progress >= REQUIRED_SEQUENCE.size():
		return
	_button_press = 1.0
	var expected: int = REQUIRED_SEQUENCE[_progress]
	var correct := _selected_program == expected
	program_submitted.emit(_selected_program, correct)
	if correct:
		_progress += 1
		if _progress >= REQUIRED_SEQUENCE.size():
			_feedback = "CICLO ACEPTADO"
			_feedback_color = Color(0.55, 0.86, 0.58)
			_completion_timer = 0.85
			_input_lock_timer = 0.85
		else:
			_feedback = "PASO %d CORRECTO" % _progress
			_feedback_color = Color(0.6, 0.82, 0.59)
			_input_lock_timer = 0.16
	else:
		_progress = 0
		_feedback = "ERROR - SECUENCIA BORRADA"
		_feedback_color = Color(0.92, 0.23, 0.16)
		_input_lock_timer = 0.48
	queue_redraw()


func _update_layout() -> void:
	var panel_size := Vector2(
		clampf(size.x * 0.76, 760.0, 1180.0),
		clampf(size.y * 0.67, 500.0, 720.0)
	)
	_panel_rect = Rect2((size - panel_size) * 0.5, panel_size)
	_red_button_center = _panel_rect.position + Vector2(panel_size.x * 0.24, panel_size.y * 0.52)
	_dial_center = _panel_rect.position + Vector2(panel_size.x * 0.70, panel_size.y * 0.48)
	_dial_radius = minf(panel_size.x, panel_size.y) * 0.22
	_red_button_radius = _dial_radius * 0.42


func _draw() -> void:
	_update_layout()
	var shadow_rect := _panel_rect.grow(18.0)
	draw_rect(shadow_rect, Color(0.0, 0.0, 0.0, 0.28))
	draw_rect(_panel_rect, Color(0.18, 0.2, 0.19, 0.72))
	draw_rect(_panel_rect.grow(-8.0), Color(0.045, 0.055, 0.051, 0.66))
	draw_rect(Rect2(_panel_rect.position + Vector2(18, 18), Vector2(_panel_rect.size.x - 36, 72)), Color(0.025, 0.032, 0.03, 0.74))
	draw_line(_panel_rect.position + Vector2(22, 96), _panel_rect.position + Vector2(_panel_rect.size.x - 22, 96), Color(0.5, 0.52, 0.47, 0.55), 3.0)

	var title_rect := Rect2(_panel_rect.position + Vector2(30, 42), Vector2(_panel_rect.size.x - 60, 30))
	draw_string(PIXEL_FONT, title_rect.position, "LAVADORA VIDA-9", HORIZONTAL_ALIGNMENT_LEFT, title_rect.size.x, 19, Color(0.78, 0.8, 0.72))
	draw_string(PIXEL_FONT, title_rect.position + Vector2(0, 34), "PROGRAMADOR MECANICO", HORIZONTAL_ALIGNMENT_LEFT, title_rect.size.x, 9, Color(0.42, 0.46, 0.42))

	_draw_red_button()
	_draw_dial()
	_draw_feedback()


func _draw_dial() -> void:
	draw_circle(_dial_center + Vector2(8, 10), _dial_radius * 1.13, Color(0.0, 0.0, 0.0, 0.58))
	draw_circle(_dial_center, _dial_radius * 1.12, Color(0.24, 0.26, 0.245))
	draw_arc(_dial_center, _dial_radius * 1.12, 0.0, TAU, 72, Color(0.51, 0.53, 0.49), 5.0, true)
	draw_circle(_dial_center, _dial_radius * 0.63, Color(0.065, 0.072, 0.069))
	draw_arc(_dial_center, _dial_radius * 0.63, 0.0, TAU, 64, Color(0.33, 0.35, 0.32), 4.0, true)

	for program in range(1, 10):
		var angle := -PI * 0.5 + float(program - 1) * TAU / 9.0
		var direction := Vector2(cos(angle), sin(angle))
		var number_center := _dial_center + direction * (_dial_radius * 0.84)
		var name_center := _dial_center + direction * (_dial_radius * 1.32)
		var selected := program == _selected_program
		if selected:
			draw_circle(number_center, 19.0 + _dial_pulse * 4.0, Color(0.62, 0.11, 0.075, 0.96))
		else:
			draw_circle(number_center, 15.0, Color(0.075, 0.085, 0.08))
		var number_color := Color(1.0, 0.72, 0.55) if selected else Color(0.63, 0.66, 0.6)
		draw_string(PIXEL_FONT, number_center + Vector2(-15, 5), str(program), HORIZONTAL_ALIGNMENT_CENTER, 30.0, 11, number_color)
		var name_color := Color(0.95, 0.95, 0.9) if selected else Color(0.62, 0.65, 0.61)
		draw_string(
			PIXEL_FONT,
			name_center + Vector2(-66.0, 4.0),
			PROGRAM_NAMES[program - 1],
			HORIZONTAL_ALIGNMENT_CENTER,
			132.0,
			7,
			name_color
		)

	var selected_angle := -PI * 0.5 + float(_selected_program - 1) * TAU / 9.0
	var pointer_direction := Vector2(cos(selected_angle), sin(selected_angle))
	var perpendicular := Vector2(-pointer_direction.y, pointer_direction.x)
	var pointer_start := _dial_center + pointer_direction * 18.0
	var pointer_tip := _dial_center + pointer_direction * (_dial_radius * 0.66)
	var arrow_base := pointer_tip - pointer_direction * 28.0
	draw_line(pointer_start + Vector2(3, 4), arrow_base + Vector2(3, 4), Color(0, 0, 0, 0.55), 18.0, true)
	draw_line(pointer_start, arrow_base, Color(0.68, 0.7, 0.67), 12.0, true)
	draw_colored_polygon(PackedVector2Array([
		pointer_tip,
		arrow_base + perpendicular * 20.0,
		arrow_base - perpendicular * 20.0,
	]), Color(0.68, 0.7, 0.67))
	draw_circle(_dial_center, 14.0, Color(0.48, 0.5, 0.47))
	draw_string(PIXEL_FONT, _dial_center + Vector2(-105, _dial_radius * 1.58), "SELECTOR DE PROGRAMA", HORIZONTAL_ALIGNMENT_CENTER, 210.0, 9, Color(0.65, 0.68, 0.63))
	draw_string(PIXEL_FONT, _dial_center + Vector2(-105, _dial_radius * 1.58 + 21), "RUEDA / A-D / 1-9", HORIZONTAL_ALIGNMENT_CENTER, 210.0, 7, Color(0.43, 0.46, 0.43))


func _draw_red_button() -> void:
	var press_offset := Vector2(0.0, _button_press * 7.0)
	draw_circle(_red_button_center + Vector2(8, 13), _red_button_radius * 1.2, Color(0.0, 0.0, 0.0, 0.65))
	draw_circle(_red_button_center, _red_button_radius * 1.18, Color(0.19, 0.2, 0.19))
	draw_circle(_red_button_center + press_offset, _red_button_radius, Color(0.63, 0.055, 0.035))
	draw_circle(_red_button_center + press_offset - Vector2(0, _red_button_radius * 0.18), _red_button_radius * 0.72, Color(0.88, 0.1, 0.055))
	draw_arc(_red_button_center + press_offset, _red_button_radius, PI * 1.08, TAU * 0.93, 32, Color(1.0, 0.31, 0.18, 0.72), 4.0, true)
	draw_string(PIXEL_FONT, _red_button_center + Vector2(-100, _red_button_radius + 43), "CONFIRMAR", HORIZONTAL_ALIGNMENT_CENTER, 200.0, 12, Color(0.74, 0.76, 0.7))
	draw_string(PIXEL_FONT, _red_button_center + Vector2(-100, _red_button_radius + 67), "CLIC / F / ESPACIO", HORIZONTAL_ALIGNMENT_CENTER, 200.0, 8, Color(0.4, 0.43, 0.4))


func _draw_feedback() -> void:
	var feedback_rect := Rect2(
		_panel_rect.position + Vector2(_panel_rect.size.x * 0.12, _panel_rect.size.y - 84.0),
		Vector2(_panel_rect.size.x * 0.76, 50.0)
	)
	draw_rect(feedback_rect, Color(0.025, 0.032, 0.029, 0.76))
	draw_rect(feedback_rect, _feedback_color.darkened(0.35), false, 2.0)
	draw_string(PIXEL_FONT, feedback_rect.position + Vector2(10, 32), _feedback, HORIZONTAL_ALIGNMENT_CENTER, feedback_rect.size.x - 20, 10, _feedback_color)
	draw_string(PIXEL_FONT, _panel_rect.position + Vector2(30, _panel_rect.size.y - 24), "ESC  SALIR", HORIZONTAL_ALIGNMENT_LEFT, 180.0, 9, Color(0.42, 0.45, 0.42))
