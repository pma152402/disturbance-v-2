@tool
extends Node3D

const BAND_SHADER := preload("res://shaders/pastel_wall_band.gdshader")
const STATIC_DECOR_BATCHER := preload("res://systems/static_decor_batcher.gd")
const RENDER_OPTIMIZER := preload("res://systems/runtime_render_optimizer.gd")
const OCCLUSION_BUILDER := preload("res://systems/runtime_occlusion_builder.gd")
const SECTOR_ACTIVITY_OPTIMIZER := preload("res://systems/runtime_sector_activity_optimizer.gd")
const SKIP_WALL_BAND_GROUP := &"skip_wall_band"
const FULL_STARTUP_VISIBILITY := preload("res://systems/full_startup_visibility.gd")
const SHADOW_PIPELINE := preload("res://systems/runtime_shadow_pipeline.gd")

## Keep church, courtyard props and exterior visible through distant windows.
## Basement remains door-gated and the labyrinth remains loaded on demand.
@export var full_startup_visibility := true


func _ready() -> void:
	var overlay := ShaderMaterial.new()
	overlay.shader = BAND_SHADER
	_apply_to_wall_meshes(self, overlay)
	if not Engine.is_editor_hint():
		STATIC_DECOR_BATCHER.optimize(self)
		var result := RENDER_OPTIMIZER.install(self, not full_startup_visibility)
		var occlusion := {"occluders": 0}
		if not full_startup_visibility:
			occlusion = OCCLUSION_BUILDER.install(self)
		var scene_root := get_tree().current_scene
		if scene_root == null:
			scene_root = get_parent()
		var activity := SECTOR_ACTIVITY_OPTIMIZER.install(scene_root, self, not full_startup_visibility)
		if full_startup_visibility:
			# Exterior vegetation is generated in a later sibling's _ready().
			_apply_full_startup_visibility.call_deferred()
		print(
			"Render optimizer: ", result.detail_meshes, " details culled; ",
			result.managed_lights, " lights; ", result.shadowless_multimeshes,
			" MultiMesh shadows removed; ", occlusion.occluders, " occluders; ",
			activity.audio, " spatial loops, ", activity.lights, " lights and ",
			activity.optional_collisions, " decorative colliders sector-managed."
		)


func _apply_full_startup_visibility() -> void:
	var result := FULL_STARTUP_VISIBILITY.apply(get_parent())
	var shadow_pipeline := SHADOW_PIPELINE.install(get_parent(), self)
	var shadow_sources := 0
	var shadow_batches := 0
	for scope: Dictionary in shadow_pipeline.shadow_scopes:
		shadow_sources += int(scope.stats.sources)
		shadow_batches += int(scope.stats.batches)
	print("Full startup visibility: ", result.geometry, " distance-limited meshes restored; ",
		result.lights, " light fades removed; ", shadow_sources, " static shadow sources in ",
		shadow_batches, " batches; ", shadow_pipeline.occlusion.occluders, " exact occluders.")


func ensure_church_catacombs() -> bool:
	if get_node_or_null("ChurchCatacombs") != null:
		return true
	# Sin preload: ni la geometria ni sus recursos se cargan al arrancar.
	var packed := load("res://environment/church_catacombs.tscn") as PackedScene
	var navigation := load("res://systems/runtime_catacomb_navigation.tscn") as PackedScene
	if packed == null or navigation == null:
		push_error("No se pudo cargar el laberinto de la iglesia")
		return false
	var catacombs := packed.instantiate()
	catacombs.name = &"ChurchCatacombs"
	add_child(catacombs)
	# La region conserva su ruta ../House/ChurchCatacombs y su transformacion.
	if get_parent().get_node_or_null("RuntimeCatacombNavigation") == null:
		get_parent().add_child(navigation.instantiate())
	return true


func _apply_to_wall_meshes(branch: Node, overlay: ShaderMaterial) -> int:
	if _skips_wall_band(branch):
		return 0

	var applied := 0
	for child: Node in branch.get_children():
		# A tagged branch is intentionally opaque: do not change it or inspect
		# any descendants that may use their own materials.
		if _skips_wall_band(child):
			continue
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			if _is_wall_surface(mesh_instance):
				mesh_instance.material_overlay = null
				mesh_instance.material_override = overlay
				applied += 1
		applied += _apply_to_wall_meshes(child, overlay)
	return applied


func _skips_wall_band(branch: Node) -> bool:
	return (
		branch.is_in_group(SKIP_WALL_BAND_GROUP)
		or bool(branch.get_meta(SKIP_WALL_BAND_GROUP, false))
	)


func _is_wall_surface(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.mesh != null:
		for surface_index in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface_index)
			if material is ShaderMaterial:
				var shader := (material as ShaderMaterial).shader
				if shader != null and shader.resource_path.ends_with("shaders/pastel_wall_band.gdshader"):
					return true
	# Respaldo para paredes con material sobrescrito por el editor.
	var parent_node := mesh_instance.get_parent()
	if mesh_instance.name != &"Mesh" or parent_node == null:
		return false
	var parent_name := String(parent_node.name).to_lower()
	return "wall" in parent_name or "partition" in parent_name or "lintel" in parent_name
