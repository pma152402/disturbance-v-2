extends SceneTree

## Regresión de los componentes que duermen hasta recibir una interacción.
## Es autónoma: no carga la casa ni necesita navegación o renderizador real.

const AlertsScene := preload("res://systems/camera_context_alerts.tscn")
const Spinner := preload("res://systems/camera_tape_spinner.gd")
const TelevisionScene := preload("res://house_props/large_tv.tscn")
const TripodScene := preload("res://house_props/camera_tripod.tscn")

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_validate_alerts()
	_validate_spinner()
	_validate_television()
	await _validate_tripod()
	if not _failed:
		print("OK: HUD, spinner, televisión y trípode duermen y recuperan sus funciones sin cambiar tiempos ni física")
	quit(1 if _failed else 0)


func _validate_alerts() -> void:
	var alerts := AlertsScene.instantiate() as CameraContextAlerts
	root.add_child(alerts)
	alerts._process(0.016)
	_check(not alerts.visible and not alerts.is_processing(), "El HUD vacío debe dormir")
	for _frame in 120:
		alerts.set_camera_active(true)
		alerts.set_storage_usage(0, 4)
	_check(not alerts.is_processing(), "Repetir el mismo estado desde la cámara no debe despertar el HUD")
	alerts.set_storage_usage(3, 4)
	_check(alerts.is_processing(), "Cambiar almacenamiento debe despertar el HUD")
	alerts._process(0.016)
	_check(alerts.visible and alerts._active_kind == CameraContextAlerts.AlertKind.LIMITED_SPACE, "Debe aparecer ESPACIO LIMITADO al entrar en la condición")
	alerts._process(alerts.display_seconds + 0.01)
	_check(not alerts.visible and alerts.is_processing(), "El aviso debe terminar y su cooldown debe continuar")
	alerts._process(alerts.repeat_cooldown_seconds)
	_check(not alerts.visible and not alerts.is_processing(), "No repetir un aviso mientras persiste la misma condición")
	alerts.set_storage_usage(4, 4)
	alerts._process(0.016)
	_check(alerts.visible and alerts._active_kind == CameraContextAlerts.AlertKind.NO_SPACE, "Debe aparecer SIN ESPACIO al llenarse la cinta")
	alerts._process(0.2)
	var label := alerts.get_node("AlertPanel/Message") as Label
	var expected_alpha := lerpf(0.68, 1.0, (sin(alerts._blink_elapsed * TAU * 1.75) + 1.0) * 0.5)
	_check(is_equal_approx(label.modulate.a, expected_alpha), "El pulso de SIN ESPACIO debe conservar frecuencia y opacidad")
	alerts.notify_object_out_of_range()
	_check(alerts._active_kind == CameraContextAlerts.AlertKind.NO_SPACE, "La prioridad del aviso debe mantenerse")
	alerts._process(alerts.display_seconds + 0.01)
	alerts.notify_no_space()
	_check(alerts.visible and is_equal_approx(alerts._remaining, alerts.display_seconds), "Cada intento directo debe reabrir SIN ESPACIO aunque haya cooldown")
	var remaining := alerts._remaining
	alerts.set_camera_active(false)
	alerts._process(10.0)
	_check(not alerts.visible and not alerts.is_processing(), "La cámara desactivada debe dormir al terminar los cooldowns")
	_check(is_equal_approx(alerts._remaining, remaining), "Desactivar la cámara debe conservar la duración pendiente como antes")
	alerts.set_storage_usage(0, 4)
	alerts._process(0.016)
	alerts.set_camera_active(true)
	alerts._process(0.2)
	_check(is_equal_approx(alerts._remaining, remaining - 0.2), "Reactivar la cámara debe reanudar el reloj pendiente")
	alerts._process(alerts.display_seconds)
	alerts.set_storage_usage(3, 4)
	alerts._process(0.016)
	_check(alerts.visible and alerts._active_kind == CameraContextAlerts.AlertKind.LIMITED_SPACE, "Salir y volver a entrar en una condición debe rearmar su aviso")
	alerts.notify_connection_lost()
	alerts._process(0.016)
	alerts._process(10.0)
	_check(alerts.visible and alerts._active_kind == CameraContextAlerts.AlertKind.NO_CONNECTION, "SIN CONEXIÓN debe permanecer visible")
	_check(not alerts.is_processing(), "Un aviso permanente sin animación debe dormir")
	alerts.free()


func _validate_spinner() -> void:
	var spinner := Spinner.new()
	spinner.visible = false
	root.add_child(spinner)
	_check(not spinner.is_processing(), "El spinner oculto debe dormir desde su creación")
	spinner.show()
	_check(spinner.is_processing(), "Mostrar el spinner debe reactivar la animación")
	spinner._process(0.25)
	_check(is_equal_approx(spinner._phase, 1.75), "El spinner debe conservar la velocidad de siete bloques por segundo")
	spinner.hide()
	var phase := spinner._phase
	_check(not spinner.is_processing(), "Ocultar el spinner debe detener el proceso")
	spinner.show()
	spinner._process(0.25)
	_check(is_equal_approx(spinner._phase, phase + 1.75), "El spinner debe reanudar la fase previa")
	spinner.free()


func _validate_television() -> void:
	var television := TelevisionScene.instantiate() as StaticBody3D
	root.add_child(television)
	_check(not television.is_processing(), "La televisión apagada debe dormir")
	_check(bool(television.call(&"toggle_power")), "La televisión debe conservar sus programas y poder encenderse")
	_check(television.is_processing(), "La televisión encendida debe animar sus programas")
	var duration := float(television.get("frame_duration"))
	television.call(&"_process", duration * 2.5)
	_check(int(television.get("_frame")) == 2, "La televisión debe conservar el avance de fotogramas")
	_check(is_equal_approx(float(television.get("_frame_time")), duration * 0.5), "La televisión debe conservar el tiempo sobrante entre fotogramas")
	_check(bool(television.call(&"next_channel")) and int(television.get("_frame")) == 0, "Cambiar canal debe reiniciar el fotograma")
	television.call(&"toggle_power")
	_check(not television.is_processing(), "Apagar la televisión debe detener el proceso")
	var light := television.get_node("ScreenLight") as OmniLight3D
	_check(not light.visible and is_zero_approx(light.light_energy), "La televisión apagada debe conservar su estado luminoso")
	television.free()


func _validate_tripod() -> void:
	var tripod := TripodScene.instantiate() as RigidBody3D
	root.add_child(tripod)
	_check(not tripod.is_physics_processing(), "El trípode sin bloqueo debe dormir")
	tripod.call(&"set_dropped", {"deployed": true}, Vector3.ZERO)
	_check(tripod.is_physics_processing() and not tripod.freeze, "Soltar el trípode debe despertar contador y física")
	tripod.call(&"_physics_process", 0.49)
	_check(not bool(tripod.call(&"can_mount_camera")), "No permitir montar la cámara antes de los 0,5 s de bloqueo")
	tripod.call(&"_physics_process", 0.02)
	_check(bool(tripod.call(&"can_mount_camera")) and not tripod.is_physics_processing(), "Al terminar el bloqueo debe permitir montaje y dormir el contador")
	tripod.position = Vector3(0.0, 20.0, 0.0)
	var previous_height := tripod.position.y
	for _frame in 5:
		await physics_frame
	_check(tripod.position.y < previous_height, "Dormir el script no debe detener la gravedad del RigidBody")
	tripod.call(&"set_dropped", {"deployed": true}, Vector3.ZERO)
	_check(tripod.is_physics_processing() and is_equal_approx(float(tripod.get("_pickup_lock_timer")), 0.5), "Volver a soltar debe rearmar el bloqueo completo")
	tripod.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
