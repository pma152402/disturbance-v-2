extends SceneTree

const MAIN_SCENE := preload("res://levels/test.tscn")


func _initialize() -> void:
	call_deferred(&"_validate")


func _validate() -> void:
	var world := MAIN_SCENE.instantiate()
	root.add_child(world)
	current_scene = world
	for _frame in 8:
		await process_frame
	var observer := get_first_node_in_group(&"camera_observer")
	if observer == null:
		push_error("No se encontro CameraObserver")
		quit(1)
		return
	if observer.is_processing():
		push_error("El observador sigue procesando la camara real al arrancar")
		quit(1)
		return
	if observer.visible:
		push_error("El observador se sigue renderizando fuera de ARCHIVO")
		quit(1)
		return
	var camera := root.get_viewport().get_camera_3d()
	var camera_state := {
		"transform": camera.global_transform,
		"fov": camera.fov,
		"projection": int(camera.projection),
		"size": camera.size,
		"near": camera.near,
		"far": camera.far,
		"cull_mask": camera.cull_mask,
	}
	observer.call(&"set_playback_analysis_active", true)
	if not observer.visible or not observer.get_node("Header").visible or not observer.get_node("Readout").visible:
		push_error("El observador no aparece al entrar en ARCHIVO")
		quit(1)
		return
	if observer.modulate.a < 0.9:
		push_error("El observador de ARCHIVO sigue siendo casi transparente")
		quit(1)
		return
	# Los flags de debug pertenecen solo a la copia en directo: no pueden ocultar
	# el panel principal mientras estamos revisando ARCHIVO.
	observer.set("debug_overlay_enabled", false)
	observer.call(&"set_playback_analysis_active", true)
	if not observer.visible or not observer.get_node("Header").visible:
		push_error("El debug de directo apaga por error el observador de ARCHIVO")
		quit(1)
		return
	observer.set("debug_overlay_enabled", true)
	var header := observer.get_node("Header") as Control
	var readout := observer.get_node("Readout") as Control
	if header.anchor_top != 1.0 or readout.anchor_top != 1.0 \
			or header.offset_left != 52.0 or readout.offset_bottom != -32.0:
		push_error("El observador de ARCHIVO no esta anclado abajo a la izquierda")
		quit(1)
		return
	var catalog := observer.call(&"get_catalog_counts") as Dictionary
	if int(catalog.get("automatic", 0)) < 80:
		push_error("El catalogo automatico es demasiado pequeno: %s" % catalog)
		quit(1)
		return
	var observations: Variant = observer.call(&"analyze_recorded_frame", camera_state)
	if not observations is Array:
		push_error("El analisis diferido no devolvio observaciones validas")
		quit(1)
		return
	observer.call(&"set_playback_analysis_active", false)
	if observer.is_processing() or observer.visible or not observer.call(&"get_current_observations").is_empty():
		push_error("CameraObserver no se durmio al salir de ARCHIVO")
		quit(1)
		return
	print("OK: observador apagado en directo y visible abajo a la izquierda solo en ARCHIVO; catalogo %s" % catalog)
	current_scene = null
	world.queue_free()
	await process_frame
	quit(0)
