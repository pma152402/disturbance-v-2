extends Node

## Instala el agrupado exclusivo de sombras y la oclusión exacta que han sido
## validados juntos. No altera luces, materiales visibles ni colisiones.
const ShadowBatcher := preload("res://systems/static_shadow_batcher.gd")
const ExactOcclusion := preload("res://systems/runtime_exact_occlusion.gd")

var _shadow_batcher := ShadowBatcher.new()
var _exact_occlusion := ExactOcclusion.new()
var _scene_root: Node
var _house: Node3D
var _enabled := false
var _inventory: Dictionary = {}


static func install(scene_root: Node, house: Node3D) -> Dictionary:
	var existing := scene_root.find_child("RuntimeShadowPipeline", true, false)
	if existing != null:
		return existing.inventory()
	var controller := new()
	controller.name = "RuntimeShadowPipeline"
	controller._scene_root = scene_root
	controller._house = house
	scene_root.add_child(controller)
	controller.enable()
	return controller.inventory()


func enable() -> Dictionary:
	if _enabled or not is_instance_valid(_scene_root) or not is_instance_valid(_house):
		return inventory()
	var shadow_scopes: Array = [{"path": str(_house.get_path()), "stats": _shadow_batcher.install(_house)}]
	var school := _house.get_node_or_null("SchoolUpperFloor") as Node3D
	if school != null:
		shadow_scopes.append({"path": str(school.get_path()), "stats": _shadow_batcher.install(school)})
	var occlusion := _exact_occlusion.install(_scene_root)
	_inventory = {"shadow_scopes": shadow_scopes, "occlusion": occlusion}
	_enabled = true
	return inventory()


func disable() -> void:
	if not _enabled:
		return
	_exact_occlusion.restore()
	_shadow_batcher.restore()
	_enabled = false


func inventory() -> Dictionary:
	var result := _inventory.duplicate(true)
	result["enabled"] = _enabled
	return result
