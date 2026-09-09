class_name CameraAlertPixelIcon
extends Control

var icon_kind := 0:
	set(value):
		icon_kind = value
		queue_redraw()
var icon_color := Color.WHITE:
	set(value):
		icon_color = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	match icon_kind:
		0: # Memoria casi llena: cartucho con dos de tres celdas ocupadas.
			_pixels([[0, 0], [1, 0], [2, 0], [3, 0], [4, 0], [0, 1], [4, 1], [0, 2], [1, 2], [2, 2], [4, 2], [0, 3], [1, 3], [2, 3], [4, 3], [0, 4], [4, 4], [0, 5], [1, 5], [2, 5], [3, 5], [4, 5]])
		1: # Sin espacio: señal de prohibido circular con barra diagonal.
			_pixels([[1, 0], [2, 0], [3, 0], [4, 0], [0, 1], [1, 1], [5, 1], [0, 2], [2, 2], [5, 2], [0, 3], [3, 3], [5, 3], [0, 4], [4, 4], [5, 4], [1, 5], [2, 5], [3, 5], [4, 5]])
		2: # Objeto fuera de rango: retícula abierta sin blanco central.
			_pixels([[0, 0], [1, 0], [0, 1], [4, 0], [5, 0], [5, 1], [0, 4], [0, 5], [1, 5], [5, 4], [4, 5], [5, 5]])
		3: # Conexión perdida: clavija y toma separadas por un corte diagonal.
			_pixels([[0, 1], [1, 1], [1, 0], [2, 0], [1, 2], [2, 2], [2, 3], [3, 3], [4, 3], [4, 4], [5, 4], [4, 5], [2, 5], [3, 4], [3, 1], [4, 0]])


func _pixels(points: Array) -> void:
	for point in points:
		var cell := point as Array
		draw_rect(Rect2(2.0 + float(cell[0]) * 4.0, 4.0 + float(cell[1]) * 4.0, 4.0, 4.0), icon_color)
