extends SceneTree
## Detecta versiones incompatibles del cerebro/animador sin fijar su diseño.
## La postura se prueba como entrada del animador; no se cambia el runtime.
var _failures := 0
var _checks := 0

func _initialize() -> void:
	call_deferred(&"_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)

func _finish() -> void:
	print("SHADOW_ANIMATION_CONTRACT checks=", _checks, " failures=", _failures)
	quit(1 if _failures else 0)

func _run() -> void:
	var packed := load("res://enemies/shadow_crawler.tscn") as PackedScene
	_check(packed != null, "No se pudo cargar ShadowCrawler")
	if packed == null:
		_finish()
		return
	var actor := packed.instantiate() as CharacterBody3D
	_check(actor != null, "ShadowCrawler no es un CharacterBody3D")
	if actor == null:
		_finish()
		return
	# Verificar antes de add_child: el animador usa el contrato en su _ready.
	var has_stance := false
	for property: Dictionary in actor.get_property_list():
		if property.name == &"upright_amount":
			has_stance = int(property.type) in [TYPE_FLOAT, TYPE_INT]
	_check(has_stance, "El animador requiere upright_amount numérico en el cerebro")
	if not has_stance:
		actor.free()
		_finish()
		return
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	floor_body.position.y = -0.1
	world.add_child(actor)
	actor.set_physics_process(false)
	var visual := actor.get_node_or_null("EditableVisual") as Node3D
	_check(visual != null, "Falta EditableVisual")
	if visual == null:
		world.free()
		_finish()
		return
	visual.set_physics_process(false)
	for amount in [0.0, 0.5, 1.0]:
		actor.set(&"upright_amount", amount)
		for orientation in [Basis.IDENTITY, Basis(Vector3.BACK, PI * 0.5), Basis(Vector3.BACK, PI)]:
			actor.global_basis = orientation
			actor.force_update_transform()
			var landmarks: Variant = visual.call(&"_body_landmarks", 0.01, 0.02)
			_check(landmarks is Array and landmarks.size() == 2, "Contrato de pelvis/pecho incompleto")
			if landmarks is Array:
				for point: Variant in landmarks:
					_check(point is Vector3 and point.is_finite(), "Pose corporal no finita")
			for index in 4:
				var contact: Variant = visual.call(&"_rest_contact", index)
				_check(contact is Vector3 and contact.is_finite(), "Contacto de reposo no finito")
			for index in 2:
				var hand: Variant = visual.call(&"_hand_basis", index)
				_check(hand is Basis and hand.is_finite(), "Orientación de mano no finita")
				var pole: Variant = visual.call(&"_leg_pole", 1.0 if index == 0 else -1.0)
				_check(pole is Vector3 and pole.is_finite(), "Polo de pierna no finito")
			visual.call(&"_physics_process", 1.0 / 60.0)
			var torso := visual.get(&"torso") as MeshInstance3D
			_check(torso != null and torso.mesh != null, "La pose no produjo torso")
			if torso != null:
				_check(torso.get_aabb().position.is_finite() and torso.get_aabb().size.is_finite(), "Límites del torso no finitos")
	for sound_name in ["BreathingSound", "FootstepSound", "VoiceSound"]:
		var sound := actor.get_node_or_null(sound_name) as AudioStreamPlayer3D
		_check(sound != null and sound.stream == null and not sound.playing, "El contrato silencioso cambió: " + sound_name)
	world.free()
	_finish()
