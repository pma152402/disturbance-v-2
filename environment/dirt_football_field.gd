extends Node3D
## Geometría persistente y editable. Solo el horneador llama a rebuild_surface().
const W := 9.0
const L := 15.0
const T := 0.085
const R := 2.72
var chalk: StandardMaterial3D

func rebuild_surface() -> void:
	var old := get_node("Generated")
	var goals := Node3D.new()
	goals.name = "Goals"
	add_child(goals)
	for label in ["NorthGoal", "SouthGoal"]:
		old.get_node(label).owner = null
		old.get_node(label).reparent(goals, false)
	old.free()
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.24, 0.17, 0.105)
	soil.roughness = 1.0
	var noise := FastNoiseLite.new()
	noise.seed = 844291
	noise.frequency = 0.16
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.58, 0.51, 0.41))
	ramp.set_color(1, Color(1.0, 0.94, 0.82))
	texture.color_ramp = ramp
	soil.albedo_texture = texture
	soil.uv1_scale = Vector3(3, 5, 1)
	var ground := Node3D.new()
	ground.name = "Ground"
	add_child(ground)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(21.2, 0.12, 34)
	var surface := piece(ground, "DirtSurface", mesh, soil)
	surface.position.y = -0.06
	var body := StaticBody3D.new()
	body.name = "FieldCollision"
	ground.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "GroundShape"
	var box := BoxShape3D.new()
	box.size = mesh.size
	shape.shape = box
	shape.position = surface.position
	body.add_child(shape)
	chalk = StandardMaterial3D.new()
	chalk.albedo_color = Color(0.82, 0.79, 0.65)
	chalk.roughness = 1.0
	var lines := Node3D.new()
	lines.name = "Markings"
	add_child(lines)
	line(lines, "WestTouchline", Vector2(-W,-L), Vector2(-W,L))
	line(lines, "EastTouchline", Vector2(W,-L), Vector2(W,L))
	line(lines, "NorthGoalLine", Vector2(-W,-L), Vector2(W,-L))
	line(lines, "SouthGoalLine", Vector2(-W,L), Vector2(W,L))
	line(lines, "HalfwayLine", Vector2(-W,0), Vector2(W,0))
	arc(lines, "CenterCircle", Vector2.ZERO, R, 0, TAU)
	spot(lines, "CenterSpot", Vector2.ZERO)
	for s: float in [-1.0, 1.0]:
		var end := Node3D.new()
		end.name = "NorthEnd" if s < 0 else "SouthEnd"
		lines.add_child(end)
		area(end, "PenaltyArea", 5.5, 4.8, s)
		area(end, "GoalArea", 3.55, 1.75, s)
		var center := Vector2(0, s * (L - 3.55))
		spot(end, "PenaltySpot", center)
		# Intersección exacta con la línea frontal del área.
		var alpha := asin((4.8 - 3.55) / R)
		var start := alpha if s < 0 else PI + alpha
		arc(end, "PenaltyArc", center, R, start, start + PI - 2 * alpha)
		for side: float in [-1.0, 1.0]:
			var angle := 0.0 if side < 0 else PI / 2
			if s > 0:
				angle = 3 * PI / 2 if side < 0 else PI
			arc(end, "WestCorner" if side < 0 else "EastCorner", Vector2(side * W, s * L), 0.72, angle, angle + PI / 2)

func piece(parent: Node, label: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	item.mesh = mesh
	item.material_override = material
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)
	return item

func line(parent: Node, label: String, a: Vector2, b: Vector2) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(a.distance_to(b), 0.004, T)
	var item := piece(parent, label, mesh, chalk)
	item.position = Vector3((a.x+b.x)/2, 0.008, (a.y+b.y)/2)
	item.rotation.y = -atan2(b.y-a.y, b.x-a.x)

func area(parent: Node, label: String, width: float, depth: float, s: float) -> void:
	var group := Node3D.new()
	group.name = label
	parent.add_child(group)
	var back := s * L
	var front := s * (L-depth)
	line(group, "WestSide", Vector2(-width,back), Vector2(-width,front))
	line(group, "Front", Vector2(-width,front), Vector2(width,front))
	line(group, "EastSide", Vector2(width,front), Vector2(width,back))

func spot(parent: Node, label: String, center: Vector2) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.11
	mesh.bottom_radius = 0.11
	mesh.height = 0.004
	mesh.radial_segments = 32
	piece(parent, label, mesh, chalk).position = Vector3(center.x,0.012,center.y)

func arc(parent: Node, label: String, center: Vector2, radius: float, start: float, finish: float) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var count := ceili((finish-start)/TAU*192)
	for i in count + 1:
		var angle := lerpf(start, finish, float(i)/count)
		for offset: float in [-T/2, T/2]:
			vertices.append(Vector3(cos(angle)*(radius+offset),0,sin(angle)*(radius+offset)))
			normals.append(Vector3.UP)
		if i < count:
			var b := i*2
			indices.append_array(PackedInt32Array([b,b+1,b+2,b+1,b+3,b+2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	piece(parent, label, mesh, chalk).position = Vector3(center.x,0.011,center.y)

## Añade desgaste sin reconstruir ni mover los nodos editados del campo.
func apply_weathering() -> void:
	if has_node("Weathering"):
		get_node("Weathering").free()
	var worn := ShaderMaterial.new()
	worn.shader = load("res://environment/football_worn_chalk.gdshader")
	for marking in get_node("Markings").find_children("*", "MeshInstance3D", true, false):
		marking.material_override = worn
	var weather := Node3D.new()
	weather.name = "Weathering"
	add_child(weather)
	var mud := StandardMaterial3D.new()
	mud.albedo_color = Color(0.13, 0.092, 0.056, 0.65)
	mud.vertex_color_use_as_albedo = true
	mud.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mud.roughness = 0.94
	var dust := mud.duplicate() as StandardMaterial3D
	dust.albedo_color = Color(0.34, 0.26, 0.16, 0.38)
	var water := ShaderMaterial.new()
	water.shader = load("res://environment/football_puddle.gdshader")
	var rng := RandomNumberGenerator.new()
	rng.seed = 837212
	# Desgaste amplio y suave en las bocas y el eje de juego.
	wear_patch(weather, "NorthGoalWear", Vector2(0,-13.6), Vector2(3.1,1.6), mud, rng, true, 0.003)
	wear_patch(weather, "SouthGoalWear", Vector2(0,13.4), Vector2(3.0,1.9), mud, rng, true, 0.003)
	wear_patch(weather, "CenterWear", Vector2(0.4,0.3), Vector2(3.5,2.7), dust, rng, true, 0.003)
	for i in 18:
		var pos := Vector2(rng.randf_range(-8,8), rng.randf_range(-14,14))
		wear_patch(weather, "ScuffedSoil%02d" % i, pos, Vector2(rng.randf_range(0.5,1.8),rng.randf_range(0.3,0.8)), mud if i % 3 == 0 else dust, rng, true, 0.0035 + i * 0.0001)
	var puddles := Node3D.new()
	puddles.name = "Puddles"
	weather.add_child(puddles)
	var positions := [Vector2(-5.8,7.4), Vector2(6.9,-7.5), Vector2(1.1,-13.9)]
	var sizes := [Vector2(1.65,0.8),Vector2(1.05,1.7),Vector2(0.95,0.45)]
	for i in positions.size():
		var group := Node3D.new()
		group.name = "Puddle%02d" % (i+1)
		puddles.add_child(group)
		group.position = Vector3(positions[i].x,0,positions[i].y)
		wear_patch(group, "WetSoilEdge", Vector2.ZERO, sizes[i]*1.35, mud, rng, true, 0.006)
		wear_patch(group, "Water", Vector2.ZERO, sizes[i], water, rng, false, 0.016)

func wear_patch(parent: Node, label: String, center: Vector2, size: Vector2, material: Material, rng: RandomNumberGenerator, feather: bool, height: float) -> void:
	var vertices := PackedVector3Array([Vector3.ZERO])
	var colors := PackedColorArray([Color.WHITE])
	var normals := PackedVector3Array([Vector3.UP])
	var indices := PackedInt32Array()
	var count := 48
	var phase := rng.randf_range(0,TAU)
	for ring in 2:
		for i in count:
			var angle := TAU * i / count
			var radius := 1.0 + 0.12*sin(angle*3+phase) + 0.07*cos(angle*7-phase)
			radius *= 0.65 if ring == 0 else 1.0
			vertices.append(Vector3(cos(angle)*size.x*radius,0,sin(angle)*size.y*radius))
			colors.append(Color(1,1,1,0 if feather and ring == 1 else 1))
			normals.append(Vector3.UP)
	for i in count:
		var a := 1+i
		var b := 1+(i+1)%count
		var c := a+count
		var d := b+count
		indices.append_array(PackedInt32Array([0,a,b,a,c,b,c,d,b]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	piece(parent,label,mesh,material).position = Vector3(center.x,height,center.y)
