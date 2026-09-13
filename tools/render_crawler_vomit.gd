extends SceneTree
class Target extends CharacterBody3D:
	var _monster_restart_pending := false
var viewport: SubViewport

func _initialize() -> void: call_deferred("run")
func block(size_: Vector3, position_: Vector3) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size_
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.24, 0.22)
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	viewport.add_child(body)
	body.position = position_

func run() -> void:
	seed(4501)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 560)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.075, 0.085, 0.075)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.5
	environment.environment = settings
	viewport.add_child(environment)
	var light := OmniLight3D.new()
	light.position = Vector3(1.8, 2.8, 3)
	light.omni_range = 12
	light.light_energy = 4
	viewport.add_child(light)
	block(Vector3(20, 0.2, 20), Vector3(0, -0.1, 0))
	block(Vector3(20, 0.2, 20), Vector3(0, 4.1, 0))
	block(Vector3(0.2, 4.2, 20), Vector3(5.1, 2, 0))
	var player := Target.new()
	player.add_to_group("player")
	viewport.add_child(player)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.fov = 52
	camera.make_current()
	var actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	viewport.add_child(actor)
	actor.set_physics_process(false)
	var visual = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	visual.shadow_coat_enabled = false
	var attack = actor.vomit
	var label := Label.new()
	label.position = Vector2(18, 18)
	label.add_theme_font_size_override("font_size", 21)
	viewport.add_child(label)
	var sheet := Image.create(1920, 1120, false, Image.FORMAT_RGBA8)
	for attachment in 3:
		attack.cancel()
		actor.surface.phase = attachment
		actor.surface.normal = [Vector3.UP, Vector3.LEFT, Vector3.DOWN][attachment]
		actor.transform = [Transform3D.IDENTITY, Transform3D(Basis(Vector3.UP, Vector3.LEFT, Vector3.BACK), Vector3(4.88, 1.8, 0)), Transform3D(Basis(Vector3.BACK, PI), Vector3(0, 3.88, 0))][attachment]
		player.position = Vector3(2.8 if attachment == 1 else 0, 0, 3.8)
		camera.position = [Vector3(3.3, 2.3, 4.9), Vector3(0.6, 3.3, 5), Vector3(3.3, 1.5, 4.9)][attachment]
		camera.look_at([Vector3(0, 0.9, 1.3), Vector3(3.8, 1.8, 1.3), Vector3(0, 2.1, 1.3)][attachment])
		visual._reset_contacts()
		for i in 25: visual._physics_process(1.0 / 60.0)
		await physics_frame
		attack._begin()
		attack.effects.set_physics_process(false)
		for stage in 2:
			if stage == 1:
				attack.phase = attack.Phase.DRIP
				attack.elapsed = 0.0
			for frame in (100 if stage == 0 else 65):
				attack.step(1.0 / 60.0)
				visual._physics_process(1.0 / 60.0)
				attack.effects._physics_process(1.0 / 60.0)
				await physics_frame
			label.text = ["Suelo", "Pared", "Techo"][attachment] + (" / Chorro a presion" if stage == 0 else " / Goteo y recuperacion")
			await process_frame
			await RenderingServer.frame_post_draw
			var shot := viewport.get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(shot, Rect2i(0, 0, 640, 560), Vector2i(attachment * 640, stage * 560))
	sheet.save_png("res://tools/output/crawler_vomit.png")
	print("CRAWLER VOMIT RENDER PASS")
	viewport.queue_free()
	await process_frame
	quit()
