import bmesh
import bpy
from collections import Counter
from mathutils import Vector
from pathlib import Path

PROJECT = Path(r"C:\Users\papar\Desktop\disturbance-v-2")
SOURCE = PROJECT / "granny_2_v1.3_model.glb"
OUTPUT_DIR = PROJECT / "characters" / "granny_editable"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT = OUTPUT_DIR / "granny_editable_rig.glb"
PREVIEW = Path.home() / "AppData" / "Local" / "Temp" / "granny_editable_preview.png"


def apply_armature_and_world_transform(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for modifier in list(obj.modifiers):
        if modifier.type == "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def dominant_category(obj: bpy.types.Object, vertex: bpy.types.MeshVertex) -> str:
    if not vertex.groups:
        return "body"
    dominant = max(vertex.groups, key=lambda link: link.weight)
    group_name = obj.vertex_groups[dominant.group].name
    if "Head" in group_name or "Neck" in group_name:
        return "head"
    if "LeftHand" in group_name:
        return "left_hand"
    if "LeftForeArm" in group_name:
        return "left_forearm"
    if "LeftArm" in group_name or "LeftShoulder" in group_name:
        return "left_upper"
    if "RightHand" in group_name:
        return "right_hand"
    if "RightForeArm" in group_name:
        return "right_forearm"
    if "RightArm" in group_name or "RightShoulder" in group_name:
        return "right_upper"
    return "body"


def duplicate_category(source: bpy.types.Object, category: str, name: str) -> bpy.types.Object:
    duplicate = source.copy()
    duplicate.data = source.data.copy()
    duplicate.name = name
    duplicate.data.name = f"{name}Mesh"
    bpy.context.collection.objects.link(duplicate)
    vertex_categories = {
        vertex.index: dominant_category(duplicate, vertex)
        for vertex in duplicate.data.vertices
    }
    keep_faces = set()
    for polygon in duplicate.data.polygons:
        face_categories = [vertex_categories[index] for index in polygon.vertices]
        counts = Counter(face_categories)
        face_category = counts.most_common(1)[0][0]
        coordinates = [duplicate.data.vertices[index].co for index in polygon.vertices]
        x_span = max(point.x for point in coordinates) - min(point.x for point in coordinates)
        center_x = sum(point.x for point in coordinates) / len(coordinates)
        center_y = sum(point.y for point in coordinates) / len(coordinates)
        center_z = sum(point.z for point in coordinates) / len(coordinates)
        if category in {"body", "head"}:
            face_is_valid = all(item == category for item in face_categories)
        elif category == "left_upper":
            face_is_valid = 2.35 <= center_x < 7.9 and 7.9 <= center_z <= 10.2 and abs(center_y) <= 1.55 and x_span <= 2.2
        elif category == "left_forearm":
            face_is_valid = 7.45 <= center_x < 14.25 and x_span <= 2.2
        elif category == "left_hand":
            face_is_valid = center_x >= 13.45 and x_span <= 2.2
        elif category == "right_upper":
            face_is_valid = -7.95 < center_x <= -2.35 and 7.9 <= center_z <= 10.2 and abs(center_y) <= 1.55 and x_span <= 2.2
        elif category == "right_forearm":
            face_is_valid = -14.3 < center_x <= -7.45 and x_span <= 2.2
        elif category == "right_hand":
            face_is_valid = center_x <= -13.45 and x_span <= 2.2
        else:
            face_is_valid = face_category == category and x_span <= 2.2
        if face_is_valid:
            keep_faces.add(polygon.index)
    mesh = bmesh.new()
    mesh.from_mesh(duplicate.data)
    mesh.verts.ensure_lookup_table()
    mesh.faces.ensure_lookup_table()
    bmesh.ops.delete(
        mesh,
        geom=[face for face in mesh.faces if face.index not in keep_faces],
        context="FACES",
    )
    loose_vertices = [vertex for vertex in mesh.verts if not vertex.link_faces]
    if loose_vertices:
        bmesh.ops.delete(mesh, geom=loose_vertices, context="VERTS")
    mesh.to_mesh(duplicate.data)
    mesh.free()
    duplicate.data.update()
    for group in list(duplicate.vertex_groups):
        duplicate.vertex_groups.remove(group)
    return duplicate


def transform_vertices(obj: bpy.types.Object, function) -> None:
    for vertex in obj.data.vertices:
        vertex.co = function(vertex.co.copy())
    obj.data.update()


def parent_keep_world(child: bpy.types.Object, parent: bpy.types.Object) -> None:
    bpy.context.view_layer.update()
    world = child.matrix_world.copy()
    child.parent = parent
    child.matrix_world = world


def empty(name: str, location: Vector, parent=None) -> bpy.types.Object:
    result = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(result)
    result.empty_display_type = "SPHERE"
    result.empty_display_size = 0.35
    result.location = location
    if parent:
        parent_keep_world(result, parent)
    return result


def make_skin_material() -> bpy.types.Material:
    material = bpy.data.materials.new("JointSkin")
    material.use_nodes = True
    material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.18, 0.075, 0.052, 1.0)
    material.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    material.roughness = 0.9
    return material


def solid_material(name: str, color, roughness: float) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = color
    material.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = roughness
    return material


def seal_mesh_boundaries(obj: bpy.types.Object, material: bpy.types.Material) -> int:
    """Close every true mesh boundary without changing the existing silhouette.

    The source character is split into editable body/head/limb pieces.  Faces
    crossing those groups are intentionally discarded, which leaves open edge
    loops around the neck, armpits and both sides of the dress.  Filling the
    loops on the resulting mesh is more robust than hiding them with oversized
    primitives and keeps all editable pivots and user transforms intact.
    """
    obj.data.materials.append(material)
    repair_material_index = len(obj.data.materials) - 1
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    mesh.verts.ensure_lookup_table()
    # The source duplicates vertices along UV seams.  They occupy the exact
    # same position and are not real holes, so weld only those coincident
    # vertices before looking for genuine open contours.
    bmesh.ops.remove_doubles(mesh, verts=list(mesh.verts), dist=0.00001)
    mesh.verts.ensure_lookup_table()
    mesh.edges.ensure_lookup_table()
    initial_boundary_edges = [edge for edge in mesh.edges if edge.is_boundary]
    if not initial_boundary_edges:
        mesh.free()
        return 0
    all_repair_faces = []
    # holes_fill may resolve only a subset when several unrelated contours
    # share the same mesh.  Re-query boundaries until no real loop remains.
    for _pass in range(8):
        mesh.edges.ensure_lookup_table()
        boundary_edges = [edge for edge in mesh.edges if edge.is_boundary]
        if not boundary_edges:
            break
        result = bmesh.ops.holes_fill(mesh, edges=boundary_edges, sides=0)
        repair_faces = list(result.get("faces", []))
        if not repair_faces:
            break
        for face in repair_faces:
            face.material_index = repair_material_index
            face.smooth = True
        all_repair_faces.extend(repair_faces)
    # Small non-planar contours around the shoulders/neck are occasionally
    # rejected by holes_fill.  Resolve each remaining connected loop on its
    # own with a triangulated cap.
    mesh.edges.ensure_lookup_table()
    pending_edges = {edge for edge in mesh.edges if edge.is_boundary}
    while pending_edges:
        first_edge = pending_edges.pop()
        component = {first_edge}
        stack = [first_edge]
        while stack:
            current = stack.pop()
            for vertex in current.verts:
                for linked_edge in vertex.link_edges:
                    if linked_edge in pending_edges and linked_edge.is_boundary:
                        pending_edges.remove(linked_edge)
                        component.add(linked_edge)
                        stack.append(linked_edge)
        result = bmesh.ops.triangle_fill(
            mesh,
            edges=list(component),
            use_beauty=True,
            use_dissolve=False,
        )
        component_faces = [
            item for item in result.get("geom", [])
            if isinstance(item, bmesh.types.BMFace)
        ]
        for face in component_faces:
            face.material_index = repair_material_index
            face.smooth = True
        all_repair_faces.extend(component_faces)
    if all_repair_faces:
        bmesh.ops.triangulate(mesh, faces=all_repair_faces)
        bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()
    return len(initial_boundary_edges)


def joint(name: str, location: Vector, radius: float, parent, material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius, location=location)
    result = bpy.context.object
    result.name = name
    result.data.name = f"{name}Mesh"
    result.data.materials.append(material)
    for polygon in result.data.polygons:
        polygon.use_smooth = True
    parent_keep_world(result, parent)
    return result


def cylinder_between(name: str, start: Vector, end: Vector, radius: float, parent, material, vertices: int = 12) -> bpy.types.Object:
    direction = end - start
    midpoint = (start + end) * 0.5
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=direction.length, location=midpoint)
    result = bpy.context.object
    result.name = name
    result.data.name = f"{name}Mesh"
    result.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    result.data.materials.append(material)
    for polygon in result.data.polygons:
        polygon.use_smooth = True
    parent_keep_world(result, parent)
    return result


def ellipsoid(name: str, location: Vector, scale: Vector, parent, material, segments: int = 12) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=8, radius=1.0, location=location)
    result = bpy.context.object
    result.name = name
    result.data.name = f"{name}Mesh"
    result.scale = scale
    result.data.materials.append(material)
    for polygon in result.data.polygons:
        polygon.use_smooth = True
    parent_keep_world(result, parent)
    return result


def setup_preview(root: bpy.types.Object) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 760
    scene.render.resolution_y = 920
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.035, 0.035, 0.04)

    target = Vector((0.0, 0.0, 5.6))

    def point_at(obj, point):
        obj.rotation_euler = (point - obj.location).to_track_quat("-Z", "Y").to_euler()

    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (0.0, -22.0, 5.8)
    camera.data.lens = 58
    point_at(camera, target)
    scene.camera = camera

    for name, location, energy, size in (
        ("Key", (-5.0, -9.0, 13.0), 1200.0, 6.0),
        ("Fill", (6.0, -4.0, 7.0), 700.0, 5.0),
    ):
        light_data = bpy.data.lights.new(name, "AREA")
        light_data.energy = energy
        light_data.shape = "DISK"
        light_data.size = size
        light = bpy.data.objects.new(name, light_data)
        scene.collection.objects.link(light)
        light.location = location
        point_at(light, target)

    scene.render.filepath = str(PREVIEW)
    bpy.ops.render.render(write_still=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))

main = bpy.data.objects["Object_100"]
accessories = [bpy.data.objects[name] for name in ("Object_98", "Object_102", "Object_104", "Object_105")]

for obj in [main, *accessories]:
    apply_armature_and_world_transform(obj)

parts = {
    "body": duplicate_category(main, "body", "Body"),
    "head": duplicate_category(main, "head", "Head"),
}

bpy.data.objects.remove(main, do_unlink=True)

body_x_scale = 0.44
body_depth_scale = 0.84
head_x_scale = 0.60
head_depth_scale = 0.76
head_pivot_position = Vector((0.0, 0.0, 9.15))

transform_vertices(parts["body"], lambda point: Vector((point.x * body_x_scale, point.y * body_depth_scale, point.z)))
transform_vertices(
    parts["head"],
    lambda point: head_pivot_position
    + Vector(
        (
            (point.x - head_pivot_position.x) * head_x_scale,
            (point.y - head_pivot_position.y) * head_depth_scale,
            point.z - head_pivot_position.z,
        )
    ),
)

root = empty("EditableGrannyRig", Vector((0.0, 0.0, 0.0)))
parts["body"].parent = root
head_pivot = empty("HeadPivot", head_pivot_position, root)
parent_keep_world(parts["head"], head_pivot)

# The source FBX bind pose exports these meshes roughly 7.75 units above the
# actual head.  Keep the detailed original assets, but bake the corrected
# placement and the same width/depth correction used by the face.
accessory_names = ("OriginalEyes", "BrokenOriginalHair", "UpperTeeth", "LowerTeeth")
for accessory, corrected_name in zip(accessories, accessory_names):
    accessory.name = corrected_name
    accessory.data.name = f"{corrected_name}Mesh"
    transform_vertices(
        accessory,
        lambda point: Vector(
            (
                point.x * head_x_scale,
                point.y * head_depth_scale,
                point.z - 7.75,
            )
        ),
    )
    if corrected_name != "BrokenOriginalHair":
        parent_keep_world(accessory, head_pivot)

skin_material = make_skin_material()
dress_patch_material = solid_material("DressPatchMaterial", (0.68, 0.67, 0.65, 1.0), 0.96)

sealed_body_edges = seal_mesh_boundaries(parts["body"], dress_patch_material)
sealed_head_edges = seal_mesh_boundaries(parts["head"], skin_material)
print("SEALED_BOUNDARY_EDGES", "body", sealed_body_edges, "head", sealed_head_edges)

left_shoulder = Vector((2.0, -1.55, 8.72))
left_elbow = Vector((2.34, -1.75, 6.68))
left_wrist = Vector((2.17, -1.92, 4.68))
right_shoulder = Vector((-2.0, -1.55, 8.72))
right_elbow = Vector((-2.34, -1.75, 6.68))
right_wrist = Vector((-2.17, -1.92, 4.68))

def build_arm(side: str, shoulder: Vector, elbow: Vector, wrist: Vector, mirror: float) -> None:
    shoulder_pivot = empty(f"{side}ShoulderPivot", shoulder, root)
    cylinder_between(f"{side}UpperArm", shoulder, elbow, 0.355, shoulder_pivot, skin_material, 16)
    joint(f"{side}ShoulderJoint", shoulder, 0.42, shoulder_pivot, dress_patch_material)
    sleeve_end = shoulder.lerp(elbow, 0.31)
    cylinder_between(f"{side}DressSleeve", shoulder, sleeve_end, 0.48, shoulder_pivot, dress_patch_material, 16)

    elbow_pivot = empty(f"{side}ElbowPivot", elbow, shoulder_pivot)
    cylinder_between(f"{side}Forearm", elbow, wrist, 0.285, elbow_pivot, skin_material, 16)
    joint(f"{side}ElbowJoint", elbow, 0.315, elbow_pivot, skin_material)

    wrist_pivot = empty(f"{side}WristPivot", wrist, elbow_pivot)
    joint(f"{side}WristJoint", wrist, 0.205, wrist_pivot, skin_material)
    palm_center = wrist + Vector((0.0, -0.02, -0.34))
    ellipsoid(f"{side}Palm", palm_center, Vector((0.265, 0.16, 0.39)), wrist_pivot, skin_material, 16)

    finger_x = (-0.26, -0.09, 0.09, 0.26)
    finger_lengths = (0.34, 0.41, 0.39, 0.31)
    for index, (offset, length) in enumerate(zip(finger_x, finger_lengths), start=1):
        start = palm_center + Vector((offset * 0.72, -0.04, -0.29))
        middle = start + Vector((0.0, -0.025, -length * 0.54))
        end = middle + Vector((0.0, -0.075, -length * 0.46))
        cylinder_between(f"{side}Finger{index}A", start, middle, 0.052, wrist_pivot, skin_material, 10)
        joint(f"{side}Finger{index}Knuckle", middle, 0.057, wrist_pivot, skin_material)
        cylinder_between(f"{side}Finger{index}B", middle, end, 0.047, wrist_pivot, skin_material, 10)
        joint(f"{side}Finger{index}Tip", end, 0.052, wrist_pivot, skin_material)
    thumb_start = palm_center + Vector((mirror * 0.24, -0.03, -0.03))
    thumb_middle = thumb_start + Vector((mirror * 0.14, -0.03, -0.11))
    thumb_end = thumb_middle + Vector((mirror * 0.12, -0.055, -0.13))
    cylinder_between(f"{side}ThumbA", thumb_start, thumb_middle, 0.065, wrist_pivot, skin_material, 10)
    cylinder_between(f"{side}ThumbB", thumb_middle, thumb_end, 0.057, wrist_pivot, skin_material, 10)
    joint(f"{side}ThumbTip", thumb_end, 0.06, wrist_pivot, skin_material)

build_arm("Left", left_shoulder, left_elbow, left_wrist, -1.0)
build_arm("Right", right_shoulder, right_elbow, right_wrist, 1.0)

# The original hair is made from broken transparent cards.  A small cluster of
# editable, matte tufts keeps the source silhouette without white alpha planes.
hair_material = solid_material("HairMaterial", (0.075, 0.07, 0.065, 1.0), 0.98)
ellipsoid("HairCap", Vector((0.0, 0.25, 10.96)), Vector((1.03, 0.86, 0.43)), head_pivot, hair_material, 20)
ellipsoid("LeftHairTuft", Vector((0.91, 0.04, 10.53)), Vector((0.31, 0.42, 0.49)), head_pivot, hair_material, 16)
ellipsoid("RightHairTuft", Vector((-0.91, 0.04, 10.53)), Vector((0.31, 0.42, 0.49)), head_pivot, hair_material, 16)

for obj in list(bpy.context.scene.objects):
    if obj not in {root, *root.children_recursive} and obj.type not in {"CAMERA", "LIGHT"}:
        bpy.data.objects.remove(obj, do_unlink=True)

for part_name, part in parts.items():
    world_points = [part.matrix_world @ vertex.co for vertex in part.data.vertices]
    if world_points:
        bounds_min = tuple(round(min(point[index] for point in world_points), 3) for index in range(3))
        bounds_max = tuple(round(max(point[index] for point in world_points), 3) for index in range(3))
        print("PART_BOUNDS", part_name, bounds_min, bounds_max)

setup_preview(root)

bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
for child in root.children_recursive:
    child.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT),
    export_format="GLB",
    use_selection=True,
    export_animations=False,
    export_apply=True,
)
print(f"EXPORTED {OUTPUT}")
print(f"PREVIEW {PREVIEW}")
