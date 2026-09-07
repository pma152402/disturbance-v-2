extends SceneTree

const RAT := preload("res://house_props/rat.tscn")
const DOOR := preload("res://doors/push_door.tscn")
const CLOCK := preload("res://house_props/wall_clock.tscn")
const CANDLE := preload("res://player/held_items/candle_held_visual.tscn")
const DARKROOM_LIGHT := preload("res://house_props/darkroom_red_ceiling_light.tscn")
const VENTILATION_PANEL := preload("res://house_props/ventilation_panel.tscn")
const WOOD_AMBIENCE := preload("res://sounds/ambient/wood_cracking_ambience.tscn")
const PLAYER := preload("res://player/player.tscn")
const ROCKING_CHAIR := preload("res://house_props/wooden_rocking_chair.tscn")
const ROCKING_CHAIR_SCRIPT := preload("res://house_props/self_rocking_chair.gd")
const GAMEPLAY_SOUNDS := preload("res://sounds/gameplay_sound_factory.gd")


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)

	var candle := CANDLE.instantiate()
	stage.add_child(candle)
	candle.call(&"configure_candle", {"burn_remaining": 30.0, "lit": true})
	await process_frame
	if candle.get_node_or_null("CandleSoundLoop") != null:
		_fail("la vela todavía controla el ruido de cámara")
		return

	var clock := CLOCK.instantiate()
	clock.set("tick_sound_enabled", true)
	stage.add_child(clock)
	await process_frame
	if not clock.get_node("TickSoundLoop").call(&"is_active"):
		_fail("el reloj habilitado no activó el tic-tac")
		return

	var darkroom_light := DARKROOM_LIGHT.instantiate()
	stage.add_child(darkroom_light)
	await process_frame
	if not darkroom_light.get_node("ElectricalHum").call(&"is_active"):
		_fail("la luz del cuarto oscuro no activó su ambiente")
		return
	var panel := VENTILATION_PANEL.instantiate()
	stage.add_child(panel)
	if panel.get_node_or_null("ScrewdriverSound") == null:
		_fail("el panel no contiene sonido de destornillador")
		return
	var panel_actor := Node3D.new()
	stage.add_child(panel_actor)
	panel.call(&"_start_screw_manipulation", panel_actor, 0)
	panel.call(&"handle_screwdriver_mouse", Vector2(0.0, 24.0))
	panel.call(&"_process", 0.02)
	if not (panel.get_node("ScrewdriverSound") as AudioStreamPlayer3D).playing:
		_fail("el destornillador no sonó durante un giro válido")
		return
	panel.call(&"end_screw_manipulation")
	panel.call(&"_process", 1.0)
	if (panel.get_node("ScrewdriverSound") as AudioStreamPlayer3D).playing:
		_fail("el destornillador siguió sonando fuera de la manipulación")
		return

	var ambience := WOOD_AMBIENCE.instantiate()
	stage.add_child(ambience)
	if (ambience as AudioStreamPlayer3D).stream == null:
		_fail("el ambiente de crujidos no tiene stream")
		return

	var player_scene := PLAYER.instantiate()
	if player_scene.get_node_or_null("FootstepSound") == null or player_scene.get_node_or_null("FootstepSoundRight") == null:
		_fail("el jugador no contiene las dos voces de pasos procedurales")
		return
	stage.add_child(player_scene)
	await process_frame
	var camera_filter := player_scene.get_node_or_null("CameraAudioFilter")
	if camera_filter == null:
		_fail("falta el filtro global de micrófono de cámara")
		return
	var master_bus := AudioServer.get_bus_index(&"Master")
	var has_high_pass := false
	var has_low_pass := false
	for effect_index in AudioServer.get_bus_effect_count(master_bus):
		var effect := AudioServer.get_bus_effect(master_bus, effect_index)
		has_high_pass = has_high_pass or effect is AudioEffectHighPassFilter
		has_low_pass = has_low_pass or effect is AudioEffectLowPassFilter
	if not has_high_pass or not has_low_pass:
		_fail("el filtro de cámara no instaló su banda limitada")
		return
	var camera_background_noise := player_scene.get_node("Head/Camera3D/CameraBackgroundNoise")
	var camera_noise_stream := camera_background_noise.get("stream") as AudioStream
	if not camera_background_noise.call(&"is_active") or camera_noise_stream == null \
		or not camera_noise_stream.resource_path.ends_with("camera_background_noise.mp3"):
		_fail("el ruido de cámara no está activo permanentemente en el jugador")
		return
	if camera_background_noise.get_parent() != player_scene.get_node("Head/Camera3D"):
		_fail("el ruido permanente no está fijado al punto de escucha")
		return
	if not is_equal_approx(float(camera_background_noise.get("volume_db")), -40.0):
		_fail("el ruido permanente no está fijado a -40 dB")
		return
	if not is_equal_approx(float(camera_background_noise.get("volume_ceiling_db")), -40.0):
		_fail("el ruido permanente no tiene techo interno de -40 dB")
		return
	camera_background_noise.call(&"_process", 2.0)
	for voice_name in ["LoopVoice1", "LoopVoice2"]:
		if float(camera_background_noise.get_node(voice_name).volume_db) > -39.99:
			_fail("una voz del ruido permanente superó -40 dB")
			return
	for variant in 4:
		var generated_step := GAMEPLAY_SOUNDS.make_outdoor_footstep(variant) as AudioStreamWAV
		if generated_step == null or generated_step.data.is_empty():
			_fail("no se generó una variante del paso exterior")
			return
	ambience.call(&"_play_crack")
	if not (ambience as AudioStreamPlayer3D).playing:
		_fail("el ambiente no inició un crack aislado")
		return
	var crack_duration := float(ambience.get("_fragment_timer"))
	if crack_duration < 0.25 or crack_duration > 0.7:
		_fail("el ambiente intentó reproducir más de un crack")
		return
	var zoom_audio := player_scene.get_node("ZoomSound") as AudioStreamPlayer
	player_scene.call(&"_play_zoom_sound", false)
	await process_frame
	if not zoom_audio.playing or zoom_audio.get_playback_position() < 1.5:
		_fail("el zoom out no empezó en el segundo tramo del audio")
		return
	player_scene.global_position = Vector3(8.0, 4.2, 6.0)
	var rocking_chair := ROCKING_CHAIR.instantiate()
	rocking_chair.set_script(ROCKING_CHAIR_SCRIPT)
	stage.add_child(rocking_chair)
	await process_frame
	if not (rocking_chair.get_node("RockingSound") as AudioStreamPlayer3D).playing:
		_fail("la mecedora no sonó al entrar en la habitación superior")
		return
	player_scene.global_position = Vector3.ZERO
	rocking_chair.call(&"_process", 0.1)
	if (rocking_chair.get_node("RockingSound") as AudioStreamPlayer3D).playing:
		_fail("la mecedora siguió sonando fuera de la habitación superior")
		return

	var door_root := DOOR.instantiate()
	stage.add_child(door_root)
	var door := door_root.get_node("Hinge")
	var actor := Node3D.new()
	stage.add_child(actor)
	door.call(&"interact", actor)
	await process_frame
	var door_audio := door.get_node("DoorSound") as AudioStreamPlayer3D
	if not door_audio.playing or door_audio.get_playback_position() > 0.5:
		_fail("la apertura no empezó en el primer tramo")
		return
	await create_timer(0.7).timeout
	door.call(&"interact", actor)
	await process_frame
	if not door_audio.playing or door_audio.get_playback_position() < 3.65:
		_fail("el cierre no empezó en el segundo tramo")
		return

	var rat := RAT.instantiate()
	rat.set("escape_delay", 0.0)
	stage.add_child(rat)
	rat.call(&"_on_escape_triggered")
	await create_timer(1.12).timeout
	if not (rat.get_node("RatSound") as AudioStreamPlayer3D).playing:
		_fail("la rata no emitió el susto un segundo después de salir")
		return

	print("OK: único paso exterior, ruido de cámara estable por postura, filtro Master, bucles optimizados y zoom")
	quit(0)


func _fail(message: String) -> void:
	push_error("FALLO: " + message)
	quit(1)
