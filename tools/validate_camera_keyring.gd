extends SceneTree
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var render := "--render" in OS.get_cmdline_user_args()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(300, 200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.065, 0.075, 0.067)
	backdrop.size = Vector2(300, 200)
	viewport.add_child(backdrop)
	var recording := Label.new()
	recording.name = "Recording"
	viewport.add_child(recording)
	var hud := load("res://systems/camera_keyring_hud.tscn").instantiate() as Control
	viewport.add_child(hud)
	hud.position = Vector2(27, 25)
	check(not hud.visible, "Keyring visible at startup")
	check(not hud.is_processing(), "Hidden keyring polls every frame")
	hud.show_or_cycle()
	check(hud.visible, "L cannot show an empty keyring")
	hud._process(3.0)
	check(not hud.visible, "Keyring does not hide like inventory")
	var caption := Label.new()
	caption.position = Vector2(27, 174)
	viewport.add_child(caption)
	var sheet := Image.create(1200, 200, false, Image.FORMAT_RGBA8) if render else null
	var ids: Array = hud.KEY_NAMES.keys()
	for count_ in [0, 1, 4, 10]:
		while hud._keys.size() < count_:
			var index: int = hud._keys.size()
			hud.add_key(ids[index], "LLAVE DEL SÓTANO" if index == 0 else hud.KEY_NAMES[ids[index]])
		check(not hud.visible, "Collecting keys unexpectedly opens the keyring")
		hud.show_or_cycle()
		check(hud.visible, "L did not reveal keys")
		check(hud.cycle_hint.modulate == Color.WHITE, "L hint is dimmed")
		for index in hud._keys.size():
			check(is_equal_approx(hud._key_head_center(index).distance_to(hud.RING_CENTER), hud.RING_RADIUS), "Key hole is detached from ring")
		if render:
			caption.text = "%d LLAVES" % count_
			await process_frame
			await RenderingServer.frame_post_draw
			var shot := viewport.get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(shot, Rect2i(0, 0, 300, 200), Vector2i([0, 1, 4, 10].find(count_) * 300, 0))
		hud._process(3.0)
	check(hud._keys[0].name == "LLAVE DEL SOTANO", "Accented key name remains in HUD")
	hud.add_key(ids[0], "DUPLICATE")
	check(hud._keys.size() == 10, "Duplicate key added a second hanging key")
	hud.show_or_cycle()
	var first: StringName = hud.get_selected_key_id()
	hud.show_or_cycle()
	check(hud.get_selected_key_id() != first, "L cannot select another collected key")
	recording.visible = false
	hud._process(0.01)
	check(not hud.visible, "Keyring remains over camera menus")
	recording.visible = true
	check(not hud.visible, "Closing camera menu reopened keyring without L")
	check(preload("res://systems/key_display_text.gd").clean("ÁÉÍÓÚ áéíóú ü Ñ") == "AEIOU aeiou u N", "Display normalization failed")
	if render:
		sheet.save_png("res://tools/output/keyring_preview.png")
	print("KEYRING: failures=", failures, " keys=", hud._keys.size())
	viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)
