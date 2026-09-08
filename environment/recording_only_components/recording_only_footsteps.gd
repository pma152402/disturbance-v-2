@tool
class_name RecordingOnlyFootsteps
extends Node3D

## Rastro sobrenatural que solo renderiza la cámara interna de la cinta.
## La capa 20 queda reservada para pistas que no deben aparecer en directo.

const RECORDING_ONLY_VISIBILITY_LAYER := 20
const RECORDING_ONLY_VISIBILITY_MASK := 1 << (RECORDING_ONLY_VISIBILITY_LAYER - 1)
const FIXED_BRIGHTNESS := 0.5
const FOOTPRINT_WIDTH_FACTOR := 0.85

@export_range(1, 24, 1) var step_count := 8
@export_range(0.2, 1.2, 0.01) var step_distance := 0.52
@export_range(0.08, 0.5, 0.01) var foot_separation := 0.2
@export_category("Aspecto")
@export_range(0.4, 2.0, 0.05) var footprint_scale := 0.88
@export_range(-20.0, 20.0, 0.5) var irregularity_degrees := 3.0
## El color puede elegirse libremente; al renderizar siempre conserva el 50 %
## de su brillo para integrarse con la imagen oscura de la videocámara.
@export var footprint_color := Color(0.68, 0.76, 0.68, 0.72)
@export var fade_oldest_steps := true
@export_category("Revelado en la cinta")
## Distancia máxima desde la cámara de grabación. Obliga a registrar y revisar
## el recorrido por tramos en lugar de revelar el rastro completo de una vez.
@export_range(1.0, 12.0, 0.1) var maximum_recording_distance := 3.2
@export_range(0.0, 2.0, 0.05) var distance_fade_margin := 0.65
@export_category("Vista del editor")
@export var show_editor_preview := true

var _editor_configuration := ""


func _ready() -> void:
	if not Engine.is_editor_hint() or show_editor_preview:
		_build_trail()
	if Engine.is_editor_hint():
		_editor_configuration = _configuration_signature()
		set_process(true)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	var configuration := _configuration_signature()
	if configuration == _editor_configuration:
		return
	_editor_configuration = configuration
	_build_trail()


func _build_trail() -> void:
	for child in get_children():
		if child.is_in_group(&"generated_recording_footprint"):
			remove_child(child)
			child.queue_free()
	if Engine.is_editor_hint() and not show_editor_preview:
		return
	for index in step_count:
		var footprint := MeshInstance3D.new()
		footprint.name = "Footprint%02d" % (index + 1)
		footprint.add_to_group(&"generated_recording_footprint")
		footprint.mesh = _make_footprint_mesh(index % 2 == 1)
		footprint.position = Vector3(
			(-1.0 if index % 2 == 0 else 1.0) * foot_separation * 0.5,
			0.012 + float(index % 3) * 0.0005,
			-float(index) * step_distance
		)
		footprint.rotation.y = deg_to_rad(
			(-1.0 if index % 2 == 0 else 1.0) * irregularity_degrees
		)
		footprint.scale = Vector3.ONE * footprint_scale
		# La previsualización usa la capa 1 para que el viewport del editor siempre
		# pueda mostrarla. Al jugar vuelve a la capa exclusiva de la cinta.
		footprint.layers = 1 if Engine.is_editor_hint() else RECORDING_ONLY_VISIBILITY_MASK
		footprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not Engine.is_editor_hint():
			footprint.visibility_range_end = maximum_recording_distance
			footprint.visibility_range_end_margin = minf(distance_fade_margin, maximum_recording_distance)
			footprint.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(footprint)


func _configuration_signature() -> String:
	# En modo @tool el inspector puede entregar temporalmente Variants durante la
	# recarga del script. str() evita exigirles un tipo numérico en ese fotograma.
	return "|".join(PackedStringArray([
		str(step_count),
		str(step_distance),
		str(foot_separation),
		str(footprint_scale),
		str(irregularity_degrees),
		str(footprint_color),
		str(fade_oldest_steps),
		str(maximum_recording_distance),
		str(distance_fade_margin),
		str(show_editor_preview),
	]))


func _make_footprint_mesh(mirrored: bool) -> ArrayMesh:
	var outline := PackedVector2Array([
		Vector2(-0.075, -0.215),
		Vector2(-0.115, -0.165),
		Vector2(-0.12, -0.075),
		Vector2(-0.095, 0.055),
		Vector2(-0.075, 0.17),
		Vector2(-0.035, 0.215),
		Vector2(0.045, 0.205),
		Vector2(0.09, 0.145),
		Vector2(0.105, 0.035),
		Vector2(0.09, -0.105),
		Vector2(0.055, -0.205),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var alpha := footprint_color.a
	if fade_oldest_steps and step_count > 1:
		var trail_index := get_child_count()
		alpha *= lerpf(0.35, 1.0, float(trail_index) / float(step_count - 1))
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(
		footprint_color.r * FIXED_BRIGHTNESS,
		footprint_color.g * FIXED_BRIGHTNESS,
		footprint_color.b * FIXED_BRIGHTNESS,
		alpha
	)
	material.vertex_color_use_as_albedo = true
	surface.set_material(material)
	var center := Vector3.ZERO
	for point_index in outline.size():
		var point_a := outline[point_index]
		var point_b := outline[(point_index + 1) % outline.size()]
		if mirrored:
			point_a.x = -point_a.x
			point_b.x = -point_b.x
		surface.set_normal(Vector3.UP)
		surface.set_color(Color.WHITE)
		surface.add_vertex(center)
		surface.set_normal(Vector3.UP)
		surface.set_color(Color.WHITE)
		surface.add_vertex(Vector3(point_a.x * FOOTPRINT_WIDTH_FACTOR, 0.0, point_a.y))
		surface.set_normal(Vector3.UP)
		surface.set_color(Color.WHITE)
		surface.add_vertex(Vector3(point_b.x * FOOTPRINT_WIDTH_FACTOR, 0.0, point_b.y))
	return surface.commit()
