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
	var player := world.get_node("Player")
	var avatar := player.get_node("PlayerAvatar")
	player.set("_flashlight_available", true)
	player.set("_flashlight_holstered", false)
	player.get_node("Head/Camera3D/HandRig/Flashlight").visible = true
	avatar.call(&"set_ground_camera_mode", true)
	player.call(&"_update_player_avatar", 1.0 / 60.0)
	var bulb := avatar.find_child("GroundCameraFlashlightBulb", true, false) as Node3D
	if bulb == null or not bulb.visible:
		push_error("La bombilla del avatar no aparece con la camara O y la linterna encendida")
		quit(1)
		return
	var flashlight_visual := avatar.find_child("SelfieFlashlight", true, false) as Node3D
	var head := avatar.get_node("Body/Head") as Node3D
	var beam_forward := -flashlight_visual.global_basis.z.normalized()
	var avatar_forward := head.global_basis.z.normalized()
	if beam_forward.dot(avatar_forward) < 0.98:
		push_error("La linterna del avatar no apunta hacia delante en la camara O")
		quit(1)
		return
	player.get_node("Head/Camera3D/HandRig/Flashlight").visible = false
	player.call(&"_update_player_avatar", 1.0 / 60.0)
	if bulb.visible:
		push_error("La bombilla del avatar sigue visible con la linterna apagada")
		quit(1)
		return
	player.get_node("Head/Camera3D/HandRig/Flashlight").visible = true
	avatar.call(&"set_ground_camera_mode", false)
	player.call(&"_update_player_avatar", 1.0 / 60.0)
	if bulb.visible:
		push_error("La bombilla auxiliar aparece fuera de la camara O")
		quit(1)
		return
	print("OK: foco del avatar limitado a camara O y sincronizado con la linterna")
	current_scene = null
	world.queue_free()
	await process_frame
	quit(0)
