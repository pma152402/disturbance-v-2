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
	for index in 16:
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
	for index in 16:
		var expected := index >= 2 and index < 14
		if lights[index].shadow_enabled != expected:
			push_error("Initial shadow selection ignored visibility, energy or the expanded budget")
			quit(1)
			return

	# Moving the camera changes the selected set. Old shadows must fade out while
	# new ones fade in instead of switching on the same frame.
	camera.position.x = 16.0
	optimizer.call(&"_update_shadow_budget")
	optimizer.call(&"_process", 0.1)
	if not lights[2].shadow_enabled or lights[2].shadow_opacity <= 0.0 or lights[2].shadow_opacity >= 1.0:
		push_error("Outgoing shadows did not fade progressively")
		quit(1)
		return
	if not lights[14].shadow_enabled or lights[14].shadow_opacity <= 0.0 or lights[14].shadow_opacity >= 1.0:
		push_error("Incoming shadows did not fade progressively")
		quit(1)
		return
	optimizer.call(&"_process", 1.0)
	if lights[2].shadow_enabled or lights[2].shadow_opacity != 0.0:
		push_error("Outgoing shadow stayed allocated after its fade")
		quit(1)
		return
	if not lights[14].shadow_enabled or lights[14].shadow_opacity < 0.99:
		push_error("Incoming shadow did not finish its fade")
		quit(1)
		return

	# At 28 m the shadow is inside the 24-32 m transition instead of popping at
	# the former hard 11 m cutoff.
	camera.position.x = -14.0
	optimizer.call(&"_update_shadow_budget")
	optimizer.call(&"_process", 1.0)
	if lights[13].shadow_opacity <= 0.0 or lights[13].shadow_opacity >= 1.0:
		push_error("Long-distance shadow fade is not active")
		quit(1)
		return

	print("SHADOW BUDGET PASSED: 12 lights, 24-32 m reach, hysteresis and smooth cross-fades")
	level.queue_free()
	await process_frame
	quit(0)
