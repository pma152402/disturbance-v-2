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
	if not recorder.get_node("Recording").visible or recorder.get_node("Recording").modulate.a > 0.23:
		_fail("REC no permanece visible y apagado durante STBY")
		return
	if recorder.get_node("TapeMode").text != "CAM 01":
		_fail("El texto superior de cámara no permanece fijo")
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
	var low_res_viewport := recorder.get("_recording_viewport") as SubViewport
	if low_res_viewport == null or low_res_viewport.size != Vector2i(426, 240):
		_fail("La grabación no usa el viewport pequeño de bajo coste")
		return
	recorder.call(&"start_recording")
	if int(recorder.call(&"_maximum_frames_per_clip")) != 60:
		_fail("La cinta no admite los 30 segundos configurados")
		return
	for _frame in 3:
		await process_frame
	# Headless usa un renderer dummy sin framebuffer. Inyectamos dos capturas JPEG
	# equivalentes para validar el archivo comprimido independientemente del GPU.
	var test_image := Image.create(426, 240, false, Image.FORMAT_RGB8)
	test_image.fill(Color(0.18, 0.28, 0.22))
	var test_frame := test_image.save_jpg_to_buffer(0.62)
	var current_clip: Array = recorder.get("_current_clip")
	current_clip.append(test_frame)
	current_clip.append(test_frame)
	recorder.call(&"stop_recording")
	if recorder.get_node("TapeMode").text != "CAM 01":
		_fail("Guardar una cinta alteró el texto fijo superior")
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
	var side_controls := recorder.get("_playback_controls_right") as Label
	var parsed_menu := side_menu.get_parsed_text()
	if not side_menu.visible or "▶ CINTA 01 A" not in parsed_menu:
		_fail("El menú lateral no señala la cinta seleccionada")
		return
	if "CINTA 02 A" not in parsed_menu or "CINTA 01 B" not in parsed_menu or "CINTA 02 B" not in parsed_menu:
		_fail("El archivo no muestra siempre sus cuatro ranuras")
		return
	if "DIRECTO" in parsed_menu:
		_fail("El archivo todavía muestra la entrada DIRECTO")
		return
	if not side_controls.visible or "VOLVER" not in side_controls.text:
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
	if "W / S" not in side_controls.text or "Q / E" in side_controls.text:
		_fail("El menú no usa W/S para cambiar de cinta")
		return
	if side_menu.vertical_alignment != VERTICAL_ALIGNMENT_CENTER:
		_fail("El archivo perdió su centrado vertical original")
		return
	if side_menu.get_theme_font(&"normal_font") != side_controls.get_theme_font(&"font") \
			or side_menu.get_theme_font_size(&"normal_font_size") != side_controls.get_theme_font_size(&"font_size"):
		_fail("El archivo no comparte tipografía y tamaño con los controles")
		return
	var tabs := recorder.get("_playback_tabs") as Control
	if not tabs.visible or tabs.get_child_count() < 3:
		_fail("Faltan las pestañas decorativas CÁMARA / ARCHIVO")
		return
	var tape_speed := recorder.get_node("TapeSpeed") as Label
	var camera_tab_geometry := recorder.get("_camera_tab_label") as Label
	var tab_center_y := tabs.offset_top + camera_tab_geometry.position.y + camera_tab_geometry.size.y * 0.5
	var speed_center_y := (tape_speed.offset_top + tape_speed.offset_bottom) * 0.5
	if not is_equal_approx(tab_center_y, speed_center_y) or tabs.offset_left != -tabs.offset_right:
		_fail("Las pestañas no están centradas a la altura exacta de SP")
		return
	if (recorder.get("_camera_tab_label") as Label).text != "CAMARA":
		_fail("La pestaña CAMARA todavía conserva el acento")
		return
	recorder.call(&"_toggle_playback_running")
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
	if not bool(recorder.get("_delete_armed")) or not confirmation.visible or "CONFIRMAR" not in confirmation.text:
		_fail("X no solicita confirmación antes de eliminar")
		return
	recorder.call(&"_delete_selected_clip")
	if clips.size() != 1 or bool(recorder.get("_delete_armed")) or confirmation.visible:
		_fail("La confirmación no eliminó exactamente una cinta")
		return
	recorder.call(&"_set_delete_confirmation", true)
	recorder.call(&"_delete_selected_clip")
	var empty_background := recorder.get("_playback_empty_background") as ColorRect
	var volume_indicator := recorder.get("_playback_volume_indicator") as Control
	if not clips.is_empty() or not empty_background.visible or empty_background.color.r <= 0.1:
		_fail("El hueco de vídeo vacío no muestra su fondo gris")
		return
	if not volume_indicator.visible or volume_indicator.get_child_count() != 5:
		_fail("Falta el indicador VOL decorativo de cuatro niveles")
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
	recorder.call(&"toggle_avdv")
	if not bool(recorder.get("_mode_transitioning")) or not bool(recorder.get("_playback_open")):
		_fail("BLOQ MAYUS no inició el paso de ARCHIVO a AV / DV")
		return
	var avdv_tab := recorder.get("_avdv_tab_label") as Label
	var archive_tab := recorder.get("_archive_tab_label") as Label
	if avdv_tab.get_theme_color(&"font_color").r <= archive_tab.get_theme_color(&"font_color").r:
		_fail("El foco no pasó a la pestaña AV / DV antes del loader")
		return
	recorder.call(&"_process", 1.2)
	var avdv_menu := recorder.get("_avdv_menu") as RichTextLabel
	if not avdv_menu.visible or "SACAR CINTA" not in avdv_menu.get_parsed_text() \
			or "METER CINTA" not in avdv_menu.get_parsed_text() \
			or "SIN CONEXIÓN" not in avdv_menu.get_parsed_text():
		_fail("El menú AV / DV no expone sus operaciones y bloqueos")
		return
	recorder.set("_avdv_selection", 0)
	recorder.call(&"_activate_avdv_option")
	if bool(recorder.get("_tape_inserted")):
		_fail("SACAR CINTA no cambió el estado físico")
		return
	recorder.call(&"_activate_avdv_option")
	if (recorder.get("_avdv_status") as Label).text != "NO HAY NINGUNA CINTA INSERTADA":
		_fail("SACAR CINTA no queda bloqueado tras extraerla")
		return
	recorder.set("_avdv_selection", 1)
	recorder.call(&"_activate_avdv_option")
	if not bool(recorder.get("_tape_inserted")):
		_fail("METER CINTA no restauró el estado físico")
		return
	recorder.call(&"toggle_avdv")
	if not bool(recorder.get("_mode_transitioning")):
		_fail("BLOQ MAYUS no inició el regreso de AV / DV a CAMARA")
		return
	var camera_tab := recorder.get("_camera_tab_label") as Label
	if camera_tab.get_theme_color(&"font_color").r <= avdv_tab.get_theme_color(&"font_color").r:
		_fail("El foco no pasó a CAMARA antes del loader final")
		return
	recorder.call(&"_process", 1.2)
	if paused or bool(recorder.get("_playback_open")) or bool(recorder.get("_mode_transitioning")):
		_fail("La cámara no regresó correctamente tras el loader")
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
