# Acompanante reutilizable

`child_companion.tscn` es la variante incluida (Nico). La logica vive en
`companion_npc_base.gd` y el modelo en `child_visual.tscn`.

## Cambiar el asset sin rehacer el NPC

1. Duplica `child_companion.tscn`.
2. Asigna otra `PackedScene` a `visual_scene`.
3. Si el nuevo visual quiere animacion procedural, implementa
   `update_companion_animation(delta, movement, waiting)` en su nodo raiz.
4. Para copiar agachado y cuerpo a tierra, implementa tambien el metodo opcional
   `set_companion_posture(posture)`, donde 0 es de pie, 1 agachado y 2 en suelo.

El nuevo asset debe apoyar los pies en Y=0 y mirar hacia +Z. La base conserva
colision, navegacion, apertura de puertas, ordenes, distancia de interaccion y
la penalizacion de velocidad de la orden CERCA.

La IA espera al horneado del mapa de navegacion antes de caminar. Sus destinos
usan dos radios de llegada (histeresis), direccion suavizada y reintento estable
si queda bloqueada, evitando el temblor de izquierda a derecha.

SIGUEME usa una zona personal, no un punto pegado a la espalda: girar la camara
no provoca recolocaciones. Al acercarse, la velocidad cae con una curva suave y
la animacion se funde hasta el reposo. El visual infantil incluye rodillas
articuladas para evitar el andar rigido desde la cadera.

Nico imita automaticamente las tres posturas del jugador. La base interpola la
capsula y la altura de navegacion, reduce la velocidad al andar agachado o a
cuatro patas y comprueba que haya espacio antes de volver a levantarse.

Los acompañantes marcados como `is_child_target` son presas prioritarias para la
abuela. Al morir emiten `killed_by_monster`, caen al suelo y pueden restaurarse
con `release_after_monster_capture(position)` para comenzar otro trayecto A-B.

Tambien compensa automaticamente la diferencia vertical entre la colision y la
malla navegable, invalida rutas cuando la casa termina un nuevo bake y rechaza
destinos proyectados al lado incorrecto de una pared.

## Controles

Mira al personaje y pulsa F. Mientras el menu este abierto:

- 1: QUIETO.
- 2: SIGUEME, manteniendo una distancia comoda.
- 3: CERCA, a menos de un metro; reduce la velocidad del jugador al 62 %.
- 4: AVANZA cinco metros en la direccion del jugador y espera.
- 5: VE ALLI, hacia el punto al que apunta la camara y espera.
- Escape: cancela el menu sin cambiar la orden.

Las distancias, velocidades y la penalizacion estan exportadas en el inspector.

## Revisión de locomoción y puertas

El visual puede implementar `set_motion_context(speed, turn_velocity, gaze,
crossing)` para animar con velocidad física, orientar la cabeza y responder al
cruce de puertas. `speed` se expresa en metros por segundo a escala del visual;
`gaze` es un punto global. La interfaz anterior sigue disponible como respaldo.

Las puertas que implementan `is_npc_passage_ready()` permiten esperar a la hoja
real sin un retraso fijo. QUIETO cancela inmediatamente el cruce. La cápsula
comprueba obstáculos antes de atravesar el umbral.

Diseño, pruebas y límites en `../../COMPANION_REWORK.md`.
