@tool
extends Node3D
## Shared editor-visible case, replacement lens and spherical left hand.

func _ready() -> void:
	build_case(self)

static func material(color: Color, metal := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metal
	result.roughness = 0.38 if metal > 0.0 else 0.8
	return result

static func box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	return part(parent, mesh, at)

static func part(parent: Node3D, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = mesh
	result.position = at
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(result)
	return result

static func build_case(parent: Node3D) -> void:
	var shell := material(Color(0.16, 0.23, 0.22))
	var dark := material(Color(0.018, 0.026, 0.026))
	var brass := material(Color(0.69, 0.52, 0.25), 0.7)
	box(parent, Vector3(0.26, 0.085, 0.18), Vector3(0, 0.043, 0), shell)
	box(parent, Vector3(0.265, 0.025, 0.185), Vector3(0, 0.096, 0), dark)
	for x in [-0.082, 0.082]:
		box(parent, Vector3(0.027, 0.03, 0.009), Vector3(x, 0.084, 0.096), brass)
	box(parent, Vector3(0.095, 0.012, 0.021), Vector3(0, 0.059, 0.112), dark)
	var label := Label3D.new()
	label.text = "KIT DE REPARACION\nLENTE  •  CAMARA"
	label.font_size = 34
	label.pixel_size = 0.00065
	label.modulate = Color(0.9, 0.83, 0.61)
	label.outline_size = 0
	label.position = Vector3(0, 0.111, 0)
	label.rotation.x = -PI / 2.0
	parent.add_child(label)

static func build_lens(parent: Node3D, damaged := false) -> Node3D:
	var lens := Node3D.new()
	parent.add_child(lens)
	var black := material(Color(0.028, 0.032, 0.035), 0.55)
	var silver := material(Color(0.48, 0.5, 0.49), 0.9)
	var glass := material(Color(0.16, 0.24, 0.2) if damaged else Color(0.08, 0.3, 0.46), 0.7)
	for ring in 4:
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.049
		mesh.outer_radius = 0.068 if ring % 2 == 0 else 0.064
		mesh.rings = 24
		mesh.ring_segments = 8
		mesh.material = silver if ring == 3 else black
		var node := part(lens, mesh, Vector3(0, 0, ring * 0.014))
		node.rotation.x = PI / 2.0
	var disc := CylinderMesh.new()
	disc.top_radius = 0.049
	disc.bottom_radius = 0.049
	disc.height = 0.004
	disc.material = glass
	part(lens, disc, Vector3(0, 0, 0.018)).rotation.x = PI / 2.0
	# White index mark makes the screw rotation readable, even in monochrome.
	box(lens, Vector3(0.007, 0.012, 0.035), Vector3(0, 0.06, 0.02), silver)
	if damaged:
		for i in 3:
			var crack := box(lens, Vector3(0.002, 0.073, 0.001), Vector3(i * 0.008 - 0.008, 0, 0.022), silver)
			crack.rotation.z = -0.65 + i * 0.55
	return lens

static func build_left_hand(parent: Node3D, skin: Material) -> Node3D:
	var hand := Node3D.new()
	hand.name = "LeftRepairHand"
	parent.add_child(hand)
	var ball := SphereMesh.new()
	ball.radius = 0.06
	ball.height = 0.12
	ball.radial_segments = 12
	ball.rings = 6
	ball.material = skin
	part(hand, ball, Vector3.ZERO).name = "HandBall"
	return hand
