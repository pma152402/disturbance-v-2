# Abuela editable

La escena que se usa en el juego es `res://monster_grandmother_imported.tscn`.
El GLB original se conserva solo como fuente; su armature Mixamo tiene el bind pose roto y no debe editarse directamente.

En el arbol de la escena, abre:

`EditableVisual > CleanModel > EditableGrannyRig`

- `HeadPivot`: mueve conjuntamente cara, pelo, ojos y dientes.
- `LeftShoulderPivot` / `RightShoulderPivot`: controlan el brazo completo.
- `LeftElbowPivot` / `RightElbowPivot`: controlan antebrazo y mano.
- `LeftWristPivot` / `RightWristPivot`: controlan palma, pulgar y dedos.
- `Body`: cuerpo y vestido originales ya corregidos de anchura.

La animacion guarda estas transformaciones como pose base al comenzar, por lo que los ajustes hechos en el editor no se pierden al moverse el personaje.

Para reconstruir el GLB limpio desde la fuente se puede ejecutar `res://tools/build_granny_editable.py` con Blender.
