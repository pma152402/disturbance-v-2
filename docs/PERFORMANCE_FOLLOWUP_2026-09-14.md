# Segunda pasada: aparición → lavadora

## Qué está costando FPS

La evidencia más fuerte es el trabajo repetido para renderizar sombras. En el
recorrido, las referencias con sombras dan 89–99 FPS; retirar temporalmente
todas las sombras da 265 FPS. Se mantiene la madera, la resolución, la IA, los
materiales y los efectos. Es una prueba de atribución de coste, no una propuesta
de dejar el juego sin sombras ni una promesa de rendimiento final.

RTX 4090, Godot 4.7.2 Forward+, ventana 3440 × 1364, escala 3D del proyecto,
VSync desactivado. Jugador/cámara reales, linterna encendida, trayecto de 13,543 m.
Todas las variantes alcanzaron el destino sin muerte. En la tanda gráfica se
congela exclusivamente la selección de luces del optimizador después del inicio,
en todas las variantes, para evitar que una sombra desactivada sea reemplazada
por otra. IA, movimiento y animaciones permanecen activos.

| Diagnóstico temporal | FPS mediano, recorrido | Frame mediano | p95 | Draw calls |
|---|---:|---:|---:|---:|
| Referencia inicial | 98,5 | 10,15 ms | 13,82 ms | 10.169 |
| Sin sombra de linterna | 100,5 | 9,95 ms | 13,86 ms | 9.656 |
| Sin sombras del sol | 140,9 | 7,09 ms | 9,07 ms | 4.815 |
| Sin sombras locales de escuela | 125,5 | 7,97 ms | 12,23 ms | 7.488 |
| Sin sombras del presupuesto local de House | 121,5 | 8,23 ms | 11,50 ms | 7.496 |
| Sin ninguna sombra | 264,9 | 3,77 ms | 5,92 ms | 1.944 |
| Referencia final | 89,2 | 11,21 ms | 14,92 ms | 10.203 |

Los efectos no se suman: comparten objetos, CPU y GPU. La deriva entre referencias
impide atribuir mejoras pequeñas a una variante; sí deja una diferencia grande
y reproducible en cantidad de draw calls. En aparición, el sol explica unos
7.050 envíos de dibujo adicionales: 13.727 con sombras frente a 6.676 sin su
sombra. No se cambió su iluminación ni su intensidad durante esa prueba.

En la selección inicial hay ocho luces escolares entre las doce locales con
sombras: cuatro farolas del patio y cuatro luces interiores escolares. El sol y
la linterna se suman fuera de ese presupuesto. Estar dentro de la casa no hace
que esas sombras externas dejen automáticamente de costar.

Los tiempos medidos de preparación/render en CPU superan a las marcas GPU en
las referencias. Estos contadores no son sumables, pero, junto con la reducción
de draw calls, apuntan a un límite de envío de geometría. Comprimir una textura
pequeña o bajar su resolución no ataca ese coste.

## Qué cambió respecto a antes

La comparación de código entre `67700e2` (09/09/2026 14:19) y `b9dea00`
(14/09/2026 01:40), en hora local, encuentra cambios simultáneos:

1. `systems/runtime_render_optimizer.gd`: de un máximo de **3 a 12** luces con
   sombras; selección antes limitada a un máximo de **11 m**, ahora con un
   alcance mínimo final de **32 m**. La actualización pasa de 0,18 a 0,12 s.
2. Se incorpora `full_startup_visibility`: elimina límites de distancia de
   geometría/luces, desactiva oclusión y evita el descarte de luces por sectores.
   Se hizo para conservar vistas del escenario a través de ventanas.
3. Se añade la ampliación escolar: el archivo contiene 809 mallas explícitas,
   29 escenas instanciadas y 16 luces, sin contar descendientes de esas instancias.
4. La aparición pasa de Z −24,59 a Z +8,07, cambia el estado inicial de iluminación
   y aparece el avatar corporal. Comparar FPS «al aparecer» en ambas versiones
   no compara la misma vista.

`project.godot` no cambia entre esas revisiones, `fce4c76` y el estado revisado:
no hay una subida global de MSAA o resolución interna que explique ese intervalo.
La escuela anterior sigue agrupándose; no se ha encontrado una desactivación
general de su batching. El suelo y BlackEnte pertenecen a cambios posteriores
del working tree. Esto identifica cambios de código compatibles con el coste
actual; no sustituye una medición de dos builds históricas en idénticas condiciones.

## Sistemas nuevos: qué se puede y qué no se puede concluir

Se repitió el recorrido congelando por separado cerebro del ente, animador,
rama completa del ente, abuela y temporizador de actualización de lluvia.
Las medianas quedaron entre 10,40 y 11,58 ms, mientras las referencias variaron
entre 10,14 y 12,07 ms. **No hay una ganancia clara separable de esa variación**.
Congelar personajes conserva sus mallas visibles, pero altera su evolución y
no reproduce todos los encuentros posibles.

Sí hay candidatos secundarios derivados del código, pendientes de perfilado
dirigido: la huida del ente puede evaluar hasta 35 rutas en una decisión; las
muestras de refugios vuelven a filtrar luces por candidato; la lluvia recalcula
225 celdas contra los techos al caminar. Son posibles fuentes de tirones, no
causas demostradas de la pérdida sostenida observada aquí. La reparación duerme
cuando está inactiva y el reconocimiento de lente sucia no se ejecuta continuamente
en STBY normal.

## Soluciones, por prioridad

1. **Agrupar las sombras de geometría estática por zona.** Mantener los objetos
   y materiales de color originales, pero construir grupos de sombras con la
   misma silueta. Puede combinar materiales visuales distintos si proyectan la
   misma profundidad. Excluir transparencias, recortes, deformación, piezas
   móviles y diferencias de culling; conservar capas y visibilidad. Requiere
   validación visual y de sombras antes de incorporarlo al juego.
2. **Agrupar más geometría opaca estática por material y zona.** El pequeño lote
   de adornos anterior no dio una ganancia clara. Se prepara un prototipo más
   amplio de primitivas, limitado por padre y celda de 4 m, para medir el margen
   sin alterar la escena guardada. Tiene coste adicional de memoria y construcción;
   si resulta útil, se debe generar al importar o preparar el nivel.
3. **Revisar divisiones de la sombra direccional y presupuesto local.** Reducir
   divisiones o volver a tres sombras puede ahorrar trabajo, pero cambia sombras
   y necesita comparación visual. Es una opción de compromiso, no equivalencia
   gráfica garantizada.
4. **Descartar por habitaciones/ventanas reales.** Elaborar visibilidad y
   oclusores que respeten huecos, puertas, cámaras y reflejos. No reactivar las
   antiguas cajas heurísticas, que ya tuvieron problemas con vistas exteriores.
5. **Optimizar picos secundarios con cachés dentro de cada operación.** Compartir
   listas de luces y resultados equivalentes en decisiones del ente; reutilizar
   buffers de lluvia. Mantener puntos evaluados, frecuencia y lógica de detección.

## Candidatos medidos en procesos independientes

Se fijó explícitamente la orientación y posición horizontal originales después
de StartupWarmup: el ratón de escritorio podía girar la cámara durante la carga.
Las cifras siguientes proceden de las repeticiones corregidas, que guardan
posición y rotación de cámara. Cada variante usa un proceso nuevo; el recorrido
alcanza el mismo destino. Los valores iniciales de la tanda de candidatos anterior
a esa corrección no se usan como evidencia de mejora.

| Candidato | FPS mediano, recorrido | Frame mediano | p95 | Draw calls |
|---|---:|---:|---:|---:|
| Referencia inicial | 98,4 | 10,16 ms | 12,86 ms | 10.210 |
| Sol con 2 divisiones de sombras | 116,1 | 8,62 ms | 11,38 ms | 7.609 |
| Sólo 3 sombras locales cercanas | 131,8 | 7,59 ms | 11,37 ms | 7.396 |
| Referencia final | 100,3 | 9,97 ms | 13,79 ms | 10.179 |
| Prototipo de agrupación estática | 99,9 | 10,01 ms | 12,81 ms | 9.070 |

**Dos divisiones solares:** conserva el sol y los objetos que proyectan sombras,
pero cambia el reparto y precisión de los mapas de sombras. Mejora aproximada
del 16–18% de FPS en este recorrido; no garantiza idéntica imagen. No se instaló
en la partida normal.

**Tres sombras locales:** conserva las tres más cercanas seleccionadas al aparecer
y mantiene sol/linterna. Mejora aproximada del 31–34%, pero elimina otras sombras
locales. No reproduce exactamente el algoritmo histórico de 11 m ni una selección
dinámica durante todo el trayecto. Es un compromiso visual explícito, no un ajuste
invisible. No se instaló en la partida normal.

**Agrupación:** `static_geometry_merge_probe.gd` convierte 2.001 primitivas en
341 grupos, manteniendo 124.780 triángulos. Reduce 1.660 instancias dibujables y
aproximadamente el 11% de draw calls del recorrido, pero **no demuestra una mejora
clara de FPS**. Los originales se conservan ocultos para restauración. Su preparación
cuesta aproximadamente 1,28 s y añade 6,33 MiB de arrays de geometría, además de
overhead y memoria del renderer no incluidos en esa cifra. No debe introducirse
durante el movimiento; una integración útil requeriría preparación fuera de juego.

El prototipo excluye scripts descendientes, conexiones de gameplay, transparencias,
deformaciones, MultiMesh e importaciones complejas. La validación sintética headless
pasa 1.517 comprobaciones de geometría, normales, tangentes, materiales, colisiones
y restauración; error máximo de vértices de 0,00000099 m. Esto **no es una validación
visual completa del nivel**. El siguiente experimento con mayor margen es agrupar
sólo las sombras opacas estáticas, cruzando materiales compatibles dentro de zonas
de visibilidad controladas, en vez de limitar cada grupo al mismo material y padre.

## Reproducción y límites

Resultados: `tools/output/ground_floor_shadows.json` y
`tools/output/ground_floor_scripts.json`, con datos por fotograma, recorridos y
lista de luces modificadas. Herramienta: `tools/benchmark_ground_floor_systems.gd`;
`-- --scripts` selecciona la tanda de sistemas. Las capturas `gameplay_*` permiten
inspeccionar las variantes.

Antes de medir se cerraron dos validaciones headless antiguas que habían terminado
correctamente y seguían consumiendo CPU. El editor permaneció abierto. La partida
normal detectada a las 16:08:17 comenzó después de finalizar ambas tandas
(sombras 16:04:56, sistemas 16:08:11), por lo que no las solapó. Las cifras no son
un benchmark de exportación aislada y el proyecto sigue recibiendo otros cambios.

En esta pasada no se han cambiado los ajustes gráficos ni la lógica de la partida
normal. Los apagados de sombras y las congelaciones existen solo en las herramientas.
