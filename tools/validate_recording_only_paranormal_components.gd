extends SceneTree

const CIRCLE_SCENE := preload("res://environment/recording_only_components/recording_only_pen_circle.tscn")
const HANGING_MAN_SCENE := preload("res://environment/recording_only_components/recording_only_hanging_man.tscn")
const RECORDING_LAYER := 20


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var circle := CIRCLE_SCENE.instantiate()
	stage.add_child(circle)
	var hanging_man := HANGING_MAN_SCENE.instantiate()
	stage.add_child(hanging_man)
	await process_frame
	if circle.get_child_count() != 1:
		_fail("El círculo no generó exactamente un trazo combinado")
		return
	if not _all_visuals_are_recording_only(circle):
		_fail("El círculo no quedó restringido a la cámara de grabación")
		return
	var figure := hanging_man.get_node_or_null("HangingFigure")
	if figure == null or figure.get_child_count() < 55:
		_fail("La figura colgada no contiene el nivel de detalle esperado")
		return
	for required_part in [
		"CeilingRope", "Noose", "NooseSecondTurn", "SackHead", "SackCenterSeam",
		"ClericalCollarTab", "CassockSkirt", "PriestCrossVertical",
		"LeftHand", "RightHand", "WristBinding01", "WristBindingKnot",
		"LeftShoe", "RightShoe", "AnkleBinding01", "AnkleBindingKnot",
	]:
		if figure.get_node_or_null(required_part) == null:
			_fail("Falta una pieza esencial en la figura colgada: %s" % required_part)
			return
	var noose := figure.get_node("Noose") as MeshInstance3D
	var noose_mesh := noose.mesh as TorusMesh
	if noose_mesh == null or noose_mesh.ring_segments < 16 or noose_mesh.rings < 24:
		_fail("La soga cervical no tiene una sección circular suficientemente suave")
		return
	var collar := figure.get_node("ClericalCollarBand") as MeshInstance3D
	var collar_mesh := collar.mesh as TorusMesh
	var collar_material := collar_mesh.material as StandardMaterial3D
	if collar_mesh == null or collar_material == null or collar_material.albedo_color.r < 0.9:
		_fail("El alzacuellos no es blanco y claramente visible")
		return
	if noose_mesh.outer_radius <= collar_mesh.outer_radius or noose.position.y <= collar.position.y:
		_fail("La soga no envuelve el alzacuellos por fuera y por encima")
		return
	if not _all_visuals_are_recording_only(figure):
		_fail("La figura colgada contiene piezas visibles en directo")
		return
	print("RECORDING ONLY PARANORMAL COMPONENTS PASSED")
	stage.queue_free()
	await process_frame
	quit(0)


func _all_visuals_are_recording_only(root_node: Node) -> bool:
	for child in root_node.get_children():
		if child is VisualInstance3D:
			var visual := child as VisualInstance3D
			if not visual.get_layer_mask_value(RECORDING_LAYER):
				return false
		if not _all_visuals_are_recording_only(child):
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
