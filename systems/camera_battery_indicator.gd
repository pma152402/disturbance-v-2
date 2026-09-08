extends Label

## Batería compacta dibujada con geometría, sin el espaciado ancho que introduce
## la fuente pixelada entre caracteres verticales.


func _ready() -> void:
	text = "BAT"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	queue_redraw()


func _draw() -> void:
	var ink := get_theme_color(&"font_color")
	# La palabra BAT la compone el propio Label, igual que FPS. El icono se
	# dibuja separado para poder subirlo y compactarlo con precisión.
	# Centro óptico común en Y=29: coincide con el centro del Label BAT.
	# 70 px dejan el mismo margen a ambos lados de las cuatro cargas; no existe
	# espacio residual que pueda leerse como una quinta ranura vacía.
	var body := Rect2(Vector2(116.0, 13.0), Vector2(70.0, 28.0))
	draw_rect(body, ink, false, 3.0)
	for index in 4:
		var bar := Rect2(body.position + Vector2(7.0 + index * 15.0, 6.0), Vector2(11.0, 16.0))
		draw_rect(bar, ink, true)
	# Pequeño borne centrado tras el cierre derecho.
	var terminal := Rect2(Vector2(body.end.x + 2.0, body.position.y + 9.0), Vector2(6.0, 10.0))
	draw_rect(terminal, ink, true)
