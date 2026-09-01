import bmesh
import bpy
from collections import deque
from pathlib import Path


PROJECT = Path(r"C:\Users\papar\Desktop\disturbance-v-2")
MODEL = PROJECT / "characters" / "granny_editable" / "granny_editable_rig.glb"


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(MODEL))

total_boundary_edges = 0
for obj in sorted((item for item in bpy.context.scene.objects if item.type == "MESH"), key=lambda item: item.name):
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    mesh.verts.ensure_lookup_table()
    mesh.edges.ensure_lookup_table()
    bmesh.ops.remove_doubles(mesh, verts=list(mesh.verts), dist=0.0001)
    mesh.verts.ensure_lookup_table()
    mesh.edges.ensure_lookup_table()
    boundary_edges = [edge for edge in mesh.edges if edge.is_boundary]
    if not boundary_edges:
        mesh.free()
        continue

    total_boundary_edges += len(boundary_edges)
    edge_set = set(boundary_edges)
    loops = []
    while edge_set:
        seed = edge_set.pop()
        component = [seed]
        queue = deque(seed.verts)
        seen_vertices = set(seed.verts)
        while queue:
            vertex = queue.popleft()
            for edge in vertex.link_edges:
                if edge not in edge_set:
                    continue
                edge_set.remove(edge)
                component.append(edge)
                for linked_vertex in edge.verts:
                    if linked_vertex not in seen_vertices:
                        seen_vertices.add(linked_vertex)
                        queue.append(linked_vertex)
        points = [obj.matrix_world @ vertex.co for vertex in seen_vertices]
        loops.append(
            {
                "edges": len(component),
                "min": tuple(round(min(point[index] for point in points), 3) for index in range(3)),
                "max": tuple(round(max(point[index] for point in points), 3) for index in range(3)),
                "center": tuple(round(sum(point[index] for point in points) / len(points), 3) for index in range(3)),
            }
        )

    print(f"MESH {obj.name}: {len(boundary_edges)} boundary edges, {len(loops)} open regions")
    for index, loop in enumerate(sorted(loops, key=lambda item: item["center"][2], reverse=True), start=1):
        print(f"  REGION {index}: {loop}")
    mesh.free()

print(f"TOTAL_BOUNDARY_EDGES {total_boundary_edges}")
