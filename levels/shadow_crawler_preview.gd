extends Node3D
## F6: inspect appearance and try the real light sensor without a player target.
var actor: CharacterBody3D
var lamp: OmniLight3D
var flashlight: SpotLight3D
var caption: Label
var mode := 0
var orbit := 0.6
var camera: Camera3D

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.11, 0.13, 0.16)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.7
	environment.environment = settings
	add_child(environment)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 0.2, 10)
	collision.shape = shape
	floor_body.add_child(collision)
	floor_body.position.y = -0.1
	add_child(floor_body)
	camera = Camera3D.new()
	camera.fov = 46
	add_child(camera)
	camera.make_current()
	lamp = OmniLight3D.new()
	lamp.position = Vector3(-1, 2.5, 1)
	lamp.light_energy = 5.0
	lamp.omni_range = 9.0
	lamp.visible = false
	add_child(lamp)
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_energy = 6.5
	flashlight.spot_range = 21.0
	flashlight.spot_angle = 29.0
	flashlight.visible = false
	camera.add_child(flashlight)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	caption = Label.new()
	caption.position = Vector2(24, 24)
	caption.add_theme_font_size_override("font_size", 22)
	canvas.add_child(caption)
	_respawn()

func _respawn() -> void:
	if is_instance_valid(actor):
		remove_child(actor)
		actor.queue_free()
	mode = 0
	lamp.visible = false
	flashlight.visible = false
	actor = preload("res://enemies/shadow_crawler.tscn").instantiate()
	actor.remain_still = true
	add_child(actor)

func _process(_delta: float) -> void:
	camera.position = Vector3(sin(orbit) * 3.6, 1.7, cos(orbit) * 3.6)
	camera.look_at(Vector3(0, 1.15, 0))
	var status := "Desvanecido — R para recrearlo"
	if is_instance_valid(actor):
		status = "%s | Disolución: %d%%" % [["Sombras", "Luz de habitación", "Linterna"][mode], roundi(actor.dissolution * 100)]
	caption.text = "BLACK ENTE\n1 Sombras · 2 Habitación · 3 Linterna · R Reiniciar\nArrastrar con botón izquierdo: girar vista\n" + status

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		orbit -= event.relative.x * 0.008
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_respawn()
		if event.keycode in [KEY_1, KEY_2, KEY_3]:
			mode = event.keycode - KEY_1
			lamp.visible = mode == 1
			flashlight.visible = mode == 2
