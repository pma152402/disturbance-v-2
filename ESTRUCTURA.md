# Estructura del proyecto

Mapa de carpetas de `DisturbanceV2`. Describe **lo que hay hoy**, incluida la raíz
sin ordenar: no es una propuesta de reorganización.

Escena de arranque: `levels/test.tscn`. Todo lo que se ve en pantalla cuelga de ahí.

## Carpetas

### Código y escenas del juego

| Carpeta | Archivos | Qué contiene |
|---|---:|---|
| `levels/` | 2 | `test.tscn` (escena de arranque) y `house_baked.tscn` (el mapa) |
| `player/` | 13 | Personaje jugable: `player.gd`, cámara, manos, inventario, posturas y `held_items/` |
| `enemies/` | 25 | La abuela: `monster_grandmother.gd` (base), sus dos variantes y el animador del rig importado |
| `doors/` | 19 | Puertas normales, empujables y con cerradura, más su travesía para NPC |
| `pickups/` | 29 | Recogibles y arrojables: botellas, latas, llaves, pilas, linterna, notas |
| `minigames/` | 14 | Caldera, lavadora, puerta entablada, comprobación de habilidad y desatascador |
| `environment/` | 21 | Exterior, clima, escuela y catacumbas |
| `geometry/` | 9 | Escaleras, barandillas y sus mallas y colisiones |
| `systems/` | 22 | Arranque, navegación en runtime, optimizador de render y agrupador de decoración |
| `shaders/` | 8 | Postprocesado PS2, distorsión, banda de pared y vestido de la abuela |
| `house_props/` | 413 | Mobiliario, luces e interacciones: 253 escenas y 47 scripts |
| `sounds/` | 53 | Audio por función más las fábricas de sonido sintetizado |

### Recursos y utillaje

| Carpeta | Archivos | Peso | Qué contiene |
|---|---:|---:|---|
| `assets/` | 228 | 46 MB | Recursos 2D propios: `pictures/`, `textures/`, `fonts/`, `environment/`, `covers/`, grafitis |
| `characters/` | 132 | 35 MB | Modelos 3D de personajes, uno por subcarpeta |
| `docs/` | 12 | — | Auditorías y notas de diseño (`*_AUDIT.md`, `*_REWORK.md`) |
| `tools/` | 251 | 14 MB | Validaciones y auditorías headless. **No entra en el juego** |
| `ps2_house/` | 302 | 17 MB | Paquete externo: modelo y texturas de la casa |
| `ps2_objects/` | 36 | 432 KB | Paquete externo: objetos sueltos |
| `source_assets/` | 67 | 58 MB | Fuentes de Blender/FBX/GLB y recursos archivados |

En la raíz solo quedan 7 archivos: `project.godot`, `icon.webp` (+ su `.import`) y los
cuatro documentos de entrada (`README.md`, `CLAUDE.md`, `ESTRUCTURA.md`, `LICENSE.md`).

### Detalle de las que tienen truco

**`characters/`** — cuatro subcarpetas y es fácil tocar la equivocada:

- `granny_editable/` — **la que usa el juego**. Rig editable por pivotes desde el
  editor. No tiene piernas: torso con vestido, cabeza y brazos con dedos.
- `granny_blender/` y `granny_blender_source/` — versión anterior y su fuente.
- `companion/` — NPC acompañante.

**`sounds/`** — el audio del juego **no siempre es un archivo**. Los pasos del
jugador, la respiración de la abuela, sus pisadas y su voz se sintetizan como PCM
en tiempo de ejecución. `sounds/footsteps/` solo contiene un `.gitkeep`: está
reservada por si algún día se usan muestras grabadas.

**`ps2_house/` y `ps2_objects/`** — paquetes de terceros que **conservan sus rutas
originales** para poder actualizarlos. No los reordenes.

**`source_assets/`** — lleva un `.gdignore`, así que Godot ni la escanea ni la
importa. Nada de aquí llega al juego. `legacy_resources/` guarda recursos sin
referencias en lugar de borrarlos.

**`tools/`** — validaciones, diagnósticos y generadores. `fixtures/` contiene entradas de pruebas; `output/` contiene resultados regenerables ignorados por Git y Godot. Véase `tools/README.md`.

## Convenciones de colocación

- Un script vive **junto a la escena que lo usa** (`house_props/antique_floor_lamp.gd`
  al lado de su `.tscn`), no en una carpeta de scripts aparte.
- Cada `.gd` lleva su `.gd.uid` al lado, y cada imagen o modelo su `.import`.
  **Si mueves uno, mueve el otro**: es lo que permite a Godot reencontrarlo.
- `.godot/` es caché local y no se versiona.

## Si necesitas mover más archivos

El proyecto tiene **457 rutas `res://` escritas a mano** en scripts y **415
`ext_resource` sin UID** en escenas, que van por ruta y no se actualizan solos.
Mover un archivo a mano deja referencias rotas silenciosas.

Comprobación de rutas literales:

powershell -ExecutionPolicy Bypass -File tools/validate_resource_paths.ps1
