"""Build ChurchCatacombs; house_baked loads it only while the game runs."""

from __future__ import annotations

from collections import defaultdict, deque
from dataclasses import dataclass
from math import cos, pi, sin
from pathlib import Path
import re


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SCENE_PATH = PROJECT_ROOT / "house_baked.tscn"
CATACOMBS_SCENE_PATH = PROJECT_ROOT / "church_catacombs.tscn"

CELL = 2.75
ORIGIN_X = -8.0
ORIGIN_Z = -49.0
FLOOR_TOP = -4.25
FLOOR_THICKNESS = 0.24
CEILING_BOTTOM = -1.16
CEILING_THICKNESS = 0.22
WALL_HEIGHT = CEILING_BOTTOM - FLOOR_TOP
WALL_THICKNESS = 0.28

RESOURCE_LINES = [
    '[ext_resource type="Material" path="res://house_props/catacombs/materials/labyrinth_wall.tres" id="cat_wall_mat"]',
    '[ext_resource type="Material" path="res://house_props/catacombs/materials/labyrinth_wall_damp.tres" id="cat_wall_damp_mat"]',
    '[ext_resource type="Material" path="res://house_props/catacombs/materials/labyrinth_wall_brick.tres" id="cat_wall_brick_mat"]',
    '[ext_resource type="Material" path="res://house_props/catacombs/materials/labyrinth_wall_mold.tres" id="cat_wall_mold_mat"]',
    '[ext_resource type="Material" path="res://house_props/catacombs/materials/labyrinth_floor.tres" id="cat_floor_mat"]',
    '[ext_resource type="Material" path="res://house_props/catacombs/materials/labyrinth_floor_stone.tres" id="cat_floor_stone_mat"]',
    '[ext_resource type="Material" path="res://house_props/catacombs/materials/labyrinth_floor_mud.tres" id="cat_floor_mud_mat"]',
    '[ext_resource type="Material" path="res://house_props/catacombs/materials/labyrinth_floor_wet.tres" id="cat_floor_wet_mat"]',
    '[ext_resource type="Material" path="res://house_props/catacombs/materials/labyrinth_ceiling.tres" id="cat_ceiling_mat"]',
    '[ext_resource type="Material" path="res://house_props/catacombs/materials/labyrinth_water.tres" id="cat_water_mat"]',
    '[ext_resource type="Material" path="res://house_props/catacombs/materials/lower_room_stone.tres" id="cat_lower_room_stone"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/catacomb_sarcophagus.tscn" id="cat_sarcophagus"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/burial_niche_panel.tscn" id="cat_niches"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/sewer_drain_grate.tscn" id="cat_grate"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/sewer_pipe_cluster.tscn" id="cat_pipes"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/catacomb_wall_lantern.tscn" id="cat_lantern"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/catacomb_iron_gate.tscn" id="cat_gate"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/bone_pile.tscn" id="cat_bones"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/collapsed_masonry.tscn" id="cat_rubble"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/catacomb_urn_cluster.tscn" id="cat_urns"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/broken_coffin.tscn" id="cat_broken_coffin"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/wrapped_body.tscn" id="cat_wrapped_body"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/hanging_cage.tscn" id="cat_cage"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/wooden_barricade.tscn" id="cat_barricade"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/wall_chains.tscn" id="cat_chains"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/ritual_shrine.tscn" id="cat_shrine"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/skull_column.tscn" id="cat_skull_column"]',
    '[ext_resource type="PackedScene" path="res://house_props/catacombs/floor_candles.tscn" id="cat_floor_candles"]',
    '[ext_resource type="PackedScene" path="res://house_props/wooden_crucifix.tscn" id="45_crucifix"]',
    '[ext_resource type="PackedScene" path="res://house_props/standing_metal_shelving.tscn" id="125_metal_shelving"]',
    '[ext_resource type="PackedScene" path="res://house_props/detailed_wooden_barrel.tscn" id="144_barrel"]',
    '[ext_resource type="PackedScene" path="res://house_props/detailed_wooden_crate.tscn" id="145_crate"]',
    '[ext_resource type="PackedScene" path="res://house_props/ritual_table.tscn" id="168_ritual_table"]',
]

GRAFFITI_SHEETS = [
    # editor name, folder/file slug, original sheet width, original sheet height
    ("Tags", "tags", 1536.0, 1024.0),
    ("Characters", "characters", 1224.0, 1285.0),
    ("Symbols", "symbols", 1230.0, 1278.0),
    ("Handstyles", "handstyles", 1254.0, 1254.0),
    ("Throwups", "throwups", 1254.0, 1254.0),
    ("Wildstyle", "wildstyle", 1254.0, 1254.0),
]

RESOURCE_LINES.extend(
    f'[ext_resource type="Texture2D" path="res://assets/graffiti_individual/{slug}/{slug}_{cell_index + 1:02d}.png" id="cat_graffiti_{slug}_{cell_index + 1:02d}"]'
    for _sheet_name, slug, _width, _height in GRAFFITI_SHEETS
    for cell_index in range(16)
)


@dataclass(frozen=True)
class Box:
    parent: str
    name: str
    center: tuple[float, float, float]
    size: tuple[float, float, float]
    material: str
    collision: bool = True


def fmt(value: float) -> str:
    if abs(value) < 0.0000005:
        return "0"
    text = f"{value:.5f}".rstrip("0").rstrip(".")
    return text


def vec(values: tuple[float, float, float]) -> str:
    return "Vector3(%s, %s, %s)" % tuple(fmt(value) for value in values)


def transform_y(position: tuple[float, float, float], degrees: float = 0.0) -> str:
    angle = degrees * pi / 180.0
    c = cos(angle)
    s = sin(angle)
    x, y, z = position
    values = (c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c, x, y, z)
    return "Transform3D(%s)" % ", ".join(fmt(value) for value in values)


def cell_world(
    column: int,
    row: int,
    dx: float = 0.0,
    dz: float = 0.0,
    y: float = FLOOR_TOP,
) -> tuple[float, float, float]:
    return (ORIGIN_X + column * CELL + dx, y, ORIGIN_Z - row * CELL + dz)


def carve_rect(cells: set[tuple[int, int]], x0: int, x1: int, r0: int, r1: int) -> None:
    for row in range(r0, r1 + 1):
        for column in range(x0, x1 + 1):
            cells.add((column, row))


def carve_path(cells: set[tuple[int, int]], points: list[tuple[int, int]]) -> None:
    """Carve a one-cell-wide orthogonal route through every point."""
    for (x0, r0), (x1, r1) in zip(points, points[1:]):
        if x0 != x1 and r0 != r1:
            raise ValueError(f"Diagonal catacomb path: {(x0, r0)} -> {(x1, r1)}")
        if x0 == x1:
            for row in range(min(r0, r1), max(r0, r1) + 1):
                cells.add((x0, row))
        else:
            for column in range(min(x0, x1), max(x0, x1) + 1):
                cells.add((column, r0))


def build_walkable_cells() -> set[tuple[int, int]]:
    cells: set[tuple[int, int]] = set()

    # Recorrido principal muy estrecho y quebrado. Cada corredor ordinario es
    # una sola celda (2.75 m brutos, 2.43 m libres entre paredes).
    carve_path(cells, [
        (0, 0), (0, 4), (-3, 4), (-3, 9), (2, 9), (2, 14),
        (-1, 14), (-1, 19), (4, 19), (4, 24), (0, 24),
        (0, 29), (-5, 29), (-5, 34), (1, 34), (1, 39),
        (-2, 39), (-2, 45), (0, 45),
    ])

    # Seis bucles largos permiten perderse y dan rutas alternativas reales.
    carve_path(cells, [(-3, 6), (-8, 6), (-8, 13), (-3, 13)])
    carve_path(cells, [(2, 11), (8, 11), (8, 17), (2, 17)])
    carve_path(cells, [(-1, 20), (-11, 20), (-11, 27), (0, 27)])
    carve_path(cells, [(4, 21), (12, 21), (12, 29), (0, 29)])
    carve_path(cells, [(-5, 31), (-14, 31), (-14, 39), (-2, 39)])
    carve_path(cells, [(1, 35), (10, 35), (10, 42), (-2, 42)])

    # Cruces secundarios que rompen la lectura del trazado desde una esquina.
    carve_path(cells, [(-8, 9), (-12, 9), (-12, 16), (-1, 16)])
    carve_path(cells, [(8, 14), (14, 14), (14, 24), (12, 24)])
    carve_path(cells, [(-11, 23), (-16, 23), (-16, 35), (-14, 35)])
    carve_path(cells, [(12, 26), (16, 26), (16, 37), (10, 37)])
    carve_path(cells, [(-10, 31), (-10, 43), (-2, 43)])
    carve_path(cells, [(6, 35), (6, 46), (0, 46)])

    # Ramales muertos deliberados: el jugador ve contenido, pero no una salida.
    carve_path(cells, [(-8, 8), (-14, 8)])
    carve_path(cells, [(8, 13), (13, 13)])
    carve_path(cells, [(-12, 16), (-16, 16)])
    carve_path(cells, [(14, 18), (17, 18)])
    carve_path(cells, [(-16, 27), (-18, 27)])
    carve_path(cells, [(16, 30), (19, 30)])
    carve_path(cells, [(-14, 37), (-18, 37)])
    carve_path(cells, [(10, 40), (15, 40)])

    # Habitaciones compactas, claramente diferenciadas de los pasillos.
    carve_rect(cells, -1, 1, 0, 2)       # vestíbulo de descenso
    carve_rect(cells, -10, -7, 5, 8)     # sala de bombas
    carve_rect(cells, -15, -12, 7, 10)   # cámara inundada
    carve_rect(cells, 7, 10, 10, 13)     # primera galería funeraria
    carve_rect(cells, -3, 2, 13, 17)     # cisterna irregular central
    carve_rect(cells, 12, 15, 16, 19)    # depósito de jaulas
    carve_rect(cells, -13, -10, 19, 22)  # osario
    carve_rect(cells, 3, 6, 18, 21)      # capilla menor
    carve_rect(cells, -18, -15, 22, 25)  # almacén sellado
    carve_rect(cells, 11, 14, 24, 27)    # archivo funerario
    carve_rect(cells, -7, -4, 28, 31)    # sala de cuerpos
    carve_rect(cells, 15, 18, 29, 32)    # taller abandonado
    carve_rect(cells, -16, -13, 34, 37)  # fosa común
    carve_rect(cells, 8, 11, 34, 37)     # santuario lateral
    carve_rect(cells, -12, -9, 40, 43)   # cámara de cadenas
    carve_rect(cells, 9, 12, 39, 42)     # cripta inundada
    carve_rect(cells, -3, 2, 44, 48)     # cripta final

    return cells


def validate_layout(cells: set[tuple[int, int]]) -> None:
    start = (0, 0)
    goal = (0, 48)
    assert start in cells and goal in cells
    visited = {start}
    queue = deque([start])
    while queue:
        column, row = queue.popleft()
        for neighbor in ((column + 1, row), (column - 1, row), (column, row + 1), (column, row - 1)):
            if neighbor in cells and neighbor not in visited:
                visited.add(neighbor)
                queue.append(neighbor)
    if visited != cells:
        raise RuntimeError(f"Disconnected catacomb cells: {sorted(cells - visited)[:12]}")

    distance = {start: 0}
    queue.append(start)
    while queue:
        current = queue.popleft()
        column, row = current
        for neighbor in ((column + 1, row), (column - 1, row), (column, row + 1), (column, row - 1)):
            if neighbor in cells and neighbor not in distance:
                distance[neighbor] = distance[current] + 1
                queue.append(neighbor)
    if distance[goal] < 45:
        raise RuntimeError("Main route became too short to read as a large labyrinth")


def row_runs(cells: set[tuple[int, int]]) -> list[tuple[int, int, int]]:
    by_row: dict[int, list[int]] = defaultdict(list)
    for column, row in cells:
        by_row[row].append(column)
    runs: list[tuple[int, int, int]] = []
    for row, columns in sorted(by_row.items()):
        columns.sort()
        start = previous = columns[0]
        for column in columns[1:]:
            if column != previous + 1:
                runs.append((start, previous, row))
                start = column
            previous = column
        runs.append((start, previous, row))
    return runs


def floor_rectangles(cells: set[tuple[int, int]]) -> list[tuple[int, int, int, int]]:
    active: dict[tuple[int, int], tuple[int, int]] = {}
    completed: list[tuple[int, int, int, int]] = []
    rows = sorted({row for _, row in cells})
    runs_by_row: dict[int, list[tuple[int, int]]] = defaultdict(list)
    for start, end, row in row_runs(cells):
        runs_by_row[row].append((start, end))

    for row in range(rows[0], rows[-1] + 2):
        current = set(runs_by_row.get(row, []))
        for run, (start_row, last_row) in list(active.items()):
            if run not in current:
                completed.append((run[0], run[1], start_row, last_row))
                del active[run]
        for run in current:
            if run in active:
                active[run] = (active[run][0], row)
            else:
                active[run] = (row, row)
    return completed


def compressed_boundary_walls(cells: set[tuple[int, int]]) -> list[tuple[str, float, float, float]]:
    # Tuple: orientation, center_x, center_z, length.
    horizontal: dict[float, list[float]] = defaultdict(list)
    vertical: dict[float, list[float]] = defaultdict(list)
    for column, row in cells:
        center_x = ORIGIN_X + column * CELL
        center_z = ORIGIN_Z - row * CELL
        if (column, row - 1) not in cells and (column, row) != (0, 0):
            horizontal[center_z + CELL * 0.5].append(center_x)
        if (column, row + 1) not in cells:
            horizontal[center_z - CELL * 0.5].append(center_x)
        if (column - 1, row) not in cells:
            vertical[center_x - CELL * 0.5].append(center_z)
        if (column + 1, row) not in cells:
            vertical[center_x + CELL * 0.5].append(center_z)

    walls: list[tuple[str, float, float, float]] = []
    for z_position, centers in horizontal.items():
        centers.sort()
        run_start = previous = centers[0]
        for center in centers[1:]:
            if center - previous > CELL + 0.01:
                walls.append(("X", (run_start + previous) * 0.5, z_position, previous - run_start + CELL))
                run_start = center
            previous = center
        walls.append(("X", (run_start + previous) * 0.5, z_position, previous - run_start + CELL))
    for x_position, centers in vertical.items():
        centers.sort(reverse=True)
        run_start = previous = centers[0]
        for center in centers[1:]:
            if previous - center > CELL + 0.01:
                walls.append(("Z", x_position, (run_start + previous) * 0.5, run_start - previous + CELL))
                run_start = center
            previous = center
        walls.append(("Z", x_position, (run_start + previous) * 0.5, run_start - previous + CELL))
    return sorted(walls, key=lambda wall: (wall[2], wall[1], wall[0]))


def sector_for(x: float, z: float) -> str:
    if z > -61.0:
        return "StartChamber"
    if z < -158.0:
        return "DeepCrypt"
    if z < -116.0:
        if x < -20.0:
            return "WestOssuary"
        if x > 10.0:
            return "EastRuinedChapel"
        return "DeepCrypt"
    if x < -18.0:
        return "WestSewers"
    if x > 9.0:
        return "EastCatacombs"
    return "CentralCistern"


def stable_score(column: int, row: int, salt: int = 0) -> int:
    """Small deterministic hash used to distribute detail without randomness."""
    return ((column + 47) * 73856093 ^ (row + 71) * 19349663 ^ salt * 83492791) & 0x7FFFFFFF


def capture_start_chamber_graffiti(source: str) -> dict[str, list[str]]:
    """Keep graffiti transforms that the user adjusted manually in the editor."""
    pattern = re.compile(
        r'\[node name="(Graffiti\d+_[^"]+)"[^\]]*parent="ChurchCatacombs/StartChamber/WallArt"[^\]]*\]\n'
        r'(.*?)(?=\n\[node|\Z)',
        re.DOTALL,
    )
    overrides: dict[str, list[str]] = {}
    for node_name, body in pattern.findall(source):
        transform_lines = [
            line for line in body.splitlines()
            if line.startswith(("transform = ", "position = ", "rotation_degrees = ", "scale = "))
        ]
        if transform_lines:
            overrides[node_name] = transform_lines
    return overrides


def capture_labyrinth_door_transform(source: str) -> str:
    """Follow the editor transform of the normal door that guards the labyrinth."""
    match = re.search(
        r'\[node name="UpperNorth_NorthWingEntranceDoor4"[^\]]*\]\n'
        r'transform = (Transform3D\([^\n]+\))',
        source,
    )
    if match:
        return match.group(1)
    return transform_y((-9.57984, 0.00236, -37.87276), 89.66)


def capture_house_prop_transforms(source: str) -> dict[str, list[str]]:
    """Preserve editor adjustments to the house-local boards and crowbar."""
    overrides: dict[str, list[str]] = {}
    for node_name in ("BoardedLabyrinthAccess", "CrowbarForLabyrinth"):
        match = re.search(
            rf'\[node name="{node_name}"[^\]]*\]\n(.*?)(?=\n\[node|\n\[editable|\Z)',
            source,
            flags=re.DOTALL,
        )
        if not match:
            continue
        transform_lines = [
            line for line in match.group(1).splitlines()
            if line.startswith(("transform = ", "position = ", "rotation_degrees = ", "scale = "))
        ]
        if transform_lines:
            overrides[node_name] = transform_lines
    return overrides


def make_generated_sections(
    graffiti_overrides: dict[str, list[str]] | None = None,
    labyrinth_door_transform: str = "",
) -> tuple[str, str]:
    graffiti_overrides = graffiti_overrides or {}
    labyrinth_door_transform = labyrinth_door_transform or transform_y(
        (-9.57984, 0.00236, -37.87276), 89.66
    )
    cells = build_walkable_cells()
    validate_layout(cells)
    boxes: list[Box] = []
    visual_boxes: list[Box] = []

    # Existing church lower room and a level connector through the former
    # second-stair opening. The entire labyrinth now starts at this floor level.
    access_parent = "ChurchCatacombs/ChurchLowerAccess/CurrentLowerRoom/Architecture"
    connector_near_z = -42.32
    connector_far_z = ORIGIN_Z + CELL * 0.5
    connector_center_z = (connector_near_z + connector_far_z) * 0.5
    connector_length = connector_near_z - connector_far_z + 0.08
    boxes.extend([
        Box(access_parent, "LowerRoomFloor", (-8.0, -4.37, -40.20), (8.20, 0.24, 4.24), 'ExtResource("cat_lower_room_stone")'),
        Box(access_parent, "SouthWall", (-8.0, -2.11, -38.08), (8.20, 4.28, 0.28), 'ExtResource("cat_lower_room_stone")'),
        Box(access_parent, "WestWall", (-12.10, -2.11, -40.20), (0.28, 4.28, 4.24), 'ExtResource("cat_lower_room_stone")'),
        Box(access_parent, "EastWall", (-3.90, -2.11, -40.20), (0.28, 4.28, 4.24), 'ExtResource("cat_lower_room_stone")'),
        Box(access_parent, "NorthWallLeft", (-10.72, -2.11, -42.32), (2.76, 4.28, 0.28), 'ExtResource("cat_lower_room_stone")'),
        Box(access_parent, "NorthWallRight", (-5.28, -2.11, -42.32), (2.76, 4.28, 0.28), 'ExtResource("cat_lower_room_stone")'),
        Box(access_parent, "NorthOpeningLintel", (-8.0, -0.58, -42.32), (2.68, 1.22, 0.28), 'ExtResource("cat_lower_room_stone")'),
        Box(access_parent, "LabyrinthConnectorFloor", (-8.0, FLOOR_TOP - FLOOR_THICKNESS * 0.5, connector_center_z), (2.68, FLOOR_THICKNESS, connector_length), 'ExtResource("cat_floor_mat")'),
        Box(access_parent, "LabyrinthConnectorCeiling", (-8.0, CEILING_BOTTOM + CEILING_THICKNESS * 0.5, connector_center_z), (2.96, CEILING_THICKNESS, connector_length), 'ExtResource("cat_ceiling_mat")'),
        Box(access_parent, "LabyrinthConnectorWallLeft", (-9.48, FLOOR_TOP + WALL_HEIGHT * 0.5, connector_center_z), (WALL_THICKNESS, WALL_HEIGHT, connector_length), 'ExtResource("cat_wall_mat")'),
        Box(access_parent, "LabyrinthConnectorWallRight", (-6.52, FLOOR_TOP + WALL_HEIGHT * 0.5, connector_center_z), (WALL_THICKNESS, WALL_HEIGHT, connector_length), 'ExtResource("cat_wall_mat")'),
    ])

    # Floors and ceilings are compressed into non-overlapping row runs.  This
    # keeps culling useful without creating one node per grid cell.
    for index, (c0, c1, r0, r1) in enumerate(floor_rectangles(cells), 1):
        center_x = ORIGIN_X + (c0 + c1) * CELL * 0.5
        center_z = ORIGIN_Z - (r0 + r1) * CELL * 0.5
        # Tiny overlap stitches floor rectangles across T-junctions after the
        # Recast voxel erosion pass. At 4 cm it is visually imperceptible.
        size_x = (c1 - c0 + 1) * CELL + 0.04
        size_z = (r1 - r0 + 1) * CELL + 0.04
        sector = sector_for(center_x, center_z)
        architecture = f"ChurchCatacombs/{sector}/Architecture"
        floor_materials = [
            'ExtResource("cat_floor_mat")',
            'ExtResource("cat_floor_stone_mat")',
            'ExtResource("cat_floor_mat")',
            'ExtResource("cat_floor_mud_mat")',
            'ExtResource("cat_floor_stone_mat")',
            'ExtResource("cat_floor_wet_mat")',
        ]
        floor_material = floor_materials[stable_score(c0, r0, index) % len(floor_materials)]
        boxes.append(Box(architecture, f"FloorSection{index:02d}", (center_x, FLOOR_TOP - FLOOR_THICKNESS * 0.5, center_z), (size_x, FLOOR_THICKNESS, size_z), floor_material))
        boxes.append(Box(architecture, f"CeilingSection{index:02d}", (center_x, CEILING_BOTTOM + CEILING_THICKNESS * 0.5, center_z), (size_x, CEILING_THICKNESS, size_z), 'ExtResource("cat_ceiling_mat")'))

    for index, (orientation, x, z, length) in enumerate(compressed_boundary_walls(cells), 1):
        size = (length, WALL_HEIGHT, WALL_THICKNESS) if orientation == "X" else (WALL_THICKNESS, WALL_HEIGHT, length)
        parent = f"ChurchCatacombs/{sector_for(x, z)}/Architecture"
        wall_materials = [
            'ExtResource("cat_wall_mat")',
            'ExtResource("cat_wall_damp_mat")',
            'ExtResource("cat_wall_mat")',
            'ExtResource("cat_wall_brick_mat")',
            'ExtResource("cat_wall_damp_mat")',
            'ExtResource("cat_wall_mold_mat")',
        ]
        wall_material = wall_materials[stable_score(int(x * 10), int(z * 10), index) % len(wall_materials)]
        boxes.append(Box(parent, f"BoundaryWall{orientation}{index:03d}", (x, FLOOR_TOP + WALL_HEIGHT * 0.5, z), size, wall_material))

    # Low, narrow arch frames reinforce the claustrophobic scale while leaving
    # a 2.1 m opening for both capsule colliders.
    def add_portal(name: str, x: float, z: float, across: str) -> None:
        parent = f"ChurchCatacombs/{sector_for(x, z)}/Architecture"
        pillar_height = 2.92
        pillar_y = FLOOR_TOP + pillar_height * 0.5
        lintel_y = FLOOR_TOP + 3.27
        if across == "X":
            boxes.extend([
                Box(parent, name + "LeftPillar", (x - 1.23, pillar_y, z), (0.34, pillar_height, 0.46), 'ExtResource("cat_wall_mat")'),
                Box(parent, name + "RightPillar", (x + 1.23, pillar_y, z), (0.34, pillar_height, 0.46), 'ExtResource("cat_wall_mat")'),
                Box(parent, name + "Lintel", (x, lintel_y, z), (2.80, 0.62, 0.46), 'ExtResource("cat_wall_mat")'),
            ])
        else:
            boxes.extend([
                Box(parent, name + "LeftPillar", (x, pillar_y, z - 1.23), (0.46, pillar_height, 0.34), 'ExtResource("cat_wall_mat")'),
                Box(parent, name + "RightPillar", (x, pillar_y, z + 1.23), (0.46, pillar_height, 0.34), 'ExtResource("cat_wall_mat")'),
                Box(parent, name + "Lintel", (x, lintel_y, z), (0.46, 0.62, 2.80), 'ExtResource("cat_wall_mat")'),
            ])

    add_portal("StartThreshold", *cell_world(0, 4)[::2], "X")
    add_portal("WestSewerThreshold", *cell_world(-8, 6)[::2], "Z")
    add_portal("EastGalleryThreshold", *cell_world(8, 11)[::2], "Z")
    add_portal("CisternNorthThreshold", *cell_world(-1, 14)[::2], "X")
    add_portal("OssuaryThreshold", *cell_world(-11, 20)[::2], "Z")
    add_portal("ChapelThreshold", *cell_world(4, 21)[::2], "Z")
    add_portal("DeepCryptThreshold", *cell_world(-2, 43)[::2], "X")

    # Shallow sewage channels: visual only, so the traversal plane remains
    # predictable for both player and NavigationAgent3D.
    visual_boxes.extend([
        Box("ChurchCatacombs/WestSewers/Drainage", "PumpRoomWastewater", cell_world(-8, 7, y=FLOOR_TOP + 0.018), (6.8, 0.036, 7.8), 'ExtResource("cat_water_mat")', False),
        Box("ChurchCatacombs/WestSewers/Drainage", "WestChannel", cell_world(-12, 13, y=FLOOR_TOP + 0.022), (0.82, 0.044, 18.0), 'ExtResource("cat_water_mat")', False),
        Box("ChurchCatacombs/CentralCistern/Drainage", "CisternFeedChannel", cell_world(-6, 16, y=FLOOR_TOP + 0.022), (26.0, 0.044, 0.82), 'ExtResource("cat_water_mat")', False),
        Box("ChurchCatacombs/EastCatacombs/Drainage", "EasternSeepage", cell_world(14, 21, y=FLOOR_TOP + 0.018), (0.72, 0.036, 16.0), 'ExtResource("cat_water_mat")', False),
        Box("ChurchCatacombs/EastRuinedChapel/Drainage", "DeepSeepage", cell_world(10, 40, y=FLOOR_TOP + 0.018), (7.0, 0.036, 6.8), 'ExtResource("cat_water_mat")', False),
    ])

    # Dozens of shallow, collision-free floor repairs break up long repeated
    # runs. They remain grouped under Drainage so they are easy to hide/edit.
    floor_patch_materials = [
        'ExtResource("cat_floor_mud_mat")',
        'ExtResource("cat_floor_stone_mat")',
        'ExtResource("cat_floor_wet_mat")',
    ]
    patch_cells = sorted(cells, key=lambda cell: stable_score(cell[0], cell[1], 17))[:52]
    for index, (column, row) in enumerate(patch_cells, 1):
        score = stable_score(column, row, 29)
        width = 0.62 + (score % 7) * 0.13
        depth = 0.58 + ((score // 7) % 8) * 0.12
        dx = (((score // 53) % 7) - 3) * 0.09
        dz = (((score // 371) % 7) - 3) * 0.09
        position = cell_world(column, row, dx, dz, FLOOR_TOP + 0.012)
        sector = sector_for(position[0], position[2])
        visual_boxes.append(Box(
            f"ChurchCatacombs/{sector}/Drainage",
            f"FloorWearPatch{index:02d}",
            position,
            (width, 0.024, depth),
            floor_patch_materials[index % len(floor_patch_materials)],
            False,
        ))

    resources: list[str] = []
    nodes: list[str] = []

    # Every one of the 96 atlas cells becomes its own reusable Godot resource.
    # This keeps six source textures in memory while exposing each painting as
    # a separately selectable MeshInstance3D in house_baked.
    graffiti_conditions = [
        ("Faded", (0.61, 0.59, 0.56, 0.48), 1.0),
        ("Weathered", (0.76, 0.73, 0.69, 0.68), 0.98),
        ("Aged", (0.86, 0.83, 0.79, 0.82), 0.95),
        ("Fresh", (1.0, 1.0, 1.0, 0.98), 0.88),
    ]
    for sheet_index, (sheet_name, slug, image_width, image_height) in enumerate(GRAFFITI_SHEETS):
        cell_width = image_width / 4.0
        cell_height = image_height / 4.0
        aspect = cell_width / cell_height
        quad_height = 1.52
        quad_width = quad_height * aspect
        for cell_index in range(16):
            resource_name = f"CatGraffiti{sheet_name}{cell_index + 1:02d}"
            condition_index = (sheet_index * 3 + cell_index * 5) % len(graffiti_conditions)
            _condition_name, color, roughness = graffiti_conditions[condition_index]
            resources.extend([
                f'[sub_resource type="StandardMaterial3D" id="{resource_name}Material"]',
                "transparency = 1",
                "cull_mode = 2",
                f"albedo_color = Color({fmt(color[0])}, {fmt(color[1])}, {fmt(color[2])}, {fmt(color[3])})",
                f'albedo_texture = ExtResource("cat_graffiti_{slug}_{cell_index + 1:02d}")',
                f"roughness = {fmt(roughness)}",
                "texture_filter = 0",
                "",
                f'[sub_resource type="QuadMesh" id="{resource_name}Quad"]',
                f'material = SubResource("{resource_name}Material")',
                f"size = Vector2({fmt(quad_width)}, {fmt(quad_height)})",
                "",
            ])

    def emit_box(box: Box, resource_index: int) -> None:
        mesh_id = f"CatBoxMesh_{resource_index:03d}"
        resources.extend([
            f'[sub_resource type="BoxMesh" id="{mesh_id}"]',
            f"material = {box.material}",
            f"size = {vec(box.size)}",
            "",
        ])
        node_path = f"{box.parent}/{box.name}"
        if box.collision:
            shape_id = f"CatBoxShape_{resource_index:03d}"
            resources.extend([
                f'[sub_resource type="BoxShape3D" id="{shape_id}"]',
                f"size = {vec(box.size)}",
                "",
            ])
            nodes.extend([
                f'[node name="{box.name}" type="StaticBody3D" parent="{box.parent}"]',
                f"position = {vec(box.center)}",
                "collision_layer = 1",
                "collision_mask = 1",
                "",
                f'[node name="Mesh" type="MeshInstance3D" parent="{node_path}"]',
                f'mesh = SubResource("{mesh_id}")',
                "",
                f'[node name="Collision" type="CollisionShape3D" parent="{node_path}"]',
                f'shape = SubResource("{shape_id}")',
                "",
            ])
        else:
            nodes.extend([
                f'[node name="{box.name}" type="MeshInstance3D" parent="{box.parent}"]',
                f"position = {vec(box.center)}",
                f'mesh = SubResource("{mesh_id}")',
                "cast_shadow = 0",
                "",
            ])

    all_boxes = boxes + visual_boxes
    for index, box in enumerate(all_boxes, 1):
        emit_box(box, index)

    # Cistern pool and ring of robust stone pillars.
    pool_mesh_id = "CatCisternPoolMesh"
    resources.extend([
        f'[sub_resource type="CylinderMesh" id="{pool_mesh_id}"]',
        'material = ExtResource("cat_water_mat")',
        "top_radius = 5.25",
        "bottom_radius = 5.25",
        "height = 0.04",
        "radial_segments = 24",
        "",
        '[sub_resource type="CylinderMesh" id="CatCisternPillarMesh"]',
        'material = ExtResource("cat_wall_mat")',
        "top_radius = 0.42",
        "bottom_radius = 0.48",
        f"height = {fmt(WALL_HEIGHT)}",
        "radial_segments = 10",
        "",
        '[sub_resource type="CylinderShape3D" id="CatCisternPillarShape"]',
        "radius = 0.48",
        f"height = {fmt(WALL_HEIGHT)}",
        "",
    ])
    nodes.extend([
        '[node name="CisternPool" type="MeshInstance3D" parent="ChurchCatacombs/CentralCistern/Drainage"]',
        f"position = {vec((-8.0, FLOOR_TOP + 0.02, -93.0))}",
        f'mesh = SubResource("{pool_mesh_id}")',
        "cast_shadow = 0",
        "",
    ])
    for pillar_index in range(8):
        angle = pillar_index * (2.0 * pi / 8.0)
        x = -8.0 + cos(angle) * 7.25
        z = -93.0 + sin(angle) * 7.25
        name = f"CisternPillar{pillar_index + 1:02d}"
        path = f"ChurchCatacombs/CentralCistern/Architecture/{name}"
        nodes.extend([
            f'[node name="{name}" type="StaticBody3D" parent="ChurchCatacombs/CentralCistern/Architecture"]',
            f"position = {vec((x, FLOOR_TOP + WALL_HEIGHT * 0.5, z))}",
            "",
            f'[node name="Mesh" type="MeshInstance3D" parent="{path}"]',
            'mesh = SubResource("CatCisternPillarMesh")',
            "",
            f'[node name="Collision" type="CollisionShape3D" parent="{path}"]',
            'shape = SubResource("CatCisternPillarShape")',
            "",
        ])

    min_column = min(column for column, _row in cells)
    max_column = max(column for column, _row in cells)
    min_row = min(row for _column, row in cells)
    max_row = max(row for _column, row in cells)
    labyrinth_min_x = ORIGIN_X + min_column * CELL - CELL * 0.5
    labyrinth_max_x = ORIGIN_X + max_column * CELL + CELL * 0.5
    labyrinth_max_z = ORIGIN_Z - min_row * CELL + CELL * 0.5
    labyrinth_min_z = ORIGIN_Z - max_row * CELL - CELL * 0.5
    labyrinth_center = (
        (labyrinth_min_x + labyrinth_max_x) * 0.5,
        CEILING_BOTTOM + 0.05,
        (labyrinth_min_z + labyrinth_max_z) * 0.5,
    )

    hierarchy: list[str] = [
        '[node name="ChurchCatacombs" type="Node3D" parent="."]',
        'editor_description = "Continuacion subterranea editable: acceso, cloacas, cisterna, catacumbas y cripta final. La arquitectura es local a house_baked."',
        'metadata/skip_wall_band = true',
        "",
        '[node name="ChurchLowerAccess" type="Node3D" parent="ChurchCatacombs"]',
        'editor_description = "Sala inferior existente corregida y descenso hacia la sala inicial."',
        "",
        '[node name="CurrentLowerRoom" type="Node3D" parent="ChurchCatacombs/ChurchLowerAccess"]',
        "",
        '[node name="Architecture" type="Node3D" parent="ChurchCatacombs/ChurchLowerAccess/CurrentLowerRoom"]',
        "",
        '[node name="Props" type="Node3D" parent="ChurchCatacombs/ChurchLowerAccess/CurrentLowerRoom"]',
        "",
    ]
    sector_descriptions = {
        "StartChamber": "Sala inicial y primer cruce del laberinto.",
        "WestSewers": "Cloacas industriales, sala de bombas y aliviadero.",
        "CentralCistern": "Cisterna central que conecta los dos grandes bucles.",
        "EastCatacombs": "Galerias de nichos y camara funeraria.",
        "WestOssuary": "Osario, deposito de huesos y ramales muertos.",
        "EastRuinedChapel": "Capilla derruida y archivo funerario.",
        "DeepCrypt": "Antecamaras y cripta final.",
    }
    for sector, description in sector_descriptions.items():
        hierarchy.extend([
            f'[node name="{sector}" type="Node3D" parent="ChurchCatacombs"]',
            f'editor_description = "{description}"',
            "",
            f'[node name="Architecture" type="Node3D" parent="ChurchCatacombs/{sector}"]',
            "",
            f'[node name="Drainage" type="Node3D" parent="ChurchCatacombs/{sector}"]',
            "",
            f'[node name="Props" type="Node3D" parent="ChurchCatacombs/{sector}"]',
            "",
            f'[node name="WallArt" type="Node3D" parent="ChurchCatacombs/{sector}"]',
            'editor_description = "96 grafitis individuales procedentes de seis atlas; cada nodo se puede seleccionar y mover por separado."',
            "",
            f'[node name="Lighting" type="Node3D" parent="ChurchCatacombs/{sector}"]',
            "",
        ])

    # Use 72 widely distributed exposed wall faces, then layer the remaining
    # 24 paintings over some of them. The normal offset prevents z-fighting.
    boundary_faces: list[tuple[int, int, str]] = []
    for column, row in cells:
        if (column, row - 1) not in cells and (column, row) != (0, 0):
            boundary_faces.append((column, row, "north"))
        if (column, row + 1) not in cells:
            boundary_faces.append((column, row, "south"))
        if (column - 1, row) not in cells:
            boundary_faces.append((column, row, "west"))
        if (column + 1, row) not in cells:
            boundary_faces.append((column, row, "east"))
    face_salts = {"north": 31, "south": 37, "west": 41, "east": 43}
    selected_faces = sorted(
        boundary_faces,
        key=lambda face: stable_score(face[0], face[1], face_salts[face[2]]),
    )[:72]
    selected_faces.sort(key=lambda face: (face[1], face[0], face[2]))
    wall_surface = CELL * 0.5 - WALL_THICKNESS * 0.5 - 0.009

    graffiti_assets = [
        (sheet_index, cell_index)
        for cell_index in range(16)
        for sheet_index in range(len(GRAFFITI_SHEETS))
    ]
    for graffiti_index, (sheet_index, cell_index) in enumerate(graffiti_assets):
        if graffiti_index < len(selected_faces):
            face_index = graffiti_index
            layer = 0
        else:
            face_index = ((graffiti_index - len(selected_faces)) * 17 + 7) % len(selected_faces)
            layer = 1
        column, row, side = selected_faces[face_index]
        score = stable_score(column, row, graffiti_index + sheet_index * 101)
        surface = wall_surface - layer * 0.018
        along = (((score // 11) % 25) - 12) * 0.052
        if layer:
            along += -0.22 if graffiti_index % 2 else 0.22
        center_x, _floor_y, center_z = cell_world(column, row)
        if side == "north":
            position = (center_x + along, 0.0, center_z + surface)
            yaw = 0
        elif side == "south":
            position = (center_x + along, 0.0, center_z - surface)
            yaw = 180
        elif side == "west":
            position = (center_x - surface, 0.0, center_z + along)
            yaw = -90
        else:
            position = (center_x + surface, 0.0, center_z + along)
            yaw = 90
        size_profiles = [
            (0.48, 0.52),
            (0.68, 0.72),
            (0.92, 0.90),
            (1.20, 1.14),
            (1.58, 1.43),
        ]
        profile_map = [0, 1, 1, 2, 2, 2, 2, 3, 3, 3, 4, 4]
        profile_index = profile_map[(score // 47) % len(profile_map)]
        scale_x, scale_y = size_profiles[profile_index]
        scale_x *= 0.94 + (score % 7) * 0.02
        scale_y *= 0.94 + ((score // 13) % 7) * 0.02
        if layer:
            scale_x *= 0.82
            scale_y *= 0.82
        visual_height = 1.52 * scale_y
        min_y = FLOOR_TOP + visual_height * 0.5 + 0.10
        max_y = CEILING_BOTTOM - visual_height * 0.5 - 0.10
        height_mix = ((score // 97) % 101) / 100.0
        y = min_y + (max_y - min_y) * height_mix
        position = (position[0], y, position[2])
        roll = ((score // 101) % 31) - 15
        sheet_name = GRAFFITI_SHEETS[sheet_index][0]
        resource_name = f"CatGraffiti{sheet_name}{cell_index + 1:02d}"
        condition_name = graffiti_conditions[(sheet_index * 3 + cell_index * 5) % len(graffiti_conditions)][0]
        sector = sector_for(position[0], position[2])
        node_name = f"Graffiti{graffiti_index + 1:03d}_{sheet_name}{cell_index + 1:02d}_{condition_name}"
        transform_properties = graffiti_overrides.get(node_name, [
            f"position = {vec(position)}",
            f"rotation_degrees = Vector3(0, {yaw}, {roll})",
            f"scale = Vector3({fmt(scale_x)}, {fmt(scale_y)}, 1)",
        ])
        hierarchy.extend([
            f'[node name="{node_name}" type="MeshInstance3D" parent="ChurchCatacombs/{sector}/WallArt"]',
            f'editor_description = "{sheet_name} celda {cell_index + 1:02d}; estado {condition_name}; capa {layer}."',
            *transform_properties,
            f'mesh = SubResource("{resource_name}Quad")',
            "cast_shadow = 0",
            f'metadata/source_sheet = "{sheet_name}"',
            f"metadata/source_cell = {cell_index}",
            f'metadata/layered = {str(bool(layer)).lower()}',
            f'metadata/condition = "{condition_name}"',
            "",
        ])

    # The rain particle collision is broad but sits at the underground ceiling,
    # so it does not alter the exterior rain volumes or their sound logic.
    hierarchy.extend([
        '[node name="CatacombRainOccluder" type="GPUParticlesCollisionBox3D" parent="ChurchCatacombs"]',
        f"position = {vec(labyrinth_center)}",
        f"size = {vec((labyrinth_max_x - labyrinth_min_x, 0.45, labyrinth_max_z - labyrinth_min_z))}",
        "",
    ])

    # Dense, authored prop pass. Large colliders live in rooms/dead ends;
    # corridor clutter is low and offset so a 0.54 m agent always has passage.
    instance_entries: list[tuple[str, str, str, str, tuple[float, float, float], float]] = []

    def add_prop(
        name: str,
        resource_id: str,
        column: int,
        row: int,
        degrees: float = 0.0,
        dx: float = 0.0,
        dz: float = 0.0,
        y_offset: float = 0.0,
        branch: str = "Props",
    ) -> None:
        position = cell_world(column, row, dx, dz, FLOOR_TOP + y_offset)
        sector = sector_for(position[0], position[2])
        instance_entries.append((name, sector, branch, resource_id, position, degrees))

    # Architectural/funerary anchors.
    for index, (column, row, degrees) in enumerate([
        (8, 11, 90), (10, 12, -90), (12, 17, 90), (15, 18, -90),
        (-13, 20, 90), (-10, 21, -90), (-18, 24, 90), (-15, 25, -90),
        (11, 25, 90), (14, 27, -90), (-12, 41, 90), (10, 41, -90),
        (-3, 46, 90), (2, 47, -90),
    ], 1):
        add_prop(f"BurialNiche{index:02d}", "cat_niches", column, row, degrees)

    for index, (column, row, degrees, dx, dz) in enumerate([
        (9, 12, 0, 0, 0), (13, 18, 90, 0, 0), (-11, 21, 0, 0, 0),
        (-16, 24, 90, 0, 0), (12, 26, 90, 0, 0), (-5, 30, 0, 0, 0),
        (17, 31, 90, 0, 0), (-14, 36, 0, 0, 0), (9, 36, 90, 0, 0),
        (-10, 42, 90, 0, 0), (11, 40, 0, 0, 0), (0, 47, 0, 0, 0),
    ], 1):
        add_prop(f"Sarcophagus{index:02d}", "cat_sarcophagus", column, row, degrees, dx, dz)

    # Industrial sewer details attached close to room walls.
    for index, (column, row, degrees, dx, dz) in enumerate([
        (-10, 6, 0, 0, 1.05), (-8, 6, 180, 0, -1.05), (-10, 8, 0, 0, 1.05),
        (-15, 8, -90, 1.05, 0), (-12, 10, 180, 0, -1.05), (-12, 14, -90, 1.05, 0),
        (14, 17, 90, -1.05, 0), (16, 30, -90, 1.05, 0), (18, 31, 90, -1.05, 0),
        (10, 40, 0, 0, 1.05),
    ], 1):
        add_prop(f"SewerPipeCluster{index:02d}", "cat_pipes", column, row, degrees, dx, dz)

    for index, (column, row) in enumerate([
        (-1, 1), (-8, 7), (-14, 9), (8, 12), (-2, 16), (-12, 21),
        (13, 26), (-5, 30), (17, 31), (-15, 36), (10, 41), (-1, 47),
    ], 1):
        add_prop(f"DrainGrate{index:02d}", "cat_grate", column, row, y_offset=0.03)

    # Repeated macabre floor dressing, all with simplified colliders.
    for index, (column, row, degrees, dx, dz) in enumerate([
        (-9, 7, 12, .45, .2), (-14, 9, -20, -.3, .35), (7, 12, 25, .35, -.25),
        (-2, 15, -15, -.45, .2), (1, 17, 30, .4, -.25), (-12, 20, 0, .35, .3),
        (-10, 22, 45, -.4, -.25), (5, 20, -30, .4, .25), (-17, 23, 18, -.25, .35),
        (13, 26, -12, .4, -.3), (-6, 29, 35, -.35, .2), (17, 30, -25, .35, .3),
        (-15, 35, 15, .4, -.2), (-14, 37, -35, -.4, .25), (9, 35, 0, .35, .3),
        (11, 37, 40, -.35, -.25), (-11, 41, -18, .35, .25), (10, 40, 20, -.35, -.2),
        (-2, 46, -30, .4, .2), (1, 48, 25, -.35, -.25),
    ], 1):
        add_prop(f"BonePile{index:02d}", "cat_bones", column, row, degrees, dx, dz, 0.02)

    for index, (column, row, degrees) in enumerate([
        (-13, 8, 15), (9, 12, -12), (14, 18, 18), (-12, 21, -10),
        (-17, 24, 22), (13, 25, -18), (-5, 31, 8), (17, 30, -14),
        (-15, 36, 20), (10, 36, -18), (-10, 42, 12), (1, 47, -10),
    ], 1):
        add_prop(f"UrnCluster{index:02d}", "cat_urns", column, row, degrees)

    for index, (column, row, degrees, dx) in enumerate([
        (-14, 8, 90, 0), (8, 12, 0, 0), (-12, 20, 90, 0), (5, 20, 0, 0),
        (-17, 24, 90, 0), (12, 26, 0, 0), (-6, 30, 90, 0), (16, 31, 0, 0),
        (-15, 35, 90, 0), (9, 36, 0, 0), (-11, 42, 90, 0), (1, 46, 0, 0),
    ], 1):
        add_prop(f"BrokenCoffin{index:02d}", "cat_broken_coffin", column, row, degrees, dx)

    for index, (column, row, degrees, dx, dz) in enumerate([
        (-13, 10, 90, .2, 0), (10, 13, 0, 0, .2), (15, 17, 90, -.2, 0),
        (-11, 22, 0, .2, 0), (-16, 25, 90, 0, -.2), (14, 25, 0, -.2, 0),
        (-5, 30, 90, .2, 0), (18, 31, 0, 0, -.2), (-14, 36, 90, -.2, 0),
        (10, 37, 0, .2, 0), (-10, 41, 90, 0, .2), (0, 46, 0, -.2, 0),
    ], 1):
        add_prop(f"WrappedBody{index:02d}", "cat_wrapped_body", column, row, degrees, dx, dz)

    # Larger silhouettes live only in chambers so they shape routes without
    # sealing the one-cell corridors.
    for index, (column, row, degrees) in enumerate([
        (-14, 9, 0), (9, 12, 0), (14, 18, 0), (-11, 21, 0),
        (-16, 24, 0), (13, 26, 0), (-5, 30, 0), (17, 31, 0),
        (-14, 36, 0), (10, 36, 0), (-10, 42, 0), (1, 47, 0),
    ], 1):
        add_prop(f"HangingCage{index:02d}", "cat_cage", column, row, degrees)

    for index, (column, row, degrees) in enumerate([
        (-14, 8, 90), (13, 13, 90), (-16, 16, 90), (17, 18, 90),
        (-18, 27, 90), (19, 30, 90), (-18, 37, 90), (15, 40, 90),
    ], 1):
        add_prop(f"DeadEndBarricade{index:02d}", "cat_barricade", column, row, degrees)
        add_prop(f"DeadEndRubble{index:02d}", "cat_rubble", column, row, degrees)

    for index, (column, row, degrees, dx, dz) in enumerate([
        (1, 1, -90, 1.18, 0), (-10, 6, 90, -1.18, 0), (-7, 7, -90, 1.18, 0),
        (-15, 8, 90, -1.18, 0), (10, 11, -90, 1.18, 0), (-3, 15, 90, -1.18, 0),
        (2, 16, -90, 1.18, 0), (15, 17, -90, 1.18, 0), (-13, 21, 90, -1.18, 0),
        (6, 19, -90, 1.18, 0), (-18, 24, 90, -1.18, 0), (14, 25, -90, 1.18, 0),
        (-7, 30, 90, -1.18, 0), (18, 30, -90, 1.18, 0), (-16, 35, 90, -1.18, 0),
        (11, 35, -90, 1.18, 0), (-12, 41, 90, -1.18, 0), (2, 47, -90, 1.18, 0),
    ], 1):
        add_prop(f"WallChains{index:02d}", "cat_chains", column, row, degrees, dx, dz)

    for index, (column, row, degrees) in enumerate([
        (8, 12, 0), (14, 18, 0), (-12, 21, 0), (5, 20, 180),
        (-17, 24, 90), (13, 26, 180), (-5, 30, 0), (17, 31, 180),
        (-15, 36, 0), (10, 36, 180), (-10, 42, 0), (0, 47, 180),
    ], 1):
        add_prop(f"RitualShrine{index:02d}", "cat_shrine", column, row, degrees)

    for index, (column, row, degrees, dx, dz) in enumerate([
        (-10, 5, 0, 1.0, 1.0), (-7, 8, 180, -1.0, -1.0), (7, 10, 0, 1.0, 1.0),
        (10, 13, 180, -1.0, -1.0), (-13, 19, 0, 1.0, 1.0), (-10, 22, 180, -1.0, -1.0),
        (3, 18, 0, 1.0, 1.0), (6, 21, 180, -1.0, -1.0), (-18, 22, 0, 1.0, 1.0),
        (14, 27, 180, -1.0, -1.0), (-7, 28, 0, 1.0, 1.0), (18, 32, 180, -1.0, -1.0),
        (-16, 34, 0, 1.0, 1.0), (11, 37, 180, -1.0, -1.0), (-12, 40, 0, 1.0, 1.0),
        (12, 42, 180, -1.0, -1.0), (-3, 44, 0, 1.0, 1.0), (2, 48, 180, -1.0, -1.0),
    ], 1):
        add_prop(f"SkullColumn{index:02d}", "cat_skull_column", column, row, degrees, dx, dz)

    # Small candles and low bone clusters intentionally invade some corridors
    # to make them feel used, but their offsets preserve a walkable side.
    for index, (column, row, dx, dz) in enumerate([
        (0, 1, .5, .4), (-3, 5, -.5, .45), (-8, 10, .5, -.4), (2, 10, -.5, .45),
        (8, 14, .5, -.45), (-1, 17, -.5, .45), (-11, 23, .5, -.45), (4, 22, -.5, .45),
        (12, 25, .5, -.45), (0, 28, -.5, .45), (-14, 33, .5, -.45), (-5, 33, -.5, .45),
        (10, 34, .5, -.45), (1, 37, -.5, .45), (-10, 40, .5, -.45), (6, 42, -.5, .45),
        (-2, 45, .5, -.45), (0, 48, -.5, .45),
    ], 1):
        add_prop(f"FloorCandles{index:02d}", "cat_floor_candles", column, row, dx=dx, dz=dz)

    # Existing house assets add material variety while staying grouped with
    # the catacomb branch and retaining their own colliders.
    for index, (column, row, degrees) in enumerate([
        (-9, 6, 0), (-8, 8, 15), (-14, 9, -12), (15, 30, 8),
        (18, 32, -18), (-15, 35, 12), (11, 41, -8),
    ], 1):
        add_prop(f"StorageCrate{index:02d}", "145_crate", column, row, degrees)
    for index, (column, row, degrees) in enumerate([
        (-10, 7, 0), (-7, 7, 12), (-13, 9, -8), (16, 30, 0),
        (18, 31, 15), (-14, 36, -10), (10, 40, 8),
    ], 1):
        add_prop(f"RustBarrel{index:02d}", "144_barrel", column, row, degrees)
    for index, (column, row, degrees) in enumerate([
        (-10, 5, 90), (15, 29, 90), (-16, 34, 90), (12, 39, 90),
    ], 1):
        add_prop(f"MetalShelf{index:02d}", "125_metal_shelving", column, row, degrees)

    # Gates only terminate optional branches; no main route is blocked.
    for index, (column, row, degrees) in enumerate([
        (-14, 8, 90), (13, 13, 90), (-18, 27, 90), (19, 30, 90), (15, 40, 90),
    ], 1):
        add_prop(f"IronGate{index:02d}", "cat_gate", column, row, degrees)

    add_prop("FinalRitualTable", "168_ritual_table", 0, 46, 180)
    add_prop("FinalCrucifix", "45_crucifix", 0, 48, 180, y_offset=1.05)

    for name, sector, branch, resource_id, position, degrees in instance_entries:
        hierarchy.extend([
            f'[node name="{name}" parent="ChurchCatacombs/{sector}/{branch}" instance=ExtResource("{resource_id}")]',
            f"transform = {transform_y(position, degrees)}",
            "",
        ])

    # Sparse practical lighting: most visual interest comes from the player's
    # flashlight and small shrine/candle glows.
    lantern_cells = [
        (1, 1, -90, 1.18, 0), (-10, 7, 90, -1.18, 0), (-15, 9, 90, -1.18, 0),
        (10, 12, -90, 1.18, 0), (-3, 16, 90, -1.18, 0), (15, 18, -90, 1.18, 0),
        (-13, 20, 90, -1.18, 0), (6, 20, -90, 1.18, 0), (-18, 23, 90, -1.18, 0),
        (14, 26, -90, 1.18, 0), (-7, 29, 90, -1.18, 0), (18, 31, -90, 1.18, 0),
        (-16, 36, 90, -1.18, 0), (11, 36, -90, 1.18, 0), (2, 47, -90, 1.18, 0),
    ]
    for index, (column, row, degrees, dx, dz) in enumerate(lantern_cells, 1):
        position = cell_world(column, row, dx, dz)
        sector = sector_for(position[0], position[2])
        hierarchy.extend([
            f'[node name="WallLantern{index:02d}" parent="ChurchCatacombs/{sector}/Lighting" instance=ExtResource("cat_lantern")]',
            f"transform = {transform_y(position, degrees)}",
            "",
        ])

    generated_resources = "\n".join(resources).rstrip() + "\n\n"
    generated_nodes = "\n".join(hierarchy + nodes).rstrip() + "\n\n"
    return generated_resources, generated_nodes


def update_scene() -> None:
    source = SCENE_PATH.read_text(encoding="utf-8")
    catacombs_source = (
        CATACOMBS_SCENE_PATH.read_text(encoding="utf-8")
        if CATACOMBS_SCENE_PATH.exists()
        else source
    )
    graffiti_overrides = capture_start_chamber_graffiti(catacombs_source)
    labyrinth_door_transform = capture_labyrinth_door_transform(source)
    house_prop_overrides = capture_house_prop_transforms(source)

    # Remove a previous generation, if present.
    source = re.sub(
        r'\n\[node name="ChurchCatacombs" type="Node3D" parent="\."[^\]]*\].*?(?=\n\[editable path=)',
        "\n",
        source,
        flags=re.DOTALL,
    )
    source = re.sub(
        r'\n\[node name="ChurchCatacombs"[^\n]*instance=ExtResource\("cat_scene"\)\]\n'
        r'(?:transform = [^\n]+\n)?',
        "\n",
        source,
    )
    source = source.replace('[editable path="ChurchCatacombs"]\n', "")
    source = re.sub(
        r'\n\[node name="(?:BoardedLabyrinthAccess|CrowbarForLabyrinth)"[^\n]*\]\n'
        r'.*?(?=\n\[node|\n\[editable|\Z)',
        "\n",
        source,
        flags=re.DOTALL,
    )
    source = re.sub(
        r'\n\[sub_resource type="(?:BoxMesh|BoxShape3D|CylinderMesh|CylinderShape3D|AtlasTexture|StandardMaterial3D|QuadMesh)" id="Cat.*?(?=\n\[(?:sub_resource|node))',
        "",
        source,
        flags=re.DOTALL,
    )
    source = "\n".join(
        line for line in source.splitlines()
        if 'id="cat_' not in line
        and 'id="house_labyrinth_boards"' not in line
        and 'id="house_labyrinth_crowbar"' not in line
    ) + "\n"

    # The two staircase instances become children of the editable branch, and
    # the fragile external-scene wall override is replaced by direct local nodes.
    source = re.sub(
        r'\n\[node name="CompactStaircase2".*?\ntransform = .*?\n',
        "\n",
        source,
    )
    source = re.sub(
        r'\n\[node name="CompactStaircase3".*?\ntransform = .*?\n',
        "\n",
        source,
    )
    source = re.sub(
        r'\n\[node name="ShaftNorth3" type="StaticBody3D" parent="BasementAccessAndInitialRoom".*?(?=\n\[node name="GrassClumpsStagingFrontDoor")',
        "\n",
        source,
        flags=re.DOTALL,
    )

    generated_resources, generated_nodes = make_generated_sections(
        graffiti_overrides,
        labyrinth_door_transform,
    )

    # The generated hierarchy uses paths suitable for embedding under the house
    # root. Rewrite them relative to ChurchCatacombs for its standalone scene.
    standalone_nodes = generated_nodes.replace(
        '[node name="ChurchCatacombs" type="Node3D" parent="."]',
        '[node name="ChurchCatacombs" type="Node3D"]',
        1,
    )
    standalone_nodes = standalone_nodes.replace(
        'parent="ChurchCatacombs/',
        'parent="',
    )
    standalone_nodes = standalone_nodes.replace(
        'parent="ChurchCatacombs"',
        'parent="."',
    )
    catacombs_scene = (
        "[gd_scene format=3]\n\n"
        + "\n".join(RESOURCE_LINES)
        + "\n\n"
        + generated_resources
        + standalone_nodes
    )
    CATACOMBS_SCENE_PATH.write_text(catacombs_scene, encoding="utf-8", newline="\n")

    # These two gameplay props deliberately remain local to house_baked so
    # they are visible and selectable while the house is edited.
    first_subresource = source.find("[sub_resource")
    if first_subresource < 0:
        raise RuntimeError("house_baked.tscn has no subresources")
    house_resources = (
        '[ext_resource type="PackedScene" path="res://house_props/catacombs/boarded_labyrinth_door.tscn" id="house_labyrinth_boards"]\n'
        '[ext_resource type="PackedScene" path="res://house_props/crowbar_pickup.tscn" id="house_labyrinth_crowbar"]\n\n'
    )
    source = source[:first_subresource].rstrip() + "\n\n" + house_resources + source[first_subresource:]

    editable = source.find('[editable path="BasementAccessAndInitialRoom"]')
    if editable < 0:
        raise RuntimeError("house_baked editable insertion point not found")
    boards_transform = house_prop_overrides.get(
        "BoardedLabyrinthAccess",
        [f"transform = {labyrinth_door_transform}"],
    )
    crowbar_transform = house_prop_overrides.get(
        "CrowbarForLabyrinth",
        [f"position = {vec((-8.25, 0.04, -37.25))}", "rotation_degrees = Vector3(0, 62, -12)"],
    )
    house_props = (
        '[node name="BoardedLabyrinthAccess" parent="." instance=ExtResource("house_labyrinth_boards")]\n'
        + "\n".join(boards_transform)
        + '\n\n[node name="CrowbarForLabyrinth" parent="." instance=ExtResource("house_labyrinth_crowbar")]\n'
        + "\n".join(crowbar_transform)
        + "\n\n"
    )
    source = source[:editable].rstrip() + "\n\n" + house_props + source[editable:]

    SCENE_PATH.write_text(source, encoding="utf-8", newline="\n")
    print(f"Generated ChurchCatacombs: {len(build_walkable_cells())} walkable cells")


if __name__ == "__main__":
    update_scene()
