# Reflejos sutiles del jugador

`levels/test.tscn` instala `systems/subtle_player_reflections.gd`. Detecta los
`MirrorSurface` de los espejos antiguo, blanco y tocador, y las ventanas
`WindowGlass*` / `GlassSolid*` de casa y escuela. Conserva sus materiales,
transparencia y reflejo ambiental. No incluye vidrieras de colores de la iglesia.

El efecto superpone solamente el avatar animado, con intensidad 0,28 en espejos
y 0,13 en ventanas. La perspectiva proviene de una camara reflejada respecto al
plano; la textura conserva su matriz de proyeccion entre capturas. La geometria
de marcos, grietas y paredes sigue tapando el reflejo. No es un reflejo completo
de la habitacion, NPC ni iluminacion dinamica: el cuerpo usa luz ambiental tenue.

La linterna tiene una copia visual estable del mismo asset del avatar, anclada
a su mano. Se muestra incluso al equiparla despues de crear los buffers. Su
lente emisiva se enciende con el estado real de la linterna y sigue la direccion
de apuntado; guardar/soltar el objeto oculta la copia. Son dos mallas adicionales
(cuerpo y lente), sin luces, sombras ni capturas adicionales. No se copian las
linternas auxiliares de selfie/suelo para evitar duplicados. El brillo fisico
del haz sobre los materiales del escenario se conserva.

## Presupuesto

- Maximo dos SubViewports de 256 px en el lado mayor, compartiendo un World3D
  que contiene exclusivamente copias visuales del avatar.
- Maximo 15 capturas por segundo y superficie; sin MSAA, sombras, postprocesado,
  animador adicional ni lectura de imagen desde GPU durante el juego.
- Seleccion cada 0,2 s: distancia maxima 5,5 m, frustum, cara frontal del espejo,
  lado del jugador y rayos contra obstaculos. Las ventanas admiten ambas caras.
- Desvanecimiento desde 3 m. Fuera de alcance, ocultas o desactivadas: ningun
  render de reflejos, aunque permanece la comprobacion periodica de proximidad.
- Los buffers se crean al necesitar el primer reflejo y se reutilizan. Las
  mallas/materiales se comparten; solo se copian transformaciones y visibilidad.
- Los cristales escolares mantienen la agrupacion existente. El batch marca el
  plano original con `reflection_batched_source`; la superposicion es hermana
  de esa malla para respetar la visibilidad de sala sin depender de su `hide()`.

`enabled` en el nodo permite desactivar el efecto para comparar. Las constantes
del controlador concentran alcance, resolucion, frecuencia y numero de slots.

## Verificacion

`tools/validate_subtle_player_reflections.gd` funciona en headless y con GPU.
Comprueba registro, materiales, matrices de reflejo, posturas, limites de
resolucion/frecuencia, oclusion, ambas caras de ventanas, cristales agrupados,
desactivacion y descarga. Con GPU comprueba que la textura contiene el cuerpo
y guarda capturas en `tools/output/subtle_reflections_*.png`.
Tambien verifica equipar tarde, anclaje a mano/lente, apuntado independiente,
encendido/apagado, guardado y ausencia de Light3D adicionales; con GPU compara
la luminosidad de la lente encendida y apagada y captura el reflejo en ventana.

`tools/benchmark_subtle_player_reflections.gd` compara OFF/ON/OFF/ON en espejo,
ventana de casa y ventana escolar agrupada, durante al menos dos segundos por
pasada. Usa el nivel real a 1280x720, sin VSync, con logica y HUD congelados.
Guarda JSON y capturas en `tools/output/`.

Medicion local del 14-09-2026, Godot 4.7.2 Forward+, RTX 4090 (promedio de las
dos pasadas de cada estado, una superficie activa en cada encuadre):

| Encuadre | OFF, ms/frame | ON, ms/frame | Diferencia |
| --- | ---: | ---: | ---: |
| Espejo del tocador | 3,026 | 3,167 | +0,141 ms |
| Ventana de casa | 4,110 | 4,176 | +0,066 ms |
| Ventana escolar | 0,641 | 0,629 | -0,012 ms |

Las diferencias pequenas/negativas son ruido de medida; no representan una
mejora de rendimiento. Las capturas efectivas fueron 14,5-15/s y cero en OFF.
Es una comprobacion orientativa del coste visual, no una garantia de FPS para
otras GPU ni una prueba de combate: durante esta medicion habia cambios ajenos
en curso y errores de carga en `grandmother_crawler_animator.gd`.
