# Acompanante reutilizable

`child_companion.tscn` es la variante incluida (Nico). La logica vive en
`companion_npc_base.gd` y el modelo en `child_visual.tscn`.

## Cambiar el asset sin rehacer el NPC

1. Duplica `child_companion.tscn`.
2. Asigna otra `PackedScene` a `visual_scene`.
3. Si el nuevo visual quiere animacion procedural, implementa
   `update_companion_animation(delta, movement, waiting)` en su nodo raiz.

El nuevo asset debe apoyar los pies en Y=0 y mirar hacia +Z. La base conserva
colision, navegacion, apertura de puertas, ordenes, distancia de interaccion y
la penalizacion de velocidad de la orden CERCA.

## Controles

Mira al personaje y pulsa F. Mientras el menu este abierto:

- 1: QUIETO.
- 2: SIGUEME, manteniendo una distancia comoda.
- 3: CERCA, a menos de un metro; reduce la velocidad del jugador al 62 %.
- 4: AVANZA cinco metros en la direccion del jugador y espera.
- 5: VE ALLI, hacia el punto al que apunta la camara y espera.
- Escape: cancela el menu sin cambiar la orden.

Las distancias, velocidades y la penalizacion estan exportadas en el inspector.

