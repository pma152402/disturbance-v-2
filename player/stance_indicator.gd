extends Control

## Silueta articulada del estado corporal del jugador.

const INK := Color(0.84, 0.88, 0.8, 0.9)
const SHADOW := Color(0.0, 0.0, 0.0, 0.82)

var _from_stance := 0
var _to_stance := 0
var _blend := 1.0


func set_stance(stance: int) -> void:
	_from_stance = stance
	_to_stance = stance
	_blend = 1.0
	queue_redraw()


func set_transition(from_stance: int, to_stance: int, blend: float) -> void:
	_from_stance = from_stance
	_to_stance = to_stance
	_blend = clampf(blend, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var figure_scale := minf(size.x / 84.0, size.y / 84.0)
	var figure_origin := (size - Vector2(84.0, 84.0) * figure_scale) * 0.5
	draw_set_transform(figure_origin, 0.0, Vector2.ONE * figure_scale)
	var from_pose := _pose_for(_from_stance)
	var to_pose := _pose_for(_to_stance)
	var pose: Array[Vector2] = []
	for index in from_pose.size():
		pose.append(from_pose[index].lerp(to_pose[index], _blend))
	_draw_figure(pose, Vector2(1.5, 2.0), SHADOW, 6.0)
	_draw_figure(pose, Vector2.ZERO, INK, 3.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_figure(p: Array[Vector2], offset: Vector2, color: Color, width: float) -> void:
	# Las coordenadas se redondean para conservar el pixelado sin pasar el HUD
	# por el shader de ondas de la camara.
	var points: Array[Vector2] = []
	for index in p.size():
		points.append((p[index] + offset).round())
	var head := points[0]
	# Cabeza construida en bloques, sin curvas ni filtrado.
	draw_rect(Rect2(head + Vector2(-5, -7), Vector2(10, 14)), color)
	draw_rect(Rect2(head + Vector2(-8, -4), Vector2(16, 8)), color)
	_draw_bone(points[1], points[2], color, width)
	_draw_bone(points[2], points[3], color, width)
	_draw_bone(points[1], points[4], color, width)
	_draw_bone(points[4], points[5], color, width)
	_draw_bone(points[1], points[6], color, width)
	_draw_bone(points[6], points[7], color, width)
	_draw_bone(points[3], points[8], color, width)
	_draw_bone(points[8], points[9], color, width)
	_draw_bone(points[3], points[10], color, width)
	_draw_bone(points[10], points[11], color, width)


func _draw_bone(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	# Una cadena de cuadrados conserva escalones claramente visibles incluso
	# cuando el indicador se muestra grande.
	var distance := a.distance_to(b)
	var pixel_step := 3.0
	var steps := maxi(1, ceili(distance / pixel_step))
	var block_size := ceilf(width)
	for step in steps + 1:
		var point := a.lerp(b, float(step) / float(steps))
		point = (point / pixel_step).round() * pixel_step
		draw_rect(Rect2(point - Vector2.ONE * block_size * 0.5, Vector2.ONE * block_size), color)


func _pose_for(stance: int) -> Array[Vector2]:
	match stance:
		1: # agachado, de perfil y con la espalda encorvada
			return [Vector2(56, 25), Vector2(49, 34), Vector2(41, 43), Vector2(34, 53), Vector2(47, 42), Vector2(53, 53), Vector2(41, 45), Vector2(45, 56), Vector2(36, 61), Vector2(37, 73), Vector2(29, 62), Vector2(18, 71)]
		2: # a cuatro patas
			return [Vector2(62, 42), Vector2(52, 48), Vector2(40, 50), Vector2(28, 51), Vector2(51, 57), Vector2(55, 70), Vector2(42, 58), Vector2(44, 71), Vector2(27, 59), Vector2(31, 70), Vector2(19, 58), Vector2(12, 69)]
		_: # de pie
			return [Vector2(42, 14), Vector2(42, 24), Vector2(42, 39), Vector2(42, 49), Vector2(31, 35), Vector2(27, 49), Vector2(53, 35), Vector2(57, 49), Vector2(34, 61), Vector2(31, 75), Vector2(50, 61), Vector2(53, 75)]
