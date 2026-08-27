@tool
extends StaticBody3D

@export_range(0.7, 20.0, 0.05) var length := 3.2:
	set(value):
		length = maxf(value, 0.7)
		_rebuild_requested = true

@export_range(0.22, 0.75, 0.01) var preferred_baluster_spacing := 0.39:
	set(value):
		preferred_baluster_spacing = maxf(value, 0.22)
		_rebuild_requested = true

@export var adapt_to_x_scale := true

var _rebuild_requested := true
var _last_scale_x := -1.0


func _ready() -> void:
	_rebuild_requested = true
	call_deferred(&"_rebuild")


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var current_scale_x := absf(scale.x)
	if not is_equal_approx(current_scale_x, _last_scale_x):
		_rebuild_requested = true
	if _rebuild_requested:
		_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_rebuild_requested = false
	_last_scale_x = absf(scale.x)
	_set_width($BottomPlinth, length)
	_set_width($BottomTrim, maxf(0.5, length - 0.12))
	_set_width($TopRail, length)
	_set_width($TopRailCap, length + 0.12)
	var edge := maxf(0.22, length * 0.5 - 0.1)
	$LeftEndPost.position.x = -edge
	$LeftPostCap.position.x = -edge
	$RightEndPost.position.x = edge
	$RightPostCap.position.x = edge
	# Al estirar el nodo, los postes se desplazan pero conservan su grosor real.
	var inverse_x := 1.0 / maxf(absf(scale.x), 0.001) if adapt_to_x_scale else 1.0
	_set_fixed_x_scale($LeftEndPost, 0.26, inverse_x)
	_set_fixed_x_scale($RightEndPost, 0.26, inverse_x)
	_set_fixed_x_scale($LeftPostCap, 0.35, inverse_x)
	_set_fixed_x_scale($RightPostCap, 0.35, inverse_x)
	var shape := $Collision.shape as BoxShape3D
	if shape != null:
		shape.size.x = length
	_update_multimeshes()


func _set_width(part: MeshInstance3D, width: float) -> void:
	var value := part.scale
	value.x = width
	part.scale = value


func _set_fixed_x_scale(part: MeshInstance3D, original_width: float, inverse_x: float) -> void:
	var value := part.scale
	value.x = original_width * inverse_x
	part.scale = value


func _update_multimeshes() -> void:
	var local_width := maxf(0.18, length - 0.66)
	var x_factor := absf(scale.x) if adapt_to_x_scale else 1.0
	var visible_width := local_width * x_factor
	var count := maxi(1, int(floor(visible_width / preferred_baluster_spacing)) + 1)
	var local_step := local_width / float(maxi(1, count - 1))
	var inverse_x := 1.0 / maxf(x_factor, 0.001)
	_update_layer($Balusters/Shafts, count, local_width, local_step, 0.69, inverse_x)
	_update_layer($Balusters/Bulbs, count, local_width, local_step, 0.48, inverse_x)
	_update_layer($Balusters/Feet, count, local_width, local_step, 0.32, inverse_x)


func _update_layer(layer: MultiMeshInstance3D, count: int, local_width: float, step: float, y: float, inverse_x: float) -> void:
	var multimesh := layer.multimesh
	if multimesh == null:
		return
	# No se crean ni destruyen nodos: el editor puede duplicar la escena con seguridad.
	multimesh.instance_count = count
	var fixed_size_basis := Basis.from_scale(Vector3(inverse_x, 1.0, 1.0))
	for index in count:
		var x := 0.0 if count == 1 else -local_width * 0.5 + step * index
		multimesh.set_instance_transform(index, Transform3D(fixed_size_basis, Vector3(x, y, 0)))
