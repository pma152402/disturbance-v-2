# Abuela editable

La escena que se usa en el juego es `res://enemies/monster_grandmother_imported.tscn`.
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

## Continuidad de brazos (2026-09-07)

El visual usa `enemies/granny_continuous_arm.gd` para crear una superficie
continua desde el anclaje del torso hasta la palma. Brazo y antebrazo comparten
los vértices del codo; las mangas comparten su borde con la piel. Las piezas
cilíndricas originales se conservan ocultas como referencia del asset.

Los anclajes de los hombros permanecen en el espacio del torso y se introducen
en el volumen del vestido. Los restos laterales de las mangas antiguas se
ajustan al contorno del pecho conservando las superficies de cierre. Los
pivotes, manos, cabeza y materiales originales siguen utilizándose.

`EditableVisual` pasa de escala 0.18 a 0.207: altura y extremidades aumentan
un 15 %. Sólo cambia la presentación; no se modifica el cuerpo físico ni los
controladores de percepción, persecución, navegación o ataques.

Validación: `tools/validate_grandmother_arm_continuity.gd` recorre 840
fotogramas y siete poses, comprueba continuidad topológica interior y unión de
manga/piel. Se conserva la animación de alimentación. Las vistas de revisión se
generan con `tools/render_grandmother_poses.gd` (opción `-- --back` para la espalda).

Cada brazo tiene 108 vértices y dos superficies de material. Se actualizan al
cambiar la pose; los datos del GLB fuente no se sobrescriben.

## Cabello flotante (2026-09-08)

`enemies/granny_floating_hair.gd` conserva 46 mechones largos de nuca y añade
30 raíces distribuidas sobre la coronilla y 8 pelos finos en frente y sienes.
Las raíces siguen exactamente `HeadPivot`, pero el nodo evita
heredar la escala irregular del GLB para que la anchura y longitud se expresen
en metros. Los mechones centrales de la cara son más cortos y finos; los de
coronilla, sienes y nuca bajan hasta los hombros y el pecho.

La implantación usa una envolvente elipsoidal obtenida del mesh visible de la
cabeza (`x ±0.36 m`, altura `0.70 m`, profundidad `0.58 m`). Esto impide que las
raíces de coronilla o frente queden ocultas dentro del cráneo.

`enemies/granny_floating_hair.gdshader` deja inmóviles las raíces y deforma
progresivamente el resto. Mezcla deriva lenta, vibración desfasada por mechón y
una elevación leve en las puntas para obtener un movimiento desagradable, como
si el pelo flotase o respondiese a un campo magnético. La validación está en
`tools/validate_grandmother_floating_hair.gd`.

El color mezcla grises blanquecinos con pequeñas variaciones amarillentas y
apagadas para conservar un aspecto envejecido y sucio. El ancho procedural está
entre `0.016 m` y `0.034 m`, suficientemente grueso para leerse con la iluminación
del juego sin perder la separación entre pelos sueltos.

## Piel (2026-09-08)

Los brazos y manos usan una base gris ceniza pálida y una textura procedural de
64 px con variación fría, poros y rojeces muy tenues. El color medio final se
valida después de multiplicar textura y albedo, evitando que vuelva a derivar a
un marrón oscuro aunque el valor base parezca claro en el inspector.
