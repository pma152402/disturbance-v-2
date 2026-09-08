# Componentes exclusivos de grabación

Estas escenas se previsualizan en el editor, pero durante el juego se asignan a
la capa visual 20. La cámara en directo excluye esa capa y la cámara interna que
graba las cintas sí la incluye.

- `2_recording_only_footsteps.tscn`: rastro de 2 pisadas.
- `4_recording_only_footsteps.tscn`: rastro de 4 pisadas.
- `recording_only_pen_circle.tscn`: círculo irregular de tinta sobre el suelo.
- `recording_only_hanging_man.tscn`: cura colgado con sotana, alzacuellos,
  crucifijo, saco cosido y manos y tobillos atados; su origen se coloca en el
  punto de anclaje del techo y el cuerpo crece hacia abajo.

Cada componente permite limitar a qué distancia aparece en la grabación y
desactivar su previsualización de editor desde el inspector.

## Editar el cura pieza por pieza

`recording_only_hanging_man.tscn` es una escena convencional. Al abrirla,
`HangingFigure` contiene directamente todas las piezas como `MeshInstance3D`:
se pueden mover, escalar, rotar, cambiar de material, duplicar o eliminar y los
cambios se guardan de forma normal. El script del nodo raíz no genera ni
reconstruye nada; únicamente cambia las capas visuales al entrar al juego.
