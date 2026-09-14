# Auditoría de rendimiento: suelo, sombras y sistemas recientes

14 de septiembre de 2026. Godot 4.7.2, Windows, Vulkan Forward+, NVIDIA RTX 4090.

## Resultado principal

Las pruebas realizadas no reproducen una caída importante atribuible a la capa
de madera. Ocultarla y sustituir únicamente su material tienen un efecto pequeño
e inconsistente frente a repetir el estado original. La mayor carga aislada en
estas vistas corresponde al renderizado de sombras: multiplican la geometría que
se prepara y dibuja, incluso con una GPU potente.

Se aplicaron mejoras conservadoras de CPU, reposo de componentes y registro de
reflejos. Se conservaron el suelo, sus materiales, luces, sombras, resolución,
postprocesado, visibilidad completa, IA y tiempos de las interacciones.
El ahorro de CPU de las mallas está medido; no equivale a haber eliminado el
cuello de botella principal del renderizado ni a un porcentaje global de FPS.

## Método y límites de atribución

- Auditoría paralela de render/geometría, IA/física/animación y sistemas secundarios.
- Inventario real de `levels/test.tscn`, lectura de código, revisión de cambios
  locales y comparación de implementaciones contra referencias independientes.
- Benchmark general inicial: cinco zonas, tres pasadas de 240 frames. Se conserva
  en `tools/output/audit_20260914_before.json`.
- Diagnóstico específico del suelo dentro del mismo proceso: original → oculto →
  material simple → original, dos veces por cámara, 90 frames de estabilización y
  120 medidos por variante en la comparación final conjunta (240 en las pruebas
  exploratorias). Cámaras a FOV 95, 1920×1080, escala 3D 0,75 y VSync desactivado.
  La comparación final usa la máscara y los planos de la cámara del jugador,
  conserva el offset original de su linterna e incluye mirar al suelo de cerca.
  Las primeras pruebas heredaban una cámara con todas las capas y alcance 80 m:
  esos resultados se conservan como exploratorios, no se usan en las tablas finales.
- IA, animadores descendientes, cuerpos y relámpagos congelados en el diagnóstico
  gráfico. Esto aísla el renderizado; no certifica FPS durante persecución,
  vómito, grabación o movimiento del jugador. La animación se comprueba aparte.
- Los tiempos de proceso/física de `Performance` y los timestamps GPU son
  monitores distintos, con diferentes intervalos de actualización. No se suman
  entre sí ni al tiempo real entre frames. La comparación principal utiliza
  tiempo de frame, p95 y llamadas de dibujo.
- El equipo tenía procesos de Godot abiertos. Se conservaron. Durante el trabajo
  aparecieron además cambios ajenos a esta auditoría, incluida otra criatura en
  `levels/test.tscn`. Por eso no se atribuye la diferencia entre dos ejecuciones
  generales a nuestras optimizaciones. Las comparaciones A/B dentro de una misma
  escena cargada y contra fixtures sí permiten aislar lo que cambian.
- El baseline histórico del 10 de septiembre es anterior a la visibilidad
  completa y a nuevo contenido; sus porcentajes automáticos no son una medida
  válida de esta intervención. No se ha sustituido ese baseline.

## Suelo: geometría, textura y shader

`environment/house_plank_floor.gd` genera al cargar **11 paneles, 290 triángulos y
811,25 m²**. No tiene callbacks de proceso/física ni colisiones propias y todos
los paneles comparten material. El recorte evita solapes y conserva escaleras y
losas. `Madera4.jpg` mide **256×256**, pesa **12.964 bytes**, está comprimida para
VRAM con S3TC y tiene mipmaps. Reducir nodos, polígonos o comprimir más esa textura
no presenta un margen relevante.

El shader tiene cinco hashes trigonométricos, varias operaciones de juntas y
clavos y una lectura anisotrópica. Las UV de la veta saltan entre tablones: unas
derivadas explícitas podrían mejorar su filtrado, pero también cambiarlo. No se
aplica esa modificación sin un beneficio demostrado y una comparación visual.

Resultado final con la linterna real encendida, en ms por frame. Cada cifra es
la mediana de las medianas de las pasadas; «original» incluye sus repeticiones.

| Vista | Suelo original | Capa oculta | Mismo suelo con material simple |
|---|---:|---:|---:|
| Salón | 6,065 | 6,235 | 6,486 |
| Reja | 4,549 | 4,501 | 4,576 |
| Planta superior | 9,270 | 9,278 | 9,372 |
| Mirando al suelo de cerca | 4,969 | 4,916 | 5,152 |

La vista cercana confirma que la prueba también cubre la tarima ocupando la
imagen delante de la cámara. El coste sigue dominado por otros pases de la escena.
La máscara real copiada en esta ejecución es 524285, con planos 0,05–4000 m.
Datos finales completos: `tools/output/house_plank_floor_benchmark_lit_all.json`.

Las diferencias pequeñas, que incluso cambian de signo, no prueban un ahorro
del material simple. No descartan un problema en otro encuadre o una primera
compilación de shader; sí descartan atribuirle por estos datos toda la caída de
las vistas ensayadas. Las capturas de cada variante quedan junto a los JSON.

## Coste de sombras aislado

La siguiente prueba conserva suelo e iluminación y desactiva exclusivamente las
sombras dentro de la instancia de diagnóstico. **No es una configuración aplicada
al juego ni una ganancia prometida conservando el aspecto.** El original se mide
antes y después de cada variante para detectar deriva del equipo.

| Vista con linterna | Original, ms | Sin sombras, ms | Llamadas originales | Sin sombras |
|---|---:|---:|---:|---:|
| Salón | 6,065 | 1,891 | 9.374 | 1.667 |
| Reja | 4,549 | 1,618 | 5.633 | 1.536 |
| Planta superior | 9,270 | 3,198 | 12.447 | 2.865 |
| Mirando al suelo de cerca | 4,969 | 0,919 | 9.237 | 175 |

Son medianas de las medianas de cada pasada; el original incluye sus repeticiones.
En la planta superior, CPU de render baja aproximadamente de **6,913 a 2,075 ms**.
La diferencia se concentra en preparar y dibujar geometría para las sombras.
La actuación prioritaria es agrupar geometría compatible y mejorar qué geometría
realmente oculta se descarta, conservando los mapas y el resultado de iluminación.

Datos: `tools/output/house_plank_floor_benchmark_lit_all.json`. La ejecución
conjunta final completó todas sus variantes sin errores de script. Los informes
`*_pre_camera_fix.json` y las cargas intermedias fallidas no sustentan estas tablas.

## Optimizaciones implementadas

| Sistema | Cambio | Evidencia |
|---|---|---|
| Piel de la trepadora | Caché de UV, índices, trigonometría y perfil; reserva de buffers; omite normales que se sobrescribían | 845 comparaciones de geometría contra originales, incluidos radios mutables e invalidación |
| Brazos continuos | Reutiliza radios, UV y trigonometría; estrechamiento una vez por anillo | Vértices, normales, UV, índices, materiales y AABB iguales byte por byte |
| Controlador de sombras | Procesa sólo luces en transición y duerme al estabilizarse | 68.768 comprobaciones a 30/60/120 FPS, misma selección y opacidad |
| HUD de alertas | Duerme cuando no quedan temporizadores; cambios de estado lo reactivan | Prioridades, cooldowns, condiciones persistentes y pulso conservados |
| TV, spinner y trípode | Duerme TV apagada, spinner oculto y contador agotado | Fotogramas, fase, bloqueo de 0,5 s y gravedad real comprobados |
| Reflejos | Calcula el frustum una vez por selección; registro diferido por ID válido | Superficies, posturas, oclusión y altas/bajas comprobadas |

Los snapshots de radios se duplican sólo al invalidar el perfil para que un
buffer reutilizado por el llamante no altere la caché. La revisión independiente
detectó este caso y se añadió su regresión. También se reprodujo y corrigió un
error de registro de reflejos cuando el agrupador libera una malla antes de que
se ejecute su llamada diferida.

Medianas de cuatro pasadas A/B sobre los mismos generadores, en milisegundos por
operación; incluyen preparación/envío desde la llamada, no tiempo GPU completado:

| Operación aislada | Anterior | Optimizada | Menos tiempo CPU |
|---|---:|---:|---:|
| Construir superficie de prueba | 0,062963 | 0,031446 | 50,1 % |
| Actualizar brazo de prueba | 0,050979 | 0,028054 | 45,0 % |

Son mejoras de rutinas concretas, de décimas de milisegundo acumuladas por actor;
**no significan un 50 % más de FPS**. Se sigue animando a la misma frecuencia y
creando superficies dinámicas; mantener sus buffers es una oportunidad posterior.

Archivos de juego cambiados en esta intervención: `enemies/crawler_surface_mesh.gd`,
`enemies/granny_continuous_arm.gd`, `systems/runtime_render_optimizer.gd`,
`systems/camera_context_alerts.gd`, `systems/camera_tape_spinner.gd`,
`systems/subtle_player_reflections.gd`, `house_props/large_tv.gd` y
`house_props/camera_tripod.gd`. Los cambios preexistentes y concurrentes se conservan.

## Inventario útil para la siguiente fase

El último inventario registra **16.390 nodos, 10.938 MeshInstance3D, 607 MultiMesh,
1.410 formas de colisión y 129 luces**. De las mallas, **7.863** están visibles en
el árbol y **528** MultiMesh están visibles. Esto no equivale a objetos dentro del
frustum ni a llamadas de dibujo: hay pases, sombras, instancias y mallas ocultas.
La instantánea se conserva en `tools/output/audit_20260914_final_inventory.json`;
el contenido concurrente puede haber cambiado después de capturarla.
Se han añadido al inventario la visibilidad y `can_process()`, que excluye scripts
heredados de ramas desactivadas aunque su flag local siga activo.

| Rama | Mallas cargadas | Visibles en árbol |
|---|---:|---:|
| FurnitureAndPickups | 1.522 | 1.121 |
| UpperFloor | 798 | 701 |
| NewFrontHouseDecor | 637 | 637 |
| SchoolUpperFloor | 1.667 | 632 |
| SchoolCompletion | 1.277 | 486 |

La escuela ya agrupa geometría y mantiene los originales ocultos. No corresponde
sumar todos esos nodos como trabajo visible. La hierba y árboles ya usan celdas
MultiMesh; la lluvia actual tiene un emisor de 480 partículas sin sombras; el
postprocesado VHS ya está combinado. El audio, pasos sintetizados, varios objetos
inactivos y la compresión de grabación ya incorporaban optimizaciones. La longitud
de un script o el tamaño de una carpeta no mide su coste por frame.

## Sistemas propuestos, por prioridad

Las siguientes intervenciones están ordenadas por su capacidad de retirar trabajo repetido conservando el resultado. Son propuestas pendientes de medición y validación; no representan incrementos de FPS ya obtenidos. La aceptación debe comparar la misma escena, cámara, estado y secuencia de acciones, e incluir p95/p99 para detectar tirones que la media oculta.

1. **Agrupación local por material compatible.** `systems/static_decor_batcher.gd:56` agrupa hermanos que comparten el mismo recurso de malla y propiedades de render, dentro de una lista limitada de decoraciones estáticas. Quedan piezas geométricamente distintas que podrían compartir una superficie por material y habitación. El siguiente agrupador debe transformar vértices y normales correctamente, conservar UV, capas, sombras y materiales, y mantener separados los límites de habitación, visibilidad e interacción. Las piezas editables y los colliders originales deben conservar su identidad; la sustitución visual se genera al ejecutar. Un grupo enorme puede impedir descartar piezas ocultas, por lo que también necesita un tamaño espacial máximo. Aceptación: ampliar `tools/validate_deferred_content_and_batching.gd`, contrastar triángulos/materiales/transformaciones y capturas con luces encendidas, sombras y puertas abiertas/cerradas. Medir reducción de llamadas de dibujo sin aumentar el trabajo visible en otras vistas. Objetivo: **FPS continuos**, principalmente coste de envío de geometría.

2. **Buffers persistentes para la piel de la trepadora.** La caché implementada reduce cálculos, pero `enemies/crawler_surface_mesh.gd:109` y `enemies/granny_continuous_arm.gd:108` siguen borrando y recreando superficies durante la animación. Torso, cuello, piernas y dos brazos suman ocho superficies potenciales por tick. Con topología fija se pueden conservar índices, UV y superficies, actualizando sólo posiciones y normales mediante buffers preparados para ello. Los límites de culling deben actualizarse con la geometría real. Mantener frecuencia, articulación, materiales, sombreado y conexión de extremidades; cambiar a otro modelo de deformación necesita una comprobación independiente. Aceptación: extender las comparaciones exactas de `tools/validate_procedural_mesh_cache.gd`, incluir AABB y material, inspeccionar suelo/pared/techo, ataque y vómito, y medir CPU y render con el enemigo activo. Objetivo: **FPS continuos** y menos asignaciones/subidas durante la animación.

3. **Consultas físicas compartidas dentro de una operación.** `enemies/grandmother_crawler.gd:100`, `grandmother_crawler_traversal.gd::step` y `crawler_collision_guard.gd::sweep` comprueban repetidamente la cápsula; algunas comprobaciones son necesarias porque la orientación cambia entre ellas. Introducir un contrato de pose validada permite eliminar únicamente repeticiones equivalentes, con invalidación al mover, rotar o cambiar cápsula/máscara. Además, `crawler_vomit_stream.gd:46` consulta ocho rayos por anillo: una prueba envolvente conservadora podría descartar anillos completamente libres antes de lanzar sus rayos. No reducir cadencia de colisión ni trasladar consultas sobre el mundo vivo a trabajadores. Aceptación: comprobar mismos contactos, alcance, daño, manchas, tiempos y ausencia de penetraciones en las validaciones de recuperación, esquinas, salto y `validate_vomit_continuous_stream.gd`; medir consultas por tick y p99. Objetivo: **picos durante saltos y coste continuo durante vómito**.

4. **Oclusión derivada de arquitectura real y sus huecos.** `systems/full_startup_visibility.gd:13` desactiva la oclusión para conservar las vistas por ventanas. El constructor de `runtime_occlusion_builder.gd` usa cajas conservadoras y exclusiones por nombre; reactivarlo directamente no demuestra que todos los huecos queden respetados. Crear oclusores sólo desde superficies opacas verificadas, recortados en ventanas, puertas, balcones y pasos. Mantener cámaras de grabación, pistas especiales, sombras y vistas entre edificios; las puertas móviles necesitan estado propio. Aceptación: ampliar `tools/validate_full_startup_visibility.gd` con cámaras a ambos lados de cada abertura, desplazamientos continuos y capturas de cinta, además de comparar imágenes y objetos descartados. Objetivo: **FPS continuos en interiores**, condicionado al coste de mantener los oclusores y a que exista geometría realmente tapada.

5. **Carga anticipada de catacumbas por proximidad.** `systems/wall_band_applier.gd:49` carga e instancia las catacumbas y su navegación de forma síncrona cuando la puerta llama a `ensure_church_catacombs()` (`house_props/catacombs/boarded_labyrinth_door.gd:93`). Solicitar los recursos en segundo plano al aproximarse al acceso permite adelantar lectura y preparación, manteniendo la activación del contenido en el momento actual. Instanciar y registrar la escena sigue teniendo coste propio: medirlo por separado y preparar bloques durante una transición sólo si no cambia visibilidad ni actividad. Aceptación: `validate_catacombs.gd`, `validate_labyrinth_barricade.gd` y carga diferida, incluyendo aproximación, retirada, reentrada y fallo de carga. Objetivo: **menor tirón al acceder**, con presupuesto de memoria y sin prometer más FPS estables.

6. **Registro incremental del Observador.** `systems/camera_observer.gd:276` ya concentra el inventario en un recorrido, pero las altas/bajas invalidan el catálogo completo y el intervalo también puede renovarlo. Registrar únicamente ramas añadidas/retiradas y mantener índices de luces, observables y oclusores evita recorrer todo el árbol cuando cambia una pieza. Conservar un refresco explícito para cambios de geometría/material, mundo, capas o reparentado que no equivalen a altas/bajas. Aceptación: `validate_deferred_camera_observer.gd`, `validate_camera_observer_audit.gd` y `validate_camera_observer_occlusion.gd`, comparando catálogo, evidencia e iluminación tras carga diferida y cambios de escena. Objetivo: **picos de inventario y coste mientras el análisis está activo**.

7. **Decodificación anticipada del archivo de cámara.** La compresión de grabación ya utiliza trabajadores en `systems/tape_frame_readback.gd:51`; el coste pendiente es `Image.load_jpg_from_buffer()` en `systems/found_footage_overlay.gd:875`, al mostrar cada fotograma. Mantener una caché pequeña del actual y siguientes, decodificados anticipadamente, con identificador de cinta/sesión para descartar resultados antiguos. Subir la textura en el hilo correspondiente, preservar orden, controles y tiempos, y conservar respuesta inmediata si se salta a un fotograma no preparado. Aceptación: ampliar `tools/validate_camera_recording_playback.gd` con saltos, reversa, borrado y cambios de cinta, comparar píxeles y limitar memoria. Objetivo: **menos tirones al reproducir y navegar por grabaciones**.

**Contenido añadido concurrentemente: ShadowCrawler.** Durante la auditoría se integró otra criatura y cambiaron sus controladores de postura, huida y animación. El inventario capturado añade 133 mallas y un CharacterBody respecto al inicial; no se atribuye ese coste a nuestras optimizaciones. Dos cargas intermedias produjeron errores de contrato entre controlador y animador (upright_amount), y una versión intermedia también tuvo un error de tipo. Sus benchmarks se descartaron. La propiedad reapareció en el desarrollo concurrente, sin modificar nosotros esa lógica. Una prueba independiente sobre la versión fresca superó 124 comprobaciones de nueve poses. La magnitud del coste de esta criatura requiere una medición con su diseño estabilizado; las cachés de malla compartidas también se aplican a las variantes que las heredan.

## Validaciones ejecutadas

- `validate_procedural_mesh_cache.gd`: 845 comparaciones; cero fallos; A/B sobre GPU real.
- `validate_shadow_idle_processing.gd`: 68.768 comprobaciones, 30/60/120 FPS.
- `validate_shadow_budget.gd`: 12 luces, alcance 24–32 m, histéresis y transiciones.
- `validate_idle_secondary_systems.gd`: alertas, TV, spinner y física del trípode.
- `validate_subtle_player_reflections.gd`: GPU real, incluidas altas/bajas diferidas.
- `validate_shadow_animation_contract.gd`: 124 comprobaciones, nueve poses de la
  versión fresca de la nueva criatura; sin modificar su lógica concurrente.
- `validate_grandmother_crawler.gd`: GPU real, 2.199 muestras; cero fallos;
  error máximo de contacto 0,000022 m; suelo, techo e inversión.
- `validate_full_startup_visibility.gd`: iglesia, escuela, exterior y ventanas;
  sótano condicionado por puerta y laberinto ausente al iniciar.
- `validate_house_plank_floor.gd`: 5.088 muestras sin solapes; colisiones y huecos.
- `git diff --check`: sin errores de espacios; avisos de finales de línea en
  archivos que ya estaban modificados antes de esta auditoría.

Los logs headless incluyen el aviso preexistente de certificados de Windows;
las pruebas de escena completa también pueden informar de recursos pendientes al
cerrar. No se han interpretado esos avisos como caídas de FPS. El error diferido
de reflejos sí se corrigió y su prueba final pasó.

## Reproducir

```powershell
# Comparación final conjunta: suelo y sombras, cuatro vistas en el mismo proceso
powershell -ExecutionPolicy Bypass -File tools/run_optimization_check.ps1 -Script res://tools/benchmark_house_plank_floor.gd -ScriptArguments --all

# Suelo: original/oculto/material simple/original, dos veces en cada vista
powershell -ExecutionPolicy Bypass -File tools/run_optimization_check.ps1 -Script res://tools/benchmark_house_plank_floor.gd -ScriptArguments --lit

# Misma escena con sombras temporalmente desactivadas, sólo diagnóstico
powershell -ExecutionPolicy Bypass -File tools/run_optimization_check.ps1 -Script res://tools/benchmark_house_plank_floor.gd -ScriptArguments --shadows

# Vista cercana mirando directamente a la tarima con linterna
powershell -ExecutionPolicy Bypass -File tools/run_optimization_check.ps1 -Script res://tools/benchmark_house_plank_floor.gd -ScriptArguments --close

# Equivalencia exacta y microbenchmark de mallas
powershell -ExecutionPolicy Bypass -File tools/run_optimization_check.ps1 -Script res://tools/validate_procedural_mesh_cache.gd
```

El ejecutor tiene timeout, guarda logs y sólo detiene el proceso que él ha creado.
Los JSON conservan todas las pasadas y el hardware. Para una referencia de FPS
jugables reproducible queda ejecutar un recorrido exportado con IA, luces,
movimiento y grabación controlados, una vez estabilizados los cambios concurrentes.

## Ampliación: recorrido desde aparición hasta lavadora

La localización indicada por el usuario se midió también con
`tools/benchmark_ground_floor_gameplay.gd`: cámara original, resolución de ventana
3440 × 1364, linterna encendida, IA y física activas. Cada variante reconstruye
la partida con la misma semilla; el jugador camina mediante las acciones reales
de entrada, siguiendo la navegación. Las tres pasadas recorrieron 13,543 m,
alcanzaron el destino navegable ante la lavadora y terminaron sin muerte.

| Variante | Aparición quieto, mediana ms | Recorrido, mediana ms | Recorrido p95 ms |
|---|---:|---:|---:|
| Madera original | 11,730 | 10,114 | 13,277 |
| Capa de madera oculta | 12,843 | 10,138 | 13,870 |
| Madera restaurada | 13,057 | 10,469 | 13,952 |

En la aparición se registraron aproximadamente 13.700 draw calls, 8,2–9,0 ms
de preparación/render en CPU y 3,1–3,4 ms de marcas GPU. El cuello de botella
observado apunta al envío de geometría, mientras que ocultar la madera no
recupera los FPS del recorrido. Esto no identifica por sí solo el origen de
una regresión histórica: no se dispone de una partida anterior equivalente.
La IA y el clima siguen activos, por lo que hay variación entre pasadas.
Había dos validaciones headless de otras tareas abiertas durante la medición;
los tiempos absolutos no deben tratarse como rendimiento aislado del equipo.

Los datos por fotograma, trayectorias y condiciones están en
`tools/output/ground_floor_gameplay.json`; las capturas `gameplay_*` permiten
comprobar la cámara y que las variantes cambian realmente el suelo.

### Agrupación conservadora aplicada tras localizar el recorrido

Se amplía `static_decor_batcher.gd` con seis escenas de decoración fija:
cesta de ropa, toallero, maniquí, escurreplatos, horno y zapatero. Sólo se agrupan
hermanos opacos que comparten malla, materiales y estado de render. Las nuevas
MultiMesh conservan explícitamente las sombras originales: el optimizador no
les aplica su eliminación de sombras de herrajes pequeños. Los scripts, cuerpos
móviles, animaciones, transparencias y CSG quedan fuera de la agrupación.

`validate_ground_floor_batching.gd` pasó 629 comprobaciones con GPU, incluyendo
integración en la partida: 20 grupos nuevos. Los seis recursos aislados ahorran
68 instancias en total; esta cifra no equivale a draw calls ahorradas por frame.

La comparación A/B/A con madera siempre visible dio 10,501 / 10,168 / 9,972 ms
de mediana durante el recorrido (agrupación desactivada / activada / desactivada).
No demuestra una mejora de FPS separable del ruido. Por tanto, se conserva como
reducción de instancias verificada, **no como solución demostrada a la caída fuerte**.
Los datos están en `tools/output/ground_floor_gameplay_batching.json`.

Repetir ambas comparaciones:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_optimization_check.ps1 -Script res://tools/benchmark_ground_floor_gameplay.gd
powershell -ExecutionPolicy Bypass -File tools/run_optimization_check.ps1 -Script res://tools/benchmark_ground_floor_gameplay.gd -ScriptArguments --batching
powershell -ExecutionPolicy Bypass -File tools/run_optimization_check.ps1 -Script res://tools/validate_ground_floor_batching.gd
```

## Referencias técnicas de las propuestas

La agrupación debe ser local porque el descarte se aplica al MultiMesh completo:
[documentación de MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html).
La propuesta de superficies persistentes se apoya en las operaciones de
[ArrayMesh](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html).
La carga en segundo plano requiere comprobar que el recurso esté listo antes de
recuperarlo para evitar otra espera:
[carga asíncrona](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html).
Preparar datos fuera del hilo principal no permite manipular libremente el árbol
activo o la GPU desde trabajadores:
[API y seguridad entre hilos](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html).
