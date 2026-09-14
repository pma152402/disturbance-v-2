extends SceneTree

## Partida libre de comparación. F7 alterna el sistema de producción y su
## referencia restaurada. No modifica escenas, recursos, luces ni calidad.
var _controller: ComparisonController


class ComparisonController extends Node:
	var pipeline: Node
	var enabled := true
	var report: Dictionary = {}

	func toggle() -> void:
		if enabled:
			pipeline.disable()
			enabled = false
			print("SHADOW_PREVIEW: referencia restaurada. F7 = activar sistema.")
			return
		report = pipeline.enable()
		enabled = true
		print("SHADOW_PREVIEW: sistema activo. F7 = referencia.")

	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F7:
			toggle()
			get_viewport().set_input_as_handled()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	change_scene_to_file("res://levels/test.tscn")
	await scene_changed
	while current_scene.get_node_or_null("StartupWarmup") != null:
		await process_frame
	for frame in 60:
		await physics_frame
	_controller = ComparisonController.new()
	_controller.name = "ShadowPipelineComparison"
	_controller.pipeline = current_scene.get_node("RuntimeShadowPipeline")
	_controller.report = _controller.pipeline.inventory()
	current_scene.add_child(_controller)
	if "--smoke" in OS.get_cmdline_user_args():
		assert(_controller.report.shadow_scopes[0].stats.sources > 0)
		assert(_controller.report.occlusion.occluders > 0)
		_controller.toggle()
		await create_timer(0.5).timeout
		assert(not root.use_occlusion_culling)
		_controller.toggle()
		await create_timer(0.5).timeout
		assert(root.use_occlusion_culling)
		print("SHADOW_PREVIEW_SMOKE_OK: partida activa, activacion y restauracion completas.")
		quit()
