extends Control

signal completed
signal cancelled
signal nail_selected(nail_index: int)
signal pry_motion(nail_index: int, progress: float, handle_value: float)
signal nail_removed(nail_index: int)

enum Phase { SELECT_NAIL, INSERTING_CROWBAR, PRYING, NAIL_RELEASED, FINISHED }

const NAIL_COUNT := 8
const REQUIRED_HALF_STROKES := 6
const PIXEL_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

var _phase := Phase.SELECT_NAIL
var _removed_nails: Array[bool] = []
var _selected_nail := -1
var _insertion_amount := 0.0
var _nail_progress := 0.0
var _handle_value := 1.0
var _handle_target := -1.0
var _half_strokes := 0
var _dragging_handle := false
var _release_timer := 0.0
var _completion_emitted := false
var _pulse_time := 0.0

var _panel_rect := Rect2()
var _work_rect := Rect2()
var _handle_track := Rect2()
var _handle_center := Vector2.ZERO
var _handle_radius := 30.0
var _nail_centers: Array[Vector2] = []


func setup(removed_flags: Array) -> void:
	_removed_nails.clear()
	for index in NAIL_COUNT:
		_removed_nails.append(index < removed_flags.size() and bool(removed_flags[index]))
	_phase = Phase.FINISHED if _count_removed_nails() >= NAIL_COUNT else Phase.SELECT_NAIL
	queue_redraw()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	if _removed_nails.is_empty():
		for index in NAIL_COUNT:
			_removed_nails.append(false)
	call_deferred(&"grab_focus")
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta
	if _phase == Phase.INSERTING_CROWBAR:
		_insertion_amount = minf(_insertion_amount + delta * 3.1, 1.0)
		if _insertion_amount >= 1.0:
			_finish_insertion()
	elif _phase == Phase.NAIL_RELEASED:
		_release_timer -= delta
		if _release_timer <= 0.0:
			_advance_after_release()
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

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_button := event as InputEventMouseButton
		_update_layout()
		if mouse_button.pressed:
			if _phase == Phase.SELECT_NAIL:
				var clicked_nail := _find_nail_at(mouse_button.position)
				if clicked_nail >= 0:
					_select_nail(clicked_nail)
			elif _phase == Phase.PRYING and mouse_button.position.distance_to(_handle_center) <= _handle_radius * 1.45:
				_dragging_handle = true
				_update_handle_from_mouse(mouse_button.position.y)
		else:
			_dragging_handle = false
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _dragging_handle and _phase == Phase.PRYING:
		_update_handle_from_mouse((event as InputEventMouseMotion).position.y)
		get_viewport().set_input_as_handled()


func _select_nail(nail_index: int) -> void:
	if _phase != Phase.SELECT_NAIL or nail_index < 0 or nail_index >= NAIL_COUNT or _removed_nails[nail_index]:
		return
	_selected_nail = nail_index
	_phase = Phase.INSERTING_CROWBAR
	_insertion_amount = 0.0
	_nail_progress = 0.0
	_handle_value = 1.0
	_handle_target = -1.0
	_half_strokes = 0
	_dragging_handle = false
	nail_selected.emit(_selected_nail)
	queue_redraw()


func _finish_insertion() -> void:
	if _phase != Phase.INSERTING_CROWBAR:
		return
	_insertion_amount = 1.0
	_phase = Phase.PRYING
	pry_motion.emit(_selected_nail, _nail_progress, _handle_value)


func _update_handle_from_mouse(mouse_y: float) -> void:
	var travel_half := _handle_track.size.y * 0.5 - _handle_radius
	_handle_value = clampf((mouse_y - _handle_track.get_center().y) / travel_half, -1.0, 1.0)
	pry_motion.emit(_selected_nail, _nail_progress, _handle_value)
	var reached_target := (_handle_target < 0.0 and _handle_value <= -0.88) or (_handle_target > 0.0 and _handle_value >= 0.88)
	if reached_target:
		_complete_half_stroke()
	queue_redraw()


func _complete_half_stroke() -> void:
	if _phase != Phase.PRYING:
		return
	_half_strokes += 1
	_nail_progress = clampf(float(_half_strokes) / float(REQUIRED_HALF_STROKES), 0.0, 1.0)
	_handle_value = _handle_target
	_handle_target *= -1.0
	pry_motion.emit(_selected_nail, _nail_progress, _handle_value)
	if _half_strokes >= REQUIRED_HALF_STROKES:
		_removed_nails[_selected_nail] = true
		_phase = Phase.NAIL_RELEASED
		_release_timer = 0.52
		_dragging_handle = false
		nail_removed.emit(_selected_nail)


func _advance_after_release() -> void:
	if _count_removed_nails() >= NAIL_COUNT:
		_phase = Phase.FINISHED
		if not _completion_emitted:
			_completion_emitted = true
			completed.emit()
		return
	_selected_nail = -1
	_insertion_amount = 0.0
	_nail_progress = 0.0
	_phase = Phase.SELECT_NAIL


func _count_removed_nails() -> int:
	var count := 0
	for removed in _removed_nails:
		if removed:
			count += 1
	return count


func _find_nail_at(mouse_position: Vector2) -> int:
	for index in _nail_centers.size():
		if not _removed_nails[index] and mouse_position.distance_to(_nail_centers[index]) <= 31.0:
			return index
	return -1


func _update_layout() -> void:
	var panel_size := Vector2(clampf(size.x * 0.78, 820.0, 1180.0), clampf(size.y * 0.78, 560.0, 790.0))
	_panel_rect = Rect2((size - panel_size) * 0.5, panel_size)
	_work_rect = Rect2(
		_panel_rect.position + Vector2(28.0, 112.0),
		Vector2(_panel_rect.size.x * 0.68, _panel_rect.size.y - 158.0)
	)
	_handle_track = Rect2(
		Vector2(_panel_rect.position.x + _panel_rect.size.x * 0.79, _panel_rect.position.y + 178.0),
		Vector2(_panel_rect.size.x * 0.13, _panel_rect.size.y - 292.0)
	)
	var travel_half := _handle_track.size.y * 0.5 - _handle_radius
	_handle_center = _handle_track.get_center() + Vector2(0.0, _handle_value * travel_half)
	_nail_centers.clear()
	for board_index in 4:
		for side in 2:
			_nail_centers.append(_board_nail_position(board_index, side))


func _board_center(board_index: int) -> Vector2:
	return _work_rect.position + Vector2(_work_rect.size.x * 0.5, _work_rect.size.y * (0.16 + board_index * 0.225))


func _board_angle(board_index: int) -> float:
	return [0.105, -0.135, 0.075, -0.165][board_index]


func _board_nail_position(board_index: int, side: int) -> Vector2:
	var local_offset := Vector2((-1.0 if side == 0 else 1.0) * _work_rect.size.x * 0.285, 0.0)
	return _board_center(board_index) + local_offset.rotated(_board_angle(board_index))


func _draw() -> void:
	_update_layout()
	draw_rect(_panel_rect.grow(16.0), Color(0.0, 0.0, 0.0, 0.26))
	draw_rect(_panel_rect, Color(0.045, 0.052, 0.049, 0.64))
	draw_rect(Rect2(_panel_rect.position + Vector2(14, 14), Vector2(_panel_rect.size.x - 28, 78)), Color(0.02, 0.026, 0.024, 0.76))
	draw_rect(_panel_rect, Color(0.44, 0.47, 0.43, 0.7), false, 3.0)
	draw_string(PIXEL_FONT, _panel_rect.position + Vector2(30, 48), "PUERTA ATRANCADA", HORIZONTAL_ALIGNMENT_LEFT, _panel_rect.size.x - 60, 18, Color(0.78, 0.81, 0.75))
	draw_string(PIXEL_FONT, _panel_rect.position + Vector2(30, 75), _instruction_text(), HORIZONTAL_ALIGNMENT_LEFT, _panel_rect.size.x - 60, 9, Color(0.56, 0.6, 0.56))

	_draw_boards_and_nails()
	if _selected_nail >= 0 and _phase != Phase.SELECT_NAIL:
		_draw_crowbar_animation()
	_draw_handle_control()

	draw_string(PIXEL_FONT, _panel_rect.position + Vector2(30, _panel_rect.size.y - 24), "ESC  SALIR", HORIZONTAL_ALIGNMENT_LEFT, 180, 9, Color(0.46, 0.49, 0.46))
	draw_string(PIXEL_FONT, _panel_rect.position + Vector2(_panel_rect.size.x - 250, _panel_rect.size.y - 24), "CLAVOS  %d / %d" % [_count_removed_nails(), NAIL_COUNT], HORIZONTAL_ALIGNMENT_RIGHT, 220, 10, Color(0.7, 0.73, 0.68))


func _instruction_text() -> String:
	match _phase:
		Phase.SELECT_NAIL: return "HAZ CLIC EN UN CLAVO"
		Phase.INSERTING_CROWBAR: return "METIENDO LA PALANCA BAJO EL CLAVO..."
		Phase.PRYING: return "AGARRA EL POMO Y MUÉVELO ARRIBA Y ABAJO"
		Phase.NAIL_RELEASED: return "CLAVO EXTRAÍDO"
		Phase.FINISHED: return "PUERTA DESPEJADA"
	return ""


func _draw_boards_and_nails() -> void:
	for board_index in 4:
		var center := _board_center(board_index)
		var angle := _board_angle(board_index)
		var half_size := Vector2(_work_rect.size.x * 0.43, 34.0)
		var corners := PackedVector2Array([
			center + Vector2(-half_size.x, -half_size.y).rotated(angle),
			center + Vector2(half_size.x, -half_size.y).rotated(angle),
			center + Vector2(half_size.x, half_size.y).rotated(angle),
			center + Vector2(-half_size.x, half_size.y).rotated(angle),
		])
		var board_removed := _removed_nails[board_index * 2] and _removed_nails[board_index * 2 + 1]
		var wood_color := Color(0.19, 0.105, 0.055, 0.34 if board_removed else 0.94)
		draw_colored_polygon(corners, wood_color)
		draw_polyline(PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]]), Color(0.42, 0.25, 0.13, 0.7), 3.0, true)
		for grain_offset in [-14.0, 7.0, 19.0]:
			var grain_from := center + Vector2(-half_size.x * 0.88, grain_offset).rotated(angle)
			var grain_to := center + Vector2(half_size.x * 0.88, grain_offset + 3.0).rotated(angle)
			draw_line(grain_from, grain_to, Color(0.08, 0.04, 0.025, 0.35), 2.0)

		for side in 2:
			var nail_index := board_index * 2 + side
			var nail_center := _nail_centers[nail_index]
			var lift := _nail_progress * 28.0 if nail_index == _selected_nail else 0.0
			nail_center.y -= lift
			if _removed_nails[nail_index]:
				draw_circle(_nail_centers[nail_index], 10.0, Color(0.035, 0.028, 0.022, 0.9))
				draw_arc(_nail_centers[nail_index], 13.0, 0, TAU, 24, Color(0.25, 0.15, 0.09, 0.7), 3.0, true)
			else:
				var selected := nail_index == _selected_nail
				if _phase == Phase.SELECT_NAIL:
					var pulse := 20.0 + sin(_pulse_time * 4.0 + nail_index) * 3.0
					draw_arc(nail_center, pulse, 0, TAU, 28, Color(0.72, 0.74, 0.68, 0.55), 2.0, true)
				draw_circle(nail_center + Vector2(3, 4), 14.0, Color(0, 0, 0, 0.52))
				draw_circle(nail_center, 13.0, Color(0.39, 0.4, 0.37) if selected else Color(0.25, 0.26, 0.24))
				draw_line(nail_center + Vector2(-6, 0), nail_center + Vector2(6, 0), Color(0.08, 0.08, 0.07), 3.0)


func _draw_crowbar_animation() -> void:
	var nail_position := _nail_centers[_selected_nail] - Vector2(0.0, _nail_progress * 28.0)
	var inserted_tip := nail_position + Vector2(-5.0, 11.0)
	var entry_tip := nail_position + Vector2(-115.0, 92.0)
	var tip := entry_tip.lerp(inserted_tip, _insertion_amount)
	var handle_end := tip + Vector2(-145.0, 115.0 + _handle_value * 28.0)
	draw_line(handle_end + Vector2(5, 7), tip + Vector2(5, 7), Color(0, 0, 0, 0.56), 22.0, true)
	draw_line(handle_end, tip, Color(0.42, 0.035, 0.025), 17.0, true)
	draw_line(tip - (handle_end - tip).normalized() * 4.0, tip + Vector2(23, -3), Color(0.62, 0.64, 0.6), 10.0, true)
	draw_circle(handle_end, 11.0, Color(0.19, 0.02, 0.015))
	var progress_rect := Rect2(_work_rect.position + Vector2(22, _work_rect.size.y - 35), Vector2(_work_rect.size.x - 44, 12))
	draw_rect(progress_rect, Color(0.015, 0.02, 0.018, 0.82))
	draw_rect(Rect2(progress_rect.position, Vector2(progress_rect.size.x * _nail_progress, progress_rect.size.y)), Color(0.59, 0.63, 0.57, 0.9))


func _draw_handle_control() -> void:
	var enabled := _phase == Phase.PRYING
	var track_color := Color(0.3, 0.32, 0.3, 0.9 if enabled else 0.35)
	draw_rect(_handle_track.grow(16), Color(0.015, 0.02, 0.018, 0.62))
	draw_line(Vector2(_handle_track.get_center().x, _handle_track.position.y), Vector2(_handle_track.get_center().x, _handle_track.end.y), track_color, 12.0, true)
	draw_circle(_handle_center + Vector2(5, 7), _handle_radius + 3.0, Color(0, 0, 0, 0.62))
	draw_circle(_handle_center, _handle_radius, Color(0.52, 0.055, 0.035, 1.0 if enabled else 0.42))
	draw_circle(_handle_center - Vector2(0, 7), _handle_radius * 0.63, Color(0.76, 0.1, 0.06, 1.0 if enabled else 0.36))
	draw_string(PIXEL_FONT, Vector2(_handle_track.position.x - 34, _handle_track.end.y + 42), "POMO", HORIZONTAL_ALIGNMENT_CENTER, _handle_track.size.x + 68, 10, Color(0.62, 0.65, 0.61))
	if enabled:
		var arrow_y := _handle_track.position.y - 24.0 if _handle_target < 0.0 else _handle_track.end.y + 25.0
		draw_string(PIXEL_FONT, Vector2(_handle_track.position.x - 34, arrow_y), "▲" if _handle_target < 0.0 else "▼", HORIZONTAL_ALIGNMENT_CENTER, _handle_track.size.x + 68, 18, Color(0.82, 0.84, 0.78))
