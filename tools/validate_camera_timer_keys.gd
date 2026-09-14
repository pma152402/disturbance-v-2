extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := (load("res://levels/test.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	for _frame in 3:
		await process_frame

	var player := game.get_node_or_null("Player")
	var recorder := game.get_node_or_null("PS2PostProcess/CameraHUD")
	if player == null or recorder == null:
		_fail("No se pudieron cargar el jugador y el HUD de la cámara")
		return
	var timer_label := recorder.get_node_or_null("CameraTimer") as Label
	if timer_label == null:
		_fail("El HUD no crea el temporizador de cámara")
		return
	if timer_label.get_theme_font(&"font") != (recorder.get_node("Recording") as Label).get_theme_font(&"font"):
		_fail("El temporizador no comparte la tipografía pixelada de la cámara")
		return
	if timer_label.get_theme_font_size(&"font_size") < 550 or timer_label.get_theme_color(&"font_color").a > 0.15:
		_fail("El temporizador no es enorme y muy transparente")
		return
	if timer_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER \
			or timer_label.vertical_alignment != VERTICAL_ALIGNMENT_CENTER:
		_fail("El temporizador no está centrado en la cámara")
		return

	# R debe conservar su semantica directa REC/STOP, independientemente del
	# temporizador opcional de T y de los sonidos del menu.
	var r_event := InputEventKey.new()
	r_event.physical_keycode = KEY_R
	r_event.pressed = true
	player.call(&"_input", r_event)
	if not bool(recorder.get("_is_recording")) or timer_label.visible:
		_fail("R no inicia la grabacion directa")
		return
	player.call(&"_input", r_event)
	if bool(recorder.get("_is_recording")):
		_fail("R no detiene la grabacion directa")
		return

	var t_event := InputEventKey.new()
	t_event.physical_keycode = KEY_T
	t_event.pressed = true
	player.call(&"_input", t_event)
	if not timer_label.visible or timer_label.text != "5" or current_scene != game:
		_fail("T no inicia la cuenta atrás de cinco segundos")
		return
	recorder.call(&"_process", 1.01)
	if timer_label.text != "4":
		_fail("La cuenta atrás no avanza de 5 a 4")
		return
	recorder.call(&"_process", 1.0)
	if timer_label.text != "3":
		_fail("La cuenta atrás no avanza de 4 a 3")
		return
	recorder.call(&"_process", 1.0)
	if timer_label.text != "2":
		_fail("La cuenta atrás no avanza de 3 a 2")
		return
	recorder.call(&"_process", 1.0)
	if timer_label.text != "1":
		_fail("La cuenta atrás no avanza de 2 a 1")
		return
	# El temporizador se arma con la camara en mano, pero debe permitir colocarla
	# antes del disparo y comenzar a grabar desde su nueva posicion.
	player.call(&"_ensure_filming_modes")
	var modes: Node = player.get("filming_modes") as Node
	modes.set("mode", 2) # camera_modes.gd: Mode.GROUND
	if not bool(player.call(&"is_camera_on_ground")):
		_fail("La prueba no pudo simular la camara colocada durante la cuenta atras")
		return
	recorder.call(&"_process", 1.0)
	if timer_label.visible:
		_fail("El temporizador no desaparece al completar los cinco segundos")
		return
	if not bool(recorder.get("_is_recording")):
		_fail("La camara colocada no empieza a grabar automaticamente al terminar la cuenta atras")
		return
	recorder.call(&"stop_recording")

	# Una cuenta nueva no se puede armar con la camara ya colocada.
	player.call(&"_input", t_event)
	if timer_label.visible or float(recorder.get("_camera_timer_remaining")) > 0.0:
		_fail("T sigue disponible cuando la camara ya esta colocada")
		return
	recorder.call(&"start_camera_timer")
	if timer_label.visible or float(recorder.get("_camera_timer_remaining")) > 0.0:
		_fail("El HUD permite iniciar T directamente con la camara colocada")
		return

	var previous_instance_id := game.get_instance_id()
	var y_event := InputEventKey.new()
	y_event.physical_keycode = KEY_Y
	y_event.pressed = true
	player.call(&"_input", y_event)
	await process_frame
	await process_frame
	if current_scene == null or current_scene.get_instance_id() == previous_instance_id:
		_fail("Y no reinicia la escena")
		return

	game = current_scene
	recorder = game.get_node("PS2PostProcess/CameraHUD")
	timer_label = recorder.get_node("CameraTimer") as Label
	recorder.set("_playback_open", true)
	paused = true
	recorder.call(&"_input", t_event)
	if timer_label.visible or bool(recorder.get("_is_recording")):
		_fail("El temporizador intenta grabar mientras está abierto el archivo de cámara")
		return
	previous_instance_id = game.get_instance_id()
	recorder.call(&"_input", y_event)
	await process_frame
	await process_frame
	if current_scene == null or current_scene.get_instance_id() == previous_instance_id:
		_fail("Y no reinicia la escena desde el archivo de cámara")
		return

	print("OK: R controla REC/STOP, T inicia 5-4-3-2-1 y Y reinicia la escena")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
