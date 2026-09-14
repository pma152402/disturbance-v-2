class_name CameraContextAlerts
extends Control

enum AlertKind { LIMITED_SPACE, NO_SPACE, OBJECT_OUT_OF_RANGE, NO_CONNECTION }

const TEXT := {
	AlertKind.LIMITED_SPACE: "ESPACIO LIMITADO",
	AlertKind.NO_SPACE: "SIN ESPACIO",
	AlertKind.OBJECT_OUT_OF_RANGE: "OBJETO FUERA DE RANGO",
	AlertKind.NO_CONNECTION: "SIN CONEXION",
}
const PRIORITY := {
	AlertKind.LIMITED_SPACE: 1,
	AlertKind.OBJECT_OUT_OF_RANGE: 2,
	AlertKind.NO_SPACE: 3,
	AlertKind.NO_CONNECTION: 4,
}
const COLORS := {
	AlertKind.LIMITED_SPACE: Color("d89032"),
	AlertKind.OBJECT_OUT_OF_RANGE: Color("d4d9ce"),
	AlertKind.NO_SPACE: Color("922f2b"),
	AlertKind.NO_CONNECTION: Color("d7463f"),
}

@export_range(0.1, 10.0, 0.1) var display_seconds := 2.4
@export_range(0.0, 10.0, 0.1) var repeat_cooldown_seconds := 4.0
@onready var _label: Label = $AlertPanel/Message
@onready var _panel: Panel = $AlertPanel
@onready var _icon: CameraAlertPixelIcon = $AlertPanel/PixelIcon

var _camera_active := true
var _storage_used := 0
var _storage_capacity := 4
var _connection_lost := false
var _active_kind := -1
var _remaining := 0.0
var _blink_elapsed := 0.0
var _cooldowns := {}
var _latched_conditions := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_blink_elapsed += delta
	for kind in _cooldowns:
		_cooldowns[kind] = maxf(float(_cooldowns[kind]) - delta, 0.0)
	if not _camera_active:
		visible = false
		_update_processing_state()
		return
	if _remaining > 0.0 and _active_kind != AlertKind.NO_CONNECTION:
		_remaining -= delta
		if _remaining <= 0.0:
			visible = false
			_active_kind = -1
	_update_alert_pulse()
	_evaluate_persistent_conditions()
	_update_processing_state()


func _update_processing_state() -> void:
	# Los avisos permanentes no se animan. Los temporales y sus cooldowns
	# conservan el mismo reloj; una nueva condición despierta el componente.
	var needs_update := _camera_active and _remaining > 0.0 and _active_kind != AlertKind.NO_CONNECTION
	for kind in _cooldowns:
		if float(_cooldowns[kind]) > 0.0:
			needs_update = true
			break
	set_process(needs_update)


func _update_alert_pulse() -> void:
	var alpha := 1.0
	if visible and _active_kind == AlertKind.NO_SPACE:
		# Pulso suave: texto e icono respiran sin apagar ni mover el panel.
		alpha = lerpf(0.68, 1.0, (sin(_blink_elapsed * TAU * 1.75) + 1.0) * 0.5)
	_label.modulate.a = alpha
	_icon.modulate.a = alpha


func set_camera_active(active: bool) -> void:
	if _camera_active == active:
		return
	_camera_active = active
	if not active:
		visible = false
	set_process(true)


func set_storage_usage(used: int, capacity: int) -> void:
	var next_used := maxi(used, 0)
	var next_capacity := maxi(capacity, 1)
	if next_used == _storage_used and next_capacity == _storage_capacity:
		return
	_storage_used = next_used
	_storage_capacity = next_capacity
	set_process(true)


func notify_object_out_of_range() -> void:
	_show_if_valid(AlertKind.OBJECT_OUT_OF_RANGE, _camera_active)


func notify_no_space() -> void:
	# Es una respuesta directa a una acción del jugador: debe reaparecer en cada
	# intento aunque todavía estuviera activo el cooldown automático.
	_cooldowns.erase(AlertKind.NO_SPACE)
	_show_if_valid(AlertKind.NO_SPACE, _storage_used >= _storage_capacity)


func notify_connection_lost() -> void:
	_connection_lost = true
	_show_if_valid(AlertKind.NO_CONNECTION, true)


func set_camera_font(camera_font: Font) -> void:
	if is_instance_valid(_label) and camera_font != null:
		_label.add_theme_font_override(&"font", camera_font)


func _evaluate_persistent_conditions() -> void:
	_check_condition(AlertKind.LIMITED_SPACE, _storage_used == _storage_capacity - 1)
	_check_condition(AlertKind.NO_SPACE, _storage_used >= _storage_capacity)
	_check_condition(AlertKind.NO_CONNECTION, _connection_lost)


func _check_condition(kind: AlertKind, condition: bool) -> void:
	var was_active := bool(_latched_conditions.get(kind, false))
	_latched_conditions[kind] = condition
	# Solo aparece al entrar en la condición; no martillea al jugador cada pocos
	# segundos mientras el estado siga siendo el mismo.
	if condition and not was_active:
		_show_if_valid(kind, true)


func _show_if_valid(kind: AlertKind, condition: bool) -> void:
	if not condition or not _camera_active or float(_cooldowns.get(kind, 0.0)) > 0.0:
		return
	if _active_kind >= 0 and int(PRIORITY[kind]) < int(PRIORITY[_active_kind]):
		return
	_active_kind = kind
	_blink_elapsed = 0.0
	_label.text = str(TEXT[kind])
	_label.add_theme_color_override(&"font_color", COLORS[kind])
	_icon.icon_kind = kind
	_icon.icon_color = COLORS[kind]
	# El panel adopta el ancho real del texto más icono, separación y márgenes.
	# Nunca reducimos el área del Label, por lo que los mensajes largos no se
	# aplastan ni cambian de línea.
	var font := _label.get_theme_font(&"font")
	var font_size := _label.get_theme_font_size(&"font_size")
	var text_width := font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var panel_width := ceilf(text_width) + 82.0
	_panel.offset_left = -panel_width * 0.5
	_panel.offset_right = panel_width * 0.5
	var panel_style := _panel.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	panel_style.border_color = COLORS[kind].darkened(0.18)
	_panel.add_theme_stylebox_override(&"panel", panel_style)
	_remaining = display_seconds
	_cooldowns[kind] = repeat_cooldown_seconds
	visible = true
	set_process(true)
