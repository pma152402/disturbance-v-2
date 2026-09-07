# Auditoría de rendimiento

Medición local del 4 de septiembre de 2026, Godot 4.7.2, Vulkan Forward+ y ventana de prueba 1280×720. La tasa quedó limitada a 120 FPS en la máquina de medición; por ello se comparan también draw calls, objetos y triángulos visibles.

## Coste encontrado

- Escena completa: 8.644 `MeshInstance3D`, 678.893 triángulos almacenados, 85 luces y 65 luces configuradas con sombras. Tras ejecutar los scripts de encendido, 21 luces estáticas encendidas quedan gestionadas.
- Colegio: 1.617 mallas, 85.864 triángulos y 11 luces; las 11 tenían sombras. Una luz puntual con sombras puede necesitar seis vistas de sombra y repetir muchas de esas mallas.
- Lluvia: cuatro emisores, 8.800 partículas y simulación a 60 Hz.
- La fragmentación en miles de nodos pesa más que el número de triángulos. Se conserva porque las piezas deben seguir editables.

## Soluciones aplicadas

- `runtime_render_optimizer.gd` actúa únicamente al jugar. Añade distancia de visibilidad a 6.947 detalles pequeños, excluyendo puertas y cuerpos móviles. Los nodos siguen separados y editables en el proyecto.
- Las luces puntuales usan desvanecimiento a distancia. Solo las dos luces con sombra más cercanas a la cámara mantienen sombras, con actualización cada 0,18 s; las demás siguen iluminando. El estado encendido/apagado que controlan otros scripts se respeta.
- Las lámparas colgantes combinaban un `OmniLight3D` con sombra (seis caras) y un foco inferior con sombra (una pasada). Al jugar se conserva la sombra dirigida del foco y se desactiva la sombra omnidireccional redundante: cada lámpara encendida pasa de siete pasadas potenciales a una.
- Sombras posicionales: filtro bajo y atlas 2048. Sombra direccional: filtro medio y mapa 2048.
- MSAA pasa de 4× a 2× y se añade FXAA para suavizar el borde restante.
- Lluvia reducida de 8.800 a 4.800 partículas y de 60 a 30 Hz de simulación. Se mantiene su aspecto denso mediante la vida y velocidad existentes.

## Comparación reproducible

Vista interior del colegio, misma cámara y 180 fotogramas:

| Métrica | Sin culling | Optimizado | Cambio |
|---|---:|---:|---:|
| Draw calls | 3.977 | 1.965 | -50,6 % |
| Objetos renderizados | 5.871 | 3.048 | -48,1 % |
| Primitivas renderizadas | 486.421 | 205.815 | -57,7 % |
| Tiempo observado | 8,34 ms | 8,33 ms | limitado a 120 FPS |

El hardware de prueba alcanza el límite de refresco en ambos casos, así que la mejora práctica de FPS debe medirse también en el equipo objetivo. La reducción de trabajo renderizado deja bastante más margen para GPU menos potentes y escenas con varias luces.

Con tres lámparas colgantes encendidas, una segunda prueba dio 3.467 → 2.002 draw calls, 5.534 → 3.087 objetos y 407.257 → 214.871 primitivas. Cada sombra `OmniLight3D` necesita un cubemap de seis caras **por fotograma**, mientras un `SpotLight3D` necesita una sola vista. Las lámparas mantienen el foco con sombra y su iluminación ambiente, pero omiten las seis caras redundantes.

Los 15 interruptores conservan explícitamente el mapa histórico de 18 asignaciones. Hay lámparas con nombres repetidos en la raíz y dentro de `FurnitureAndPickups`; por eso una ruta válida por nombre no basta para comprobar el circuito. `tools/validate_wall_lights.gd` compara cada `NodePath` con la referencia anterior, enciende el destino y comprueba que emita luz. El bypass del cuadro está activo para pruebas.

Ejecutar la comparación:

`godot --path . --script res://tools/benchmark_render_scene.gd`

`godot --path . --script res://tools/benchmark_render_scene.gd -- --optimized`

## Segunda pasada: CPU y sistemas

La escena jugable contiene 12.266 nodos. Antes de esta pasada había 60 nodos con `_process()` activo, 5 con `_physics_process()` y 3 audios reproduciéndose al arrancar. Tras convertir los objetos inactivos a lógica por eventos/temporizadores, el mismo punto de prueba queda en **5 procesos, 3 físicas y 2 audios**. Es una reducción del 91,7 % en callbacks `_process` iniciales y del 40 % en físicas.

- Las 19 balaustradas modulares solo vigilan cambios de escala en el editor; su geometría ya serializada no se reconstruye ni se consulta al jugar.
- Las 16 lámparas colgantes duermen cuando están apagadas. El parpadeo y sus materiales solo procesan cuando la lámpara realmente emite.
- Los siete visuales de vela y las cerillas procesan exclusivamente mientras arden o muestran humo.
- Las puertas dobles de armario y el armario del libro despiertan al interactuar y vuelven a dormir al alcanzar el ángulo final.
- Los tres relojes usan un `Timer` de 4 Hz en lugar de entrar en GDScript 60 veces por segundo.
- La caldera ya resuelta deja de simular temperatura, resorte de aguja y humo. Si se activa el puzle, mantiene su simulación normal.
- La acústica de lluvia interior conserva una transición suave, pero calcula oclusión y actualiza el bus de audio a 10 Hz.
- Relámpagos y el presupuesto de sombras usan temporizadores del motor; no mantienen scripts activos cada fotograma.
- La abuela bloqueada detrás de `MasterBedroomDoor` duerme física, rig y respiración. Un monitor ligero de física detecta la apertura y reactiva todo en menos de dos fotogramas.

La escena contiene dos controladores de abuela distintos, separados unos 1,3 m al cargar: `MonsterGrandmother` es el encuentro inicial con los ojos cubiertos e `ImportedGrandmotherGroundFloor` es el encuentro fotosensible bloqueado por la puerta. No se ha eliminado ninguno porque sus estados y reglas son diferentes. El segundo ya no consume IA antes de su evento de activación.

## Mejoras estructurales recomendadas

1. **Navegación precalculada con invalidación.** `runtime_house_navigation.gd` analiza todos los colliders y hornea el `NavigationMesh` asíncronamente en cada arranque. Conviene guardar una malla horneada desde el editor y regenerarla cuando cambien paredes, suelos o escaleras. El runtime puede conservar el horneado actual como fallback. Esto reduce el pico de CPU y el tiempo antes de que la IA pueda patrullar.
2. **Activación por habitaciones.** Añadir volúmenes `Area3D` con un identificador de zona para dormir IA, audio 3D, partículas e interactivos de habitaciones lejanas. Puertas y puentes pueden marcar conexiones entre zonas. Este sistema encaja especialmente bien con el colegio, sótano y laberinto, y permite cargar el laberinto solo al iniciar su minijuego.
3. **Perfiles de calidad.** Exponer Bajo/Medio/Alto para cantidad de lluvia, MSAA, atlas y número máximo de luces con sombra. El presupuesto actual de dos sombras es un buen valor Medio; equipos potentes podrían usar 3–4 y equipos modestos 1.
4. **Oclusión por estancias.** El edificio tiene muchas paredes y 8.644 mallas pequeñas. Occluders grandes y simples en paredes/forjados pueden evitar dibujar habitaciones completas detrás de muros. Deben hornearse o colocarse sobre arquitectura, nunca sobre cada decoración.
5. **Percepción compartida de IA.** Si se añaden más enemigos, centralizar visión/sonido a 10–15 Hz y repartir consultas entre fotogramas. La persecución y el ataque pueden seguir a frecuencia de física. Con solo un enemigo despierto, el beneficio actual sería pequeño.
6. **Overlay de diagnóstico.** Mantener un modo debug que muestre FPS, frame CPU/GPU, draw calls, luces con sombra y procesos despiertos facilita detectar regresiones justo después de editar una zona.

No conviene unir las decoraciones editables en una sola malla: reduciría nodos/draw calls, pero rompería el flujo de edición solicitado. La combinación actual de piezas independientes, distancia de visibilidad, `MultiMesh` para vegetación y activación por eventos conserva esa flexibilidad.

## Tercera pasada: estructura, HUD y colisiones

Después de las optimizaciones por eventos, todavía quedaban dos controles de interfaz ejecutando GDScript continuamente. El indicador de postura ahora duerme cuando el jugador está quieto y despierta al caminar, correr, agacharse o tumbarse. El timestamp, contador de FPS y piloto `REC` usan temporizadores. El reposo de la escena completa baja así de 5 a **3 `_process()` activos**: jugador, audio meteorológico y la vela inicialmente encendida. Las físicas activas siguen siendo las tres necesarias: jugador, rata y el encuentro de abuela despierto.

La auditoría geométrica encontró 898 colisiones. Tres eran duplicados exactos porque también estaban duplicados sus nodos visuales: `ReceptionAndHall/Wall_14`, `BasementDoorLintel4` y `StraightThreeStepSection7`. Se retiraron las segundas copias, dejando **895 colisiones y cero solapes exactos**. Los colliders grandes restantes corresponden a suelos, cubiertas y paredes completas; su gran tamaño es apropiado y evita fragmentar todavía más el broadphase.

La nueva medición interior queda en 1.954 draw calls, 3.030 objetos y 203.513 primitivas. Las 18 asignaciones de los 15 interruptores siguen verificadas.

### Aviso de escena de texto grande

`house_baked.tscn` mide aproximadamente 1,46 MiB y contiene 3.508 nodos, 1.158 subrecursos y 705 `BoxMesh`. El aviso del editor no indica corrupción ni afecta directamente a los FPS; advierte sobre el tiempo de serialización y lectura del editor. Guardarla como `.scn` ocultaría el contenido y aceleraría algo la carga, pero dificultaría revisar y mantener cambios.

El origen principal es `SchoolUpperFloor`, que se integró localmente para permitir edición directa. Su copia independiente `school_upper_floor.tscn` contiene 2.062 nodos y 739 subrecursos. La solución mantenible es dividirla por habitaciones en escenas propias (`classroom`, `dining_kitchen`, `dormitory`, `bridge_and_corridor`) e instanciarlas desde la casa. Cada elemento seguirá siendo editable abriendo su escena, mientras `house_baked.tscn` solo guardará transformaciones y referencias. Conviene hacer esta migración cuando la distribución de cada habitación esté estable, porque cambia rutas de nodos usadas por luces, puertas y pruebas.

### Esquema propuesto para crecer sin perder rendimiento

- `World/ZoneManager`: registra zonas y activa su contenido al entrar el jugador.
- `Zone3D`: un `Area3D` por casa, colegio, sótano, iglesia y laberinto; contiene referencias a IA, audio, partículas y contenido diferido.
- `DeferredScene`: instancia una `PackedScene` al recibir `activate()` y puede liberarla al terminar el capítulo. El laberinto ya sigue parcialmente este patrón mediante `ensure_church_catacombs()`.
- `PowerCircuit`: sustituye gradualmente rutas directas interruptor→lámpara por identificadores de circuito y señales. Evita que renombrar o mover una lámpara rompa el interruptor.
- `NavigationCoordinator`: usa mallas precalculadas por zona y enlaza regiones al cargar una zona. El horneado completo actual queda como fallback de desarrollo.
- `PerformanceProfile`: centraliza lluvia, distancia de detalles, cantidad de sombras, resolución del atlas y postprocesado. Permite Bajo/Medio/Alto sin editar escenas.

La prioridad recomendada es modularizar navegación y activación por zonas antes de añadir otra planta o varios enemigos. Externalizar toda la geometría únicamente para silenciar el aviso del editor aporta menos al juego que evitar cargar, hornear y procesar zonas que todavía no participan en la misión.

## Módulo del acceso exterior al sótano

La puerta exterior y `BasementAccessAndInitialRoom` se han extraído a `house_props/exterior_basement_access.tscn`. La casa conserva una única instancia, mientras su puerta, rampa, túneles, paredes, techos y colisiones se editan en la escena propia. Las transformaciones globales se mantienen.

## Reducir el análisis inicial de navegación

Las 895 colisiones no se consultan continuamente: `runtime_house_navigation.gd` las analiza una vez al arrancar y hornea la navegación de forma asíncrona. Por eso afecta al tiempo de inicio y al momento en que la IA comienza a patrullar, pero no al FPS estable posterior.

Godot permite cambiar `geometry_source_geometry_mode` a `SOURCE_GEOMETRY_GROUPS_EXPLICIT` y usar `geometry_source_group_name`. La selección correcta no es una línea de ruta, sino los `StaticBody3D` que definen el espacio: suelos, rampas, escaleras, paredes, techos bajos y obstáculos grandes. Objetos pequeños como vasos, libros, cubiertos, lámparas y decoración quedan fuera.

Flujo recomendado durante construcción:

1. Crear el grupo persistente `navigation_bake_source`.
2. Añadir a ese grupo solo cuerpos estructurales y muebles grandes que bloqueen pasos.
3. Configurar el `NavigationMesh` para usar grupos explícitos.
4. Validar que todas las zonas accesibles están conectadas y que ninguna pared puede atravesarse.
5. Cuando la arquitectura esté estable, hornear en el editor y guardar la malla como `.res`.
6. En runtime cargar ese `.res`; puertas móviles usan enlaces u obstáculos dinámicos y no obligan a rehornear.

Marcar solo un recorrido central produciría una IA rígida y problemas al investigar sonidos o luces fuera de esa línea. Debe marcarse toda la superficie caminable y sus límites. El grupo permite que cualquier nueva pared o suelo se incluya desde el Inspector sin modificar código.
