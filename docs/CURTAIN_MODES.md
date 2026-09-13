# Cortinas interactivas

Acercarse a la tela o a uno de sus laterales y pulsar **F**. Cada cortina cambia
independientemente: **recogidas → cerradas → abiertas → recogidas**. El texto de
interacción indica la siguiente acción. Las pulsaciones durante la animación no
acumulan movimientos.

Se han integrado las 14 cortinas de ventana, el telón del salón de actos y la
cortina del confesionario. Se conserva su apariencia inicial: ventanas y telón
recogidos; confesionario cerrado, como estaba en la escena original.

- Recogidas: geometría original; en el confesionario, tela recogida hacia un lado.
- Cerradas: paños desplegados con pliegues y solape entre secciones.
- Abiertas: tela plegada a los extremos de la barra; el confesionario abre hacia
  un solo lado. Se conservan barras, remates y cenefas.

La transición tarda 1,15 segundos (1,8 en el telón) con aceleración y frenado
suaves. Las colas acompañan al extremo inferior del paño al desplegarse. No hay
simulación física de tela ni bucles de animación en reposo. Las áreas de F no
bloquean el movimiento; el objetivo central se activa solo con la tela cerrada.

## Implementación y coste

`house_props/interactive_curtains.gd` controla estado, interacción y transición.
`house_props/curtain_mesh_builder.gd` conserva los materiales originales y genera
tres poses estáticas compartidas por las instancias equivalentes. Durante la
transición se usa una malla con dos blend shapes; al terminar se sustituye por
una malla normal sin deformación GPU. No se reconstruyen vértices por fotograma.

Las 25 piezas originales de cada ventana se agrupan en 4 superficies por material
(350 piezas visibles de ventanas pasan a 56 superficies). El telón usa 1 superficie
y la tela del confesionario 2: 59 superficies en total para los 16 conjuntos. Esto
reduce envíos de dibujo; no es una medición del aumento de FPS del nivel completo.
Las mallas originales quedan ocultas en ejecución y siguen editables en la escena.

El controlador del telón excluye sus piezas del agrupado estático de la escuela.
Su integración también está en `tools/build_school_completion.gd`, de modo que
regenerar la ampliación no elimina el comportamiento.

## Verificación

Con Godot 4.7.2, desde la raíz del proyecto:

```powershell
..\godot.exe --headless --fixed-fps 60 --path . --script tools/validate_curtains.gd --quit-after 1800
..\godot.exe --headless --fixed-fps 60 --path . --script tools/validate_curtain_interaction.gd --quit-after 1800
..\godot.exe --path . --script tools/validate_curtains.gd --quit-after 1800 -- --render
```

Resultados: 59 comprobaciones de poses y transiciones, 140 de interacción e
integración, sin fallos de las comprobaciones. Se verifica F con el jugador real
desde ambos lados, transformaciones con giro/escala, bloqueo por paredes, hueco
abierto sin objetivo invisible, independencia de estados y acceso a un tirador
en cada modo de las 16 cortinas del nivel. También se arrancó la escena principal.

El render genera `tools/output/curtain_three_modes.png` y
`tools/output/curtain_transitions.png`, inspeccionadas con iluminación de prueba.
Los logs del entorno incluyen un aviso del almacén de certificados y, al cerrar
la escena completa, recursos pendientes de liberar; no aparecen errores de
parseo ni de ejecución de los scripts de cortinas.
