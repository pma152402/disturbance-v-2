extends SceneTree
## Check the visible envelope separately from the physics envelope, including
## millimetre offsets at every structural edge, not just player-sized openings.
const VISUAL_LAYER := 1 << 18
var house: Node3D
var space: PhysicsDirectSpaceState3D
var mesh_bounds: Array[AABB] = []
var solid_boxes: Array = []
var failures: Array = []
var samples := 0

func _initialize() -> void: call_deferred("run")

func run() -> void:
	house = load("res://levels/house_baked.tscn").instantiate()
	_strip_scripts(house)
	root.add_child(house)
	var proxies := Node3D.new()
	root.add_child(proxies)
	var inventory: Array = []
	var all_faces := PackedVector3Array()
	for visual in house.find_children("*","MeshInstance3D",true,false):
		if not visual.is_visible_in_tree() or visual.mesh == null: continue
		var bounds: AABB = visual.global_transform*visual.get_aabb()
		if not bounds.intersects(AABB(Vector3(-34,-0.5,-18),Vector3(21,14,24))): continue
		var faces: PackedVector3Array = visual.mesh.get_faces()
		for i in faces.size(): faces[i] = visual.global_transform*faces[i]
		all_faces.append_array(faces)
		if visual.mesh is BoxMesh: solid_boxes.append([bounds,visual.global_transform.affine_inverse(),visual.get_aabb()])
		if bounds.size.length() > 2.5:
			mesh_bounds.append(bounds)
			inventory.append({"path":str(house.get_path_to(visual)),"position":str(bounds.position),"end":str(bounds.end)})
	FileAccess.open("res://tools/output/school_shell_inventory.json",FileAccess.WRITE).store_string(JSON.stringify(inventory,"\t"))
	var body := StaticBody3D.new()
	body.collision_layer = VISUAL_LAYER
	body.collision_mask = 0
	proxies.add_child(body)
	var shape := CollisionShape3D.new()
	shape.shape = ConcavePolygonShape3D.new()
	shape.shape.set_faces(all_faces)
	shape.shape.backface_collision = true
	body.add_child(shape)
	print("SHELL VISUAL TRIANGLES ",all_faces.size()/3)
	await physics_frame
	await physics_frame
	space = house.get_world_3d().direct_space_state
	for storey in 3:
		var base: float = [0.0,4.16,8.4][storey]
		var height: float = [4.16,4.24,4.16][storey]
		# axis: 0 means X varies, 2 means Z varies. Perimeter of the union
		# of the school wings. The east bridge and street doorway are deliberate.
		var edges := [[2,-30.15,-17.3,-14.1],[2,-30.15,-2.9,3.79],[0,-14.1,-33.6,-30.15],[0,-2.9,-33.6,-30.15],[2,-33.6,-14.1,-2.9],[0,-17.3,-30.15,-26.55],[2,-26.55,-17.3,-13.94],[0,-13.94,-26.55,-14.35],[2,-14.35,-13.94,-1.88],[0,-1.88,-15.04,-14.35],[2,-15.04,-1.88,5.1],[0,5.1,-22.54,-15.04],[2,-22.54,-1.88,5.1],[0,-1.88,-26.55,-22.54],[2,-26.55,-1.88,3.79],[0,3.79,-30.15,-26.55]]
		if storey==0: edges[8][3] = -6.03 # Ground corridor continues east into the house.
		for i in edges.size(): _edge(storey,base,height,i,edges[i])
		if storey>0:
			for corner in [[-33.6,-14.1,-1,-1],[-33.6,-2.9,-1,1],[-30.15,-17.3,-1,-1],[-26.55,-17.3,1,-1],[-14.35,-13.94,1,-1],[-14.35,-1.88,1,1],[-15.04,5.1,1,1],[-22.54,5.1,-1,1],[-30.15,3.79,-1,1],[-26.55,3.79,1,1]]:
				for y in [0.5,1.8,3.2]:
					var point := Vector3(corner[0]+corner[2]*0.099,base+y,corner[1]+corner[3]*0.099)
					samples += 2
					if not _inside_visual_box(point) or not _inside_physics(point): failures.append({"corner":str(point),"mesh":_inside_visual_box(point),"physics":_inside_physics(point)})
	var report := {"samples":samples,"failures":failures}
	FileAccess.open("res://tools/output/school_shell_audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	for failure in failures: print("SHELL GAP ",failure)
	print("SCHOOL SHELL: ",samples," probes, ",failures.size()," defective edge/height pairs")
	quit(0 if failures.is_empty() else 1)

func _strip_scripts(node: Node) -> void:
	for child_ in node.get_children(): _strip_scripts(child_)
	node.set_script(null)

func _edge(storey: int, base: float, height: float, index: int, edge: Array) -> void:
	var axis: int = edge[0]
	var fixed: float = edge[1]
	var a: float = edge[2]
	var b: float = edge[3]
	var positions: Array[float] = [a+0.001,b-0.001]
	for step in ceili((b-a)/0.1): positions.append(minf(b-0.001,a+0.025+step*0.1))
	for bounds in mesh_bounds:
		for point in [bounds.position[axis],bounds.end[axis]]:
			if point>a and point<b:
				positions.append(maxf(a+0.001,point-0.001))
				positions.append(minf(b-0.001,point+0.001))
	var levels: Array[float] = [0.001,0.05,0.5,1.099,1.101,1.8,2.899,2.901,3.2,3.8,3.999,height-0.001]
	for bounds in mesh_bounds:
		for y in [bounds.position.y,bounds.end.y]:
			if y>base and y<base+height:
				levels.append(clampf(y-base-0.001,0.001,height-0.001))
				levels.append(clampf(y-base+0.001,0.001,height-0.001))
	# Quantize duplicates for fast dense seam coverage.
	var us := {}; var ys := {}
	for u in positions: us[roundi(u*1000)] = u
	for y in levels: ys[roundi(y*1000)] = y
	for y in ys.values():
		var misses := [0,0]
		var first := [Vector3.ZERO,Vector3.ZERO]
		for u in us.values():
			if storey==1 and index==8 and u > -5.35 and u < -2.65 and y<2.94: continue
			if storey==0 and index==5 and u > -29.7 and u < -27.0 and y<2.94: continue
			var p := Vector3(u,base+y,fixed) if axis==0 else Vector3(fixed,base+y,u)
			var normal := Vector3(0,0,0.45) if axis==0 else Vector3(0.45,0,0)
			for kind in 2:
				var q := PhysicsRayQueryParameters3D.create(p-normal,p+normal,1 if kind==0 else VISUAL_LAYER)
				q.hit_back_faces = true
				q.hit_from_inside = true
				samples += 1
				if space.intersect_ray(q).is_empty():
					if kind==1 and _inside_visual_box(p): continue
					if kind==0 and _inside_physics(p): continue
					misses[kind] += 1
					if misses[kind]==1: first[kind] = p
		if misses[0] or misses[1]: failures.append({"floor":storey,"edge":index,"y":snappedf(base+y,0.001),"collision_misses":misses[0],"mesh_misses":misses[1],"first_collision":str(first[0]),"first_mesh":str(first[1])})

func _inside_visual_box(p: Vector3) -> bool:
	for box_ in solid_boxes:
		if box_[0].grow(0.00002).has_point(p) and box_[2].grow(0.00002).has_point(box_[1]*p): return true
	return false

func _inside_physics(p: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE*0.00004
	q.shape = shape
	q.collision_mask = 1
	q.transform.origin = p
	return not space.intersect_shape(q,1).is_empty()
