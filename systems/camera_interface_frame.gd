extends Control

@export var full_frame := false
@export var side_brackets := false
@export var inset := 28.0
@export var corner_length := 92.0
@export var line_width := 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var ink := Color(0.86, 0.9, 0.83, 0.78)
	var bounds := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
	if full_frame:
		draw_rect(bounds, ink, false, line_width)
		return
	var left := bounds.position.x
	var top := bounds.position.y
	var right := bounds.end.x
	var bottom := bounds.end.y
	if side_brackets:
		draw_polyline(PackedVector2Array([
			Vector2(left + corner_length, top), Vector2(left, top),
			Vector2(left, bottom), Vector2(left + corner_length, bottom),
		]), ink, line_width)
		draw_polyline(PackedVector2Array([
			Vector2(right - corner_length, top), Vector2(right, top),
			Vector2(right, bottom), Vector2(right - corner_length, bottom),
		]), ink, line_width)
		return
	for segment in [
		[Vector2(left, top + corner_length), Vector2(left, top), Vector2(left + corner_length, top)],
		[Vector2(right - corner_length, top), Vector2(right, top), Vector2(right, top + corner_length)],
		[Vector2(left, bottom - corner_length), Vector2(left, bottom), Vector2(left + corner_length, bottom)],
		[Vector2(right - corner_length, bottom), Vector2(right, bottom), Vector2(right, bottom - corner_length)],
	]:
		draw_polyline(PackedVector2Array(segment), ink, line_width)
