# Auditoría de la abuela trepadora — 13/09/2026

## Problemas identificados

| Problema | Efecto | Corrección |
| --- | --- | --- |
| Solo se comprobaba el destino, no la curva | Choques con bancos o techos durante un salto aprobado | Planificador que barre la cápsula rotada en toda la curva; misma trayectoria en ejecución |
| Giro dirigido por la velocidad de cada frame | Orientación variable y corrección brusca al tocar superficie | Orientaciones inicial/final fijas, interpolación que acaba antes del aterrizaje |
| Arco alto fijo incluso en saltos cortos | Golpes contra techos bajos | Selección del arco más bajo que permita pasar |
| Destinos podían cambiar durante la preparación | Despegue hacia un obstáculo nuevo | Validación inmediatamente antes del impulso; cancelación o retroceso físico si se bloquea |
| Cadena iniciada dentro de la llamada de aterrizaje | Se lanzaba el siguiente salto antes de apoyar | Pausa de apoyo de 0,24 s y siguiente decisión en el controlador de IA |
| Aterrizaje inventaba una pista al azar | Cambios de rumbo sin relación con el jugador | Se mantiene la evidencia real y se reanuda persecución/investigación |
| Referencia de atasco en el pivote del actor | Girar aparentaba movimiento aunque la cápsula siguiera bloqueada | Medición desde el centro físico |
| Caída y giro excluidos del detector | Estados que podían durar indefinidamente | Recuperación específica con dirección libre comprobada por cápsula |
| Patrón de evasión escogía izquierda/derecha cada frame | Oscilación entre bancos | Elección de lado con breve persistencia y comprobación del volumen corporal |
| Cambios alrededor del límite de persecución | Abandonaba la caza por la pared | Umbrales de entrada/salida de 6/8 m; cancelación al actualizar percepción |
| Historial inexistente de destinos fallidos | Repetición de saltos al mismo bloqueo | Memoria limitada de 8 posiciones durante 10 s |
| Las patas conservaban la fase de vuelo al llegar | Un pie podía levantarse tras aterrizar | Restablecimiento de apoyos y de la mezcla de marcha durante la amortiguación |

## Silueta

- Pecho +18 cm, pelvis +16 cm, sin escalar globalmente el personaje.
- Brazos +10% de longitud; radios centrales -18%, conservando las uniones al torso y a la mano.
- Muslo y pantorrilla de 50 cm (antes 43); grosor reducido progresivamente.
- IK, articulaciones y superficies siguen compartiendo los mismos anclajes.
- La variante original con falda conserva sus proporciones; el grosor configurable del brazo tiene valor neutro por defecto.

## Validación

Godot 4.7.2, física a 60 Hz. Los ensayos variables invocan el controlador de salto a 30/60/120 FPS. Los archivos de log están en tools/output.

| Prueba | Resultado observado |
| --- | --- |
| Seguridad de salto | 711 muestras, 0 fallos: techo/suelo a tres FPS, pared interpuesta, techo de 1,8 m, objeto que llega antes y después del despegue, giro bloqueado |
| Persecución integrada en dos pasillos de la iglesia | 60 s simulados, 0 fallos; 3140 frames de persecución cercana visible, 0 desvíos hacia techo; mayor tramo sin avanzar mientras intentaba moverse: 0,60 s |
| Recorrido en ese ensayo | 29,14 m, 23 impactos de ataque, 3 cadenas de recuperación; desplazamiento máximo por frame: 0,284 m |
| Cadena entre bancos reales | 3/3 saltos, máximo 1,804 m, alineación de aterrizaje 1,0 |
| Anatomía y marcha | 2264 muestras, 0 fallos; articulaciones unidas, huesos de longitud constante y apoyos a distintas velocidades |
| Cognición heredada | 31 comprobaciones, 0 fallos |
| Techo y emboscada, balaustres, esquinas, simetría y exclusión de puertas | Sin fallos en sus ensayos de regresión |

Coste orientativo en esta máquina: alrededor de 0,12 ms por paso de IA en la persecución integrada, sin incluir el render. Construcción de una trayectoria simple: unos 0,30 ms en el ensayo sintético. No son medidas de FPS de una partida ni garantías para otras máquinas.

La selección de destino limita a doce candidatos la comprobación costosa de trayectorias por intento. Las consultas se realizan al iniciar/revalidar saltos o durante recuperaciones; se evitan reintentos completos cada frame.

## Alcance

Estos ensayos cubren las colisiones reales de los pasillos de la iglesia y casos adversos sintéticos. No demuestran ausencia de atascos en cualquier combinación de geometría o de objetos móviles del nivel. Si no hay una trayectoria físicamente libre, el controlador cancela, retrocede o vuelve a intentar una ruta a pie; no atraviesa paredes para forzar el salto.

## Ampliación posterior: alcance, extremidades y capa de acecho

Por petición del usuario, el límite de salto pasa de 3,2 a 5 m y la distancia preferida de 1,8 a 3,6 m. La búsqueda conserva cuatro distancias candidatas, con opciones cortas para espacios estrechos, y las mismas comprobaciones de cápsula, trayectoria y destino. Se mantiene la activación tras cuatro segundos inmóvil y las cadenas de uno a tres saltos. El tiempo máximo de vuelo pasa a 0,68 s para absorber el recorrido adicional sin disparar la velocidad.

Los segmentos de pierna pasan de 50 a 57 cm; los brazos reciben aproximadamente otro 14% de longitud. Se elevan pelvis y pecho 7 y 6 cm respectivamente. No se escala el personaje completo ni sus manos: se conserva la unión de sus articulaciones.

La capa oscura utiliza los materiales opacos existentes, con copias locales compartidas entre las piezas. Cubre piel, ropa, ojos y pelo; se revela entre 9 y 2,2 m del jugador, con suavizado temporal que acelera la revelación al acercarse. No modifica la percepción, no añade pasadas de render y no oscurece los recursos de la variante original. Once materiales StandardMaterial3D y el material local del pelo bastan para las 88 mallas registradas, incluidas las ocultas. Las texturas se comparten y los materiales no se duplican en cada frame.

Resultados de la nueva revisión, todos con cero fallos en sus comprobaciones:

- Seguridad: 943 muestras a 30/60/120 FPS; incluye vuelos de 4,8 m, rechazo de destinos fuera del límite, obstáculos que cambian durante el salto y selección de recorridos largos en espacio libre.
- Iglesia real: cadena de 3/3 saltos, máximo 3,602 m y alineación final 1,0. Se conservan las dos transiciones por el balaustre.
- Persecución entre bancos: 60 s simulados, 3231 frames de visión cercana, cero desvíos hacia paredes, 31,93 m recorridos y máximo tramo sin avanzar de 0,383 s mientras intentaba moverse.
- Anatomía: 2388 muestras con bóveda real, error máximo de apoyo 7,6 mm; simetría de manos verificada con cuatro orientaciones iniciales.
- Capa oscura: transición a tres FPS, restauración de colores, aislamiento de la original y persistencia de materiales durante la reconstrucción de extremidades. Comparativa renderizada con Vulkan/Forward+ en `tools/output/crawler_shadow_coat.png`; seis poses revisadas en `tools/output/grandmother_crawler_poses.png`.

Los procesos de validación siguen mostrando el aviso del almacén de certificados y algunos avisos de recursos al cerrar. El render produjo además un error no fatal al escribir la caché de shaders; completó las imágenes y las comprobaciones de materiales sin errores de compilación de shader. No se ha medido el efecto sobre FPS de una partida completa.

## Recuperación rápida y recepción de pie — 14/09/2026

La variante activa en `levels/test.tscn` es `grandmother_crawler.tscn`. El salto
bípedo heredado se desactiva explícitamente en esta escena: cambiar el valor solo
en `_init` no bastaba al sustituir el script de una escena heredada.

- Máximo de seis saltos por cadena, conservando la selección aleatoria de uno a
  seis y la cancelación temprana al recuperar al jugador o no tener apoyo seguro.
- Bloqueo mientras intenta avanzar: 0,8 s en lugar de los cuatro segundos de
  espera. Órbita sin progreso hacia el siguiente tramo de ruta: 1,5 s.
- Los intervalos de espera y marcha se separan: terminar un ataque no dispara un
  escape por haber acumulado su pausa. Un desvío válido se mide contra su propio
  tramo, y trepar se evalúa por progreso físico, no por acercamiento al suelo.
- Sin arco seguro se intenta un desvío navegable con espacio para la cápsula;
  la salida lateral corta queda como alternativa. El aterrizaje limpia la evasión
  y dirección de giro anteriores.
- La orientación final se alcanza al 60% del vuelo. Manos y pies salen de la
  pose recogida entre el 58% y el 88%, antes del contacto, y se estabilizan durante
  0,28 s antes de poder encadenar el siguiente salto.
- Se comprueban las cuatro esquinas de la huella de manos/pies, además del centro
  y sus extremos. Selección, despegue y recepción comparten la orientación real
  de llegada; se exige alineación tanto del eje vertical como del rumbo.

Resultados finales con Godot 4.7.2, sin fallos en las comprobaciones:

| Prueba | Resultado |
| --- | --- |
| Temporización aislada | Bloqueo: 0,800 s; órbita: 1,533 s. Avance, desvío, espera y pausa de ataque conservados |
| Cadena entre bancos reales | 6/6 saltos, longitud máxima 3,602 m, alineación final 1,0, paso máximo 0,283 m |
| Seguridad a 30/60/120 FPS | 969 muestras: orientación, despliegue y posición de los tobillos visibles antes de aterrizar; también obstáculos móviles, techo bajo, cancelación y retroceso |
| Persecución integrada | 60 s, 2883 frames de visión cercana, 0 desvíos hacia techo, 38,16 m recorridos, 22 impactos de ataque, una cadena de escape |
| Mayor intervalo sin avance en persecución | 0,617 s; el ensayo ahora exige menos de 1,6 s, antes permitía 5,5 s |
| Regresiones | Cadena general, anatomía/marcha (2239 muestras), 31 condiciones de cognición con la trepadora, tres transiciones de esquina y exclusión de puertas |

La última persecución repite las mismas medidas tanto a tiempo real como con
`--fixed-fps 60`. Continúan los avisos del entorno relativos al log, certificados
y recursos al salir. Son pruebas físicas automatizadas, no una revisión visual
de una partida completa ni garantía de superar cualquier geometría.

Tras un error de recarga del editor con `_obstacle_jump_active`, se retira la
consulta innecesaria de ese miembro en el movimiento de la trepadora. Las variantes
original e importada consultan el estado propiedad del controlador base mediante
`get`, igual que el animador. Los tres scripts superan `--check-only`; se repiten
sin fallos las pruebas de recuperación, cadena de seis y altar de la original.
