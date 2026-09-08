@tool
class_name RecordingOnlyPenCircle
extends Node3D

## Círculo irregular dibujado a mano que la cámara en directo no puede ver.

const RECORDING_ONLY_VISIBILITY_MASK := 1 << 19
const FIXED_BRIGHTNESS := 0.5

@export_category("Trazo")
@export_range(0.15, 2.0, 0.01) var radius := 0.52
@export_range(0.01, 0.2, 0.002) var line_width := 0.06
@export_range(0.0, 0.15, 0.005) var irregularity := 0.035
@export_range(16, 96, 1) var segment_count := 52
@export var ink_color := Color(0.68, 0.76, 0.68, 0.72)
@export_category("Revelado en la cinta")
@export_range(1.0, 12.0, 0.1) var maximum_recording_distance := 3.9
@export_range(0.0, 2.0, 0.05) var distance_fade_margin := 0.65
@export_category("Vista del editor")
@export var show_editor_preview := true

var _editor_configuration := ""


func _ready() -> void:
	if not Engine.is_editor_hint() or show_editor_preview:
		_build_circle()
	if Engine.is_editor_hint():
		_editor_configuration = _configuration_signature()
		set_process(true)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	var configuration := _configuration_signature()
	if configuration != _editor_configuration:
		_editor_configuration = configuration
		_build_circle()


func _build_circle() -> void:
	for child in get_children():
		if child.is_in_group(&"generated_recording_only_component"):
			remove_child(child)
			child.queue_free()
	if Engine.is_editor_hint() and not show_editor_preview:
		return
	var circle := MeshInstance3D.new()
	circle.name = "HandDrawnInkCircle"
	circle.add_to_group(&"generated_recording_only_component")
	circle.mesh = _make_circle_mesh()
	circle.position.y = 0.012
	circle.layers = 1 if Engine.is_editor_hint() else RECORDING_ONLY_VISIBILITY_MASK
	circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not Engine.is_editor_hint():
		circle.visibility_range_end = maximum_recording_distance
		circle.visibility_range_end_margin = minf(distance_fade_margin, maximum_recording_distance)
		circle.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(circle)


func _make_circle_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_ink_ring(surface, radius, line_width, 0, segment_count)
	# Una segunda pasada incompleta crea el pequeño solape típico de un círculo
	# repasado con bolígrafo sin convertirlo en una circunferencia perfecta.
	_add_ink_ring(surface, radius + line_width * 0.42, line_width * 0.42, 3, int(segment_count * 0.72))
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(
		ink_color.r * FIXED_BRIGHTNESS,
		ink_color.g * FIXED_BRIGHTNESS,
		ink_color.b * FIXED_BRIGHTNESS,
		ink_color.a
	)
	material.roughness = 1.0
	surface.set_material(material)
	return surface.commit()


func _add_ink_ring(surface: SurfaceTool, base_radius: float, width: float, start_index: int, count: int) -> void:
	for local_index in count:
		var index_a := start_index + local_index
		var index_b := index_a + 1
		var angle_a := TAU * float(index_a) / float(segment_count)
		var angle_b := TAU * float(index_b) / float(segment_count)
		var wobble_a := _radius_wobble(angle_a)
		var wobble_b := _radius_wobble(angle_b)
		var width_a := width * (0.78 + 0.22 * sin(angle_a * 11.0 + 0.7))
		var width_b := width * (0.78 + 0.22 * sin(angle_b * 11.0 + 0.7))
		var outer_a := Vector3(cos(angle_a), 0.0, sin(angle_a)) * (base_radius + wobble_a + width_a)
		var inner_a := Vector3(cos(angle_a), 0.0, sin(angle_a)) * (base_radius + wobble_a - width_a)
		var outer_b := Vector3(cos(angle_b), 0.0, sin(angle_b)) * (base_radius + wobble_b + width_b)
		var inner_b := Vector3(cos(angle_b), 0.0, sin(angle_b)) * (base_radius + wobble_b - width_b)
		_add_triangle(surface, outer_a, inner_a, outer_b)
		_add_triangle(surface, outer_b, inner_a, inner_b)


func _radius_wobble(angle: float) -> float:
	return irregularity * (
		sin(angle * 3.0 + 0.35) * 0.52
		+ sin(angle * 7.0 + 1.7) * 0.31
		+ sin(angle * 13.0 + 0.2) * 0.17
	)


func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for vertex in [a, b, c]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(vertex)


func _configuration_signature() -> String:
	return "|".join(PackedStringArray([
		str(radius), str(line_width), str(irregularity), str(segment_count),
		str(ink_color), str(maximum_recording_distance),
		str(distance_fade_margin), str(show_editor_preview),
	]))
