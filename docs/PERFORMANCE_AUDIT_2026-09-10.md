# Auditoría de rendimiento: movimiento y grabación

Fecha: 10 de septiembre de 2026. Godot 4.7.2, Forward+, Vulkan, RTX 4090.

**Cambio posterior solicitado para las ventanas:** ahora House activa
`full_startup_visibility`. Se deshabilitan los recortes de distancia y oclusores
automáticos que ocultaban la iglesia desde las ventanas. Las mediciones de esta
auditoría se tomaron antes de ese cambio de visibilidad. Se mantienen las mejoras
de HUD y grabación; véase `tools/README.md` para la nueva política y sus pruebas.

## Hallazgos y cambios aplicados

### 1. El HUD consumía varios milisegundos al moverse

`player/stance_indicator.gd` construía la silueta del personaje a 84×84 píxeles,
recorría toda la imagen tres veces, pintaba 25 píxeles de contorno por cada píxel
opaco y creaba una `ImageTexture` nueva por cada frame animado. La animación al
caminar, correr, agacharse y gatear convierte ese trabajo en coste continuo.

Se sustituyeron los bucles por `Image.fill_rect` y `Image.blit_rect_mask`, que
ejecutan las mismas operaciones en código nativo. La textura final de 42×42 se
actualiza y se reutiliza. Se mantienen las poses, interpolaciones, velocidad de
animación, colores, contorno, sombra y filtro nearest.

**Mediana de rasterización CPU en la primera prueba headless: 4,732 ms → 0,610 ms,
un 87,1 % menos.** La repetición con renderizador real dio 4,009 → 0,508 ms
(87,3 % menos); además, 16 frames animados producen las mismas texturas y mantienen
el mismo RID en la versión optimizada. Es el coste
del HUD aislado, no una promesa de un 87 % más de FPS del juego. La prueba cubre
195 imágenes: 19 poses, interpolaciones, estado normal/desactivado y recorte en
los bordes. Todas coinciden byte por byte con la implementación original,
guardada como referencia independiente en `tools/fixtures/`.

### 2. Grabar bloqueaba el hilo principal esperando a la GPU y al JPEG

La captura ya utilizaba un viewport de 426×240 y solo lo dibujaba cada 0,5 s.
El problema pendiente estaba en `get_image()` y `save_jpg_to_buffer()` ejecutados
sincrónicamente al final del render. Una resolución pequeña reduce el volumen
de datos, pero no elimina la espera a que termine la GPU.

Ahora `systems/tape_frame_readback.gd` solicita la lectura asíncrona desde el
hilo de render y comprime el JPEG en `WorkerThreadPool`. Solo se permite una
captura en vuelo: no se acumulan colas sin límite. El archivo sigue viviendo
comprimido en RAM y la reproducción conserva su textura reutilizable.

La API asíncrona entrega los datos de la textura solicitada unos frames después;
la alternativa síncrona bloquea hasta recibirlos. Véase la
[documentación de RenderingDevice](https://docs.godotengine.org/en/stable/classes/class_renderingdevice.html#class-renderingdevice-method-texture-get-data-async).
Las operaciones de GPU se despachan mediante
[RenderingServer.call_on_render_thread](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-call-on-render-thread).

Se conservan resolución, intervalo, calidad JPEG 0,62, duración y límites del
archivo, así como la cámara separada que revela las pistas de la capa 20 y oculta
la guía de colocación de la capa 19. Las pruebas sobre GPU comparan JPEGs contra
el método anterior sobre exactamente el mismo framebuffer, byte por byte.

Cada sesión tiene un identificador: un resultado retrasado de STOP no puede
entrar en la grabación siguiente. START repetido ya no borra una grabación activa.
Al parar se descarta el trabajo aún pendiente, y el viewport se libera cuando
termina ese trabajo; no queda una segunda cámara renderizando en STBY.

Para dispositivos o formatos no compatibles con la lectura RGBA8 asíncrona se
mantiene una ruta de lectura convencional con compresión en segundo plano.
`asynchronous_capture = false` permite comparar explícitamente con el método
síncrono original o diagnosticar problemas de un controlador.

### 3. La primera captura tenía un coste de preparación adicional

Antes del cambio se midió un pico de 43,436 ms en la primera grabación de casa.
Quitar la lectura síncrona por sí sola no eliminaba ese pico inicial. Se añadió
una captura de preparación al arrancar la escena, sin activar REC, usar una
ranura de cinta ni sumar tiempo grabado. El viewport temporal se libera al acabar.
Esto desplaza preparación de render/lectura al arranque; no elimina los posibles
costes de cargar contenido nuevo durante el recorrido.

### 4. El benchmark anterior no medía estos dos problemas

Las cámaras fijas con el jugador congelado no animan el indicador de postura,
y el benchmark anterior tampoco activaba REC. Además, una mediana puede esconder
tirones que ocurren una vez cada medio segundo.

Se añadió `run_recording_benchmark.ps1`, que alterna dos veces el método original
y el nuevo dentro del mismo proceso en cinco zonas. Mide seis segundos por estado,
registra media, p50, p95, p99, p99,9, máximo y cantidad de capturas. `-WalkingHud`
activa la animación del HUD durante esa comparación. Tiene watchdog y solo detiene
el proceso que él mismo inició en caso de timeout.

También se corrigió un contador del agrupador de decoración: contabilizaba el
tamaño de un grupo una vez por cada instancia, inflando las cifras del informe.
No cambia la geometría agrupada.

## Resultado de la comparación de grabación

Promedio de los p99 de las dos pasadas por método, en milisegundos; menor es mejor:

| Zona | Síncrono | Asíncrono | Reducción del p99 |
|---|---:|---:|---:|
| Casa | 6,194 | 4,895 | 21,0 % |
| Iglesia | 2,784 | 2,536 | 8,9 % |
| Patio | 5,855 | 5,687 | 2,9 % |
| Escuela | 6,056 | 5,428 | 10,4 % |
| Sótano | 6,342 | 6,107 | 3,7 % |

En casa, los máximos de las pasadas asíncronas fueron inferiores a 8 ms después
de la preparación inicial. Es una observación de esta prueba, no un límite
garantizado. En iglesia hubo un pico aislado mayor con la ruta asíncrona, aunque
su p99 fue menor. El tiempo medio cambia poco y no mejora en todas las zonas;
la ganancia de la grabación está principalmente en reducir los tirones. La
gran mejora continua al moverse corresponde al HUD, medido por separado.

Las cifras finales se registran en `tools/output/recording_current.json` y su
log. STBY y STOP se incluyen para identificar coste persistente. Las dos pasadas
A/B usan la misma escena, resolución, calidad y posición; IA y relámpagos están
congelados. La variación entre ejecuciones y las tareas del sistema afectan a los
FPS absolutos: el dato del HUD aislado y las comparaciones de píxeles son pruebas
distintas de la medición de frame completo.

## Alcance visual y costes que siguen existiendo

- Esta intervención conserva los shaders, resolución 3D, sombras, iluminación,
  niebla, vegetación y distancias de dibujado existentes al comenzar el trabajo.
- El viewport de cinta sigue renderizando la escena cada captura. Esa segunda
  vista es necesaria para el contenido sobrenatural que no aparece en directo;
  la mejora elimina esperas evitables, no el coste de dibujar esa vista.
- El proyecto ya tenía agrupación de decoración, oclusión y control por sectores.
  El arranque actual informa de 103 luces gestionadas y 136 oclusores. El informe
  general que ya existía mostraba unas 4.100 draw calls en sótano. Es una zona a
  seguir perfilando si queda limitada por CPU de render en otros equipos.
- El siguiente trabajo de geometría debería agrupar piezas realmente estáticas
  por material y habitación, conservando transformaciones y capacidad de oclusión.
  Quitar más sombras, bajar resolución o recortar distancias sí puede alterar el
  aspecto: no se aplicaron nuevos recortes de ese tipo en esta intervención.
- Las mediciones se realizaron en una RTX 4090; no certifican un mínimo de FPS en
  otras GPUs, ni cubren un recorrido completo con enemigos y streaming activos.

## Validación y reproducción

Desde la raíz del proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_recording_benchmark.ps1
powershell -ExecutionPolicy Bypass -File tools/run_recording_benchmark.ps1 -WalkingHud
```

Scripts de validación ejecutados con Godot:

- `validate_stance_raster_performance.gd`: 195 imágenes idénticas, benchmark CPU
  y 16 actualizaciones de textura idénticas con renderizador real.
- `validate_async_recording.gd`: lectura real, igualdad de JPEGs, preparación sin
  consumo de cinta, fallback para HDR, START repetido, ocho carreras STOP/START
  y cierre de escena.
- `validate_camera_recording_playback.gd`: archivo, reproducción y menús.
- `validate_camera_cassette_inventory.gd`: inventario de cintas.
- `validate_recording_only_footsteps.gd`: capas de visibilidad y posición sobre el
  suelo; se actualizó para iniciar REC antes de buscar la cámara creada a demanda.
- `validate_deferred_content_and_batching.gd`: 654 mallas en 92 grupos; geometría,
  materiales, matrices, colisiones y carga diferida conservados.

La validación preexistente `validate_recording_only_paranormal_components.gd`
falla porque exige al menos 55 hijos y piezas concretas de una versión anterior
de la figura colgada. La escena actual ya tenía menos piezas y otros nombres antes
de esta intervención. Se deja registrado, sin modificar ese modelo para satisfacer
una expectativa antigua. Los logs también contienen un aviso del almacén de
certificados de Windows que aparece tanto antes como después de los cambios.

Los cambios que ya existían al iniciar la auditoría se han conservado. No se ha
creado ningún commit ni se han reemplazado los baselines anteriores.
