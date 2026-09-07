# Auditoría de rendimiento — 4 de septiembre de 2026

Actualización tras la implementación solicitada: el laberinto y su navegación
se cargan una sola vez al iniciar el minijuego de la entrada de la iglesia.
Se agrupan 710 piezas fijas en 114 MultiMesh, por mueble y configuración de
renderizado, conservando las escenas editables. El arranque pasa de 11.570 a
6.931 MeshInstance3D y de 67 a 181 MultiMeshInstance3D. Se difieren además 676
CollisionShape3D y 45 luces Omni del laberinto. El inventario JSON refleja ahora
este estado posterior; las cifras del análisis original que sigue son la base
anterior. No son mediciones de FPS.

Validación gráfica con Forward+/Vulkan: geometría, materiales, matrices mundiales
(incluida escala no uniforme), colisiones e idempotencia de la agrupación;
ausencia del laberinto en caché al arrancar, activación exclusiva desde la puerta
de iglesia, cancelación/reintento sin duplicar y horneado de navegación correctos.
La carga del laberinto es síncrona al iniciar el minijuego: elimina su coste de
arranque, pero puede causar una pausa puntual en esa primera interacción.

La prioridad es reducir el trabajo de renderizado de la escena: geometría fragmentada, visibilidad por zonas y sombras. Reorganizar carpetas o partir scripts no aumenta los FPS por sí mismo.

## Alcance y límites

Revisión del estado actual del proyecto, incluidos cambios locales sin confirmar. Se ha cargado `test.tscn` con Godot 4.7.2 y se ha recorrido el árbol después de 120 ticks de física. Se han revisado configuración, shaders y bucles de ejecución. No se han modificado escenas, scripts de juego ni ajustes gráficos.

La ejecución fue **headless**: permite verificar nodos e inicialización, pero **no mide GPU, draw calls reales ni FPS jugables**. Las prioridades siguientes son hipótesis fundamentadas, no porcentajes de mejora medidos. El número de mallas cargadas no equivale al número de llamadas de dibujo: influyen visibilidad, superficies, instancing y pases de sombras.

Datos reproducibles: `tools/performance_inventory.json`. Herramienta: `tools/audit_performance_inventory.gd`. El log registra un aviso de certificados y avisos de recursos al cerrar; la carga, las dos navegaciones y la escritura del inventario finalizaron. El tiempo de esa ejecución no debe interpretarse como benchmark de carga de una versión distribuida.

## Inventario de la escena cargada

| Elemento | Cantidad |
|---|---:|
| Nodos totales dentro de la escena | 15.780 |
| MeshInstance3D | 11.570 |
| Recursos de malla distintos entre esos MeshInstance3D | 2.999 |
| MultiMeshInstance3D | 67 |
| Luces: Omni / Spot / direccional | 93 / 30 / 1 |
| Luces con sombras configuradas | 54 |
| Luces visibles en el árbol, con energía positiva y sombras, en la muestra | 20 |
| Luces con distance_fade_enabled | 0 |
| StaticBody3D / CollisionShape3D | 1.328 / 1.416 |
| CharacterBody3D / RigidBody3D | 7 / 23 |
| Emisores de lluvia GPU | 4 × 2.200 partículas |
| Vegetación exterior generada | 4.600 instancias |
| Árboles exteriores generados | 220 instancias |
| OccluderInstance3D / oclusión del viewport | 0 / desactivada |

«Visible en el árbol» no significa visible por la cámara ni que esa luz genere una actualización de sombras en cada frame. La muestra corresponde al arranque; encender lámparas cambia la carga.

## 1. Geometría fragmentada y falta de oclusión — prioridad alta

Las catacumbas aportan 3.929 mallas; `House/FurnitureAndPickups`, 1.503; `House/UpperFloor`, 806; y `House/NewFrontHouseDecor`, 599. Solo estas cuatro ramas suman 6.837 mallas.

Hay muebles muy fragmentados: `OfficeBookcaseOak` contiene 178 mallas y `OfficeBookcaseSteel`, 177. Son ejemplos claros para optimizar el coste por objeto, aunque sus triángulos sean pocos. En una casa con muchas paredes, el descarte por campo de visión no elimina necesariamente las habitaciones que quedan detrás de la pared que estamos mirando. Forward+ sí dispone de prepaso de profundidad, por lo que tampoco sería correcto afirmar que todos los píxeles ocultos reciben el sombreado completo.

Acciones propuestas:

1. Añadir oclusores simples para paredes y forjados opacos y activar la oclusión. Dejar libres puertas, ventanas y huecos de escaleras. Activar solo el ajuste, sin crear oclusores, no resuelve el problema.
2. Agrupar geometría estática por mueble o habitación y material. Mantener separadas las piezas que se abren, se recogen o se animan. Compartir materiales y mallas donde sea posible.
3. Para objetos repetidos, aprovechar instancing o MultiMesh por zona. Para un mueble formado por muchas piezas diferentes, puede convenir hornear esas piezas en una malla con pocas superficies.
4. Añadir distancia máxima o versiones simplificadas a detalles pequeños que no se distinguen desde lejos.

No unir toda la casa en una única malla: su volumen de visibilidad enorme dificultaría descartarla por zonas. La documentación explica tanto la utilidad de la oclusión en interiores como su coste de CPU: [oclusión en Godot](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html).

## 2. Luces y sombras — prioridad alta

`project.godot` configura ambos filtros de sombras en nivel 3. `rainy_weather.tscn` mantiene una luz direccional con sombras hasta 70 metros. Varias luminarias generan sombras desde una OmniLight y también desde una SpotLight: chandelier y faroles de iglesia, además de lámparas de techo que pueden encenderse durante el juego.

En el arranque, las 20 luces visibles con sombras incluyen 11 pertenecientes al chandelier, faroles y apliques de iglesia. No hay desvanecimiento por distancia configurado en ninguna luz.

Acciones propuestas:

- Comparar filtros de sombras más baratos y limitar distancia/rango de las luces que no necesitan cubrir grandes zonas.
- Probar una única luz con sombras por luminaria; mantener el relleno sin sombras cuando no cause filtraciones visibles a través de paredes.
- Desactivar la proyección de sombras de pequeños elementos decorativos cuando la diferencia no sea perceptible.
- Reservar iluminación horneada para fuentes realmente estáticas. Las lámparas con interruptor y parpadeo, la linterna y los relámpagos requieren conservar su comportamiento dinámico.

Las sombras necesitan renderizados adicionales de geometría; por eso esta revisión se complementa con la reducción de mallas. No se presupone que cambiar solo la energía de una luz invalide su mapa de sombras cada frame. Referencia: [luces y sombras de Godot](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html).

## 3. Resolución y postprocesado — prioridad alta para una prueba rápida

El proyecto configura 1920 × 1080 y MSAA 4× (`msaa_3d=2`). No configura una escala reducida de renderizado 3D. `test.tscn` aplica dos efectos de pantalla completa, `ps2_distortion.gdshader` y `ps2_postprocess.gdshader`, con una copia intermedia de pantalla.

El `pixel_size=8` del shader cuantiza las coordenadas de muestreo después de renderizar el mundo. **No hace que la escena 3D se dibuje a una octava parte de resolución.**

Probar escala 3D 0,75 y 0,5, además de MSAA 2× y desactivado. A 0,75, el número de píxeles 3D es el 56,25 % del original; a 0,5, el 25 %. Esto no equivale a esos porcentajes de mejora de FPS: no reduce proporcionalmente física, scripts, geometría, sombras ni todo el postprocesado 2D.

La estética pixelada hace esta prueba especialmente interesante. Si se busca abaratar también los filtros, valorar aplicar ambos en un viewport de resolución baja y presentar el HUD por separado. Fusionar shaders requiere preservar correctamente la composición de la distorsión con el filtro. Referencia: [escalado de resolución](https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html).

## 4. Exterior y lluvia — prioridad media/alta según la cámara

`exterior_environment.gd` ya utiliza MultiMesh y la hierba no proyecta sombras. Hay distancias de visibilidad de 34–48 metros para las cuatro capas de vegetación y de 90 metros para los árboles. Son optimizaciones existentes, no tareas pendientes.

La limitación está en agrupar 2.500, 800, 600 y 700 plantas en cuatro bloques que abarcan áreas extensas. MultiMesh se descarta como conjunto, no planta por planta. Probar dividir cada capa en celdas espaciales, inicialmente de unos 10–20 metros, y ajustar según el equilibrio entre llamadas de dibujo y descarte. Los árboles también admiten sectores. Referencia: [optimización con MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html).

La lluvia mantiene cuatro emisores de 2.200 partículas, simulación a 60 Hz, colisiones y AABB de 60 × 50 × 60 metros por emisor. Probar menos partículas, simulación a 30 Hz y emisores cercanos al jugador o activados por sectores. En interiores, mantener lluvia donde sea visible por puertas y ventanas; en zonas subterráneas cerradas, se puede prescindir de ella visualmente conservando el sonido. Los nodos llamados RainOccluder son colisionadores de partículas, no oclusores del renderizado del mundo.

## 5. CPU, física e inicialización — segunda fase

Hay pequeñas mejoras concretas, pero no evidencia de que sean el cuello de botella principal:

- `house_props/modular_balcony_balustrade.gd:25`: 19 instancias reciben `_process` y retornan inmediatamente fuera del editor. Desactivar ese procesamiento en ejecución.
- `house_props/double_cabinet_doors.gd:12` y `book_opening_wall_cabinet.gd:11`: seis instancias interpolan puertas incluso cuando ya están inmóviles. Procesar solo durante el movimiento, ajustar al ángulo final con tolerancia y reactivar al interactuar.
- `house_props/grandma_ceiling_lamp.gd:17`: 16 controladores siguen entrando en `_process` apagados. Su luz de parpadeo ya se desactiva correctamente; se puede hacer lo mismo con el controlador.
- `sounds/ambient/indoor_weather_audio.gd:55`: vuelve a consultar refugio y aplicar audio cada frame. Fuera de los volúmenes explícitos puede lanzar un rayo por frame. Muestrear refugio a 5–10 Hz o al desplazarse y conservar la transición suave; escribir parámetros solo cuando cambian.
- `house_props/rat.gd:295`: una rata activa puede probar 12 direcciones en recuperaciones de atasco, con rayos de obstáculos/suelo. Limitar reintentos repetidos si el profiler muestra picos. Ya limita la prueba normal de obstáculos a 0,1 segundos.
- IA: la búsqueda de luces está cacheada y parte del escaneo se ejecuta cada 0,18 segundos; la navegación ya limita actualizaciones de destino. No conviene reescribirla sin medir. Evitar desactivar enemigos por simple distancia si deben perseguir al jugador entre habitaciones.

Los 1.416 CollisionShape3D justifican revisar colisiones por zona y detalles innecesarios, pero no prueban que la física sea cara: gran parte de los cuerpos son estáticos. Conservar la precisión necesaria en puertas, agachado y recorridos estrechos.

`runtime_house_navigation.gd:28` prepara las dos navegaciones al arrancar. El horneado es asíncrono, pero la extracción de geometría puede generar una pausa inicial. Para mapa estático, guardar navegación precalculada y gestionar puertas mediante enlaces/regiones cuando proceda. Esto apunta a carga y tirones de inicio, no a un coste de horneado continuo por frame.

Los scripts de fotos, notas y libros revisados ya desactivan su `_process` tras actualizarse. La longitud de `player.gd` es un problema de mantenimiento potencial, no una medida de consumo de FPS.

## Organización que sí puede mejorar FPS

Separar el mapa en **zonas espaciales operativas**: exterior, planta baja, planta superior, oficinas, iglesia y sectores de catacumbas. Cada zona puede tener geometría estática, decoración, luces, audio y actores identificables. Un controlador determina qué se renderiza o actualiza, conserva el estado de puzles y anticipa zonas próximas antes de cruzar puertas.

Crear archivos `.tscn` separados sin controlar su activación no reduce el trabajo: si todos siguen instanciados y activos, el coste permanece. Ocultar una zona tampoco detiene automáticamente scripts y física; hay que tratar por separado visibilidad, procesamiento y colisiones. Conviene empezar por oclusión y agrupación local antes de implantar descarga/carga completa, que añade complejidad a navegación, sonido y persistencia.

Mover archivos a carpetas más ordenadas, renombrar nodos o dividir `player.gd` facilita mantenimiento, pero no aporta FPS directamente. Tampoco borrar recursos fuente que no están instanciados ataca el coste por frame. Los nombres «Staging» no demuestran que esos objetos sobren: verificar su uso antes de excluirlos del juego.

## Orden de validación y aceptación

1. Medir una ejecución gráfica de referencia, preferiblemente exportada, con resolución fija, VSync/límite de FPS controlados, calentamiento previo y mismo recorrido/cámara. Registrar frame time mediano y p95, CPU/GPU, draw calls y primitivas. Separar arranque de rendimiento estable.
2. En pasillo, iglesia, exterior y catacumbas, comparar individualmente: sombras apagadas temporalmente, escala 3D reducida, filtros desactivados, lluvia desactivada y exterior oculto. Repetir con lámparas encendidas y durante persecución.
3. Si domina renderizado: implementar primero oclusión, simplificación de luminarias y un prototipo de agrupación de un mueble/habitación. Si domina CPU: usar profiler de scripts/física para elegir la siguiente intervención.
4. Comparar las mismas vistas antes/después, incluyendo ventanas, puertas abiertas, escalera y linterna. Mantener cambios solo si mejoran tiempo por frame y no rompen la imagen o interacción.

Objetivos orientativos: 60 FPS exige 16,67 ms/frame; 120 FPS, 8,33 ms/frame. **Con este inventario no es posible prometer una ganancia concreta ni declarar cuál de los candidatos consume más milisegundos.** Sí permite concentrar la primera ronda en los sistemas con mayor carga estructural.
