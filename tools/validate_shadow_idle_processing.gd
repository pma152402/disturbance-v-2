extends SceneTree

## Comparacion con el controlador anterior, congelado en fixtures. Headless
## valida estados e interpolaciones, sin atribuirles una mejora de FPS/GPU.
const Optimizer := preload("res://systems/runtime_render_optimizer.gd")
const Reference := preload("res://tools/fixtures/runtime_render_optimizer_reference.gd")

var _comparisons := 0
var _failed := false


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	for fps in [30, 60, 120]:
		_run_pair(camera, fps)
		if _failed:
			quit(1)
			return
	# La instalacion previa a una camara mantiene el desvanecimiento original.
	camera.free()
	var unobserved := _make_lights()
	Optimizer.install(unobserved, false)
	var pending := unobserved.get_node("RuntimeRenderOptimizer")
	_check(pending.is_processing(), "Sin camara debe conservarse el fade inicial")
	pending.call(&"_process", 1.0)
	_check(not pending.is_processing(), "El fade inicial debe terminar sin camara")
	unobserved.free()
	print("OK: sombras equivalentes en ", _comparisons, " comprobaciones a 30/60/120 FPS; seleccion, opacidad, ocultacion, apagado, eliminacion y reposo sin _process conservados.")
	quit(1 if _failed else 0)


func _run_pair(camera: Camera3D, fps: int) -> void:
	camera.position = Vector3.ZERO
	var before := _make_lights()
	var after := _make_lights()
	Reference.install(before, false)
	Optimizer.install(after, false)
	var reference := before.get_node("RuntimeRenderOptimizer")
	var optimized := after.get_node("RuntimeRenderOptimizer")
	(reference.get_node("ShadowBudgetTimer") as Timer).stop()
	(optimized.get_node("ShadowBudgetTimer") as Timer).stop()
	_check(not optimized.is_processing(), "La seleccion inicial estable no debe procesar")
	var elapsed := 0.0
	var delta := 1.0 / float(fps)
	for frame in fps * 6:
		var phase := float(frame) * delta
		camera.position = Vector3(sin(phase * 1.7) * 24.0, 0.0, cos(phase * 0.9) * 4.0)
		if frame == fps:
			before.get_node("Lamp04").hide()
			after.get_node("Lamp04").hide()
		if frame == fps * 2:
			before.get_node("Lamp07/Light").light_energy = 0.0
			after.get_node("Lamp07/Light").light_energy = 0.0
		if frame == fps * 3:
			before.get_node("Lamp04").show()
			after.get_node("Lamp04").show()
		if frame == fps * 4:
			before.get_node("Lamp11").free()
			after.get_node("Lamp11").free()
		elapsed += delta
		if elapsed >= Optimizer.UPDATE_INTERVAL:
			elapsed = 0.0
			reference.call(&"_update_shadow_budget")
			optimized.call(&"_update_shadow_budget")
		reference.call(&"_process", delta)
		if optimized.is_processing():
			optimized.call(&"_process", delta)
		_compare(before, after, fps, frame)
		if _failed:
			break
	# Objetivos fraccionarios estables: el float32 del motor no debe provocar
	# reactivaciones perpetuas al repetir el mismo presupuesto.
	camera.position = Vector3(-21.357, 0.0, 2.315)
	reference.call(&"_update_shadow_budget")
	optimized.call(&"_update_shadow_budget")
	for frame in fps * 2:
		reference.call(&"_process", delta)
		if optimized.is_processing():
			optimized.call(&"_process", delta)
		_compare(before, after, fps, frame)
	_check(not optimized.is_processing(), "Las luces estables deben dormir")
	for tick in 20:
		reference.call(&"_update_shadow_budget")
		optimized.call(&"_update_shadow_budget")
		_check(not optimized.is_processing(), "El mismo presupuesto no debe despertar luces asentadas")
		_compare(before, after, fps, tick)
	before.free()
	after.free()


func _make_lights() -> Node3D:
	var branch := Node3D.new()
	root.add_child(branch)
	for index in 40:
		var lamp := Node3D.new()
		lamp.name = "Lamp%02d" % index
		branch.add_child(lamp)
		lamp.position = Vector3(float(index) * 1.7 - 22.0, 0.0, float(index % 5) * 2.1)
		var light: Light3D
		if index % 3 == 0:
			var spot := SpotLight3D.new()
			spot.spot_range = 10.0 + float(index % 5)
			light = spot
		else:
			var omni := OmniLight3D.new()
			omni.omni_range = 8.0 + float(index % 4)
			light = omni
		light.name = "Light"
		light.shadow_enabled = index % 9 != 0
		light.shadow_opacity = 0.45 + float(index % 6) * 0.1
		lamp.add_child(light)
	return branch


func _compare(before: Node3D, after: Node3D, fps: int, frame: int) -> void:
	for node in before.find_children("Light", "Light3D", true, false):
		var original := node as Light3D
		var optimized := after.get_node(before.get_path_to(original)) as Light3D
		_check(original.shadow_enabled == optimized.shadow_enabled and original.shadow_opacity == optimized.shadow_opacity,
			"Diferencia a %d FPS, frame %d, %s: %s/%s -> %s/%s" % [fps, frame, before.get_path_to(original), original.shadow_enabled, original.shadow_opacity, optimized.shadow_enabled, optimized.shadow_opacity])


func _check(condition: bool, message: String) -> void:
	_comparisons += 1
	if not condition and not _failed:
		_failed = true
		push_error(message)
