extends RefCounted
## Offline geometry helpers. Coordinates shared by meshes and colliders.

static func relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current is Node3D and current != root:
		result = current.transform*result
		current = current.get_parent()
	return result

static func stitch(root: Node3D) -> void:
	for category in ["Wall", "Frame"]:
		var parts: Array = []
		for mesh in root.find_children("*","MeshInstance3D",true,false):
			if not mesh.mesh is BoxMesh or not str(mesh.name).begins_with(category+"Part"): continue
			var bounds: AABB = relative_transform(mesh,root)*mesh.get_aabb()
			if category=="Frame" and absf(bounds.size.y-0.2)>0.001: continue
			if minf(bounds.size.x,bounds.size.z)>0.241: continue
			parts.append([mesh,bounds,0 if bounds.size.z<bounds.size.x else 2])
		for part in parts:
			var bounds: AABB = part[1]
			var axis: int = part[2]
			var cross_axis := 2 if axis==0 else 0
			var start := bounds.position[axis]
			var finish := bounds.end[axis]
			for end_index in 2:
				var point := start if end_index==0 else finish
				if _continues(parts,part,point): continue
				for other in parts:
					if other[2]==axis: continue
					var ob: AABB = other[1]
					if minf(bounds.end.y,ob.end.y)-maxf(bounds.position.y,ob.position.y)<0.01: continue
					if absf(ob.get_center()[axis]-point)>0.001: continue
					var across := bounds.get_center()[cross_axis]
					if across<ob.position[cross_axis]-0.001 or across>ob.end[cross_axis]+0.001: continue
					var corner := (absf(across-ob.position[cross_axis])<0.001 or absf(across-ob.end[cross_axis])<0.001) and not _continues(parts,other,across)
					var amount := ob.size[axis]/2
					# Horizontal walls own L corners. Vertical walls butt into them;
					# either orientation stops at the near face of a T junction.
					var extend := axis==0 and corner
					if end_index==0: start = point+(-amount if extend else amount)
					else: finish = point+(amount if extend else -amount)
					break
			var p := bounds.position
			var size := bounds.size
			p[axis] = start
			size[axis] = finish-start
			if size[axis]<=0.001: continue
			var mesh: MeshInstance3D = part[0]
			mesh.mesh = mesh.mesh.duplicate()
			mesh.mesh.size = size
			mesh.transform = relative_transform(mesh.get_parent(),root).affine_inverse()*Transform3D(Basis.IDENTITY,p+size/2)
			if category=="Wall":
				var collider := mesh.get_parent().get_node_or_null("Collision") as CollisionShape3D
				if collider:
					collider.shape = collider.shape.duplicate()
					collider.shape.size = size
					collider.transform = mesh.transform

static func _continues(parts: Array, part: Array, point: float) -> bool:
	var bounds: AABB = part[1]
	var axis: int = part[2]
	var cross_axis := 2 if axis==0 else 0
	for candidate in parts:
		if candidate[0]==part[0] or candidate[2]!=axis: continue
		var other: AABB = candidate[1]
		if absf(other.get_center()[cross_axis]-bounds.get_center()[cross_axis])>0.001: continue
		if minf(bounds.end.y,other.end.y)-maxf(bounds.position.y,other.position.y)<0.01: continue
		if absf(point-bounds.position[axis])<0.001 and absf(point-other.end[axis])<0.001: return true
		if absf(point-bounds.end[axis])<0.001 and absf(point-other.position[axis])<0.001: return true
	return false

static func rect_union(rects: Array[Rect2], subtract: Array[Rect2] = []) -> Array[Rect2]:
	var xs := {}; var zs := {}
	for rect in rects+subtract:
		for x in [rect.position.x,rect.end.x]: xs[roundi(x*10000)] = snappedf(x,0.0001)
		for z in [rect.position.y,rect.end.y]: zs[roundi(z*10000)] = snappedf(z,0.0001)
	var xx := xs.values(); xx.sort()
	var zz := zs.values(); zz.sort()
	var cells := {}
	for x in xx.size()-1:
		for z in zz.size()-1:
			var center := Vector2((xx[x]+xx[x+1])/2,(zz[z]+zz[z+1])/2)
			var covered := false
			for rect in rects: covered = covered or rect.has_point(center)
			for rect in subtract: if rect.has_point(center): covered = false
			if covered: cells[Vector2i(x,z)] = true
	var result: Array[Rect2] = []
	for z in zz.size()-1:
		for x in xx.size()-1:
			if not cells.has(Vector2i(x,z)): continue
			var end_x := x+1
			while cells.has(Vector2i(end_x,z)): end_x += 1
			var end_z := z+1
			while end_z<zz.size()-1:
				var full := true
				for col in range(x,end_x): full = full and cells.has(Vector2i(col,end_z))
				if not full: break
				end_z += 1
			for col in range(x,end_x):
				for row in range(z,end_z): cells.erase(Vector2i(col,row))
			result.append(Rect2(xx[x],zz[z],xx[end_x]-xx[x],zz[end_z]-zz[z]))
	return result
