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
