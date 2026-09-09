extends Control

const TREE_INK := Color(0.56, 0.61, 0.56, 0.58)
const CONTROLS_INK := Color(0.90, 0.93, 0.86, 0.96)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	_draw_archive_tree()
	# Un único '[' alto que abraza la columna CONTROLES desde su izquierda.
	var x := size.x - 405.0
	# Desde el centro de "CONTROLES" hasta el centro de "TAB / ESC", la última
	# opción del panel. Es una línea continua como los brackets centrales.
	var top := size.y * 0.255
	var bottom := size.y * 0.740
	draw_polyline(PackedVector2Array([
		Vector2(x + 24.0, top),
		Vector2(x, top),
		Vector2(x, bottom),
		Vector2(x + 24.0, bottom),
	]), CONTROLS_INK, 3.0)


func _draw_archive_tree() -> void:
	# El texto conserva exactamente su posición. Estas líneas ocupan únicamente
	# el margen que ya dejan el puntero y el espaciado original del listado.
	# Tres píxeles a la derecha respecto a la colocación anterior.
	var trunk_x := 68.0
	# El RichTextLabel centra las nueve líneas de este bloque: la primera cinta
	# queda aquí y las siguientes avanzan exactamente dos alturas de línea.
	var first_row_y := size.y * 0.444 + 8.0
	var row_step := 51.0
	var last_row_y := first_row_y + row_step * 3.0
	# El tronco comienza claramente por debajo del título; las cuatro ramas no
	# cambian de sitio y siguen centradas con sus respectivas letras C.
	var root_y := first_row_y - 30.0
	draw_line(Vector2(trunk_x, root_y), Vector2(trunk_x, last_row_y), TREE_INK, 3.0)
	for index in 4:
		var row_y := first_row_y + row_step * index
		draw_line(Vector2(trunk_x, row_y), Vector2(trunk_x + 18.0, row_y), TREE_INK, 3.0)
