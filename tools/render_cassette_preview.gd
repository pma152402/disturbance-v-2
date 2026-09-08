extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1000, 700)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.029, 0.033)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.52, 0.58)
	environment.ambient_light_energy = 0.72
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var packed := load("res://house_props/cassette_tape.tscn") as PackedScene
	var tape_a := packed.instantiate() as Node3D
	var tape_b := packed.instantiate() as Node3D
	tape_a.set("tape_number", 1)
	tape_b.set("tape_number", 2)
	tape_b.set("display_side", "B")
	tape_a.position = Vector3(-0.39, 0.08, 0)
	tape_a.rotation.y = -0.16
	tape_b.position = Vector3(0.39, 0.08, 0.02)
	tape_b.rotation = Vector3(0, 0.16, PI)
	stage.add_child(tape_a)
	stage.add_child(tape_b)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(2.4, 1.7)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.095, 0.082, 0.07)
	floor_material.roughness = 0.9
	floor_mesh.material = floor_material
	floor.mesh = floor_mesh
	stage.add_child(floor)
	var key_light := DirectionalLight3D.new()
	key_light.rotation = Vector3(-0.9, -0.55, 0)
	key_light.light_energy = 1.35
	key_light.shadow_enabled = true
	stage.add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-0.8, 1.0, 0.7)
	fill_light.omni_range = 3.0
	fill_light.light_energy = 2.0
	stage.add_child(fill_light)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.look_at_from_position(Vector3(0, 1.45, 1.15), Vector3(0, 0, 0))
	for _frame in 12:
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tools/output/cassette_tape_preview.png"))
	quit(0)
