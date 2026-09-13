extends SceneTree

const Reflections := preload("res://systems/subtle_player_reflections.gd")
var _failed := false


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(960, 640)
	var world := Node3D.new()
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.add_to_group(&"player")
	world.add_child(player)
	player.position = Vector3(0, 0.85, 2)
	var avatar := preload("res://characters/companion/child_visual.tscn").instantiate() as Node3D
	avatar.name = "PlayerAvatar"
	avatar.position.y = -0.9
	avatar.rotation.y = PI
	player.add_child(avatar)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = player.position + Vector3(0, 0.62, 0)
	camera.fov = 65.0
	camera.cull_mask = 1048573
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.08, 0.09, 0.10)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7, 0.75, 0.8)
	environment.environment.ambient_light_energy = 0.8
	world.add_child(environment)
	var mirror := preload("res://house_props/antique_mirror.tscn").instantiate() as Node3D
	world.add_child(mirror)
	var white := preload("res://house_props/white_antique_mirror.tscn").instantiate() as Node3D
	world.add_child(white)
	white.position.x = -1.1
	var vanity := preload("res://house_props/antique_vanity_table.tscn").instantiate() as Node3D
	world.add_child(vanity)
	vanity.position.x = 10.0
	var window := StaticBody3D.new()
	window.name = "WindowGlass_test"
	world.add_child(window)
	window.position = Vector3(1.3, 1.0, 0)
	var glass := MeshInstance3D.new()
	glass.mesh = BoxMesh.new()
	(glass.mesh as BoxMesh).size = Vector3(1.5, 1.8, 0.035)
	var glass_material := StandardMaterial3D.new()
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.albedo_color = Color(0.45, 0.6, 0.64, 0.15)
	glass.material_override = glass_material
	window.add_child(glass)
	var controller := Reflections.new()
	world.add_child(controller)
	await _frames(10)
	_check(controller.surfaces.size() == 4, "Registrar espejos antiguo/blanco/tocador y ventana")
	_check(controller.slots.size() == 2, "Presupuesto estricto de dos capturas")
	_check(_active(controller) > 0, "Espejo frontal debe activarse")
	_check(glass.material_override == glass_material, "Conservar el material original de ventana")
	var reflected := Reflections.reflected_transform(camera.global_transform, Vector3.ZERO, Vector3.BACK)
	_check(reflected.origin.is_equal_approx(Vector3(0, 1.47, -2)), "Reflejar posicion al otro lado del plano")
	_check(reflected.basis.determinant() > 0.99, "Conservar base diestra para caras visibles")
	for slot in controller.slots:
		var viewport := slot.viewport as SubViewport
		_check(viewport.world_3d != world.get_world_3d(), "No renderizar la casa en las capturas")
		_check(maxi(viewport.size.x, viewport.size.y) <= 256, "Resolucion acotada")
		_check(viewport.positional_shadow_atlas_size == 0, "Sin sombras adicionales")
	# Movimiento y posturas: copiar las matrices animadas reales, no otra animacion.
	for stance: float in [0.0, 1.0, 2.0]:
		avatar.call(&"update_player_animation", 0.2, Vector3(0.0, 0.0, -1.4), stance, true, false, -0.2, 0.1, &"", &"")
		controller._sync_avatar()
		for pair in controller._proxies:
			_check(pair.proxy.global_transform.is_equal_approx(pair.source.global_transform), "Reflejo sigue postura y animacion")
	avatar.call(&"update_player_animation", 1.0, Vector3.ZERO, 0.0, true, false, 0.0, 0.0, &"", &"")
	if DisplayServer.get_name() != "headless":
		await _frames(12)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/output/subtle_reflections_fixture.png")
		var first_viewport := controller.slots[0].viewport as SubViewport
		var captured := first_viewport.get_texture().get_image()
		captured.save_png("res://tools/output/subtle_reflections_avatar.png")
		var opaque_pixels := 0
		for y in captured.get_height():
			for x in captured.get_width():
				if captured.get_pixel(x, y).a > 0.1:
					opaque_pixels += 1
		_check(opaque_pixels > 50, "Captura GPU contiene el cuerpo visible")
	# Equipar despues de crear las capturas: la linterna no dependia del inventario inicial.
	avatar.call(&"update_player_animation", 0.2, Vector3.ZERO, 0.0, true, false, 0.0, 0.0, &"flashlight", &"", true)
	controller._sync_avatar()
	var torch: Node3D = controller._reflected_flashlight
	var lens: MeshInstance3D = controller._flashlight_lens
	var hand := avatar.get_node("Body/LeftArm/Forearm/Hand") as Node3D
	_check(torch.is_visible_in_tree() and lens.is_visible_in_tree(), "Equipar tarde muestra linterna y bombilla encendida")
	_check(torch.global_position.is_equal_approx(hand.to_global(Vector3(0, -0.055, 0.018))), "La linterna permanece en la mano reflejada")
	_check(lens.position.is_equal_approx(Vector3(0.024, 0.027, -0.3)), "Brillo centrado sobre la lente del asset")
	_check(controller.slots[0].viewport.find_children("*", "Light3D", true, false).is_empty(), "La bombilla no anade luces al render del reflejo")
	var lens_on: Image
	if DisplayServer.get_name() != "headless":
		controller._capture_elapsed = 1.0
		controller._process(0.0)
		await RenderingServer.frame_post_draw
		lens_on = controller.slots[0].viewport.get_texture().get_image()
		root.get_texture().get_image().save_png("res://tools/output/subtle_reflections_flashlight_on.png")
	avatar.set("_flashlight_on", false)
	controller._sync_avatar()
	_check(torch.is_visible_in_tree() and not lens.is_visible_in_tree(), "Apagar conserva el cuerpo de linterna sin brillo")
	if DisplayServer.get_name() != "headless":
		controller._capture_elapsed = 1.0
		controller._process(0.0)
		await RenderingServer.frame_post_draw
		var lens_off: Image = controller.slots[0].viewport.get_texture().get_image()
		root.get_texture().get_image().save_png("res://tools/output/subtle_reflections_flashlight_off.png")
		var changed := 0
		for y in lens_on.get_height():
			for x in lens_on.get_width():
				if lens_on.get_pixel(x, y).r - lens_off.get_pixel(x, y).r > 0.05:
					changed += 1
		_check(changed > 0, "La bombilla produce brillo real en la captura GPU")
		# Comprobar tambien el cristal transparente desde su centro.
		camera.position.x = 1.3
		player.position.x = 1.3
		avatar.set("_flashlight_on", true)
		controller._select_surfaces(camera)
		controller._capture_elapsed = 1.0
		controller._process(0.0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/output/subtle_reflections_window_flashlight.png")
		camera.position.x = 0.0
		player.position.x = 0.0
		controller._select_surfaces(camera)
	# Apuntar la mano orienta la linterna reflejada, sin cambiar la pose original.
	var aiming_head := Node3D.new()
	aiming_head.name = "Head"
	player.add_child(aiming_head)
	var aiming_camera := Node3D.new()
	aiming_camera.name = "Camera3D"
	aiming_head.add_child(aiming_camera)
	var aiming_hand := Node3D.new()
	aiming_hand.name = "HandRig"
	aiming_camera.add_child(aiming_hand)
	var aiming_light := SpotLight3D.new()
	aiming_light.name = "Flashlight"
	aiming_light.light_energy = 0.0
	aiming_hand.add_child(aiming_light)
	aiming_light.rotation = Vector3(0.2, 0.4, 0.0)
	controller._sync_avatar()
	_check((-torch.global_basis.z.normalized()).dot(-aiming_light.global_basis.z.normalized()) > 0.999, "La lente sigue el apuntado independiente de la linterna real")
	aiming_head.free()
	avatar.set("_equipped_item", &"")
	controller._sync_avatar()
	_check(not torch.is_visible_in_tree(), "Guardar o soltar la linterna retira tambien su reflejo")
	# Detras del espejo y fuera del alcance no queda ninguna captura encendida.
	camera.position.z = -2
	player.position.z = -2
	camera.rotation.y = PI
	window.visible = false
	await _frames(2)
	controller._select_surfaces(camera)
	_check(_active(controller) == 0, "Espejos no reflejan por detras")
	camera.position = Vector3(0, 1.47, 20)
	controller._select_surfaces(camera)
	var count := controller.capture_count
	for frame in 60:
		controller._process(1.0 / 60.0)
	_check(controller.capture_count == count, "Cero capturas fuera de alcance")
	# Rechazo de una pared opaca entre la camara y el espejo.
	camera.position = Vector3(0, 1.47, 2)
	camera.rotation = Vector3.ZERO
	player.position.z = 2
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 4, 0.2)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	wall.position = Vector3(0, 1, 1)
	await physics_frame
	await physics_frame
	controller._select_surfaces(camera)
	_check(_active(controller) == 0, "No reflejar a traves de paredes")
	wall.free()
	await physics_frame
	controller._select_surfaces(camera)
	_check(_active(controller) > 0, "Reactivar al volver a tener vision directa")
	# No superar 15 capturas/s por slot incluso con seleccion frecuente a 60 FPS.
	controller.set_process(false)
	controller._capture_elapsed = 0.0
	count = controller.capture_count
	for frame in 600:
		controller._process(1.0 / 60.0)
	_check(controller.capture_count - count <= 300, "Tope de 15 Hz por cada uno de los dos slots")
	# La ventana funciona desde fuera y desde dentro; la sala oculta la desactiva.
	mirror.visible = false
	white.visible = false
	window.visible = true
	camera.position = Vector3(1.3, 1.47, -2)
	player.position = Vector3(1.3, 0.85, -2)
	camera.rotation.y = PI
	controller._select_surfaces(camera)
	_check(_active(controller) == 1, "Ventana visible por su segunda cara")
	glass.set_meta(&"reflection_batched_source", true)
	glass.hide()
	controller._select_surfaces(camera)
	_check(_active(controller) == 1, "Cristal agrupado conserva reflejo")
	controller._process(0.1)
	var reflected_window: MeshInstance3D = controller.slots[0].surface.overlay if not controller.slots[0].surface.is_empty() else controller.slots[1].surface.overlay
	_check(reflected_window.is_visible_in_tree(), "Reflejo agrupado no hereda la ocultacion de la malla original")
	window.hide()
	controller._select_surfaces(camera)
	_check(_active(controller) == 0, "Ocultar sala oculta tambien cristal agrupado")
	controller.enabled = false
	controller._process(0.1)
	_check(_active(controller) == 0, "Desactivar libera el presupuesto de render")
	var remaining := controller.surfaces.size()
	glass.queue_free()
	await _frames(2)
	_check(controller.surfaces.size() == remaining - 1, "Descargar cristal limpia su registro y reflejo")
	print("REFLEJOS SUTILES: ", "FALLO" if _failed else "OK: superficies, posturas, limites, oclusion y reposo")
	world.queue_free()
	await process_frame
	quit(1 if _failed else 0)


func _active(controller: Node) -> int:
	var count := 0
	for slot in controller.slots:
		if not slot.surface.is_empty():
			count += 1
	return count


func _frames(count: int) -> void:
	for frame in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
