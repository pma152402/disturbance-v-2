# Herramientas del proyecto

- Sistema de agrupado exclusivo de sombras + oclusión real:
  [SHADOW_PIPELINE_EXPERIMENT_2026-09-14](../docs/SHADOW_PIPELINE_EXPERIMENT_2026-09-14.md).
  Integrado en `systems/runtime_shadow_pipeline.gd` y el arranque de House.
  `preview_shadow_pipeline.gd` abre una partida libre y **F7** alterna con la
  referencia; `-- --smoke` verifica activación/restauración y termina.
  `benchmark_shadow_pipeline.gd -- --only=combined` mide el recorrido; también
  admite `pipeline_baseline`, `shadow_batch`, `exact_occlusion`, `pipeline_repeat`.
  `validate_shadow_pipeline_visual.gd -- --only=combined` compara imágenes A/B/A.
  `validate_static_shadow_batch_probe.gd` y `validate_static_occluder_probe.gd`
  validan geometría y exclusiones en headless. Conserva cuatro divisiones del
  sol, la linterna, materiales visibles y colisiones.

- Segunda pasada de FPS: [PERFORMANCE_FOLLOWUP_2026-09-14](../docs/PERFORMANCE_FOLLOWUP_2026-09-14.md).
  `benchmark_ground_floor_systems.gd` aísla sombras; `-- --scripts` aísla IA,
  animaciones y lluvia. `benchmark_ground_floor_candidates.gd` compara candidatos;
  `-- --only=sun_two_splits`, `three_local_shadows`, `static_merge` o
  `candidate_baseline` permite procesos independientes. Requieren GPU y una sola
  partida abierta. No modifican recursos ni la configuración del juego normal.
  `static_geometry_merge_probe.gd` es un prototipo restaurable de agrupación;
  `validate_static_geometry_merge_probe.gd` verifica su geometría en headless.

- `benchmark_ground_floor_gameplay.gd`: recorre aparición → lavadora con jugador,
  cámara, IA y física reales, a la resolución de la ventana. Compara madera
  puesta/oculta/restaurada; `-- --batching` compara la nueva agrupación estática.
  Guarda tiempos por fotograma, trayectorias y capturas en `output/`.
  `validate_ground_floor_batching.gd`: verifica geometría, materiales, sombras,
  CSG, colisiones y exclusiones, más la integración en la partida. Requiere GPU.

- Auditoría del 14 de septiembre: resultados medidos, cambios conservadores y
  sistemas propuestos en [PERFORMANCE_AUDIT_2026-09-14](../docs/PERFORMANCE_AUDIT_2026-09-14.md).
  `benchmark_house_plank_floor.gd` compara suelo original, oculto y material simple
  dentro de la misma escena. `-- --all` combina cuatro vistas y sombras en una sola
  carga con la cámara del jugador. `-- --lit` usa la linterna real; `-- --close` mira
  directamente la tarima; `-- --shadows` aísla sombras sólo en el diagnóstico.
  `run_optimization_check.ps1 -Script res://tools/<script>.gd` ejecuta las pruebas
  con timeout y logs, sin cerrar otros procesos de Godot.
- `validate_procedural_mesh_cache.gd`: GPU real; equivalencia byte por byte de
  mallas, invalidación de caché y cuatro pasadas A/B de CPU.
  `validate_shadow_idle_processing.gd`: selección y transiciones de sombras
  idénticas a 30/60/120 FPS, incluyendo reposo. `validate_idle_secondary_systems.gd`:
  reactivación y tiempos de alertas, TV, spinner y trípode. Estas dos últimas
  funcionan en headless. El inventario de rendimiento distingue ahora mallas
  visibles en árbol y scripts que pueden procesar de sus flags locales.

- `validate_house_plank_floor.gd`: verifica la capa desmontable de tablones,
  sus recortes, colisiones originales y huecos. `render_house_plank_floor.gd`
  revisa la integracion en el salon real. Detalles en
  [HOUSE_PLANK_FLOOR](../docs/HOUSE_PLANK_FLOOR.md).

- `generate_catacombs.py`: regenera `church_catacombs.tscn`. La casa lo carga
  al iniciar el minijuego de BoardedLabyrinthAccess (entrada de la iglesia),
  junto con su navegacion. No se instancia al arrancar ni en el editor.
- `validate_deferred_content_and_batching.gd`: valida carga diferida, cancelacion,
  reintento y navegacion, y compara geometria, materiales, transformaciones y
  colisiones antes/despues de agrupar decoracion. Ejecutar sin `--headless`:
  el renderizador dummy no conserva las matrices de MultiMesh.
- `split_graffiti_sheets.py`: recorta las hojas maestras en texturas individuales.
- `validate_catacombs.gd`: comprueba geometria y navegacion hasta la cripta.
- `validate_labyrinth_barricade.gd`: comprueba palanca, tablones e inventario.
- `validate_camera_tripod.gd`: comprueba recogida con F, colocacion exclusiva
  con LMB, superficie invalida, cursor liberado, minijuego y montaje de camara.
  Ejecutar sin `--headless`: el servidor dummy no captura el raton.
- `validate_player_tripod_grip.gd`: 60 muestras de contacto del tripode con la
  palma, reequipado, vista externa y selfie sin dedos. `-- --render` guarda
  una captura en `tools/output/player_tripod_grip.png` (sin `--headless`).

Las hojas maestras permanecen en `assets/graffiti_sheets`, ignoradas por Godot
pero accesibles para el script de recorte.

Los modelos que aparecen en las manos del jugador se agrupan en
`player/held_items`, y los scripts de cada objeto permanecen junto a su escena
en `house_props`.

## Organización y resultados

- Los scripts validate_* y check_* son validaciones reutilizables; audit_* e inspect_* son diagnósticos.
- fixtures/ conserva las referencias JSON necesarias para las pruebas.
- output/ contiene capturas e informes regenerables. Está excluida de Git y de la importación de Godot; conservar su .gdignore.
- Los constructores build_* y las migraciones restantes modifican escenas: no ejecutarlos como una suite de pruebas.
- validate_resource_paths.ps1 comprueba referencias literales sin iniciar Godot.
- run_performance_benchmark.ps1 mide casa, iglesia, patio, escuela y sotano con
  tres pasadas deterministas, guarda medianas y compara automaticamente contra
  un baseline. Vease ../docs/PERFORMANCE_BENCHMARK.md.

Véase ../docs/CLEANUP_2026-09-08.md para el detalle de la limpieza.

## Auditoría de grabación y HUD

- `validate_camera_observer_audit.gd`: 31 comprobaciones del Observador: catálogo
  dinámico, colisiones de decoración, luces, oclusión, encuadre y entradas disabled.
- `benchmark_observer_triangles.gd`: comparación de consultas por caras y árbol
  nativo, con igualdad de resultados y conservación de huecos.
- Revisión conjunta de la vieja/Observador, retirada del prototipo y límites del
  análisis histórico: `../docs/GRANDMOTHER_OBSERVER_AUDIT_2026-09-14.md`.
- `run_recording_benchmark.ps1`: compara STBY, grabación síncrona y asíncrona
  alternadas dos veces y STOP en cinco zonas, con renderizado real. `-WalkingHud`
  mantiene animado el indicador de postura. Guarda `output/recording_current.json`.
- `validate_async_recording.gd`: requiere GPU; compara JPEGs byte a byte y comprueba
  START repetido, carreras STOP/START y cierre de escena con lectura pendiente.
- `validate_stance_raster_performance.gd`: funciona con `--headless`; compara 195
  máscaras con la referencia original y mide el coste de dibujar el HUD.

Resultados, alcance y limitaciones: `../docs/PERFORMANCE_AUDIT_2026-09-10.md`.

## Visibilidad desde ventanas

`House.full_startup_visibility` está activado por defecto. Mantiene iglesia,
escuela, tendederos y exterior sin recortes de distancia y desactiva los
oclusores automáticos basados en cajas de colisión, que tapaban vistas por las
ventanas. Conserva agrupación de mallas, presupuesto de sombras y las mejoras
del HUD y de la grabación. El sótano sigue oculto hasta abrir su puerta (sus
colisiones y recursos siguen en la escena); el laberinto sí se carga a demanda.

`validate_full_startup_visibility.gd` comprueba esta política y sus excepciones.
Desactivar `full_startup_visibility` en House antes de arrancar recupera el modo
de recortes anterior para comparar. Los benchmarks anteriores a este cambio
corresponden a ese modo y no deben confundirse con el escenario visible completo.

## Nueva abuela de la iglesia

- `validate_church_grandmother.gd`: percepción, memoria, oído, búsqueda, bloqueos,
  ataques esquivables y persecución real; ejecutar con `--headless`.
- `validate_grandmother_obstacle_jump.gd`: salto seguro de obstáculos bajos y
  rechazo de paredes altas.
- `validate_church_grandmother_altar_jump.gd`: aproximación frontal en el nivel
  real de la variante original, con IA completa: salto junto al mueble del altar
  y aterrizaje sin falsa transición de planta.
- `validate_grandmother_jump_chain.gd`: siete gradas consecutivas; verifica el
  máximo de seis saltos seguidos, pausa posterior, orientación y punto de recepción.
- `validate_granny_overhead_attack.gd`: trayectoria completa de ambos ataques a
  30/60/120 FPS, codos y manos por delante, anticipación sobre la cabeza y brazos
  altos en persecución. `-- --child` comprueba el ataque a otro objetivo;
  `-- --render` genera secuencias laterales reales, sin congelar cada pose.
- Las pruebas de `grandmother_arm_continuity`, `grandmother_door_traversal`,
  `grandmother_child_priority` e `imported_grandmother_eating` aceptan `-- --church`
  para comprobar esta variante conservando sus casos anteriores por defecto.
- `audit_church_grandmother_runtime.gd`: nivel real, traza de decisiones y tiempo
  CPU del controlador/animador. `-- --legacy` compara el comportamiento anterior;
  `-- --search` prueba 40 s con ocultación del jugador. Resultados en `output/`.
- `render_church_grandmother.gd`: seis poses con GPU; `-- --back` muestra la espalda.
- `validate_granny_surfaces.gd`: subida, inversión, aterrizaje, ausencia de apoyo,
  pérdida de memoria y golpes descendentes con ambos brazos. `-- --church` usa
  las colisiones de paredes y bóveda del nivel y comprueba movimientos continuos.
- `render_church_grandmother.gd -- --surfaces`: poses de pared, techo y descenso.
- `bake_church_vault_collisions.gd`: añade una sola vez ocho hulls convexos que
  coinciden con la bóveda visible, incluyendo sus transformaciones deformadas.
  Las colisiones ya están guardadas en `house_baked.tscn`; no ejecutarlo al jugar.
  Usan la capa física 20, reservada para apoyos de escalada y excluida del
  horneado de navegación del suelo.

La escalada se activa durante una búsqueda/persecución con pistas recientes y
pared cercana. Solo acepta apoyos estáticos, adapta la orientación a techos
inclinados y suelta el apoyo al perder la pista, encontrar un borde u obstáculo,
acercarse al destino o agotar la excursión (12 s; máximo 5 s sobre el techo).
Después del aterrizaje retoma la investigación y espera 10 s antes de volver a
trepar. `can_climb` permite desactivarlo y `climb_speed` ajusta la velocidad.

Auditoría, parámetros y límites: `../docs/CHURCH_GRANDMOTHER_AUDIT_2026-09-10.md`.

## Saltos de la variante trepadora

- `validate_crawler_recovery_timing.gd`: bloqueo físico en 0,8 s, órbita sin
  progreso en 1,5 s; no interrumpe avance, desvíos válidos ni pausas de ataque.
- `validate_crawler_church_spider_escape.gd`: seis saltos encadenados entre los
  bancos reales, destinos seguros, orientación final y continuidad física.
- `validate_crawler_jump_safety.gd`: cápsula barrida, obstáculos móviles, techo
  bajo, cancelación y retroceso; orientación y pies desplegados antes de recibir
  el peso a 30/60/120 FPS.
- `validate_crawler_spider_jump.gd`: preparación, alcance, cadenas de uno a seis,
  reanudación de persecución y exclusión de muebles como destinos.
- `validate_grandmother_door_traversal.gd -- --crawler`: cruce de puerta normal
  y doble con la variante activa, en ambos sentidos. La prueba histórica de
  prioridad infantil se omite explícitamente si el NPC niño está retirado.
- `audit_crawler_pursuit_stability.gd`: 60 s de persecución con IA completa en dos
  pasillos de la iglesia. `-- --trace` añade el motivo y posición de cada escape.

Parámetros y resultados: `../docs/CRAWLER_STABILITY_AUDIT_2026-09-13.md`.

## Escuela terminada: tres plantas

- `validate_school_completion.gd`: puertas abiertas, pasos con cápsula del jugador,
  paredes y techos, refugios de lluvia, vegetación, nueve salas nuevas y mobiliario
  existente. Recorre ambas escaleras en los dos sentidos y el acceso al escenario.
  `-- --navigation` comprueba diez destinos conectados entre las tres plantas.
  `-- --preview` requiere GPU y guarda seis vistas en `output/school_finished_*.png`.
- `build_school_completion.gd`: reconstruye **solo** la ampliación editable
  `environment/school_completion.tscn` e integra sus huecos de acceso. Sobrescribe
  los cambios manuales hechos dentro de esta ampliación; no ejecutarlo para jugar.
- `validate_school_weather_access.gd` y `validate_full_startup_visibility.gd`
  incluyen los interiores nuevos y su presencia desde el inicio.

Distribución y decisiones de integración: `../docs/SCHOOL_COMPLETION.md`.
