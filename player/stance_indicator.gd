extends Control

## Silueta articulada del estado corporal del jugador.

const INK := Color(0.86, 0.9, 0.83, 1.0)
const OUTLINE_INK := Color(0.02, 0.025, 0.02, 1.0)
const SHADOW_INK := Color(0.0, 0.0, 0.0, 1.0)
const RASTER_SIZE := Vector2i(84, 84)
const DISPLAY_RASTER_SIZE := Vector2i(42, 42)
const OUTLINE_RADIUS := 2
const SHADOW_OFFSET := Vector2i(3, 3)

var _from_stance := 0
var _to_stance := 0
var _blend := 1.0
var _walking := false
var _walking_blend := 0.0
var _walking_phase := 0.0
var _crouch_moving := false
var _crouch_blend := 0.0
var _crouch_phase := 0.0
var _prone_moving := false
var _prone_blend := 0.0
var _prone_phase := 0.0
var _running := false
var _running_blend := 0.0
var _running_phase := 0.0
var _raster_texture: ImageTexture


func _process(delta: float) -> void:
	var walking_target := 1.0 if _walking and not _running else 0.0
	var next_walking_blend := move_toward(_walking_blend, walking_target, delta * 8.0)
	if not is_equal_approx(next_walking_blend, _walking_blend):
		_walking_blend = next_walking_blend
		queue_redraw()
	if _walking_blend > 0.001:
		_walking_phase = fmod(_walking_phase + delta * 6.0, TAU)
		queue_redraw()
	var next_crouch_blend := move_toward(_crouch_blend, 1.0 if _crouch_moving else 0.0, delta * 8.0)
	if not is_equal_approx(next_crouch_blend, _crouch_blend):
		_crouch_blend = next_crouch_blend
		queue_redraw()
	if _crouch_blend > 0.001:
		_crouch_phase = fmod(_crouch_phase + delta * 5.2, TAU)
		queue_redraw()
	var next_prone_blend := move_toward(_prone_blend, 1.0 if _prone_moving else 0.0, delta * 8.0)
	if not is_equal_approx(next_prone_blend, _prone_blend):
		_prone_blend = next_prone_blend
		queue_redraw()
	if _prone_blend > 0.001:
		_prone_phase = fmod(_prone_phase + delta * 4.6, TAU)
		queue_redraw()
	var target := 1.0 if _running else 0.0
	var next_blend := move_toward(_running_blend, target, delta * 8.0)
	if not is_equal_approx(next_blend, _running_blend):
		_running_blend = next_blend
		queue_redraw()
	if _running_blend > 0.001:
		_running_phase = fmod(_running_phase + delta * 9.0, TAU)
		queue_redraw()


func set_running(running: bool) -> void:
	_running = running


func set_walking(walking: bool) -> void:
	_walking = walking


func set_crouch_moving(moving: bool) -> void:
	_crouch_moving = moving


func set_prone_moving(moving: bool) -> void:
	_prone_moving = moving


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
	var from_pose := _pose_for(_from_stance)
	var to_pose := _pose_for(_to_stance)
	var pose: Array[Vector2] = []
	var walking_pose := _walking_pose()
	var crouch_pose := _four_frame_pose([11, 12, 13, 14], _crouch_phase)
	var prone_pose := _four_frame_pose([15, 16, 17, 18], _prone_phase)
	var running_pose := _running_pose()
	for index in from_pose.size():
		var stance_point := from_pose[index].lerp(to_pose[index], _blend)
		var walking_point := stance_point.lerp(walking_pose[index], _walking_blend)
		var crouch_point := walking_point.lerp(crouch_pose[index], _crouch_blend)
		var prone_point := crouch_point.lerp(prone_pose[index], _prone_blend)
		pose.append(prone_point.lerp(running_pose[index], _running_blend))
	# La postura de Ctrl queda dos píxeles visuales más baja. Interpolar el
	# desplazamiento evita que el monigote dé un salto al cambiar de postura.
	var crouch_drop := lerpf(2.0 if _from_stance == 1 else 0.0, 2.0 if _to_stance == 1 else 0.0, _blend) * (1.0 - maxf(_walking_blend, _running_blend))
	for index in pose.size():
		pose[index].y += crouch_drop
	var silhouette := Image.create(RASTER_SIZE.x, RASTER_SIZE.y, false, Image.FORMAT_RGBA8)
	silhouette.fill(Color.TRANSPARENT)
	_draw_figure_to_image(silhouette, pose)
	var image := _style_silhouette(silhouette)
	# Reducir la máscara antes de ampliarla genera píxeles grandes reales. El
	# filtro nearest conserva cada bloque completamente duro, sin difuminado.
	image.resize(DISPLAY_RASTER_SIZE.x, DISPLAY_RASTER_SIZE.y, Image.INTERPOLATE_NEAREST)
	# Conservar la referencia entre fotogramas; una textura local puede liberarse
	# al terminar _draw y Godot muestra entonces su placeholder blanco.
	_raster_texture = ImageTexture.create_from_image(image)
	draw_texture_rect(_raster_texture, Rect2(Vector2.ZERO, size), false)


func _style_silhouette(silhouette: Image) -> Image:
	var styled := Image.create(RASTER_SIZE.x, RASTER_SIZE.y, false, Image.FORMAT_RGBA8)
	styled.fill(Color.TRANSPARENT)
	# Sombra dura equivalente al desplazamiento de la fuente del HUD.
	for y in RASTER_SIZE.y:
		for x in RASTER_SIZE.x:
			if silhouette.get_pixel(x, y).a <= 0.0:
				continue
			var shadow_pixel := Vector2i(x, y) + SHADOW_OFFSET
			if shadow_pixel.x < RASTER_SIZE.x and shadow_pixel.y < RASTER_SIZE.y:
				styled.set_pixelv(shadow_pixel, SHADOW_INK)
	# Contorno cuadrado y compacto, sin antialiasing, como las letras de cámara.
	for y in RASTER_SIZE.y:
		for x in RASTER_SIZE.x:
			if silhouette.get_pixel(x, y).a <= 0.0:
				continue
			for oy in range(-OUTLINE_RADIUS, OUTLINE_RADIUS + 1):
				for ox in range(-OUTLINE_RADIUS, OUTLINE_RADIUS + 1):
					var outline_pixel := Vector2i(x + ox, y + oy)
					if outline_pixel.x >= 0 and outline_pixel.y >= 0 and outline_pixel.x < RASTER_SIZE.x and outline_pixel.y < RASTER_SIZE.y:
						styled.set_pixelv(outline_pixel, OUTLINE_INK)
	# El relleno se aplica al final para conservar una silueta limpia y uniforme.
	for y in RASTER_SIZE.y:
		for x in RASTER_SIZE.x:
			if silhouette.get_pixel(x, y).a > 0.0:
				styled.set_pixel(x, y, INK)
	return styled


func _running_pose() -> Array[Vector2]:
	# Cuatro fases anatómicas impiden que las rodillas y los pies atraviesen el
	# cuerpo al cambiar de apoyo: contacto, paso, contacto contrario y paso.
	var frame_position: float = fmod(_running_phase, TAU) / TAU * 4.0
	var frame_index := int(floor(frame_position))
	var next_frame_index := (frame_index + 1) % 4
	var frame_blend: float = frame_position - floor(frame_position)
	frame_blend = frame_blend * frame_blend * (3.0 - 2.0 * frame_blend)
	var frame_ids := [3, 4, 5, 6]
	var current_frame := _pose_for(frame_ids[frame_index])
	var next_frame := _pose_for(frame_ids[next_frame_index])
	var pose: Array[Vector2] = []
	for index in current_frame.size():
		pose.append(current_frame[index].lerp(next_frame[index], frame_blend))
	return pose


func _walking_pose() -> Array[Vector2]:
	var frame_position: float = fmod(_walking_phase, TAU) / TAU * 4.0
	var frame_index := int(floor(frame_position))
	var next_frame_index := (frame_index + 1) % 4
	var frame_blend: float = frame_position - floor(frame_position)
	frame_blend = frame_blend * frame_blend * (3.0 - 2.0 * frame_blend)
	var frame_ids := [7, 8, 9, 10]
	var current_frame := _pose_for(frame_ids[frame_index])
	var next_frame := _pose_for(frame_ids[next_frame_index])
	var pose: Array[Vector2] = []
	for index in current_frame.size():
		pose.append(current_frame[index].lerp(next_frame[index], frame_blend))
	return pose


func _four_frame_pose(frame_ids: Array, phase: float) -> Array[Vector2]:
	var frame_position: float = fmod(phase, TAU) / TAU * 4.0
	var frame_index := int(floor(frame_position))
	var next_frame_index := (frame_index + 1) % 4
	var frame_blend: float = frame_position - floor(frame_position)
	frame_blend = frame_blend * frame_blend * (3.0 - 2.0 * frame_blend)
	var current_frame := _pose_for(frame_ids[frame_index])
	var next_frame := _pose_for(frame_ids[next_frame_index])
	var pose: Array[Vector2] = []
	for index in current_frame.size():
		pose.append(current_frame[index].lerp(next_frame[index], frame_blend))
	return pose


func _draw_figure_to_image(image: Image, points: Array[Vector2]) -> void:
	# Todas las piezas se fusionan en una única máscara opaca antes de aplicar
	# la opacidad del Control. Las intersecciones nunca suman transparencia.
	_draw_pixel_bone(image, points[1], points[2])
	_draw_pixel_bone(image, points[2], points[3])
	_draw_pixel_bone(image, points[1], points[4])
	_draw_pixel_bone(image, points[4], points[5])
	_draw_pixel_bone(image, points[1], points[6])
	_draw_pixel_bone(image, points[6], points[7])
	_draw_pixel_bone(image, points[3], points[8])
	_draw_pixel_bone(image, points[8], points[9])
	_draw_pixel_bone(image, points[3], points[10])
	_draw_pixel_bone(image, points[10], points[11])
	_stamp_pixel_head(image, points[0].round())


func _draw_pixel_bone(image: Image, a: Vector2, b: Vector2) -> void:
	var steps := maxi(1, ceili(a.distance_to(b)))
	for step in steps + 1:
		var point := a.lerp(b, float(step) / float(steps)).round()
		_stamp_block(image, point, 3)


func _stamp_block(image: Image, center: Vector2, radius: int) -> void:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var pixel := Vector2i(center) + Vector2i(x, y)
			if pixel.x >= 0 and pixel.y >= 0 and pixel.x < RASTER_SIZE.x and pixel.y < RASTER_SIZE.y:
				image.set_pixelv(pixel, INK)


func _stamp_pixel_head(image: Image, center: Vector2) -> void:
	# Cabeza octogonal construida por escalones rectos, como un glifo bitmap.
	for y in range(-9, 10):
		for x in range(-11, 12):
			var corner_cut := 3 if absi(y) >= 7 else 1 if absi(y) >= 5 else 0
			if absi(x) > 11 - corner_cut:
				continue
			var pixel := Vector2i(center) + Vector2i(x, y)
			if pixel.x >= 0 and pixel.y >= 0 and pixel.x < RASTER_SIZE.x and pixel.y < RASTER_SIZE.y:
				image.set_pixelv(pixel, INK)


func _pose_for(stance: int) -> Array[Vector2]:
	match stance:
		3: # carrera: contacto, pierna derecha delante
			return [Vector2(58, 21), Vector2(51, 30), Vector2(45, 40), Vector2(38, 49), Vector2(43, 35), Vector2(31, 31), Vector2(54, 38), Vector2(65, 46), Vector2(49, 57), Vector2(64, 70), Vector2(31, 57), Vector2(17, 68)]
		4: # carrera: apoyo derecho y pierna izquierda pasando flexionada
			return [Vector2(58, 22), Vector2(51, 31), Vector2(45, 41), Vector2(38, 50), Vector2(47, 36), Vector2(58, 44), Vector2(48, 36), Vector2(36, 31), Vector2(39, 60), Vector2(38, 73), Vector2(49, 55), Vector2(50, 66)]
		5: # carrera: contacto contrario, pierna izquierda delante
			return [Vector2(58, 21), Vector2(51, 30), Vector2(45, 40), Vector2(38, 49), Vector2(54, 38), Vector2(65, 46), Vector2(43, 35), Vector2(31, 31), Vector2(31, 57), Vector2(17, 68), Vector2(49, 57), Vector2(64, 70)]
		6: # carrera: apoyo izquierdo y pierna derecha pasando flexionada
			return [Vector2(58, 22), Vector2(51, 31), Vector2(45, 41), Vector2(38, 50), Vector2(48, 36), Vector2(36, 31), Vector2(47, 36), Vector2(58, 44), Vector2(49, 55), Vector2(50, 66), Vector2(39, 60), Vector2(38, 73)]
		7: # andando: contacto con el pie derecho delante
			return [Vector2(43, 14), Vector2(43, 24), Vector2(42, 39), Vector2(42, 49), Vector2(34, 35), Vector2(29, 47), Vector2(51, 35), Vector2(56, 47), Vector2(48, 61), Vector2(56, 75), Vector2(37, 61), Vector2(29, 75)]
		8: # andando: apoyo derecho y paso izquierdo
			return [Vector2(42, 15), Vector2(42, 25), Vector2(42, 40), Vector2(42, 50), Vector2(36, 35), Vector2(33, 48), Vector2(49, 36), Vector2(52, 48), Vector2(43, 62), Vector2(43, 76), Vector2(47, 59), Vector2(49, 69)]
		9: # andando: contacto con el pie izquierdo delante
			return [Vector2(41, 14), Vector2(41, 24), Vector2(42, 39), Vector2(42, 49), Vector2(33, 35), Vector2(28, 47), Vector2(50, 35), Vector2(55, 47), Vector2(37, 61), Vector2(29, 75), Vector2(48, 61), Vector2(56, 75)]
		10: # andando: apoyo izquierdo y paso derecho
			return [Vector2(42, 15), Vector2(42, 25), Vector2(42, 40), Vector2(42, 50), Vector2(35, 36), Vector2(32, 48), Vector2(48, 35), Vector2(51, 48), Vector2(47, 59), Vector2(49, 69), Vector2(43, 62), Vector2(43, 76)]
		11: # agachado: contacto derecho, zancada abierta
			return [Vector2(56, 25), Vector2(49, 34), Vector2(41, 43), Vector2(34, 53), Vector2(47, 41), Vector2(56, 50), Vector2(40, 45), Vector2(33, 56), Vector2(42, 60), Vector2(50, 71), Vector2(28, 61), Vector2(18, 70)]
		12: # agachado: apoyo derecho, izquierda recogida
			return [Vector2(55, 27), Vector2(48, 35), Vector2(40, 44), Vector2(34, 54), Vector2(45, 43), Vector2(49, 54), Vector2(40, 44), Vector2(48, 51), Vector2(35, 62), Vector2(35, 74), Vector2(43, 58), Vector2(46, 67)]
		13: # agachado: contacto izquierdo, brazos alternados
			return [Vector2(56, 25), Vector2(49, 34), Vector2(41, 43), Vector2(34, 53), Vector2(40, 45), Vector2(33, 56), Vector2(47, 41), Vector2(56, 50), Vector2(28, 61), Vector2(18, 70), Vector2(42, 60), Vector2(50, 71)]
		14: # agachado: apoyo izquierdo, derecha recogida
			return [Vector2(55, 27), Vector2(48, 35), Vector2(40, 44), Vector2(34, 54), Vector2(40, 44), Vector2(48, 51), Vector2(45, 43), Vector2(49, 54), Vector2(43, 58), Vector2(46, 67), Vector2(35, 62), Vector2(35, 74)]
		15: # cuatro patas: mano derecha y rodilla izquierda adelantadas
			return [Vector2(62, 42), Vector2(52, 48), Vector2(40, 50), Vector2(28, 51), Vector2(53, 56), Vector2(62, 68), Vector2(42, 58), Vector2(37, 71), Vector2(30, 59), Vector2(36, 70), Vector2(19, 58), Vector2(12, 69)]
		16: # cuatro patas: apoyo diagonal y extremidades recogidas
			return [Vector2(61, 44), Vector2(51, 49), Vector2(39, 51), Vector2(27, 52), Vector2(51, 58), Vector2(51, 72), Vector2(42, 57), Vector2(48, 67), Vector2(28, 60), Vector2(28, 71), Vector2(24, 57), Vector2(30, 66)]
		17: # cuatro patas: mano izquierda y rodilla derecha adelantadas
			return [Vector2(62, 42), Vector2(52, 48), Vector2(40, 50), Vector2(28, 51), Vector2(42, 58), Vector2(37, 71), Vector2(53, 56), Vector2(62, 68), Vector2(19, 58), Vector2(12, 69), Vector2(30, 59), Vector2(36, 70)]
		18: # cuatro patas: segundo apoyo diagonal, espalda nivelada
			return [Vector2(61, 44), Vector2(51, 49), Vector2(39, 51), Vector2(27, 52), Vector2(42, 57), Vector2(48, 67), Vector2(51, 58), Vector2(51, 72), Vector2(24, 57), Vector2(30, 66), Vector2(28, 60), Vector2(28, 71)]
		1: # agachado, de perfil y con la espalda encorvada
			return [Vector2(56, 25), Vector2(49, 34), Vector2(41, 43), Vector2(34, 53), Vector2(47, 42), Vector2(53, 53), Vector2(41, 45), Vector2(45, 56), Vector2(36, 61), Vector2(37, 73), Vector2(29, 62), Vector2(18, 71)]
		2: # a cuatro patas
			return [Vector2(62, 42), Vector2(52, 48), Vector2(40, 50), Vector2(28, 51), Vector2(51, 57), Vector2(55, 70), Vector2(42, 58), Vector2(44, 71), Vector2(27, 59), Vector2(31, 70), Vector2(19, 58), Vector2(12, 69)]
		_: # de pie
			return [Vector2(42, 14), Vector2(42, 24), Vector2(42, 39), Vector2(42, 49), Vector2(31, 35), Vector2(27, 49), Vector2(53, 35), Vector2(57, 49), Vector2(34, 61), Vector2(31, 75), Vector2(50, 61), Vector2(53, 75)]
