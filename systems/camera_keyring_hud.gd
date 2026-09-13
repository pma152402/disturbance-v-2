extends Control

const HUD_WHITE := Color(0.90, 0.93, 0.86, 0.96)
const HUD_DIM := Color(0.48, 0.53, 0.49, 0.82)
const HUD_SHADOW := Color(0.015, 0.02, 0.016, 0.92)
const KeyText := preload("res://systems/key_display_text.gd")
const RING_CENTER := Vector2(58.0, 30.0)
const RING_RADIUS := 17.0
const KEY_HEAD_RADIUS := 7.0
const PIXEL_GRID := 2.0
const DISPLAY_SECONDS := 2.7
const FADE_SECONDS := 0.55
const KEY_NAMES := {
	&"old_house_key": "LLAVE ANTIGUA",
	&"storage_key": "LLAVE TRASTERO",
	&"diogenes_key": "LLAVE DIOGENES",
	&"main_door_key": "LLAVE PRINCIPAL",
	&"master_bedroom_key": "LLAVE DORMITORIO",
	&"lower_north_wing_key": "LLAVE ALA NORTE",
	&"church_key": "LLAVE IGLESIA",
	&"basement_key": "LLAVE SOTANO",
	&"rooftop_key": "LLAVE AZOTEA",
	&"back_room_key": "LLAVE DEL FONDO",
}

@onready var key_name_label: Label = $KeyName
@onready var cycle_hint: Label = $CycleHint

var _keys: Array[Dictionary] = []
var _selected_index := -1
var _recording_label: CanvasItem
var _display_remaining := 0.0


func _ready() -> void:
	add_to_group(&"camera_keyring")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Se dibuja delante del postproceso. Sus formas se rasterizan sobre una
	# rejilla propia para conservar el acabado pixelado del resto del HUD.
	_recording_label = get_parent().get_node_or_null("CameraHUD/Recording") as CanvasItem
	if not is_instance_valid(_recording_label):
		_recording_label = get_parent().get_node_or_null("Recording") as CanvasItem
	visible = false
	set_process(false)
	_sync_from_player.call_deferred()
	_refresh()


func _process(delta: float) -> void:
	_display_remaining = maxf(0.0, _display_remaining - delta)
	if _display_remaining <= 0.0 or (is_instance_valid(_recording_label) and not _recording_label.visible):
		_display_remaining = 0.0
		visible = false
		set_process(false)
		return
	modulate.a = minf(1.0, _display_remaining / FADE_SECONDS)


func show_or_cycle() -> void:
	if is_instance_valid(_recording_label) and not _recording_label.visible:
		return
	if visible:
		cycle_key()
	_display_remaining = DISPLAY_SECONDS
	modulate.a = 1.0
	visible = true
	set_process(true)


func add_key(key_id: StringName, display_name := "") -> void:
	if key_id.is_empty():
		return
	for index in _keys.size():
		if _keys[index].get("id", &"") == key_id:
			_selected_index = index
			_refresh()
			return
	var resolved_name := display_name.strip_edges()
	if resolved_name.is_empty():
		resolved_name = str(KEY_NAMES.get(key_id, str(key_id).replace("_", " ").to_upper()))
	_keys.append({"id": key_id, "name": KeyText.clean(resolved_name).to_upper()})
	_selected_index = _keys.size() - 1
	_refresh()


func cycle_key() -> bool:
	if _keys.is_empty():
		return false
	_selected_index = wrapi(_selected_index + 1, 0, _keys.size())
	_refresh()
	return true


func get_selected_key_id() -> StringName:
	if _selected_index < 0 or _selected_index >= _keys.size():
		return &""
	return _keys[_selected_index].get("id", &"") as StringName


func _sync_from_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null or not player.has_method(&"get_collected_key_entries"):
		return
	for entry in player.call(&"get_collected_key_entries"):
		if entry is Dictionary:
			add_key(entry.get("id", &"") as StringName, str(entry.get("name", "")))


func _refresh() -> void:
	var has_keys := not _keys.is_empty()
	cycle_hint.modulate = Color.WHITE
	if not has_keys:
		key_name_label.text = "SIN LLAVES"
	else:
		key_name_label.text = str(_keys[_selected_index].get("name", "LLAVE"))
	queue_redraw()


func _draw() -> void:
	# Every collected key stays on the ring. Draw the selected key last so its
	# teeth remain legible as the keyring fills up.
	for index in _keys.size():
		if index != _selected_index:
			_draw_hanging_key(index, false)
	if _selected_index >= 0:
		_draw_hanging_key(_selected_index, true)
	# Aro pequeño y poligonal: acompaña a las llaves sin dominar el icono.
	draw_arc(RING_CENTER + Vector2(2.0, 2.0), RING_RADIUS, 0.0, TAU, 12, HUD_SHADOW, 4.0, false)
	draw_arc(RING_CENTER, RING_RADIUS, 0.0, TAU, 12, HUD_WHITE, 2.5, false)


func _key_angle(index: int) -> float:
	var spread := minf(1.12, float(_keys.size() - 1) * 0.22)
	return PI * 0.5 + lerpf(-spread, spread, float(index) / maxf(float(_keys.size() - 1), 1.0))


func _key_head_center(index: int) -> Vector2:
	return _snap_to_pixel_grid(RING_CENTER + Vector2.from_angle(_key_angle(index)) * RING_RADIUS)


func _snap_to_pixel_grid(point: Vector2) -> Vector2:
	return (point / PIXEL_GRID).round() * PIXEL_GRID


func _draw_hanging_key(index: int, selected: bool) -> void:
	var key_id := str(_keys[index].get("id", "key"))
	var variant := absi(key_id.hash())
	var head_center := _key_head_center(index)
	var direction := Vector2.from_angle(_key_angle(index))
	var side := Vector2(direction.y, -direction.x)
	var length := 34.0 + float(variant % 4) * 3.0
	var ink := HUD_WHITE if selected else Color(0.64, 0.69, 0.63, 0.88)
	# Sombra dura de dos píxeles y formas sin antialias: queda integrada con la
	# tipografía y sobrevive mejor a la pixelación posterior de la cámara.
	_draw_key_body(head_center + Vector2(2.0, 2.0), direction, side, length, variant, HUD_SHADOW, 7.0)
	_draw_key_body(head_center, direction, side, length, variant, ink, 5.0)


func _draw_key_body(
	head_center: Vector2,
	direction: Vector2,
	side: Vector2,
	length: float,
	variant: int,
	ink: Color,
	stroke: float
) -> void:
	draw_arc(head_center, KEY_HEAD_RADIUS, 0.0, TAU, 12, ink, stroke, false)
	draw_line(
		_snap_to_pixel_grid(head_center + direction * (KEY_HEAD_RADIUS - 1.0)),
		_snap_to_pixel_grid(head_center + direction * length),
		ink,
		stroke,
		false
	)
	# Stable lengths/teeth identify each key without changing the collected id.
	for tooth in 3:
		if ((variant >> tooth) & 1) == 0 and tooth == 1:
			continue
		var start := _snap_to_pixel_grid(head_center + direction * (length - 10.0 + tooth * 5.0))
		var depth := 6.0 + float((variant >> (tooth + 3)) & 1) * 2.0
		draw_line(start, _snap_to_pixel_grid(start + side * depth), ink, maxf(4.0, stroke - 1.0), false)
