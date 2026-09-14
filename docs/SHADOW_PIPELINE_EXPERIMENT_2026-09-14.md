# Prueba: agrupado exclusivo de sombras y oclusión real

## Resultado medido

En la RTX 4090, con **la selección dinámica de sombras funcionando normalmente**,
la combinación pasa de **97,9–98,1 FPS a 134,1 FPS** en el recorrido aparición →
lavadora: aproximadamente **+37 %**. No se reducen las divisiones del sol, la
calidad de la linterna ni el presupuesto de luces.

El sistema está integrado en el arranque normal mediante
`systems/runtime_shadow_pipeline.gd`. Existe una partida libre para compararlo
con el estado restaurado mediante F7, sin editar escenas ni assets.
Esto prueba la viabilidad en el recorrido pedido, no garantiza el mismo porcentaje
en cada habitación, al grabar o en todos los encuentros.

Confirmación final con presupuesto dinámico activo, tres procesos independientes:

| Variante | FPS recorrido¹ | Mediana ms | p95 ms | Llamadas de dibujo |
|---|---:|---:|---:|---:|
| Referencia normal inicial | 97,9 | 10,212 | 13,468 | 10.180 |
| Sistema integrado | **134,1** | **7,456** | **9,723** | **6.067** |
| Referencia normal final | 98,1 | 10,195 | 13,709 | 10.179 |

Todos llegan al destino sin muerte; recorridos de 13,543–13,613 m. La IA y la
física siguen activas, por lo que hay pequeñas variaciones de trayectoria.

Primera tanda de aislamiento, manteniendo la misma selección inicial de luces:

| Variante | FPS recorrido¹ | Mediana ms | p95 ms | Llamadas de dibujo | Render CPU ms |
|---|---:|---:|---:|---:|---:|
| Referencia inicial | 98,9 | 10,110 | 13,439 | 10.188 | 6,363 |
| Agrupado de sombras | 101,8 | 9,826 | 12,912 | 7.521 | 6,136 |
| Oclusores exactos, paredes incluidas | 112,3 | 8,901 | 11,965 | 8.649 | 5,694 |
| Combinación | **136,4** | **7,334** | **9,313** | **5.916** | **4,486** |
| Referencia final | 99,0 | 10,101 | 13,662 | 10.179 | 6,490 |

¹ 1000 / mediana del tiempo entre fotogramas, no media aritmética de FPS.
En esta tanda la combinación da +38 %; en aparición quieta pasa de 84,9–86,5 a
121,1 FPS. La confirmación dinámica anterior es más cercana a la partida normal.
Las ganancias de las variantes no se suman. El agrupado aislado ofrece una
diferencia pequeña; su reducción de llamadas sí es clara. La combinación reduce
aproximadamente un 42 % las llamadas y un 31 % el p95 frente a las referencias.

Cada variante final usa un proceso nuevo. Godot 4.7.2, Forward+, ventana
3440 × 1364, escala 3D original, VSync desactivado. Trayecto real de 13,543 m;
IA, física, animaciones y lluvia activas. Todas las variantes alcanzan el destino
sin muerte. La selección de sombras del optimizador se congela después del
arranque, igual en todas las variantes de aislamiento, como en la auditoría
anterior. Las variantes finales `live_*` mantienen ese sistema activo.
El editor permanece abierto; no se ejecutan dos partidas GPU simultáneamente.

## Agrupado exclusivo de sombras

`systems/static_shadow_batcher.gd` conserva las mallas visibles, sus materiales,
transformaciones y colisiones. Sólo desactiva la emisión de sombras de fuentes
compatibles y crea una malla `SHADOWS_ONLY` equivalente por grupo.

- **2.834 fuentes → 340 grupos de sombras**, 2.494 emisores menos.
- Conserva los **165.904 triángulos** originales, sus posiciones, normales y
  orientación; no simplifica siluetas ni altera materiales del pase de color.
- Une materiales opacos distintos si comparten reglas de rasterización de sombra.
  Conserva capas, cara frontal/trasera/doble y margen de descarte.
- Mismo padre y celda de 4 m; excluye actores, ramas con scripts/movimiento/
  animación/callbacks, alpha, shaders, parallax, normal maps, efectos de vértice,
  LOD importado, fades y otras configuraciones no verificadas.
- `restore()` repone exactamente el modo de sombra de cada fuente y elimina
  los grupos. No oculta las fuentes del pase de color ni toca sus colliders.

El agrupador añade 5.499.024 bytes (~5,24 MiB) de arrays CPU, además de copias GPU
y objetos. Construirlo consume alrededor de 1,3–1,5 s fuera del intervalo medido.
Actualmente se construye durante la pantalla de carga. Hornearlo o cachearlo
evitaría ese coste, pero no es necesario para la ganancia durante el juego.
Alterar una pieza estática por código externo requeriría invalidar su grupo; por
eso el filtro excluye ramas que tengan scripts, movimiento o animación.

## Oclusión entre zonas

`systems/runtime_exact_occlusion.gd` activa la oclusión nativa del viewport principal con
**256 piezas opacas reales**, 3.072 triángulos y 110.592 bytes de arrays. Su
construcción cuesta unos 0,30 s. Se usan caras exactas de BoxMesh de arquitectura,
con la transformación y visibilidad de la fuente; nunca cajas que rellenen una
habitación o el hueco de una ventana.

Esto permite descartar render detrás de superficies opacas sin apagar manualmente
las sombras de una lámpara. El sistema nativo decide qué puede descartarse.
No se cambian intensidades, máscaras de luces ni `shadow_enabled`. La linterna
conserva rango 21, ángulo 29°, bias 0,03 y normal bias 1,5. El sol conserva modo
2 (cuatro divisiones), sombras activas y distancia de sombras 35.

Los huecos entre piezas permanecen abiertos. Vidrios, hojas con scripts y
superficies no verificadas no generan oclusores. Las puertas transparentes no se
consideran paredes por estar cerradas. No se activa oclusión en TapeCamera.
Una guardia desactiva el experimento si la cámara cambia de mundo/capas o entra
en un sólido. No reactiva oclusores antiguos que ya existieran en el mundo.

Las paredes principales usan `pastel_wall_band.gdshader`. Se revisó su código:
sólo calcula varyings, ALBEDO y ROUGHNESS. Se admite exclusivamente su ruta y
SHA256 normalizado exactos; un cambio posterior del shader vuelve a excluirlo.
Una prueba inicial que excluía estas paredes no mejoraba el recorrido; sus JSON
se conservan como `*_preliminary.json` y no se mezclan con los resultados finales.

**No se ha creado un grafo completo de habitaciones/portales.** Los portales NPC
existentes no describen los polígonos de ventanas y puertas. Apagar una sombra
por un raycast hacia la lámpara podría dejar que la luz atravesase la pared.
La prueba usa geometría de oclusión real y deja esta decisión al motor.

## Validación visual y funcional

- `validate_static_shadow_batch_probe.gd`: **744 comprobaciones, 0 fallos**.
  Transformaciones reflejadas/no uniformes, normales, culling mezclado, materiales,
  colisiones, exclusiones, idempotencia y restauración.
- `validate_static_occluder_probe.gd`: **731 comprobaciones, 0 fallos**.
  Ventana abierta entre cuatro piezas, geometría exacta, transparencia, shader
  alterado, capas, segundo viewport, guardia y restauración.
- `validate_shadow_pipeline_visual.gd -- --only=combined`: A/B/A en aparición,
  lavadora y ventana de la entrada. **Región central (70 % de altura) idéntica
  byte por byte a resolución completa** en las tres vistas, incluyendo linterna.
  Se excluye el HUD del análisis. Capturas originales completas guardadas.
- Para el A/B visual se congelan scripts/IA/partículas y se fija TIME en copias
  temporales de los shaders 2D. Es el mismo instante de VHS en ambos estados;
  no se guarda ese cambio ni se aplica en los benchmarks de FPS.

Las imágenes prueban esas tres poses, no todos los ángulos y estados del mapa.
La partida libre permite comparar puertas, ventanas y grabación con las lógicas
normales activas y restaurar el estado anterior con F7.
`preview_shadow_pipeline.gd -- --smoke` también superó la activación y restauración
con la partida y el optimizador normales activos.

## Cómo probar y reproducir

Desde la raíz del proyecto, PowerShell:

```powershell
& ..\godot.exe --path . --script res://tools/preview_shadow_pipeline.gd
```

La partida arranca con el sistema de producción activo. **F7** alterna entre el
sistema y la referencia; el resto de controles es el normal. Al activar puede haber una
pausa de construcción. Cerrar esa partida deja los recursos originales intactos.
`-- --smoke` ejecuta activación/restauración automática y termina.

Medición de una variante, con una sola partida abierta:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_optimization_check.ps1 -Script res://tools/benchmark_shadow_pipeline.gd -TimeoutSeconds 150 -ScriptArguments --only=combined
```

Otras variantes: `pipeline_baseline`, `shadow_batch`, `exact_occlusion`,
`pipeline_repeat`; `live_baseline`, `live_combined`, `live_repeat` conservan la
selección dinámica de sombras activa. La herramienta no activa el candidato de dos divisiones del
sol, rechazado por el usuario.

Datos y capturas: `tools/output/shadow_pipeline_*.json`,
`tools/output/shadow_visual_combined.json`, `tools/output/shadow_visual_*_*.png`.
El HUD de las capturas visuales no sirve para medir FPS: refleja pausas y trabajo
de comparación de imágenes; las cifras válidas son las de los benchmarks.

Referencias de API: [GeometryInstance3D](https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html),
[Occlusion culling](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html).
