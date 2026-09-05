# Auditoría de rendimiento — 2026-09-05

## Estado medido

- Escena: 8.796 mallas, 8.881 superficies y unas 694.425 caras.
- Materiales distintos: 1.086.
- Luces: 85 en recursos; 81 luces posicionales gestionadas en runtime.
- Sombras visibles al arrancar: 1 direccional. Las sombras posicionales tienen un presupuesto máximo de 3 fuentes cercanas.
- Colisiones: 895 activas o configuradas, sin duplicados exactos.
- Lluvia: 1 emisor y 900 partículas, frente a 4 emisores y 4.800 partículas al inicio de la auditoría.
- Audio al arrancar: 5 voces reproduciéndose y 7 scripts con proceso activo total en la escena.
- Detalles pequeños con descarte por distancia: 5.432.

## Cambios aplicados

- Carga inicial en segundo plano de la escena principal.
- Caché persistente de escenas que pueden aparecer durante la partida: puzles, objetos lanzados, pickups y herramientas.
- Bloqueo temporal del control hasta terminar navegación, generación de escenario, audio procedural y varios fotogramas de calentamiento gráfico.
- El laberinto de la iglesia permanece diferido hasta completar su minijuego.
- Presupuesto único para sombras omni y spot, con descarte por distancia para todas las luces posicionales.
- Cuatro campos de lluvia globales sustituidos por uno que sigue al jugador cada 0,25 s.
- Distorsión VHS y postproceso PS2 fusionados en una única pasada de pantalla.
- Eliminadas tres ramas visuales y físicas exactamente superpuestas.
- Bucles y ambientes de audio lejanos o inactivos dejan de decodificar y procesar.

## Límites actuales

La carga inicial reduce tirones de primera aparición, pero no reduce el coste de dibujar la escena una vez cargada. El límite continuo sigue siendo la cantidad de objetos y materiales: 8.796 mallas y 1.086 materiales producen mucha preparación de draw calls, especialmente en equipos modestos.

La siguiente mejora grande requerirá sectorizar la casa y el colegio por habitaciones o plantas, manteniendo cargados los recursos pero desactivando del árbol visual y físico los sectores alejados. Esto conserva una transición instantánea porque los recursos permanecen en memoria y reduce el trabajo continuo. Conviene hacerlo cuando se retome la modularización para no alterar ahora la edición de las escenas.

También quedan dos variantes completas de la abuela colocadas en `test.tscn`. Ambas están configuradas como inactivas, pero sus geometrías siguen cargadas. Antes de retirar una hay que decidir cuál será la versión definitiva.
