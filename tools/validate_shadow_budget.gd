extends SceneTree

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	var camera := Camera3D.new()
	level.add_child(camera)
	camera.make_current()
	var lights: Array[OmniLight3D] = []
	for index in 5:
		var lamp := OmniLight3D.new()
		lamp.shadow_enabled = true
		lamp.omni_range = 10.0
		level.add_child(lamp)
		lamp.position.x = float(index + 1)
		lights.append(lamp)
	var hidden_parent := Node3D.new()
	level.add_child(hidden_parent)
	lights[0].reparent(hidden_parent)
	hidden_parent.hide()
	lights[1].light_energy = 0.0
	load("res://systems/runtime_render_optimizer.gd").install(level)
	var optimizer := level.get_node("RuntimeRenderOptimizer")
	for iteration in 3:
		optimizer.call(&"_update_shadow_budget")
		for index in 5:
			if lights[index].shadow_enabled != (index >= 2):
				push_error("Hidden/unpowered lights consumed the shadow budget")
				quit(1)
				return
	lights[2].queue_free()
	await process_frame
	optimizer.call(&"_update_shadow_budget")
	print("SHADOW BUDGET PASSED: hidden ancestors, zero energy, repeated updates, freed light")
	level.queue_free()
	await process_frame
	quit(0)
