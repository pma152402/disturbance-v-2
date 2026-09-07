extends SceneTree

## Comprueba que cada suelo real del juego se clasifica en la superficie
## esperada y que el sintetizador produce audio distinto para cada una.

# Rutas reales de test.tscn, obtenidas sondeando el suelo bajo el jugador.
const EXPECTED := {
	"Weather/CellarGroundCutout/GroundCutoutCollision": &"dirt",
	"House/GroundFloor/GroundFloorSlab": &"wood",
	"House/UpperFloor/UpperFloorSlabEast": &"wood",
	"House/GroundFloor/ChurchNaveFloor": &"stone",
	"House/CompactStaircase/WalkableRamp": &"wood",
	"House/NewFrontHouseDecor/AntiqueMedallionRug": &"carpet",
}

# El clasificador solo lee el nombre del nodo y dos ancestros, así que los suelos
# de escenas que se montan en runtime (la escuela) se prueban por nombre. Sirve
# igual y no ata el validador a dónde acabe colgando esa escena.
const EXPECTED_BY_NAME := {
	"Kitchen/CeramicSolid0": &"tile",
	"ExteriorBridge/StoneSolid0": &"stone",
	"Classroom/FloorSolid0": &"wood",
	"BasementAccessAndInitialRoom/BasementStairContinuousCollider": &"stone",
	"Backyard/GravelPath": &"gravel",
	"Workshop/SteelGrateWalkway": &"metal",
	"Bedroom/WoolAlfombra": &"carpet",
}


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := (load("res://test.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	# La planta de la escuela se construye en runtime; hay que dejarla montar.
	var navigation := game.get_node_or_null("RuntimeHouseNavigation")
	if navigation != null and navigation.navigation_mesh == null:
		await navigation.navigation_baked
	for _frame in 30:
		await physics_frame
	var player := game.get_node("Player") as CharacterBody3D

	for path in EXPECTED:
		var node := game.get_node_or_null(NodePath(path))
		if node == null:
			return _fail("La ruta de suelo %s ya no existe; actualiza este validador" % path)
		var classified: StringName = player.call(&"_classify_surface", node)
		if classified != EXPECTED[path]:
			return _fail("%s se clasificó como '%s' y se esperaba '%s'" % [path, classified, EXPECTED[path]])

	for chain in EXPECTED_BY_NAME:
		var parts := (chain as String).split("/")
		var parent := Node3D.new()
		parent.name = parts[0]
		var floor_node := StaticBody3D.new()
		floor_node.name = parts[1]
		parent.add_child(floor_node)
		game.add_child(parent)
		var classified: StringName = player.call(&"_classify_surface", floor_node)
		parent.queue_free()
		if classified != EXPECTED_BY_NAME[chain]:
			return _fail("%s se clasificó como '%s' y se esperaba '%s'" % [chain, classified, EXPECTED_BY_NAME[chain]])

	# Un grupo surface_* debe imponerse sobre la heurística del nombre.
	var slab := game.get_node("House/GroundFloor/GroundFloorSlab")
	slab.add_to_group(&"surface_tile")
	if StringName(player.call(&"_classify_surface", slab)) != &"tile":
		return _fail("El grupo surface_tile no anuló la heurística de nombre")
	slab.remove_from_group(&"surface_tile")

	# Cada superficie debe sonar distinta: si dos perfiles generasen la misma
	# onda, el trabajo de ajuste no estaría llegando al audio.
	var factory := load("res://sounds/gameplay_sound_factory.gd")
	var digests: Dictionary = {}
	for surface in factory.SURFACE_PROFILES:
		var stream: AudioStreamWAV = factory.make_surface_footstep(surface, 0)
		if stream == null or stream.data.is_empty():
			return _fail("La superficie '%s' no generó audio" % surface)
		# El PCM es binario: convertirlo a texto lo corta en el primer byte nulo y
		# haría pasar por iguales ondas distintas.
		var digest := "%d:%s" % [stream.data.size(), Marshalls.raw_to_base64(stream.data).sha256_text()]
		if digests.has(digest):
			return _fail("'%s' y '%s' generan exactamente el mismo paso" % [surface, digests[digest]])
		digests[digest] = surface

	# Los pasos propios no deben tapar la escena.
	var walking_db := float(player.get("volumen_pasos_normal_db"))
	if walking_db > -4.0:
		return _fail("El paso andando está a %.1f dB; debería quedar bajo el ambiente" % walking_db)

	print("OK: %d suelos clasificados, %d superficies con audio propio, paso andando a %.1f dB" % [
		EXPECTED.size() + EXPECTED_BY_NAME.size(), digests.size(), walking_db
	])
	current_scene = null
	game.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
