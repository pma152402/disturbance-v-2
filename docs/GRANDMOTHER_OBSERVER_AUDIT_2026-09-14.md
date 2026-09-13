# Revisión de la vieja y del Observador — 14/09/2026

## Retirada del prototipo antiguo

Se eliminan únicamente `enemies/monster_grandmother_crawler.gd`, su `.gd.uid` y
`monster_grandmother_crawler.tscn`: prototipo independiente con extremidades y
cara procedurales, sin referencia en escenas activas ni dependencia de la actual.
Los tres estaban versionados y se pueden recuperar de Git. No se eliminan mallas,
texturas ni bases compartidas.

La vigente sigue siendo `grandmother_crawler.tscn`, derivada de
`church_grandmother` → `monster_grandmother_imported` → `monster_grandmother`.
Se corrige el esquema desactualizado de `CLAUDE.md`. La variante con falda es una
base/alternativa conservada, no el prototipo retirado.

## Vieja actual

No se cambia su comportamiento ni se retoca su anatomía en esta pasada. Durante
la comprobación final entraron cambios del ataque de vómito: se corrige únicamente
la anotación `bool` de `vomiting` que impedía compilar el animador, sin rediseñar
ese ataque. Se comprueban los controladores que habían recibido los ajustes de salto:

- Cognición de la trepadora: 31 condiciones, sin fallos.
- Recuperación física: 0,800 s; órbita sin progreso: 1,533 s. Avance normal,
  rodeos válidos y pausa de ataque conservados.
- Cadena en la iglesia: 6/6 saltos, alineación final 1,0, desplazamiento máximo
  por paso 0,283 m.
- Seguridad: 969 muestras a 30/60/120 FPS, sin penetraciones ni aterrizajes
  laterales en los casos de prueba; cancelación y retroceso ante obstáculos móviles.
- Anatomía en la bóveda real: 2344 muestras, error de apoyo inferior a 0,1 mm.
- Persecución integrada de 60 s: 39,73 m recorridos, 23 impactos, una cadena de
  escape, 0 desvíos hacia techo con persecución cercana y atasco máximo de 0,583 s.
- Acecho según encuadre a tres FPS y cruce de puerta normal/doble en ambos sentidos:
  sin fallos. La prueba de puertas admite ahora `-- --crawler`.

La prueba histórica del NPC niño no es aplicable: su escena ya es un marcador
`ChildCompanionRetired`, no un personaje con IA. Ahora lo detecta y se declara
**omitida**, evitando un error por instancia nula y un proceso que no terminaba.
No se restaura el NPC ni se presenta esa prueba como aprobada.

Estas cifras corresponden al controlador de movimiento revisado; no certifican
funciones nuevas que se estén añadiendo simultáneamente en otros cambios.

## Correcciones del Observador

1. El catálogo vacío ya no se reconstruye en cada fotograma. Altas y bajas de
   nodos marcan una invalidación que se agrupa hasta el siguiente análisis.
   Activar ARCHIVO dos veces tampoco repite el trabajo. Se mantiene dormido en directo.
2. Un inventario de `Node3D` sustituye los recorridos separados de escenas, luces
   y mallas. Se descartan otros `World3D`, como vistas auxiliares de previsualización.
3. El descarte por encuadre y distancia precede al recorrido de geometrías. Se
   respetan también los planos cercano y lejano, antes ignorados.
4. La oclusión visual utiliza el árbol de triángulos nativo del recurso `Mesh`,
   que el motor invalida cuando cambia la malla. No se conserva una copia de caras
   desactualizada ni se recorre cada triángulo en GDScript. Las cajas y transformaciones
   se reutilizan dentro de un análisis, no entre fotogramas; puertas móviles y huecos
   siguen actualizándose. Las transformaciones singulares se descartan.
5. Las luces negativas, negras, ocultas, apagadas o de otro mundo no habilitan
   detección. Las paredes visibles sin collider también bloquean la iluminación,
   no solo la línea de la cámara. La selección guarda solo las cuatro fuentes
   locales más cercanas, sin ordenar la lista entera por objeto.
6. Una colisión desactivada, vacía o sin capas no obliga al rayo a tocar un cuerpo
   inexistente. Tampoco lo hacen las Areas invisibles de interacción. Se conservan
   referencias ligeras y se consulta su estado actual, sin reexplorar el árbol por muestra.
7. El catálogo manual refresca sus geometrías cuando cambian los nodos. Las
   etiquetas automáticas sustituyen palabras/frases completas y primero las más
   largas: `CAN` ya no corrompe `CANDLE` y `CANDLESTICK`.
8. Los metadatos de cinta conservan la política de oclusión del jugador de la cámara
   original, no del nombre de su copia `TapeCamera`; también aspecto, desplazamientos
   horizontal/vertical y desplazamiento de frustum. Las cintas anteriores usan valores
   predeterminados compatibles. El cuerpo del jugador tapa objetos en cámara externa.

Las entradas sin iluminación continúan en gris y no aportan identificadores,
intensidad ni evidencia activa. No se amplían los presupuestos de doce consultas
de visibilidad e iluminación por muestra.

## Validación y coste

- `validate_camera_observer_audit.gd`: 31 condiciones, 0 fallos; altas/bajas en
  ARCHIVO, luces, colisiones activas/desactivadas, capas, cambios de malla, cámara
  externa, límites de encuadre, etiquetas y salida del modo.
- `validate_camera_observer_occlusion.gd`: pared sin collider y desplazamiento.
- `validate_deferred_camera_observer.gd`: catálogo real de 570 entradas, inactivo
  y oculto fuera de ARCHIVO, análisis y limpieza al salir.
- `validate_camera_recording_playback.gd`: recorrido de grabación/archivo, usando
  JPEG sintético en headless; añade la comprobación de metadatos de cámara externa.
- `benchmark_observer_triangles.gd`: 256 rayos sobre 4224 caras, resultados
  idénticos; bucle anterior **29,588 ms**, consulta nativa **0,350 ms**. Comprueba
  además una abertura dentro del AABB. Mide solo la consulta geométrica con el
  árbol ya construido, no la primera construcción, el Observador completo ni los FPS.

Referencia de la API nativa: [TriangleMesh — documentación de Godot](https://docs.godotengine.org/en/4.5/classes/class_trianglemesh.html).

## Límite pendiente: estado histórico de la grabación

ARCHIVO conserva imágenes y poses de cámara, pero `analyze_recorded_frame()`
consulta el escenario **actual**. Si una puerta, luz o personaje cambió después
de grabar, los resultados pueden diferir del fotograma almacenado. No es análisis
de píxeles ni reconstrucción temporal. Corregirlo exige guardar evidencia/estado
histórico durante la captura o introducir una reproducción de escena aislada;
esta pasada no reactiva análisis continuo durante REC ni añade ese coste.

La selección sigue siendo semántica y acotada: requiere el centro del objeto
dentro del encuadre, limita candidatos y reconoce oclusores visuales por sus nombres.
No pretende enumerar exhaustivamente todo píxel visible ni sustituir una prueba
visual de la partida. Los avisos del entorno sobre logs/certificados al ejecutar
headless son independientes de las comprobaciones de comportamiento.
