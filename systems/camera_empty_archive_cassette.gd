extends Control
## Pictograma de fondo de bajo contraste para un archivo de cámara vacío.

const DESIGN_SIZE := Vector2(820.0, 520.0)
const DARKEST_EXISTING := Color(0.25, 0.28, 0.26, 0.30)
const DEEPER_INK := Color(0.205, 0.23, 0.215, 0.42)
const PROHIBITED_CENTER := Vector2(410.0, 260.0)
const PROHIBITED_RADIUS := 205.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var scale_factor := minf(size.x / 1020.0, size.y / 620.0)
	var drawing_size := DESIGN_SIZE * scale_factor
	var origin := (size - drawing_size) * 0.5
	draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)
	_draw_cassette()
	# Se dibuja después para que la prohibición cubra físicamente el casete.
	_draw_prohibited_symbol()


func _draw_cassette() -> void:
	# Dos únicos tonos oscuros: la forma debe leerse sin separarse del fondo.
	draw_rect(Rect2(60, 92, 700, 340), DEEPER_INK)
	draw_rect(Rect2(74, 106, 672, 312), DARKEST_EXISTING)
	draw_rect(Rect2(142, 166, 536, 150), DEEPER_INK)
	draw_rect(Rect2(162, 184, 496, 114), DARKEST_EXISTING)
	_draw_reel(Vector2(270, 241))
	_draw_reel(Vector2(550, 241))
	var lower_panel := PackedVector2Array([
		Vector2(225, 418), Vector2(595, 418), Vector2(550, 330), Vector2(270, 330),
	])
	draw_colored_polygon(lower_panel, DEEPER_INK)


func _draw_reel(center: Vector2) -> void:
	draw_circle(center, 53.0, DEEPER_INK)
	draw_circle(center, 25.0, DARKEST_EXISTING)


func _draw_prohibited_symbol() -> void:
	draw_arc(PROHIBITED_CENTER, PROHIBITED_RADIUS, 0.0, TAU, 72, DARKEST_EXISTING, 30.0)
	var diagonal := Vector2(145.0, 145.0)
	draw_line(PROHIBITED_CENTER - diagonal, PROHIBITED_CENTER + diagonal, DARKEST_EXISTING, 34.0)
