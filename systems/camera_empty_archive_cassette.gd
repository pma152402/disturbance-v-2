extends Control
## Pictograma de fondo de bajo contraste para un archivo de cámara vacío.

const DESIGN_SIZE := Vector2(820.0, 520.0)
# Los mismos tonos base del casete 3D, con alfa bajo para que sean fondo.
const BLACK_PLASTIC := Color(0.018, 0.021, 0.024, 0.26)
const EDGE_PLASTIC := Color(0.045, 0.049, 0.052, 0.29)
const PROHIBITED_INK := Color(0.085, 0.095, 0.09, 0.78)
const CASSETTE_RECT := Rect2(85.0, 55.0, 650.0, 410.0)
const PROHIBITED_CENTER := Vector2(410.0, 260.0)
const PROHIBITED_RADIUS := 300.0


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
	# Silueta compacta 1.58:1, igual que la carcasa 0.68 x 0.43 del TSCN.
	var shell := PackedVector2Array([
		Vector2(105, CASSETTE_RECT.position.y),
		Vector2(715, CASSETTE_RECT.position.y),
		Vector2(735, 75), Vector2(735, 445), Vector2(715, 465),
		Vector2(105, 465), Vector2(85, 445), Vector2(85, 75),
	])
	draw_colored_polygon(shell, BLACK_PLASTIC)
	var shell_outline := PackedVector2Array([
		shell[0], shell[1], shell[2], shell[3], shell[4],
		shell[5], shell[6], shell[7], shell[0],
	])
	draw_polyline(shell_outline, EDGE_PLASTIC, 8.0, true)

	# Raíles de la carcasa y placa del cabezal, igual que Shell en el casete 3D.
	draw_line(Vector2(120, 82), Vector2(700, 82), EDGE_PLASTIC, 8.0, true)
	draw_line(Vector2(120, 438), Vector2(700, 438), EDGE_PLASTIC, 8.0, true)
	draw_line(Vector2(112, 100), Vector2(112, 420), EDGE_PLASTIC, 7.0, true)
	draw_line(Vector2(708, 100), Vector2(708, 420), EDGE_PLASTIC, 7.0, true)
	draw_rect(Rect2(338, 428, 144, 12), EDGE_PLASTIC)

	# Ventana grande, cinta visible y las dos bobinas del FaceA/FaceB original.
	var window := PackedVector2Array([
		Vector2(160, 132), Vector2(660, 132), Vector2(680, 152),
		Vector2(680, 318), Vector2(660, 338), Vector2(160, 338),
		Vector2(140, 318), Vector2(140, 152),
	])
	draw_colored_polygon(window, EDGE_PLASTIC)
	draw_rect(Rect2(165, 158, 490, 154), BLACK_PLASTIC)
	draw_line(Vector2(205, 235), Vector2(615, 235), EDGE_PLASTIC, 18.0, true)
	_draw_reel(Vector2(275, 235))
	_draw_reel(Vector2(545, 235))

	# Etiqueta inferior simplificada con sus dos reglas de escritura.
	var label_panel := PackedVector2Array([
		Vector2(245, 352), Vector2(575, 352), Vector2(605, 420), Vector2(215, 420),
	])
	draw_colored_polygon(label_panel, EDGE_PLASTIC)
	draw_line(Vector2(260, 373), Vector2(560, 373), BLACK_PLASTIC, 6.0, true)
	draw_line(Vector2(247, 397), Vector2(573, 397), BLACK_PLASTIC, 6.0, true)

	for screw_center in [Vector2(122, 102), Vector2(698, 102), Vector2(122, 418), Vector2(698, 418)]:
		_draw_screw(screw_center)


func _draw_reel(center: Vector2) -> void:
	draw_circle(center, 70.0, EDGE_PLASTIC)
	draw_circle(center, 51.0, BLACK_PLASTIC)
	draw_circle(center, 29.0, EDGE_PLASTIC)
	draw_circle(center, 13.0, BLACK_PLASTIC)
	for spoke_index in 6:
		var direction := Vector2.RIGHT.rotated(TAU * float(spoke_index) / 6.0)
		draw_line(center + direction * 14.0, center + direction * 27.0, BLACK_PLASTIC, 7.0, true)


func _draw_screw(center: Vector2) -> void:
	draw_circle(center, 7.0, EDGE_PLASTIC)
	draw_line(center + Vector2(-3.5, 0), center + Vector2(3.5, 0), BLACK_PLASTIC, 2.0, true)


func _draw_prohibited_symbol() -> void:
	# Capa superior: ocupa casi todo el alto, pero apenas se separa del fondo.
	draw_arc(PROHIBITED_CENTER, PROHIBITED_RADIUS, 0.0, TAU, 96, PROHIBITED_INK, 18.0, true)
	var diagonal := Vector2(212.0, 212.0)
	draw_line(PROHIBITED_CENTER - diagonal, PROHIBITED_CENTER + diagonal, PROHIBITED_INK, 21.0, true)
