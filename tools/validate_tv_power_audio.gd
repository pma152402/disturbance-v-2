extends SceneTree

const TelevisionScene := preload("res://house_props/large_tv.tscn")
const GameplaySounds := preload("res://sounds/gameplay_sound_factory.gd")
const PowerOnSound := preload("res://sounds/objects/tv_crt_power_on.wav")
const PowerOffSound := preload("res://sounds/objects/tv_crt_power_off.wav")
const ChannelRotarySound := preload("res://sounds/objects/tv_channel_rotary_real.mp3")
const VolumeRotarySound := preload("res://sounds/objects/tv_volume_rotary_real.mp3")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var television := TelevisionScene.instantiate()
	root.add_child(television)
	await process_frame

	var power_audio := television.get_node_or_null("PowerAudio") as AudioStreamPlayer3D
	var control_audio := television.get_node_or_null("ControlAudio") as AudioStreamPlayer3D
	_assert(power_audio != null, "La tele debe crear un reproductor 3D para el encendido")
	_assert(control_audio != null, "La tele debe crear un reproductor 3D para sus ruedas")
	_assert(power_audio.max_distance == 14.0, "El sonido debe quedar localizado cerca de la tele")
	_assert(control_audio.max_distance == 10.0, "Los controles deben oirse mas cerca que el encendido")

	var power_on := PowerOnSound
	var power_off := PowerOffSound
	var channel_change := ChannelRotarySound
	var volume_detent := VolumeRotarySound
	var remote_channel := GameplaySounds.make_crt_remote_channel_response()
	_assert(power_on != null and power_on.get_length() > 1.0, "El encendido real debe incluir su cola de calentamiento")
	_assert(power_off != null and power_off.get_length() > 0.6, "El apagado real debe incluir su descarga")
	_assert(not is_equal_approx(channel_change.get_length(), volume_detent.get_length()), "Las dos ruedas deben usar grabaciones distintas")
	_assert(channel_change.get_length() > 1.0, "El selector de canal debe conservar el cuerpo de la grabacion real")
	_assert(volume_detent.get_length() > 1.0, "La rueda de volumen debe conservar el cuerpo de la grabacion real")
	_assert(remote_channel != channel_change, "El mando no debe imitar el selector mecanico de canal")
	_assert(GameplaySounds.make_tv_remote_button(&"power") != GameplaySounds.make_tv_remote_button(&"volume"), "Los botones del mando deben conservar pesos distintos")

	_assert(bool(television.call(&"toggle_power")), "La tele debe poder encenderse")
	_assert(power_audio.stream == power_on, "Encender debe reproducir el efecto CRT correspondiente")
	_assert(bool(television.call(&"next_channel")), "La tele encendida debe poder cambiar de canal")
	_assert(control_audio.stream == channel_change, "Cambiar de canal debe accionar el selector mecanico")
	_assert(bool(television.call(&"adjust_volume", 1)), "La tele encendida debe poder subir el volumen")
	_assert(control_audio.stream == volume_detent, "Ajustar volumen debe accionar el clic dentado")
	_assert(bool(television.call(&"next_channel", true)), "El mando debe poder cambiar el canal")
	_assert(control_audio.stream == remote_channel, "El mando solo debe provocar la respuesta electronica de sintonia")
	control_audio.stream = null
	_assert(bool(television.call(&"adjust_volume", 1, true)), "El mando debe poder ajustar volumen")
	_assert(control_audio.stream == null, "El volumen remoto no debe girar fisicamente la rueda de la tele")
	_assert(bool(television.call(&"toggle_power")), "La tele debe poder apagarse")
	_assert(power_audio.stream == power_off, "Apagar debe reproducir el efecto CRT correspondiente")

	print("OK: la tele reproduce encendido, apagado, canal y volumen CRT en audio 3D")
	television.queue_free()
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
