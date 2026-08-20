# LEGACY GENERATOR: no longer loaded by the project.
# Edit res://house_baked.tscn directly in Godot for all future map changes.
extends Node3D

const DoorScene = preload("res://push_door.tscn")
const BottleScene = preload("res://bottle_pickup.tscn")
const CanScene = preload("res://can_pickup.tscn")
const ChairScene = preload("res://house_props/chair.tscn")
const TableScene = preload("res://house_props/table.tscn")
const SofaScene = preload("res://house_props/sofa.tscn")
const ShelfScene = preload("res://house_props/shelf.tscn")
const BarrelScene = preload("res://house_props/barrel.tscn")
const BedScene = preload("res://house_props/bed.tscn")
const CrateScene = preload("res://house_props/crate.tscn")
const RugScene = preload("res://house_props/rug.tscn")
const TrashScene = preload("res://house_props/trash_can.tscn")

const WallTexture = preload("res://ps2_house/Models/Abandoned_House_Pared2.jpg")
const FloorTexture = preload("res://ps2_house/Models/Abandoned_House_Piso2.jpg")
const CeilingTexture = preload("res://ps2_house/Models/Abandoned_House_Techo.jpg")
const WoodTexture = preload("res://ps2_house/Models/Abandoned_House_Madera4.jpg")

const HALF_WIDTH := 18.0
const HALF_DEPTH := 16.0
const LEVEL_HEIGHT := 4.2
const WALL_HEIGHT := 4.0
const WALL_THICKNESS := 0.22
const DOOR_WIDTH := 2.2
const DOOR_HEIGHT := 2.7
const WINDOW_WIDTH := 2.8
const WINDOW_BOTTOM := 1.05
const WINDOW_TOP := 2.75

var _floors: Array[Transform3D] = []
var _ceilings: Array[Transform3D] = []
var _walls: Array[Transform3D] = []
var _wood: Array[Transform3D] = []
var _glass: Array[Transform3D] = []
var _stairs: Array[Transform3D] = []
var _fixtures: Array[Transform3D] = []
var _collisions: Array[Transform3D] = []
var _doors: Array[Transform3D] = []
var _lights: Array[Vector3] = []


func _ready() -> void:
	_build_house()
	_create_render_batches()
	_create_collisions()
	_create_doors()
	_create_lights()
	_place_props()


func _build_house() -> void:
	# Each slab is made around its stair opening, so no floor or ceiling can cross a staircase.
	_add_level_slab(-LEVEL_HEIGHT, Rect2())
	_add_level_slab(0.0, Rect2(Vector2(-12.2, 0.0), Vector2(4.4, 9.4)))
	_add_level_slab(LEVEL_HEIGHT, Rect2(Vector2(7.8, -9.6), Vector2(4.4, 9.8)))
	_add_ceiling_below(0.0, Rect2(Vector2(-12.2, 0.0), Vector2(4.4, 9.4)))
	_add_ceiling_below(LEVEL_HEIGHT, Rect2(Vector2(7.8, -9.6), Vector2(4.4, 9.8)))
	_add_visual(_ceilings, Vector3(0, LEVEL_HEIGHT * 2.0 - 0.1, 0), Vector3(HALF_WIDTH * 2.0, 0.2, HALF_DEPTH * 2.0))

	_build_exterior(-LEVEL_HEIGHT, false)
	_build_exterior(0.0, true)
	_build_exterior(LEVEL_HEIGHT, false)
	_build_basement_partitions()
	_build_ground_partitions()
	_build_upper_partitions()
	_build_stairs()
	_place_light_markers()


func _add_level_slab(floor_y: float, hole: Rect2) -> void:
	if hole.size == Vector2.ZERO:
		_add_solid(_floors, Vector3(0, floor_y - 0.1, 0), Vector3(HALF_WIDTH * 2.0, 0.2, HALF_DEPTH * 2.0))
		return
	var x1 := hole.position.x
	var x2 := hole.end.x
	var z1 := hole.position.y
	var z2 := hole.end.y
	_add_solid(_floors, Vector3((-HALF_WIDTH + x1) * 0.5, floor_y - 0.1, 0), Vector3(x1 + HALF_WIDTH, 0.2, HALF_DEPTH * 2.0))
	_add_solid(_floors, Vector3((x2 + HALF_WIDTH) * 0.5, floor_y - 0.1, 0), Vector3(HALF_WIDTH - x2, 0.2, HALF_DEPTH * 2.0))
	_add_solid(_floors, Vector3((x1 + x2) * 0.5, floor_y - 0.1, (-HALF_DEPTH + z1) * 0.5), Vector3(x2 - x1, 0.2, z1 + HALF_DEPTH))
	_add_solid(_floors, Vector3((x1 + x2) * 0.5, floor_y - 0.1, (z2 + HALF_DEPTH) * 0.5), Vector3(x2 - x1, 0.2, HALF_DEPTH - z2))


func _add_ceiling_below(level_y: float, hole: Rect2) -> void:
	var ceiling_y := level_y - 0.23
	if hole.size == Vector2.ZERO:
		_add_visual(_ceilings, Vector3(0, ceiling_y, 0), Vector3(HALF_WIDTH * 2.0, 0.04, HALF_DEPTH * 2.0))
		return
	var x1 := hole.position.x
	var x2 := hole.end.x
	var z1 := hole.position.y
	var z2 := hole.end.y
	_add_visual(_ceilings, Vector3((-HALF_WIDTH + x1) * 0.5, ceiling_y, 0), Vector3(x1 + HALF_WIDTH, 0.04, HALF_DEPTH * 2.0))
	_add_visual(_ceilings, Vector3((x2 + HALF_WIDTH) * 0.5, ceiling_y, 0), Vector3(HALF_WIDTH - x2, 0.04, HALF_DEPTH * 2.0))
	_add_visual(_ceilings, Vector3((x1 + x2) * 0.5, ceiling_y, (-HALF_DEPTH + z1) * 0.5), Vector3(x2 - x1, 0.04, z1 + HALF_DEPTH))
	_add_visual(_ceilings, Vector3((x1 + x2) * 0.5, ceiling_y, (z2 + HALF_DEPTH) * 0.5), Vector3(x2 - x1, 0.04, HALF_DEPTH - z2))


func _build_exterior(floor_y: float, has_entrance: bool) -> void:
	var south_openings: Array[Dictionary] = [
		{"offset": -10.5, "type": "window"}, {"offset": 10.5, "type": "window"}
	]
	if has_entrance:
		south_openings.append({"offset": 0.0, "type": "door"})
	else:
		south_openings.append({"offset": 0.0, "type": "window"})
	_add_wall_with_openings(Vector3(0, floor_y + 2.0, HALF_DEPTH), HALF_WIDTH * 2.0, true, south_openings)
	_add_wall_with_openings(Vector3(0, floor_y + 2.0, -HALF_DEPTH), HALF_WIDTH * 2.0, true, [
		{"offset": -10.5, "type": "window"}, {"offset": 0.0, "type": "window"}, {"offset": 10.5, "type": "window"}
	])
	_add_wall_with_openings(Vector3(-HALF_WIDTH, floor_y + 2.0, 0), HALF_DEPTH * 2.0, false, [
		{"offset": -8.5, "type": "window"}, {"offset": 0.0, "type": "window"}, {"offset": 8.5, "type": "window"}
	])
	_add_wall_with_openings(Vector3(HALF_WIDTH, floor_y + 2.0, 0), HALF_DEPTH * 2.0, false, [
		{"offset": -8.5, "type": "window"}, {"offset": 0.0, "type": "window"}, {"offset": 8.5, "type": "window"}
	])


func _build_ground_partitions() -> void:
	var y := 0.0
	_add_wall_with_openings(Vector3(-4, y + 2, 0), 32, false, [
		{"offset": -10.5, "type": "door"}, {"offset": -1.5, "type": "door"}, {"offset": 11.5, "type": "door"}
	])
	_add_wall_with_openings(Vector3(4, y + 2, 0), 32, false, [
		{"offset": -12.0, "type": "door"}, {"offset": 1.5, "type": "door"}, {"offset": 11.5, "type": "door"}
	])
	_add_wall_with_openings(Vector3(-11, y + 2, -5), 14, true, [{"offset": 0.0, "type": "door"}])
	_add_wall_with_openings(Vector3(-11, y + 2, 9), 14, true, [{"offset": -2.5, "type": "door"}])
	_add_wall_with_openings(Vector3(11, y + 2, 5), 14, true, [{"offset": 0.0, "type": "door"}])


func _build_upper_partitions() -> void:
	var y := LEVEL_HEIGHT
	_add_wall_with_openings(Vector3(-4, y + 2, 0), 32, false, [
		{"offset": -10.5, "type": "door"}, {"offset": 0.0, "type": "door"}, {"offset": 10.5, "type": "door"}
	])
	_add_wall_with_openings(Vector3(4, y + 2, 0), 32, false, [
		{"offset": -11.5, "type": "door"}, {"offset": 2.0, "type": "door"}, {"offset": 11.0, "type": "door"}
	])
	_add_wall_with_openings(Vector3(-11, y + 2, -5), 14, true, [{"offset": 1.5, "type": "door"}])
	_add_wall_with_openings(Vector3(-11, y + 2, 7), 14, true, [{"offset": -2.0, "type": "door"}])
	_add_wall_with_openings(Vector3(11, y + 2, 5), 14, true, [{"offset": 1.5, "type": "door"}])


func _build_basement_partitions() -> void:
	var y := -LEVEL_HEIGHT
	_add_wall_with_openings(Vector3(-4, y + 2, -8), 16, false, [
		{"offset": -3.5, "type": "door"}, {"offset": 4.0, "type": "door"}
	])
	_add_wall_with_openings(Vector3(4, y + 2, 0), 32, false, [
		{"offset": -10.0, "type": "door"}, {"offset": 0.0, "type": "door"}, {"offset": 10.0, "type": "door"}
	])
	_add_wall_with_openings(Vector3(-11, y + 2, -5), 14, true, [{"offset": 0.0, "type": "door"}])
	_add_wall_with_openings(Vector3(11, y + 2, -5), 14, true, [{"offset": -2.0, "type": "door"}])
	_add_wall_with_openings(Vector3(11, y + 2, 7), 14, true, [{"offset": 2.0, "type": "door"}])


func _build_stairs() -> void:
	_add_staircase(Vector3(10, 0, -9.2), Vector3(0, 0, 1), true)
	_add_solid(_floors, Vector3(10, LEVEL_HEIGHT - 0.1, -0.05), Vector3(4.4, 0.2, 0.7))
	_add_staircase(Vector3(-10, 0, 0.2), Vector3(0, 0, 1), false)


func _add_staircase(start: Vector3, direction: Vector3, goes_up: bool) -> void:
	var count := 21
	var run := 0.42
	var rise := LEVEL_HEIGHT / float(count)
	var total_run := run * float(count)
	for index in count:
		var progress := float(index + 1) / float(count) if goes_up else float(index) / float(count)
		var top_y := start.y + (LEVEL_HEIGHT * progress if goes_up else -LEVEL_HEIGHT * progress)
		var tread_position := start + direction * run * (float(index) + 0.5)
		tread_position.y = top_y - 0.07
		_add_visual(_stairs, tread_position, Vector3(3.8, 0.14, run + 0.05))
		if goes_up or index > 0:
			var riser_position := start + direction * run * float(index)
			riser_position.y = top_y + (-rise * 0.5 if goes_up else rise * 0.5)
			_add_visual(_stairs, riser_position, Vector3(3.8, rise, 0.12))

	var vertical := LEVEL_HEIGHT if goes_up else -LEVEL_HEIGHT
	var ramp_length := Vector2(total_run, LEVEL_HEIGHT).length()
	var ramp_center := start + direction * total_run * 0.5 + Vector3.UP * vertical * 0.5
	var angle := -atan2(vertical, total_run)
	var ramp_basis := Basis(Vector3.RIGHT, angle).scaled(Vector3(3.96, 0.18, ramp_length))
	_collisions.append(Transform3D(ramp_basis, ramp_center))

	# Visible structural stringers and handrails follow the exact stair slope.
	for side: float in [-1.0, 1.0]:
		var stringer_center := ramp_center + Vector3(side * 1.82, -0.24, 0)
		var stringer_basis := Basis(Vector3.RIGHT, angle).scaled(Vector3(0.16, 0.28, ramp_length))
		_add_visual_transform(_wood, Transform3D(stringer_basis, stringer_center))
		var handrail_center := ramp_center + Vector3(side * 2.0, 1.05, 0)
		var handrail_basis := Basis(Vector3.RIGHT, angle).scaled(Vector3(0.12, 0.12, ramp_length + 0.2))
		_add_visual_transform(_wood, Transform3D(handrail_basis, handrail_center))

	for post_index in range(0, count + 1, 4):
		var clamped_index := mini(post_index, count)
		var post_progress := float(clamped_index) / float(count)
		var post_top_y := start.y + (LEVEL_HEIGHT * post_progress if goes_up else -LEVEL_HEIGHT * post_progress)
		var post_position := start + direction * run * float(clamped_index)
		post_position.y = post_top_y + 0.55
		for side: float in [-1.0, 1.0]:
			_add_visual(_wood, post_position + Vector3(side * 2.0, 0, 0), Vector3(0.14, 1.1, 0.14))


func _add_wall_with_openings(center: Vector3, length: float, along_x: bool, openings: Array) -> void:
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["offset"]) < float(b["offset"]))
	var cursor := -length * 0.5
	for opening: Dictionary in sorted:
		var kind := str(opening["type"])
		var width := DOOR_WIDTH if kind == "door" else WINDOW_WIDTH
		var opening_center := float(opening["offset"])
		var opening_start := opening_center - width * 0.5
		if opening_start > cursor:
			_add_wall_piece(_offset(center, (cursor + opening_start) * 0.5, along_x), _wall_size(opening_start - cursor, WALL_HEIGHT, along_x))
		_add_opening_structure(_offset(center, opening_center, along_x), width, along_x, kind)
		cursor = opening_center + width * 0.5
	if cursor < length * 0.5:
		_add_wall_piece(_offset(center, (cursor + length * 0.5) * 0.5, along_x), _wall_size(length * 0.5 - cursor, WALL_HEIGHT, along_x))


func _add_opening_structure(center: Vector3, width: float, along_x: bool, kind: String) -> void:
	var floor_y := center.y - WALL_HEIGHT * 0.5
	if kind == "door":
		var lintel_height := WALL_HEIGHT - DOOR_HEIGHT
		_add_wall_piece(Vector3(center.x, floor_y + DOOR_HEIGHT + lintel_height * 0.5, center.z), _wall_size(width, lintel_height, along_x), false)
		var rotation_y := 0.0 if along_x else PI * 0.5
		_doors.append(Transform3D(Basis(Vector3.UP, rotation_y), Vector3(center.x, floor_y, center.z)))
		return
	_add_wall_piece(Vector3(center.x, floor_y + WINDOW_BOTTOM * 0.5, center.z), _wall_size(width, WINDOW_BOTTOM, along_x), false)
	var top_height := WALL_HEIGHT - WINDOW_TOP
	_add_wall_piece(Vector3(center.x, floor_y + WINDOW_TOP + top_height * 0.5, center.z), _wall_size(width, top_height, along_x), false)
	var glass_size := _wall_size(width - 0.12, WINDOW_TOP - WINDOW_BOTTOM, along_x)
	if along_x:
		glass_size.z = 0.035
	else:
		glass_size.x = 0.035
	var glass_transform := Transform3D(Basis().scaled(glass_size), Vector3(center.x, floor_y + (WINDOW_BOTTOM + WINDOW_TOP) * 0.5, center.z))
	_glass.append(glass_transform)
	_collisions.append(glass_transform)
	_add_window_frame(Vector3(center.x, floor_y + (WINDOW_BOTTOM + WINDOW_TOP) * 0.5, center.z), width, WINDOW_TOP - WINDOW_BOTTOM, along_x)


func _add_window_frame(center: Vector3, width: float, height: float, along_x: bool) -> void:
	_add_visual(_wood, Vector3(center.x, center.y - height * 0.5, center.z), _wall_size(width, 0.09, along_x))
	_add_visual(_wood, Vector3(center.x, center.y + height * 0.5, center.z), _wall_size(width, 0.09, along_x))
	_add_visual(_wood, center, _wall_size(0.09, height, along_x))


func _place_light_markers() -> void:
	var levels: Array[float] = [-LEVEL_HEIGHT, 0.0, LEVEL_HEIGHT]
	var fixture_points: Array[Vector2] = [Vector2(0, -10), Vector2(0, 1), Vector2(0, 12), Vector2(-11, -9), Vector2(11, 9)]
	for floor_y: float in levels:
		for fixture_point: Vector2 in fixture_points:
			_lights.append(Vector3(fixture_point.x, floor_y + 3.45, fixture_point.y))
			_add_visual(_fixtures, Vector3(fixture_point.x, floor_y + 3.9, fixture_point.y), Vector3(1.35, 0.08, 0.42))


func _place_props() -> void:
	_spawn_prop(SofaScene, Vector3(-13, 0, -11), 0.25)
	_spawn_prop(TableScene, Vector3(-10, 0, -8), 0.0)
	_spawn_prop(ChairScene, Vector3(-8, 0, -9), -1.1)
	_spawn_prop(ShelfScene, Vector3(15.8, 0, 10), PI)
	_spawn_prop(BedScene, Vector3(11, 0, 10), PI * 0.5)
	_spawn_prop(RugScene, Vector3(0, 0.01, 1), 0.0)
	_spawn_prop(BedScene, Vector3(-12, LEVEL_HEIGHT, -10), 0.0)
	_spawn_prop(BedScene, Vector3(11, LEVEL_HEIGHT, 10), PI)
	_spawn_prop(ShelfScene, Vector3(-15.5, LEVEL_HEIGHT, 10), 0.0)
	_spawn_prop(ChairScene, Vector3(10, LEVEL_HEIGHT, 7), 1.4)
	_spawn_prop(BarrelScene, Vector3(-14, -LEVEL_HEIGHT, -11), 0.0)
	_spawn_prop(CrateScene, Vector3(-11, -LEVEL_HEIGHT, -9), 0.4)
	_spawn_prop(CrateScene, Vector3(-10, -LEVEL_HEIGHT, -8), -0.2)
	_spawn_prop(TrashScene, Vector3(14, -LEVEL_HEIGHT, 11), 0.0)
	_spawn_prop(ShelfScene, Vector3(15.5, -LEVEL_HEIGHT, -10), PI)
	_spawn_prop(BottleScene, Vector3(-1.2, 0, 8.0), 0.6)
	_spawn_prop(CanScene, Vector3(9.5, 0, 8.0), -0.8)
	_spawn_prop(BottleScene, Vector3(-13, LEVEL_HEIGHT, 5), 1.0)
	_spawn_prop(CanScene, Vector3(12, -LEVEL_HEIGHT, -9), 0.4)


func _spawn_prop(scene: PackedScene, world_position: Vector3, rotation_y: float) -> void:
	var instance := scene.instantiate() as Node3D
	instance.position = world_position
	instance.rotation.y = rotation_y
	add_child(instance)


func _add_solid(target: Array[Transform3D], world_position: Vector3, size: Vector3) -> void:
	var box_transform := Transform3D(Basis().scaled(size), world_position)
	target.append(box_transform)
	_collisions.append(box_transform)


func _add_visual(target: Array[Transform3D], world_position: Vector3, size: Vector3) -> void:
	target.append(Transform3D(Basis().scaled(size), world_position))


func _add_visual_transform(target: Array[Transform3D], visual_transform: Transform3D) -> void:
	target.append(visual_transform)


func _add_wall_piece(center: Vector3, size: Vector3, add_trim := true) -> void:
	_add_solid(_walls, center, size)
	if not add_trim:
		return
	var trim_size := size
	if size.x < size.z:
		trim_size.x = 0.27
	else:
		trim_size.z = 0.27
	trim_size.y = 0.24
	var base_y := center.y - size.y * 0.5
	_add_visual(_wood, Vector3(center.x, base_y + 0.12, center.z), trim_size)


func _wall_size(length: float, height: float, along_x: bool) -> Vector3:
	return Vector3(length, height, WALL_THICKNESS) if along_x else Vector3(WALL_THICKNESS, height, length)


func _offset(center: Vector3, amount: float, along_x: bool) -> Vector3:
	return center + (Vector3(amount, 0, 0) if along_x else Vector3(0, 0, amount))


func _create_render_batches() -> void:
	_create_multimesh("Floors", _floors, _textured_material(FloorTexture, Color(0.43, 0.42, 0.38), 3.2))
	_create_multimesh("Ceilings", _ceilings, _textured_material(CeilingTexture, Color(0.5, 0.49, 0.45), 2.5))
	_create_multimesh("Walls", _walls, _textured_material(WallTexture, Color(0.56, 0.54, 0.5), 2.0))
	_create_multimesh("WoodTrim", _wood, _textured_material(WoodTexture, Color(0.2, 0.14, 0.09), 1.5))
	_create_multimesh("Stairs", _stairs, _textured_material(WoodTexture, Color(0.62, 0.43, 0.24), 1.8))
	_create_multimesh("Glass", _glass, _glass_material())
	_create_multimesh("Fixtures", _fixtures, _emissive_material())


func _create_multimesh(node_name: String, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	add_child(instance)


func _create_collisions() -> void:
	var body := StaticBody3D.new()
	body.name = "HouseCollisions"
	add_child(body)
	for box_transform in _collisions:
		var shape := BoxShape3D.new()
		shape.size = box_transform.basis.get_scale()
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = Transform3D(box_transform.basis.orthonormalized(), box_transform.origin)
		body.add_child(collision)


func _create_doors() -> void:
	for index in _doors.size():
		var door := DoorScene.instantiate() as Node3D
		door.name = "PushDoor%02d" % index
		door.transform = _doors[index]
		add_child(door)


func _create_lights() -> void:
	for index in _lights.size():
		var light := OmniLight3D.new()
		light.name = "HouseLight%02d" % index
		light.position = _lights[index]
		light.light_color = Color(1.0, 0.69, 0.37)
		light.light_energy = 1.8 if index % 4 else 2.35
		light.omni_range = 7.2
		light.omni_attenuation = 1.55
		light.shadow_enabled = false
		add_child(light)


func _textured_material(texture: Texture2D, tint: Color, uv_scale: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.texture_repeat = true
	material.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.roughness = 0.94
	return material


func _glass_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.12, 0.19, 0.24, 0.3)
	material.metallic = 0.3
	material.roughness = 0.12
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _emissive_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.78, 0.42)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.58, 0.2)
	material.emission_energy_multiplier = 3.2
	return material
