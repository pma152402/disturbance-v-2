extends Control

signal completed
signal cancelled
signal values_changed(temperature: float, blockage: float)
signal action_used(action: StringName)

const PIXEL_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const GREEN_MIN := 18.0
const GREEN_MAX := 39.0
const STABILIZE_REQUIRED := 5.0

var temperature := 76.0
var blockage := 100.0
var stabilize_time := 0.0
var _feedback := "PURGA PRESION Y DESATASCA LA SALIDA"
var _feedback_color := Color(0.88, 0.74, 0.42)
var _action_cooldown := 0.0
var _danger_flash := 0.0
var _completed := false
var _panel_rect := Rect2()
var _button_rects: Array[Rect2] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	call_deferred(&"grab_focus")
	values_changed.emit(temperature, blockage)
	queue_redraw()


func _process(delta: float) -> void:
	if _completed:
		queue_redraw()
		return
	_action_cooldown = maxf(0.0, _action_cooldown - delta)
	_danger_flash = maxf(0.0, _danger_flash - delta)

	# Cuanto mayor sea el atasco, mas deprisa vuelve a calentarse la caldera.
	var heat_rate := lerpf(-2.2, 5.2, blockage / 100.0)
	temperature = clampf(temperature + heat_rate * delta, 0.0, 100.0)
	if blockage <= 0.0 and temperature >= GREEN_MIN and temperature <= GREEN_MAX:
		stabilize_time = minf(STABILIZE_REQUIRED, stabilize_time + delta)
		_feedback = "ESTABILIZANDO... %.1f / %.0f s" % [stabilize_time, STABILIZE_REQUIRED]
		_feedback_color = Color(0.35, 1.0, 0.42)
		if stabilize_time >= STABILIZE_REQUIRED:
			_completed = true
			_feedback = "CALDERA ESTABLE"
			completed.emit()
	else:
		stabilize_time = maxf(0.0, stabilize_time - delta * 1.6)

	if temperature >= 99.5:
		blockage = minf(100.0, blockage + 18.0)
		temperature = 91.0
		stabilize_time = 0.0
		_danger_flash = 0.7
		_feedback = "SOBREPRESION - PURGA AHORA"
		_feedback_color = Color(1.0, 0.12, 0.055)
		action_used.emit(&"overheat")
	values_changed.emit(temperature, blockage)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		if key == KEY_ESCAPE:
			cancelled.emit()
			get_viewport().set_input_as_handled()
			return
		if key in [KEY_Q, KEY_1]:
			_use_action(&"fuel")
		elif key in [KEY_E, KEY_2]:
			_use_action(&"vent")
		elif key in [KEY_F, KEY_SPACE, KEY_3]:
			_use_action(&"pump")
		else:
			return
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_update_layout()
		var mouse_position := (event as InputEventMouseButton).position
		for index in _button_rects.size():
			if _button_rects[index].has_point(mouse_position):
				_use_action([&"fuel", &"vent", &"pump"][index])
				get_viewport().set_input_as_handled()
				return


func _use_action(action: StringName) -> void:
	if _completed or _action_cooldown > 0.0:
		return
	_action_cooldown = 0.16
	match action:
		&"fuel":
			temperature = minf(100.0, temperature + 12.0)
			_feedback = "COMBUSTIBLE +  TEMPERATURA SUBIENDO"
			_feedback_color = Color(1.0, 0.67, 0.16)
		&"vent":
			temperature = maxf(0.0, temperature - 17.0)
			_feedback = "VALVULA ABIERTA - PRESION LIBERADA"
			_feedback_color = Color(0.48, 0.78, 1.0)
		&"pump":
			var safe_to_pump := temperature >= 28.0 and temperature <= 72.0
			blockage = maxf(0.0, blockage - (22.0 if safe_to_pump else 8.0))
			temperature = minf(100.0, temperature + 5.0)
			if safe_to_pump:
				_feedback = "ATASCO CEDIENDO"
				_feedback_color = Color(0.52, 0.92, 0.48)
			else:
				_feedback = "MALA PRESION - EL EMBOLO NO AGARRA"
				_feedback_color = Color(1.0, 0.38, 0.18)
	action_used.emit(action)
	values_changed.emit(temperature, blockage)
	queue_redraw()


func _update_layout() -> void:
	var panel_size := Vector2(clampf(size.x * 0.78, 760.0, 1120.0), clampf(size.y * 0.72, 540.0, 760.0))
	_panel_rect = Rect2((size - panel_size) * 0.5, panel_size)
	_button_rects.clear()
	var button_width := (panel_size.x - 100.0) / 3.0
	for index in 3:
		_button_rects.append(Rect2(_panel_rect.position + Vector2(30.0 + index * (button_width + 20.0), panel_size.y - 145.0), Vector2(button_width, 72.0)))


func _draw() -> void:
	_update_layout()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.58))
	draw_rect(_panel_rect.grow(14.0), Color(0.0, 0.0, 0.0, 0.62))
	draw_rect(_panel_rect, Color(0.105, 0.12, 0.11, 0.98))
	draw_rect(_panel_rect.grow(-8.0), Color(0.035, 0.043, 0.039, 1.0), false, 3.0)
	if _danger_flash > 0.0:
		draw_rect(_panel_rect.grow(-5.0), Color(1.0, 0.02, 0.0, _danger_flash * 0.35), false, 8.0)

	draw_string(PIXEL_FONT, _panel_rect.position + Vector2(32, 48), "CALDERA DEL SOTANO", HORIZONTAL_ALIGNMENT_LEFT, _panel_rect.size.x - 64, 18, Color(0.82, 0.84, 0.75))
	draw_string(PIXEL_FONT, _panel_rect.position + Vector2(32, 75), "CONTROL MANUAL DE PRESION", HORIZONTAL_ALIGNMENT_LEFT, _panel_rect.size.x - 64, 9, Color(0.46, 0.5, 0.45))
	_draw_gauge()
	_draw_blockage()
	_draw_buttons()


func _draw_gauge() -> void:
	var center := _panel_rect.position + Vector2(_panel_rect.size.x * 0.31, _panel_rect.size.y * 0.43)
	var radius := minf(_panel_rect.size.x, _panel_rect.size.y) * 0.225
	draw_circle(center, radius * 1.12, Color(0.18, 0.19, 0.17))
	var colors := [Color(0.05, 0.92, 0.12), Color(1.0, 0.9, 0.04), Color(1.0, 0.34, 0.02), Color(1.0, 0.025, 0.012)]
	for sector in 4:
		var start := PI + float(sector) * PI / 4.0
		var finish := start + PI / 4.0
		draw_arc(center, radius, start, finish, 18, colors[sector], 24.0, true)
	var angle := PI + clampf(temperature / 100.0, 0.0, 1.0) * PI
	var tip := center + Vector2(cos(angle), sin(angle)) * radius * 0.82
	draw_line(center + Vector2(4, 5), tip + Vector2(4, 5), Color(0, 0, 0, 0.65), 9.0, true)
	draw_line(center, tip, Color(0.9, 0.88, 0.73), 6.0, true)
	draw_circle(center, 11.0, Color(0.64, 0.48, 0.19))
	draw_string(PIXEL_FONT, center + Vector2(-100, radius + 39), "TEMPERATURA  %03d%%" % int(temperature), HORIZONTAL_ALIGNMENT_CENTER, 200, 11, Color(0.86, 0.86, 0.77))


func _draw_blockage() -> void:
	var origin := _panel_rect.position + Vector2(_panel_rect.size.x * 0.58, 150)
	var bar_size := Vector2(_panel_rect.size.x * 0.31, 34)
	draw_string(PIXEL_FONT, origin, "ATASCO EN SALIDA", HORIZONTAL_ALIGNMENT_LEFT, bar_size.x, 11, Color(0.76, 0.78, 0.7))
	var bar := Rect2(origin + Vector2(0, 25), bar_size)
	draw_rect(bar, Color(0.025, 0.03, 0.027))
	draw_rect(Rect2(bar.position + Vector2(4, 4), Vector2((bar.size.x - 8) * blockage / 100.0, bar.size.y - 8)), Color(0.86, 0.16, 0.055))
	draw_string(PIXEL_FONT, origin + Vector2(0, 94), "ESTABILIDAD", HORIZONTAL_ALIGNMENT_LEFT, bar_size.x, 11, Color(0.76, 0.78, 0.7))
	var stable_bar := Rect2(origin + Vector2(0, 119), bar_size)
	draw_rect(stable_bar, Color(0.025, 0.03, 0.027))
	draw_rect(Rect2(stable_bar.position + Vector2(4, 4), Vector2((stable_bar.size.x - 8) * stabilize_time / STABILIZE_REQUIRED, stable_bar.size.y - 8)), Color(0.1, 0.86, 0.22))
	draw_string(PIXEL_FONT, origin + Vector2(0, 205), _feedback, HORIZONTAL_ALIGNMENT_CENTER, bar_size.x, 8, _feedback_color)
	draw_string(PIXEL_FONT, origin + Vector2(0, 237), "DESATASCA Y MANTEN\nLA AGUJA EN VERDE", HORIZONTAL_ALIGNMENT_CENTER, bar_size.x, 8, Color(0.52, 0.56, 0.5))


func _draw_buttons() -> void:
	var labels := ["Q / 1  COMBUSTIBLE", "E / 2  PURGAR", "F / 3  BOMBEAR"]
	var colors := [Color(0.75, 0.28, 0.06), Color(0.12, 0.48, 0.7), Color(0.42, 0.5, 0.2)]
	for index in 3:
		var shadow_rect := Rect2(_button_rects[index].position + Vector2(5, 7), _button_rects[index].size)
		draw_rect(shadow_rect, Color(0, 0, 0, 0.55))
		draw_rect(_button_rects[index], colors[index])
		draw_rect(_button_rects[index].grow(-5), colors[index].lightened(0.18), false, 3.0)
		draw_string(PIXEL_FONT, _button_rects[index].position + Vector2(8, 43), labels[index], HORIZONTAL_ALIGNMENT_CENTER, _button_rects[index].size.x - 16, 9, Color(0.96, 0.95, 0.86))
	draw_string(PIXEL_FONT, _panel_rect.position + Vector2(30, _panel_rect.size.y - 24), "ESC  SALIR", HORIZONTAL_ALIGNMENT_LEFT, 180, 8, Color(0.42, 0.45, 0.41))
