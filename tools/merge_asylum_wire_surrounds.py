from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROPS = ROOT / "house_props"


def merge_obj(output_name: str, parts: list[tuple[str, tuple[float, float, float]]]) -> None:
    vertices: list[str] = []
    normals: list[str] = []
    faces: list[str] = []
    vertex_offset = 0
    normal_offset = 0

    for filename, offset in parts:
        part_vertices: list[str] = []
        part_normals: list[str] = []
        part_faces: list[str] = []
        for line in (PROPS / filename).read_text(encoding="utf-8").splitlines():
            if line.startswith("v "):
                x, y, z = map(float, line.split()[1:4])
                part_vertices.append(f"v {x + offset[0]:.12g} {y + offset[1]:.12g} {z + offset[2]:.12g}")
            elif line.startswith("vn "):
                part_normals.append(line)
            elif line.startswith("f "):
                rewritten: list[str] = []
                for corner in line.split()[1:]:
                    indices = corner.split("/")
                    indices[0] = str(int(indices[0]) + vertex_offset)
                    if len(indices) > 2 and indices[2]:
                        indices[2] = str(int(indices[2]) + normal_offset)
                    rewritten.append("/".join(indices))
                part_faces.append("f " + " ".join(rewritten))
        vertices.extend(part_vertices)
        normals.extend(part_normals)
        faces.extend(part_faces)
        vertex_offset += len(part_vertices)
        normal_offset += len(part_normals)

    content = ["o UnifiedStaticWovenSurround", *vertices, *normals, "s 1", *faces, ""]
    (PROPS / output_name).write_text("\n".join(content), encoding="utf-8")


for width, side_x in (("4m", 1.495), ("3m", 1.22)):
    merge_obj(
        f"asylum_surround_{width}_woven_unified.obj",
        [
            (f"asylum_surround_{width}_left.obj", (-side_x, 1.965, 0.0)),
            (f"asylum_surround_{width}_right.obj", (side_x, 1.965, 0.0)),
            (f"asylum_surround_{width}_top.obj", (0.0, 3.325, 0.0)),
        ],
    )
