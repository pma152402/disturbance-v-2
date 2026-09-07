# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proyecto

`DisturbanceV2` — juego de terror en primera persona en Godot **4.7** (GDScript puro, renderer Forward+, estética found footage / PS2). No hay C#, ni `.csproj`, ni dependencias externas. La escena de arranque es `res://levels/test.tscn`.

Los comentarios de código, la documentación y los mensajes de validación están **en español**. Manténlo así.

El mapa de carpetas, con lo que hace y contiene cada una, esta en `ESTRUCTURA.md`. Las auditorias y notas de diseno viven en `docs/`.

## Comandos

Godot no está en el PATH salvo que se haya instalado con alias; usa el binario de consola (`Godot_v*_win64_console.exe`) para ver stdout.

```bash
# Importar assets tras clonar o tras añadir recursos nuevos (genera .godot/, no versionada)
godot --headless --path . --import

# Ejecutar el juego
godot --path .

# Abrir el editor
godot -e --path .

# Ejecutar UNA validación (todas viven en tools/, son SceneTree scripts con quit(0)/quit(1))
godot --headless --path . --script res://tools/validate_grandmother_pathfinding.gd
```

Algunas validaciones **no** funcionan en `--headless` porque el renderizador dummy no conserva matrices de MultiMesh ni geometría instanciada — `tools/validate_deferred_content_and_batching.gd` lo documenta explícitamente. Si una validación falla solo en headless, prueba sin la bandera antes de tocar código.

## Verificación: el patrón `tools/`

No hay framework de test. Cada comportamiento se valida con un script `SceneTree` en `tools/` que instancia `levels/test.tscn`, espera a `navigation_baked`, manipula el nodo bajo prueba y hace `quit(0)` con un `print("OK: ...")` o `push_error()` + `quit(1)`. **Cualquier cambio de comportamiento debe llevar su validación**, nueva o reutilizando la existente.

Suite de la abuela (la más relevante al tocar IA):

| Script | Qué comprueba |
|---|---|
| `validate_grandmother_locomotion.gd` | Aceleración isótropa, tope de velocidad angular, zancada por distancia |
| `validate_grandmother_pathfinding.gd` | Recorrido con geometría entre habitaciones, tiempo máximo atascada |
| `validate_grandmother_close_combat.gd` | Tiempo hasta el ataque y órbita acumulada alrededor del jugador |
| `validate_grandmother_search_behavior.gd` | Llegada a la última posición, barrido y retorno a patrulla |
| `validate_grandmother_door_traversal.gd` | Cruce de puerta normal y doble desde ambos lados |
| `validate_photosensitive_runtime.gd` | Luces, memoria, patrulla y revelado anti-espera |
| `validate_grandmother_child_priority.gd` | Prioridad de niños sobre el jugador |
| `validate_grandmother_unreachable_target.gd` | Presa fuera del navmesh: acecho acotado, sin bloqueo permanente |
| `validate_grandmother_roaming_and_ledge.gd` | Paseo por la casa y zarpazo con empuje a un saliente |
| `validate_footstep_surfaces.gd` | Clasificación de suelos, audio distinto por superficie y volumen |

Los `audit_*.gd` son diagnósticos que imprimen inventarios (rendimiento, colisiones, audio); no devuelven código de salida útil.

## Arquitectura

### Jerarquía de la abuela

Tres enemigos comparten una sola máquina de estados. Un cambio en la base afecta a los tres:

```
enemies/monster_grandmother.gd  (CharacterBody3D, 1495 lineas — máquina de estados, navegación, puertas, ataque, comer)
├── enemies/monster_grandmother_imported.gd   → enemies/monster_grandmother_imported.tscn   (variante FOTOSENSIBLE; la usada en test.tscn)
└── enemies/monster_grandmother_crawler.gd    → enemies/monster_grandmother_crawler.tscn    (variante reptante)
```

`State { PATROL, INVESTIGATE, CHASE, SEARCH, ATTACK, EAT }` vive en la base. La variante importada **añade una segunda capa de decisión encima**, `PhotoBehavior { PATROL, STATIC_LIGHT, FLASHLIGHT, LIGHT_MEMORY, CLOSE_PLAYER, CLOSE_MEMORY, FOOTSTEP, REVEALED_PLAYER }`: `PhotoBehavior` elige el estímulo (¿linterna? ¿lámpara encendida? ¿pasos?) y luego mapea a un `State` de la base, que es quien mueve el cuerpo. Al depurar, mira siempre **los dos**: `_photo_behavior` explica el porqué, `current_state` explica el cómo.

La variante importada **sobrescribe `_physics_process` por completo** en vez de extenderlo. Hay una rama temprana que devuelve el control a la base cuando la presa es un niño (`_prey != _player`), porque la prioridad infantil manda sobre las reglas fotosensibles. Cualquier lógica nueva de la base que deba aplicarse a la abuela fotosensible hay que enchufarla también en ese `_physics_process`.

### Presas y prioridad

`_refresh_preferred_prey()` elige entre el jugador (grupo `player`) y los niños (grupo `child_target`, con `can_be_targeted_by_monster()`). `_prey` es el objetivo de movimiento y ataque; `_player` se conserva aparte porque las reglas fotosensibles (linterna, iluminación, cercanía) siguen midiéndose sobre el jugador aunque persiga a un niño.

### Visual: dos animadores en paralelo

- `enemies/monster_grandmother.gd::_update_animation()` anima el modelo procedural `Model` (esferas y cilindros con IK de dos huesos) **y dispara los pasos de audio** desde `_motion_phase`.
- `enemies/granny_editable_visual_animator.gd` anima el rig importado `EditableVisual/CleanModel/EditableGrannyRig`.

En `enemies/monster_grandmother_imported.tscn` el `Model` procedural está en `visible = false` pero **`_update_animation()` sigue ejecutándose**: es la fuente de los pasos de audio. El animador visual lee `_motion_phase` del cuerpo para que el bob visual y el sonido de paso caigan juntos.

**El rig importado no tiene piernas** (`granny_editable_rig.glb`: 68 nodos — torso+vestido, cabeza, brazos con dedos, ninguna pierna ni pie). El vestido llega al suelo y oculta la ausencia. Toda la sensación de caminar sale del bob vertical, el balanceo lateral y la inclinación en los giros. No intentes animar piernas que no existen.

Todas las poses del animador son **offsets sobre la transformación guardada en la escena** (`_base_*` capturados en `_ready`), para que los ajustes manuales hechos en el editor sobre `HeadPivot`, `*ShoulderPivot`, `*ElbowPivot` y `*WristPivot` no se pierdan al moverse el personaje. Si añades una pose, sigue ese patrón: nunca escribas rotaciones absolutas.

### Navegación

`systems/runtime_house_navigation.gd` (`NavigationRegion3D`) hornea el navmesh **en runtime** desde los colliders estáticos, de forma asíncrona, y emite `navigation_baked`. Nada que navegue puede asumir que la malla existe en el primer frame:

- `systems/startup_warmup.gd` congela al jugador tras una pantalla de carga hasta que el horneado termina.
- Las validaciones hacen `await navigation.navigation_baked`.
- `enemies/monster_grandmother.gd::_refresh_navigation_state()` revisa `map_get_iteration_id()` cada refresco y llama a `_on_navigation_rebuilt()` cuando cambia, para que las variantes reproyecten sus puntos de patrulla.

Nada garantiza que la presa este sobre el navmesh: el jugador puede subirse a muros y repisas. `_update_unreachable_target()` cubre ese caso comparando el final real de la ruta con el destino pedido, porque un destino en una isla de navegacion desconectada devuelve una ruta degenerada de dos puntos y "he llegado" es indistinguible de "no hay camino" si solo se mira la posicion propia.

Los cambios de planta se resuelven con un `NavigationLink3D` en `systems/runtime_house_navigation.tscn` mas los anclajes `STAIR_LOWER_ANCHOR` / `STAIR_UPPER_ANCHOR` **hardcodeados** en `enemies/monster_grandmother.gd`. Si mueves la escalera de `levels/house_baked.tscn`, hay que mover ambos.

`systems/runtime_catacomb_navigation.tscn` reutiliza el mismo script para las catacumbas, cargadas bajo demanda desde el minijuego de la iglesia.

### Puertas

**Las puertas cerradas no se hornean en el navmesh, asi que cada habitacion es una isla de navegacion separada.** Cualquier logica que exija que una ruta termine en su destino fallara para todo lo que este al otro lado de una puerta; la travesia de puertas es lo que une las islas en tiempo de ejecucion. Ojo tambien al colocar un NPC: un pasillo rodeado de `locked_door.gd` lo deja encerrado sin que nada lo advierta.

Las puertas del grupo `npc_door` exponen `ensure_open_for_npc(npc)`, `get_npc_traversal_portal() -> {center, normal, open_wait}` e `is_npc_passage_ready()`. La abuela **se compromete** al cruce: `_begin_door_traversal()` congela recálculo de ruta, evasión lateral y recuperación de atasco, y avanza en línea recta entrada → salida. `systems/npc_passage_probe.gd` comprueba si el hueco está libre. Las puertas con llave consumen la interacción sin abrirse, por eso solo se inicia el cruce si la hoja confirma `_is_open`.

### Audio

Respiración, pasos y voz de la abuela se **sintetizan en runtime** (`_make_tonal_stream()` genera PCM), no son archivos. `sounds/` contiene el resto.

Los pasos del jugador salen de `sounds/gameplay_sound_factory.gd::make_surface_footstep()`. Un paso son tres capas —golpe del talón, resonancia del material y textura del roce— cuyo reparto define `SURFACE_PROFILES`; ahí se ajusta cómo suena cada material, no en el volumen.

`player/player.gd::_classify_surface()` decide la superficie leyendo el nombre del collider pisado y dos ancestros contra `SURFACE_KEYWORDS`. **El orden de esa lista importa**: `GroundFloorSlab` es la planta baja (madera) y `GroundCutoutCollision` es el patio (tierra), así que `floor`/`slab` reclaman los suelos interiores antes de que `ground` actúe como último recurso. Para forzar un suelo concreto, añádele el grupo `surface_<tipo>`: gana sobre la heurística.

La superficie también escala el radio de `footstep_heard`, así que la moqueta esconde de verdad al jugador y la baldosa lo delata.

## Documentación viva

Los `*_AUDIT.md` / `*_REWORK.md` de la raíz son el registro de decisiones de diseño y las cifras de referencia de cada validación (`GRANDMOTHER_AI_AUDIT.md` es el más completo). Al cambiar el comportamiento de un NPC, actualiza el documento correspondiente con los números nuevos.

## Convenciones

- `project.godot` activa `gdscript/warnings/untyped_declaration=1`: **declara el tipo de cada variable** (`var x: float = 0.0` o `var x := 0.0`).
- `.gitattributes` fuerza `eol=lf` en `.gd`, `.tscn`, `.tres`, `.gdshader`, `.godot` y `.md`. No introduzcas CRLF.
- `.godot/` es caché local y no se versiona.
- El suavizado dependiente de frame se escribe `1.0 - exp(-k * delta)`, no `minf(delta * k, 1.0)`; lo segundo cambia de velocidad con los FPS.
