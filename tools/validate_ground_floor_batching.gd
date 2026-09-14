extends "res://tools/validate_deferred_content_and_batching.gd"

## Reutiliza la firma de geometria/materiales/estado de render independiente del
## agrupador. Requiere GPU: el renderer dummy no conserva matrices de MultiMesh.
const Optimizer := preload("res://systems/runtime_render_optimizer.gd")
const CANDIDATES := {
	"dirty_laundry_basket": 10,
	"wall_towel_holder": 6,
	"old_dress_mannequin": 7,
	"retro_dish_drying_rack": 11,
	"detailed_wood_fired_oven": 20,
}

class ScriptedDecor:
	extends Node3D
	var mutable_state := 0

var _checks := 0
var _failed := false


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Esta validacion requiere renderizador real: ejecutar sin --headless")
		quit(1)
		return
	var expected_savings := CANDIDATES.duplicate()
	# El zapatero es una ampliacion opcional del mismo conjunto conservador.
	if "shoe_dresser" in Batcher.EXACT_FIXED_SCENES:
		expected_savings["shoe_dresser"] = 14
	var total_reduction := 0
	for scene_name: String in expected_savings:
		var prop := _instantiate_prop(scene_name)
		prop.transform = Transform3D(Basis.from_euler(Vector3(0.13, 0.7, -0.2)).scaled(Vector3(0.71, 1.37, 0.93)), Vector3(4.2, -1.5, 7.3))
		var before: Array = []
		var collisions: Dictionary = {}
		_snapshot(prop, before, collisions)
		var csg_before := _csg_snapshot(prop)
		var result: Dictionary = Batcher.optimize(prop)
		var reduction := int(result.source_meshes) - int(result.batches)
		_check(reduction == int(expected_savings[scene_name]), "Reduccion inesperada en %s: %s" % [scene_name, result])
		_compare_snapshot(prop, before, collisions, "agrupacion de " + scene_name)
		_check(_csg_snapshot(prop) == csg_before, "La agrupacion modifica CSG en " + scene_name)
		_check(Batcher.optimize(prop).source_meshes == 0, "Agrupar dos veces modifica " + scene_name)
		_compare_snapshot(prop, before, collisions, "segunda agrupacion de " + scene_name)
		# La integracion real ejecuta despues el optimizador. No debe quitar la
		# sombra de las nuevas agrupaciones pequenas por su tamano o nombre.
		Optimizer.install(prop, false)
		_compare_snapshot(prop, before, collisions, "optimizador de " + scene_name)
		_check(_csg_snapshot(prop) == csg_before, "El optimizador modifica CSG en " + scene_name)
		total_reduction += reduction
		print("GROUND_BATCH: ", scene_name, " ", result.source_meshes, " mallas -> ", result.batches, " grupos; ", reduction, " instancias menos")
		prop.free()
		if _failed:
			quit(1)
			return
	_validate_exclusions()
	# Comprobar también la integración en la casa, no sólo recursos aislados.
	var game := (load("res://levels/test.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	var integrated := 0
	for node in game.find_children("*", "MultiMeshInstance3D", true, false):
		if bool(node.get_meta(&"preserve_authored_shadows", false)):
			integrated += 1
	print("GROUND_BATCH_INTEGRATED: ", integrated, " grupos con sombras preservadas")
	_check(integrated > 0, "La escena real no integra ninguna agrupacion nueva")
	for frame in 2:
		await process_frame
	game.free()
	print("OK: agrupacion de planta baja, ", total_reduction, " instancias menos por conjunto, ", _checks, " comprobaciones; geometria, materiales, matrices, CSG, colisiones, sombras y exclusiones conservados.")
	quit(1 if _failed else 0)


func _instantiate_prop(scene_name: String) -> Node3D:
	var prop := (load("res://house_props/%s.tscn" % scene_name) as PackedScene).instantiate() as Node3D
	root.add_child(prop)
	return prop


func _compare_snapshot(prop: Node3D, expected_visuals: Array, expected_collisions: Dictionary, context: String) -> void:
	var visuals: Array = []
	var collisions: Dictionary = {}
	_snapshot(prop, visuals, collisions)
	_check(collisions == expected_collisions, "Colisiones diferentes tras " + context)
	_check(visuals.size() == expected_visuals.size(), "Cantidad de geometria diferente tras " + context)
	for expected: Array in expected_visuals:
		var match_index := -1
		for index in visuals.size():
			if expected[0] == visuals[index][0] and expected[1].is_equal_approx(visuals[index][1]):
				match_index = index
				break
		_check(match_index >= 0, "Geometria, material, matriz o estado de render diferente tras " + context)
		if match_index >= 0:
			visuals.remove_at(match_index)
	_check(visuals.is_empty(), "Aparece geometria adicional tras " + context)


func _csg_snapshot(prop: Node3D) -> Dictionary:
	var result := {}
	for node in prop.find_children("*", "CSGShape3D", true, false):
		var shape := node as CSGShape3D
		result[str(prop.get_path_to(shape))] = [shape.get_instance_id(), shape.global_transform, shape.visible, shape.operation]
	return result


func _validate_exclusions() -> void:
	var scripted := _instantiate_prop("dirty_laundry_basket")
	scripted.set_script(ScriptedDecor)
	_check(Batcher.optimize(scripted).source_meshes == 0, "Una escena con script no debe agruparse")
	_check(scripted.get("mutable_state") == 0, "Se modifica el estado de un componente con script")
	scripted.free()
	var moving := _instantiate_prop("dirty_laundry_basket")
	var actor := AnimatableBody3D.new()
	moving.add_child(actor)
	_check(Batcher.optimize(moving).source_meshes == 0, "Una escena con cuerpo movil no debe agruparse")
	moving.free()
	var animated := _instantiate_prop("dirty_laundry_basket")
	animated.add_child(AnimationPlayer.new())
	_check(Batcher.optimize(animated).source_meshes == 0, "Una escena animada no debe agruparse")
	animated.free()
	var transparent := _instantiate_prop("dirty_laundry_basket")
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.2, 0.5, 0.7, 0.4)
	for node in transparent.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = glass
	var before: Array = []
	var collisions: Dictionary = {}
	_snapshot(transparent, before, collisions)
	_check(Batcher.optimize(transparent).source_meshes == 0, "Las superficies transparentes no deben agruparse")
	_compare_snapshot(transparent, before, collisions, "exclusion de transparencia")
	transparent.free()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error(message)
