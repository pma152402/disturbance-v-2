extends Node3D
## F6 inspection room, independent from the game. Physics supports are real.
var actor: CharacterBody3D
var original: CharacterBody3D
var camera: Camera3D
var caption: Label
var mode := 0
var clock := 0.0
var orbit := 0.55
var elevation := 0.25
var camera_distance := 4.2
var paused := false
var comparison := false

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.065, 0.08, 0.095)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_energy = 0.6
	environment.environment = settings
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -25, 0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	add_child(light)
	_box(Vector3(18, 0.2, 18), Vector3(0, -0.1, 0), Color(0.17, 0.19, 0.20))
	_box(Vector3(12, 5, 0.2), Vector3(0, 2.5, 2.0), Color(0.24, 0.25, 0.26))
	_box(Vector3(12, 0.2, 10), Vector3(0, 4.6, -2.9), Color(0.19, 0.20, 0.22))
	actor = preload("res://enemies/grandmother_crawler.tscn").instantiate()
	add_child(actor)
	actor.set_physics_process(false)
	original = preload("res://enemies/church_grandmother.tscn").instantiate()
	add_child(original)
	original.position = Vector3(-2.0, 0, 0)
	original.set_physics_process(false)
	original.visible = false
	original.collision_layer = 0
	original.get_node("EditableVisual").set_physics_process(false)
	camera = Camera3D.new()
	camera.fov = 50
	add_child(camera)
	camera.make_current()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	caption = Label.new()
	caption.position = Vector2(24, 24)
	caption.add_theme_font_size_override("font_size", 22)
	canvas.add_child(caption)
	_reset(0)

func _box(size: Vector3, point: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	instance.material_override = material
	body.add_child(instance)
	add_child(body)
	body.position = point

func _reset(next_mode: int) -> void:
	mode = next_mode
	clock = 0.0
	actor.position = Vector3.ZERO
	actor.rotation = Vector3.ZERO
	actor.velocity = Vector3.ZERO
	actor.set("current_state", 0)
	actor.surface.phase = 0
	actor.surface.cooldown = 0
	actor.surface.scan_timer = 0
	actor.get_node("EditableVisual")._reset_contacts()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _reset(0)
			KEY_2: _reset(1)
			KEY_3: _reset(2)
			KEY_4: _reset(3)
			KEY_R: _reset(mode)
			KEY_SPACE: paused = not paused
			KEY_V:
				comparison = not comparison
				original.visible = comparison
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		orbit -= event.relative.x * 0.007
		elevation = clampf(elevation + event.relative.y * 0.005, -0.6, 1.1)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(1.4, camera_distance - 0.3)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(8.0, camera_distance + 0.3)

func _physics_process(delta: float) -> void:
	actor.get_node("EditableVisual").set_physics_process(not paused)
	if paused:
		return
	clock += delta
	actor._idle_clock = clock
	actor.gaze_position = actor.position + actor.basis.z * 4.0 + actor.basis.y * 0.9
	match mode:
		0:
			actor.velocity = Vector3.DOWN
			actor.move_and_slide()
		1:
			actor.rotation.y += delta * 0.9
			actor.velocity = actor.basis.z * 1.2 + Vector3.DOWN
			actor.move_and_slide()
		2:
			actor.current_state = 4
			actor._attack_timer = fposmod(clock, 2.0)
			actor.attack_side = 1.0 if int(clock / 2.0) % 2 == 0 else -1.0
		3:
			if actor.surface.active():
				actor.surface.step(delta, Vector3(0, 0, -4), true)
			elif clock < 1.0:
				actor.position.z = 0.4
				actor.surface.consider(delta, Vector3(0, 0, 5), true)
	if comparison:
		original._idle_clock = clock
		original.get_node("EditableVisual")._physics_process(delta)

func _process(_delta: float) -> void:
	var focus := actor.position + Vector3.UP * 0.7
	if comparison:
		focus = focus.lerp(original.position + Vector3.UP, 0.4)
	camera.position = focus + Vector3(sin(orbit) * cos(elevation), sin(elevation), cos(orbit) * cos(elevation)) * camera_distance
	camera.look_at(focus)
	caption.text = "VIEJA TREPADORA  |  %s\n1 Reposo   2 Caminar   3 Ataque   4 Pared y techo\nV Comparar con original   Espacio Pausa   R Reiniciar\nArrastrar: girar vista   Rueda: acercar" % ["Reposo", "Caminar", "Ataque", "Trepado"][mode]
