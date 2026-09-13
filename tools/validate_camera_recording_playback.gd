extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := (load("res://levels/test.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	for _frame in 3:
		await process_frame
	var recorder := game.get_node_or_null("PS2PostProcess/CameraHUD")
	if recorder == null:
		_fail("No existe el grabador de la cámara")
		return
	if game.get_node_or_null("PS2Distortion") != null:
		_fail("La distorsión continúa ejecutándose como segunda pasada de pantalla")
		return
	var postprocess := game.get_node("PS2PostProcess")
	var screen_filter := postprocess.get_node("ScreenFilter") as ColorRect
	var combined_material := screen_filter.material as ShaderMaterial
	if combined_material == null or combined_material.shader == null \
			or not combined_material.shader.resource_path.ends_with("ps2_camera_combined.gdshader"):
		_fail("El filtro principal no utiliza el shader PS2 fusionado")
		return
	if not is_equal_approx(float(combined_material.get_shader_parameter("vignette_strength")), 0.94) \
			or not is_equal_approx(float(combined_material.get_shader_parameter("vignette_inner")), 0.07) \
			or not is_equal_approx(float(combined_material.get_shader_parameter("vignette_outer")), 0.47):
		_fail("La cámara no conserva la oscuridad y viñeta VHS originales")
		return
	var combined_source := FileAccess.get_file_as_string("res://shaders/ps2_camera_combined.gdshader")
	if "outside_lens" in combined_source:
		_fail("El shader vuelve a pintar marcos negros fuera de la lente")
		return
	if "cool_highlight" in combined_source or "blood_highlight" in combined_source:
		_fail("El postfiltro general vuelve a confundir la iglesia con sangre o grietas")
		return
	if postprocess.find_children("*", "BackBufferCopy", true, false).size() != 0 \
			or screen_filter.get_index() >= recorder.get_index():
		_fail("El filtro único conserva un BackBufferCopy manual o tapa el HUD nítido")
		return
	if not is_equal_approx(float(ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0)), 0.75):
		_fail("La escena 3D no está configurada al 75 por ciento")
		return
	var recording_label := recorder.get_node("Recording") as Label
	var recording_dot := recorder.get_node("RecordingDot") as Polygon2D
	if not recording_label.visible or recording_label.modulate.a > 0.23 \
			or not recording_dot.visible or recording_dot.modulate.a > 0.23:
		_fail("REC no permanece visible y apagado durante STBY")
		return
	if recording_label.text != "REC" or recording_label.vertical_alignment != VERTICAL_ALIGNMENT_CENTER \
			or not is_equal_approx(recording_dot.position.y, (recording_label.offset_top + recording_label.offset_bottom) * 0.5):
		_fail("La bola de REC no está centrada verticalmente con el texto")
		return
	if recording_dot.scale != Vector2(1.15, 1.15):
		_fail("La bola de REC no es exactamente un 15 por ciento más grande")
		return
	if recorder.get_node("TapeMode").text != "VID 01" \
			or recorder.get_node("TapeSide").text != "A":
		_fail("El HUD de cámara no muestra el vídeo y la cara A inicial")
		return
	var battery := recorder.get_node("Battery") as Label
	if battery.get_script() == null or battery.text != "BAT" or battery.vertical_alignment != VERTICAL_ALIGNMENT_CENTER:
		_fail("BAT no está visible o alineado con el contador FPS")
		return
	if battery.offset_top >= (recorder.get_node("FPS") as Control).offset_top:
		_fail("El conjunto BAT no quedó elevado respecto a FPS")
		return
	var zoom_meter := game.get_node("Player/ZoomUI/ZoomMeter") as Control
	var zoom_minus := zoom_meter.get_node("Minus") as Label
	var zoom_plus := zoom_meter.get_node("Plus") as Label
	var zoom_segment := zoom_meter.get_node("ZoomSegments/Segment01") as ColorRect
	var segment_center := (zoom_segment.offset_top + zoom_segment.offset_bottom) * 0.5
	if zoom_minus.vertical_alignment != VERTICAL_ALIGNMENT_CENTER \
			or zoom_plus.vertical_alignment != VERTICAL_ALIGNMENT_CENTER \
			or zoom_minus.get_theme_font(&"font") != zoom_plus.get_theme_font(&"font") \
			or zoom_minus.get_theme_font_size(&"font_size") != 22 \
			or zoom_plus.get_theme_font_size(&"font_size") != 22 \
			or not is_equal_approx((zoom_minus.offset_top + zoom_minus.offset_bottom) * 0.5, segment_center) \
			or not is_equal_approx((zoom_plus.offset_top + zoom_plus.offset_bottom) * 0.5, segment_center):
		_fail("Los signos -/+ no comparten centro vertical con el zoom")
		return
	var camera_frame := recorder.get("_camera_corner_frame") as Control
	var menu_frame := recorder.get("_menu_outline_frame") as Control
	var inner_brackets := recorder.get("_menu_inner_brackets") as Control
	if not camera_frame.visible or menu_frame.visible or inner_brackets.visible:
		_fail("El directo no usa exclusivamente el encuadre de esquinas")
		return
	var stance_indicator := game.get_node("Player/StanceUI/StanceIndicator") as Control
	if stance_indicator.position != Vector2(329.0, 76.0) or stance_indicator.size != Vector2(74.0, 80.0):
		_fail("El monigote no conservó su posición relativa dentro del HUD desplazado")
		return
	var tape_mode_geometry := recorder.get_node("TapeMode") as Control
	var tape_side_geometry := recorder.get_node("TapeSide") as Control
	var fps_geometry := recorder.get_node("FPS") as Control
	var timestamp_geometry := recorder.get_node("Timestamp") as Control
	if recording_label.offset_top != 50.0 or recording_dot.position.y != 82.0 \
			or tape_mode_geometry.offset_top != 115.0 or tape_side_geometry.offset_top != 117.0:
		_fail("La sección superior izquierda no está desplazada 10 px")
		return
	if battery.offset_top != 60.0 or battery.offset_left != -307.0 \
			or fps_geometry.offset_top != 72.0 or fps_geometry.offset_left != -632.0:
		_fail("La sección superior derecha no está 30 px abajo y 10 px a la derecha")
		return
	if timestamp_geometry.offset_top != -104.0 or zoom_meter.offset_top != -154.0:
		_fail("La sección inferior derecha no está desplazada 20 px hacia abajo")
		return
	if (recorder.get_node("Recording") as Control).offset_left < 70.0 \
			or (recorder.get_node("Battery") as Control).offset_right > -60.0 \
			or (zoom_meter as Control).offset_right > -70.0:
		_fail("El HUD del directo invade la zona segura de las esquinas")
		return
	# GPU startup briefly warms the capture pipeline without recording. Wait for
	# that asynchronous job before asserting the steady-state STBY resources.
	var warmup_deadline := Time.get_ticks_msec() + 5000
	while bool(recorder.get("_capture_pending")) and Time.get_ticks_msec() < warmup_deadline:
		await process_frame
	var low_res_viewport := recorder.get("_recording_viewport") as SubViewport
	if low_res_viewport != null or recorder.get("_recording_camera") != null:
		_fail("La segunda cámara existe antes de comenzar a grabar")
		return
	recorder.call(&"start_recording")
	low_res_viewport = recorder.get("_recording_viewport") as SubViewport
	if low_res_viewport == null or low_res_viewport.size != Vector2i(426, 240):
		_fail("La grabación no crea su viewport pequeño bajo demanda")
		return
	var candle_preview := game.get_node("Player/CandlePlacementPreview") as VisualInstance3D
	var tape_camera := recorder.get("_recording_camera") as Camera3D
	if not candle_preview.get_layer_mask_value(19) or tape_camera.get_cull_mask_value(19):
		_fail("La guía verde de la vela sigue incluida en las grabaciones")
		return
	var recording_blink_timer := recorder.get("_recording_blink_timer") as Timer
	if recording_blink_timer == null or not recording_blink_timer.one_shot \
			or recording_blink_timer.time_left < 1.9:
		_fail("REC no comienza encendido con una fase completa de dos segundos")
		return
	recorder.call(&"_toggle_recording")
	if not recording_label.visible or recording_label.modulate.a > 0.3 \
			or not recording_dot.visible or recording_dot.modulate.a < 0.99 \
			or not is_equal_approx(recording_blink_timer.wait_time, 1.0):
		_fail("La bola no permanece encendida mientras parpadea el texto REC")
		return
	recorder.call(&"_toggle_recording")
	if recording_label.modulate.a < 0.99 or recording_dot.modulate.a < 0.99 \
			or not is_equal_approx(recording_blink_timer.wait_time, 2.0):
		_fail("REC no recupera su fase encendida con la bola fija")
		return
	if int(recorder.call(&"_maximum_frames_per_clip")) != 60:
		_fail("La cinta no admite los 30 segundos configurados")
		return
	recorder.call(&"_process", 1.05)
	if recorder.get_node("TapeSide").text != "A":
		_fail("La cara de la cinta cambia durante una grabación")
		return
	for _frame in 3:
		await process_frame
	# La copia TapeCamera debe conservar el encuadre y la política de la cámara
	# de origen; su propio nombre nunca identifica el modo selfie/externo.
	var external_camera := Camera3D.new()
	external_camera.name = "FilmingCamera"
	external_camera.keep_aspect = Camera3D.KEEP_WIDTH
	external_camera.h_offset = 0.12
	external_camera.v_offset = -0.08
	external_camera.frustum_offset = Vector2(0.05, -0.03)
	game.add_child(external_camera)
	recorder.call(&"_sync_recording_camera", external_camera)
	var external_state: Dictionary = recorder.call(&"_recording_camera_state")
	if bool(external_state.exclude_player) or int(external_state.keep_aspect) != Camera3D.KEEP_WIDTH \
			or not is_equal_approx(float(external_state.h_offset), 0.12) \
			or not is_equal_approx(float(external_state.v_offset), -0.08) \
			or external_state.frustum_offset != Vector2(0.05, -0.03):
		_fail("La cinta perdió el encuadre o la oclusión del jugador de la cámara externa")
		return
	external_camera.queue_free()
	recorder.call(&"_sync_recording_camera", root.get_camera_3d())
	# Capturas JPEG sintéticas para comprobar el archivo comprimido sin GPU.
	var test_image := Image.create(426, 240, false, Image.FORMAT_RGB8)
	test_image.fill(Color(0.18, 0.28, 0.22))
	var test_frame := test_image.save_jpg_to_buffer(0.62)
	var current_clip: Array = recorder.get("_current_clip")
	current_clip.append(test_frame)
	current_clip.append(test_frame)
	var current_camera_frames: Array = recorder.get("_current_clip_camera_frames")
	current_camera_frames.append(recorder.call(&"_recording_camera_state"))
	current_camera_frames.append(recorder.call(&"_recording_camera_state"))
	recorder.call(&"stop_recording")
	# STOP invalidates in-flight captures, then releases their viewport on completion.
	var stop_deadline := Time.get_ticks_msec() + 5000
	while bool(recorder.get("_capture_pending")) and Time.get_ticks_msec() < stop_deadline:
		await process_frame
	if recorder.get("_recording_viewport") != null or recorder.get("_recording_camera") != null:
		_fail("La segunda cámara no se destruyó al detener la grabación")
		return
	if recorder.get_node("TapeMode").text != "VID 02":
		_fail("Guardar un vídeo no avanzó su identificador")
		return
	recorder.set("_recording_sequence", 99)
	recorder.call(&"_update_recording_identifiers")
	if recorder.get_node("TapeMode").text != "VID 04" \
			or recorder.get_node("TapeSide").text != "B":
		_fail("El identificador de vídeo o la cara B final son incorrectos")
		return
	recorder.set("_recording_sequence", 2)
	recorder.call(&"_update_recording_identifiers")
	if recorder.get_node("TapeSide").text != "A":
		_fail("El segundo vídeo no permanece en la cara A")
		return
	var clips: Array = recorder.get("_saved_clips")
	if clips.size() != 1 or (clips[0] as Array).is_empty():
		_fail("La cámara no conservó fotogramas reales")
		return
	if (clips[0] as Array)[0] is Texture2D:
		_fail("El archivo continúa acumulando texturas en la GPU")
		return
	recorder.call(&"toggle_playback")
	if not paused or not bool(recorder.get("_playback_open")):
		_fail("La transición a ARCHIVO no pausó el mundo")
		return
	if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
		_fail("El cursor sigue visible al entrar en ARCHIVO")
		return
	if not bool(recorder.get("_mode_transitioning")) or not (recorder.get("_tape_spinner") as Control).visible:
		_fail("TAB no inició el loader de CÁMARA a ARCHIVO")
		return
	if (recorder.get_node("Recording") as CanvasItem).visible or (recorder.get_node("FPS") as CanvasItem).visible:
		_fail("REC o FPS siguen visibles en la vista ARCHIVO")
		return
	if (recorder.get_node("Timestamp") as CanvasItem).visible:
		_fail("La fecha/hora sigue visible durante el acceso a ARCHIVO")
		return
	recorder.call(&"_process", 1.2)
	if bool(recorder.get("_mode_transitioning")):
		_fail("El loader de entrada no terminó")
		return
	if camera_frame.visible or not menu_frame.visible or not inner_brackets.visible:
		_fail("ARCHIVO no combina el encuadre completo con los corchetes interiores")
		return
	var observer := game.get_node("PS2PostProcess/CameraObserver") as Control
	var observer_header := observer.get_node("Header") as Label
	var observer_readout := observer.get_node("Readout") as RichTextLabel
	if not observer.visible or not bool(observer.get("_playback_analysis_active")):
		_fail("El Observador no se activa al analizar una grabación de ARCHIVO")
		return
	if observer_header.get_theme_font(&"font") != observer_readout.get_theme_font(&"normal_font") \
			or not observer_header.get_theme_font(&"font").resource_path.ends_with("PressStart2P-Regular.ttf"):
		_fail("Todo el Observador no utiliza la tipografía pixelada")
		return
	var observation_summaries: Array = recorder.get("_saved_clip_observations")
	if observation_summaries.is_empty() or int((observation_summaries[0] as Dictionary).get("analyzed_frame", -1)) != 0:
		_fail("El Observador de ARCHIVO no analizó el fotograma grabado")
		return
	var playback_tabs_for_bracket := recorder.get("_playback_tabs") as Control
	var expected_bracket_top := playback_tabs_for_bracket.offset_top + (recorder.get("_camera_tab_label") as Label).size.y * 0.5
	var progress_for_bracket := recorder.get("_playback_progress_track") as Control
	var expected_bracket_bottom := (progress_for_bracket.offset_top + progress_for_bracket.offset_bottom) * 0.5
	if inner_brackets.offset_left != -inner_brackets.offset_right \
			or not is_equal_approx(inner_brackets.offset_top, expected_bracket_top) \
			or not is_equal_approx(inner_brackets.offset_bottom, expected_bracket_bottom):
		_fail("Los corchetes interiores no conectan pestañas y barra de duración")
		return
	if float(inner_brackets.get("line_width")) != float(camera_frame.get("line_width")):
		_fail("Los corchetes interiores no tienen el grosor de las esquinas")
		return
	recorder.call(&"_toggle_recording")
	if (recorder.get_node("Recording") as CanvasItem).visible:
		_fail("El parpadeo volvió a mostrar REC dentro de ARCHIVO")
		return
	for hidden_path in [
		"Player/StanceUI/StanceIndicator",
		"Player/ZoomUI/ZoomMeter",
		"Player/InventoryUI/InventorySlots",
		"Player/InteractionUI/NoteControlsPrompt",
	]:
		if (game.get_node(hidden_path) as CanvasItem).visible:
			_fail("PLAYBACK dejó visible una ayuda del directo: %s" % hidden_path)
			return
	if recorder.get("_playback_image").texture == null:
		_fail("PLAYBACK no mostró el fotograma grabado")
		return
	var side_menu := recorder.get("_playback_menu_left") as RichTextLabel
	var side_controls := recorder.get("_playback_controls_right") as RichTextLabel
	var parsed_menu := side_menu.get_parsed_text()
	if not side_menu.visible or "CINTA A 01 ◀" not in parsed_menu:
		_fail("El menú lateral no señala la cinta seleccionada")
		return
	if "CINTA A 02" not in parsed_menu or "CINTA B 03" not in parsed_menu or "CINTA B 04" not in parsed_menu:
		_fail("El archivo no muestra siempre sus cuatro ranuras")
		return
	if "DIRECTO" in parsed_menu:
		_fail("El archivo todavía muestra la entrada DIRECTO")
		return
	if not side_controls.visible or "TAB / ESC" not in side_controls.text or "CAMARA" not in side_controls.text:
		_fail("Faltan los controles grandes del lateral derecho")
		return
	if "ESPACIO" not in side_controls.text:
		_fail("El menú no explica el control de reproducción")
		return
	var playback_info := recorder.get("_playback_info") as Label
	var previous_button := recorder.get("_playback_previous_button") as Label
	var toggle_button := recorder.get("_playback_toggle_button") as Control
	var next_button := recorder.get("_playback_next_button") as Label
	if "CINTA" in playback_info.text or "PLAY" in playback_info.text or "PAUSA" in playback_info.text:
		_fail("Los botones inferiores todavía contienen etiquetas de texto")
		return
	if previous_button.text != "◀" or next_button.text != "▶":
		_fail("Faltan los botones de avance y retroceso sobre el loader")
		return
	var pause_bars: Array = recorder.get("_playback_pause_bars")
	if toggle_button.offset_top != previous_button.offset_top or pause_bars.size() != 2:
		_fail("La pausa no está cuadrada con las flechas")
		return
	if (pause_bars[0] as ColorRect).position.y != (pause_bars[1] as ColorRect).position.y \
			or (pause_bars[0] as ColorRect).size != (pause_bars[1] as ColorRect).size:
		_fail("Las dos barras de pausa no están alineadas entre sí")
		return
	var play_icon := recorder.get("_playback_play_icon") as Polygon2D
	if not play_icon.visible or (pause_bars[0] as ColorRect).visible:
		_fail("El transporte pausado no muestra el botón PLAY")
		return
	if "W / S" not in side_controls.text or "Q / E" not in side_controls.text or "CAMBIAR MENU" not in side_controls.text:
		_fail("El menú no separa W/S para cintas y Q/E para pestañas")
		return
	if side_menu.vertical_alignment != VERTICAL_ALIGNMENT_CENTER:
		_fail("El archivo perdió su centrado vertical original")
		return
	if side_menu.get_theme_font(&"normal_font") != side_controls.get_theme_font(&"normal_font") \
			or side_menu.get_theme_font_size(&"normal_font_size") != side_controls.get_theme_font_size(&"normal_font_size"):
		_fail("El archivo no comparte tipografía y tamaño con los controles")
		return
	var tabs := recorder.get("_playback_tabs") as Control
	if not tabs.visible or tabs.get_child_count() < 3:
		_fail("Faltan las pestañas decorativas CÁMARA / ARCHIVO")
		return
	var camera_tab_geometry := recorder.get("_camera_tab_label") as Label
	if tabs.offset_left != -tabs.offset_right or camera_tab_geometry.size.y <= 0.0:
		_fail("Las pestañas no están centradas horizontalmente")
		return
	if (recorder.get("_camera_tab_label") as Label).text != "CAMARA":
		_fail("La pestaña CAMARA todavía conserva el acento")
		return
	recorder.call(&"_toggle_playback_running")
	if play_icon.visible or not (pause_bars[0] as ColorRect).visible:
		_fail("El transporte en marcha no muestra el botón PAUSA")
		return
	recorder.call(&"_process", 0.31)
	if int(recorder.get("_selected_frame")) != 1:
		_fail("PLAY no avanzó tras 0,3 segundos")
		return
	var progress_track := recorder.get("_playback_progress_track") as Control
	var progress_segments: Array = recorder.get("_playback_progress_segments")
	if not progress_track.visible or progress_segments.size() != 24 \
			or (progress_segments[23] as ColorRect).color.r < 0.7:
		_fail("El loader no avanzó hasta el final de la cinta")
		return
	recorder.call(&"_process", 0.31)
	if int(recorder.get("_selected_frame")) != 0:
		_fail("La reproducción no volvió al inicio en bucle")
		return
	clips.append((clips[0] as Array).duplicate())
	recorder.call(&"_step_clip", 1)
	var load_time := float(recorder.get("_tape_load_timer"))
	var spinner := recorder.get("_tape_spinner") as Control
	if not bool(recorder.get("_tape_loading")) or load_time < 1.5 or load_time > 3.5 or not spinner.visible:
		_fail("Cambiar de cinta no inició el loader aleatorio")
		return
	recorder.call(&"_process", 3.6)
	if bool(recorder.get("_tape_loading")) or int(recorder.get("_selected_clip")) != 1 or spinner.visible:
		_fail("El loader no terminó cargando la cinta seleccionada")
		return
	recorder.call(&"_set_delete_confirmation", true)
	var confirmation := recorder.get("_delete_confirmation") as Label
	var confirmation_backdrop := recorder.get("_delete_confirmation_backdrop") as ColorRect
	if not bool(recorder.get("_delete_armed")) or not confirmation.visible \
			or "▶  ELIMINAR" not in confirmation.text or "ESPACIO  ACEPTAR" not in confirmation.text:
		_fail("X no solicita confirmación antes de eliminar")
		return
	if not confirmation_backdrop.visible or confirmation_backdrop.color.a < 0.5:
		_fail("La confirmación no oscurece el cuadro de vídeo")
		return
	recorder.call(&"_delete_selected_clip")
	if clips.size() != 1 or bool(recorder.get("_delete_armed")) or confirmation.visible:
		_fail("La confirmación no eliminó exactamente una cinta")
		return
	recorder.call(&"_set_delete_confirmation", true)
	recorder.call(&"_delete_selected_clip")
	var empty_background := recorder.get("_playback_empty_background") as ColorRect
	var empty_cassette := empty_background.get_node_or_null("EmptyArchiveCassette") as Control
	var volume_indicator := recorder.get("_playback_volume_indicator") as Control
	if not clips.is_empty() or not empty_background.visible or empty_background.color.r >= 0.1:
		_fail("El hueco de vídeo vacío no se integra con el fondo oscuro")
		return
	if empty_cassette == null or empty_cassette.get_script() == null \
			or empty_cassette.size.x < 900.0 or empty_cassette.size.y < 500.0:
		_fail("El archivo vacío no muestra el cassette grande con símbolo de prohibido")
		return
	var empty_cassette_source := FileAccess.get_file_as_string("res://systems/camera_empty_archive_cassette.gd")
	if "PROHIBITED_RADIUS := 300.0" not in empty_cassette_source \
			or "BLACK_PLASTIC" not in empty_cassette_source or "EDGE_PLASTIC" not in empty_cassette_source \
			or "BODY_LIGHT" in empty_cassette_source or "SYMBOL :=" in empty_cassette_source:
		_fail("El cassette vacío no conserva el diseño simple y suave del casete 3D")
		return
	if not volume_indicator.visible or volume_indicator.get_child_count() != 5:
		_fail("Falta el indicador VOL decorativo de cuatro niveles")
		return
	var battery_center_x := ((recorder.get_node("Battery") as Control).offset_left + (recorder.get_node("Battery") as Control).offset_right) * 0.5
	var volume_center_x := (volume_indicator.offset_left + volume_indicator.offset_right) * 0.5
	if absf(battery_center_x - volume_center_x) > 0.5:
		_fail("VOL no está centrado horizontalmente con BAT")
		return
	for level_index in range(1, 5):
		var volume_level := volume_indicator.get_child(level_index) as Panel
		if volume_level.size != Vector2(26.0, 26.0) or volume_level.position.y != 26.0:
			_fail("Las barras de VOL no comparten tamaño y altura")
			return
	if (recorder.get_node("Timestamp") as CanvasItem).visible:
		_fail("ARCHIVO muestra fecha/hora junto al indicador VOL")
		return
	var empty_volume_level := volume_indicator.get_child(4) as Panel
	var empty_volume_style := empty_volume_level.get_theme_stylebox(&"panel") as StyleBoxFlat
	if empty_volume_style.bg_color.a != 0.0 or empty_volume_style.border_width_left <= 0:
		_fail("La última barra de VOL no está vacía y perfilada")
		return
	var playback_material := (recorder.get("_playback_image") as TextureRect).material as ShaderMaterial
	if playback_material == null or playback_material.shader == null:
		_fail("El vídeo de ARCHIVO no tiene su filtro pixelado local")
		return
	recorder.call(&"step_camera_menu", 1)
	if not bool(recorder.get("_mode_transitioning")) or not bool(recorder.get("_playback_open")):
		_fail("E no inició el paso de ARCHIVO a AV / IO")
		return
	if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
		_fail("El cursor reapareció al entrar en AV / IO")
		return
	var avio_tab := recorder.get("_avio_tab_label") as Label
	var archive_tab := recorder.get("_archive_tab_label") as Label
	if avio_tab.get_theme_color(&"font_color").r <= archive_tab.get_theme_color(&"font_color").r:
		_fail("El foco no pasó a la pestaña AV / IO antes del loader")
		return
	recorder.set("debug_external_recorder_connected", false)
	recorder.call(&"_process", 1.2)
	var avio_menu := recorder.get("_avio_menu") as RichTextLabel
	if not avio_menu.visible or "SACAR CINTA" not in avio_menu.get_parsed_text() \
			or "METER CINTA" not in avio_menu.get_parsed_text() \
			or "GRABAR CINTA" not in avio_menu.get_parsed_text() \
			or "SIN CONEXION" in avio_menu.get_parsed_text() \
			or "SIN GRABACIONES" in avio_menu.get_parsed_text():
		_fail("El menú AV / IO no expone sus operaciones y bloqueos")
		return
	var avio_explanation := recorder.get("_avio_explanation") as RichTextLabel
	var avio_controls := recorder.get("_avio_controls_right") as RichTextLabel
	if not avio_controls.visible or (recorder.get("_avio_status") as Label).visible \
			or "CAMBIAR MENU" not in avio_controls.get_parsed_text():
		_fail("AV / IO no tiene su panel derecho o conserva la barra inferior")
		return
	recorder.set("_avio_selection", 2)
	recorder.call(&"_refresh_avio_menu")
	if "GRABAR CINTA" not in avio_menu.get_parsed_text() \
			or "SIN GRABACIONES" in avio_menu.get_parsed_text() \
			or "REQUIERE DVD EXTERNO PARA GRABAR LA CINTA DEFINITIVAMENTE" not in avio_explanation.get_parsed_text() \
			or avio_explanation.vertical_alignment != VERTICAL_ALIGNMENT_CENTER:
		_fail("GRABAR CINTA no conserva su mensaje inferior centrado")
		return
	recorder.set("_avio_selection", 0)
	recorder.call(&"_refresh_avio_menu")
	if not avio_explanation.get_parsed_text().strip_edges().is_empty():
		_fail("AV / IO muestra descripciones de opciones ajenas al cursor")
		return
	var cassette_scene := load("res://house_props/cassette_tape.tscn") as PackedScene
	if cassette_scene == null:
		_fail("No se puede cargar el componente CassetteTape")
		return
	var cassette_1 := cassette_scene.instantiate()
	var cassette_2 := cassette_scene.instantiate()
	cassette_1.set("tape_number", 1)
	cassette_2.set("tape_number", 2)
	game.add_child(cassette_1)
	game.add_child(cassette_2)
	for _slot in 4:
		clips.append([test_frame])
	recorder.set("_avio_selection", 2)
	recorder.call(&"_refresh_avio_menu")
	recorder.call(&"_activate_avio_option")
	if bool(cassette_1.call(&"has_recording", "A")) \
			or bool(cassette_1.call(&"has_recording", "B")) \
			or bool(cassette_2.call(&"has_recording", "A")) \
			or bool(cassette_2.call(&"has_recording", "B")):
		_fail("GRABAR CINTA no debe transferir contenido mientras esté desactivada")
		return
	clips.clear()
	clips.append([test_frame])
	clips.append([test_frame])
	recorder.set("_avio_selection", 3)
	recorder.call(&"_refresh_avio_menu")
	if "VACIA LA CINTA POR COMPLETO" not in avio_explanation.get_parsed_text():
		_fail("REBOBINAR no advierte que vacía la cinta")
		return
	recorder.call(&"_activate_avio_option")
	if not bool(recorder.get("_avio_erase_armed")) or clips.size() != 2:
		_fail("REBOBINAR no exige confirmación antes de vaciar")
		return
	if avio_explanation.get_parsed_text().strip_edges() != "SE ELIMINARA LA GRABACION DEFINITIVAMENTE":
		_fail("La confirmación de REBOBINAR no muestra el aviso definitivo")
		return
	recorder.call(&"_activate_avio_option")
	if not clips.is_empty() or bool(recorder.get("_avio_erase_armed")):
		_fail("La segunda confirmación no vació la cinta")
		return
	if not avio_explanation.get_parsed_text().strip_edges().is_empty() \
			or "[color=#59615a]▶  REBOBINAR CINTA" not in avio_menu.text:
		_fail("REBOBINAR no queda deshabilitado y sin acción al vaciar la cinta")
		return
	recorder.set("_avio_selection", 0)
	recorder.call(&"_refresh_avio_menu")
	recorder.call(&"_activate_avio_option")
	if bool(recorder.get("_tape_inserted")):
		_fail("SACAR CINTA no cambió el estado físico")
		return
	recorder.call(&"_activate_avio_option")
	if (recorder.get("_avio_status") as Label).text != "NO HAY NINGUNA CINTA INSERTADA":
		_fail("SACAR CINTA no queda bloqueado tras extraerla")
		return
	recorder.set("_avio_selection", 1)
	recorder.call(&"_activate_avio_option")
	if bool(recorder.get("_tape_inserted")) or not bool(recorder.get("_avio_scan_armed")) \
			or "¿ESCANEAR?" not in avio_explanation.get_parsed_text():
		_fail("METER CINTA no solicita escanear la cinta nueva")
		return
	recorder.call(&"_activate_avio_option")
	if not bool(recorder.get("_tape_inserted")) or bool(recorder.get("_avio_scan_armed")):
		_fail("La confirmación del escaneo no insertó la cinta")
		return
	recorder.call(&"step_camera_menu", 1)
	if not bool(recorder.get("_mode_transitioning")):
		_fail("E no inició el paso de AV / IO a AJUSTES")
		return
	recorder.call(&"_process", 1.2)
	if int(recorder.get("_active_mode")) != 3 or not (recorder.get("_settings_menu") as RichTextLabel).visible:
		_fail("La pestaña AJUSTES no aparece detrás de AV / IO")
		return
	var settings_tab := recorder.get("_settings_tab_label") as Label
	var data_tab := recorder.get("_data_tab_label") as Label
	var camera_carousel_tab := recorder.get("_camera_tab_label") as Label
	if not settings_tab.visible or not avio_tab.visible or not (recorder.get("_archive_tab_label") as Label).visible or camera_carousel_tab.visible:
		_fail("El carrusel superior no desplaza sus tres opciones para mostrar AJUSTES")
		return
	var left_tab_arrow := recorder.get("_tabs_left_arrow") as Label
	var right_tab_arrow := recorder.get("_tabs_right_arrow") as Label
	if not left_tab_arrow.visible or not right_tab_arrow.visible or left_tab_arrow.text != "◀" or right_tab_arrow.text != "▶":
		_fail("Las tres opciones superiores no tienen flechas izquierda y derecha")
		return
	recorder.call(&"step_camera_menu", -1)
	recorder.call(&"_process", 1.2)
	if int(recorder.get("_active_mode")) != 2 or not avio_tab.visible:
		_fail("La flecha izquierda no regresa de AJUSTES a AV / IO")
		return
	recorder.call(&"step_camera_menu", 1)
	recorder.call(&"_process", 1.2)
	if int(recorder.get("_active_mode")) != 3 or not settings_tab.visible:
		_fail("La flecha derecha no vuelve a abrir AJUSTES")
		return
	clips.append([test_frame])
	recorder.set("_lifetime_recorded_seconds", 756.0)
	recorder.set("_tapes_spent", 7)
	recorder.call(&"step_camera_menu", 1)
	recorder.call(&"_process", 1.2)
	if int(recorder.get("_active_mode")) != 4 or not (recorder.get("_data_panel") as RichTextLabel).visible:
		_fail("La pestaña DATOS no aparece después de AJUSTES")
		return
	var data_text := (recorder.get("_data_panel") as RichTextLabel).text
	var required_data := [
		"MINUTOS GRABADOS", "012.6 MIN", "CINTAS GASTADAS", "007",
		"VIDEOS GUARDADOS", "01 / 04", "MEMORIA UTILIZADA",
		"CINTA", "INSERTADA", "UBICACION", "DESCONOCIDA",
	]
	for required_text in required_data:
		if required_text not in data_text:
			_fail("DATOS no muestra correctamente: %s" % required_text)
			return
	for fabricated_text in ["ULTIMA SEÑAL", "TEMPERATURA", "INTERFERENCIA", "DISPOSITIVOS DETECTADOS", "OPERADORES REGISTRADOS"]:
		if fabricated_text in data_text:
			_fail("DATOS conserva información inventada: %s" % fabricated_text)
			return
	if not left_tab_arrow.visible or right_tab_arrow.visible:
		_fail("DATOS debe mostrar solo la flecha hacia una opción existente")
		return
	recorder.call(&"step_camera_menu", 1)
	if bool(recorder.get("_mode_transitioning")) or int(recorder.get("_active_mode")) != 4:
		_fail("La navegación avanzó desde DATOS aunque no existe otra opción a la derecha")
		return
	recorder.call(&"_begin_mode_transition", 0)
	var camera_tab := recorder.get("_camera_tab_label") as Label
	if camera_tab.get_theme_color(&"font_color").r <= avio_tab.get_theme_color(&"font_color").r:
		_fail("El foco no pasó a CAMARA antes del loader final")
		return
	recorder.call(&"_process", 1.2)
	if paused or bool(recorder.get("_playback_open")) or bool(recorder.get("_mode_transitioning")):
		_fail("La cámara no regresó correctamente tras el loader")
		return
	if left_tab_arrow.visible or not right_tab_arrow.visible:
		_fail("CAMARA debe mostrar solo la flecha hacia una opción existente")
		return
	if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_fail("El cursor no volvió al modo capturado al regresar a CAMARA")
		return
	if not (recorder.get_node("Recording") as CanvasItem).visible or not (recorder.get_node("FPS") as CanvasItem).visible:
		_fail("REC o FPS no reaparecieron al volver a CAMARA")
		return
	if not (recorder.get_node("Timestamp") as CanvasItem).visible or volume_indicator.visible:
		_fail("CAMARA no restauró exclusivamente la fecha/hora")
		return
	if not (game.get_node("Player/StanceUI/StanceIndicator") as CanvasItem).visible:
		_fail("El HUD del directo no recuperó su visibilidad al cerrar PLAYBACK")
		return
	print("CAMERA RECORDING PLAYBACK PASSED")
	current_scene = null
	game.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	paused = false
	push_error(message)
	quit(1)
