extends MeshInstance3D
## A single indexed skin from the torso to the wrist. Adjacent sections share
## their elbow ring, so rotating the rig cannot open a seam between cylinders.
const SIDES := 12
const RINGS := 9
var shoulder: Node3D
var elbow: Node3D
var wrist: Node3D
var palm: MeshInstance3D
var mount := Vector3.ZERO
var thickness_scale := 1.0
var _last_thickness_scale := -1.0
var _skin: Material
var _cloth: Material
var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _uvs := PackedVector2Array()
var _skin_indices := PackedInt32Array()
var _cloth_indices := PackedInt32Array()
var _last_points := PackedVector3Array()
var _radii := PackedFloat32Array([0.48, 0.43, 0.34, 0.29, 0.28, 0.275, 0.24, 0.19, 0.17])
var _cosines := PackedFloat64Array()
var _sines := PackedFloat64Array()

func configure(upper: Node3D, joint: Node3D, hand: Node3D, torso: MeshInstance3D, skin: Material) -> void:
	shoulder = upper
	elbow = joint
	wrist = hand
	for child in wrist.get_children():
		if child is MeshInstance3D and str(child.name).ends_with("Palm"):
			palm = child
	_skin = skin
	_cloth = torso.get_active_material(0)
	var origin := to_local(shoulder.global_position)
	var torso_center := to_local(torso.to_global(torso.get_aabb().get_center()))
	# Embed the upper ring inside the chest. This mount belongs to the torso,
	# not the shoulder, and cannot peel away when the arm is raised.
	mount = Vector3(lerpf(origin.x, torso_center.x, 0.48), origin.y - 0.12, lerpf(origin.z, torso_center.z, 0.6))
	_vertices.resize(RINGS * SIDES)
	_normals.resize(RINGS * SIDES)
	_uvs.resize(RINGS * SIDES)
	# Las secciones conservan UV y ángulos durante toda la animación.
	# Float64 evita redondear los resultados de sin/cos antes de usarlos.
	_cosines.resize(SIDES)
	_sines.resize(SIDES)
	for side in SIDES:
		var angle := TAU * float(side) / SIDES
		_cosines[side] = cos(angle)
		_sines[side] = sin(angle)
	for ring in RINGS:
		for side in SIDES:
			_uvs[ring * SIDES + side] = Vector2(float(side) / SIDES, float(ring) / (RINGS - 1))
	for ring in RINGS - 1:
		for side in SIDES:
			var a := ring * SIDES + side
			var b := ring * SIDES + (side + 1) % SIDES
			var c := a + SIDES
			var d := b + SIDES
			# Godot front faces use clockwise winding.
			var triangles := PackedInt32Array([a, c, b, b, c, d])
			if ring < 2:
				_cloth_indices.append_array(triangles)
			else:
				_skin_indices.append_array(triangles)
	mesh = ArrayMesh.new()
	update_surface()

func update_surface() -> void:
	var upper := to_local(shoulder.global_position)
	var joint := to_local(elbow.global_position)
	var hand := to_local(wrist.global_position)
	var palm_center := hand + (hand - joint).normalized() * 0.12
	if is_instance_valid(palm):
		palm_center = to_local(palm.to_global(palm.get_aabb().get_center()))
	var points := PackedVector3Array([
		mount, upper, upper.lerp(joint, 0.25), upper.lerp(joint, 0.72),
		joint, joint.lerp(hand, 0.22), joint.lerp(hand, 0.58), hand,
		palm_center,
	])
	if points == _last_points and is_equal_approx(thickness_scale, _last_thickness_scale):
		return
	_last_points = points
	_last_thickness_scale = thickness_scale
	var radial := Vector3.FORWARD
	for ring in RINGS:
		var before := points[maxi(0, ring - 1)]
		var after := points[mini(RINGS - 1, ring + 1)]
		var tangent := (after - before).normalized()
		radial = radial - tangent * radial.dot(tangent)
		if radial.length_squared() < 0.001:
			radial = tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT)
		radial = radial.normalized()
		var second := tangent.cross(radial).normalized()
		# El estrechamiento es común a todo el anillo, no a cada vértice.
		var taper := lerpf(1.0, thickness_scale, 1.0 if ring in [2, 3, 4, 5, 6] else 0.45 if ring == 1 else 0.0)
		for side in SIDES:
			var normal := radial * _cosines[side] + second * _sines[side]
			var index := ring * SIDES + side
			# Preserve the torso mount and palm closure; taper only the limb shaft.
			_vertices[index] = points[ring] + normal * _radii[ring] * taper
			_normals[index] = normal
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	var surface := mesh as ArrayMesh
	surface.clear_surfaces()
	arrays[Mesh.ARRAY_INDEX] = _cloth_indices
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	surface.surface_set_material(0, _cloth)
	arrays[Mesh.ARRAY_INDEX] = _skin_indices
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	surface.surface_set_material(1, _skin)
