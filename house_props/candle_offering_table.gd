extends StaticBody3D

## Mesa de ofrendas para el puzzle de la iglesia.
## La tapa reproduce los tres patrones de la referencia: A, B y C.

signal puzzle_completed

## Marcados en rojo en la referencia: A(6,9,10), B(12,20,22), C(24,25).
@export var solution_slots: Array[int] = [6, 9, 10, 12, 20, 22, 24, 25]
@export var snap_radius := 0.18
@export var completion_message := "PATRON CORRECTO\nMINIJUEGO COMPLETADO"
@export_category("Depuracion")
@export var flash_solution_on_start := false
@export_range(0.2, 5.0, 0.1) var solution_flash_duration := 20.0

@onready var slots_root: Node3D = $Slots
@onready var status_light: OmniLight3D = $StatusLight

var _occupied_slots: Dictionary = {}
var _completed := false


func _ready() -> void:
	_register_initial_candles()
	if flash_solution_on_start:
		call_deferred(&"_flash_solution_slots")


func _register_initial_candles() -> void:
	for child in slots_root.find_children("InitialCandle*", "RigidBody3D", true, false):
		var candle := child as Node3D
		var slot := candle.get_parent() as Marker3D
		if slot == null:
			continue
		var slot_index := int(slot.get_meta(&"slot_index", -1))
		if slot_index >= 0:
			_occupied_slots[slot_index] = candle


func _flash_solution_slots() -> void:
	var highlighted: Array[MeshInstance3D] = []
	for slot_index in solution_slots:
		var slot := _get_slot(slot_index)
		if slot == null:
			continue
		var socket := slot.get_node_or_null("Socket") as MeshInstance3D
		if socket == null:
			continue
		var highlight := StandardMaterial3D.new()
		highlight.albedo_color = Color(0.08, 0.95, 0.24)
		highlight.emission_enabled = true
		highlight.emission = Color(0.03, 1.0, 0.12)
		highlight.emission_energy_multiplier = 4.0
		highlight.roughness = 0.35
		socket.material_override = highlight
		highlighted.append(socket)
	await get_tree().create_timer(solution_flash_duration).timeout
	for socket in highlighted:
		if is_instance_valid(socket):
			socket.material_override = null


func get_candle_slot_at(world_point: Vector3) -> Dictionary:
	if _completed:
		return {}
	var nearest_index := -1
	var nearest_distance := INF
	for child in slots_root.find_children("Slot*", "Marker3D", true, false):
		var slot := child as Marker3D
		if slot == null:
			continue
		var slot_index := int(slot.get_meta(&"slot_index", -1))
		if _occupied_slots.has(slot_index):
			continue
		var distance := Vector2(world_point.x, world_point.z).distance_to(Vector2(slot.global_position.x, slot.global_position.z))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = slot_index
	if nearest_index < 0 or nearest_distance > snap_radius:
		return {}
	var snap_slot := _get_slot(nearest_index)
	return {"slot": nearest_index, "position": snap_slot.global_position}


func accept_candle(candle: Node3D, slot_index: int) -> bool:
	if _completed or candle == null or _occupied_slots.has(slot_index):
		return false
	var slot := _get_slot(slot_index)
	if slot == null:
		return false
	candle.reparent(self, true)
	candle.global_position = slot.global_position + Vector3.UP * 0.17
	candle.global_rotation = global_rotation
	if candle.has_method(&"set_placed"):
		candle.call(&"set_placed")
	_occupied_slots[slot_index] = candle
	_refresh_state()
	return true


func release_candle(candle: Node3D) -> void:
	for slot_index in _occupied_slots.keys():
		if _occupied_slots[slot_index] == candle:
			_occupied_slots.erase(slot_index)
			if not _completed:
				_refresh_state()
			return


func _get_slot(slot_index: int) -> Marker3D:
	return slots_root.find_child("Slot%d" % slot_index, true, false) as Marker3D


func _refresh_state() -> void:
	var placed := _occupied_slots.keys()
	placed.sort()
	var expected := solution_slots.duplicate()
	expected.sort()
	if placed == expected:
		_completed = true
		status_light.light_color = Color(1.0, 0.55, 0.18)
		status_light.light_energy = 2.2
		_show_completion_message()
		puzzle_completed.emit()
	else:
		status_light.light_color = Color(0.46, 0.08, 0.04)
		status_light.light_energy = 0.38


func _show_completion_message() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().root.add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.01, 0.005, 0.58)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(backdrop)
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -390.0
	label.offset_top = -70.0
	label.offset_right = 390.0
	label.offset_bottom = 70.0
	label.text = completion_message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 30)
	label.add_theme_color_override(&"font_color", Color(0.96, 0.76, 0.38))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	var tween := layer.create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(layer, "modulate:a", 0.0, 0.65)
	tween.tween_callback(layer.queue_free)
